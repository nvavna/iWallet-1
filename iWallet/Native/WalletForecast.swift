import Foundation

/// A read-only projection of saved recurring schedules in one currency.
enum WalletForecast {
    enum Horizon: Int, CaseIterable, Identifiable {
        case sevenDays = 7
        case thirtyDays = 30
        var id: Int { rawValue }
    }

    struct Plan {
        let id: UUID
        let name: String
        let amountMinor: Int64
        let currencyCode: String
        let cadence: RecurringCadence
        let nextDueDate: Date
        let anchorDay: Int
        let anchorMonth: Int
        let timeZoneIdentifier: String
        let isActive: Bool

        init(id: UUID = UUID(), name: String, amountMinor: Int64, currencyCode: String,
             cadence: RecurringCadence, nextDueDate: Date, anchorDay: Int, anchorMonth: Int,
             timeZoneIdentifier: String, isActive: Bool = true) {
            self.id = id
            self.name = name
            self.amountMinor = amountMinor
            self.currencyCode = currencyCode
            self.cadence = cadence
            self.nextDueDate = nextDueDate
            self.anchorDay = anchorDay
            self.anchorMonth = anchorMonth
            self.timeZoneIdentifier = timeZoneIdentifier
            self.isActive = isActive
        }

        @MainActor
        init(payment: WalletRecurringPayment) throws {
            guard let cadence = RecurringCadence(rawValue: payment.cadenceRaw) else {
                throw RecurringPaymentError.invalidSchedule
            }
            self.init(id: payment.id, name: payment.name, amountMinor: payment.amountMinor,
                      currencyCode: payment.currencyCode, cadence: cadence, nextDueDate: payment.nextDueDate,
                      anchorDay: payment.anchorDay, anchorMonth: payment.anchorMonth,
                      timeZoneIdentifier: payment.timeZoneIdentifier, isActive: payment.isActive)
        }
    }

    struct Occurrence: Identifiable {
        struct ID: Hashable {
            let planID: UUID
            let date: Date
        }
        var id: ID { ID(planID: planID, date: date) }
        let planID: UUID
        let name: String
        let amountMinor: Int64
        let date: Date
        let timeZoneIdentifier: String

        fileprivate init(_ plan: Plan, date: Date) {
            planID = plan.id
            name = plan.name
            amountMinor = plan.amountMinor
            self.date = date
            timeZoneIdentifier = plan.timeZoneIdentifier
        }
    }

    struct Snapshot {
        let currencyCode: String
        let horizon: Horizon
        let upcoming: [Occurrence]
        let overdue: [Occurrence]
        let upcomingMinor: Int64
        let overdueMinor: Int64
    }

    /// Today and the following 6/29 civil dates in each plan's own time zone.
    /// Each overdue plan contributes its single saved open date to overdue,
    /// and every projected occurrence inside the window to upcoming.
    static func make(plans: [Plan], currencyCode: String, horizon: Horizon,
                     now: Date = Date()) throws -> Snapshot {
        guard WalletCurrency(rawValue: currencyCode) != nil else { throw MoneyError.unsupportedCurrency }
        guard WalletDateRange.contains(now) else { throw WalletStoreError.invalidDate }
        var windows: [String: Window] = [:]
        var upcoming: [Occurrence] = []
        var overdue: [Occurrence] = []
        for plan in plans where plan.isActive && plan.currencyCode == currencyCode {
            guard plan.amountMinor > 0 else { throw MoneyError.nonPositiveAmount }
            try RecurringSchedule.validate(nextDueDate: plan.nextDueDate, cadence: plan.cadence,
                                           anchorDay: plan.anchorDay, anchorMonth: plan.anchorMonth,
                                           timeZoneIdentifier: plan.timeZoneIdentifier)
            let window: Window
            if let cached = windows[plan.timeZoneIdentifier] {
                window = cached
            } else {
                window = try Window(now: now, horizon: horizon, timeZoneIdentifier: plan.timeZoneIdentifier)
                windows[plan.timeZoneIdentifier] = window
            }
            if plan.nextDueDate < window.today {
                overdue.append(Occurrence(plan, date: plan.nextDueDate))
            }
            let dates = try window.dates(for: plan)
            upcoming.append(contentsOf: dates.map { Occurrence(plan, date: $0) })
        }
        func ordered(_ lhs: Occurrence, _ rhs: Occurrence) -> Bool {
            if lhs.date != rhs.date { return lhs.date < rhs.date }
            if lhs.name != rhs.name { return lhs.name < rhs.name }
            return lhs.planID.uuidString < rhs.planID.uuidString
        }
        return Snapshot(currencyCode: currencyCode, horizon: horizon,
                        upcoming: upcoming.sorted(by: ordered), overdue: overdue.sorted(by: ordered),
                        upcomingMinor: try Money.sum(upcoming.map(\.amountMinor)),
                        overdueMinor: try Money.sum(overdue.map(\.amountMinor)))
    }

    private struct Window {
        struct Day {
            let date: Date
            let offset: Int
            let month: Int
            let day: Int
            let lastDayOfMonth: Int
        }
        let calendar: Calendar
        let today: Date
        let days: [Day]

        init(now: Date, horizon: Horizon, timeZoneIdentifier: String) throws {
            let calendar = try RecurringSchedule.calendar(timeZoneIdentifier: timeZoneIdentifier)
            let today = calendar.startOfDay(for: now)
            var days: [Day] = []
            for offset in 0..<horizon.rawValue {
                guard let candidate = calendar.date(byAdding: .day, value: offset, to: today) else {
                    throw RecurringPaymentError.invalidSchedule
                }
                let date = calendar.startOfDay(for: candidate)
                guard WalletDateRange.contains(date) else { continue }
                let components = calendar.dateComponents([.month, .day], from: date)
                guard let month = components.month, let day = components.day,
                      let dayRange = calendar.range(of: .day, in: .month, for: date) else {
                    throw RecurringPaymentError.invalidSchedule
                }
                days.append(Day(date: date, offset: offset, month: month, day: day,
                                lastDayOfMonth: dayRange.upperBound - 1))
            }
            self.calendar = calendar
            self.today = today
            self.days = days
        }

        func dates(for plan: Plan) throws -> [Date] {
            // Check only the small visible window, even when the saved due date is centuries old.
            // The explicit saved anchors preserve the 31st and leap day after short months.
            let elapsed: Int
            if plan.cadence == .weekly {
                // Some local days start at 01:00 after a midnight DST jump.
                // Compare at the same local clock time so seven civil days stay seven.
                guard let dueNoon = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: plan.nextDueDate),
                      let todayNoon = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: today),
                      let days = calendar.dateComponents([.day], from: dueNoon, to: todayNoon).day else {
                    throw RecurringPaymentError.invalidSchedule
                }
                elapsed = days
            } else {
                elapsed = 0
            }
            return days.compactMap { day in
                guard day.date >= plan.nextDueDate else { return nil }
                switch plan.cadence {
                case .weekly:
                    return (elapsed + day.offset).isMultiple(of: 7) ? day.date : nil
                case .monthly:
                    return day.day == min(plan.anchorDay, day.lastDayOfMonth) ? day.date : nil
                case .yearly:
                    return day.month == plan.anchorMonth && day.day == min(plan.anchorDay, day.lastDayOfMonth)
                        ? day.date : nil
                }
            }
        }
    }
}

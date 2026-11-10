import Foundation
import SwiftData
import XCTest
@testable import WalletCore

final class WalletForecastTests: XCTestCase {
    private func day(_ year: Int, _ month: Int, _ day: Int, zone: String = "UTC") throws -> Date {
        let calendar = try RecurringSchedule.calendar(timeZoneIdentifier: zone)
        let noon = try XCTUnwrap(calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12)))
        return calendar.startOfDay(for: noon)
    }

    private func plan(_ name: String = "Plan", _ amount: Int64 = 100, due: Date,
                      cadence: RecurringCadence = .weekly, currency: String = "USD", zone: String = "UTC",
                      anchorDay: Int? = nil, anchorMonth: Int? = nil, active: Bool = true,
                      id: UUID = UUID()) throws -> WalletForecast.Plan {
        let calendar = try RecurringSchedule.calendar(timeZoneIdentifier: zone)
        return .init(id: id, name: name, amountMinor: amount, currencyCode: currency, cadence: cadence,
                     nextDueDate: due, anchorDay: anchorDay ?? calendar.component(.day, from: due),
                     anchorMonth: anchorMonth ?? calendar.component(.month, from: due),
                     timeZoneIdentifier: zone, isActive: active)
    }

    func testWindowStartsTodayAndIncludesSixOrTwentyNineFollowingDays() throws {
        let first = try day(2026, 11, 5)
        let plans = try [plan("Today", 1, due: first, cadence: .yearly),
                         plan("Day 7", 2, due: day(2026, 11, 11), cadence: .yearly),
                         plan("Day 8", 4, due: day(2026, 11, 12), cadence: .yearly),
                         plan("Day 30", 8, due: day(2026, 12, 4), cadence: .yearly),
                         plan("Day 31", 16, due: day(2026, 12, 5), cadence: .yearly)]
        let now = first.addingTimeInterval(23 * 3_600)
        let week = try WalletForecast.make(plans: plans, currencyCode: "USD", horizon: .sevenDays, now: now)
        let month = try WalletForecast.make(plans: plans, currencyCode: "USD", horizon: .thirtyDays, now: now)
        XCTAssertEqual(week.upcoming.map(\.name), ["Today", "Day 7"])
        XCTAssertEqual(week.upcomingMinor, 3)
        XCTAssertEqual(month.upcoming.map(\.name), ["Today", "Day 7", "Day 8", "Day 30"])
        XCTAssertEqual(month.upcomingMinor, 15)
        XCTAssertTrue(month.overdue.isEmpty)
    }

    func testWeeklyPlanContributesEveryOccurrenceButNeverBeforeSavedDueDate() throws {
        let first = try day(2026, 11, 5)
        let startsNow = try plan("Weekly", 99, due: first)
        let startsLater = try plan("Later", 50, due: day(2026, 11, 26))
        let snapshot = try WalletForecast.make(plans: [startsLater, startsNow], currencyCode: "USD",
                                               horizon: .thirtyDays, now: first)
        XCTAssertEqual(snapshot.upcoming.filter { $0.planID == startsNow.id }.map(\.date),
                       try [day(2026, 11, 5), day(2026, 11, 12), day(2026, 11, 19),
                            day(2026, 11, 26), day(2026, 12, 3)])
        XCTAssertEqual(snapshot.upcoming.filter { $0.planID == startsLater.id }.map(\.date),
                       try [day(2026, 11, 26), day(2026, 12, 3)])
        XCTAssertEqual(snapshot.upcomingMinor, 595)
        XCTAssertEqual(Set(snapshot.upcoming.map(\.id)).count, 7)
    }

    func testOverdueMonthlyPlanHasOneOpenDateAndFutureOccurrencesWithClampedAnchor31() throws {
        let due = try day(2020, 12, 31)
        let rent = try plan("Rent", 1_050, due: due, cadence: .monthly)
        let snapshot = try WalletForecast.make(plans: [rent], currencyCode: "USD",
                                               horizon: .thirtyDays, now: day(2025, 1, 31))
        XCTAssertEqual(snapshot.overdue.map(\.date), [due])
        XCTAssertEqual(snapshot.overdueMinor, 1_050)
        XCTAssertEqual(snapshot.upcoming.map(\.date), try [day(2025, 1, 31), day(2025, 2, 28)])
        XCTAssertEqual(snapshot.upcomingMinor, 2_100)
        let march = try WalletForecast.make(plans: [try plan(due: day(2025, 2, 28), cadence: .monthly, anchorDay: 31)],
            currencyCode: "USD", horizon: .sevenDays, now: day(2025, 3, 28))
        XCTAssertEqual(march.upcoming.first?.date, try day(2025, 3, 31))
    }

    func testAnnualLeapDayReturnsAfterNonLeapFebruary() throws {
        let leap = try plan("Annual", 250, due: day(2025, 2, 28), cadence: .yearly, anchorDay: 29)
        for (year, expectedDay) in [(2027, 28), (2028, 29)] {
            let snapshot = try WalletForecast.make(plans: [leap], currencyCode: "USD",
                                                   horizon: .sevenDays, now: day(year, 2, 25))
            XCTAssertEqual(snapshot.overdue.count, 1)
            XCTAssertEqual(snapshot.upcoming.map(\.date), try [day(year, 2, expectedDay)])
        }
    }

    func testVeryOldOverdueWeeklyPlanProjectsOnlyCurrentWindow() throws {
        let ancient = try plan("Long running", 10, due: day(1, 1, 15))
        let today = try day(2026, 11, 5)
        let snapshot = try WalletForecast.make(plans: [ancient], currencyCode: "USD",
                                               horizon: .thirtyDays, now: today)
        XCTAssertEqual(snapshot.overdue.map(\.date), [ancient.nextDueDate])
        XCTAssertEqual(snapshot.overdueMinor, 10)
        XCTAssertTrue((4...5).contains(snapshot.upcoming.count))
        XCTAssertEqual(snapshot.upcomingMinor, Int64(snapshot.upcoming.count) * 10)
        let first = try XCTUnwrap(snapshot.upcoming.first)
        XCTAssertGreaterThanOrEqual(first.date, today)
        XCTAssertLessThan(first.date, try day(2026, 11, 12))
        for (previous, next) in zip(snapshot.upcoming, snapshot.upcoming.dropFirst()) {
            let expected = try RecurringSchedule.nextDate(after: previous.date, cadence: .weekly,
                anchorDay: ancient.anchorDay, anchorMonth: ancient.anchorMonth, timeZoneIdentifier: "UTC")
            XCTAssertEqual(next.date, expected)
        }
    }

    func testLocalTodayCanDifferForTwoPlansAtSameInstant() throws {
        let west = "America/Los_Angeles", east = "Asia/Tokyo"
        let dueWest = try day(2026, 11, 5, zone: west)
        let dueEast = try day(2026, 11, 5, zone: east)
        let plans = try [plan("West", 10, due: dueWest, zone: west), plan("East", 20, due: dueEast, zone: east)]
        let now = try day(2026, 11, 5).addingTimeInterval(23 * 3_600)
        let snapshot = try WalletForecast.make(plans: plans, currencyCode: "USD", horizon: .sevenDays, now: now)
        XCTAssertEqual(snapshot.overdue.map(\.name), ["East"])
        XCTAssertEqual(snapshot.upcoming.map(\.date), try [dueWest, day(2026, 11, 12, zone: east)])
        XCTAssertEqual(snapshot.upcomingMinor, 30)
        XCTAssertEqual(snapshot.overdueMinor, 20)
    }

    func testWeeklyCivilDatesAcrossSpringAndAutumnDST() throws {
        let zone = "America/New_York"
        for (month, dayOfMonth, hours) in [(3, 8, 167), (11, 1, 169)] {
            let due = try day(2026, month, dayOfMonth, zone: zone)
            let payment = try plan(due: due, zone: zone)
            let snapshot = try WalletForecast.make(plans: [payment], currencyCode: "USD",
                                                   horizon: .thirtyDays, now: due.addingTimeInterval(3_600))
            let expected = try RecurringSchedule.nextDate(after: due, cadence: .weekly, anchorDay: dayOfMonth,
                                                          anchorMonth: month, timeZoneIdentifier: zone)
            XCTAssertEqual(snapshot.upcoming[1].date, expected)
            XCTAssertEqual(expected.timeIntervalSince(due), TimeInterval(hours * 3_600))
        }
    }

    func testWeeklyMidnightGapStillMatchesSevenCivilDaysLater() throws {
        let zone = "America/Sao_Paulo"
        let due = try day(2018, 11, 4, zone: zone)
        let next = try RecurringSchedule.nextDate(after: due, cadence: .weekly,
                                                 anchorDay: 4, anchorMonth: 11, timeZoneIdentifier: zone)
        let snapshot = try WalletForecast.make(plans: [try plan(due: due, zone: zone)],
                                               currencyCode: "USD", horizon: .sevenDays, now: next)
        XCTAssertEqual(snapshot.upcoming.map(\.date), [next])
        XCTAssertEqual(snapshot.overdue.map(\.date), [due])
    }

    func testPausedAndOtherCurrenciesAreExcludedFromBothTotals() throws {
        let current = try day(2026, 11, 5), earlier = try day(2026, 11, 1)
        let plans = try [plan("USD", 1, due: current), plan("EUR", 200, due: earlier, currency: "EUR"),
                         plan("Paused", 400, due: earlier, active: false)]
        let snapshot = try WalletForecast.make(plans: plans, currencyCode: "USD", horizon: .thirtyDays, now: current)
        XCTAssertEqual(snapshot.upcomingMinor, 5)
        XCTAssertTrue(snapshot.upcoming.allSatisfy { $0.name == "USD" })
        XCTAssertTrue(snapshot.overdue.isEmpty)
        let empty = try WalletForecast.make(plans: plans, currencyCode: "JPY", horizon: .sevenDays, now: current)
        XCTAssertTrue(empty.upcoming.isEmpty)
        XCTAssertEqual(empty.upcomingMinor, 0)
        XCTAssertEqual(empty.overdueMinor, 0)
    }

    func testInvalidInputsAndOverflowDoNotReturnPartialForecast() throws {
        let today = try day(2026, 11, 5)
        XCTAssertThrowsError(try WalletForecast.make(plans: [], currencyCode: "BAD", horizon: .sevenDays, now: today))
        XCTAssertThrowsError(try WalletForecast.make(plans: [try plan("Zero", 0, due: today)],
                                                    currencyCode: "USD", horizon: .sevenDays, now: today))
        let huge = try plan("Huge", Int64.max, due: today)
        XCTAssertEqual(try WalletForecast.make(plans: [huge], currencyCode: "USD",
                                               horizon: .sevenDays, now: today).upcomingMinor, Int64.max)
        XCTAssertThrowsError(try WalletForecast.make(plans: [huge], currencyCode: "USD", horizon: .thirtyDays, now: today)) {
            XCTAssertEqual($0 as? MoneyError, .overflow)
        }
        let old = try day(2020, 1, 1)
        let overdue = try [plan("A", Int64.max, due: old, cadence: .yearly),
                           plan("B", 1, due: old, cadence: .yearly)]
        XCTAssertThrowsError(try WalletForecast.make(plans: overdue, currencyCode: "USD", horizon: .sevenDays, now: today)) {
            XCTAssertEqual($0 as? MoneyError, .overflow)
        }
    }

    func testFinalSupportedDayDoesNotRequireAValidNextYear() throws {
        let due = try day(9999, 12, 31)
        let snapshot = try WalletForecast.make(plans: [try plan(due: due, cadence: .monthly)],
                                               currencyCode: "USD", horizon: .thirtyDays, now: due)
        XCTAssertEqual(snapshot.upcoming.map(\.date), [due])
    }

    @MainActor
    func testForecastLeavesPersistedScheduleAndLedgerUntouched() async throws {
        let container = try WalletStore.makeContainer(inMemory: true)
        let context = container.mainContext
        let due = try day(2022, 1, 31)
        let payment = WalletRecurringPayment(name: "Rent", amountMinor: 10_500, currencyCode: "USD",
            category: nil, cadence: .monthly, nextDueDate: due, anchorDay: 31, anchorMonth: 1, timeZoneIdentifier: "UTC")
        context.insert(payment)
        try context.save()
        let token = payment.occurrenceID
        let copies = [try WalletForecast.Plan(payment: payment)]
        let snapshot = try WalletForecast.make(plans: copies, currencyCode: "USD", horizon: .thirtyDays,
                                               now: day(2026, 11, 5))
        XCTAssertEqual(snapshot.upcoming.map(\.date), try [day(2026, 11, 30)])
        XCTAssertEqual(snapshot.overdue.map(\.date), [due])
        XCTAssertFalse(context.hasChanges)
        let fresh = ModelContext(container)
        let stored = try XCTUnwrap(fresh.fetch(FetchDescriptor<WalletRecurringPayment>()).first)
        XCTAssertEqual(stored.nextDueDate, due)
        XCTAssertEqual(stored.occurrenceID, token)
        XCTAssertEqual(try fresh.fetchCount(FetchDescriptor<WalletTransaction>()), 0)
    }
}

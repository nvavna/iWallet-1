import Foundation
import SwiftData

enum RecurringCadence: String, Codable, CaseIterable, Identifiable, Sendable {
    case weekly, monthly, yearly

    var id: String { rawValue }
    var localizedName: String {
        switch self {
        case .weekly: return NSLocalizedString("Weekly", comment: "Recurring payment cadence")
        case .monthly: return NSLocalizedString("Monthly", comment: "Recurring payment cadence")
        case .yearly: return NSLocalizedString("Yearly", comment: "Recurring payment cadence")
        }
    }
}

struct RecurringOccurrence: Equatable, Sendable {
    let paymentID: UUID
    let occurrenceID: UUID
    let dueDate: Date
}

@Model
final class WalletRecurringPayment {
    @Attribute(.unique) var id: UUID
    var name: String
    var amountMinor: Int64
    var currencyCode: String
    var category: WalletCategory?
    var cadenceRaw: String
    var nextDueDate: Date
    var anchorDay: Int
    var anchorMonth: Int
    var timeZoneIdentifier: String
    var isActive: Bool
    var isSubscription: Bool
    var occurrenceID: UUID

    var cadence: RecurringCadence {
        get { RecurringCadence(rawValue: cadenceRaw) ?? .monthly }
        set { cadenceRaw = newValue.rawValue }
    }
    var occurrence: RecurringOccurrence {
        RecurringOccurrence(paymentID: id, occurrenceID: occurrenceID, dueDate: nextDueDate)
    }
    // Invalid persisted time zones can still be displayed. Every write and
    // backup validates the identifier and never uses this display fallback.
    var timeZone: TimeZone { TimeZone(identifier: timeZoneIdentifier) ?? TimeZone(secondsFromGMT: 0)! }
    var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }

    func isOverdue(asOf date: Date = Date()) -> Bool {
        guard isActive, WalletDateRange.contains(date), WalletDateRange.contains(nextDueDate) else { return false }
        return calendar.startOfDay(for: nextDueDate) < calendar.startOfDay(for: date)
    }

    func isDueToday(asOf date: Date = Date()) -> Bool {
        guard isActive, WalletDateRange.contains(date), WalletDateRange.contains(nextDueDate) else { return false }
        return calendar.isDate(nextDueDate, inSameDayAs: date)
    }

    init(name: String, amountMinor: Int64, currencyCode: String, category: WalletCategory?,
         cadence: RecurringCadence, nextDueDate: Date, anchorDay: Int, anchorMonth: Int,
         timeZoneIdentifier: String, isActive: Bool = true, isSubscription: Bool = false,
         id: UUID = UUID(), occurrenceID: UUID = UUID()) {
        self.id = id
        self.name = name
        self.amountMinor = amountMinor
        self.currencyCode = currencyCode
        self.category = category
        self.cadenceRaw = cadence.rawValue
        self.nextDueDate = nextDueDate
        self.anchorDay = anchorDay
        self.anchorMonth = anchorMonth
        self.timeZoneIdentifier = timeZoneIdentifier
        self.isActive = isActive
        self.isSubscription = isSubscription
        self.occurrenceID = occurrenceID
    }
}

enum RecurringPaymentError: LocalizedError, Equatable {
    case emptyName, missingPayment, invalidSchedule, invalidTimeZone
    case pausedPayment, staleOccurrence, unsavedChanges

    var errorDescription: String? {
        switch self {
        case .emptyName:
            return NSLocalizedString("Enter a payment name.", comment: "Recurring payment error")
        case .missingPayment:
            return NSLocalizedString("This recurring payment is no longer available.", comment: "Recurring payment error")
        case .invalidSchedule:
            return NSLocalizedString("Choose a valid recurring payment date and schedule.", comment: "Recurring payment error")
        case .invalidTimeZone:
            return NSLocalizedString("The payment's time zone is not supported.", comment: "Recurring payment error")
        case .pausedPayment:
            return NSLocalizedString("Resume this payment before recording or skipping an occurrence.", comment: "Recurring payment error")
        case .staleOccurrence:
            return NSLocalizedString("This payment has changed. Review its current details before continuing.", comment: "Recurring payment error")
        case .unsavedChanges:
            return NSLocalizedString("Finish or cancel your current changes before updating recurring payments.", comment: "Recurring payment error")
        }
    }
}

/// A recurrence is a Gregorian calendar day in a saved time zone, not a fixed
/// number of seconds. The original day/month survive short months and leap years.
enum RecurringSchedule {
    static func calendar(timeZoneIdentifier: String) throws -> Calendar {
        guard let timeZone = TimeZone(identifier: timeZoneIdentifier) else { throw RecurringPaymentError.invalidTimeZone }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }

    static func normalizedDate(_ date: Date, timeZoneIdentifier: String) throws -> Date {
        guard WalletDateRange.contains(date) else { throw WalletStoreError.invalidDate }
        let calendar = try calendar(timeZoneIdentifier: timeZoneIdentifier)
        let day = calendar.startOfDay(for: date)
        guard WalletDateRange.contains(day), (1...9999).contains(calendar.component(.year, from: day)),
              calendar.component(.era, from: day) == 1 else { throw WalletStoreError.invalidDate }
        return day
    }

    static func validate(nextDueDate: Date, cadence: RecurringCadence, anchorDay: Int,
                         anchorMonth: Int, timeZoneIdentifier: String) throws {
        guard (1...31).contains(anchorDay), (1...12).contains(anchorMonth) else { throw RecurringPaymentError.invalidSchedule }
        let normalized = try normalizedDate(nextDueDate, timeZoneIdentifier: timeZoneIdentifier)
        guard normalized == nextDueDate else { throw RecurringPaymentError.invalidSchedule }
        let calendar = try calendar(timeZoneIdentifier: timeZoneIdentifier)
        if cadence != .weekly {
            guard let days = calendar.range(of: .day, in: .month, for: nextDueDate),
                  calendar.component(.day, from: nextDueDate) == min(anchorDay, days.count) else {
                throw RecurringPaymentError.invalidSchedule
            }
        }
        if cadence == .yearly, calendar.component(.month, from: nextDueDate) != anchorMonth {
            throw RecurringPaymentError.invalidSchedule
        }
    }

    static func nextDate(after date: Date, cadence: RecurringCadence, anchorDay: Int,
                         anchorMonth: Int, timeZoneIdentifier: String) throws -> Date {
        try validate(nextDueDate: date, cadence: cadence, anchorDay: anchorDay,
                     anchorMonth: anchorMonth, timeZoneIdentifier: timeZoneIdentifier)
        let calendar = try calendar(timeZoneIdentifier: timeZoneIdentifier)
        let next: Date
        if cadence == .weekly {
            guard let value = calendar.date(byAdding: .day, value: 7, to: date) else { throw RecurringPaymentError.invalidSchedule }
            next = calendar.startOfDay(for: value)
        } else {
            let year = calendar.component(.year, from: date)
            let month = calendar.component(.month, from: date)
            let nextYear = cadence == .yearly || month == 12 ? year + 1 : year
            let nextMonth = cadence == .yearly ? anchorMonth : (month == 12 ? 1 : month + 1)
            guard (1...9999).contains(nextYear),
                  let first = calendar.date(from: DateComponents(year: nextYear, month: nextMonth, day: 1, hour: 12)),
                  let days = calendar.range(of: .day, in: .month, for: first) else { throw RecurringPaymentError.invalidSchedule }
            let targetDay = min(anchorDay, days.count)
            guard let value = calendar.date(from: DateComponents(year: nextYear, month: nextMonth, day: targetDay, hour: 12)),
                  calendar.component(.year, from: value) == nextYear,
                  calendar.component(.month, from: value) == nextMonth,
                  calendar.component(.day, from: value) == targetDay else { throw RecurringPaymentError.invalidSchedule }
            next = calendar.startOfDay(for: value)
        }
        guard WalletDateRange.contains(next), next > date else { throw RecurringPaymentError.invalidSchedule }
        try validate(nextDueDate: next, cadence: cadence, anchorDay: anchorDay,
                     anchorMonth: anchorMonth, timeZoneIdentifier: timeZoneIdentifier)
        return next
    }
}

/// Recurring writes use an isolated context so a failed insert cannot leak a
/// phantom expense into SwiftUI queries. After success the UI must reload its
/// model container/context; an existing caller model is an obsolete snapshot.
@MainActor
extension WalletStore {
    @discardableResult
    static func saveRecurringPayment(context: ModelContext, payment: WalletRecurringPayment? = nil,
                                     name: String, amountMinor: Int64, currencyCode: String,
                                     category: WalletCategory, cadence: RecurringCadence, nextDueDate: Date,
                                     isSubscription: Bool = false,
                                     timeZoneIdentifier: String = TimeZone.current.identifier) throws -> WalletRecurringPayment {
        let working = try recurringWriteContext(context)
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw RecurringPaymentError.emptyName }
        try validateRecurringAmount(amountMinor, currencyCode: currencyCode)
        let storedCategory = try recurringCategory(category, caller: context, working: working)
        let storedPayment = try payment.map { try currentPayment($0, caller: context, working: working) }
        let due = try RecurringSchedule.normalizedDate(nextDueDate, timeZoneIdentifier: timeZoneIdentifier)
        let calendar = try RecurringSchedule.calendar(timeZoneIdentifier: timeZoneIdentifier)
        let preservesAnchor = storedPayment.map {
            $0.cadenceRaw == cadence.rawValue && $0.nextDueDate == due && $0.timeZoneIdentifier == timeZoneIdentifier
        } ?? false
        let anchorDay = preservesAnchor ? storedPayment!.anchorDay : calendar.component(.day, from: due)
        let anchorMonth = preservesAnchor ? storedPayment!.anchorMonth : calendar.component(.month, from: due)
        try RecurringSchedule.validate(nextDueDate: due, cadence: cadence, anchorDay: anchorDay,
                                       anchorMonth: anchorMonth, timeZoneIdentifier: timeZoneIdentifier)
        let result = storedPayment ?? WalletRecurringPayment(name: name, amountMinor: amountMinor, currencyCode: currencyCode,
                                                              category: nil, cadence: cadence, nextDueDate: due,
                                                              anchorDay: anchorDay, anchorMonth: anchorMonth,
                                                              timeZoneIdentifier: timeZoneIdentifier, isSubscription: isSubscription)
        if storedPayment == nil { working.insert(result) }
        result.name = name
        result.amountMinor = amountMinor
        result.currencyCode = currencyCode
        result.category = storedCategory
        result.cadence = cadence
        result.nextDueDate = due
        result.anchorDay = anchorDay
        result.anchorMonth = anchorMonth
        result.timeZoneIdentifier = timeZoneIdentifier
        result.isSubscription = isSubscription
        result.occurrenceID = UUID()
        try commitRecurring(working)
        // New IDs have never been cached in the caller. Existing models must
        // not be used after success until the documented UI reload completes.
        if let payment { return payment }
        let id = result.id
        return (try? context.fetch(FetchDescriptor<WalletRecurringPayment>(predicate: #Predicate { $0.id == id })).first) ?? result
    }

    static func setRecurringPaymentActive(context: ModelContext, payment: WalletRecurringPayment, isActive: Bool) throws {
        let working = try recurringWriteContext(context)
        let stored = try currentPayment(payment, caller: context, working: working)
        guard stored.isActive != isActive else { return }
        stored.isActive = isActive
        stored.occurrenceID = UUID()
        try commitRecurring(working)
    }

    static func deleteRecurringPayment(context: ModelContext, payment: WalletRecurringPayment) throws {
        let working = try recurringWriteContext(context)
        let stored = try currentPayment(payment, caller: context, working: working)
        working.delete(stored)
        try commitRecurring(working)
    }

    @discardableResult
    static func markRecurringPaymentPaid(context: ModelContext, payment: WalletRecurringPayment,
                                         expectedOccurrence: RecurringOccurrence, paidAt: Date = Date(),
                                         category: WalletCategory? = nil) throws -> WalletTransaction {
        let working = try recurringWriteContext(context)
        let stored = try currentPayment(payment, caller: context, working: working, expectedOccurrence: expectedOccurrence)
        guard stored.isActive else { throw RecurringPaymentError.pausedPayment }
        guard WalletDateRange.contains(paidAt) else { throw WalletStoreError.invalidDate }
        try validateRecurringAmount(stored.amountMinor, currencyCode: stored.currencyCode)
        guard !stored.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw RecurringPaymentError.emptyName }
        let storedCategory: WalletCategory
        if let category {
            storedCategory = try recurringCategory(category, caller: context, working: working)
        } else {
            guard let category = stored.category else { throw WalletStoreError.invalidCategory }
            try validateStoredRecurringCategory(category)
            storedCategory = category
        }
        let next = try nextRecurringDate(stored)
        let transaction = WalletTransaction(amountMinor: stored.amountMinor, currencyCode: stored.currencyCode,
                                             date: paidAt, note: stored.name, kind: .expense)
        working.insert(transaction)
        transaction.category = storedCategory
        stored.category = storedCategory
        stored.nextDueDate = next
        stored.occurrenceID = UUID()
        try commitRecurring(working)
        let id = transaction.id
        return (try? context.fetch(FetchDescriptor<WalletTransaction>(predicate: #Predicate { $0.id == id })).first) ?? transaction
    }

    static func skipRecurringPaymentOccurrence(context: ModelContext, payment: WalletRecurringPayment,
                                               expectedOccurrence: RecurringOccurrence) throws {
        let working = try recurringWriteContext(context)
        let stored = try currentPayment(payment, caller: context, working: working, expectedOccurrence: expectedOccurrence)
        guard stored.isActive else { throw RecurringPaymentError.pausedPayment }
        stored.nextDueDate = try nextRecurringDate(stored)
        stored.occurrenceID = UUID()
        try commitRecurring(working)
    }

    private static func nextRecurringDate(_ payment: WalletRecurringPayment) throws -> Date {
        guard let cadence = RecurringCadence(rawValue: payment.cadenceRaw) else { throw RecurringPaymentError.invalidSchedule }
        return try RecurringSchedule.nextDate(after: payment.nextDueDate, cadence: cadence, anchorDay: payment.anchorDay,
                                              anchorMonth: payment.anchorMonth, timeZoneIdentifier: payment.timeZoneIdentifier)
    }

    private static func recurringWriteContext(_ caller: ModelContext) throws -> ModelContext {
        guard !caller.hasChanges else { throw RecurringPaymentError.unsavedChanges }
        caller.autosaveEnabled = false
        let working = ModelContext(caller.container)
        working.autosaveEnabled = false
        return working
    }

    private static func currentPayment(_ payment: WalletRecurringPayment, caller: ModelContext, working: ModelContext,
                                        expectedOccurrence: RecurringOccurrence? = nil) throws -> WalletRecurringPayment {
        guard payment.modelContext === caller, !payment.isDeleted else { throw RecurringPaymentError.missingPayment }
        let id = payment.id
        let descriptor = FetchDescriptor<WalletRecurringPayment>(predicate: #Predicate { $0.id == id })
        guard let stored = try working.fetch(descriptor).first else { throw RecurringPaymentError.missingPayment }
        guard stored.occurrence == payment.occurrence,
              expectedOccurrence == nil || stored.occurrence == expectedOccurrence else { throw RecurringPaymentError.staleOccurrence }
        return stored
    }

    private static func validateRecurringAmount(_ amountMinor: Int64, currencyCode: String) throws {
        guard amountMinor > 0 else { throw MoneyError.nonPositiveAmount }
        guard amountMinor <= Money.maximumAmountMinor else { throw MoneyError.amountTooLarge }
        guard WalletCurrency(rawValue: currencyCode) != nil else { throw MoneyError.unsupportedCurrency }
    }

    private static func recurringCategory(_ category: WalletCategory, caller: ModelContext, working: ModelContext) throws -> WalletCategory {
        guard category.modelContext === caller, !category.isDeleted else { throw WalletStoreError.invalidCategory }
        let id = category.id
        let descriptor = FetchDescriptor<WalletCategory>(predicate: #Predicate { $0.id == id })
        guard let stored = try working.fetch(descriptor).first else { throw WalletStoreError.invalidCategory }
        try validateStoredRecurringCategory(stored)
        return stored
    }

    private static func validateStoredRecurringCategory(_ category: WalletCategory) throws {
        guard category.kindRaw == TransactionKind.expense.rawValue else { throw WalletStoreError.categoryKindMismatch }
        guard !category.isArchived else { throw WalletStoreError.archivedCategory }
    }

    private static func commitRecurring(_ working: ModelContext) throws {
        do { try working.save() }
        catch {
            working.rollback()
            working.processPendingChanges()
            throw error
        }
    }
}

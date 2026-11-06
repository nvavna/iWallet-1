import Foundation
import SwiftData
import XCTest
@testable import WalletCore

final class RecurringPaymentsTests: XCTestCase {
    private func day(_ year: Int, _ month: Int, _ day: Int, zone: String = "UTC") throws -> Date {
        let calendar = try RecurringSchedule.calendar(timeZoneIdentifier: zone)
        return calendar.startOfDay(for: try XCTUnwrap(calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))))
    }

    func testMonthlyAnchorReturnsTo31AfterShortMonthAndCrossesYear() throws {
        var date = try day(2024, 1, 31)
        for expected in try [day(2024, 2, 29), day(2024, 3, 31), day(2024, 4, 30)] {
            date = try RecurringSchedule.nextDate(after: date, cadence: .monthly, anchorDay: 31, anchorMonth: 1, timeZoneIdentifier: "UTC")
            XCTAssertEqual(date, expected)
        }
        XCTAssertEqual(try RecurringSchedule.nextDate(after: day(2025, 12, 31), cadence: .monthly,
                                                       anchorDay: 31, anchorMonth: 12, timeZoneIdentifier: "UTC"), try day(2026, 1, 31))
    }

    func testYearlyLeapDayReturnsInNextLeapYear() throws {
        var date = try day(2024, 2, 29)
        for year in 2025...2028 {
            date = try RecurringSchedule.nextDate(after: date, cadence: .yearly, anchorDay: 29, anchorMonth: 2, timeZoneIdentifier: "UTC")
            XCTAssertEqual(date, try day(year, 2, year == 2028 ? 29 : 28))
        }
    }

    func testWeeklyUsesCalendarDaysAcrossBothDSTTransitions() throws {
        let zone = "America/New_York"
        let spring = try day(2026, 3, 1, zone: zone)
        let springNext = try RecurringSchedule.nextDate(after: spring, cadence: .weekly, anchorDay: 1, anchorMonth: 3, timeZoneIdentifier: zone)
        XCTAssertEqual(springNext, try day(2026, 3, 8, zone: zone))
        let afterSpring = try RecurringSchedule.nextDate(after: springNext, cadence: .weekly, anchorDay: 1, anchorMonth: 3, timeZoneIdentifier: zone)
        XCTAssertEqual(afterSpring, try day(2026, 3, 15, zone: zone))
        XCTAssertEqual(afterSpring.timeIntervalSince(springNext), 7 * 86_400 - 3_600)
        let fall = try day(2026, 11, 1, zone: zone)
        let afterFall = try RecurringSchedule.nextDate(after: fall, cadence: .weekly, anchorDay: 1, anchorMonth: 11, timeZoneIdentifier: zone)
        XCTAssertEqual(afterFall, try day(2026, 11, 8, zone: zone))
        XCTAssertEqual(afterFall.timeIntervalSince(fall), 7 * 86_400 + 3_600)
    }

    func testScheduleRejectsInvalidAnchorsTimeZoneDatesAndOverflow() throws {
        let due = try day(2026, 1, 31)
        for (anchor, month) in [(0, 1), (32, 1), (31, 0), (31, 13)] {
            XCTAssertThrowsError(try RecurringSchedule.validate(nextDueDate: due, cadence: .monthly,
                                                                  anchorDay: anchor, anchorMonth: month, timeZoneIdentifier: "UTC"))
        }
        XCTAssertThrowsError(try RecurringSchedule.validate(nextDueDate: due, cadence: .monthly, anchorDay: 30, anchorMonth: 1, timeZoneIdentifier: "UTC"))
        XCTAssertThrowsError(try RecurringSchedule.validate(nextDueDate: due, cadence: .yearly, anchorDay: 31, anchorMonth: 2, timeZoneIdentifier: "UTC"))
        XCTAssertThrowsError(try RecurringSchedule.validate(nextDueDate: due.addingTimeInterval(1), cadence: .monthly, anchorDay: 31, anchorMonth: 1, timeZoneIdentifier: "UTC"))
        XCTAssertThrowsError(try RecurringSchedule.normalizedDate(due, timeZoneIdentifier: "Not/A_Zone"))
        for interval in [Double.nan, .infinity, -.infinity, -62_135_596_801, 253_402_300_800] {
            XCTAssertThrowsError(try RecurringSchedule.normalizedDate(Date(timeIntervalSince1970: interval), timeZoneIdentifier: "UTC"))
        }
        XCTAssertThrowsError(try RecurringSchedule.nextDate(after: day(9999, 12, 31), cadence: .monthly,
                                                             anchorDay: 31, anchorMonth: 12, timeZoneIdentifier: "UTC"))
    }

    @MainActor
    func testPlanIsNotExpenseUntilExplicitPaymentAndDuplicateSnapshotIsRejected() async throws {
        let container = try WalletStore.makeContainer(inMemory: true)
        var context = container.mainContext
        var payment = try makePayment(context, due: day(2026, 1, 31))
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<WalletTransaction>()), 0)
        XCTAssertEqual(try Money.totalsByCurrency(context.fetch(FetchDescriptor<WalletTransaction>())), [:])
        let occurrence = payment.occurrence
        let paidAt = try day(2026, 4, 10).addingTimeInterval(123.125)
        let transaction = try WalletStore.markRecurringPaymentPaid(context: context, payment: payment, expectedOccurrence: occurrence, paidAt: paidAt)
        payment = try reload(payment, context: &context)
        XCTAssertEqual(transaction.amountMinor, 1234)
        XCTAssertEqual(transaction.currencyCode, "USD")
        XCTAssertEqual(transaction.kind, .expense)
        XCTAssertEqual(transaction.note, "Internet")
        XCTAssertEqual(transaction.date, paidAt)
        XCTAssertEqual(payment.nextDueDate, try day(2026, 2, 28), "Only one overdue occurrence is settled.")
        XCTAssertTrue(payment.isOverdue(asOf: paidAt))
        XCTAssertThrowsError(try WalletStore.markRecurringPaymentPaid(context: context, payment: payment, expectedOccurrence: occurrence)) {
            XCTAssertEqual($0 as? RecurringPaymentError, .staleOccurrence)
        }
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<WalletTransaction>()), 1)
        XCTAssertFalse(context.hasChanges)
    }

    @MainActor
    func testStaleSecondContextCannotPayOrSkipTheSameOccurrence() async throws {
        let container = try WalletStore.makeContainer(inMemory: true)
        let context = container.mainContext
        let payment = try makePayment(context, due: day(2026, 1, 31))
        let another = ModelContext(container)
        another.autosaveEnabled = false
        let cached = try XCTUnwrap(another.fetch(FetchDescriptor<WalletRecurringPayment>()).first)
        let occurrence = cached.occurrence
        _ = try WalletStore.markRecurringPaymentPaid(context: context, payment: payment, expectedOccurrence: payment.occurrence)
        XCTAssertThrowsError(try WalletStore.markRecurringPaymentPaid(context: another, payment: cached, expectedOccurrence: occurrence)) {
            XCTAssertEqual($0 as? RecurringPaymentError, .staleOccurrence)
        }
        XCTAssertThrowsError(try WalletStore.skipRecurringPaymentOccurrence(context: another, payment: cached, expectedOccurrence: occurrence))
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<WalletTransaction>()), 1)
        XCTAssertFalse(another.hasChanges)
    }

    @MainActor
    func testSkipAdvancesOnePeriodWithoutPostingAndInvalidatesConfirmation() async throws {
        let container = try WalletStore.makeContainer(inMemory: true)
        var context = container.mainContext
        var payment = try makePayment(context, due: day(2026, 1, 31))
        let occurrence = payment.occurrence
        try WalletStore.skipRecurringPaymentOccurrence(context: context, payment: payment, expectedOccurrence: occurrence)
        payment = try reload(payment, context: &context)
        XCTAssertEqual(payment.nextDueDate, try day(2026, 2, 28))
        XCTAssertNotEqual(payment.occurrenceID, occurrence.occurrenceID)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<WalletTransaction>()), 0)
        XCTAssertThrowsError(try WalletStore.skipRecurringPaymentOccurrence(context: context, payment: payment, expectedOccurrence: occurrence))
        try WalletStore.skipRecurringPaymentOccurrence(context: context, payment: payment, expectedOccurrence: payment.occurrence)
        payment = try reload(payment, context: &context)
        XCTAssertEqual(payment.nextDueDate, try day(2026, 3, 31))
    }

    @MainActor
    func testEditsPreserveAnchorAndPausePreservesDateButInvalidatesDraft() async throws {
        let container = try WalletStore.makeContainer(inMemory: true)
        var context = container.mainContext
        var payment = try makePayment(context, due: day(2026, 1, 31))
        try WalletStore.skipRecurringPaymentOccurrence(context: context, payment: payment, expectedOccurrence: payment.occurrence)
        payment = try reload(payment, context: &context)
        let beforeEdit = payment.occurrence
        let category = try XCTUnwrap(payment.category)
        _ = try WalletStore.saveRecurringPayment(context: context, payment: payment, name: " Faster internet ", amountMinor: 2345,
                                                 currencyCode: "EUR", category: category, cadence: .monthly,
                                                 nextDueDate: payment.nextDueDate, isSubscription: true, timeZoneIdentifier: "UTC")
        payment = try reload(payment, context: &context)
        XCTAssertEqual(payment.anchorDay, 31)
        XCTAssertEqual(payment.name, "Faster internet")
        XCTAssertTrue(payment.isSubscription)
        XCTAssertThrowsError(try WalletStore.markRecurringPaymentPaid(context: context, payment: payment, expectedOccurrence: beforeEdit))
        let beforePause = payment.occurrence
        try WalletStore.setRecurringPaymentActive(context: context, payment: payment, isActive: false)
        payment = try reload(payment, context: &context)
        XCTAssertFalse(payment.isOverdue(asOf: try day(2026, 4, 1)))
        XCTAssertThrowsError(try WalletStore.skipRecurringPaymentOccurrence(context: context, payment: payment, expectedOccurrence: payment.occurrence)) {
            XCTAssertEqual($0 as? RecurringPaymentError, .pausedPayment)
        }
        _ = try WalletStore.saveRecurringPayment(context: context, payment: payment, name: payment.name, amountMinor: 2345,
                                                 currencyCode: "EUR", category: XCTUnwrap(payment.category), cadence: .monthly,
                                                 nextDueDate: payment.nextDueDate, timeZoneIdentifier: "UTC")
        payment = try reload(payment, context: &context)
        XCTAssertFalse(payment.isActive, "Editing does not resume a paused plan.")
        try WalletStore.setRecurringPaymentActive(context: context, payment: payment, isActive: true)
        payment = try reload(payment, context: &context)
        XCTAssertEqual(payment.nextDueDate, try day(2026, 2, 28))
        XCTAssertThrowsError(try WalletStore.markRecurringPaymentPaid(context: context, payment: payment, expectedOccurrence: beforePause))
        _ = try WalletStore.markRecurringPaymentPaid(context: context, payment: payment, expectedOccurrence: payment.occurrence)
        payment = try reload(payment, context: &context)
        XCTAssertEqual(payment.nextDueDate, try day(2026, 3, 31))
    }

    @MainActor
    func testArchivedCategoryPreservesPlanAndActiveReplacementCommitsWithPayment() async throws {
        let container = try WalletStore.makeContainer(inMemory: true)
        var context = container.mainContext
        var payment = try makePayment(context, due: day(2026, 1, 31))
        let oldCategory = try XCTUnwrap(payment.category)
        let occurrence = payment.occurrence
        try WalletStore.archiveCategory(context: context, category: oldCategory)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<WalletRecurringPayment>()), 1)
        XCTAssertThrowsError(try WalletStore.markRecurringPaymentPaid(context: context, payment: payment, expectedOccurrence: occurrence)) {
            XCTAssertEqual($0 as? WalletStoreError, .archivedCategory)
        }
        XCTAssertEqual(payment.occurrence, occurrence)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<WalletTransaction>()), 0)
        let replacement = try WalletStore.saveCategory(context: context, name: "Bills", icon: "house", color: "colorBlue", kind: .expense)
        let transaction = try WalletStore.markRecurringPaymentPaid(context: context, payment: payment, expectedOccurrence: occurrence, category: replacement)
        payment = try reload(payment, context: &context)
        XCTAssertEqual(payment.category?.id, replacement.id)
        XCTAssertEqual(transaction.category?.id, replacement.id)
        try WalletStore.deleteRecurringPayment(context: context, payment: payment)
        context = freshContext(container)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<WalletTransaction>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<WalletRecurringPayment>()), 0)
    }

    @MainActor
    func testDeletingCategoryNullifiesPlanAndPreservesActualHistory() async throws {
        let container = try WalletStore.makeContainer(inMemory: true)
        var context = container.mainContext
        var payment = try makePayment(context, due: day(2026, 1, 31))
        _ = try WalletStore.markRecurringPaymentPaid(context: context, payment: payment, expectedOccurrence: payment.occurrence)
        payment = try reload(payment, context: &context)
        let transaction = try XCTUnwrap(context.fetch(FetchDescriptor<WalletTransaction>()).first)
        context.delete(try XCTUnwrap(payment.category))
        try context.save()
        XCTAssertNil(payment.category)
        XCTAssertNil(transaction.category)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<WalletRecurringPayment>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<WalletTransaction>()), 1)
        XCTAssertThrowsError(try WalletStore.markRecurringPaymentPaid(context: context, payment: payment, expectedOccurrence: payment.occurrence))
        let backup = try WalletBackup.decode(data: WalletBackup.snapshot(context: context).encodedData())
        let restored = try WalletStore.makeContainer(inMemory: true)
        _ = try backup.restore(into: restored.mainContext)
        XCTAssertNil(try XCTUnwrap(restored.mainContext.fetch(FetchDescriptor<WalletRecurringPayment>()).first).category)
        XCTAssertEqual(try restored.mainContext.fetchCount(FetchDescriptor<WalletTransaction>()), 1)
    }

    @MainActor
    func testValidationRejectsBadDraftWithoutMutatingPlanAndKeepsCurrenciesSeparate() async throws {
        let container = try WalletStore.makeContainer(inMemory: true)
        let context = container.mainContext
        let payment = try makePayment(context, due: day(2026, 1, 31))
        let category = try XCTUnwrap(payment.category)
        let original = payment.occurrence
        for amount in [Int64(0), -1, Money.maximumAmountMinor + 1] {
            XCTAssertThrowsError(try WalletStore.saveRecurringPayment(context: context, payment: payment, name: "Bad", amountMinor: amount,
                                                                      currencyCode: "USD", category: category, cadence: .monthly,
                                                                      nextDueDate: payment.nextDueDate, timeZoneIdentifier: "UTC"))
        }
        for (name, currency, zone) in [(" ", "USD", "UTC"), ("Bad", "???", "UTC"), ("Bad", "USD", "Not/A_Zone")] {
            XCTAssertThrowsError(try WalletStore.saveRecurringPayment(context: context, payment: payment, name: name, amountMinor: 100,
                                                                      currencyCode: currency, category: category, cadence: .monthly,
                                                                      nextDueDate: payment.nextDueDate, timeZoneIdentifier: zone))
        }
        XCTAssertThrowsError(try WalletStore.markRecurringPaymentPaid(context: context, payment: payment, expectedOccurrence: original,
                                                                      paidAt: Date(timeIntervalSince1970: .nan)))
        XCTAssertEqual(payment.occurrence, original)
        XCTAssertEqual(payment.name, "Internet")
        let income = try WalletStore.saveCategory(context: context, name: "Wage", icon: "banknote", color: "colorBlue", kind: .income)
        XCTAssertThrowsError(try WalletStore.markRecurringPaymentPaid(context: context, payment: payment, expectedOccurrence: original, category: income))
        let yen = try WalletStore.saveRecurringPayment(context: context, name: "Japanese service", amountMinor: 500,
                                                       currencyCode: "JPY", category: category, cadence: .monthly,
                                                       nextDueDate: payment.nextDueDate, timeZoneIdentifier: "UTC")
        _ = try WalletStore.markRecurringPaymentPaid(context: context, payment: payment, expectedOccurrence: payment.occurrence)
        _ = try WalletStore.markRecurringPaymentPaid(context: context, payment: yen, expectedOccurrence: yen.occurrence)
        XCTAssertEqual(try Money.totalsByCurrency(context.fetch(FetchDescriptor<WalletTransaction>())), ["USD": -1234, "JPY": -500])
    }

    @MainActor
    func testDueStatusUsesSavedTimeZoneAndDirtyContextIsNotDiscarded() async throws {
        let container = try WalletStore.makeContainer(inMemory: true)
        let context = container.mainContext
        let payment = try makePayment(context, due: day(2026, 3, 1, zone: "Asia/Tokyo"), zone: "Asia/Tokyo")
        XCTAssertTrue(payment.isDueToday(asOf: try day(2026, 2, 28).addingTimeInterval(16 * 3600)))
        XCTAssertFalse(payment.isOverdue(asOf: try day(2026, 3, 1)))
        XCTAssertTrue(payment.isOverdue(asOf: try day(2026, 3, 2)))
        let original = payment.occurrence
        context.insert(WalletCategory(name: "Unsaved", icon: "cart", color: "colorBlue", kind: .expense))
        XCTAssertThrowsError(try WalletStore.skipRecurringPaymentOccurrence(context: context, payment: payment, expectedOccurrence: original)) {
            XCTAssertEqual($0 as? RecurringPaymentError, .unsavedChanges)
        }
        XCTAssertTrue(context.hasChanges)
        XCTAssertEqual(payment.occurrence, original)
        context.rollback()
    }

    @MainActor
    func testFailedSaveRollsBackBothExpenseAndSchedule() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("readonly.store")
        let original: RecurringOccurrence = try autoreleasepool {
            let source = try diskContainer(url)
            return try makePayment(source.mainContext, due: day(2026, 1, 31)).occurrence
        }
        let readonly = try diskContainer(url, allowsSave: false)
        let context = readonly.mainContext
        let payment = try XCTUnwrap(context.fetch(FetchDescriptor<WalletRecurringPayment>()).first)
        XCTAssertThrowsError(try WalletStore.markRecurringPaymentPaid(context: context, payment: payment, expectedOccurrence: original))
        XCTAssertEqual(payment.occurrence, original)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<WalletTransaction>()), 0)
        XCTAssertFalse(context.hasChanges)
        XCTAssertThrowsError(try WalletStore.skipRecurringPaymentOccurrence(context: context, payment: payment, expectedOccurrence: original))
        XCTAssertEqual(payment.occurrence, original)
    }

    @MainActor
    func testVersionTwoBackupRoundTripReopenAndRepeatImport() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = try WalletStore.makeContainer(inMemory: true)
        var context = source.mainContext
        var payment = try makePayment(context, due: day(2024, 2, 29))
        try WalletStore.setRecurringPaymentActive(context: context, payment: payment, isActive: false)
        payment = try reload(payment, context: &context)
        try WalletStore.archiveCategory(context: context, category: XCTUnwrap(payment.category))
        var original = try WalletBackup.snapshot(context: source.mainContext)
        original.formatVersion = 2 // Exercise the original payments envelope.
        let data = try original.encodedData()
        let decoded = try WalletBackup.decode(data: data)
        XCTAssertEqual(decoded, original)
        let url = directory.appendingPathComponent("restored.store")
        try autoreleasepool {
            let destination = try diskContainer(url)
            let summary = try decoded.restore(into: destination.mainContext)
            XCTAssertEqual(summary.insertedRecurringPayments, 1)
            XCTAssertEqual(summary.insertedTransactions, 0)
            let repeated = try decoded.restore(into: destination.mainContext)
            XCTAssertEqual(repeated.insertedRecurringPayments, 0)
            XCTAssertEqual(repeated.skippedRecurringPayments, 1)
        }
        let reopened = try diskContainer(url)
        let restored = try WalletBackup.snapshot(context: reopened.mainContext)
        XCTAssertEqual(restored.recurringPayments, original.recurringPayments)
        XCTAssertEqual(restored.categories, original.categories)
    }

    @MainActor
    func testPlanBackupConflictRejectsAllAdditionsAndMalformedPlansAreRejected() async throws {
        let source = try WalletStore.makeContainer(inMemory: true)
        _ = try makePayment(source.mainContext, due: day(2026, 1, 31))
        let original = try WalletBackup.snapshot(context: source.mainContext)
        let destination = try WalletStore.makeContainer(inMemory: true)
        _ = try original.restore(into: destination.mainContext)
        var conflict = original
        conflict.recurringPayments[0].amountMinor += 1
        conflict.categories.append(.init(id: UUID(), name: "New", icon: "cart", color: "colorBlue", kind: "expense", isArchived: false))
        XCTAssertThrowsError(try conflict.restore(into: destination.mainContext)) {
            XCTAssertEqual($0 as? WalletBackupError, .conflictingRecord)
        }
        XCTAssertEqual(try destination.mainContext.fetchCount(FetchDescriptor<WalletCategory>()), 1)
        XCTAssertEqual(try WalletBackup.snapshot(context: destination.mainContext).recurringPayments, original.recurringPayments)
        let invalidMutations: [(inout WalletBackup.RecurringPaymentRecord) -> Void] = [
            { $0.name = " " }, { $0.amountMinor = 0 }, { $0.amountMinor = Money.maximumAmountMinor + 1 },
            { $0.currencyCode = "???" }, { $0.cadence = "daily" }, { $0.anchorDay = 32 },
            { $0.anchorMonth = 0 }, { $0.timeZoneIdentifier = "Invalid" }, { $0.nextDueDate = .distantFuture },
            { $0.nextDueDate.addTimeInterval(1) }, { $0.categoryID = UUID() }
        ]
        for mutation in invalidMutations {
            var invalid = original
            mutation(&invalid.recurringPayments[0])
            XCTAssertThrowsError(try invalid.validate())
        }
        var invalid = original
        invalid.recurringPayments.append(invalid.recurringPayments[0])
        XCTAssertThrowsError(try invalid.validate()) { XCTAssertEqual($0 as? WalletBackupError, .duplicateID) }
        invalid = original
        invalid.categories[0].kind = "income"
        XCTAssertThrowsError(try invalid.validate()) { XCTAssertEqual($0 as? WalletBackupError, .categoryKindMismatch) }
        invalid = original
        invalid.formatVersion = 1
        XCTAssertThrowsError(try invalid.encodedData(), "Plans cannot be silently exported in a version understood by older apps.")
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: original.encodedData()) as? [String: Any])
        json.removeValue(forKey: "recurringPayments")
        XCTAssertThrowsError(try WalletBackup.decode(data: JSONSerialization.data(withJSONObject: json)), "Version 2 requires its plans collection.")
    }

    @MainActor
    func testFailedBackupSaveDoesNotLeavePlansOrCategoriesInUIContext() async throws {
        let source = try WalletStore.makeContainer(inMemory: true)
        _ = try makePayment(source.mainContext, due: day(2026, 1, 31))
        let backup = try WalletBackup.snapshot(context: source.mainContext)
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("readonly.store")
        try autoreleasepool {
            let initial = try diskContainer(url)
            try WalletStore.seedIfNeeded(context: initial.mainContext)
        }
        let destination = try diskContainer(url, allowsSave: false)
        let count = try destination.mainContext.fetchCount(FetchDescriptor<WalletCategory>())
        XCTAssertThrowsError(try backup.restore(into: destination.mainContext))
        XCTAssertEqual(try destination.mainContext.fetchCount(FetchDescriptor<WalletCategory>()), count)
        XCTAssertEqual(try destination.mainContext.fetchCount(FetchDescriptor<WalletRecurringPayment>()), 0)
        XCTAssertFalse(destination.mainContext.hasChanges)
    }

    @MainActor
    func testVersionOneImportLeavesExistingPlansIntactAndLimitsCountPlans() async throws {
        let container = try WalletStore.makeContainer(inMemory: true)
        _ = try makePayment(container.mainContext, due: day(2026, 1, 31))
        let original = try WalletBackup.snapshot(context: container.mainContext)
        var old = original
        old.formatVersion = 1
        old.recurringPayments = []
        let data = try old.encodedData()
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertNil(json["recurringPayments"], "A version 1 file retains its original shape.")
        let decoded = try WalletBackup.decode(data: data)
        XCTAssertTrue(decoded.recurringPayments.isEmpty)
        XCTAssertEqual(try decoded.restore(into: container.mainContext).insertedRecurringPayments, 0)
        XCTAssertEqual(try WalletBackup.snapshot(context: container.mainContext).recurringPayments, original.recurringPayments)
        var oversized = original
        oversized.recurringPayments = Array(repeating: original.recurringPayments[0], count: WalletBackup.maximumRecordCount)
        XCTAssertThrowsError(try oversized.validate()) { XCTAssertEqual($0 as? WalletBackupError, .tooManyRecords) }
    }

    @MainActor
    func testPaidOccurrenceAndExpenseSurviveReopenAndCannotBeReplayed() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("paid.store")
        let oldOccurrence: RecurringOccurrence = try autoreleasepool {
            let container = try diskContainer(url)
            let payment = try makePayment(container.mainContext, due: day(2026, 1, 31))
            let expected = payment.occurrence
            _ = try WalletStore.markRecurringPaymentPaid(context: container.mainContext, payment: payment,
                                                         expectedOccurrence: expected, paidAt: day(2026, 1, 31))
            return expected
        }
        let reopened = try diskContainer(url)
        let context = reopened.mainContext
        let payment = try XCTUnwrap(context.fetch(FetchDescriptor<WalletRecurringPayment>()).first)
        XCTAssertEqual(payment.nextDueDate, try day(2026, 2, 28))
        XCTAssertThrowsError(try WalletStore.markRecurringPaymentPaid(context: context, payment: payment, expectedOccurrence: oldOccurrence)) {
            XCTAssertEqual($0 as? RecurringPaymentError, .staleOccurrence)
        }
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<WalletTransaction>()), 1)
        XCTAssertEqual(try Money.totalsByCurrency(context.fetch(FetchDescriptor<WalletTransaction>())), ["USD": -1234])
    }

    @MainActor
    func testOriginalSwiftDataSchemaUpgradesWithoutChangingHistoryOrReceipt() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("v1.store")
        let categoryID = UUID()
        let transactionID = UUID()
        let date = try day(2026, 1, 31).addingTimeInterval(123.125)
        try autoreleasepool {
            // These frozen types reproduce the pre-recurring entity names and
            // fields. This writes a real on-disk SwiftData store, not JSON.
            let schema = Schema([PreRecurringSchema.WalletCategory.self, PreRecurringSchema.WalletTransaction.self,
                                 PreRecurringSchema.WalletMigrationReceipt.self])
            let container = try ModelContainer(for: schema, configurations: [ModelConfiguration("Test", schema: schema, url: url, cloudKitDatabase: .none)])
            let context = container.mainContext
            context.autosaveEnabled = false
            let category = PreRecurringSchema.WalletCategory(id: categoryID)
            context.insert(category)
            context.insert(PreRecurringSchema.WalletTransaction(id: transactionID, date: date, category: category))
            context.insert(PreRecurringSchema.WalletMigrationReceipt(completedAt: date))
            try context.save()
        }
        let upgraded = try diskContainer(url)
        let context = upgraded.mainContext
        let category = try XCTUnwrap(context.fetch(FetchDescriptor<WalletCategory>()).first)
        let transaction = try XCTUnwrap(context.fetch(FetchDescriptor<WalletTransaction>()).first)
        XCTAssertEqual(category.id, categoryID)
        XCTAssertEqual(transaction.id, transactionID)
        XCTAssertEqual(transaction.amountMinor, 123456)
        XCTAssertEqual(transaction.currencyCode, "EUR")
        XCTAssertEqual(transaction.note, "Original history")
        XCTAssertEqual(transaction.date, date)
        XCTAssertEqual(transaction.category?.id, categoryID)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<WalletMigrationReceipt>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<WalletRecurringPayment>()), 0)
        XCTAssertTrue(category.recurringPayments.isEmpty)
        _ = try WalletStore.saveRecurringPayment(context: context, name: "After upgrade", amountMinor: 2500, currencyCode: "USD",
                                                 category: category, cadence: .monthly, nextDueDate: day(2026, 2, 28), timeZoneIdentifier: "UTC")
        XCTAssertEqual(try WalletBackup.snapshot(context: context).transactions.count, 1)
        XCTAssertEqual(try WalletBackup.snapshot(context: context).recurringPayments.count, 1)
    }

    @MainActor
    private func makePayment(_ context: ModelContext, due: Date, zone: String = "UTC") throws -> WalletRecurringPayment {
        let category = try WalletStore.saveCategory(context: context, name: "Bills", icon: "house", color: "colorBlue", kind: .expense)
        return try WalletStore.saveRecurringPayment(context: context, name: "Internet", amountMinor: 1234, currencyCode: "USD",
                                                    category: category, cadence: .monthly, nextDueDate: due,
                                                    isSubscription: true, timeZoneIdentifier: zone)
    }

    @MainActor
    private func freshContext(_ container: ModelContainer) -> ModelContext {
        let context = ModelContext(container)
        context.autosaveEnabled = false
        return context
    }

    @MainActor
    private func reload(_ payment: WalletRecurringPayment, context: inout ModelContext) throws -> WalletRecurringPayment {
        let id = payment.id
        context = freshContext(context.container)
        return try XCTUnwrap(context.fetch(FetchDescriptor<WalletRecurringPayment>(predicate: #Predicate { $0.id == id })).first)
    }

    private func temporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    @MainActor
    private func diskContainer(_ url: URL, allowsSave: Bool = true) throws -> ModelContainer {
        let schema = WalletStore.schema
        let configuration = ModelConfiguration("Test", schema: schema, url: url, allowsSave: allowsSave, cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        container.mainContext.autosaveEnabled = false
        return container
    }
}

private enum PreRecurringSchema {
    @Model final class WalletCategory {
        @Attribute(.unique) var id: UUID
        var name: String
        var icon: String
        var color: String
        var kindRaw: String
        var isArchived: Bool
        @Relationship(deleteRule: .nullify, inverse: \WalletTransaction.category)
        var transactions: [WalletTransaction] = []
        init(id: UUID) {
            self.id = id; name = "Original bills"; icon = "house"; color = "colorBlue"
            kindRaw = "expense"; isArchived = false
        }
    }
    @Model final class WalletTransaction {
        @Attribute(.unique) var id: UUID
        var amountMinor: Int64
        var currencyCode: String
        var date: Date
        var note: String
        var kindRaw: String
        var category: WalletCategory?
        init(id: UUID, date: Date, category: WalletCategory) {
            self.id = id; self.date = date; self.category = category
            amountMinor = 123456; currencyCode = "EUR"; note = "Original history"; kindRaw = "expense"
        }
    }
    @Model final class WalletMigrationReceipt {
        @Attribute(.unique) var id: String
        var sourceDigest: String
        var currencyCode: String
        var completedAt: Date
        var transactionCount: Int
        var categoryCount: Int
        init(completedAt: Date) {
            id = "realm-v1"; sourceDigest = String(repeating: "a", count: 64); currencyCode = "EUR"
            self.completedAt = completedAt; transactionCount = 1; categoryCount = 1
        }
    }
}

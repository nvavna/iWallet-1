import Foundation
import SwiftData
import XCTest
@testable import WalletCore

final class WalletBudgetTests: XCTestCase {
    private let november = BudgetMonth(year: 2026, month: 11)
    private let eastern = "America/New_York"

    @MainActor
    func testCopyPreviousMonthAcrossYearsPreservesExistingLimitsAndSkipsArchivedCategories() async throws {
        let container = try WalletStore.makeContainer(inMemory: true)
        let context = container.mainContext
        let december = BudgetMonth(year: 2026, month: 12)
        let january = BudgetMonth(year: 2027, month: 1)
        let food = try category("Food", in: context)
        let rent = try category("Rent", in: context)
        let travel = try category("Travel", in: context)
        try WalletStore.createBudget(context: context, category: food, month: december, currencyCode: "USD", limitMinor: 999)
        let yen = try WalletStore.createBudget(context: context, category: food, month: december, currencyCode: "JPY",
                                               limitMinor: 123_456, timeZoneIdentifier: "Asia/Tokyo")
        let rentLimit = try WalletStore.createBudget(context: context, category: rent, month: december, currencyCode: "USD",
                                                     limitMinor: 78_901, timeZoneIdentifier: eastern)
        try WalletStore.createBudget(context: context, category: travel, month: december, currencyCode: "EUR", limitMinor: 100)
        try WalletStore.archiveCategory(context: context, category: travel)
        let existing = try WalletStore.createBudget(context: context, category: food, month: january, currencyCode: "USD",
                                                    limitMinor: 42, timeZoneIdentifier: "UTC")
        try WalletStore.createBudget(context: context, category: food, month: november, currencyCode: "EUR", limitMinor: 790)
        let before = try WalletBackup.snapshot(context: context)

        XCTAssertEqual(try WalletStore.copyPreviousBudgets(context: context, to: january),
                       BudgetCopySummary(added: 2, existing: 1, archived: 1))
        let after = try WalletBackup.snapshot(context: context)
        let originalIDs = Set(before.budgets.map(\.id))
        XCTAssertEqual(after.budgets.filter { originalIDs.contains($0.id) }, before.budgets)
        XCTAssertEqual(after.categories, before.categories)
        let copied = after.budgets.filter { !originalIDs.contains($0.id) }
        XCTAssertEqual(copied.count, 2)
        for source in [yen, rentLimit] {
            let new = try XCTUnwrap(copied.first { $0.currencyCode == source.currencyCode && $0.categoryID == source.categoryID })
            XCTAssertEqual(BudgetMonth(year: new.year, month: new.month), january)
            XCTAssertEqual(new.limitMinor, source.limitMinor)
            XCTAssertEqual(new.timeZoneIdentifier, source.timeZoneIdentifier)
        }
        XCTAssertEqual(existing.limitMinor, 42)
        XCTAssertEqual(try WalletStore.copyPreviousBudgets(context: context, to: january),
                       BudgetCopySummary(added: 0, existing: 3, archived: 1))
        XCTAssertEqual(try WalletBackup.snapshot(context: context).budgets, after.budgets)
    }

    @MainActor
    func testCopyWithNoSourceOrInvalidMonthLeavesWalletUnchanged() async throws {
        let container = try WalletStore.makeContainer(inMemory: true)
        let context = container.mainContext
        let food = try category("Food", in: context)
        try WalletStore.createBudget(context: context, category: food, month: november, currencyCode: "USD", limitMinor: 99)
        let before = try WalletBackup.snapshot(context: context)
        XCTAssertEqual(try WalletStore.copyPreviousBudgets(context: context, to: november), BudgetCopySummary())
        for month in [BudgetMonth(year: 1, month: 1), BudgetMonth(year: 2027, month: 13)] {
            XCTAssertThrowsError(try WalletStore.copyPreviousBudgets(context: context, to: month)) {
                XCTAssertEqual($0 as? WalletBudgetError, .invalidMonth)
            }
        }
        XCTAssertEqual(try WalletBackup.snapshot(context: context).budgets, before.budgets)
    }

    @MainActor
    func testInvalidPriorLimitDoesNotLeaveAPartialCopy() async throws {
        let container = try WalletStore.makeContainer(inMemory: true)
        let context = container.mainContext
        let food = try category("Food", in: context)
        try WalletStore.createBudget(context: context, category: food, month: november, currencyCode: "USD", limitMinor: 99)
        context.insert(WalletBudget(categoryID: food.id, year: november.year, month: november.month,
                                    currencyCode: "JPY", limitMinor: -1, timeZoneIdentifier: eastern))
        try context.save()
        let december = BudgetMonth(year: 2026, month: 12)
        XCTAssertThrowsError(try WalletStore.copyPreviousBudgets(context: context, to: december)) {
            XCTAssertEqual($0 as? MoneyError, .nonPositiveAmount)
        }
        XCTAssertFalse(context.hasChanges)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<WalletBudget>()), 2)
    }

    @MainActor
    func testActualSpendingMatchesCategoryCurrencyAndCivilMonthAcrossDST() async throws {
        let container = try WalletStore.makeContainer(inMemory: true)
        let context = container.mainContext
        let food = try category("Food", in: context)
        let bills = try category("Bills", in: context)
        let budget = try WalletStore.createBudget(context: context, category: food, month: november,
                                                  currencyCode: "USD", limitMinor: 5000, timeZoneIdentifier: eastern)
        let interval = try november.interval(in: eastern)
        XCTAssertEqual(interval.start, ISO8601DateFormatter().date(from: "2026-11-01T04:00:00Z"))
        XCTAssertEqual(interval.end, ISO8601DateFormatter().date(from: "2026-12-01T05:00:00Z"))
        try add(500, to: food, at: interval.start.addingTimeInterval(-1), in: context)
        try add(2600, to: food, at: interval.start, in: context)
        try add(2800, to: food, at: interval.end.addingTimeInterval(-0.125), in: context)
        try add(999, to: food, at: interval.end, in: context)
        try add(700, to: food, at: interval.start, currency: "EUR", in: context)
        try add(400, to: bills, at: interval.start, in: context)
        try WalletStore.saveRecurringPayment(context: context, name: "Future payment", amountMinor: 5000,
                                             currencyCode: "USD", category: food, cadence: .monthly, nextDueDate: interval.start,
                                             timeZoneIdentifier: eastern)
        // A historical income with this category must not reduce actual spending.
        context.insert(WalletTransaction(amountMinor: 10000, currencyCode: "USD", date: interval.start,
                                         kind: .income, category: food))
        try context.save()
        let actual = try context.fetch(FetchDescriptor<WalletTransaction>())
        var progress = try budget.progress(transactions: actual)
        XCTAssertEqual(progress, BudgetProgress(spentMinor: 5400, remainingMinor: -400))
        try WalletStore.updateBudgetLimit(context: context, budget: budget, limitMinor: 6000)
        progress = try budget.progress(transactions: actual)
        XCTAssertEqual(progress, BudgetProgress(spentMinor: 5400, remainingMinor: 600))
    }

    @MainActor
    func testScopeUniquenessArchivingEditingDeletingLeaveHistoryUnchanged() async throws {
        let container = try WalletStore.makeContainer(inMemory: true)
        let context = container.mainContext
        let food = try category("Food", in: context)
        let spendDate = try november.interval(in: eastern).start
        try add(456, to: food, at: spendDate, in: context)
        let original = try WalletBackup.snapshot(context: context)
        let budget = try WalletStore.createBudget(context: context, category: food, month: november,
                                                  currencyCode: "USD", limitMinor: 300, timeZoneIdentifier: eastern)
        XCTAssertThrowsError(try WalletStore.createBudget(context: context, category: food, month: november,
                                                         currencyCode: "USD", limitMinor: 900, timeZoneIdentifier: "UTC")) {
            XCTAssertEqual($0 as? WalletBudgetError, .duplicateBudget)
        }
        _ = try WalletStore.createBudget(context: context, category: food, month: november, currencyCode: "JPY", limitMinor: 17)
        _ = try WalletStore.createBudget(context: context, category: food, month: .init(year: 2026, month: 12),
                                         currencyCode: "USD", limitMinor: 200)
        try WalletStore.archiveCategory(context: context, category: food)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<WalletBudget>()), 3)
        XCTAssertThrowsError(try WalletStore.createBudget(context: context, category: food, month: november,
                                                         currencyCode: "EUR", limitMinor: 350)) {
            XCTAssertEqual($0 as? WalletBudgetError, .inactiveCategory)
        }
        try WalletStore.updateBudgetLimit(context: context, budget: budget, limitMinor: 456)
        XCTAssertEqual(try budget.progress(transactions: food.transactions), BudgetProgress(spentMinor: 456, remainingMinor: 0))
        try WalletStore.deleteBudget(context: context, budget: budget)
        let exported = try WalletBackup.snapshot(context: context)
        XCTAssertEqual(exported.budgets.count, 2)
        XCTAssertEqual(exported.transactions, original.transactions)
        XCTAssertEqual(exported.categories.first?.isArchived, true)
    }

    @MainActor
    func testInvalidInputsAreRejectedWithoutPersistingLimits() async throws {
        let container = try WalletStore.makeContainer(inMemory: true)
        let context = container.mainContext
        let food = try category("Food", in: context)
        let salary = try WalletStore.saveCategory(context: context, name: "Salary", icon: "circle", color: "colorBlue", kind: .income)
        func create(_ category: WalletCategory, _ month: BudgetMonth, _ currency: String, _ limit: Int64, _ zone: String = "UTC") throws {
            try WalletStore.createBudget(context: context, category: category, month: month, currencyCode: currency,
                                         limitMinor: limit, timeZoneIdentifier: zone)
        }
        XCTAssertThrowsError(try create(salary, november, "USD", 1))
        XCTAssertThrowsError(try create(food, november, "abc", 1))
        XCTAssertThrowsError(try create(food, november, "USD", 0))
        XCTAssertThrowsError(try create(food, november, "USD", -10))
        XCTAssertThrowsError(try create(food, november, "USD", Money.maximumAmountMinor + 1))
        XCTAssertThrowsError(try create(food, november, "USD", 1, "nonesuch"))
        for (year, month) in [(0, 1), (10000, 1), (2026, 0), (2026, 13)] {
            XCTAssertThrowsError(try create(food, .init(year: year, month: month), "USD", 1))
        }
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<WalletBudget>()), 0)
    }

    @MainActor
    func testV3BackupRoundTripRepeatAndScopeConflictsAreAtomic() async throws {
        let source = try WalletStore.makeContainer(inMemory: true)
        let food = try category("Food", in: source.mainContext)
        try add(100, to: food, at: november.interval(in: eastern).start, in: source.mainContext)
        _ = try WalletStore.createBudget(context: source.mainContext, category: food, month: november,
                                         currencyCode: "USD", limitMinor: 9000, timeZoneIdentifier: eastern)
        try WalletStore.archiveCategory(context: source.mainContext, category: food)
        let original = try WalletBackup.snapshot(context: source.mainContext)
        XCTAssertEqual(original.formatVersion, 3)
        let decoded = try WalletBackup.decode(data: original.encodedData())
        XCTAssertEqual(decoded, original)
        let target = try WalletStore.makeContainer(inMemory: true)
        let context = target.mainContext
        XCTAssertEqual(try decoded.restore(into: context).insertedBudgets, 1)
        XCTAssertEqual(try decoded.restore(into: context).skippedBudgets, 1)
        for change in [0, 1] {
            var conflict = original
            conflict.categories.append(.init(id: UUID(), name: "New", icon: "cart", color: "colorBlue",
                                             kind: "expense", isArchived: false))
            if change == 0 { conflict.budgets[0].id = UUID() } else { conflict.budgets[0].limitMinor += 1 }
            XCTAssertThrowsError(try conflict.restore(into: context)) { XCTAssertEqual($0 as? WalletBackupError, .conflictingRecord) }
            let after = try WalletBackup.snapshot(context: context)
            XCTAssertEqual(after.budgets, original.budgets)
            XCTAssertEqual(after.categories, original.categories)
            XCTAssertEqual(after.transactions, original.transactions)
        }
    }

    @MainActor
    func testMalformedBudgetsAndLegacyEnvelopeCannotSmuggleScopes() async throws {
        let source = try WalletStore.makeContainer(inMemory: true)
        let food = try category("Food", in: source.mainContext)
        _ = try WalletStore.createBudget(context: source.mainContext, category: food, month: november, currencyCode: "USD", limitMinor: 1)
        let snapshot = try WalletBackup.snapshot(context: source.mainContext)
        for version in [1, 2] {
            var legacy = snapshot
            legacy.formatVersion = version
            XCTAssertThrowsError(try legacy.encodedData())
            legacy.budgets = []
            let data = try legacy.encodedData()
            var json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
            XCTAssertNil(json["budgets"])
            let file = try WalletBackup.decode(data: data)
            XCTAssertEqual(try file.restore(into: source.mainContext).insertedBudgets, 0)
            XCTAssertEqual(try WalletBackup.snapshot(context: source.mainContext).budgets, snapshot.budgets)
            json["budgets"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(snapshot.budgets))
            XCTAssertThrowsError(try WalletBackup.decode(data: JSONSerialization.data(withJSONObject: json)))
        }
        let mutations: [(inout WalletBackup.BudgetRecord) -> Void] = [
            { $0.categoryID = UUID() }, { $0.currencyCode = "???" }, { $0.year = 0 }, { $0.month = 13 },
            { $0.limitMinor = 0 }, { $0.limitMinor = Money.maximumAmountMinor + 1 }, { $0.timeZoneIdentifier = "nonesuch" }
        ]
        for mutate in mutations {
            var malformed = snapshot
            mutate(&malformed.budgets[0])
            XCTAssertThrowsError(try malformed.validate())
        }
        var malformed = snapshot
        malformed.categories[0].kind = "income"
        XCTAssertThrowsError(try malformed.validate())
        malformed = snapshot
        malformed.budgets.append(snapshot.budgets[0])
        malformed.budgets[1].id = UUID()
        XCTAssertThrowsError(try malformed.validate()) { XCTAssertEqual($0 as? WalletBackupError, .duplicateID) }
        malformed.budgets = Array(repeating: snapshot.budgets[0], count: WalletBackup.maximumRecordCount)
        XCTAssertThrowsError(try malformed.validate()) { XCTAssertEqual($0 as? WalletBackupError, .tooManyRecords) }
        var missing = try XCTUnwrap(JSONSerialization.jsonObject(with: snapshot.encodedData()) as? [String: Any])
        missing.removeValue(forKey: "budgets")
        XCTAssertThrowsError(try WalletBackup.decode(data: JSONSerialization.data(withJSONObject: missing)))
    }

    @MainActor
    func testBuildFiveDiskStoreUpgradesWithHistoryPlansAndReceipt() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("wallet.store")
        let categoryID = UUID(), transactionID = UUID(), paymentID = UUID(), occurrenceID = UUID()
        let date = try november.interval(in: eastern).start
        try autoreleasepool {
            // All four existing model definitions are unchanged from build 5.
            let schema = Schema([WalletCategory.self, WalletTransaction.self, WalletMigrationReceipt.self, WalletRecurringPayment.self])
            let container = try ModelContainer(for: schema, configurations: [ModelConfiguration("Test", schema: schema, url: url, cloudKitDatabase: .none)])
            let context = container.mainContext
            context.autosaveEnabled = false
            let category = WalletCategory(name: "Food", icon: "cart", color: "colorBlue", kind: .expense, id: categoryID)
            context.insert(category)
            context.insert(WalletTransaction(amountMinor: 57, currencyCode: "USD", date: date, note: "Old expense",
                                             kind: .expense, category: category, id: transactionID))
            context.insert(WalletRecurringPayment(name: "Monthly", amountMinor: 25, currencyCode: "USD", category: category,
                                                   cadence: .monthly, nextDueDate: date, anchorDay: 1, anchorMonth: 11,
                                                   timeZoneIdentifier: eastern, isActive: true, isSubscription: true,
                                                   id: paymentID, occurrenceID: occurrenceID))
            context.insert(WalletMigrationReceipt(sourceDigest: String(repeating: "a", count: 64), currencyCode: "USD",
                                                  completedAt: date, transactionCount: 1, categoryCount: 1))
            try context.save()
        }
        let schema = WalletStore.schema
        let config = ModelConfiguration("Test", schema: schema, url: url, cloudKitDatabase: .none)
        let budgetID = try autoreleasepool {
            let container = try ModelContainer(for: schema, configurations: [config])
            let context = container.mainContext
            XCTAssertEqual(try context.fetchCount(FetchDescriptor<WalletBudget>()), 0)
            let category = try XCTUnwrap(context.fetch(FetchDescriptor<WalletCategory>()).first)
            XCTAssertEqual(category.id, categoryID)
            return try WalletStore.createBudget(context: context, category: category, month: november, currencyCode: "USD",
                                                limitMinor: 99, timeZoneIdentifier: eastern).id
        }
        let reopened = try ModelContainer(for: schema, configurations: [config])
        let context = reopened.mainContext
        let snapshot = try WalletBackup.snapshot(context: context)
        XCTAssertEqual(snapshot.budgets.map(\.id), [budgetID])
        XCTAssertEqual(snapshot.transactions.map(\.id), [transactionID])
        XCTAssertEqual(snapshot.transactions.first?.note, "Old expense")
        XCTAssertEqual(snapshot.recurringPayments.map(\.id), [paymentID])
        XCTAssertEqual(snapshot.recurringPayments.first?.occurrenceID, occurrenceID)
        XCTAssertEqual(try context.fetch(FetchDescriptor<WalletMigrationReceipt>()).first?.sourceDigest, String(repeating: "a", count: 64))
        let budget = try XCTUnwrap(context.fetch(FetchDescriptor<WalletBudget>()).first)
        XCTAssertEqual(try budget.progress(transactions: context.fetch(FetchDescriptor<WalletTransaction>())),
                       BudgetProgress(spentMinor: 57, remainingMinor: 42))
    }

    @MainActor
    private func category(_ name: String, in context: ModelContext) throws -> WalletCategory {
        try WalletStore.saveCategory(context: context, name: name, icon: "cart", color: "colorBlue", kind: .expense)
    }

    @MainActor
    private func add(_ amount: Int64, to category: WalletCategory, at date: Date, currency: String = "USD",
                     in context: ModelContext) throws {
        try WalletStore.saveTransaction(context: context, amountMinor: amount, currencyCode: currency, date: date,
                                        note: "", kind: .expense, category: category)
    }
}

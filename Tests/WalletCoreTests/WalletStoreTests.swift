import Foundation
import SwiftData
import XCTest
@testable import WalletCore

final class WalletStoreTests: XCTestCase {
    @MainActor
    func testSeedIsIdempotentAndAutosaveIsOff() async throws {
        let container = try WalletStore.makeContainer(inMemory: true)
        let context = container.mainContext
        XCTAssertFalse(context.autosaveEnabled)
        try WalletStore.seedIfNeeded(context: context)
        let categories = try context.fetch(FetchDescriptor<WalletCategory>())
        XCTAssertFalse(categories.isEmpty)
        XCTAssertTrue(categories.contains { $0.kind == .income })
        XCTAssertTrue(categories.contains { $0.kind == .expense })
        try WalletStore.seedIfNeeded(context: context)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<WalletCategory>()), categories.count)
    }

    @MainActor
    func testTransactionCreateEditAndDelete() async throws {
        let container = try WalletStore.makeContainer(inMemory: true)
        let context = container.mainContext
        let category = try WalletStore.saveCategory(context: context, name: " Food ", icon: "cart.fill", color: "colorPurple", kind: .expense)
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        try WalletStore.saveTransaction(context: context, amountMinor: 100_000_001, currencyCode: "USD", date: date,
                                        note: " Lunch ", kind: .expense, category: category)
        let transaction = try XCTUnwrap(context.fetch(FetchDescriptor<WalletTransaction>()).first)
        let id = transaction.id
        XCTAssertEqual(category.name, "Food")
        XCTAssertEqual(transaction.note, "Lunch")
        XCTAssertEqual(transaction.category?.id, category.id)
        XCTAssertEqual(category.transactions.count, 1)
        try WalletStore.saveTransaction(context: context, transaction: transaction, amountMinor: 1250,
                                        currencyCode: "EUR", date: date, note: "Dinner", kind: .expense, category: category)
        XCTAssertEqual(transaction.id, id)
        XCTAssertEqual(transaction.amountMinor, 1250)
        XCTAssertEqual(transaction.currencyCode, "EUR")
        XCTAssertEqual(transaction.note, "Dinner")
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<WalletTransaction>()), 1)
        try WalletStore.deleteTransaction(context: context, transaction: transaction)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<WalletTransaction>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<WalletCategory>()), 1)
    }

    @MainActor
    func testRepeatPrefillsTodaysDraftAndOnlySavingCreatesASeparateTransaction() async throws {
        let container = try WalletStore.makeContainer(inMemory: true)
        let context = container.mainContext
        let wage = try WalletStore.saveCategory(context: context, name: "Зарплата", icon: "banknote",
                                                color: "colorGreen", kind: .income)
        let bonus = try WalletStore.saveCategory(context: context, name: "Премия", icon: "gift",
                                                 color: "colorBlue", kind: .income)
        let previous = Date(timeIntervalSince1970: 1_700_000_000)
        let today = Date(timeIntervalSince1970: 1_710_000_000)
        try WalletStore.saveTransaction(context: context, amountMinor: 987_654_321, currencyCode: "EUR",
                                        date: previous, note: "За февраль", kind: .income, category: wage)
        let source = try XCTUnwrap(context.fetch(FetchDescriptor<WalletTransaction>()).first)
        var draft = WalletTransactionDraft.repeating(source, on: today)
        XCTAssertEqual(draft.date, today)
        XCTAssertEqual(draft.currencyCode, "EUR")
        XCTAssertEqual(try Money.parse(draft.amountText, currencyCode: draft.currencyCode), 987_654_321)
        XCTAssertEqual(draft.kind, .income)
        XCTAssertEqual(draft.categoryID, wage.id)
        XCTAssertEqual(draft.note, "За февраль")

        draft.amountText = "42"
        draft.categoryID = bonus.id
        XCTAssertFalse(context.hasChanges)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<WalletTransaction>()), 1)
        let category = try XCTUnwrap(context.fetch(FetchDescriptor<WalletCategory>()).first { $0.id == draft.categoryID })
        try WalletStore.saveTransaction(context: context,
                                        amountMinor: Money.parse(draft.amountText, currencyCode: draft.currencyCode),
                                        currencyCode: draft.currencyCode, date: draft.date, note: draft.note,
                                        kind: draft.kind, category: category)
        let transactions = try context.fetch(FetchDescriptor<WalletTransaction>())
        XCTAssertEqual(transactions.count, 2)
        let savedCopy = try XCTUnwrap(transactions.first { $0.id != source.id })
        XCTAssertEqual(savedCopy.amountMinor, 4200)
        XCTAssertEqual(savedCopy.category?.id, bonus.id)
        XCTAssertEqual(savedCopy.date, today)
        XCTAssertEqual(savedCopy.note, "За февраль")
        XCTAssertEqual(source.category?.id, wage.id)
        XCTAssertEqual(source.amountMinor, 987_654_321)
        XCTAssertEqual(source.date, previous)
    }

    @MainActor
    func testRepeatRequiresAnActiveCategoryForArchivedAndUncategorizedHistory() async throws {
        let container = try WalletStore.makeContainer(inMemory: true)
        let context = container.mainContext
        let category = try WalletStore.saveCategory(context: context, name: "Архив", icon: "house",
                                                    color: "colorBlue", kind: .expense)
        try WalletStore.saveTransaction(context: context, amountMinor: 341, currencyCode: "JPY",
                                        date: .now, note: "履歴", kind: .expense, category: category)
        try WalletStore.archiveCategory(context: context, category: category)
        let source = try XCTUnwrap(context.fetch(FetchDescriptor<WalletTransaction>()).first)
        let archivedDraft = WalletTransactionDraft.repeating(source)
        XCTAssertNil(archivedDraft.categoryID)
        XCTAssertEqual(try Money.parse(archivedDraft.amountText, currencyCode: archivedDraft.currencyCode), 341)
        XCTAssertEqual(WalletTransactionDraft.editing(source).categoryID, category.id)
        XCTAssertEqual(source.category?.id, category.id)
        XCTAssertFalse(context.hasChanges)

        context.delete(category)
        try context.save()
        XCTAssertNil(source.category)
        let uncategorizedDraft = WalletTransactionDraft.repeating(source)
        XCTAssertNil(uncategorizedDraft.categoryID)
        XCTAssertEqual(uncategorizedDraft.note, "履歴")
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<WalletTransaction>()), 1)
    }

    @MainActor
    func testInvalidEditDoesNotMutateSavedTransaction() async throws {
        let container = try WalletStore.makeContainer(inMemory: true)
        let context = container.mainContext
        let category = try WalletStore.saveCategory(context: context, name: "Food", icon: "cart", color: "colorPurple", kind: .expense)
        try WalletStore.saveTransaction(context: context, amountMinor: 100, currencyCode: "USD", date: .now,
                                        note: "Saved", kind: .expense, category: category)
        let transaction = try XCTUnwrap(context.fetch(FetchDescriptor<WalletTransaction>()).first)
        // Editing happens in ordinary value drafts. An invalid Save must keep the stored version.
        let draftAmount: Int64 = -500
        let draftNote = "Unsaved"
        XCTAssertThrowsError(try WalletStore.saveTransaction(context: context, transaction: transaction,
                                                              amountMinor: draftAmount, currencyCode: "USD", date: .now,
                                                              note: draftNote, kind: .expense, category: category))
        XCTAssertEqual(transaction.amountMinor, 100)
        XCTAssertEqual(transaction.note, "Saved")
        XCTAssertFalse(context.hasChanges)
    }

    @MainActor
    func testDatesOutsideBackupRangeAreRejectedBeforeChangingRecords() async throws {
        let container = try WalletStore.makeContainer(inMemory: true)
        let context = container.mainContext
        let category = try WalletStore.saveCategory(context: context, name: "Food", icon: "cart", color: "colorPurple", kind: .expense)
        let originalDate = Date(timeIntervalSince1970: 1_700_000_000)
        try WalletStore.saveTransaction(context: context, amountMinor: 100, currencyCode: "USD", date: originalDate,
                                        note: "Saved", kind: .expense, category: category)
        let transaction = try XCTUnwrap(context.fetch(FetchDescriptor<WalletTransaction>()).first)
        for interval in [-62_135_596_801.0, 253_402_300_800.0, .infinity, -.infinity, .nan] {
            let date = Date(timeIntervalSince1970: interval)
            XCTAssertThrowsError(try WalletStore.saveTransaction(context: context, amountMinor: 200,
                                                                  currencyCode: "USD", date: date, note: "New",
                                                                  kind: .expense, category: category)) {
                XCTAssertEqual($0 as? WalletStoreError, .invalidDate)
            }
            XCTAssertThrowsError(try WalletStore.saveTransaction(context: context, transaction: transaction,
                                                                  amountMinor: 200, currencyCode: "USD", date: date,
                                                                  note: "Edited", kind: .expense, category: category)) {
                XCTAssertEqual($0 as? WalletStoreError, .invalidDate)
            }
            XCTAssertEqual(transaction.date, originalDate)
            XCTAssertEqual(transaction.amountMinor, 100)
            XCTAssertEqual(transaction.note, "Saved")
            XCTAssertFalse(context.hasChanges)
        }
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<WalletTransaction>()), 1)
        XCTAssertNoThrow(try WalletBackup.snapshot(context: context).encodedData())
    }

    @MainActor
    func testSupportedBoundaryDatesCanBeSavedAndBackedUp() async throws {
        let container = try WalletStore.makeContainer(inMemory: true)
        let context = container.mainContext
        let category = try WalletStore.saveCategory(context: context, name: "Food", icon: "cart", color: "colorPurple", kind: .expense)
        for interval in [-62_135_596_800.0, 253_402_300_799.0] {
            try WalletStore.saveTransaction(context: context, amountMinor: 100, currencyCode: "USD",
                                            date: Date(timeIntervalSince1970: interval), note: "Boundary",
                                            kind: .expense, category: category)
        }
        let backup = try WalletBackup.snapshot(context: context)
        XCTAssertEqual(try WalletBackup.decode(data: backup.encodedData()), backup)
    }

    @MainActor
    func testMigrationPreferencesRecoverAfterCommitAndPreserveLaterManualChoice() async throws {
        let suite = "iWallet-tests.migrationPreferences.\(UUID().uuidString)"
        let preferences = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { preferences.removePersistentDomain(forName: suite) }
        preferences.set("RUB", forKey: "preferredCurrencyCode")
        let receipt = WalletMigrationReceipt(sourceDigest: String(repeating: "a", count: 64),
                                              currencyCode: "USD", transactionCount: 1, categoryCount: 1)

        // The receipt survived the import commit, but its post-commit preferences did not.
        WalletStore.applyMigrationPreferences(receipt: receipt, preferences: preferences)
        XCTAssertEqual(preferences.string(forKey: "preferredCurrencyCode"), "USD")
        preferences.set("EUR", forKey: "preferredCurrencyCode")
        WalletStore.applyMigrationPreferences(receipt: receipt, preferences: preferences)
        XCTAssertEqual(preferences.string(forKey: "preferredCurrencyCode"), "EUR")

        // A different source receipt is not mistaken for the one already applied.
        let anotherReceipt = WalletMigrationReceipt(sourceDigest: String(repeating: "b", count: 64),
                                                     currencyCode: "JPY", transactionCount: 1, categoryCount: 1)
        WalletStore.applyMigrationPreferences(receipt: anotherReceipt, preferences: preferences)
        XCTAssertEqual(preferences.string(forKey: "preferredCurrencyCode"), "JPY")
    }

    @MainActor
    func testMigrationPreferencesReplayAfterCurrencyWasSetButMarkerWasNot() async throws {
        let suite = "iWallet-tests.migrationPreferences.\(UUID().uuidString)"
        let preferences = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { preferences.removePersistentDomain(forName: suite) }
        let receipt = WalletMigrationReceipt(sourceDigest: String(repeating: "a", count: 64),
                                              currencyCode: "USD", transactionCount: 1, categoryCount: 1)
        preferences.set(receipt.currencyCode, forKey: "preferredCurrencyCode")
        WalletStore.applyMigrationPreferences(receipt: receipt, preferences: preferences)
        XCTAssertEqual(preferences.string(forKey: "preferredCurrencyCode"), "USD")
        preferences.set("GBP", forKey: "preferredCurrencyCode")
        WalletStore.applyMigrationPreferences(receipt: receipt, preferences: preferences)
        XCTAssertEqual(preferences.string(forKey: "preferredCurrencyCode"), "GBP")
    }

    @MainActor
    func testCategoryMismatchAndUnsupportedCurrencyAreRejected() async throws {
        let container = try WalletStore.makeContainer(inMemory: true)
        let context = container.mainContext
        let category = try WalletStore.saveCategory(context: context, name: "Salary", icon: "banknote", color: "colorGreen", kind: .income)
        XCTAssertThrowsError(try WalletStore.saveTransaction(context: context, amountMinor: 100, currencyCode: "USD", date: .now,
                                                              note: "", kind: .expense, category: category))
        XCTAssertThrowsError(try WalletStore.saveTransaction(context: context, amountMinor: 100, currencyCode: "XYZ", date: .now,
                                                              note: "", kind: .income, category: category))
        XCTAssertThrowsError(try WalletStore.saveTransaction(context: context, amountMinor: 0, currencyCode: "USD", date: .now,
                                                              note: "", kind: .income, category: category))
        XCTAssertThrowsError(try WalletStore.saveTransaction(context: context, amountMinor: Money.maximumAmountMinor + 1,
                                                              currencyCode: "USD", date: .now, note: "", kind: .income, category: category))
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<WalletTransaction>()), 0)
    }

    @MainActor
    func testArchivePreservesHistoryAndPreventsNewEntries() async throws {
        let container = try WalletStore.makeContainer(inMemory: true)
        let context = container.mainContext
        let category = try WalletStore.saveCategory(context: context, name: "Food", icon: "cart", color: "colorPurple", kind: .expense)
        try WalletStore.saveTransaction(context: context, amountMinor: 100, currencyCode: "USD", date: .now,
                                        note: "Saved", kind: .expense, category: category)
        let transaction = try XCTUnwrap(context.fetch(FetchDescriptor<WalletTransaction>()).first)
        try WalletStore.archiveCategory(context: context, category: category)
        XCTAssertTrue(category.isArchived)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<WalletTransaction>()), 1)
        XCTAssertEqual(transaction.category?.id, category.id)
        XCTAssertEqual(try Money.totalsByCurrency([transaction]), ["USD": -100])
        XCTAssertThrowsError(try WalletStore.saveTransaction(context: context, amountMinor: 200, currencyCode: "USD", date: .now,
                                                              note: "New", kind: .expense, category: category))
        // Existing records can still be corrected without resurrecting the archived category.
        try WalletStore.saveTransaction(context: context, transaction: transaction, amountMinor: 150, currencyCode: "USD",
                                        date: .now, note: "Corrected", kind: .expense, category: category)
        XCTAssertEqual(transaction.amountMinor, 150)
        XCTAssertTrue(category.isArchived)
    }

    @MainActor
    func testRelationshipDoesNotCascadeDeleteFinancialHistory() async throws {
        let container = try WalletStore.makeContainer(inMemory: true)
        let context = container.mainContext
        let category = try WalletStore.saveCategory(context: context, name: "Food", icon: "cart", color: "colorPurple", kind: .expense)
        try WalletStore.saveTransaction(context: context, amountMinor: 100, currencyCode: "USD", date: .now,
                                        note: "Saved", kind: .expense, category: category)
        context.delete(category)
        try context.save()
        let transaction = try XCTUnwrap(context.fetch(FetchDescriptor<WalletTransaction>()).first)
        XCTAssertNil(transaction.category)
        XCTAssertEqual(transaction.amountMinor, 100)
    }

    @MainActor
    func testDiskPersistenceReopensWithIdentityAndExactAmount() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("test.store")
        let savedID: UUID = try autoreleasepool {
            let container = try diskContainer(at: url)
            let context = container.mainContext
            let category = try WalletStore.saveCategory(context: context, name: "Food", icon: "cart", color: "colorPurple", kind: .expense)
            try WalletStore.saveTransaction(context: context, amountMinor: 100_000_001, currencyCode: "USD", date: .now,
                                            note: "Persistent", kind: .expense, category: category)
            return try XCTUnwrap(context.fetch(FetchDescriptor<WalletTransaction>()).first).id
        }
        let reopened = try diskContainer(at: url)
        let transaction = try XCTUnwrap(reopened.mainContext.fetch(FetchDescriptor<WalletTransaction>()).first)
        XCTAssertEqual(transaction.id, savedID)
        XCTAssertEqual(transaction.amountMinor, 100_000_001)
        XCTAssertEqual(transaction.currencyCode, "USD")
        XCTAssertEqual(transaction.note, "Persistent")
        XCTAssertEqual(transaction.category?.name, "Food")
    }

    @MainActor
    func testLegacyDetectionLeavesFileContentsUnchanged() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let legacyURL = directory.appendingPathComponent("default.realm")
        let marker = Data("legacy-data-do-not-open-or-overwrite".utf8)
        try marker.write(to: legacyURL)
        XCTAssertEqual(WalletStore.legacyStoreURLs(in: [directory]), [legacyURL])
        XCTAssertEqual(try Data(contentsOf: legacyURL), marker)
        XCTAssertTrue(WalletStore.legacyStoreURLs(in: [directory.appendingPathComponent("absent")]).isEmpty)
    }

    @MainActor
    func testFailedDiskSaveRollsBackEdit() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("readonly.store")
        try autoreleasepool {
            let container = try diskContainer(at: url)
            let context = container.mainContext
            let category = try WalletStore.saveCategory(context: context, name: "Food", icon: "cart", color: "colorPurple", kind: .expense)
            try WalletStore.saveTransaction(context: context, amountMinor: 100, currencyCode: "USD", date: .now,
                                            note: "Saved", kind: .expense, category: category)
        }
        let readonly = try diskContainer(at: url, allowsSave: false)
        let context = readonly.mainContext
        let transaction = try XCTUnwrap(context.fetch(FetchDescriptor<WalletTransaction>()).first)
        let category = try XCTUnwrap(transaction.category)
        XCTAssertThrowsError(try WalletStore.saveTransaction(context: context, transaction: transaction, amountMinor: 500,
                                                              currencyCode: "USD", date: .now, note: "Unsaved",
                                                              kind: .expense, category: category))
        XCTAssertEqual(transaction.amountMinor, 100)
        XCTAssertEqual(transaction.note, "Saved")
        XCTAssertFalse(context.hasChanges)
    }

    @MainActor
    func testFailedNewTransactionDoesNotAppearInHistoryOrCategory() async throws {
        for originalCount in 0...1 {
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: directory) }
            let url = directory.appendingPathComponent("readonly-insert.store")
            try autoreleasepool {
                let source = try diskContainer(at: url)
                let category = try WalletStore.saveCategory(context: source.mainContext, name: "Food", icon: "cart", color: "colorPurple", kind: .expense)
                if originalCount > 0 {
                    try WalletStore.saveTransaction(context: source.mainContext, amountMinor: 100, currencyCode: "USD", date: .now,
                                                    note: "Previously saved", kind: .expense, category: category)
                }
            }
            let readonly = try diskContainer(at: url, allowsSave: false)
            let context = readonly.mainContext
            let category = try XCTUnwrap(context.fetch(FetchDescriptor<WalletCategory>()).first)
            let originalIDs = Set(try context.fetch(FetchDescriptor<WalletTransaction>()).map(\.id))
            XCTAssertEqual(category.transactions.count, originalCount)
            XCTAssertThrowsError(try WalletStore.saveTransaction(context: context, amountMinor: 500, currencyCode: "USD", date: .now,
                                                                  note: "Must remain unsaved", kind: .expense, category: category))
            XCTAssertEqual(Set(try context.fetch(FetchDescriptor<WalletTransaction>()).map(\.id)), originalIDs,
                           "A failed save must not leave a phantom transaction visible in the UI context.")
            XCTAssertEqual(Set(category.transactions.map(\.id)), originalIDs,
                           "The existing category must not retain the failed transaction.")
            XCTAssertFalse(context.hasChanges)
            let reopened = try diskContainer(at: url, allowsSave: false)
            XCTAssertEqual(Set(try reopened.mainContext.fetch(FetchDescriptor<WalletTransaction>()).map(\.id)), originalIDs)
        }
    }

    @MainActor
    private func diskContainer(at url: URL, allowsSave: Bool = true) throws -> ModelContainer {
        let schema = WalletStore.schema
        let configuration = ModelConfiguration("Test", schema: schema, url: url, allowsSave: allowsSave, cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        container.mainContext.autosaveEnabled = false
        return container
    }
}

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
        let schema = Schema([WalletCategory.self, WalletTransaction.self, WalletMigrationReceipt.self, WalletRecurringPayment.self])
        let configuration = ModelConfiguration("Test", schema: schema, url: url, allowsSave: allowsSave, cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        container.mainContext.autosaveEnabled = false
        return container
    }
}

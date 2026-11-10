import Foundation
import SwiftData
import XCTest
@testable import WalletCore

final class WalletBackupTests: XCTestCase {
    private func fixture() -> WalletBackup {
        let category = WalletBackup.CategoryRecord(id: UUID(), name: "Food", icon: "cart.fill", color: "colorPurple", kind: "expense", isArchived: true)
        let date = Date(timeIntervalSince1970: 1_700_000_000.123456)
        return WalletBackup(createdAt: date, categories: [category], transactions: [
            .init(id: UUID(), amountMinor: 100_000_001, currencyCode: "USD", date: date, note: "Точная сумма", kind: "expense", categoryID: category.id),
            .init(id: UUID(), amountMinor: 500, currencyCode: "JPY", date: date.addingTimeInterval(0.000001), note: "No category", kind: "income", categoryID: nil)
        ])
    }

    func testEncodingPreservesAllFieldsAndFractionalDates() throws {
        let backup = fixture()
        let data = try backup.encodedData()
        XCTAssertEqual(try WalletBackup.decode(data: data), backup)
        XCTAssertTrue(String(decoding: data, as: UTF8.self).contains("formatVersion"))
    }

    @MainActor
    func testLongSavedTextExportsAndRestoresWithoutTruncation() async throws {
        let source = try WalletStore.makeContainer(inMemory: true)
        let name = String(repeating: "Длинное название ", count: 40).trimmingCharacters(in: .whitespaces)
        let icon = String(repeating: "i", count: 129)
        let color = String(repeating: "c", count: 129)
        let note = String(repeating: "Точная запись. ", count: 1_000).trimmingCharacters(in: .whitespaces)
        let category = try WalletStore.saveCategory(context: source.mainContext, name: name,
                                                     icon: icon, color: color, kind: .expense)
        try WalletStore.saveTransaction(context: source.mainContext, amountMinor: 12345, currencyCode: "RUB",
                                        date: Date(timeIntervalSince1970: 1_700_000_000.123456),
                                        note: note, kind: .expense, category: category)
        let original = try WalletBackup.snapshot(context: source.mainContext)
        let decoded = try WalletBackup.decode(data: original.encodedData())
        let destination = try WalletStore.makeContainer(inMemory: true)
        _ = try decoded.restore(into: destination.mainContext)
        let restored = try WalletBackup.snapshot(context: destination.mainContext)
        XCTAssertEqual(restored.categories, original.categories)
        XCTAssertEqual(restored.transactions, original.transactions)
        XCTAssertEqual(restored.categories.first?.name, name)
        XCTAssertEqual(restored.categories.first?.icon, icon)
        XCTAssertEqual(restored.categories.first?.color, color)
        XCTAssertEqual(restored.transactions.first?.note, note)
    }

    func testDecodesOriginalVersionOneExportWithWholeSecondISO8601Dates() throws {
        var backup = fixture()
        backup.formatVersion = 1
        backup.createdAt = Date(timeIntervalSince1970: 1_700_000_000)
        backup.transactions = backup.transactions.map { record in
            var record = record
            record.date = backup.createdAt
            return record
        }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        XCTAssertEqual(try WalletBackup.decode(data: encoder.encode(backup)), backup)
    }

    func testRejectsNewerVersionBeforeReadingRecords() {
        XCTAssertThrowsError(try WalletBackup.decode(data: Data("{\"formatVersion\":4}".utf8))) {
            XCTAssertEqual($0 as? WalletBackupError, .unsupportedVersion)
        }
    }

    func testRejectsImpossibleDatesAndTrailingDateText() throws {
        for date in ["2023-02-30T12:00:00Z", "2023-01-01T12:00:00Zjunk", "2023-01-01T12:00:00.5Zjunk", "not-a-date"] {
            var json = try XCTUnwrap(JSONSerialization.jsonObject(with: fixture().encodedData()) as? [String: Any])
            json["createdAt"] = date
            XCTAssertThrowsError(try WalletBackup.decode(data: JSONSerialization.data(withJSONObject: json)), date)
        }
    }

    func testRejectsMalformedRecordValuesAndReferences() throws {
        var bad = fixture()
        bad.categories[0].kind = "Expense"
        XCTAssertThrowsError(try bad.validate())
        bad = fixture()
        bad.transactions[0].kind = "refund"
        XCTAssertThrowsError(try bad.validate())
        for amount: Int64 in [0, -1, Money.maximumAmountMinor + 1] {
            bad = fixture()
            bad.transactions[0].amountMinor = amount
            XCTAssertThrowsError(try bad.validate())
        }
        bad = fixture()
        bad.transactions[0].currencyCode = "???"
        XCTAssertThrowsError(try bad.validate())
        bad = fixture()
        bad.transactions[0].categoryID = UUID()
        XCTAssertThrowsError(try bad.validate()) { XCTAssertEqual($0 as? WalletBackupError, .missingCategory) }
        bad = fixture()
        bad.transactions[0].kind = "income"
        XCTAssertThrowsError(try bad.validate()) { XCTAssertEqual($0 as? WalletBackupError, .categoryKindMismatch) }
        bad = fixture()
        bad.transactions.append(bad.transactions[0])
        XCTAssertThrowsError(try bad.validate()) { XCTAssertEqual($0 as? WalletBackupError, .duplicateID) }
        bad = fixture()
        bad.categories.append(bad.categories[0])
        XCTAssertThrowsError(try bad.validate()) { XCTAssertEqual($0 as? WalletBackupError, .duplicateID) }
        XCTAssertThrowsError(try WalletBackup.decode(data: Data("not json".utf8)))
    }

    func testRejectsOversizedFilesAndRecordCollections() {
        XCTAssertThrowsError(try WalletBackup.decode(data: Data(repeating: 32, count: WalletBackup.maximumFileSize + 1))) {
            XCTAssertEqual($0 as? WalletBackupError, .fileTooLarge)
        }
        var backup = fixture()
        backup.categories = Array(repeating: backup.categories[0], count: WalletBackup.maximumRecordCount + 1)
        XCTAssertThrowsError(try backup.validate()) { XCTAssertEqual($0 as? WalletBackupError, .tooManyRecords) }
    }

    @MainActor
    func testRestoreIsIdempotentAndPreservesCurrenciesAndMissingCategory() async throws {
        let container = try WalletStore.makeContainer(inMemory: true)
        let context = container.mainContext
        let backup = try WalletBackup.decode(data: fixture().encodedData())
        XCTAssertEqual(try backup.restore(into: context), .init(insertedCategories: 1, insertedTransactions: 2, skippedCategories: 0, skippedTransactions: 0))
        XCTAssertEqual(try backup.restore(into: context), .init(insertedCategories: 0, insertedTransactions: 0, skippedCategories: 1, skippedTransactions: 2))
        let transactions = try context.fetch(FetchDescriptor<WalletTransaction>())
        XCTAssertEqual(try Money.totalsByCurrency(transactions), ["USD": -100_000_001, "JPY": 500])
        XCTAssertEqual(transactions.filter { $0.category == nil }.count, 1)
        XCTAssertTrue(try XCTUnwrap(context.fetch(FetchDescriptor<WalletCategory>()).first).isArchived)
        XCTAssertFalse(context.hasChanges)
        XCTAssertFalse(context.autosaveEnabled)
    }

    @MainActor
    func testSnapshotExportReimportIntoSameStoreDoesNotConflict() async throws {
        let container = try WalletStore.makeContainer(inMemory: true)
        let context = container.mainContext
        _ = try fixture().restore(into: context)
        let backup = try WalletBackup.snapshot(context: context)
        let decoded = try WalletBackup.decode(data: backup.encodedData())
        XCTAssertEqual(try decoded.restore(into: context).insertedTransactions, 0)
    }

    @MainActor
    func testConflictingTransactionRejectsAllNewRecordsBeforeMutation() async throws {
        let container = try WalletStore.makeContainer(inMemory: true)
        let context = container.mainContext
        let original = fixture()
        _ = try original.restore(into: context)
        var conflicting = original
        conflicting.transactions[0].note = "Would overwrite"
        let additions = fixture()
        conflicting.categories += additions.categories
        conflicting.transactions += additions.transactions
        XCTAssertThrowsError(try conflicting.restore(into: context)) { XCTAssertEqual($0 as? WalletBackupError, .conflictingRecord) }
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<WalletCategory>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<WalletTransaction>()), 2)
        XCTAssertFalse(context.hasChanges)
        let saved = try WalletBackup.snapshot(context: context)
        XCTAssertEqual(Set(saved.transactions.map(\.note)), Set(original.transactions.map(\.note)))
    }

    @MainActor
    func testConflictingCategoryAndInvalidBackupLeaveStoreUnchanged() async throws {
        let container = try WalletStore.makeContainer(inMemory: true)
        let context = container.mainContext
        let original = fixture()
        _ = try original.restore(into: context)
        var bad = original
        bad.categories[0].isArchived = false
        XCTAssertThrowsError(try bad.restore(into: context)) { XCTAssertEqual($0 as? WalletBackupError, .conflictingRecord) }
        bad = original
        bad.transactions[0].amountMinor = -5
        XCTAssertThrowsError(try bad.restore(into: context))
        XCTAssertTrue(try XCTUnwrap(context.fetch(FetchDescriptor<WalletCategory>()).first).isArchived)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<WalletTransaction>()), 2)
        XCTAssertFalse(context.hasChanges)
    }

    @MainActor
    func testPendingUserChangesAreNeitherSavedNorDiscarded() async throws {
        let container = try WalletStore.makeContainer(inMemory: true)
        let context = container.mainContext
        context.insert(WalletCategory(name: "Draft", icon: "cart", color: "colorPurple", kind: .expense))
        XCTAssertThrowsError(try fixture().restore(into: context)) { XCTAssertEqual($0 as? WalletBackupError, .unsavedChanges) }
        XCTAssertThrowsError(try WalletBackup.snapshot(context: context))
        XCTAssertTrue(context.hasChanges)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<WalletTransaction>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<WalletCategory>()), 1)
    }

    @MainActor
    func testDiskExportImportReopensWithSameIdentityAndValues() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let original = fixture()
        let data: Data = try autoreleasepool {
            let source = try diskContainer(at: directory.appendingPathComponent("source.store"))
            _ = try original.restore(into: source.mainContext)
            return try WalletBackup.snapshot(context: source.mainContext).encodedData()
        }
        let backupURL = directory.appendingPathComponent("backup.json")
        try data.write(to: backupURL)
        try autoreleasepool {
            let destination = try diskContainer(at: directory.appendingPathComponent("restored.store"))
            let decoded = try WalletBackup.decode(data: Data(contentsOf: backupURL))
            _ = try decoded.restore(into: destination.mainContext)
        }
        let reopened = try diskContainer(at: directory.appendingPathComponent("restored.store"))
        let restored = try WalletBackup.snapshot(context: reopened.mainContext)
        XCTAssertEqual(restored.categories, original.categories)
        XCTAssertEqual(restored.transactions.sorted { $0.id.uuidString < $1.id.uuidString }, original.transactions.sorted { $0.id.uuidString < $1.id.uuidString })
    }

    @MainActor
    func testMigrationReceiptCommitsWithRecordsAndConflictingReceiptRejects() async throws {
        let container = try WalletStore.makeContainer(inMemory: true)
        let context = container.mainContext
        var backup = fixture()
        backup.transactions = backup.transactions.filter { $0.currencyCode == "USD" }
        let receipt = migrationReceipt(for: backup)
        _ = try backup.restore(into: context, migrationReceipt: receipt)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<WalletMigrationReceipt>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<WalletTransaction>()), 1)
        let matchingReceipt = migrationReceipt(for: backup)
        XCTAssertEqual(try backup.restore(into: context, migrationReceipt: matchingReceipt).insertedTransactions, 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<WalletMigrationReceipt>()), 1)
        let conflict = migrationReceipt(for: backup)
        conflict.sourceDigest = String(repeating: "b", count: 64)
        XCTAssertThrowsError(try backup.restore(into: context, migrationReceipt: conflict)) { XCTAssertEqual($0 as? WalletBackupError, .conflictingRecord) }
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<WalletMigrationReceipt>()), 1)
    }

    @MainActor
    func testSaveFailureRollsBackImportedRecordsAndMigrationReceipt() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("readonly.store")
        try autoreleasepool {
            let container = try diskContainer(at: url)
            try WalletStore.seedIfNeeded(context: container.mainContext)
        }
        let readonly = try diskContainer(at: url, allowsSave: false)
        let context = readonly.mainContext
        let existingCategoryCount = try context.fetchCount(FetchDescriptor<WalletCategory>())
        var backup = fixture()
        backup.transactions = backup.transactions.filter { $0.currencyCode == "USD" }
        XCTAssertThrowsError(try backup.restore(into: context, migrationReceipt: migrationReceipt(for: backup)))
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<WalletCategory>()), existingCategoryCount)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<WalletTransaction>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<WalletMigrationReceipt>()), 0)
        XCTAssertFalse(context.hasChanges)
    }

    @MainActor
    func testMigrationReceiptSurvivesReopenAndLaterTransactionEdits() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("migrated.store")
        var backup = fixture()
        backup.transactions = backup.transactions.filter { $0.currencyCode == "USD" }
        try autoreleasepool {
            let container = try diskContainer(at: url)
            let context = container.mainContext
            _ = try backup.restore(into: context, migrationReceipt: migrationReceipt(for: backup))
            let transaction = try XCTUnwrap(context.fetch(FetchDescriptor<WalletTransaction>()).first)
            let category = try XCTUnwrap(transaction.category)
            try WalletStore.saveTransaction(context: context, transaction: transaction, amountMinor: 250,
                                            currencyCode: "USD", date: transaction.date, note: "Edited after import",
                                            kind: .expense, category: category)
        }
        let reopened = try diskContainer(at: url)
        let receipt = try XCTUnwrap(reopened.mainContext.fetch(FetchDescriptor<WalletMigrationReceipt>()).first)
        XCTAssertEqual(receipt.id, "realm-v1")
        XCTAssertEqual(receipt.sourceDigest, String(repeating: "a", count: 64))
        XCTAssertEqual(receipt.transactionCount, 1)
        XCTAssertEqual(receipt.categoryCount, 1)
        let transaction = try XCTUnwrap(reopened.mainContext.fetch(FetchDescriptor<WalletTransaction>()).first)
        XCTAssertEqual(transaction.amountMinor, 250)
        XCTAssertEqual(transaction.note, "Edited after import")
    }

    @MainActor
    private func migrationReceipt(for backup: WalletBackup) -> WalletMigrationReceipt {
        WalletMigrationReceipt(sourceDigest: String(repeating: "a", count: 64), currencyCode: "USD",
                               transactionCount: backup.transactions.count, categoryCount: backup.categories.count)
    }

    private func temporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
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

import Foundation
import SwiftData
import XCTest
import RealmSwift
@testable import WalletCore

/// Generated schema fixtures exercise failures; the checked-in synthetic fixture
/// additionally exercises the original Realm 10.40.0 / Core 13.13.0 file format.
final class LegacyWalletMigrationTests: XCTestCase {
    func testStableIDsAreTypedRepeatableAndCaseInsensitive() throws {
        let id = try LegacyWalletMigration.stableID(for: .category, objectID: "64a000000000000000000001")
        XCTAssertEqual(id.uuidString, "BA16E725-F365-863D-B227-661F312BF88F")
        XCTAssertEqual(id, try LegacyWalletMigration.stableID(for: .category, objectID: "64A000000000000000000001"))
        XCTAssertNotEqual(id, try LegacyWalletMigration.stableID(for: .transaction, objectID: "64a000000000000000000001"))
        XCTAssertThrowsError(try LegacyWalletMigration.stableID(for: .category, objectID: "invalid"))
    }

    func testAmbiguousCurrencySymbolsRemainAmbiguous() {
        XCTAssertEqual(LegacyWalletMigration.currencyCandidates(for: "$"), [.usd, .aud, .cad, .mxn])
        XCTAssertEqual(LegacyWalletMigration.currencyCandidates(for: "¥"), [.jpy, .cny])
        XCTAssertEqual(LegacyWalletMigration.currencyCandidates(for: "£"), [.gbp, .egp])
        XCTAssertEqual(LegacyWalletMigration.currencyCandidates(for: "RUB"), [.rub])
        XCTAssertEqual(LegacyWalletMigration.currencyCandidates(for: "₽"), [.rub])
        XCTAssertEqual(LegacyWalletMigration.currencyCandidates(for: nil), [])
        XCTAssertEqual(LegacyWalletMigration.currencyCandidates(for: "unknown"), [])
    }

    func testFloatConversionUsesDecimalRoundingAndCurrencyScale() throws {
        let cents = try LegacyWalletMigration.convertAmount(12.34, currencyCode: "USD")
        XCTAssertEqual(cents.amountMinor, 1234)
        XCTAssertFalse(cents.wasRounded)
        let rounded = try LegacyWalletMigration.convertAmount(12.345, currencyCode: "USD")
        XCTAssertEqual(rounded.amountMinor, 1235)
        XCTAssertTrue(rounded.wasRounded)
        XCTAssertEqual(try LegacyWalletMigration.convertAmount(12.5, currencyCode: "JPY").amountMinor, 13)
        XCTAssertEqual(try LegacyWalletMigration.convertAmount(0.01, currencyCode: "USD").amountMinor, 1)
        // A value already rounded by Float is not invented back into 16,777,217.
        XCTAssertEqual(try LegacyWalletMigration.convertAmount(Float(16_777_217), currencyCode: "JPY").amountMinor, 16_777_216)
    }

    func testInvalidAndUnrepresentableAmountsAreRejected() {
        for amount: Float in [0, -1, .nan, .infinity, -.infinity, .greatestFiniteMagnitude] {
            XCTAssertThrowsError(try LegacyWalletMigration.convertAmount(amount, currencyCode: "USD"))
        }
        XCTAssertThrowsError(try LegacyWalletMigration.convertAmount(0.01, currencyCode: "JPY"))
        XCTAssertThrowsError(try LegacyWalletMigration.convertAmount(1, currencyCode: "$"))
    }

    func testSchema15ConversionPreservesFieldsAndSourceBytes() throws {
        try withFixture { source, backups in
            let temporary = backups.deletingLastPathComponent().appendingPathComponent("temporary")
            let original = try Data(contentsOf: source)
            let originalDate = try source.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
            let preview = try LegacyWalletMigration.prepare(from: source, currencyCode: "RUB", backupDirectory: backups,
                                                           temporaryDirectory: temporary)
            XCTAssertEqual(preview.sourceSchemaVersion, 15)
            XCTAssertEqual(preview.backup.categories.count, 1)
            XCTAssertEqual(preview.backup.transactions.count, 1)
            let category = try XCTUnwrap(preview.backup.categories.first)
            let transaction = try XCTUnwrap(preview.backup.transactions.first)
            XCTAssertEqual(category.name, "Продукты")
            XCTAssertEqual(category.icon, "cart.fill")
            XCTAssertEqual(category.color, "colorPurple")
            XCTAssertEqual(category.kind, "expense")
            XCTAssertEqual(transaction.categoryID, category.id)
            XCTAssertEqual(transaction.amountMinor, 1234)
            XCTAssertEqual(transaction.currencyCode, "RUB")
            XCTAssertEqual(transaction.note, "Milk / молоко")
            XCTAssertEqual(transaction.date, Date(timeIntervalSince1970: 1_700_000_000.125))
            XCTAssertEqual(try Data(contentsOf: source), original)
            XCTAssertEqual(try Data(contentsOf: preview.snapshotURL), original)
            XCTAssertEqual(try source.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate, originalDate)
            XCTAssertEqual(try LegacyWalletMigration.sourceDigest(at: source), preview.sourceDigest)
            XCTAssertTrue(FileManager.default.fileExists(atPath: preview.reportURL.path))
            XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: temporary.path), [])
            try preview.backup.validate()
        }
    }

    func testRepeatedPreparationHasIdenticalIdentitiesAndValues() throws {
        try withFixture { source, backups in
            let first = try LegacyWalletMigration.prepare(from: source, currencyCode: "USD", backupDirectory: backups)
            let firstReport = try Data(contentsOf: first.reportURL)
            let second = try LegacyWalletMigration.prepare(from: source, currencyCode: "USD", backupDirectory: backups)
            let third = try LegacyWalletMigration.prepare(from: source, currencyCode: "EUR", backupDirectory: backups)
            XCTAssertEqual(first.sourceDigest, second.sourceDigest)
            XCTAssertEqual(first.backup.categories, second.backup.categories)
            XCTAssertEqual(first.backup.transactions, second.backup.transactions)
            XCTAssertEqual(first.snapshotURL, second.snapshotURL)
            XCTAssertEqual(first.snapshotURL, third.snapshotURL)
            XCTAssertEqual(first.snapshotURL.deletingLastPathComponent().lastPathComponent, first.sourceDigest)
            XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: backups.path), [first.sourceDigest])
            XCTAssertNotEqual(first.reportURL, second.reportURL)
            XCTAssertNotEqual(first.reportURL, third.reportURL)
            XCTAssertEqual(try Data(contentsOf: first.reportURL), firstReport)
            XCTAssertEqual(third.backup.transactions.first?.currencyCode, "EUR")
        }
    }

    func testPartialSnapshotCopyFailureRemovesUnpublishedStaging() throws {
        try withFixture { source, backups in
            let temporary = backups.deletingLastPathComponent().appendingPathComponent("temporary")
            let original = try Data(contentsOf: source)
            let manager = PartialCopyFileManager(failingCopy: 1)
            XCTAssertThrowsError(try LegacyWalletMigration.prepare(from: source, currencyCode: "USD",
                backupDirectory: backups, temporaryDirectory: temporary, fileManager: manager)) {
                XCTAssertEqual(($0 as NSError).code, CocoaError.fileWriteOutOfSpace.rawValue)
            }
            XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: backups.path), [])
            XCTAssertFalse(FileManager.default.fileExists(atPath: temporary.path))
            XCTAssertEqual(try Data(contentsOf: source), original)
            // A clean retry can publish a verified snapshot, not a partial file.
            let preview = try LegacyWalletMigration.prepare(from: source, currencyCode: "USD",
                backupDirectory: backups, temporaryDirectory: temporary)
            XCTAssertEqual(try Data(contentsOf: preview.snapshotURL), original)
        }
    }

    func testPartialWorkingCopyFailureKeepsSnapshotAndCleansTemporaryFiles() throws {
        try withFixture { source, backups in
            let temporary = backups.deletingLastPathComponent().appendingPathComponent("temporary")
            let original = try Data(contentsOf: source)
            let digest = try LegacyWalletMigration.sourceDigest(at: source)
            let manager = PartialCopyFileManager(failingCopy: 2)
            XCTAssertThrowsError(try LegacyWalletMigration.prepare(from: source, currencyCode: "USD",
                backupDirectory: backups, temporaryDirectory: temporary, fileManager: manager)) {
                XCTAssertEqual(($0 as NSError).code, CocoaError.fileWriteOutOfSpace.rawValue)
            }
            XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: temporary.path), [])
            XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: backups.path), [digest])
            let snapshot = backups.appendingPathComponent(digest).appendingPathComponent("default.realm")
            XCTAssertEqual(try Data(contentsOf: snapshot), original)
            XCTAssertEqual(try Data(contentsOf: source), original)
            let retry = try LegacyWalletMigration.prepare(from: source, currencyCode: "USD",
                backupDirectory: backups, temporaryDirectory: temporary)
            XCTAssertEqual(retry.snapshotURL, snapshot)
            XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: temporary.path), [])
        }
    }

    func testCorruptCachedSnapshotIsRejectedWithoutOverwritingIt() throws {
        try withFixture { source, backups in
            let temporary = backups.deletingLastPathComponent().appendingPathComponent("temporary")
            let original = try Data(contentsOf: source)
            let first = try LegacyWalletMigration.prepare(from: source, currencyCode: "USD",
                backupDirectory: backups, temporaryDirectory: temporary)
            let corrupted = Data("synthetic snapshot corruption".utf8)
            try corrupted.write(to: first.snapshotURL)
            XCTAssertThrowsError(try LegacyWalletMigration.prepare(from: source, currencyCode: "USD",
                backupDirectory: backups, temporaryDirectory: temporary)) {
                XCTAssertEqual($0 as? LegacyWalletMigrationError, .snapshotMismatch)
            }
            XCTAssertEqual(try Data(contentsOf: first.snapshotURL), corrupted)
            XCTAssertEqual(try Data(contentsOf: source), original)
            XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: backups.path), [first.sourceDigest])
            XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: temporary.path), [])
        }
    }

    func testMalformedRealmRemovesWorkingFilesAndReusesRetainedBytes() throws {
        try withFixture { source, backups in
            let malformed = Data("not a Realm database".utf8)
            try malformed.write(to: source)
            let temporary = backups.deletingLastPathComponent().appendingPathComponent("temporary")
            let digest = try LegacyWalletMigration.sourceDigest(at: source)
            for _ in 0..<2 {
                XCTAssertThrowsError(try LegacyWalletMigration.prepare(from: source, currencyCode: "USD",
                    backupDirectory: backups, temporaryDirectory: temporary))
                XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: temporary.path), [])
                XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: backups.path), [digest])
            }
            XCTAssertEqual(try Data(contentsOf: source), malformed)
            XCTAssertEqual(try Data(contentsOf: backups.appendingPathComponent(digest).appendingPathComponent("default.realm")), malformed)
        }
    }

    @MainActor
    func testOriginalRealm1040FixtureTransfersIntoSwiftDataWithoutChangingSource() async throws {
        let fixture = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Fixtures/iwallet-schema15-realm-10.40.0.realm")
        let fixtureBytes = try Data(contentsOf: fixture)
        XCTAssertEqual(try LegacyWalletMigration.sourceDigest(at: fixture),
                       "b427523b505ddf61179a6b4af00870756efbcc1cd1bdbf3eef059f2ecad19bdd")
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("iWallet-original-fixture-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = directory.appendingPathComponent("default.realm")
        try FileManager.default.copyItem(at: fixture, to: source)
        let preview = try LegacyWalletMigration.prepare(from: source, currencyCode: "RUB",
            backupDirectory: directory.appendingPathComponent("backups"), temporaryDirectory: directory.appendingPathComponent("temporary"))
        XCTAssertEqual(preview.backup.categories.count, 2)
        XCTAssertEqual(preview.backup.transactions.count, 4)
        XCTAssertEqual(preview.amountAdjustments.count, 1)
        let expected: [(String, Int64, TimeInterval, String, String)] = [
            ("64a000000000000000000002", 1234, 1_700_000_000.125, "Milk / молоко", "expense"),
            ("64a000000000000000000005", 1, 1_700_000_001.5, "Smallest cent", "expense"),
            ("64a000000000000000000006", 1235, 1_700_000_002.75, "Explicit rounding case", "expense"),
            ("64a000000000000000000004", 12345, 1_700_000_003.875, "Synthetic income", "income")
        ]
        for (legacyID, minor, time, note, kind) in expected {
            let id = try LegacyWalletMigration.stableID(for: .transaction, objectID: legacyID)
            let transaction = try XCTUnwrap(preview.backup.transactions.first { $0.id == id })
            XCTAssertEqual(transaction.amountMinor, minor)
            XCTAssertEqual(transaction.date, Date(timeIntervalSince1970: time))
            XCTAssertEqual(transaction.note, note)
            XCTAssertEqual(transaction.kind, kind)
            XCTAssertEqual(transaction.currencyCode, "RUB")
            let categoryID = kind == "expense" ? "64a000000000000000000001" : "64a000000000000000000003"
            XCTAssertEqual(transaction.categoryID, try LegacyWalletMigration.stableID(for: .category, objectID: categoryID))
        }
        let container = try WalletStore.makeContainer(inMemory: true)
        let receipt = WalletMigrationReceipt(sourceDigest: preview.sourceDigest, currencyCode: "RUB", transactionCount: 4, categoryCount: 2)
        let summary = try preview.backup.restore(into: container.mainContext, migrationReceipt: receipt)
        XCTAssertEqual(summary.insertedCategories, 2)
        XCTAssertEqual(summary.insertedTransactions, 4)
        XCTAssertEqual(try container.mainContext.fetchCount(FetchDescriptor<WalletMigrationReceipt>()), 1)
        XCTAssertEqual(try container.mainContext.fetchCount(FetchDescriptor<WalletTransaction>()), 4)
        XCTAssertEqual(try Data(contentsOf: source), fixtureBytes)
        XCTAssertEqual(try Data(contentsOf: fixture), fixtureBytes)
        XCTAssertEqual(try Data(contentsOf: preview.snapshotURL), fixtureBytes)
    }

    func testRoundingIsReportedWithOriginalFloatBits() throws {
        try withFixture(amount: 12.345) { source, backups in
            let preview = try LegacyWalletMigration.prepare(from: source, currencyCode: "USD", backupDirectory: backups)
            let adjustment = try XCTUnwrap(preview.amountAdjustments.first)
            XCTAssertEqual(adjustment.originalTransactionID, "64a000000000000000000002")
            XCTAssertEqual(adjustment.originalFloatBits, Float(12.345).bitPattern)
            XCTAssertEqual(adjustment.originalDecimal, "12.345")
            XCTAssertEqual(adjustment.amountMinor, 1235)
        }
    }

    func testEarlierAndUnknownSchemasAreRejectedWithoutChangingSource() throws {
        for version: UInt64 in [14, 16] {
            try withFixture(schemaVersion: version) { source, backups in
                let original = try Data(contentsOf: source)
                XCTAssertThrowsError(try LegacyWalletMigration.prepare(from: source, currencyCode: "USD", backupDirectory: backups)) {
                    XCTAssertEqual($0 as? LegacyWalletMigrationError, .unsupportedSchema(version))
                }
                XCTAssertEqual(try Data(contentsOf: source), original)
            }
        }
    }

    func testOrphansAndConflictingLinksStopWithoutLosingSource() throws {
        for relationship in [FixtureRelationship.orphan, .wrongCategoryID, .multipleParents, .wrongKind] {
            try withFixture(relationship: relationship) { source, backups in
                let original = try Data(contentsOf: source)
                XCTAssertThrowsError(try LegacyWalletMigration.prepare(from: source, currencyCode: "USD", backupDirectory: backups)) {
                    XCTAssertEqual($0 as? LegacyWalletMigrationError, .inconsistentRelationships)
                }
                XCTAssertEqual(try Data(contentsOf: source), original)
            }
        }
    }

    func testInvalidStoredAmountStopsWithoutChangingSource() throws {
        try withFixture(amount: -1) { source, backups in
            let original = try Data(contentsOf: source)
            XCTAssertThrowsError(try LegacyWalletMigration.prepare(from: source, currencyCode: "USD", backupDirectory: backups)) {
                XCTAssertEqual($0 as? LegacyWalletMigrationError, .invalidAmount)
            }
            XCTAssertEqual(try Data(contentsOf: source), original)
        }
    }

    @MainActor
    func testPreparedBackupRestoresIdempotentlyWithAtomicReceipt() async throws {
        try withFixture { source, backups in
            let preview = try LegacyWalletMigration.prepare(from: source, currencyCode: "USD", backupDirectory: backups)
            let container = try WalletStore.makeContainer(inMemory: true)
            let context = container.mainContext
            let receipt = WalletMigrationReceipt(sourceDigest: preview.sourceDigest, currencyCode: "USD",
                                                   transactionCount: 1, categoryCount: 1)
            let first = try preview.backup.restore(into: context, migrationReceipt: receipt)
            XCTAssertEqual(first.insertedCategories, 1)
            XCTAssertEqual(first.insertedTransactions, 1)
            let second = try preview.backup.restore(into: context)
            XCTAssertEqual(second.skippedCategories, 1)
            XCTAssertEqual(second.skippedTransactions, 1)
            XCTAssertEqual(try context.fetchCount(FetchDescriptor<WalletTransaction>()), 1)
            XCTAssertEqual(try context.fetchCount(FetchDescriptor<WalletMigrationReceipt>()), 1)
            XCTAssertFalse(context.hasChanges)
        }
    }

    private enum FixtureRelationship { case normal, orphan, wrongCategoryID, multipleParents, wrongKind }

    private func withFixture(amount: Float = 12.34, schemaVersion: UInt64 = 15,
                             relationship: FixtureRelationship = .normal,
                             _ body: (URL, URL) throws -> Void) throws {
        let manager = FileManager.default
        let directory = manager.temporaryDirectory.appendingPathComponent("iWallet-legacy-test-\(UUID().uuidString)", isDirectory: true)
        try manager.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? manager.removeItem(at: directory) }
        let source = directory.appendingPathComponent("default.realm")
        let backups = directory.appendingPathComponent("backups", isDirectory: true)
        // Release the Realm and every managed object before byte-for-byte copying.
        try autoreleasepool {
            let realm = try Realm(configuration: .init(fileURL: source, schemaVersion: schemaVersion,
                                                       objectTypes: [Category.self, TransactionItem.self]))
            let category = Category()
            category.id = try ObjectId(string: "64a000000000000000000001")
            category.name = "Продукты"
            category.icon = "cart.fill"
            category.color = "colorPurple"
            let transaction = TransactionItem()
            transaction.id = try ObjectId(string: "64a000000000000000000002")
            transaction.categoryId = relationship == .wrongCategoryID ? ObjectId.generate() : category.id
            transaction.amount = amount
            transaction.note = "Milk / молоко"
            transaction.date = Date(timeIntervalSince1970: 1_700_000_000.125)
            if relationship == .wrongKind { transaction.type = "Income" }
            try realm.write {
                realm.add(category)
                realm.add(transaction)
                if relationship != .orphan { category.transactions.append(transaction) }
                if relationship == .multipleParents {
                    let other = Category()
                    other.name = "Other"
                    other.icon = "folder"
                    other.color = "colorBlue"
                    other.transactions.append(transaction)
                    realm.add(other)
                }
            }
        }
        try body(source, backups)
    }
}

/// Reproduces a disk-full copy which has already written a partial destination.
private final class PartialCopyFileManager: FileManager, @unchecked Sendable {
    private let failingCopy: Int
    private var copyCount = 0

    init(failingCopy: Int) {
        self.failingCopy = failingCopy
        super.init()
    }

    override func copyItem(at srcURL: URL, to dstURL: URL) throws {
        copyCount += 1
        if copyCount == failingCopy {
            try Data("partial file".utf8).write(to: dstURL)
            throw CocoaError(.fileWriteOutOfSpace)
        }
        try super.copyItem(at: srcURL, to: dstURL)
    }
}

// Exact persisted class/property names from the original b521ad4 schema 15.
// These exist only in the test target; production uses dynamic migration objects.
final class Category: Object {
    @Persisted(primaryKey: true) var id: ObjectId = ObjectId.generate()
    @Persisted var name = ""
    @Persisted var icon = ""
    @Persisted var color = ""
    @Persisted var type = "Expense"
    @Persisted var transactions: List<TransactionItem>
}

final class TransactionItem: Object {
    @Persisted(primaryKey: true) var id: ObjectId = ObjectId.generate()
    @Persisted var categoryId: ObjectId = ObjectId.generate()
    @Persisted var amount: Float = 0
    @Persisted var note = ""
    @Persisted var date = Date()
    @Persisted var type = "Expense"
    @Persisted(originProperty: "transactions") var category: LinkingObjects<Category>
}

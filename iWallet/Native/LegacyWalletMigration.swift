import Foundation
import CryptoKit
import RealmSwift

enum LegacyWalletMigrationError: LocalizedError, Equatable {
    case missingSource
    case sourceChanged
    case snapshotMismatch
    case unsupportedSchema(UInt64)
    case invalidSchema
    case invalidRecord
    case inconsistentRelationships
    case invalidAmount
    case currencyRequired
    case readerDidNotRun

    var errorDescription: String? {
        switch self {
        case .missingSource:
            NSLocalizedString("The previous wallet file is unavailable. Your data has not been changed.", comment: "Legacy migration error")
        case .sourceChanged:
            NSLocalizedString("The previous wallet changed while it was being copied. Close other copies of iWallet and try again.", comment: "Legacy migration error")
        case .snapshotMismatch:
            NSLocalizedString("The saved copy of your previous wallet failed verification. It has not been overwritten.", comment: "Legacy migration error")
        case .unsupportedSchema:
            NSLocalizedString("This previous wallet version is not supported yet. Keep the original file for a future import.", comment: "Legacy migration error")
        case .invalidSchema:
            NSLocalizedString("The previous wallet has an unexpected structure. The original file has not been changed.", comment: "Legacy migration error")
        case .invalidRecord:
            NSLocalizedString("Some previous wallet records need review before they can be imported. The original file has not been changed.", comment: "Legacy migration error")
        case .inconsistentRelationships:
            NSLocalizedString("Some transactions have missing or conflicting categories. Import stopped without changing your data.", comment: "Legacy migration error")
        case .invalidAmount:
            NSLocalizedString("Some previous amounts cannot be safely converted. Import stopped without changing your data.", comment: "Legacy migration error")
        case .currencyRequired:
            NSLocalizedString("Choose the original wallet's currency before importing. Currency symbols alone may be ambiguous.", comment: "Legacy migration error")
        case .readerDidNotRun:
            NSLocalizedString("The previous wallet could not be read. The original file has not been changed.", comment: "Legacy migration error")
        }
    }
}

/// A one-time bridge. The source and retained snapshot are never opened with Realm.
/// Call only during the cold-upgrade bootstrap, before any legacy writer is started.
/// This reader supports the verified schema 15, not arbitrary earlier schemas.
enum LegacyWalletMigration {
    static let importerVersion = 1
    static let supportedSchemaVersion: UInt64 = 15

    struct Preview: Sendable {
        let backup: WalletBackup
        let sourceDigest: String
        let sourceSchemaVersion: UInt64
        /// A retained, byte-for-byte copy, before Realm can upgrade its file format.
        let snapshotURL: URL
        let reportURL: URL
        let amountAdjustments: [AmountAdjustment]
    }

    struct AmountAdjustment: Codable, Equatable, Identifiable, Sendable {
        let originalTransactionID: String
        let originalFloatBits: UInt32
        let originalDecimal: String
        let amountMinor: Int64
        var id: String { originalTransactionID }
    }

    enum EntityKind: String, Sendable { case category, transaction }

    struct AmountConversion: Sendable {
        let amountMinor: Int64
        let originalDecimal: String
        let wasRounded: Bool
    }

    static func buildBackup(from sourceURL: URL, currencyCode: String) throws -> WalletBackup {
        try prepare(from: sourceURL, currencyCode: currencyCode).backup
    }

    /// Location and file operations are injectable for disk-failure tests.
    /// Production snapshots stay in Application Support; working copies are
    /// temporary. Repeated reviews of the same bytes reuse the verified snapshot.
    static func prepare(from sourceURL: URL, currencyCode: String,
                        backupDirectory: URL? = nil, temporaryDirectory: URL? = nil,
                        fileManager: FileManager = .default) throws -> Preview {
        guard WalletCurrency(rawValue: currencyCode) != nil else {
            throw LegacyWalletMigrationError.currencyRequired
        }
        let snapshot = try makeSnapshot(from: sourceURL, backupDirectory: backupDirectory, manager: fileManager)
        // Only the working copy is temporary. Keep the original snapshot even if
        // opening, conversion, validation, or a later SwiftData import fails.
        let workingDirectory = (temporaryDirectory ?? fileManager.temporaryDirectory)
            .appendingPathComponent("iWallet-legacy-working-\(UUID().uuidString)", isDirectory: true)
        // Install cleanup before creation or copying can fail partway through.
        defer { try? fileManager.removeItem(at: workingDirectory) }
        try fileManager.createDirectory(at: workingDirectory, withIntermediateDirectories: true)
        let workingURL = workingDirectory.appendingPathComponent("default.realm")
        try fileManager.copyItem(at: snapshot.originalURL, to: workingURL)
        guard try sourceDigest(at: workingURL) == snapshot.digest else {
            throw LegacyWalletMigrationError.snapshotMismatch
        }

        let extracted = try autoreleasepool {
            try extract(from: workingURL, currencyCode: currencyCode)
        }
        guard try sourceDigest(at: sourceURL) == snapshot.digest else {
            throw LegacyWalletMigrationError.sourceChanged
        }
        try extracted.backup.validate()

        let report = Report(importerVersion: importerVersion, sourceDigest: snapshot.digest,
                            sourceSchemaVersion: supportedSchemaVersion, currencyCode: currencyCode,
                            createdAt: Date(), categoryCount: extracted.backup.categories.count,
                            transactionCount: extracted.backup.transactions.count,
                            amountAdjustments: extracted.adjustments)
        let reports = snapshot.directory.appendingPathComponent("reports", isDirectory: true)
        try fileManager.createDirectory(at: reports, withIntermediateDirectories: true)
        // Currency changes must never overwrite the report previously reviewed.
        let reportURL = reports.appendingPathComponent("\(currencyCode)-v\(importerVersion)-\(UUID().uuidString).json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(report).write(to: reportURL, options: .atomic)
        return Preview(backup: extracted.backup, sourceDigest: snapshot.digest,
                       sourceSchemaVersion: supportedSchemaVersion, snapshotURL: snapshot.originalURL,
                       reportURL: reportURL, amountAdjustments: extracted.adjustments)
    }

    /// Returns suggestions only. The caller must obtain explicit confirmation of
    /// the currency; the old database did not store a currency per transaction.
    static func currencyCandidates(for legacyValue: String?) -> [WalletCurrency] {
        guard let value = legacyValue?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return [] }
        if let currency = WalletCurrency(rawValue: value) { return [currency] }
        let legacySymbols: [String: [String]] = [
            "$": ["USD", "AUD", "CAD", "MXN"], "€": ["EUR"], "¥": ["JPY", "CNY"],
            "£": ["GBP", "EGP"], "CHF": ["CHF"], "₽": ["RUB"], "₹": ["INR"],
            "R$": ["BRL"], "R": ["ZAR"], "₺": ["TRY"], "Rp": ["IDR"],
            "HK$": ["HKD"], "S$": ["SGD"], "NT$": ["TWD"], "₩": ["KRW"],
            "฿": ["THB"], "RM": ["MYR"], "₱": ["PHP"], "₫": ["VND"],
            "KSh": ["KES"], "Br": ["BYN"], "₴": ["UAH"], "₸": ["KZT"],
            "m": ["TMT"], "Kč": ["CZK"]
        ]
        return (legacySymbols[value] ?? []).compactMap(WalletCurrency.init(rawValue:))
    }

    /// Version-8 UUID: first 128 SHA-256 bits, namespaced by importer and entity.
    /// Never change this namespace for a retry or the same records would duplicate.
    static func stableID(for entity: EntityKind, objectID: String) throws -> UUID {
        let hex = objectID.lowercased()
        guard hex.count == 24, hex.allSatisfy({ $0.isASCII && $0.isHexDigit }) else {
            throw LegacyWalletMigrationError.invalidRecord
        }
        let namespace = "com.idevnva.iwallet.realm15-to-swiftdata.v1/\(entity.rawValue)/\(hex)"
        var bytes = Array(SHA256.hash(data: Data(namespace.utf8)).prefix(16))
        bytes[6] = (bytes[6] & 0x0f) | 0x80
        bytes[8] = (bytes[8] & 0x3f) | 0x80
        return UUID(uuid: (bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
                           bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]))
    }

    /// Converts the shortest decimal representation of the stored Float, not
    /// `Float * 100`. Halfway values round away from zero to the currency's scale.
    /// The original Float's lost precision cannot be reconstructed; the preview
    /// records each value whose decimal representation needs rounding.
    static func convertAmount(_ amount: Float, currencyCode: String) throws -> AmountConversion {
        guard let currency = WalletCurrency(rawValue: currencyCode) else {
            throw LegacyWalletMigrationError.currencyRequired
        }
        guard amount.isFinite, amount > 0 else { throw LegacyWalletMigrationError.invalidAmount }
        let decimalText = String(amount)
        guard let value = Decimal(string: decimalText, locale: Locale(identifier: "en_US_POSIX")) else {
            throw LegacyWalletMigrationError.invalidAmount
        }
        let scale: Decimal = currency.fractionDigits == 0 ? 1 : 100
        var scaled = value * scale
        var rounded = Decimal()
        NSDecimalRound(&rounded, &scaled, 0, .plain)
        guard !rounded.isNaN, rounded > 0, rounded <= Decimal(Money.maximumAmountMinor) else {
            throw LegacyWalletMigrationError.invalidAmount
        }
        return AmountConversion(amountMinor: NSDecimalNumber(decimal: rounded).int64Value,
                                originalDecimal: decimalText, wasRounded: rounded != scaled)
    }

    /// Streaming digest also lets bootstrap recheck the source just before commit.
    static func sourceDigest(at url: URL) throws -> String {
        let file = try FileHandle(forReadingFrom: url)
        defer { try? file.close() }
        var hasher = SHA256()
        while let data = try file.read(upToCount: 1_048_576), !data.isEmpty { hasher.update(data: data) }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    private static func extract(from workingURL: URL, currencyCode: String) throws -> Extracted {
        // Even schemaVersionAtURL may invoke Realm internals, so it only sees the
        // working copy. Earlier or unknown schemas are rejected, never guessed.
        let version = try schemaVersionAtURL(workingURL)
        guard version == supportedSchemaVersion else {
            throw LegacyWalletMigrationError.unsupportedSchema(version)
        }
        let result = ExtractionResult()
        let configuration = Realm.Configuration(
            fileURL: workingURL,
            schemaVersion: supportedSchemaVersion + 1,
            migrationBlock: { migration, oldVersion in
                result.store(Result {
                    guard oldVersion == supportedSchemaVersion else {
                        throw LegacyWalletMigrationError.unsupportedSchema(oldVersion)
                    }
                    return try read(migration: migration, currencyCode: currencyCode)
                })
            },
            deleteRealmIfMigrationNeeded: false,
            objectTypes: []
        )
        // Public Migration API provides dynamic access to the on-disk old schema
        // without declaring any persistent Realm model classes in the new app.
        try Realm.performMigration(for: configuration)
        guard let value = result.load() else { throw LegacyWalletMigrationError.readerDidNotRun }
        return try value.get()
    }

    private static func read(migration: Migration, currencyCode: String) throws -> Extracted {
        try validateSchema(migration.oldSchema)
        var categories: [LegacyCategory] = []
        var transactions: [LegacyTransaction] = []
        var readError: Error?
        migration.enumerateObjects(ofType: "Category") { object, _ in
            guard readError == nil else { return }
            do {
                guard let object,
                      let id = object["id"] as? ObjectId,
                      let name = object["name"] as? String,
                      let icon = object["icon"] as? String,
                      let color = object["color"] as? String,
                      let type = object["type"] as? String,
                      let links = object["transactions"] as? List<DynamicObject> else {
                    throw LegacyWalletMigrationError.invalidRecord
                }
                let transactionIDs = try links.map { item -> String in
                    guard let id = item["id"] as? ObjectId else { throw LegacyWalletMigrationError.invalidRecord }
                    return id.stringValue
                }
                categories.append(LegacyCategory(id: id.stringValue, name: name, icon: icon, color: color,
                                                 kind: try kind(from: type), transactionIDs: Array(transactionIDs)))
            } catch { readError = error }
        }
        if let readError { throw readError }

        migration.enumerateObjects(ofType: "TransactionItem") { object, _ in
            guard readError == nil else { return }
            do {
                guard let object,
                      let id = object["id"] as? ObjectId,
                      let categoryID = object["categoryId"] as? ObjectId,
                      let amount = object["amount"] as? Float,
                      let date = object["date"] as? Date,
                      let note = object["note"] as? String,
                      let type = object["type"] as? String,
                      date.timeIntervalSince1970.isFinite else {
                    throw LegacyWalletMigrationError.invalidRecord
                }
                transactions.append(LegacyTransaction(id: id.stringValue, categoryID: categoryID.stringValue,
                                                       amount: amount, date: date, note: note, kind: try kind(from: type)))
            } catch { readError = error }
        }
        if let readError { throw readError }
        return try makeBackup(categories: categories, transactions: transactions, currencyCode: currencyCode)
    }

    private static func makeBackup(categories: [LegacyCategory], transactions: [LegacyTransaction],
                                   currencyCode: String) throws -> Extracted {
        guard Set(categories.map(\.id)).count == categories.count,
              Set(transactions.map(\.id)).count == transactions.count else {
            throw LegacyWalletMigrationError.invalidRecord
        }
        let categoriesByID = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) })
        let transactionIDs = Set(transactions.map(\.id))
        var memberships: [String: Set<String>] = [:]
        for category in categories {
            guard Set(category.transactionIDs).count == category.transactionIDs.count else {
                throw LegacyWalletMigrationError.inconsistentRelationships
            }
            for id in category.transactionIDs {
                guard transactionIDs.contains(id) else { throw LegacyWalletMigrationError.inconsistentRelationships }
                memberships[id, default: []].insert(category.id)
            }
        }
        let convertedCategories = try categories.map { category in
            WalletBackup.CategoryRecord(id: try stableID(for: .category, objectID: category.id),
                                        name: category.name, icon: category.icon, color: category.color,
                                        kind: category.kind.rawValue, isArchived: false)
        }.sorted { $0.id.uuidString < $1.id.uuidString }
        var adjustments: [AmountAdjustment] = []
        let convertedTransactions = try transactions.map { transaction in
            guard let category = categoriesByID[transaction.categoryID], category.kind == transaction.kind,
                  memberships[transaction.id] == Set([transaction.categoryID]) else {
                // Preserve the source and stop: never silently discard an orphan
                // or guess which of multiple contradictory categories was intended.
                throw LegacyWalletMigrationError.inconsistentRelationships
            }
            let amount = try convertAmount(transaction.amount, currencyCode: currencyCode)
            if amount.wasRounded {
                adjustments.append(AmountAdjustment(originalTransactionID: transaction.id,
                                                     originalFloatBits: transaction.amount.bitPattern,
                                                     originalDecimal: amount.originalDecimal,
                                                     amountMinor: amount.amountMinor))
            }
            return WalletBackup.TransactionRecord(
                id: try stableID(for: .transaction, objectID: transaction.id), amountMinor: amount.amountMinor,
                currencyCode: currencyCode, date: transaction.date, note: transaction.note,
                kind: transaction.kind.rawValue,
                categoryID: try stableID(for: .category, objectID: transaction.categoryID)
            )
        }.sorted { $0.id.uuidString < $1.id.uuidString }
        let backup = WalletBackup(formatVersion: 1, createdAt: Date(), categories: convertedCategories,
                                  transactions: convertedTransactions)
        try backup.validate()
        return Extracted(backup: backup, adjustments: adjustments.sorted { $0.id < $1.id })
    }

    private static func kind(from rawValue: String) throws -> TransactionKind {
        switch rawValue {
        case "Expense": .expense
        case "Income": .income
        default: throw LegacyWalletMigrationError.invalidRecord
        }
    }

    private static func validateSchema(_ schema: Schema) throws {
        guard Set(schema.objectSchema.map(\.className)) == Set(["Category", "TransactionItem"]),
              let category = schema["Category"], let transaction = schema["TransactionItem"] else {
            throw LegacyWalletMigrationError.invalidSchema
        }
        let categoryFields: [(String, PropertyType)] = [
            ("id", .objectId), ("name", .string), ("icon", .string), ("color", .string), ("type", .string)
        ]
        let transactionFields: [(String, PropertyType)] = [
            ("id", .objectId), ("categoryId", .objectId), ("amount", .float),
            ("note", .string), ("date", .date), ("type", .string)
        ]
        let expectedCategoryFields = Set(categoryFields.map(\.0) + ["transactions"])
        let expectedTransactionFields = Set(transactionFields.map(\.0))
        let actualTransactionFields = Set(transaction.properties.map(\.name))
        guard Set(category.properties.map(\.name)) == expectedCategoryFields,
              actualTransactionFields == expectedTransactionFields
                || actualTransactionFields == expectedTransactionFields.union(["category"]) else {
            throw LegacyWalletMigrationError.invalidSchema
        }
        for (object, fields) in [(category, categoryFields), (transaction, transactionFields)] {
            guard object.primaryKeyProperty?.name == "id" else { throw LegacyWalletMigrationError.invalidSchema }
            for (name, type) in fields {
                guard let field = object[name], field.type == type, !field.isOptional,
                      !field.isArray, !field.isSet, !field.isMap else {
                    throw LegacyWalletMigrationError.invalidSchema
                }
            }
        }
        guard let links = category["transactions"], links.type == .object, links.isArray,
              links.objectClassName == "TransactionItem" else {
            throw LegacyWalletMigrationError.invalidSchema
        }
        if let backlink = transaction["category"] {
            guard backlink.type == .linkingObjects, backlink.objectClassName == "Category" else {
                throw LegacyWalletMigrationError.invalidSchema
            }
        }
        // The backlink is derived from this list; checking every list membership
        // against categoryId below also verifies that relationship's meaning.
    }

    private static func makeSnapshot(from sourceURL: URL, backupDirectory: URL?,
                                     manager: FileManager) throws -> Snapshot {
        guard sourceURL.isFileURL,
              (try? sourceURL.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else {
            throw LegacyWalletMigrationError.missingSource
        }
        let support = try backupDirectory ?? manager.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                          appropriateFor: nil, create: true)
            .appendingPathComponent("iWalletLegacyMigration", isDirectory: true)
        let digest = try sourceDigest(at: sourceURL)
        let directory = support.appendingPathComponent(digest, isDirectory: true)
        let originalURL = directory.appendingPathComponent("default.realm")
        try manager.createDirectory(at: support, withIntermediateDirectories: true)

        if manager.fileExists(atPath: directory.path) {
            try verifySnapshot(at: originalURL, expectedDigest: digest)
        } else {
            // Publish only a complete, verified snapshot, using a same-volume
            // rename. A partial copy or disk-full error leaves no staging files.
            let staging = support.appendingPathComponent(".snapshot-\(UUID().uuidString)", isDirectory: true)
            defer { try? manager.removeItem(at: staging) }
            try manager.createDirectory(at: staging, withIntermediateDirectories: true)
            let stagedURL = staging.appendingPathComponent("default.realm")
            // A cold local Realm keeps all durable data in .realm. Its .lock,
            // .note and .management siblings are transient coordination state,
            // including FIFOs, and must not be copied into the reader's directory.
            try manager.copyItem(at: sourceURL, to: stagedURL)
            guard try sourceDigest(at: stagedURL) == digest,
                  try sourceDigest(at: sourceURL) == digest else {
                throw LegacyWalletMigrationError.sourceChanged
            }
            do {
                try manager.moveItem(at: staging, to: directory)
            } catch {
                // A concurrent reviewer may have published the same digest. Do
                // not replace it; reuse it only after verifying its actual bytes.
                guard manager.fileExists(atPath: directory.path) else { throw error }
                try verifySnapshot(at: originalURL, expectedDigest: digest)
            }
        }
        guard try sourceDigest(at: sourceURL) == digest else {
            throw LegacyWalletMigrationError.sourceChanged
        }
        return Snapshot(directory: directory, originalURL: originalURL, digest: digest)
    }

    private static func verifySnapshot(at url: URL, expectedDigest: String) throws {
        let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
        guard values?.isRegularFile == true, values?.isSymbolicLink != true,
              try sourceDigest(at: url) == expectedDigest else {
            throw LegacyWalletMigrationError.snapshotMismatch
        }
    }

    private struct Snapshot {
        let directory: URL
        let originalURL: URL
        let digest: String
    }
    private struct Extracted {
        let backup: WalletBackup
        let adjustments: [AmountAdjustment]
    }
    private struct LegacyCategory {
        let id: String
        let name: String
        let icon: String
        let color: String
        let kind: TransactionKind
        let transactionIDs: [String]
    }
    private struct LegacyTransaction {
        let id: String
        let categoryID: String
        let amount: Float
        let date: Date
        let note: String
        let kind: TransactionKind
    }
    private struct Report: Codable {
        let importerVersion: Int
        let sourceDigest: String
        let sourceSchemaVersion: UInt64
        let currencyCode: String
        let createdAt: Date
        let categoryCount: Int
        let transactionCount: Int
        let amountAdjustments: [AmountAdjustment]
    }

    /// Realm invokes its @Sendable migration callback synchronously. A locked
    /// result box avoids sending any live Realm objects outside that callback.
    private final class ExtractionResult: @unchecked Sendable {
        private let lock = NSLock()
        private var result: Result<Extracted, Error>?
        func store(_ result: Result<Extracted, Error>) {
            lock.lock()
            defer { lock.unlock() }
            self.result = result
        }
        func load() -> Result<Extracted, Error>? {
            lock.lock()
            defer { lock.unlock() }
            return result
        }
    }
}

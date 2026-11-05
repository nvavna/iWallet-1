import Foundation
import SwiftData

enum WalletBackupError: LocalizedError, Equatable {
    case fileTooLarge
    case tooManyRecords
    case malformedFile
    case unsupportedVersion
    case invalidRecord
    case duplicateID
    case missingCategory
    case categoryKindMismatch
    case conflictingRecord
    case unsavedChanges

    var errorDescription: String? {
        switch self {
        case .fileTooLarge:
            return NSLocalizedString("The backup exceeds the 50 MB file limit.", comment: "Backup error")
        case .tooManyRecords:
            return NSLocalizedString("The backup exceeds the 100,000 record limit.", comment: "Backup error")
        case .malformedFile:
            return NSLocalizedString("This file is not a valid iWallet backup.", comment: "Backup error")
        case .unsupportedVersion:
            return NSLocalizedString("This backup requires a different version of iWallet.", comment: "Backup error")
        case .invalidRecord:
            return NSLocalizedString("The backup contains an invalid category or transaction.", comment: "Backup error")
        case .duplicateID:
            return NSLocalizedString("The backup contains duplicate record identifiers.", comment: "Backup error")
        case .missingCategory:
            return NSLocalizedString("A transaction refers to a category missing from the backup.", comment: "Backup error")
        case .categoryKindMismatch:
            return NSLocalizedString("A transaction and its category have different types.", comment: "Backup error")
        case .conflictingRecord:
            return NSLocalizedString("A record in this backup conflicts with data already on this device. Nothing was imported.", comment: "Backup error")
        case .unsavedChanges:
            return NSLocalizedString("Finish or cancel your current changes before importing a backup.", comment: "Backup error")
        }
    }
}

struct WalletBackup: Codable, Equatable, Sendable {
    static let currentFormatVersion = 1
    static let maximumFileSize = 50 * 1_024 * 1_024
    static let maximumRecordCount = 100_000

    var formatVersion: Int = currentFormatVersion
    var createdAt: Date = Date()
    var categories: [CategoryRecord]
    var transactions: [TransactionRecord]

    struct CategoryRecord: Codable, Equatable, Sendable {
        var id: UUID
        var name: String
        var icon: String
        var color: String
        var kind: String
        var isArchived: Bool
    }

    struct TransactionRecord: Codable, Equatable, Sendable {
        var id: UUID
        var amountMinor: Int64
        var currencyCode: String
        var date: Date
        var note: String
        var kind: String
        var categoryID: UUID?
    }

    struct ImportSummary: Equatable, Sendable {
        let insertedCategories: Int
        let insertedTransactions: Int
        let skippedCategories: Int
        let skippedTransactions: Int
    }

    @MainActor
    static func snapshot(context: ModelContext) throws -> WalletBackup {
        guard !context.hasChanges else { throw WalletBackupError.unsavedChanges }
        let categories = try context.fetch(FetchDescriptor<WalletCategory>()).map(CategoryRecord.init)
        let transactions = try context.fetch(FetchDescriptor<WalletTransaction>()).map(TransactionRecord.init)
        let backup = WalletBackup(categories: categories.sorted { $0.id.uuidString < $1.id.uuidString },
                                  transactions: transactions.sorted { $0.id.uuidString < $1.id.uuidString })
        try backup.validate()
        return backup
    }

    func encodedData() throws -> Data {
        try validate()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(try BackupDateCoding.string(from: date))
        }
        let data = try encoder.encode(self)
        guard data.count <= Self.maximumFileSize else { throw WalletBackupError.fileTooLarge }
        return data
    }

    static func decode(data: Data) throws -> WalletBackup {
        guard data.count <= maximumFileSize else { throw WalletBackupError.fileTooLarge }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            guard let date = BackupDateCoding.date(from: value) else { throw WalletBackupError.malformedFile }
            return date
        }
        do {
            // Check the envelope before decoding records from a future schema.
            let header = try decoder.decode(VersionHeader.self, from: data)
            guard header.formatVersion == currentFormatVersion else { throw WalletBackupError.unsupportedVersion }
            let backup = try decoder.decode(Self.self, from: data)
            try backup.validate()
            return backup
        } catch let error as WalletBackupError {
            throw error
        } catch {
            throw WalletBackupError.malformedFile
        }
    }

    func validate() throws {
        guard formatVersion == Self.currentFormatVersion else { throw WalletBackupError.unsupportedVersion }
        guard categories.count <= Self.maximumRecordCount,
              transactions.count <= Self.maximumRecordCount - categories.count else { throw WalletBackupError.tooManyRecords }
        guard WalletDateRange.contains(createdAt) else { throw WalletBackupError.invalidRecord }
        var categoryMap: [UUID: CategoryRecord] = [:]
        var transactionIDs = Set<UUID>()
        for category in categories {
            guard categoryMap.updateValue(category, forKey: category.id) == nil else { throw WalletBackupError.duplicateID }
            guard TransactionKind(rawValue: category.kind) != nil,
                  !category.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !category.icon.isEmpty,
                  !category.color.isEmpty else { throw WalletBackupError.invalidRecord }
        }
        for transaction in transactions {
            guard transactionIDs.insert(transaction.id).inserted else { throw WalletBackupError.duplicateID }
            guard TransactionKind(rawValue: transaction.kind) != nil,
                  WalletCurrency(rawValue: transaction.currencyCode) != nil,
                  transaction.amountMinor > 0, transaction.amountMinor <= Money.maximumAmountMinor,
                  WalletDateRange.contains(transaction.date) else { throw WalletBackupError.invalidRecord }
            if let id = transaction.categoryID {
                guard let category = categoryMap[id] else { throw WalletBackupError.missingCategory }
                guard category.kind == transaction.kind else { throw WalletBackupError.categoryKindMismatch }
            }
        }
    }

    /// Additive restore: identical identities are skipped, conflicts reject the entire file.
    /// Validation and conflict checks complete before any persistent model is changed.
    @MainActor
    func restore(into context: ModelContext, migrationReceipt: WalletMigrationReceipt? = nil) throws -> ImportSummary {
        try validate()
        guard !context.hasChanges else { throw WalletBackupError.unsavedChanges }
        context.autosaveEnabled = false
        // Failed saves can leave newly related models registered in a SwiftData
        // context even after rollback. Keep that temporary state out of the UI's
        // context; only the single successful store save becomes visible to it.
        let importContext = ModelContext(context.container)
        importContext.autosaveEnabled = false
        return try restoreValidated(into: importContext, migrationReceipt: migrationReceipt)
    }

    @MainActor
    private func restoreValidated(into context: ModelContext, migrationReceipt: WalletMigrationReceipt?) throws -> ImportSummary {
        let storedCategories = try context.fetch(FetchDescriptor<WalletCategory>())
        let storedTransactions = try context.fetch(FetchDescriptor<WalletTransaction>())
        var categoriesByID: [UUID: WalletCategory] = [:]
        var transactionsByID: [UUID: WalletTransaction] = [:]
        for category in storedCategories {
            guard categoriesByID.updateValue(category, forKey: category.id) == nil else { throw WalletBackupError.conflictingRecord }
        }
        for transaction in storedTransactions {
            guard transactionsByID.updateValue(transaction, forKey: transaction.id) == nil else { throw WalletBackupError.conflictingRecord }
        }
        for category in categories {
            if let existing = categoriesByID[category.id], CategoryRecord(existing) != category {
                throw WalletBackupError.conflictingRecord
            }
        }
        for transaction in transactions {
            if let existing = transactionsByID[transaction.id], TransactionRecord(existing) != transaction {
                throw WalletBackupError.conflictingRecord
            }
        }
        var receiptToInsert: WalletMigrationReceipt?
        if let receipt = migrationReceipt {
            guard receipt.modelContext == nil,
                  !receipt.id.isEmpty, receipt.id.count <= 128,
                  receipt.sourceDigest.count == 64,
                  receipt.sourceDigest.allSatisfy({ $0.isASCII && $0.isHexDigit }),
                  WalletCurrency(rawValue: receipt.currencyCode) != nil,
                  WalletDateRange.contains(receipt.completedAt),
                  receipt.categoryCount == categories.count,
                  receipt.transactionCount == transactions.count,
                  transactions.allSatisfy({ $0.currencyCode == receipt.currencyCode }) else { throw WalletBackupError.invalidRecord }
            let receipts = try context.fetch(FetchDescriptor<WalletMigrationReceipt>())
            if let existing = receipts.first(where: { $0.id == receipt.id }) {
                guard existing.sourceDigest == receipt.sourceDigest,
                      existing.currencyCode == receipt.currencyCode,
                      existing.categoryCount == receipt.categoryCount,
                      existing.transactionCount == receipt.transactionCount else { throw WalletBackupError.conflictingRecord }
            } else {
                receiptToInsert = receipt
            }
        }
        let newCategories = categories.filter { categoriesByID[$0.id] == nil }
        let newTransactions = transactions.filter { transactionsByID[$0.id] == nil }
        let summary = ImportSummary(insertedCategories: newCategories.count, insertedTransactions: newTransactions.count,
                                    skippedCategories: categories.count - newCategories.count,
                                    skippedTransactions: transactions.count - newTransactions.count)
        guard !newCategories.isEmpty || !newTransactions.isEmpty || receiptToInsert != nil else { return summary }

        for record in newCategories {
            // validate() has already checked every raw value.
            guard let kind = TransactionKind(rawValue: record.kind) else { throw WalletBackupError.invalidRecord }
            let category = WalletCategory(name: record.name, icon: record.icon, color: record.color,
                                          kind: kind, isArchived: record.isArchived, id: record.id)
            context.insert(category)
            categoriesByID[record.id] = category
        }
        for record in newTransactions {
            guard let kind = TransactionKind(rawValue: record.kind) else { throw WalletBackupError.invalidRecord }
            context.insert(WalletTransaction(amountMinor: record.amountMinor, currencyCode: record.currencyCode,
                                              date: record.date, note: record.note, kind: kind,
                                              category: record.categoryID.flatMap { categoriesByID[$0] }, id: record.id))
        }
        if let receiptToInsert { context.insert(receiptToInsert) }
        do {
            try context.save()
        } catch {
            context.rollback()
            context.processPendingChanges()
            throw error
        }
        return summary
    }

    private struct VersionHeader: Decodable { let formatVersion: Int }
}

private extension WalletBackup.CategoryRecord {
    init(_ category: WalletCategory) {
        self.init(id: category.id, name: category.name, icon: category.icon, color: category.color,
                  kind: category.kindRaw, isArchived: category.isArchived)
    }
}

private extension WalletBackup.TransactionRecord {
    init(_ transaction: WalletTransaction) {
        self.init(id: transaction.id, amountMinor: transaction.amountMinor, currencyCode: transaction.currencyCode,
                  date: transaction.date, note: transaction.note, kind: transaction.kindRaw, categoryID: transaction.category?.id)
    }
}

private enum BackupDateCoding {
    // ISO8601DateFormatter truncates fractional seconds. Keep the fractional interval
    // separately so exporting and reimporting an unchanged transaction is idempotent.
    static func string(from date: Date) throws -> String {
        guard WalletDateRange.contains(date) else { throw WalletBackupError.invalidRecord }
        let interval = date.timeIntervalSinceReferenceDate
        let whole = floor(interval)
        let fraction = interval - whole
        let formatter = formatter()
        let base = formatter.string(from: Date(timeIntervalSinceReferenceDate: whole))
        if fraction == 0 { return base }
        var digits = String(format: "%.17f", locale: Locale(identifier: "en_US_POSIX"), fraction).dropFirst(2)
        while digits.last == "0" { digits.removeLast() }
        let encoded = String(base.dropLast()) + "." + digits + "Z"
        guard Self.date(from: encoded) == date else { throw WalletBackupError.invalidRecord }
        return encoded
    }

    static func date(from string: String) -> Date? {
        let formatter = formatter()
        guard let separator = string.firstIndex(of: ".") else { return strictWholeDate(from: string, formatter: formatter) }
        let afterPoint = string[string.index(after: separator)...]
        let digits = afterPoint.prefix { $0.isASCII && $0.isNumber }
        guard !digits.isEmpty, digits.count <= 17,
              let fraction = TimeInterval("0." + digits), fraction >= 0, fraction < 1 else { return nil }
        let suffix = afterPoint.dropFirst(digits.count)
        guard suffix == "Z" else { return nil }
        guard let whole = strictWholeDate(from: String(string[..<separator]) + suffix, formatter: formatter) else { return nil }
        return whole.addingTimeInterval(fraction)
    }

    private static func strictWholeDate(from string: String, formatter: ISO8601DateFormatter) -> Date? {
        // Both the original exporter and this format write UTC dates. Foundation's
        // parser alone accepts impossible dates and trailing text, so round-trip
        // the whole-second portion before accepting it.
        guard string.count == 20, string.last == "Z",
              let date = formatter.date(from: string), formatter.string(from: date) == string else { return nil }
        return date
    }

    private static func formatter() -> ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }
}

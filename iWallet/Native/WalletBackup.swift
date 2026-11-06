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
            return NSLocalizedString("The backup contains an invalid record.", comment: "Backup error")
        case .duplicateID:
            return NSLocalizedString("The backup contains duplicate record identifiers.", comment: "Backup error")
        case .missingCategory:
            return NSLocalizedString("A record refers to a category missing from the backup.", comment: "Backup error")
        case .categoryKindMismatch:
            return NSLocalizedString("A record and its category have different types.", comment: "Backup error")
        case .conflictingRecord:
            return NSLocalizedString("A record in this backup conflicts with data already on this device. Nothing was imported.", comment: "Backup error")
        case .unsavedChanges:
            return NSLocalizedString("Finish or cancel your current changes before importing a backup.", comment: "Backup error")
        }
    }
}

struct WalletBackup: Codable, Equatable, Sendable {
    static let currentFormatVersion = 3
    static let maximumFileSize = 50 * 1_024 * 1_024
    static let maximumRecordCount = 100_000

    var formatVersion: Int = currentFormatVersion
    var createdAt: Date = Date()
    var categories: [CategoryRecord]
    var transactions: [TransactionRecord]
    var recurringPayments: [RecurringPaymentRecord]
    var budgets: [BudgetRecord]

    init(formatVersion: Int = currentFormatVersion, createdAt: Date = Date(),
         categories: [CategoryRecord], transactions: [TransactionRecord],
         recurringPayments: [RecurringPaymentRecord] = [], budgets: [BudgetRecord] = []) {
        self.formatVersion = formatVersion
        self.createdAt = createdAt
        self.categories = categories
        self.transactions = transactions
        self.recurringPayments = recurringPayments
        self.budgets = budgets
    }

    private enum CodingKeys: String, CodingKey {
        case formatVersion, createdAt, categories, transactions, recurringPayments, budgets
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        formatVersion = try values.decode(Int.self, forKey: .formatVersion)
        createdAt = try values.decode(Date.self, forKey: .createdAt)
        categories = try values.decode([CategoryRecord].self, forKey: .categories)
        transactions = try values.decode([TransactionRecord].self, forKey: .transactions)
        if formatVersion == 1 {
            recurringPayments = try values.decodeIfPresent([RecurringPaymentRecord].self, forKey: .recurringPayments) ?? []
        } else {
            recurringPayments = try values.decode([RecurringPaymentRecord].self, forKey: .recurringPayments)
        }
        if formatVersion < 3 {
            budgets = try values.decodeIfPresent([BudgetRecord].self, forKey: .budgets) ?? []
        } else {
            budgets = try values.decode([BudgetRecord].self, forKey: .budgets)
        }
    }

    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(formatVersion, forKey: .formatVersion)
        try values.encode(createdAt, forKey: .createdAt)
        try values.encode(categories, forKey: .categories)
        try values.encode(transactions, forKey: .transactions)
        if formatVersion >= 2 { try values.encode(recurringPayments, forKey: .recurringPayments) }
        if formatVersion >= 3 { try values.encode(budgets, forKey: .budgets) }
    }

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

    struct RecurringPaymentRecord: Codable, Equatable, Sendable {
        var id: UUID
        var name: String
        var amountMinor: Int64
        var currencyCode: String
        var categoryID: UUID?
        var cadence: String
        var nextDueDate: Date
        var anchorDay: Int
        var anchorMonth: Int
        var timeZoneIdentifier: String
        var isActive: Bool
        var isSubscription: Bool
        var occurrenceID: UUID
    }

    struct BudgetRecord: Codable, Equatable, Sendable {
        var id: UUID
        var categoryID: UUID
        var year: Int
        var month: Int
        var currencyCode: String
        var limitMinor: Int64
        var timeZoneIdentifier: String

        var scopeKey: String {
            WalletBudget.key(categoryID: categoryID, year: year, month: month, currencyCode: currencyCode)
        }
    }

    struct ImportSummary: Equatable, Sendable {
        let insertedCategories: Int
        let insertedTransactions: Int
        let skippedCategories: Int
        let skippedTransactions: Int
        let insertedRecurringPayments: Int
        let skippedRecurringPayments: Int
        let insertedBudgets: Int
        let skippedBudgets: Int

        init(insertedCategories: Int, insertedTransactions: Int, skippedCategories: Int, skippedTransactions: Int,
             insertedRecurringPayments: Int = 0, skippedRecurringPayments: Int = 0,
             insertedBudgets: Int = 0, skippedBudgets: Int = 0) {
            self.insertedCategories = insertedCategories
            self.insertedTransactions = insertedTransactions
            self.skippedCategories = skippedCategories
            self.skippedTransactions = skippedTransactions
            self.insertedRecurringPayments = insertedRecurringPayments
            self.skippedRecurringPayments = skippedRecurringPayments
            self.insertedBudgets = insertedBudgets
            self.skippedBudgets = skippedBudgets
        }
    }

    @MainActor
    static func snapshot(context: ModelContext) throws -> WalletBackup {
        guard !context.hasChanges else { throw WalletBackupError.unsavedChanges }
        // Recurring commits intentionally use isolated contexts. Read persisted
        // values rather than possibly cached models awaiting the UI reload.
        let readContext = ModelContext(context.container)
        readContext.autosaveEnabled = false
        let categories = try readContext.fetch(FetchDescriptor<WalletCategory>()).map(CategoryRecord.init)
        let transactions = try readContext.fetch(FetchDescriptor<WalletTransaction>()).map(TransactionRecord.init)
        let recurringPayments = try readContext.fetch(FetchDescriptor<WalletRecurringPayment>()).map(RecurringPaymentRecord.init)
        let budgets = try readContext.fetch(FetchDescriptor<WalletBudget>()).map(BudgetRecord.init)
        let backup = WalletBackup(categories: categories.sorted { $0.id.uuidString < $1.id.uuidString },
                                  transactions: transactions.sorted { $0.id.uuidString < $1.id.uuidString },
                                  recurringPayments: recurringPayments.sorted { $0.id.uuidString < $1.id.uuidString },
                                  budgets: budgets.sorted { $0.id.uuidString < $1.id.uuidString })
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
            guard (1...currentFormatVersion).contains(header.formatVersion) else { throw WalletBackupError.unsupportedVersion }
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
        guard (1...Self.currentFormatVersion).contains(formatVersion) else { throw WalletBackupError.unsupportedVersion }
        guard formatVersion != 1 || recurringPayments.isEmpty else { throw WalletBackupError.invalidRecord }
        guard formatVersion >= 3 || budgets.isEmpty else { throw WalletBackupError.invalidRecord }
        guard categories.count <= Self.maximumRecordCount,
              transactions.count <= Self.maximumRecordCount - categories.count,
              recurringPayments.count <= Self.maximumRecordCount - categories.count - transactions.count,
              budgets.count <= Self.maximumRecordCount - categories.count - transactions.count - recurringPayments.count else {
            throw WalletBackupError.tooManyRecords
        }
        guard WalletDateRange.contains(createdAt) else { throw WalletBackupError.invalidRecord }
        var categoryMap: [UUID: CategoryRecord] = [:]
        var transactionIDs = Set<UUID>()
        var recurringPaymentIDs = Set<UUID>()
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
        for payment in recurringPayments {
            guard recurringPaymentIDs.insert(payment.id).inserted else { throw WalletBackupError.duplicateID }
            guard !payment.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  WalletCurrency(rawValue: payment.currencyCode) != nil,
                  payment.amountMinor > 0, payment.amountMinor <= Money.maximumAmountMinor,
                  let cadence = RecurringCadence(rawValue: payment.cadence) else { throw WalletBackupError.invalidRecord }
            do {
                try RecurringSchedule.validate(nextDueDate: payment.nextDueDate, cadence: cadence,
                                                anchorDay: payment.anchorDay, anchorMonth: payment.anchorMonth,
                                                timeZoneIdentifier: payment.timeZoneIdentifier)
            } catch { throw WalletBackupError.invalidRecord }
            if let id = payment.categoryID {
                guard let category = categoryMap[id] else { throw WalletBackupError.missingCategory }
                guard category.kind == TransactionKind.expense.rawValue else { throw WalletBackupError.categoryKindMismatch }
            }
        }
        var budgetIDs = Set<UUID>()
        var budgetScopes = Set<String>()
        for budget in budgets {
            guard budgetIDs.insert(budget.id).inserted, budgetScopes.insert(budget.scopeKey).inserted else {
                throw WalletBackupError.duplicateID
            }
            guard let category = categoryMap[budget.categoryID] else { throw WalletBackupError.missingCategory }
            guard category.kind == TransactionKind.expense.rawValue else { throw WalletBackupError.categoryKindMismatch }
            guard WalletCurrency(rawValue: budget.currencyCode) != nil,
                  budget.limitMinor > 0, budget.limitMinor <= Money.maximumAmountMinor,
                  (try? BudgetMonth(year: budget.year, month: budget.month).interval(in: budget.timeZoneIdentifier)) != nil
            else { throw WalletBackupError.invalidRecord }
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
        let storedRecurringPayments = try context.fetch(FetchDescriptor<WalletRecurringPayment>())
        var categoriesByID: [UUID: WalletCategory] = [:]
        var transactionsByID: [UUID: WalletTransaction] = [:]
        var recurringPaymentsByID: [UUID: WalletRecurringPayment] = [:]
        for category in storedCategories {
            guard categoriesByID.updateValue(category, forKey: category.id) == nil else { throw WalletBackupError.conflictingRecord }
        }
        for transaction in storedTransactions {
            guard transactionsByID.updateValue(transaction, forKey: transaction.id) == nil else { throw WalletBackupError.conflictingRecord }
        }
        for payment in storedRecurringPayments {
            guard recurringPaymentsByID.updateValue(payment, forKey: payment.id) == nil else { throw WalletBackupError.conflictingRecord }
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
        for payment in recurringPayments {
            if let existing = recurringPaymentsByID[payment.id], RecurringPaymentRecord(existing) != payment {
                throw WalletBackupError.conflictingRecord
            }
        }
        // UUIDs identify backups. Scope also has to match because there can
        // only be one limit for a category, month, and currency.
        let storedBudgets = try context.fetch(FetchDescriptor<WalletBudget>())
        var budgetsByID: [UUID: BudgetRecord] = [:]
        var ownerByScope: [String: UUID] = [:]
        for model in storedBudgets {
            let record = BudgetRecord(model)
            guard budgetsByID.updateValue(record, forKey: record.id) == nil,
                  ownerByScope.updateValue(record.id, forKey: record.scopeKey) == nil else { throw WalletBackupError.conflictingRecord }
        }
        for record in budgets {
            if let existing = budgetsByID[record.id], existing != record { throw WalletBackupError.conflictingRecord }
            if let owner = ownerByScope[record.scopeKey], owner != record.id { throw WalletBackupError.conflictingRecord }
        }
        var receiptToInsert: WalletMigrationReceipt?
        if let receipt = migrationReceipt {
            guard recurringPayments.isEmpty, budgets.isEmpty, receipt.modelContext == nil,
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
        let newRecurringPayments = recurringPayments.filter { recurringPaymentsByID[$0.id] == nil }
        let newBudgets = budgets.filter { budgetsByID[$0.id] == nil }
        let summary = ImportSummary(insertedCategories: newCategories.count, insertedTransactions: newTransactions.count,
                                    skippedCategories: categories.count - newCategories.count,
                                    skippedTransactions: transactions.count - newTransactions.count,
                                    insertedRecurringPayments: newRecurringPayments.count,
                                    skippedRecurringPayments: recurringPayments.count - newRecurringPayments.count,
                                    insertedBudgets: newBudgets.count, skippedBudgets: budgets.count - newBudgets.count)
        guard !newCategories.isEmpty || !newTransactions.isEmpty || !newRecurringPayments.isEmpty || !newBudgets.isEmpty || receiptToInsert != nil else { return summary }

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
        for record in newRecurringPayments {
            guard let cadence = RecurringCadence(rawValue: record.cadence) else { throw WalletBackupError.invalidRecord }
            context.insert(WalletRecurringPayment(name: record.name, amountMinor: record.amountMinor,
                                                   currencyCode: record.currencyCode,
                                                   category: record.categoryID.flatMap { categoriesByID[$0] },
                                                   cadence: cadence, nextDueDate: record.nextDueDate,
                                                   anchorDay: record.anchorDay, anchorMonth: record.anchorMonth,
                                                   timeZoneIdentifier: record.timeZoneIdentifier, isActive: record.isActive,
                                                   isSubscription: record.isSubscription, id: record.id, occurrenceID: record.occurrenceID))
        }
        for record in newBudgets {
            context.insert(WalletBudget(categoryID: record.categoryID, year: record.year, month: record.month,
                                        currencyCode: record.currencyCode, limitMinor: record.limitMinor,
                                        timeZoneIdentifier: record.timeZoneIdentifier, id: record.id))
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

private extension WalletBackup.RecurringPaymentRecord {
    init(_ payment: WalletRecurringPayment) {
        self.init(id: payment.id, name: payment.name, amountMinor: payment.amountMinor,
                  currencyCode: payment.currencyCode, categoryID: payment.category?.id, cadence: payment.cadenceRaw,
                  nextDueDate: payment.nextDueDate, anchorDay: payment.anchorDay, anchorMonth: payment.anchorMonth,
                  timeZoneIdentifier: payment.timeZoneIdentifier, isActive: payment.isActive,
                  isSubscription: payment.isSubscription, occurrenceID: payment.occurrenceID)
    }
}

private extension WalletBackup.BudgetRecord {
    init(_ budget: WalletBudget) {
        self.init(id: budget.id, categoryID: budget.categoryID, year: budget.year, month: budget.month,
                  currencyCode: budget.currencyCode, limitMinor: budget.limitMinor, timeZoneIdentifier: budget.timeZoneIdentifier)
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

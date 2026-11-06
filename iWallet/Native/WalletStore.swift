import Foundation
import SwiftData

enum WalletStoreError: LocalizedError, Equatable {
    case invalidCategory
    case archivedCategory
    case categoryKindMismatch
    case missingTransaction
    case emptyCategoryName
    case invalidDate

    var errorDescription: String? {
        switch self {
        case .invalidCategory:
            return NSLocalizedString("Choose an available category.", comment: "Storage error")
        case .archivedCategory:
            return NSLocalizedString("Choose an active category for the new transaction.", comment: "Storage error")
        case .categoryKindMismatch:
            return NSLocalizedString("The category must match the transaction type.", comment: "Storage error")
        case .missingTransaction:
            return NSLocalizedString("This transaction is no longer available.", comment: "Storage error")
        case .emptyCategoryName:
            return NSLocalizedString("Enter a category name.", comment: "Storage error")
        case .invalidDate:
            return NSLocalizedString("Choose a date between years 1 and 9999.", comment: "Storage error")
        }
    }
}

/// Shared by normal saves and JSON backup validation so every saved date can be exported.
enum WalletDateRange {
    static func contains(_ date: Date) -> Bool {
        let interval = date.timeIntervalSince1970
        // ISO calendar years 0001 ... 9999. The bounds also reject NaN and infinity.
        return interval.isFinite && interval >= -62_135_596_800 && interval < 253_402_300_800
    }
}

@MainActor
enum WalletStore {
    static var schema: Schema {
        Schema([WalletCategory.self, WalletTransaction.self, WalletMigrationReceipt.self, WalletRecurringPayment.self, WalletBudget.self])
    }

    static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Self.schema
        let configuration: ModelConfiguration
        if inMemory {
            configuration = ModelConfiguration("iWalletNative", schema: schema,
                                               isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        } else {
            let support = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                      appropriateFor: nil, create: true)
            let directory = support.appendingPathComponent("iWalletNative", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            configuration = ModelConfiguration("iWalletNative", schema: schema,
                                               url: directory.appendingPathComponent("wallet.store"),
                                               cloudKitDatabase: .none)
        }
        let container = try ModelContainer(for: schema, configurations: [configuration])
        container.mainContext.autosaveEnabled = false
        return container
    }

    static func seedIfNeeded(context: ModelContext) throws {
        context.autosaveEnabled = false
        guard try context.fetchCount(FetchDescriptor<WalletCategory>()) == 0 else { return }
        let defaults: [(String, String, String, TransactionKind)] = [
            ("Food", "cart.fill", "colorPurple", .expense),
            ("Eating out", "fork.knife", "colorYellow2", .expense),
            ("Transport", "bus.fill", "colorGray1", .expense),
            ("House", "house.fill", "colorYellow", .expense),
            ("Health", "heart.fill", "colorRed", .expense),
            ("Entertainment", "sparkles", "colorPurple2", .expense),
            ("Clothing and footwear", "tshirt.fill", "colorBrown1", .expense),
            ("Trips", "airplane", "colorPurple1", .expense),
            ("Wage", "banknote.fill", "colorGreen", .income),
            ("Part time job", "briefcase.fill", "colorGreen2", .income),
            ("Present", "gift.fill", "colorGreen1", .income),
            ("Dividends", "chart.line.uptrend.xyaxis", "colorBlue2", .income)
        ]
        try write(context: context) {
            for (name, icon, color, kind) in defaults {
                context.insert(WalletCategory(name: NSLocalizedString(name, comment: "Default category"),
                                              icon: icon, color: color, kind: kind))
            }
        }
    }

    @discardableResult
    static func saveCategory(context: ModelContext, name: String, icon: String, color: String,
                             kind: TransactionKind) throws -> WalletCategory {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw WalletStoreError.emptyCategoryName }
        let category = WalletCategory(name: trimmed, icon: icon, color: color, kind: kind)
        try write(context: context) { context.insert(category) }
        return category
    }

    static func saveTransaction(context: ModelContext, transaction: WalletTransaction? = nil,
                                amountMinor: Int64, currencyCode: String, date: Date, note: String,
                                kind: TransactionKind, category: WalletCategory) throws {
        guard amountMinor > 0 else { throw MoneyError.nonPositiveAmount }
        guard amountMinor <= Money.maximumAmountMinor else { throw MoneyError.amountTooLarge }
        guard WalletCurrency(rawValue: currencyCode) != nil else { throw MoneyError.unsupportedCurrency }
        guard WalletDateRange.contains(date) else { throw WalletStoreError.invalidDate }
        guard category.modelContext === context, !category.isDeleted else { throw WalletStoreError.invalidCategory }
        guard category.kind == kind else { throw WalletStoreError.categoryKindMismatch }
        if let transaction {
            guard transaction.modelContext === context, !transaction.isDeleted else { throw WalletStoreError.missingTransaction }
        }
        guard !category.isArchived || transaction?.category?.id == category.id else { throw WalletStoreError.archivedCategory }

        try write(context: context) {
            if let transaction {
                transaction.amountMinor = amountMinor
                transaction.currencyCode = currencyCode
                transaction.date = date
                transaction.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
                transaction.kind = kind
                transaction.category = category
            } else {
                context.insert(WalletTransaction(amountMinor: amountMinor, currencyCode: currencyCode,
                                                  date: date, note: note.trimmingCharacters(in: .whitespacesAndNewlines),
                                                  kind: kind, category: category))
            }
        }
    }

    static func archiveCategory(context: ModelContext, category: WalletCategory) throws {
        guard category.modelContext === context, !category.isDeleted else { throw WalletStoreError.invalidCategory }
        try write(context: context) { category.isArchived = true }
    }

    static func deleteTransaction(context: ModelContext, transaction: WalletTransaction) throws {
        guard transaction.modelContext === context, !transaction.isDeleted else { throw WalletStoreError.missingTransaction }
        try write(context: context) { context.delete(transaction) }
    }

    /// Replays the post-commit preference update if the app stopped after saving
    /// the migration receipt. A matching marker preserves later manual choices.
    static func applyMigrationPreferences(receipt: WalletMigrationReceipt, preferences: UserDefaults = .standard) {
        let markerKey = "migrationPreferencesApplied.\(receipt.id)"
        guard preferences.string(forKey: markerKey) != receipt.sourceDigest else { return }
        preferences.set(receipt.currencyCode, forKey: "preferredCurrencyCode")
        // Mark completion only after the currency has been applied. If execution
        // stops before this write, replaying the same currency remains safe.
        preferences.set(receipt.sourceDigest, forKey: markerKey)
    }

    /// Reports only existing legacy files. Nothing is opened, moved, or deleted.
    static func legacyStoreURLs(in directories: [URL]? = nil) -> [URL] {
        let manager = FileManager.default
        let roots = directories ?? (manager.urls(for: .documentDirectory, in: .userDomainMask)
            + manager.urls(for: .applicationSupportDirectory, in: .userDomainMask))
        return roots.map { $0.appendingPathComponent("default.realm") }
            .filter { manager.fileExists(atPath: $0.path) }
    }

    static func write(context: ModelContext, mutation: () -> Void) throws {
        context.autosaveEnabled = false
        mutation()
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }
}

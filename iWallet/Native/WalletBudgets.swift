import Foundation
import SwiftData

enum WalletBudgetError: LocalizedError, Equatable {
    case invalidMonth, duplicateBudget, unavailableBudget, inactiveCategory

    var errorDescription: String? {
        switch self {
        case .invalidMonth: return NSLocalizedString("Choose a valid budget month.", comment: "Budget error")
        case .duplicateBudget: return NSLocalizedString("This category already has a budget for this month and currency.", comment: "Budget error")
        case .unavailableBudget: return NSLocalizedString("This budget is no longer available.", comment: "Budget error")
        case .inactiveCategory: return NSLocalizedString("Choose an active expense category for this budget.", comment: "Budget error")
        }
    }
}

/// A civil month, independent of the user's display calendar.
struct BudgetMonth: Equatable {
    let year: Int
    let month: Int

    init(year: Int, month: Int) {
        self.year = year
        self.month = month
    }

    init(containing date: Date, timeZone: TimeZone = .current) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        year = calendar.component(.year, from: date)
        month = calendar.component(.month, from: date)
    }

    func advanced(by months: Int) -> BudgetMonth? {
        guard (1...9999).contains(year), (1...12).contains(month) else { return nil }
        let index = (year - 1) * 12 + month - 1
        let (target, overflow) = index.addingReportingOverflow(months)
        guard !overflow, (0..<(9999 * 12)).contains(target) else { return nil }
        return BudgetMonth(year: target / 12 + 1, month: target % 12 + 1)
    }

    func interval(in timeZoneIdentifier: String) throws -> DateInterval {
        guard (1...9999).contains(year), (1...12).contains(month),
              let zone = TimeZone(identifier: timeZoneIdentifier) else { throw WalletBudgetError.invalidMonth }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        guard let middle = calendar.date(from: DateComponents(year: year, month: month, day: 15, hour: 12)),
              let interval = calendar.dateInterval(of: .month, for: middle) else { throw WalletBudgetError.invalidMonth }
        return interval
    }
}

struct BudgetProgress: Equatable {
    let spentMinor: Int64
    /// Negative when spending exceeds the limit.
    let remainingMinor: Int64
}

struct BudgetCopySummary: Equatable {
    var added = 0
    var existing = 0
    var archived = 0
}

@Model
final class WalletBudget {
    @Attribute(.unique) var id: UUID
    @Attribute(.unique) var scopeKey: String
    var categoryID: UUID
    var year: Int
    var month: Int
    var currencyCode: String
    var limitMinor: Int64
    var timeZoneIdentifier: String

    init(categoryID: UUID, year: Int, month: Int, currencyCode: String, limitMinor: Int64,
         timeZoneIdentifier: String, id: UUID = UUID()) {
        self.id = id
        self.categoryID = categoryID
        self.year = year
        self.month = month
        self.currencyCode = currencyCode
        self.limitMinor = limitMinor
        self.timeZoneIdentifier = timeZoneIdentifier
        scopeKey = Self.key(categoryID: categoryID, year: year, month: month, currencyCode: currencyCode)
    }

    static func key(categoryID: UUID, year: Int, month: Int, currencyCode: String) -> String {
        "\(categoryID.uuidString)|\(year)|\(month)|\(currencyCode)"
    }

    func progress(transactions: [WalletTransaction]) throws -> BudgetProgress {
        let interval = try BudgetMonth(year: year, month: month).interval(in: timeZoneIdentifier)
        let amounts = transactions.compactMap { transaction -> Int64? in
            guard transaction.category?.id == categoryID, transaction.kindRaw == TransactionKind.expense.rawValue,
                  transaction.currencyCode == currencyCode,
                  transaction.date >= interval.start, transaction.date < interval.end else { return nil }
            return transaction.amountMinor
        }
        guard amounts.allSatisfy({ $0 > 0 }) else { throw MoneyError.nonPositiveAmount }
        let spent = try Money.sum(amounts)
        // Both values are nonnegative, so their signed difference fits Int64.
        return BudgetProgress(spentMinor: spent, remainingMinor: limitMinor - spent)
    }
}

extension WalletStore {
    @discardableResult
    static func createBudget(context: ModelContext, category: WalletCategory, month: BudgetMonth,
                             currencyCode: String, limitMinor: Int64,
                             timeZoneIdentifier: String = TimeZone.current.identifier) throws -> WalletBudget {
        let budget = try makeBudget(context: context, category: category, month: month, currencyCode: currencyCode,
                                    limitMinor: limitMinor, timeZoneIdentifier: timeZoneIdentifier)
        let key = budget.scopeKey
        let matching = FetchDescriptor<WalletBudget>(predicate: #Predicate { $0.scopeKey == key })
        guard try context.fetchCount(matching) == 0 else { throw WalletBudgetError.duplicateBudget }
        try write(context: context) { context.insert(budget) }
        return budget
    }

    static func copyPreviousBudgets(context: ModelContext, to month: BudgetMonth) throws -> BudgetCopySummary {
        guard let previous = month.advanced(by: -1) else { throw WalletBudgetError.invalidMonth }
        func budgets(in period: BudgetMonth) throws -> [WalletBudget] {
            let year = period.year
            let monthNumber = period.month
            return try context.fetch(FetchDescriptor<WalletBudget>(predicate: #Predicate {
                $0.year == year && $0.month == monthNumber
            }))
        }

        var summary = BudgetCopySummary()
        let sources = try budgets(in: previous)
        guard !sources.isEmpty else { return summary }
        let categories = try context.fetch(FetchDescriptor<WalletCategory>())
        let byID = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) })
        let existing = Set(try budgets(in: month).map(\.scopeKey))
        var copies: [WalletBudget] = []
        for source in sources {
            guard let category = byID[source.categoryID] else { throw WalletBudgetError.inactiveCategory }
            if category.isArchived {
                summary.archived += 1
                continue
            }
            let key = WalletBudget.key(categoryID: category.id, year: month.year, month: month.month,
                                       currencyCode: source.currencyCode)
            if existing.contains(key) {
                summary.existing += 1
                continue
            }
            copies.append(try makeBudget(context: context, category: category, month: month,
                                         currencyCode: source.currencyCode, limitMinor: source.limitMinor,
                                         timeZoneIdentifier: source.timeZoneIdentifier))
        }
        if !copies.isEmpty {
            try write(context: context) {
                for copy in copies { context.insert(copy) }
            }
        }
        summary.added = copies.count
        return summary
    }

    private static func makeBudget(context: ModelContext, category: WalletCategory, month: BudgetMonth,
                                   currencyCode: String, limitMinor: Int64, timeZoneIdentifier: String) throws -> WalletBudget {
        guard category.modelContext === context, !category.isDeleted,
              category.kindRaw == TransactionKind.expense.rawValue, !category.isArchived else { throw WalletBudgetError.inactiveCategory }
        guard WalletCurrency(rawValue: currencyCode) != nil else { throw MoneyError.unsupportedCurrency }
        try validateBudgetLimit(limitMinor)
        _ = try month.interval(in: timeZoneIdentifier)
        return WalletBudget(categoryID: category.id, year: month.year, month: month.month, currencyCode: currencyCode,
                            limitMinor: limitMinor, timeZoneIdentifier: timeZoneIdentifier)
    }

    static func updateBudgetLimit(context: ModelContext, budget: WalletBudget, limitMinor: Int64) throws {
        guard budget.modelContext === context, !budget.isDeleted else { throw WalletBudgetError.unavailableBudget }
        try validateBudgetLimit(limitMinor)
        try write(context: context) { budget.limitMinor = limitMinor }
    }

    static func deleteBudget(context: ModelContext, budget: WalletBudget) throws {
        guard budget.modelContext === context, !budget.isDeleted else { throw WalletBudgetError.unavailableBudget }
        try write(context: context) { context.delete(budget) }
    }

    private static func validateBudgetLimit(_ limit: Int64) throws {
        guard limit > 0 else { throw MoneyError.nonPositiveAmount }
        guard limit <= Money.maximumAmountMinor else { throw MoneyError.amountTooLarge }
    }
}

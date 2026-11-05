import Foundation

/// Value-only analytics. Persisted money never passes through floating-point arithmetic.
enum WalletInsights {
    enum Period: String, CaseIterable, Identifiable {
        case month, quarter, year, allTime
        var id: String { rawValue }
        var localizedName: String {
            switch self {
            case .month: return NSLocalizedString("Month", comment: "Analytics period")
            case .quarter: return NSLocalizedString("Quarter", comment: "Analytics period")
            case .year: return NSLocalizedString("Year", comment: "Analytics period")
            case .allTime: return NSLocalizedString("All time", comment: "Analytics period")
            }
        }
    }

    enum CategoryID: Hashable {
        case category(UUID), uncategorized, other
        var stableKey: String {
            switch self {
            case .category(let id): return id.uuidString
            case .uncategorized: return "~uncategorized"
            case .other: return "~other"
            }
        }
    }

    struct Entry {
        let id: UUID
        let amountMinor: Int64
        let currencyCode: String
        let date: Date
        let kind: TransactionKind
        let categoryID: UUID?
        let categoryName: String?
        let categoryIcon: String?
        let categoryColor: String?

        init(id: UUID = UUID(), amountMinor: Int64, currencyCode: String, date: Date,
             kind: TransactionKind, categoryID: UUID? = nil, categoryName: String? = nil,
             categoryIcon: String? = nil, categoryColor: String? = nil) {
            self.id = id
            self.amountMinor = amountMinor
            self.currencyCode = currencyCode
            self.date = date
            self.kind = kind
            self.categoryID = categoryID
            self.categoryName = categoryName
            self.categoryIcon = categoryIcon
            self.categoryColor = categoryColor
        }

        @MainActor
        init(transaction: WalletTransaction) {
            self.init(id: transaction.id, amountMinor: transaction.amountMinor,
                      currencyCode: transaction.currencyCode, date: transaction.date,
                      kind: transaction.kind, categoryID: transaction.category?.id,
                      categoryName: transaction.category?.name, categoryIcon: transaction.category?.icon,
                      categoryColor: transaction.category?.color)
        }
    }

    struct Bucket: Identifiable {
        var id: Date { interval.start }
        let interval: DateInterval
        let incomeMinor: Int64
        let expenseMinor: Int64
    }

    struct CategoryTotal: Identifiable {
        let id: CategoryID
        let name: String
        let icon: String
        let color: String
        let amountMinor: Int64
    }

    struct Comparison {
        let interval: DateInterval
        let previousMinor: Int64
        let changeMinor: Int64
        /// Nil when the preceding period has no amount; zero never becomes infinity.
        let percentChange: Decimal?
    }

    struct Snapshot {
        let period: Period
        let currencyCode: String
        let calendar: Calendar
        /// Half-open: start is included; end is excluded. Nil only for empty all-time history.
        let interval: DateInterval?
        let previousInterval: DateInterval?
        let buckets: [Bucket]
        let incomeMinor: Int64
        let expenseMinor: Int64
        let netMinor: Int64
        let expenseAverageMinor: Int64
        let expenseActiveDays: Int
        let transactionCount: Int
        let incomeComparison: Comparison?
        let expenseComparison: Comparison?
        let incomeCategories: [CategoryTotal]
        let expenseCategories: [CategoryTotal]
        let incomeDonutSegments: [CategoryTotal]
        let expenseDonutSegments: [CategoryTotal]

        func categories(for kind: TransactionKind) -> [CategoryTotal] {
            kind == .income ? incomeCategories : expenseCategories
        }

        func donutSegments(for kind: TransactionKind) -> [CategoryTotal] {
            kind == .income ? incomeDonutSegments : expenseDonutSegments
        }

        func comparison(for kind: TransactionKind) -> Comparison? {
            kind == .income ? incomeComparison : expenseComparison
        }
    }

    typealias SnapshotResult = Result<Snapshot, Error>

    static func result(entries: [Entry], currencyCode: String, period: Period,
                       now: Date = Date(), calendar: Calendar = .current) -> SnapshotResult {
        Result { try make(entries: entries, currencyCode: currencyCode, period: period,
                          now: now, calendar: calendar) }
    }

    static func make(entries: [Entry], currencyCode: String, period: Period,
                     now: Date = Date(), calendar: Calendar = .current) throws -> Snapshot {
        guard WalletCurrency(rawValue: currencyCode) != nil else { throw MoneyError.unsupportedCurrency }
        guard WalletDateRange.contains(now) else { throw WalletStoreError.invalidDate }
        let currencyEntries = entries.filter { $0.currencyCode == currencyCode }
        for entry in currencyEntries {
            guard entry.amountMinor > 0 else { throw MoneyError.nonPositiveAmount }
            guard WalletDateRange.contains(entry.date) else { throw WalletStoreError.invalidDate }
        }
        let intervals = try periodIntervals(period: period, entries: currencyEntries, now: now, calendar: calendar)
        let selected = currencyEntries.filter { contains($0.date, in: intervals.current) }
        let previous = currencyEntries.filter { contains($0.date, in: intervals.previous) }
        let income = selected.filter { $0.kind == .income }
        let expenses = selected.filter { $0.kind == .expense }
        let incomeMinor = try Money.sum(income.map(\.amountMinor))
        let expenseMinor = try Money.sum(expenses.map(\.amountMinor))
        let activeDays = Set(expenses.map { calendar.startOfDay(for: $0.date) }).count
        let incomeCategories = try categoryTotals(income)
        let expenseCategories = try categoryTotals(expenses)
        let buckets = try bucketIntervals(period: period, interval: intervals.current, calendar: calendar).map { interval in
            let contents = selected.filter { contains($0.date, in: interval) }
            return Bucket(interval: interval,
                          incomeMinor: try Money.sum(contents.filter { $0.kind == .income }.map(\.amountMinor)),
                          expenseMinor: try Money.sum(contents.filter { $0.kind == .expense }.map(\.amountMinor)))
        }
        return Snapshot(period: period, currencyCode: currencyCode, calendar: calendar,
                        interval: intervals.current, previousInterval: intervals.previous, buckets: buckets,
                        incomeMinor: incomeMinor, expenseMinor: expenseMinor,
                        netMinor: try Money.sum([incomeMinor, -expenseMinor]),
                        expenseAverageMinor: try Money.averagePerDay(expenses.map(\.amountMinor), activeDays: activeDays),
                        expenseActiveDays: activeDays, transactionCount: selected.count,
                        incomeComparison: try comparison(current: incomeMinor, previous: previous,
                                                         kind: .income, interval: intervals.previous),
                        expenseComparison: try comparison(current: expenseMinor, previous: previous,
                                                          kind: .expense, interval: intervals.previous),
                        incomeCategories: incomeCategories, expenseCategories: expenseCategories,
                        incomeDonutSegments: try donutSegments(incomeCategories),
                        expenseDonutSegments: try donutSegments(expenseCategories))
    }

    private static func contains(_ date: Date, in interval: DateInterval?) -> Bool {
        guard let interval else { return false }
        return date >= interval.start && date < interval.end
    }

    private static func periodIntervals(period: Period, entries: [Entry], now: Date,
                                        calendar: Calendar) throws -> (current: DateInterval?, previous: DateInterval?) {
        if period == .allTime {
            guard let first = entries.map(\.date).min(), let last = entries.map(\.date).max() else { return (nil, nil) }
            let start = calendar.startOfDay(for: first)
            guard let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: last)), end > start else {
                throw WalletStoreError.invalidDate
            }
            return (DateInterval(start: start, end: end), nil)
        }
        let component: Calendar.Component = period == .month ? .month : period == .quarter ? .quarter : .year
        guard let whole = calendar.dateInterval(of: component, for: now),
              let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)),
              let priorDay = calendar.date(byAdding: .day, value: -1, to: whole.start),
              let previousWhole = calendar.dateInterval(of: component, for: priorDay) else {
            throw WalletStoreError.invalidDate
        }
        let end = min(tomorrow, whole.end)
        guard let days = calendar.dateComponents([.day], from: whole.start, to: end).day,
              days > 0, let previousEnd = calendar.date(byAdding: .day, value: days, to: previousWhole.start) else {
            throw WalletStoreError.invalidDate
        }
        return (DateInterval(start: whole.start, end: end),
                DateInterval(start: previousWhole.start, end: min(previousEnd, previousWhole.end)))
    }

    private static func bucketIntervals(period: Period, interval: DateInterval?, calendar: Calendar) throws -> [DateInterval] {
        guard let interval else { return [] }
        let component: Calendar.Component
        let stride: Int
        switch period {
        case .month: component = .day; stride = 1
        case .quarter: component = .weekOfYear; stride = 1
        case .year: component = .month; stride = 1
        case .allTime:
            guard let firstMonth = calendar.dateInterval(of: .month, for: interval.start)?.start,
                  let lastMonth = calendar.dateInterval(of: .month, for: interval.end.addingTimeInterval(-1))?.start,
                  let months = calendar.dateComponents([.month], from: firstMonth, to: lastMonth).month else {
                throw WalletStoreError.invalidDate
            }
            if months < 24 {
                component = .month; stride = 1
            } else {
                component = .year
                guard let firstYear = calendar.dateInterval(of: .year, for: interval.start)?.start,
                      let lastYear = calendar.dateInterval(of: .year, for: interval.end.addingTimeInterval(-1))?.start,
                      let years = calendar.dateComponents([.year], from: firstYear, to: lastYear).year else {
                    throw WalletStoreError.invalidDate
                }
                stride = max(1, (years + 24) / 24)
            }
        }
        guard var cursor = calendar.dateInterval(of: component, for: interval.start)?.start else {
            throw WalletStoreError.invalidDate
        }
        var result: [DateInterval] = []
        while cursor < interval.end {
            // Calendar-based steps preserve local day boundaries across DST. The cap is
            // defensive; supported month/quarter/year calendars fit comfortably within it.
            guard result.count < 32,
                  let next = calendar.date(byAdding: component, value: stride, to: cursor), next > cursor else {
                throw WalletStoreError.invalidDate
            }
            result.append(DateInterval(start: max(cursor, interval.start), end: min(next, interval.end)))
            cursor = next
        }
        return result
    }

    private static func categoryTotals(_ entries: [Entry]) throws -> [CategoryTotal] {
        let grouped = Dictionary(grouping: entries) { entry in
            entry.categoryID.map(CategoryID.category) ?? .uncategorized
        }
        return try grouped.map { id, values in
            // A category has one set of metadata in the store. Sorting makes value-only
            // input deterministic even if a caller supplies inconsistent snapshots.
            let first = values.sorted { $0.id.uuidString < $1.id.uuidString }[0]
            return CategoryTotal(id: id,
                                 name: first.categoryName ?? NSLocalizedString("Uncategorized", comment: "Category"),
                                 icon: first.categoryIcon ?? "square.grid.2x2",
                                 color: first.categoryColor ?? "colorGray",
                                 amountMinor: try Money.sum(values.map(\.amountMinor)))
        }.sorted {
            $0.amountMinor == $1.amountMinor ? $0.id.stableKey < $1.id.stableKey : $0.amountMinor > $1.amountMinor
        }
    }

    private static func donutSegments(_ categories: [CategoryTotal]) throws -> [CategoryTotal] {
        guard categories.count > 5 else { return categories }
        return Array(categories.prefix(5)) + [CategoryTotal(id: .other,
            name: NSLocalizedString("Other categories", comment: "Grouped chart categories"),
            icon: "ellipsis", color: "colorGray",
            amountMinor: try Money.sum(categories.dropFirst(5).map(\.amountMinor)))]
    }

    private static func comparison(current: Int64, previous: [Entry], kind: TransactionKind,
                                   interval: DateInterval?) throws -> Comparison? {
        guard let interval else { return nil }
        let previousMinor = try Money.sum(previous.filter { $0.kind == kind }.map(\.amountMinor))
        let change = try Money.sum([current, -previousMinor])
        let percentage = previousMinor > 0 ? Decimal(change) / Decimal(previousMinor) * 100 : nil
        return Comparison(interval: interval, previousMinor: previousMinor, changeMinor: change, percentChange: percentage)
    }
}

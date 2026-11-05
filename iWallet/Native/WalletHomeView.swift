import SwiftUI
import SwiftData

struct WalletHomeView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Query(sort: \WalletTransaction.date, order: .reverse) private var transactions: [WalletTransaction]
    @AppStorage("preferredCurrencyCode") private var preferredCurrency = WalletDefaults.currencyCode
    @State private var selectedCurrency = ""
    @State private var selectedKind: TransactionKind = .expense
    @State private var showingEditor = false
    @State private var allTime = true

    private var currency: String { selectedCurrency.isEmpty ? preferredCurrency : selectedCurrency }
    private var currencies: [String] { Set(transactions.map(\.currencyCode) + [preferredCurrency]).sorted() }
    private var currencyTransactions: [WalletTransaction] { transactions.filter { $0.currencyCode == currency } }
    private var periodTransactions: [WalletTransaction] {
        guard !allTime, let interval = Calendar.current.dateInterval(of: .month, for: .now) else {
            return currencyTransactions
        }
        return currencyTransactions.filter { $0.date >= interval.start && $0.date < interval.end }
    }
    private var expenses: [WalletTransaction] { periodTransactions.filter { $0.kind == .expense } }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    balanceHeader
                    summary
                    VStack(spacing: 12) {
                        Picker("Transaction type", selection: $selectedKind) {
                            Text("Expense").tag(TransactionKind.expense)
                            Text("Income").tag(TransactionKind.income)
                        }
                        .pickerStyle(.segmented)
                        .accessibilityIdentifier("homeTransactionType")
                        categorySummary
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .accessibilityIdentifier("walletHome")
            .background(WalletTheme.background)
            .navigationTitle("iWallet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("New transaction", systemImage: "plus") { showingEditor = true }
                }
            }
            .sheet(isPresented: $showingEditor) {
                TransactionEditorView(initialKind: selectedKind, initialCurrencyCode: currency)
            }
        }
    }

    private var surface: Color { WalletTheme.surface }

    private var balanceHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 12) {
                Text("Total balance")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                Spacer(minLength: 8)
                currencyMenu
            }
            amount(balanceResult, font: .largeTitle.weight(.semibold))
                .accessibilityLabel("Total balance")
                .accessibilityValue(balanceAccessibilityValue)
        }
        .padding(.horizontal, 4)
        .padding(.bottom, 4)
    }

    private var currencyMenu: some View {
        Menu {
            Picker("Display currency", selection: Binding(get: { currency }, set: { selectedCurrency = $0 })) {
                ForEach(currencies, id: \.self) { Text($0).tag($0) }
            }
        } label: {
            HStack(spacing: 4) {
                Text(currency)
                Image(systemName: "chevron.down").font(.caption2.weight(.semibold))
            }
            .font(.subheadline)
            .foregroundStyle(WalletTheme.accent)
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
        }
        .accessibilityLabel("Display currency")
        .accessibilityValue(currency)
    }

    private var periodMenu: some View {
        Menu {
            Picker("Period", selection: $allTime) {
                Text("This month").tag(false)
                Text("All time").tag(true)
            }
        } label: {
            HStack(spacing: 4) {
                Text(LocalizedStringKey(allTime ? "All time" : "This month"))
                Image(systemName: "chevron.down").font(.caption2.weight(.semibold))
            }
            .font(.subheadline)
            .foregroundStyle(WalletTheme.accent)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .accessibilityLabel("Period")
        .accessibilityValue(Text(LocalizedStringKey(allTime ? "All time" : "This month")))
    }

    private var summary: some View {
        VStack(spacing: 8) {
            let headerLayout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 0))
                : AnyLayout(HStackLayout(spacing: 12))
            headerLayout {
                Text("Summary").font(.headline).accessibilityAddTraits(.isHeader)
                if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 8) }
                periodMenu
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)

            VStack(spacing: 0) {
                metric("Income", result: total(for: .income))
                Divider().padding(.leading, 16)
                metric("Expense", result: total(for: .expense))
                Divider().padding(.leading, 16)
                metric("Expense average", result: averageResult, detail: "Per day with spending")
                    .accessibilityHint("Average expense per day with spending in the selected period.")
            }
            .background(surface, in: RoundedRectangle(cornerRadius: 16))
        }
    }

    private func metric(_ title: LocalizedStringKey, result: Result<Int64, Error>,
                        detail: LocalizedStringKey? = nil) -> some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 16))
        return layout {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.subheadline)
                if let detail {
                    Text(detail).font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 0) }
            amount(result, font: .subheadline.weight(.semibold))
                .multilineTextAlignment(dynamicTypeSize.isAccessibilitySize ? .leading : .trailing)
                .layoutPriority(1)
        }
        .frame(maxWidth: .infinity, minHeight: 28, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func amount(_ result: Result<Int64, Error>, font: Font) -> some View {
        switch result {
        case .success(let value):
            Text(Money.format(value, currencyCode: currency))
                .font(font).monospacedDigit()
                .fixedSize(horizontal: false, vertical: true)
        case .failure:
            Text("Total is too large to display").font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var balanceAccessibilityValue: String {
        switch balanceResult {
        case .success(let value): Money.format(value, currencyCode: currency)
        case .failure: String(localized: "Total is too large to display")
        }
    }

    private var balanceResult: Result<Int64, Error> {
        Result { try Money.sum(currencyTransactions.map { $0.kind == .income ? $0.amountMinor : -$0.amountMinor }) }
    }

    private var averageResult: Result<Int64, Error> {
        Result {
            let days = Set(expenses.map { Calendar.current.startOfDay(for: $0.date) }).count
            return try Money.averagePerDay(expenses.map(\.amountMinor), activeDays: days)
        }
    }

    private func total(for kind: TransactionKind) -> Result<Int64, Error> {
        Result { try Money.sum(periodTransactions.filter { $0.kind == kind }.map(\.amountMinor)) }
    }

    private var categoryTotals: Result<[HomeCategoryTotal], Error> {
        Result {
            let grouped = Dictionary(grouping: periodTransactions.filter { $0.kind == selectedKind }) { $0.category?.id }
            return try grouped.map { key, items in
                HomeCategoryTotal(id: key, category: items.first?.category,
                                  amount: try Money.sum(items.map(\.amountMinor)))
            }.sorted {
                $0.amount == $1.amount ? $0.name.localizedStandardCompare($1.name) == .orderedAscending : $0.amount > $1.amount
            }
        }
    }

    @ViewBuilder
    private var categorySummary: some View {
        switch categoryTotals {
        case .failure:
            Label("Total is too large to display", systemImage: "exclamationmark.triangle")
                .frame(maxWidth: .infinity, alignment: .leading)
                .walletSurface()
        case .success(let totals):
            if totals.isEmpty {
                ContentUnavailableView {
                    Label(LocalizedStringKey(selectedKind == .expense ? "No expenses for this period" : "No income for this period"),
                          systemImage: selectedKind == .expense ? "arrow.up.right" : "arrow.down.left")
                } actions: {
                    Button("Add transaction", systemImage: "plus") { showingEditor = true }
                        .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity)
                .background(surface, in: RoundedRectangle(cornerRadius: 16))
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(totals) { item in
                        NavigationLink {
                            TransactionListView(categoryID: item.id, categoryName: item.name,
                                                onlyUncategorized: item.id == nil, currencyCode: currency)
                        } label: {
                            categoryRow(item)
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("View category transactions")
                        if item.id != totals.last?.id { Divider().padding(.leading, 58) }
                    }
                }
                .background(surface, in: RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    private func categoryRow(_ item: HomeCategoryTotal) -> some View {
        HStack(spacing: 12) {
            CategoryBadge(category: item.category, size: 28)
                .dynamicTypeSize(.large)
                .accessibilityHidden(true)
            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
                : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 12))
            layout {
                Text(item.name)
                    .fixedSize(horizontal: false, vertical: true)
                if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 0) }
                Text(Money.format(item.amount, currencyCode: currency))
                    .fontWeight(.medium).monospacedDigit()
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(dynamicTypeSize.isAccessibilitySize ? .leading : .trailing)
                    .layoutPriority(1)
            }
            .font(.body)
            .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "chevron.forward")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary).accessibilityHidden(true)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .frame(minHeight: 52)
        .foregroundStyle(.primary)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

}

private struct HomeCategoryTotal: Identifiable {
    let id: UUID?
    let category: WalletCategory?
    let amount: Int64
    var name: String { category?.name ?? String(localized: "Uncategorized") }
}

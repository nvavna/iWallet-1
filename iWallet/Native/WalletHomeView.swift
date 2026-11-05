import SwiftUI
import SwiftData

struct WalletHomeView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Query(sort: \WalletTransaction.date, order: .reverse) private var transactions: [WalletTransaction]
    @AppStorage("preferredCurrencyCode") private var preferredCurrency = WalletDefaults.currencyCode
    @State private var selectedCurrency = ""
    @State private var selectedKind: TransactionKind = .expense
    @State private var showingEditor = false
    @State private var showingSettings = false
    @State private var allTime = true
    var showTransactions: () -> Void

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
    private var summaryColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 12), count: dynamicTypeSize.isAccessibilitySize ? 1 : 2)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    displayOptions
                    summary
                    Picker("Transaction type", selection: $selectedKind) {
                        Text("Expense").tag(TransactionKind.expense)
                        Text("Income").tag(TransactionKind.income)
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("homeTransactionType")

                    categorySummary
                    Button(action: showTransactions) {
                        HStack(spacing: 10) {
                            Label("Transactions", systemImage: "clock")
                            Spacer(minLength: 8)
                            Image(systemName: "chevron.forward").font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .frame(minHeight: 44)
                        .padding(.horizontal, 12)
                        .background(WalletTheme.surface, in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("showTransactions")
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 100)
            }
            .accessibilityIdentifier("walletHome")
            .background(WalletTheme.background)
            .foregroundStyle(WalletTheme.accent)
            .navigationTitle("iWallet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingSettings = true } label: {
                        if dynamicTypeSize.isAccessibilitySize {
                            Image(systemName: "gearshape")
                        } else {
                            Text("Settings")
                        }
                    }
                    .accessibilityLabel("Settings")
                }
            }
            .overlay(alignment: .bottomTrailing) {
                Button { showingEditor = true } label: {
                    Image(systemName: "plus")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(WalletTheme.background)
                        .frame(width: 56, height: 56)
                        .background(WalletTheme.accent, in: Circle())
                        .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("New transaction")
                .padding(20)
            }
            .sheet(isPresented: $showingEditor) {
                TransactionEditorView(initialKind: selectedKind, initialCurrencyCode: currency)
            }
            .sheet(isPresented: $showingSettings) { WalletSettingsView() }
        }
    }

    private var displayOptions: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
            : AnyLayout(HStackLayout(spacing: 12))
        return layout {
            Menu {
                Picker("Display currency", selection: Binding(get: { currency }, set: { selectedCurrency = $0 })) {
                    ForEach(currencies, id: \.self) { Text($0).tag($0) }
                }
            } label: {
                HStack(spacing: 5) {
                    Text(currency).fontWeight(.semibold)
                    Image(systemName: "chevron.down").font(.caption)
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .accessibilityLabel("Display currency")
            .accessibilityValue(currency)

            if !dynamicTypeSize.isAccessibilitySize { Spacer() }
            Menu {
                Picker("Period", selection: $allTime) {
                    Text("This month").tag(false)
                    Text("All time").tag(true)
                }
            } label: {
                HStack(spacing: 5) {
                    Text(LocalizedStringKey(allTime ? "All time" : "This month"))
                    Image(systemName: "chevron.down").font(.caption)
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .accessibilityLabel("Period")
            .accessibilityValue(Text(LocalizedStringKey(allTime ? "All time" : "This month")))
        }
        .font(.subheadline)
    }

    private var summary: some View {
        LazyVGrid(columns: summaryColumns, spacing: 12) {
            metric("Balance", symbol: "equal.circle", color: "colorBlue", result: balanceResult, isAllTime: true)
            metric("Expense average", symbol: "plusminus.circle", color: "colorYellow", result: averageResult)
                .accessibilityHint("Average expense per day with spending in the selected period.")
            metric("Income", symbol: "plus.circle", color: "colorGreen", result: total(for: .income))
            metric("Expense", symbol: "minus.circle", color: "colorRed", result: total(for: .expense))
        }
    }

    private func metric(_ title: LocalizedStringKey, symbol: String, color: String,
                        result: Result<Int64, Error>, isAllTime: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    metricIcon(symbol, color: color)
                    Spacer(minLength: 0)
                    metricAmount(result).fixedSize(horizontal: true, vertical: false)
                }
                VStack(alignment: .leading, spacing: 8) {
                    metricIcon(symbol, color: color)
                    metricAmount(result).fixedSize(horizontal: false, vertical: true)
                }
            }
            Text(title).font(.subheadline).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text(LocalizedStringKey(isAllTime || allTime ? "All time" : "This month"))
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(WalletTheme.surface, in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
    }

    private func metricIcon(_ symbol: String, color: String) -> some View {
        Image(systemName: symbol)
            .font(.body.weight(.medium))
            .foregroundStyle(.black)
            .padding(6)
            .background(WalletTheme.categoryColor(color), in: RoundedRectangle(cornerRadius: 8))
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private func metricAmount(_ result: Result<Int64, Error>) -> some View {
        switch result {
        case .success(let amount):
            Text(Money.format(amount, currencyCode: currency))
                .font(.headline).monospacedDigit()
        case .failure:
            Text("Total is too large to display").font(.subheadline)
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
                VStack(spacing: 12) {
                    Image("icon").resizable().scaledToFit().frame(width: 32, height: 32)
                        .accessibilityHidden(true)
                    Text("iWallet").font(.headline)
                    Text(LocalizedStringKey(selectedKind == .expense ? "No expenses for this period" : "No income for this period"))
                        .foregroundStyle(.secondary).multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(24)
                .background(WalletTheme.surface, in: RoundedRectangle(cornerRadius: 12))
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
                        if item.id != totals.last?.id { Divider().padding(.leading, 52) }
                    }
                }
                .background(WalletTheme.surface, in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private func categoryRow(_ item: HomeCategoryTotal) -> some View {
        HStack(spacing: 10) {
            CategoryBadge(category: item.category)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    Text(item.name).fixedSize(horizontal: true, vertical: false)
                    Spacer(minLength: 0)
                    Text(Money.format(item.amount, currencyCode: currency))
                        .fontWeight(.semibold).fixedSize(horizontal: true, vertical: false)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name)
                    Text(Money.format(item.amount, currencyCode: currency)).fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
            }
            .font(.body)
            Image(systemName: "chevron.forward").font(.footnote)
                .foregroundStyle(.secondary).accessibilityHidden(true)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .frame(minHeight: 52)
        .contentShape(Rectangle())
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2)
                .fill(WalletTheme.categoryColor(item.category?.color ?? "colorBlue"))
                .frame(width: 4).padding(.vertical, 8)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct HomeCategoryTotal: Identifiable {
    let id: UUID?
    let category: WalletCategory?
    let amount: Int64
    var name: String { category?.name ?? String(localized: "Uncategorized") }
}

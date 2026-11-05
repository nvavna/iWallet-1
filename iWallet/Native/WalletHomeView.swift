import SwiftUI
import SwiftData

struct WalletHomeView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Query(sort: \WalletTransaction.date, order: .reverse) private var transactions: [WalletTransaction]
    @AppStorage("preferredCurrencyCode") private var preferredCurrency = WalletDefaults.currencyCode
    @State private var selectedCurrency = ""
    @State private var showingEditor = false
    @State private var showingSettings = false
    @State private var allTime = false
    var showTransactions: () -> Void

    private var currency: String { selectedCurrency.isEmpty ? preferredCurrency : selectedCurrency }
    private var currencies: [String] { Set(transactions.map(\.currencyCode) + [preferredCurrency]).sorted() }
    private var currencyTransactions: [WalletTransaction] { transactions.filter { $0.currencyCode == currency } }
    private var periodTransactions: [WalletTransaction] {
        guard !allTime, let interval = Calendar.current.dateInterval(of: .month, for: .now) else {
            return currencyTransactions
        }
        return currencyTransactions.filter { interval.contains($0.date) && $0.date < interval.end }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    balanceCard
                    Button { showingEditor = true } label: {
                        Label("New transaction", systemImage: "plus.circle.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .clipShape(RoundedRectangle(cornerRadius: 18))

                    VStack(alignment: .leading, spacing: 16) {
                        Picker("Period", selection: $allTime) {
                            Text("This month").tag(false)
                            Text("All time").tag(true)
                        }
                        .pickerStyle(.segmented)
                        periodSummary
                    }

                    spendingCard
                    recentTransactions
                    Label("Your finances stay on your device", systemImage: "lock.shield")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 8)
                }
                .padding(20)
            }
            .background(WalletTheme.background)
            .navigationTitle("iWallet")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Picker("Display currency", selection: Binding(get: { currency }, set: { selectedCurrency = $0 })) {
                            ForEach(currencies, id: \.self) { Text($0).tag($0) }
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Text(currency).font(.subheadline.weight(.semibold))
                            Image(systemName: "chevron.down").font(.caption2.weight(.bold))
                        }
                    }
                    .accessibilityLabel("Display currency")
                    .accessibilityValue(currency)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingSettings = true } label: { Image(systemName: "gearshape") }
                        .accessibilityLabel("Settings")
                }
            }
            .sheet(isPresented: $showingEditor) { TransactionEditorView() }
            .sheet(isPresented: $showingSettings) { WalletSettingsView() }
        }
    }

    private var balanceCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            let headerLayout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
                : AnyLayout(HStackLayout())
            headerLayout {
                Label("Balance", systemImage: "wallet.bifold")
                    .font(.headline)
                if !dynamicTypeSize.isAccessibilitySize { Spacer() }
                Text(currency).font(.caption.weight(.semibold))
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(.white.opacity(0.14), in: Capsule())
            }
            switch balanceResult {
            case .success(let amount):
                Text(Money.format(amount, currencyCode: currency))
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .textSelection(.enabled)
            case .failure:
                Label("Total is too large to display", systemImage: "exclamationmark.triangle")
            }
            Text("Income minus expenses · all time")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.85))
        }
        .foregroundStyle(.white)
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 28)
                .fill(LinearGradient(colors: [Color(red: 0.26, green: 0.25, blue: 0.67), Color(red: 0.15, green: 0.15, blue: 0.37)], startPoint: .topLeading, endPoint: .bottomTrailing))
        }
        .accessibilityElement(children: .combine)
    }

    private var balanceResult: Result<Int64, Error> {
        Result {
            try Money.sum(currencyTransactions.map { $0.kind == .income ? $0.amountMinor : -$0.amountMinor })
        }
    }

    private var periodSummary: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 145), spacing: 12)], spacing: 12) {
            summaryTile(kind: .income, symbol: "arrow.down.left", color: .green)
            summaryTile(kind: .expense, symbol: "arrow.up.right", color: .orange)
        }
    }

    private func summaryTile(kind: TransactionKind, symbol: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(kind.localizedName, systemImage: symbol)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if let total = try? Money.sum(periodTransactions.filter { $0.kind == kind }.map(\.amountMinor)) {
                Text(Money.format(total, currencyCode: currency))
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                    .monospacedDigit()
            } else {
                Text("Total is too large to display").font(.footnote)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(WalletTheme.surface, in: RoundedRectangle(cornerRadius: 20))
        .overlay(alignment: .topLeading) {
            Capsule().fill(color).frame(width: 28, height: 3).padding(.leading, 18)
        }
        .accessibilityElement(children: .combine)
    }

    private var spendingCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Spending by category").font(.headline)
            let expenses = periodTransactions.filter { $0.kind == .expense }
            if expenses.isEmpty {
                Label("No expenses for this period", systemImage: "leaf")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .padding(.vertical, 12)
            } else {
                let grouped = Dictionary(grouping: expenses, by: { $0.category?.id })
                let totals = grouped.compactMap { key, items -> CategoryTotal? in
                    guard let amount = try? Money.sum(items.map(\.amountMinor)) else { return nil }
                    return CategoryTotal(id: key, category: items.first?.category, amount: amount)
                }.sorted { $0.amount > $1.amount }
                if totals.count != grouped.count || (try? Money.sum(expenses.map(\.amountMinor))) == nil {
                    Text("Total is too large to display").foregroundStyle(.secondary)
                } else {
                    let total = (try? Money.sum(expenses.map(\.amountMinor))) ?? 0
                    ForEach(totals.prefix(5)) { item in
                        HStack(spacing: 12) {
                            CategoryBadge(category: item.category)
                            VStack(alignment: .leading, spacing: 8) {
                                ViewThatFits(in: .horizontal) {
                                    HStack {
                                        Text(item.category?.name ?? String(localized: "Uncategorized"))
                                        Spacer(minLength: 8)
                                        Text(Money.format(item.amount, currencyCode: currency)).fontWeight(.medium)
                                    }
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(item.category?.name ?? String(localized: "Uncategorized"))
                                        Text(Money.format(item.amount, currencyCode: currency)).fontWeight(.medium)
                                    }
                                }
                                .font(.subheadline)
                                ProgressView(value: Double(item.amount), total: Double(max(total, 1)))
                                    .tint(WalletTheme.categoryColor(item.category?.color ?? "colorBlue"))
                                    .accessibilityHidden(true)
                            }
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .walletSurface()
    }

    private var recentTransactions: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Recent transactions").font(.headline)
                Spacer()
                Button("See all", action: showTransactions)
                    .font(.subheadline)
            }
            if currencyTransactions.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "sparkles").font(.largeTitle).foregroundStyle(WalletTheme.accent)
                    Text("A little clarity, every day").font(.headline)
                    Text("Add your first transaction to see where your money goes.")
                        .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    Button("Add first transaction") { showingEditor = true }
                        .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 16)
            } else {
                ForEach(Array(currencyTransactions.prefix(5))) { transaction in
                    TransactionRow(transaction: transaction)
                    if transaction.id != currencyTransactions.prefix(5).last?.id { Divider() }
                }
            }
        }
        .walletSurface()
    }
}

private struct CategoryTotal: Identifiable {
    let id: UUID?
    let category: WalletCategory?
    let amount: Int64
}

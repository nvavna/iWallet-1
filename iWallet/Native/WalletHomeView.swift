import SwiftUI
import SwiftData

struct WalletHomeView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \WalletTransaction.date, order: .reverse) private var transactions: [WalletTransaction]
    @Query(sort: \WalletRecurringPayment.nextDueDate) private var payments: [WalletRecurringPayment]
    @AppStorage("preferredCurrencyCode") private var preferredCurrency = WalletDefaults.currencyCode
    @SceneStorage("wallet.overview.currency") private var selectedCurrency = ""
    @SceneStorage("wallet.overview.kind") private var storedKind = TransactionKind.expense.rawValue
    @State private var showingEditor = false
    @State private var now = Date()
    @SceneStorage("wallet.overview.period") private var storedPeriod = WalletInsights.Period.month.rawValue
    var showPayments: () -> Void = {}

    private var currency: String { selectedCurrency.isEmpty ? preferredCurrency : selectedCurrency }
    private var period: WalletInsights.Period { WalletInsights.Period(rawValue: storedPeriod) ?? .month }
    private var selectedKind: TransactionKind { TransactionKind(rawValue: storedKind) ?? .expense }
    private var currencies: [String] {
        Set(transactions.map(\.currencyCode) + payments.map(\.currencyCode) + [preferredCurrency]).sorted()
    }
    private var currencyTransactions: [WalletTransaction] { transactions.filter { $0.currencyCode == currency } }
    private var dashboard: WalletInsights.SnapshotResult {
        WalletInsights.result(entries: transactions.map { WalletInsights.Entry(transaction: $0) },
                              currencyCode: currency, period: period, now: now)
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    balanceHeader
                    periodHeader
                    switch dashboard {
                    case .success(let snapshot):
                        summary(snapshot)
                        WalletTimelineCard(snapshot: snapshot)
                        upcomingSection
                        VStack(spacing: 16) {
                            Picker("Transaction type", selection: Binding(get: { selectedKind }, set: { storedKind = $0.rawValue })) {
                                Text("Expense").tag(TransactionKind.expense)
                                Text("Income").tag(TransactionKind.income)
                            }
                            .pickerStyle(.segmented)
                            .accessibilityIdentifier("homeTransactionType")
                            WalletCategoryChartCard(snapshot: snapshot, kind: selectedKind)
                            categorySummary(snapshot)
                            if selectedKind == .expense {
                                NavigationLink {
                                    WalletBudgetListView()
                                } label: {
                                    HStack {
                                        Label("Monthly budgets", systemImage: "chart.bar")
                                        Spacer()
                                        Image(systemName: "chevron.forward").font(.caption)
                                            .accessibilityHidden(true)
                                    }
                                    .frame(minHeight: 44)
                                }
                                .accessibilityIdentifier("overviewBudgets")
                            }
                        }
                    case .failure:
                        Label("Total is too large to display", systemImage: "exclamationmark.triangle")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .walletSurface()
                        upcomingSection
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
            .task { await refreshClock() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { now = Date() }
            }
        }
    }

    @MainActor
    private func refreshClock() async {
        while !Task.isCancelled {
            now = Date()
            do { try await Task.sleep(for: .seconds(60)) }
            catch { return }
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
                .accessibilityIdentifier("overviewBalance")
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
            Picker("Period", selection: Binding(get: { period }, set: { storedPeriod = $0.rawValue })) {
                ForEach(WalletInsights.Period.allCases) { item in
                    Text(item.localizedName).tag(item)
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(period.localizedName)
                Image(systemName: "chevron.down").font(.caption2.weight(.semibold))
            }
            .font(.subheadline)
            .foregroundStyle(WalletTheme.accent)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .accessibilityLabel("Period")
        .accessibilityValue(period.localizedName)
    }

    private var periodHeader: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 8))
        return layout {
            Text("Cash flow").font(.headline).accessibilityAddTraits(.isHeader)
            if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 8) }
            periodMenu
        }
        .padding(.horizontal, 4)
    }

    private func summary(_ snapshot: WalletInsights.Snapshot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
                : AnyLayout(HStackLayout(alignment: .top, spacing: 12))
            layout {
                metric("Income", value: snapshot.incomeMinor, symbol: "arrow.down.left", color: "colorGreen")
                metric("Expense", value: snapshot.expenseMinor, symbol: "arrow.up.right", color: "colorBlue")
            }
            if snapshot.expenseActiveDays > 0 {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Expense average").font(.caption).foregroundStyle(.secondary)
                    Text("\(Money.format(snapshot.expenseAverageMinor, currencyCode: currency)) · \(String(localized: "Per day with spending"))")
                        .font(.subheadline).monospacedDigit()
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 4)
                .accessibilityElement(children: .combine)
                .accessibilityHint("Average expense per day with spending in the selected period.")
            }
        }
    }

    private func metric(_ title: LocalizedStringKey, value: Int64, symbol: String, color: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(WalletTheme.categoryColor(color))
                    .accessibilityHidden(true)
                Text(title).font(.subheadline).foregroundStyle(.secondary)
            }
            Text(Money.format(value, currencyCode: currency))
                .font(.title3.weight(.semibold)).monospacedDigit()
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .walletSurface()
        .accessibilityElement(children: .combine)
    }

    private var upcomingSection: some View {
        WalletForecastCard(payments: payments, currencyCode: currency, now: now, showPayments: showPayments)
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

    @ViewBuilder
    private func categorySummary(_ snapshot: WalletInsights.Snapshot) -> some View {
        let categories = transactions.reduce(into: [UUID: WalletCategory]()) { result, transaction in
            if let category = transaction.category { result[category.id] = category }
        }
        let totals = snapshot.categories(for: selectedKind).map { value in
            let id: UUID?
            if case .category(let categoryID) = value.id { id = categoryID } else { id = nil }
            return HomeCategoryTotal(id: id, category: id.flatMap { categories[$0] }, amount: value.amountMinor)
        }
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

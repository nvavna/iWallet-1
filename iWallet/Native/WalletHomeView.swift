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
    @State private var newKind: TransactionKind?
    @State private var editingTransaction: WalletTransaction?
    @State private var now = Date()
    @ScaledMetric(relativeTo: .largeTitle) private var balanceSize: CGFloat = 46
    @SceneStorage("wallet.overview.period") private var storedPeriod = WalletInsights.Period.month.rawValue
    var showTransactions: () -> Void
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
                VStack(alignment: .leading, spacing: 22) {
                    balanceHeader
                    switch dashboard {
                    case .success(let snapshot):
                        if !currencyTransactions.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                periodHeader
                                summary(snapshot)
                            }
                        }
                        recentTransactions
                        upcomingSection
                        if !currencyTransactions.isEmpty {
                            WalletTimelineCard(snapshot: snapshot)
                            if snapshot.expenseActiveDays > 0 { average(snapshot) }
                            categoryBreakdown(snapshot)
                        }
                    case .failure:
                        Label("Total is too large to display", systemImage: "exclamationmark.triangle")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .walletSurface()
                        recentTransactions
                        upcomingSection
                    }
                    NavigationLink {
                        SpendingReportDestination(currencyCode: currency)
                    } label: {
                        HStack {
                            Label("Spending report", systemImage: "doc.text.magnifyingglass")
                            Spacer()
                            Image(systemName: "chevron.forward").font(.caption).accessibilityHidden(true)
                        }.frame(minHeight: 44)
                    }
                    .accessibilityIdentifier("overviewSpendingReport")
                    NavigationLink {
                        WalletBudgetListView()
                    } label: {
                        HStack {
                            Label("Monthly budgets", systemImage: "chart.bar")
                            Spacer()
                            Image(systemName: "chevron.forward").font(.caption).accessibilityHidden(true)
                        }
                        .frame(minHeight: 44)
                    }
                    .accessibilityIdentifier("overviewBudgets")
                }
                .padding(.horizontal, 18)
                .padding(.top, 10)
                .padding(.bottom, 24)
            }
            .accessibilityIdentifier("walletHome")
            .background(WalletTheme.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if #available(iOS 26, *) {
                    ToolbarItem(placement: .topBarLeading) { wordmark }.sharedBackgroundVisibility(.hidden)
                    ToolbarItem(placement: .topBarTrailing) { today }.sharedBackgroundVisibility(.hidden)
                } else {
                    ToolbarItem(placement: .topBarLeading) { wordmark }
                    ToolbarItem(placement: .topBarTrailing) { today }
                }
            }
            .sheet(item: $newKind) { kind in
                TransactionEditorView(initialKind: kind, initialCurrencyCode: currency)
            }
            .sheet(item: $editingTransaction) { transaction in
                TransactionEditorView(transaction: transaction)
            }
            .task { await refreshClock() }
            .onChange(of: currencies, initial: true) { _, available in
                if !selectedCurrency.isEmpty && !available.contains(selectedCurrency) { selectedCurrency = "" }
            }
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

    private var wordmark: some View {
        HStack(spacing: 8) {
            Image(systemName: "wallet.pass.fill")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(WalletTheme.mint)
                .frame(width: 31, height: 31)
                .background(WalletTheme.forest, in: .rect(cornerRadius: 10))
                .accessibilityHidden(true)
            Text(verbatim: "iWallet")
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(WalletTheme.ink)
        }
        .fixedSize()
        .labelStyle(.titleAndIcon)
        .accessibilityAddTraits(.isHeader)
    }

    private var today: some View {
        Text(now, format: .dateTime.weekday(.abbreviated).day().month(.abbreviated))
            .font(.subheadline.weight(.medium))
            .foregroundStyle(WalletTheme.secondaryInk)
    }

    private var balanceHeader: some View {
        let shape = RoundedRectangle(cornerRadius: 27, style: .continuous)
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Text("Total balance")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.86))
                    .accessibilityHidden(true)
                Spacer(minLength: 0)
                currencyMenu
            }
            balanceAmount
                .foregroundStyle(.white)
                .accessibilityLabel("Total balance")
                .accessibilityValue(balanceAccessibilityValue)
                .accessibilityIdentifier("overviewBalance")
            Text("Income minus expenses · all time")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.78))
                .padding(.top, 4)

            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(spacing: 8)) : AnyLayout(HStackLayout(spacing: 10))
            layout {
                entryButton(.expense)
                entryButton(.income)
            }
            .padding(.top, 23)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 18)
        .background(alignment: .trailing) {
            ZStack(alignment: .trailing) {
                WalletTheme.forest
                BalanceEngraving()
                    .frame(maxWidth: 165)
                    .accessibilityHidden(true)
                    .allowsHitTesting(false)
            }
        }
        .clipShape(shape)
        .overlay { shape.strokeBorder(.white.opacity(0.12), lineWidth: 0.8) }
    }

    private func entryButton(_ kind: TransactionKind) -> some View {
        Button { newKind = kind } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus").font(.caption.weight(.bold))
                Text(kind.localizedName).font(.subheadline.weight(.semibold))
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .foregroundStyle(kind == .expense ? WalletTheme.forest : .white)
            .background(kind == .expense ? WalletTheme.mint : .white.opacity(0.12), in: .capsule)
            .overlay { Capsule().strokeBorder(.white.opacity(kind == .income ? 0.22 : 0), lineWidth: 1) }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(kind == .expense ? Text("Add expense") : Text("Add income"))
        .accessibilityIdentifier(kind == .expense ? "quickAddExpense" : "quickAddIncome")
    }

    private var currencyMenu: some View {
        Menu {
            Picker("Display currency", selection: Binding(get: { currency }, set: { selectedCurrency = $0 })) {
                ForEach(currencies, id: \.self) { Text($0).tag($0) }
            }
        } label: {
            HStack(spacing: 5) {
                Text(currency).font(.caption.weight(.bold))
                Image(systemName: "chevron.down").font(.system(size: 9, weight: .bold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .background(WalletTheme.forest.opacity(0.85), in: .capsule)
            .overlay { Capsule().strokeBorder(.white.opacity(0.32), lineWidth: 0.8) }
            .frame(minHeight: 44)
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
            Text("Cash flow").font(.title3.weight(.semibold)).foregroundStyle(WalletTheme.ink).accessibilityAddTraits(.isHeader)
            if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 8) }
            periodMenu
        }
        .padding(.horizontal, 4)
    }

    private func summary(_ snapshot: WalletInsights.Snapshot) -> some View {
        let vertical = dynamicTypeSize.isAccessibilitySize
        let layout = vertical ? AnyLayout(VStackLayout(alignment: .leading, spacing: 14))
                              : AnyLayout(HStackLayout(alignment: .top, spacing: 14))
        return layout {
            metric("Income", value: snapshot.incomeMinor, symbol: "arrow.down.left", color: WalletTheme.income)
            if !vertical { Divider() }
            metric("Expenses", value: snapshot.expenseMinor, symbol: "arrow.up.right", color: WalletTheme.expense)
        }
        .fixedSize(horizontal: false, vertical: true)
        .walletSurface()
    }

    private func metric(_ title: LocalizedStringKey, value: Int64, symbol: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(color)
                    .frame(width: 21, height: 21)
                    .background(color.opacity(0.11), in: .circle)
                    .accessibilityHidden(true)
                Text(title).font(.subheadline).foregroundStyle(WalletTheme.secondaryInk)
            }
            Text(Money.format(value, currencyCode: currency))
                .font(.system(.title3, design: .rounded, weight: .semibold)).monospacedDigit()
                .foregroundStyle(WalletTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func average(_ snapshot: WalletInsights.Snapshot) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Expense average").font(.subheadline.weight(.semibold))
            HStack {
                Text(Money.format(snapshot.expenseAverageMinor, currencyCode: currency)).monospacedDigit()
                Text("Per day with spending").foregroundStyle(WalletTheme.secondaryInk)
            }
            .font(.subheadline)
        }
        .padding(.horizontal, 4)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Average expense per day with spending in the selected period.")
    }

    private var recentTransactions: some View {
        let recent = Array(currencyTransactions.prefix(3))
        return VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text("Recent transactions")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(WalletTheme.ink)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 4)
                if !recent.isEmpty {
                    Button(action: showTransactions) {
                        HStack(spacing: 4) {
                            Text("See all")
                            Image(systemName: "chevron.forward").font(.caption2.weight(.bold))
                        }
                        .font(.subheadline.weight(.medium))
                        .frame(minHeight: 44)
                    }
                    .accessibilityIdentifier("showTransactionHistory")
                }
            }
            .padding(.horizontal, 4)
            if recent.isEmpty {
                Label {
                    let hint: LocalizedStringKey = transactions.isEmpty
                        ? "Add your first transaction to see where your money goes." : "No matching transactions"
                    Text(hint)
                        .font(.subheadline).foregroundStyle(WalletTheme.secondaryInk)
                } icon: {
                    Image(systemName: "list.bullet.rectangle").foregroundStyle(WalletTheme.accent)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .walletSurface()
            } else {
                VStack(spacing: 0) {
                    ForEach(recent) { transaction in
                        Button { editingTransaction = transaction } label: {
                            TransactionRow(transaction: transaction, showsDate: true)
                                .padding(.horizontal, 14)
                                .frame(minHeight: 52)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Edit transaction")
                        if transaction.id != recent.last?.id { Divider().padding(.leading, 62) }
                    }
                }
                .padding(.vertical, 3)
                .background(surface, in: .rect(cornerRadius: 20))
                .overlay { RoundedRectangle(cornerRadius: 20).strokeBorder(WalletTheme.hairline, lineWidth: 0.6) }
            }
        }
    }

    private func categoryBreakdown(_ snapshot: WalletInsights.Snapshot) -> some View {
        VStack(spacing: 12) {
            Picker("Transaction type", selection: Binding(get: { selectedKind }, set: { storedKind = $0.rawValue })) {
                Text("Expense").tag(TransactionKind.expense)
                Text("Income").tag(TransactionKind.income)
            }
            .walletChoiceStyle()
            .accessibilityIdentifier("homeTransactionType")
            if !snapshot.categories(for: selectedKind).isEmpty {
                WalletCategoryChartCard(snapshot: snapshot, kind: selectedKind)
            }
            categorySummary(snapshot)
        }
    }

    private var upcomingSection: some View {
        WalletForecastCard(payments: payments, currencyCode: currency, now: now, showPayments: showPayments)
    }

    @ViewBuilder
    private var balanceAmount: some View {
        switch balanceResult {
        case .success(let value):
            let amount = Text(Money.format(value, currencyCode: currency)).monospacedDigit()
            let compactFont = Font.system(size: balanceSize * 0.82, weight: .medium, design: .serif)
            ViewThatFits(in: .horizontal) {
                amount.font(.system(size: balanceSize, weight: .medium, design: .serif)).fixedSize()
                amount.font(compactFont).fixedSize()
                amount.font(compactFont).fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
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
                Button("Add transaction", systemImage: "plus") { newKind = selectedKind }
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
                    .accessibilityIdentifier("overviewCategoryTotal")
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

/// Engraved lines on the balance card recall the fine curves on a banknote.
private struct BalanceEngraving: View {
    var body: some View {
        Canvas { context, size in
            for index in 0..<21 {
                let shift = CGFloat(index) * 5.5
                var path = Path()
                path.move(to: CGPoint(x: size.width * 0.32 + shift, y: -2))
                path.addCurve(to: CGPoint(x: -26 + shift, y: size.height + 2),
                              control1: CGPoint(x: size.width * 1.42 + shift, y: size.height * 0.45),
                              control2: CGPoint(x: -18 + shift, y: size.height * 0.39))
                context.stroke(path, with: .color(WalletTheme.mint.opacity(0.24)), lineWidth: 0.7)
            }
        }
        .mask(LinearGradient(colors: [.clear, .white], startPoint: .leading, endPoint: .trailing))
        .flipsForRightToLeftLayoutDirection(true)
    }
}

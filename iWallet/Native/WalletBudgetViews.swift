import SwiftUI
import SwiftData

struct WalletBudgetListView: View {
    @Environment(\.locale) private var locale
    @Environment(\.modelContext) private var context
    @AppStorage("preferredCurrencyCode") private var currencyCode = WalletDefaults.currencyCode
    @Query(sort: \WalletCategory.name) private var categories: [WalletCategory]
    @Query(sort: \WalletBudget.currencyCode) private var budgets: [WalletBudget]
    @State private var month = BudgetMonth(containing: .now)
    @State private var editor: BudgetEditorRoute?
    @State private var copyResult: String?
    @State private var copyError: String?

    var body: some View {
        List {
            Section {
                HStack {
                    Button { moveMonth(-1) } label: {
                        Label("Previous month", systemImage: "chevron.left")
                            .frame(minWidth: 44, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                        .disabled(month.advanced(by: -1) == nil)
                        .accessibilityIdentifier("previousBudgetMonth")
                    Spacer()
                    Text(month.displayName(locale: locale)).font(.headline)
                        .multilineTextAlignment(.center)
                        .accessibilityIdentifier("budgetMonth")
                    Spacer()
                    Button { moveMonth(1) } label: {
                        Label("Next month", systemImage: "chevron.right")
                            .frame(minWidth: 44, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                        .disabled(month.advanced(by: 1) == nil)
                        .accessibilityIdentifier("nextBudgetMonth")
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                Button(action: copyPreviousBudgets) {
                    Label("Copy last month’s budgets", systemImage: "doc.on.doc")
                }
                .disabled(month.advanced(by: -1) == nil)
                .accessibilityIdentifier("copyPreviousBudgets")
            } footer: {
                if let copyResult {
                    Text(copyResult).accessibilityIdentifier("budgetCopyResult")
                }
            }
            let visible = budgets.filter { $0.year == month.year && $0.month == month.month }
            if visible.isEmpty {
                ContentUnavailableView("No budgets this month", systemImage: "gauge.with.dots.needle.50percent",
                                       description: Text("Set a spending limit for a category."))
                    .listRowBackground(Color.clear)
            } else {
                let byID = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) })
                Section {
                    ForEach(visible.sorted { lhs, rhs in
                        let order = (byID[lhs.categoryID]?.name ?? "").localizedStandardCompare(byID[rhs.categoryID]?.name ?? "")
                        return order == .orderedSame ? lhs.currencyCode < rhs.currencyCode : order == .orderedAscending
                    }) { budget in
                        Button {
                            editor = BudgetEditorRoute(budget: budget)
                        } label: {
                            BudgetRow(budget: budget, category: byID[budget.categoryID])
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("budgetRow-\(budget.id.uuidString)")
                    }
                }
            }
        }
        .accessibilityIdentifier("budgetList")
        .navigationTitle("Monthly budgets")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("New budget", systemImage: "plus") { editor = BudgetEditorRoute(budget: nil) }
                    .accessibilityIdentifier("newBudget")
            }
        }
        .sheet(item: $editor) { route in
            BudgetEditor(budget: route.budget, month: month, categories: categories, currency: currencyCode)
        }
        .alert("Unable to complete the operation", isPresented: Binding(
            get: { copyError != nil }, set: { _ in copyError = nil }
        )) {
            Button("OK", role: .cancel) {}
        } message: { Text(copyError ?? "") }
    }

    private func moveMonth(_ delta: Int) {
        guard let nextMonth = month.advanced(by: delta) else { return }
        month = nextMonth
        copyResult = nil
    }

    private func copyPreviousBudgets() {
        do {
            let result = try WalletStore.copyPreviousBudgets(context: context, to: month)
            var messages: [String] = []
            if result.added > 0 {
                messages.append(String(localized: "Budgets added: \(result.added).", locale: locale))
            }
            if result.existing > 0 {
                messages.append(String(localized: "Limits already set: \(result.existing).", locale: locale))
            }
            if result.archived > 0 {
                messages.append(String(localized: "Skipped budgets in archived categories: \(result.archived).", locale: locale))
            }
            let message = messages.isEmpty ? String(localized: "No budgets were set last month.", locale: locale)
                                           : messages.joined(separator: " ")
            copyResult = message
            AccessibilityNotification.Announcement(message).post()
        } catch {
            copyResult = nil
            copyError = error.localizedDescription
        }
    }
}

private struct BudgetEditorRoute: Identifiable {
    let id = UUID()
    let budget: WalletBudget?
}

private extension BudgetMonth {
    func displayName(locale: Locale) -> String {
        guard let interval = try? interval(in: TimeZone.current.identifier) else { return "—" }
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = .current
        formatter.setLocalizedDateFormatFromTemplate("LLLLy")
        return formatter.string(from: interval.start)
    }
}

private struct BudgetRow: View {
    let budget: WalletBudget
    let category: WalletCategory?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            CategoryBadge(category: category).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                Text(category?.name ?? String(localized: "Uncategorized")).font(.headline)
                if category?.isArchived == true { Text("Archived").font(.caption).foregroundStyle(.secondary) }
                Text(verbatim: budget.currencyCode).font(.caption).foregroundStyle(.secondary)
                if let progress = try? budget.progress(transactions: category?.transactions ?? []) {
                    amount("Budget limit", budget.limitMinor)
                    amount("Spent", progress.spentMinor)
                    ProgressView(value: min(1, Double(progress.spentMinor) / Double(budget.limitMinor)))
                        .tint(progress.remainingMinor < 0 ? .orange : WalletTheme.accent)
                        .accessibilityHidden(true)
                    amount(progress.remainingMinor < 0 ? "Over budget" : "Remaining",
                           abs(progress.remainingMinor)).fontWeight(.semibold)
                } else {
                    Text("Unable to calculate this total.").foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 5)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private func amount(_ title: LocalizedStringKey, _ value: Int64) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).foregroundStyle(.secondary).fixedSize()
                Spacer(minLength: 8)
                Text(Money.format(value, currencyCode: budget.currencyCode)).monospacedDigit().fixedSize()
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).foregroundStyle(.secondary)
                Text(Money.format(value, currencyCode: budget.currencyCode)).monospacedDigit()
            }
        }
        .font(.subheadline)
    }
}

private struct BudgetEditor: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @FocusState private var editingAmount: Bool
    @State private var amount: String
    @State private var currency: String
    @State private var categoryID: UUID?
    @State private var error: String?
    @State private var discard = false
    @State private var delete = false
    let budget: WalletBudget?
    let month: BudgetMonth
    let categories: [WalletCategory]
    private let initialAmount: String
    private let initialCurrency: String
    private let initialCategoryID: UUID?

    init(budget: WalletBudget?, month: BudgetMonth, categories: [WalletCategory], currency: String) {
        self.budget = budget
        self.month = month
        self.categories = categories
        initialAmount = budget.map { Money.inputText($0.limitMinor, currencyCode: $0.currencyCode) } ?? ""
        initialCurrency = budget?.currencyCode ?? currency
        initialCategoryID = budget?.categoryID ?? categories.first { $0.kind == .expense && !$0.isArchived }?.id
        _amount = State(initialValue: initialAmount)
        _currency = State(initialValue: initialCurrency)
        _categoryID = State(initialValue: initialCategoryID)
    }

    private var hasChanges: Bool {
        amount != initialAmount || currency != initialCurrency || categoryID != initialCategoryID
    }

    private var parsed: Result<Int64, Error> { Result { try Money.parse(amount, currencyCode: currency) } }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Month", value: month.displayName(locale: locale))
                    if budget != nil {
                        LabeledContent("Category", value: categories.first { $0.id == categoryID }?.name ?? String(localized: "Uncategorized"))
                        LabeledContent("Currency", value: currency)
                    } else {
                        Menu {
                            Picker("Category", selection: $categoryID) {
                                ForEach(categories.filter { $0.kind == .expense && !$0.isArchived }) { category in
                                    Label(category.name, systemImage: WalletTheme.categorySymbol(category.icon))
                                        .tag(Optional(category.id))
                                }
                            }
                        } label: {
                            WalletFormMenuLabel("Category", value: categories.first { $0.id == categoryID }?.name ?? String(localized: "Choose a category"))
                        }
                        .accessibilityIdentifier("budgetCategory")
                        Menu {
                            Picker("Currency", selection: $currency) {
                                ForEach(WalletCurrency.allCases) { item in Text(item.displayName).tag(item.rawValue) }
                            }
                        } label: {
                            WalletFormMenuLabel("Currency", value: WalletCurrency(rawValue: currency)?.displayName ?? currency)
                        }
                        .accessibilityIdentifier("budgetCurrency")
                        if categoryID == nil {
                            Text("Create an expense category in Settings to add a budget.").foregroundStyle(.secondary)
                        }
                    }
                }
                Section("Budget limit") {
                    TextField("Amount", text: $amount)
                        .font(.title2.monospacedDigit())
                        .keyboardType(.decimalPad)
                        .focused($editingAmount)
                        .accessibilityIdentifier("budgetAmount")
                    if !amount.isEmpty, case .failure(let failure) = parsed {
                        Text(failure.localizedDescription).font(.footnote).foregroundStyle(.secondary)
                    }
                }
                if budget != nil {
                    Button("Delete budget", role: .destructive) { delete = true }
                        .accessibilityIdentifier("deleteBudget")
                }
            }
            .navigationTitle(budget == nil ? String(localized: "New budget") : String(localized: "Edit budget"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark") {
                        if hasChanges { discard = true } else { dismiss() }
                    }
                    .labelStyle(.iconOnly)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", systemImage: "checkmark", action: save)
                        .labelStyle(.iconOnly)
                        .disabled(categoryID == nil || (try? parsed.get()) == nil)
                        .accessibilityIdentifier("saveBudget")
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { editingAmount = false }
                }
            }
            .interactiveDismissDisabled(hasChanges)
            .confirmationDialog("Discard changes?", isPresented: $discard, titleVisibility: .visible) {
                Button("Discard changes", role: .destructive) { dismiss() }
                Button("Keep editing", role: .cancel) {}
            }
            .confirmationDialog("Delete this budget?", isPresented: $delete, titleVisibility: .visible) {
                Button("Delete budget", role: .destructive) {
                    guard let budget else { return }
                    do {
                        try WalletStore.deleteBudget(context: context, budget: budget)
                        dismiss()
                    } catch { self.error = error.localizedDescription }
                }
                .accessibilityIdentifier("confirmDeleteBudget")
                Button("Cancel", role: .cancel) {}
            } message: { Text("Your transactions will be kept.") }
            .alert("Unable to complete the operation", isPresented: Binding(get: { error != nil }, set: { _ in error = nil })) {
                Button("OK", role: .cancel) { error = nil }
            } message: { Text(error ?? "") }
        }
    }

    private func save() {
        do {
            let limit = try parsed.get()
            if let budget {
                try WalletStore.updateBudgetLimit(context: context, budget: budget, limitMinor: limit)
            } else {
                guard let category = categories.first(where: { $0.id == categoryID }) else { throw WalletBudgetError.inactiveCategory }
                try WalletStore.createBudget(context: context, category: category, month: month, currencyCode: currency, limitMinor: limit)
            }
            dismiss()
        } catch { self.error = error.localizedDescription }
    }
}

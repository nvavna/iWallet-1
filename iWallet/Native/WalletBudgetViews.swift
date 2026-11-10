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
                        Label("Previous month", systemImage: "chevron.backward")
                            .frame(minWidth: 44, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                        .disabled(month.advanced(by: -1) == nil)
                        .accessibilityIdentifier("previousBudgetMonth")
                    Spacer()
                    Text(month.displayName(locale: locale))
                        .font(.system(.title3, design: .rounded, weight: .semibold))
                        .foregroundStyle(WalletTheme.ink)
                        .multilineTextAlignment(.center)
                        .accessibilityIdentifier("budgetMonth")
                    Spacer()
                    Button { moveMonth(1) } label: {
                        Label("Next month", systemImage: "chevron.forward")
                            .frame(minWidth: 44, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                        .disabled(month.advanced(by: 1) == nil)
                        .accessibilityIdentifier("nextBudgetMonth")
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .listRowBackground(WalletTheme.surface)
                Button(action: copyPreviousBudgets) {
                    Label("Copy last month’s budgets", systemImage: "doc.on.doc")
                }
                .font(.subheadline.weight(.medium))
                .listRowBackground(WalletTheme.surface)
                .disabled(month.advanced(by: -1) == nil)
                .accessibilityIdentifier("copyPreviousBudgets")
            } footer: {
                if let copyResult {
                    Text(copyResult).accessibilityIdentifier("budgetCopyResult")
                }
            }
            let visible = budgets.filter { $0.year == month.year && $0.month == month.month }
            if visible.isEmpty {
                WalletEmptyListRow(
                    title: "No budgets this month", systemImage: "gauge.with.dots.needle.50percent",
                    message: "Set a spending limit for a category.",
                    actionTitle: "New budget", actionIdentifier: "emptyBudgetAction"
                ) { editor = BudgetEditorRoute(budget: nil) }
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
                        .listRowBackground(WalletTheme.surface)
                    }
                }
            }
        }
        .accessibilityIdentifier("budgetList")
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(WalletTheme.background)
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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let budget: WalletBudget
    let category: WalletCategory?

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(spacing: 10) {
                CategoryBadge(category: category, size: 38).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(category?.name ?? String(localized: "Uncategorized")).font(.headline)
                    if category?.isArchived == true { Text("Archived").font(.caption) }
                    Text(verbatim: budget.currencyCode).font(.caption).foregroundStyle(WalletTheme.secondaryInk)
                }
                Spacer()
                Image(systemName: "chevron.forward").font(.caption.weight(.semibold))
                    .foregroundStyle(WalletTheme.secondaryInk).accessibilityHidden(true)
            }
            if let progress = try? budget.progress(transactions: category?.transactions ?? []) {
                let over = progress.remainingMinor < 0
                amount(over ? "Over budget" : "Remaining", abs(progress.remainingMinor),
                       font: .system(.title2, design: .rounded, weight: .semibold))
                    .foregroundStyle(over ? WalletTheme.expense : WalletTheme.income)
                ProgressView(value: min(1, Double(progress.spentMinor) / Double(budget.limitMinor)))
                    .tint(over ? WalletTheme.expense : WalletTheme.accent)
                    .accessibilityHidden(true)
                let layout = dynamicTypeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
                    : AnyLayout(HStackLayout(alignment: .top, spacing: 12))
                layout {
                    amount("Spent", progress.spentMinor)
                    amount("Budget limit", budget.limitMinor)
                }
            } else {
                Text("Unable to calculate this total.").foregroundStyle(WalletTheme.secondaryInk)
            }
        }
        .foregroundStyle(WalletTheme.ink)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private func amount(_ title: LocalizedStringKey, _ value: Int64, font: Font = .subheadline.weight(.semibold)) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.caption).foregroundStyle(WalletTheme.secondaryInk)
            Text(Money.format(value, currencyCode: budget.currencyCode)).font(font).monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
                Section("Budget limit") {
                    TextField("Amount", text: $amount,
                              prompt: Text("Amount").foregroundColor(WalletTheme.secondaryInk))
                        .font(.system(.largeTitle, design: .rounded, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(WalletTheme.ink)
                        .keyboardType(.decimalPad)
                        .focused($editingAmount)
                        .accessibilityIdentifier("budgetAmount")
                    if !amount.isEmpty, case .failure(let failure) = parsed {
                        Text(failure.localizedDescription).font(.footnote).foregroundStyle(WalletTheme.expense)
                    }
                }
                .listRowBackground(WalletTheme.surface)
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
                .listRowBackground(WalletTheme.surface)
                if budget != nil {
                    Button("Delete budget", role: .destructive) { delete = true }
                        .accessibilityIdentifier("deleteBudget")
                }
            }
            .scrollContentBackground(.hidden)
            .background(WalletTheme.background)
            .scrollDismissesKeyboard(.interactively)
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

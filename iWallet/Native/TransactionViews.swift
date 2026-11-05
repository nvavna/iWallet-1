import SwiftUI
import SwiftData

struct TransactionListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WalletTransaction.date, order: .reverse) private var transactions: [WalletTransaction]
    @State private var searchText = ""
    @State private var filter: TransactionFilter = .all
    @State private var editor: TransactionEditorPresentation?
    @State private var pendingDeletion: WalletTransaction?
    @State private var errorMessage: String?

    private var filteredTransactions: [WalletTransaction] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return transactions.filter { transaction in
            let matchesKind = filter.kind == nil || transaction.kind == filter.kind
            let matchesSearch = query.isEmpty
                || transaction.note.localizedStandardContains(query)
                || (transaction.category?.name.localizedStandardContains(query) ?? false)
                || transaction.currencyCode.localizedStandardContains(query)
            return matchesKind && matchesSearch
        }
    }

    private var groupedTransactions: [TransactionDay] {
        Dictionary(grouping: filteredTransactions) { Calendar.current.startOfDay(for: $0.date) }
            .map { TransactionDay(date: $0.key, transactions: $0.value) }
            .sorted { $0.date > $1.date }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Transaction type", selection: $filter) {
                        ForEach(TransactionFilter.allCases) { filter in
                            Text(LocalizedStringKey(filter.title)).tag(filter)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                    .listRowBackground(Color.clear)
                }

                if filteredTransactions.isEmpty {
                    Section {
                        if transactions.isEmpty {
                            ContentUnavailableView {
                                Label("Your story starts here", systemImage: "list.bullet.rectangle")
                            } description: {
                                Text("Add your first transaction to see your money in perspective.")
                            } actions: {
                                Button("Add transaction", systemImage: "plus") {
                                    editor = TransactionEditorPresentation()
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        } else {
                            ContentUnavailableView {
                                Label("No matching transactions", systemImage: "magnifyingglass")
                            } description: {
                                Text("Try a different search or transaction type.")
                            }
                        }
                    }
                    .listRowBackground(Color.clear)
                }

                ForEach(groupedTransactions) { day in
                    Section {
                        ForEach(day.transactions) { transaction in
                            Button {
                                editor = TransactionEditorPresentation(transaction: transaction)
                            } label: {
                                TransactionRow(transaction: transaction)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(WalletTheme.surface)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button("Delete", systemImage: "trash", role: .destructive) {
                                    pendingDeletion = transaction
                                }
                            }
                            .accessibilityHint("Edit transaction")
                        }
                    } header: {
                        Text(day.date, format: .dateTime.day().month(.wide).year())
                            .textCase(nil)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(WalletTheme.background)
            .navigationTitle("Transactions")
            .searchable(text: $searchText, prompt: "Search transactions")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add transaction", systemImage: "plus") {
                        editor = TransactionEditorPresentation()
                    }
                }
            }
            .sheet(item: $editor) { presentation in
                TransactionEditorView(transaction: presentation.transaction)
            }
            .confirmationDialog("Delete transaction?", isPresented: Binding(
                get: { pendingDeletion != nil },
                set: { if !$0 { pendingDeletion = nil } }
            ), titleVisibility: .visible) {
                if let transaction = pendingDeletion {
                    Button("Delete transaction", role: .destructive) {
                        do {
                            try WalletStore.deleteTransaction(context: modelContext, transaction: transaction)
                        } catch {
                            errorMessage = error.localizedDescription
                        }
                        pendingDeletion = nil
                    }
                }
                Button("Cancel", role: .cancel) { pendingDeletion = nil }
            } message: {
                Text("This transaction will be permanently removed.")
            }
            .alert("Unable to delete transaction", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }
}

struct TransactionEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @AppStorage("preferredCurrencyCode") private var preferredCurrencyCode = Locale.current.currency?.identifier ?? "USD"
    @Query(sort: \WalletCategory.name) private var categories: [WalletCategory]
    private enum Field: Hashable { case amount, note }
    @FocusState private var focusedField: Field?
    @State private var amountText = ""
    @State private var currencyCode = "USD"
    @State private var date = Date()
    @State private var note = ""
    @State private var kind: TransactionKind = .expense
    @State private var selectedCategoryID: UUID?
    @State private var hasLoadedDraft = false
    @State private var showsCategoryEditor = false
    @State private var amountError: String?
    @State private var saveError: String?

    let transaction: WalletTransaction?
    let initialCategory: WalletCategory?

    init(transaction: WalletTransaction? = nil, initialCategory: WalletCategory? = nil) {
        self.transaction = transaction
        self.initialCategory = initialCategory
    }

    private var availableCategories: [WalletCategory] {
        categories.filter {
            $0.kind == kind && (!$0.isArchived || $0.id == transaction?.category?.id)
        }
    }

    private var selectedCategory: WalletCategory? {
        availableCategories.first { $0.id == selectedCategoryID }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Transaction type", selection: $kind) {
                        Text(LocalizedStringKey(TransactionKind.expense.localizedName)).tag(TransactionKind.expense)
                        Text(LocalizedStringKey(TransactionKind.income.localizedName)).tag(TransactionKind.income)
                    }
                    .pickerStyle(.segmented)

                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        TextField("0", text: $amountText)
                            .font(.largeTitle.weight(.semibold))
                            .monospacedDigit()
                            .keyboardType(.decimalPad)
                            .focused($focusedField, equals: .amount)
                            .accessibilityLabel("Amount")
                            .accessibilityIdentifier("transactionAmount")
                        Text(currencyCode)
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 12)

                    if let amountError {
                        Label(amountError, systemImage: "exclamationmark.circle")
                            .font(.callout)
                            .foregroundStyle(.red)
                            .accessibilityIdentifier("transactionAmountError")
                    }
                } header: {
                    Text("Amount")
                }

                Section {
                    Picker("Category", selection: $selectedCategoryID) {
                        Text("Choose a category").tag(UUID?.none)
                        ForEach(availableCategories) { category in
                            Label(category.name, systemImage: category.icon)
                                .tag(Optional(category.id))
                        }
                    }
                    .accessibilityIdentifier("transactionCategory")

                    Button("New category", systemImage: "plus.circle") {
                        focusedField = nil
                        showsCategoryEditor = true
                    }
                } footer: {
                    if availableCategories.isEmpty {
                        Text("Create a category to organize this transaction.")
                    } else if selectedCategory?.isArchived == true {
                        Text("This category is archived. It is kept here for your existing transaction.")
                    }
                }

                Section {
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    TextField("Note (optional)", text: $note, axis: .vertical)
                        .focused($focusedField, equals: .note)
                        .lineLimit(2...5)
                        .textInputAutocapitalization(.sentences)
                        .accessibilityLabel("Note")
                        .accessibilityIdentifier("transactionNote")
                }

                Section {
                    Picker("Currency", selection: $currencyCode) {
                        ForEach(WalletCurrency.allCases) { currency in
                            Text(currency.displayName).tag(currency.rawValue)
                        }
                        if WalletCurrency(rawValue: currencyCode) == nil {
                            Text(currencyCode).tag(currencyCode)
                        }
                    }
                    .accessibilityIdentifier("transactionCurrency")
                } footer: {
                    Text("Changing the currency keeps the entered amount. No conversion is performed.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(WalletTheme.background)
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(transaction == nil ? Text("New transaction") : Text("Edit transaction"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .accessibilityIdentifier("saveTransaction")
                        .fontWeight(.semibold)
                        .disabled(amountText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedCategory == nil)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focusedField = nil }
                }
            }
            .onAppear(perform: loadDraft)
            .onChange(of: kind) { _, _ in
                if selectedCategory == nil { selectedCategoryID = nil }
            }
            .onChange(of: amountText) { _, _ in amountError = nil }
            .onChange(of: currencyCode) { _, _ in amountError = nil }
            .sheet(isPresented: $showsCategoryEditor) {
                CategoryEditorView(kind: kind) { category in
                    kind = category.kind
                    selectedCategoryID = category.id
                }
            }
            .alert("Unable to save transaction", isPresented: Binding(
                get: { saveError != nil },
                set: { if !$0 { saveError = nil } }
            )) {
                Button("OK", role: .cancel) { saveError = nil }
            } message: {
                Text(saveError ?? "")
            }
        }
    }

    private func loadDraft() {
        guard !hasLoadedDraft else { return }
        hasLoadedDraft = true
        if let transaction {
            kind = transaction.kind
            currencyCode = transaction.currencyCode
            amountText = Money.inputText(transaction.amountMinor, currencyCode: transaction.currencyCode)
            date = transaction.date
            note = transaction.note
            selectedCategoryID = transaction.category?.id
        } else {
            currencyCode = WalletCurrency(rawValue: preferredCurrencyCode)?.rawValue ?? "USD"
            if let initialCategory, !initialCategory.isArchived {
                kind = initialCategory.kind
                selectedCategoryID = initialCategory.id
            }
        }
    }

    private func save() {
        let amountMinor: Int64
        do {
            amountMinor = try Money.parse(amountText, currencyCode: currencyCode)
        } catch {
            amountError = error.localizedDescription
            focusedField = .amount
            return
        }
        guard let selectedCategory else { return }
        do {
            try WalletStore.saveTransaction(
                context: modelContext,
                transaction: transaction,
                amountMinor: amountMinor,
                currencyCode: currencyCode,
                date: date,
                note: note.trimmingCharacters(in: .whitespacesAndNewlines),
                kind: kind,
                category: selectedCategory
            )
            dismiss()
        } catch {
            saveError = error.localizedDescription
        }
    }

}

struct TransactionRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let transaction: WalletTransaction

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            CategoryBadge(category: transaction.category)
                .accessibilityHidden(true)

            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 8) {
                    details
                    amount
                }
            } else {
                details
                Spacer(minLength: 8)
                amount
                    .multilineTextAlignment(.trailing)
                    .layoutPriority(1)
            }
        }
        .padding(.vertical, 5)
        .accessibilityElement(children: .combine)
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let category = transaction.category {
                Text(category.name)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
            } else {
                Text("Uncategorized")
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
            }
            if !transaction.note.isEmpty {
                Text(transaction.note)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var amount: some View {
        VStack(alignment: dynamicTypeSize.isAccessibilitySize ? .leading : .trailing, spacing: 3) {
            Text((transaction.kind == .expense ? "−" : "+") + Money.format(transaction.amountMinor, currencyCode: transaction.currencyCode))
                .font(.body.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(transaction.kind == .income ? WalletTheme.accent : Color.primary)
            Text(transaction.currencyCode)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

private struct TransactionEditorPresentation: Identifiable {
    let id = UUID()
    var transaction: WalletTransaction? = nil
}

private struct TransactionDay: Identifiable {
    let date: Date
    let transactions: [WalletTransaction]
    var id: Date { date }
}

private enum TransactionFilter: String, CaseIterable, Identifiable {
    case all, expense, income
    var id: String { rawValue }
    var title: String {
        switch self {
        case .all: "All"
        case .expense: "Expenses"
        case .income: "Income"
        }
    }
    var kind: TransactionKind? {
        switch self {
        case .all: nil
        case .expense: .expense
        case .income: .income
        }
    }
}

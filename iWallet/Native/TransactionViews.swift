import SwiftUI
import SwiftData

struct TransactionListView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WalletTransaction.date, order: .reverse) private var transactions: [WalletTransaction]
    @Query private var categories: [WalletCategory]
    @State private var searchText = ""
    @State private var filter: TransactionFilter = .all
    @State private var editor: TransactionEditorPresentation?
    @State private var pendingDeletion: WalletTransaction?
    @State private var errorMessage: String?

    var categoryID: UUID? = nil
    var categoryName: String? = nil
    var onlyUncategorized = false
    var currencyCode: String? = nil
    var isPresentedModally = true

    private var isCategoryHistory: Bool { categoryID != nil || onlyUncategorized }
    private var initialCategory: WalletCategory? { categories.first { $0.id == categoryID } }

    private var filteredTransactions: [WalletTransaction] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return transactions.filter { transaction in
            let matchesKind = filter.kind == nil || transaction.kind == filter.kind
            let matchesSearch = query.isEmpty
                || transaction.note.localizedStandardContains(query)
                || (transaction.category?.name.localizedStandardContains(query) ?? false)
                || transaction.currencyCode.localizedStandardContains(query)
            let matchesCategory = onlyUncategorized
                ? transaction.category == nil
                : categoryID == nil || transaction.category?.id == categoryID
            let matchesCurrency = currencyCode == nil || transaction.currencyCode == currencyCode
            return matchesKind && matchesSearch && matchesCategory && matchesCurrency
        }
    }

    private var groupedTransactions: [TransactionDay] {
        Dictionary(grouping: filteredTransactions) { Calendar.current.startOfDay(for: $0.date) }
            .map { TransactionDay(date: $0.key, transactions: $0.value) }
            .sorted { $0.date > $1.date }
    }

    var body: some View {
        if isCategoryHistory {
            historyContent
        } else {
            NavigationStack { historyContent }
        }
    }

    private var historyContent: some View {
        List {
            Section {
                Picker("Transaction type", selection: $filter) {
                    ForEach(TransactionFilter.allCases) { filter in
                        Text(LocalizedStringKey(filter.title)).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("transactionFilter")
                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                .listRowBackground(Color.clear)
            } footer: {
                if isCategoryHistory {
                    HStack {
                        Text("All time")
                        Spacer()
                        if let currencyCode { Text(currencyCode) }
                    }
                }
            }

            if filteredTransactions.isEmpty {
                Section {
                    if transactions.isEmpty {
                        WalletEmptyListRow(
                            title: "Your story starts here", systemImage: "list.bullet.rectangle",
                            message: "Add your first transaction to see your money in perspective.",
                            actionTitle: "Add transaction", actionIdentifier: "emptyTransactionAction"
                        ) {
                            editor = TransactionEditorPresentation()
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
                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                            repeatButton(for: transaction)
                                .tint(WalletTheme.accent)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button("Delete", systemImage: "trash", role: .destructive) {
                                pendingDeletion = transaction
                            }
                        }
                        .contextMenu {
                            repeatButton(for: transaction)
                            Button("Delete transaction", systemImage: "trash", role: .destructive) {
                                pendingDeletion = transaction
                            }
                        }
                        .accessibilityAction(named: Text("Repeat transaction")) {
                            repeatTransaction(transaction)
                        }
                        .accessibilityAction(named: Text("Delete transaction")) {
                            pendingDeletion = transaction
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
        .navigationTitle(categoryName ?? String(localized: "Transactions"))
        .navigationBarTitleDisplayMode(isPresentedModally || isCategoryHistory ? .inline : .large)
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always),
                    prompt: "Search transactions")
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            if isPresentedModally && !isCategoryHistory {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            if !isCategoryHistory || initialCategory?.isArchived == false {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add transaction", systemImage: "plus") {
                        editor = TransactionEditorPresentation()
                    }
                }
            }
        }
        .sheet(item: $editor) { presentation in
            TransactionEditorView(transaction: presentation.transaction, repeatedDraft: presentation.repeatedDraft,
                                  initialCategory: initialCategory, initialCurrencyCode: currencyCode)
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

    private func repeatButton(for transaction: WalletTransaction) -> some View {
        Button("Repeat transaction", systemImage: "arrow.clockwise") {
            repeatTransaction(transaction)
        }
        .accessibilityIdentifier("repeatTransaction")
    }

    private func repeatTransaction(_ transaction: WalletTransaction) {
        editor = TransactionEditorPresentation(repeatedDraft: .repeating(transaction))
    }
}

struct TransactionEditorView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @AppStorage("preferredCurrencyCode") private var preferredCurrencyCode = Locale.current.currency?.identifier ?? "USD"
    @Query(sort: \WalletCategory.name) private var categories: [WalletCategory]
    private enum Field: Hashable { case amount, note }
    @FocusState private var focusedField: Field?
    @State private var draft = WalletTransactionDraft()
    @State private var showsCategoryEditor = false
    @State private var amountError: String?
    @State private var saveError: String?
    @State private var initialDraft: WalletTransactionDraft?
    @State private var showsDiscardConfirmation = false

    let transaction: WalletTransaction?
    let repeatedDraft: WalletTransactionDraft?
    let initialCategory: WalletCategory?
    let initialKind: TransactionKind
    let initialCurrencyCode: String?

    init(transaction: WalletTransaction? = nil, repeatedDraft: WalletTransactionDraft? = nil,
         initialCategory: WalletCategory? = nil, initialKind: TransactionKind = .expense,
         initialCurrencyCode: String? = nil) {
        self.transaction = transaction
        self.repeatedDraft = repeatedDraft
        self.initialCategory = initialCategory
        self.initialKind = initialKind
        self.initialCurrencyCode = initialCurrencyCode
    }

    private var availableCategories: [WalletCategory] {
        categories.filter {
            $0.kind == draft.kind && (!$0.isArchived || $0.id == transaction?.category?.id)
        }
    }

    private var selectedCategory: WalletCategory? {
        availableCategories.first { $0.id == draft.categoryID }
    }

    private var hasUnsavedChanges: Bool {
        guard let initialDraft else { return false }
        return draft != initialDraft
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Transaction type", selection: $draft.kind) {
                        Text(LocalizedStringKey(TransactionKind.expense.localizedName)).tag(TransactionKind.expense)
                        Text(LocalizedStringKey(TransactionKind.income.localizedName)).tag(TransactionKind.income)
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("transactionType")
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                    .listRowBackground(Color.clear)
                }

                Section {
                    let amountLayout = dynamicTypeSize.isAccessibilitySize
                        ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
                        : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 12))
                    amountLayout {
                        TextField("0", text: $draft.amountText)
                            .font(.largeTitle.weight(.medium))
                            .monospacedDigit()
                            .keyboardType(.decimalPad)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .focused($focusedField, equals: .amount)
                            .accessibilityLabel("Amount")
                            .accessibilityIdentifier("transactionAmount")
                        Text(draft.currencyCode)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                    .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }

                    if let amountError {
                        Label(amountError, systemImage: "exclamationmark.circle")
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("transactionAmountError")
                    }

                    Menu {
                        Picker("Currency", selection: $draft.currencyCode) {
                            ForEach(WalletCurrency.allCases) { currency in
                                Text(currency.displayName).tag(currency.rawValue)
                            }
                            if WalletCurrency(rawValue: draft.currencyCode) == nil {
                                Text(draft.currencyCode).tag(draft.currencyCode)
                            }
                        }
                    } label: {
                        WalletFormMenuLabel("Currency", value: WalletCurrency(rawValue: draft.currencyCode)?.displayName ?? draft.currencyCode)
                    }
                    .accessibilityIdentifier("transactionCurrency")
                } header: {
                    Text("Amount")
                } footer: {
                    Text("Changing the currency keeps the entered amount. No conversion is performed.")
                }

                Section {
                    Menu {
                        Picker("Category", selection: $draft.categoryID) {
                            Text("Choose a category").tag(UUID?.none)
                            ForEach(availableCategories) { category in
                                Label(category.name, systemImage: WalletTheme.categorySymbol(category.icon))
                                    .tag(Optional(category.id))
                            }
                        }
                    } label: {
                        WalletFormMenuLabel("Category", value: selectedCategory?.name ?? String(localized: "Choose a category"))
                    }
                    .accessibilityIdentifier("transactionCategory")

                    Button("New category", systemImage: "plus") {
                        focusedField = nil
                        showsCategoryEditor = true
                    }
                } footer: {
                    if availableCategories.isEmpty {
                        Text("Create a category to organize this transaction.")
                    } else if repeatedDraft != nil && selectedCategory == nil {
                        Text("Choose an active category for the new transaction.")
                    } else if selectedCategory?.isArchived == true {
                        Text("This category is archived. It is kept here for your existing transaction.")
                    }
                }

                Section("Details") {
                    DatePicker(selection: $draft.date, displayedComponents: .date) {
                        Label("Date", systemImage: "calendar")
                    }
                    .accessibilityIdentifier("transactionDate")
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Note (optional)", systemImage: "text.alignleft")
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                            .fixedSize(horizontal: false, vertical: true)
                        TextField("", text: $draft.note, axis: .vertical)
                            .focused($focusedField, equals: .note)
                            .lineLimit(1...5)
                            .textInputAutocapitalization(.sentences)
                            .accessibilityLabel("Note")
                            .accessibilityIdentifier("transactionNote")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(WalletTheme.background)
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(transaction == nil ? Text("New transaction") : Text("Edit transaction"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark", role: .cancel, action: cancel)
                        .labelStyle(.iconOnly)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", systemImage: "checkmark", action: save)
                        .labelStyle(.iconOnly)
                        .accessibilityIdentifier("saveTransaction")
                        .fontWeight(.semibold)
                        .disabled(draft.amountText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedCategory == nil)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focusedField = nil }
                }
            }
            .onAppear(perform: loadDraft)
            .onChange(of: draft.kind) { _, _ in
                if selectedCategory == nil { draft.categoryID = nil }
            }
            .onChange(of: draft.amountText) { _, _ in amountError = nil }
            .onChange(of: draft.currencyCode) { _, _ in amountError = nil }
            .navigationDestination(isPresented: $showsCategoryEditor) {
                CategoryEditorView(kind: draft.kind, isPresentedModally: false) { category in
                    draft.kind = category.kind
                    draft.categoryID = category.id
                }
            }
            .confirmationDialog("Discard changes?", isPresented: $showsDiscardConfirmation,
                                titleVisibility: .visible) {
                Button("Discard changes", role: .destructive) { dismiss() }
                Button("Keep editing", role: .cancel) { }
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
        .interactiveDismissDisabled(hasUnsavedChanges || showsCategoryEditor)
    }

    private func loadDraft() {
        guard initialDraft == nil else { return }
        if let transaction {
            draft = .editing(transaction)
        } else if let repeatedDraft {
            draft = repeatedDraft
        } else {
            draft.kind = initialKind
            draft.currencyCode = WalletCurrency(rawValue: initialCurrencyCode ?? preferredCurrencyCode)?.rawValue ?? "USD"
            if let initialCategory, !initialCategory.isArchived {
                draft.kind = initialCategory.kind
                draft.categoryID = initialCategory.id
            }
        }
        initialDraft = draft
    }

    private func cancel() {
        focusedField = nil
        if hasUnsavedChanges {
            showsDiscardConfirmation = true
        } else {
            dismiss()
        }
    }

    private func save() {
        let amountMinor: Int64
        do {
            amountMinor = try Money.parse(draft.amountText, currencyCode: draft.currencyCode)
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
                currencyCode: draft.currencyCode,
                date: draft.date,
                note: draft.note,
                kind: draft.kind,
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
        HStack(alignment: .top, spacing: 12) {
            CategoryBadge(category: transaction.category)
                .accessibilityHidden(true)
            if dynamicTypeSize.isAccessibilitySize {
                verticalContent
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 12) {
                        details.frame(minWidth: 100)
                        amount(singleLine: true)
                    }
                    verticalContent
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(transaction.category?.name ?? String(localized: "Uncategorized"))
                .font(.body.weight(.medium))
                .foregroundStyle(.primary)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
            if !transaction.note.isEmpty {
                Text(transaction.note)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var verticalContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            details
            amount(singleLine: false)
        }
    }

    private func amount(singleLine: Bool) -> some View {
        VStack(alignment: singleLine ? .trailing : .leading, spacing: 3) {
            Text((transaction.kind == .expense ? "−" : "+") + Money.format(transaction.amountMinor, currencyCode: transaction.currencyCode))
                .font(.body.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(.primary)
                .fixedSize(horizontal: singleLine, vertical: true)
            Text(transaction.currencyCode)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .multilineTextAlignment(singleLine ? .trailing : .leading)
        .layoutPriority(1)
    }
}

private struct TransactionEditorPresentation: Identifiable {
    let id = UUID()
    var transaction: WalletTransaction? = nil
    var repeatedDraft: WalletTransactionDraft? = nil
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

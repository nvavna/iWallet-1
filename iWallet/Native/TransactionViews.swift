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
        let days = groupedTransactions
        return List {
            Section {
                Picker("Transaction type", selection: $filter) {
                    ForEach(TransactionFilter.allCases) { filter in
                        Text(LocalizedStringKey(filter.title)).tag(filter)
                    }
                }
                .walletChoiceStyle()
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

            if days.isEmpty {
                Section {
                    if transactions.isEmpty {
                        WalletEmptyListRow(
                            title: "Your story starts here", systemImage: "arrow.left.arrow.right",
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

            ForEach(days) { day in
                Section {
                    ForEach(day.transactions) { transaction in
                        Button {
                            editor = TransactionEditorPresentation(transaction: transaction)
                        } label: {
                            TransactionRow(transaction: transaction)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .listRowInsets(EdgeInsets(top: 3, leading: 14, bottom: 3, trailing: 14))
                        .listRowBackground(WalletTheme.surface)
                        .listRowSeparatorTint(WalletTheme.hairline)
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
                    dayHeader(day.date)
                }
            }
        }
        .listStyle(.insetGrouped)
        .listSectionSpacing(16)
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
                                  initialCategory: initialCategory, initialKind: filter.kind ?? .expense,
                                  initialCurrencyCode: currencyCode)
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

    private static let relativeDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.dateStyle = .medium
        formatter.doesRelativeDateFormatting = true
        return formatter
    }()

    private func dayHeader(_ date: Date) -> some View {
        let calendar = Calendar.current
        let recent = calendar.isDateInToday(date) || calendar.isDateInYesterday(date)
        return HStack(alignment: .firstTextBaseline, spacing: 8) {
            if recent {
                Text(verbatim: Self.relativeDayFormatter.string(from: date))
            } else if calendar.isDate(date, equalTo: Date(), toGranularity: .year) {
                Text(date, format: .dateTime.weekday(.wide).day().month(.wide))
            } else {
                Text(date, format: .dateTime.day().month(.wide).year())
            }
            if recent {
                Spacer(minLength: 8)
                Text(date, format: .dateTime.day().month(.abbreviated))
                    .font(.caption)
                    .foregroundStyle(WalletTheme.secondaryInk)
            }
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(WalletTheme.ink)
        .textCase(nil)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
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
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    amountCard
                    categorySection
                    detailSection
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .frame(maxWidth: 620)
                .frame(maxWidth: .infinity)
            }
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
                    Button(action: save) {
                        if dynamicTypeSize.isAccessibilitySize {
                            Label("Save", systemImage: "checkmark").labelStyle(.iconOnly)
                        } else {
                            Text("Save")
                        }
                    }
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

    private var kindColor: Color {
        draft.kind == .expense ? WalletTheme.expense : WalletTheme.income
    }

    private var amountCard: some View {
        let header = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
            : AnyLayout(HStackLayout(spacing: 10))
        return VStack(alignment: .leading, spacing: 12) {
            header {
                Label("Amount", systemImage: draft.kind == .expense ? "arrow.up.right" : "arrow.down.left")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(kindColor)
                if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 4) }
                currencyMenu
            }
            TextField(0.formatted(), text: $draft.amountText,
                      prompt: Text(0.formatted()).foregroundColor(WalletTheme.secondaryInk))
                .font(.system(.largeTitle, design: .rounded, weight: .semibold))
                .fontWidth(.expanded)
                .monospacedDigit()
                .textFieldStyle(.plain)
                .foregroundStyle(WalletTheme.ink)
                .keyboardType(.decimalPad)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focusedField, equals: .amount)
                .accessibilityLabel("Amount")
                .accessibilityIdentifier("transactionAmount")
                .frame(minHeight: 54)

            if let amountError {
                Label(amountError, systemImage: "exclamationmark.circle")
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("transactionAmountError")
            }
            if let initialDraft, draft.currencyCode != initialDraft.currencyCode, !draft.amountText.isEmpty {
                Text("Changing the currency keeps the entered amount. No conversion is performed.")
                    .font(.footnote)
                    .foregroundStyle(WalletTheme.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Picker("Transaction type", selection: $draft.kind) {
                Text("Expense").tag(TransactionKind.expense)
                Text("Income").tag(TransactionKind.income)
            }
            .walletChoiceStyle()
            .accessibilityIdentifier("transactionType")
        }
        .padding(18)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(WalletTheme.surface)
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(kindColor.opacity(0.07))
                }
        }
    }

    private var currencyMenu: some View {
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
            HStack(spacing: 6) {
                Text(draft.currencyCode).font(.subheadline.weight(.semibold))
                Image(systemName: "chevron.down").font(.caption2.weight(.bold))
            }
            .foregroundStyle(WalletTheme.ink)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(WalletTheme.surface, in: Capsule())
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .accessibilityLabel("Currency")
        .accessibilityValue(draft.currencyCode)
        .accessibilityIdentifier("transactionCurrency")
    }

    private var categorySection: some View {
        let header = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 2))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 10))
        return VStack(alignment: .leading, spacing: 7) {
            header {
                Text("Category").font(.headline).foregroundStyle(WalletTheme.ink)
                    .accessibilityAddTraits(.isHeader)
                if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 0) }
                Button("New category", systemImage: "plus") {
                    focusedField = nil
                    showsCategoryEditor = true
                }
                .font(.subheadline.weight(.medium))
                .frame(minHeight: 44)
            }
            Menu {
                Picker("Category", selection: $draft.categoryID) {
                    Text("Choose a category").tag(UUID?.none)
                    ForEach(availableCategories) { category in
                        Label(category.name, systemImage: WalletTheme.categorySymbol(category.icon))
                            .tag(Optional(category.id))
                    }
                }
            } label: {
                HStack(spacing: 12) {
                    CategoryBadge(category: selectedCategory, size: 36)
                        .accessibilityHidden(true)
                    Text(selectedCategory?.name ?? String(localized: "Choose a category"))
                        .font(.body.weight(.medium))
                        .multilineTextAlignment(.leading)
                        .foregroundStyle(WalletTheme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(WalletTheme.secondaryInk)
                        .accessibilityHidden(true)
                }
                .padding(14)
                .frame(maxWidth: .infinity)
                .background(WalletTheme.surface, in: RoundedRectangle(cornerRadius: 18))
                .contentShape(Rectangle())
            }
            .accessibilityIdentifier("transactionCategory")
            Group {
                if availableCategories.isEmpty {
                    Text("Create a category to organize this transaction.")
                } else if repeatedDraft != nil && selectedCategory == nil {
                    Text("Choose an active category for the new transaction.")
                } else if selectedCategory?.isArchived == true {
                    Text("This category is archived. It is kept here for your existing transaction.")
                }
            }
            .font(.footnote)
            .foregroundStyle(WalletTheme.secondaryInk)
        }
    }

    private var detailSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Details")
                .font(.headline)
                .foregroundStyle(WalletTheme.ink)
                .accessibilityAddTraits(.isHeader)
            VStack(alignment: .leading, spacing: 0) {
                let dateLayout = dynamicTypeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6))
                    : AnyLayout(HStackLayout(spacing: 8))
                dateLayout {
                    Label("Date", systemImage: "calendar")
                        .accessibilityHidden(true)
                    if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 0) }
                    DatePicker("Date", selection: $draft.date, displayedComponents: .date)
                        .labelsHidden()
                        .accessibilityIdentifier("transactionDate")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 10)

                Divider().overlay(WalletTheme.hairline)

                HStack(alignment: .center, spacing: 9) {
                    Image(systemName: "text.alignleft")
                        .foregroundStyle(WalletTheme.secondaryInk)
                        .accessibilityHidden(true)
                    TextField("Note (optional)", text: $draft.note,
                              prompt: Text(dynamicTypeSize.isAccessibilitySize
                                           ? LocalizedStringKey("Note") : "Note (optional)")
                                  .foregroundColor(WalletTheme.secondaryInk),
                              axis: .vertical)
                        .textFieldStyle(.plain)
                        .focused($focusedField, equals: .note)
                        .lineLimit(1...5)
                        .textInputAutocapitalization(.sentences)
                        .accessibilityLabel("Note")
                        .accessibilityIdentifier("transactionNote")
                        .frame(minHeight: 44)
                }
                .padding(.vertical, 4)
            }
            .foregroundStyle(WalletTheme.ink)
            .padding(.horizontal, 16)
            .background(WalletTheme.surface, in: RoundedRectangle(cornerRadius: 18))
        }
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
    var showsDate = false

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            CategoryBadge(category: transaction.category, size: 40)
                .accessibilityHidden(true)
            if dynamicTypeSize.isAccessibilitySize {
                verticalContent
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        details.frame(minWidth: 100)
                        Spacer(minLength: 0)
                        amount(singleLine: true)
                    }
                    verticalContent
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 9)
        .accessibilityElement(children: .combine)
    }

    private var details: some View {
        let category = transaction.category?.name ?? String(localized: "Uncategorized")
        return VStack(alignment: .leading, spacing: 4) {
            Text(transaction.note.isEmpty ? category : transaction.note)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(WalletTheme.ink)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
            if !transaction.note.isEmpty {
                Text(category)
                    .font(.caption)
                    .foregroundStyle(WalletTheme.secondaryInk)
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
        let formatted = Money.format(transaction.amountMinor, currencyCode: transaction.currencyCode)
        let signed = (transaction.kind == .expense ? "−" : "+") + formatted
        return VStack(alignment: singleLine ? .trailing : .leading, spacing: 4) {
            Text(verbatim: signed)
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(transaction.kind == .income ? WalletTheme.income : WalletTheme.ink)
                .fixedSize(horizontal: singleLine, vertical: true)
                .accessibilityLabel(Text(verbatim: formatted.contains(transaction.currencyCode)
                                         ? signed : "\(signed) \(transaction.currencyCode)"))
            if showsDate {
                let sameYear = Calendar.current.isDate(transaction.date, equalTo: .now, toGranularity: .year)
                let format = Date.FormatStyle().day().month(.abbreviated)
                Text(transaction.date, format: sameYear ? format : format.year())
                    .font(.caption)
                    .foregroundStyle(WalletTheme.secondaryInk)
            }
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

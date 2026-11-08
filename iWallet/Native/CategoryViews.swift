import SwiftUI
import SwiftData

struct CategoryListView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WalletCategory.name) private var categories: [WalletCategory]
    @State private var kind: TransactionKind = .expense
    @State private var showsEditor = false
    @State private var pendingArchive: WalletCategory?
    @State private var errorMessage: String?
    private let isPushed: Bool

    init(isPushed: Bool = false) {
        self.isPushed = isPushed
    }

    private var activeCategories: [WalletCategory] {
        categories.filter { $0.kind == kind && !$0.isArchived }
    }

    var body: some View {
        if isPushed {
            content
        } else {
            NavigationStack { content }
        }
    }

    private var content: some View {
        List {
            Section {
                Picker("Category type", selection: $kind) {
                    Text(LocalizedStringKey(TransactionKind.expense.localizedName)).tag(TransactionKind.expense)
                    Text(LocalizedStringKey(TransactionKind.income.localizedName)).tag(TransactionKind.income)
                }
                .pickerStyle(.segmented)
                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                .listRowBackground(Color.clear)
            }

            if activeCategories.isEmpty {
                WalletEmptyListRow(
                    title: "Make room for what matters", systemImage: "square.grid.2x2",
                    message: "Create categories that match your everyday life.",
                    actionTitle: "Add category", actionIdentifier: "emptyCategoryAction"
                ) {
                    showsEditor = true
                }
            } else {
                Section {
                    ForEach(activeCategories) { category in
                        HStack(spacing: 12) {
                            CategoryBadge(category: category)
                                .accessibilityHidden(true)
                            Text(category.name)
                                .font(.body)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 0)
                        }
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.vertical, 4)
                        .listRowBackground(WalletTheme.surface)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button("Archive", systemImage: "archivebox") {
                                pendingArchive = category
                            }
                            .tint(.orange)
                        }
                        .contextMenu {
                            Button("Archive category", systemImage: "archivebox") {
                                pendingArchive = category
                            }
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityAction(named: Text("Archive category")) {
                            pendingArchive = category
                        }
                    }
                } footer: {
                    Text("Archiving a category preserves its transactions in your history.")
                }
            }
        }
        .listStyle(.insetGrouped)
        .accessibilityIdentifier("walletCategoryList")
        .scrollContentBackground(.hidden)
        .background(WalletTheme.background)
        .navigationTitle("Categories")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !isPushed {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Add category", systemImage: "plus") { showsEditor = true }
            }
        }
        .sheet(isPresented: $showsEditor) {
            CategoryEditorView(kind: kind)
        }
        .confirmationDialog("Archive category?", isPresented: Binding(
            get: { pendingArchive != nil },
            set: { if !$0 { pendingArchive = nil } }
        ), titleVisibility: .visible) {
            if let category = pendingArchive {
                Button("Archive category") {
                    do {
                        try WalletStore.archiveCategory(context: modelContext, category: category)
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                    pendingArchive = nil
                }
            }
            Button("Cancel", role: .cancel) { pendingArchive = nil }
        } message: {
            Text("It will be hidden when adding transactions. Existing transactions will stay in your history.")
        }
        .alert("Unable to archive category", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }
}

struct CategoryEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var kind: TransactionKind
    @State private var name = ""
    @State private var icon = "cart"
    @State private var color = "colorBlue"
    @State private var errorMessage: String?
    @State private var showsDiscardConfirmation = false
    private let initialKind: TransactionKind
    private let isPresentedModally: Bool
    private let allowKindSelection: Bool
    private let onSave: ((WalletCategory) -> Void)?
    private let columns = [GridItem(.adaptive(minimum: 48), spacing: 12)]

    private var selectedIconTitle: String {
        CategoryIconChoice.all.first { $0.symbol == icon }?.title ?? "Other"
    }

    private var selectedColorTitle: String {
        CategoryColorChoice.all.first { $0.asset == color }?.title ?? "Blue"
    }

    private var hasChanges: Bool {
        !name.isEmpty || icon != "cart" || color != "colorBlue" || kind != initialKind
    }

    init(
        kind: TransactionKind = .expense,
        isPresentedModally: Bool = true,
        allowKindSelection: Bool = true,
        onSave: ((WalletCategory) -> Void)? = nil
    ) {
        _kind = State(initialValue: kind)
        initialKind = kind
        self.isPresentedModally = isPresentedModally
        self.allowKindSelection = allowKindSelection
        self.onSave = onSave
    }

    var body: some View {
        if isPresentedModally {
            NavigationStack { content }
                .interactiveDismissDisabled(hasChanges)
        } else {
            content
        }
    }

    private var content: some View {
        Form {
            Section {
                HStack(spacing: 12) {
                    CategorySymbolBadge(symbol: icon, color: color, size: 44)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 4) {
                        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text("Category name")
                                .foregroundStyle(.secondary)
                        } else {
                            Text(name)
                        }
                        Text(LocalizedStringKey(kind.localizedName))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 4)
                .accessibilityElement(children: .combine)
            }

            Section {
                TextField("Category name", text: $name)
                    .accessibilityIdentifier("categoryName")
                    .textInputAutocapitalization(.sentences)
                    .submitLabel(.done)
                if allowKindSelection {
                    Picker("Category type", selection: $kind) {
                        Text(LocalizedStringKey(TransactionKind.expense.localizedName)).tag(TransactionKind.expense)
                        Text(LocalizedStringKey(TransactionKind.income.localizedName)).tag(TransactionKind.income)
                    }
                    .pickerStyle(.segmented)
                }
            }

            Section {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(CategoryIconChoice.all) { choice in
                        Button {
                            icon = choice.symbol
                        } label: {
                            Image(systemName: choice.symbol)
                                .font(.system(size: 22, weight: .semibold))
                                .symbolRenderingMode(.hierarchical)
                                .foregroundStyle(icon == choice.symbol ? WalletTheme.categoryColor(color) : Color.secondary)
                                .frame(width: 48, height: 48)
                                .background(icon == choice.symbol ? WalletTheme.categoryColor(color).opacity(0.12) : Color.clear,
                                            in: RoundedRectangle(cornerRadius: 12))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 12)
                                        .strokeBorder(icon == choice.symbol ? Color.primary : Color.secondary.opacity(0.18),
                                                      lineWidth: icon == choice.symbol ? 2 : 1)
                                }
                                .overlay(alignment: .topTrailing) {
                                    if icon == choice.symbol {
                                        selectionIndicator
                                            .offset(x: 4, y: -4)
                                    }
                                }
                                .contentShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text(LocalizedStringKey(choice.title)))
                        .accessibilityAddTraits(icon == choice.symbol ? .isSelected : [])
                    }
                }
                .padding(.vertical, 8)
            } header: {
                Text("Icon")
            } footer: {
                Text(LocalizedStringKey(selectedIconTitle))
            }

            Section {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(CategoryColorChoice.all) { choice in
                        Button {
                            color = choice.asset
                        } label: {
                            Circle()
                                .fill(WalletTheme.categoryColor(choice.asset))
                                .frame(width: 32, height: 32)
                                .frame(width: 48, height: 48)
                                .contentShape(Rectangle())
                                .overlay {
                                    RoundedRectangle(cornerRadius: 12)
                                        .strokeBorder(color == choice.asset ? Color.primary : Color.clear, lineWidth: 2)
                                }
                                .overlay(alignment: .topTrailing) {
                                    if color == choice.asset {
                                        selectionIndicator
                                            .offset(x: 4, y: -4)
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text(LocalizedStringKey(choice.title)))
                        .accessibilityAddTraits(color == choice.asset ? .isSelected : [])
                    }
                }
                .padding(.vertical, 8)
            } header: {
                Text("Color")
            } footer: {
                Text(LocalizedStringKey(selectedColorTitle))
            }
        }
        .scrollContentBackground(.hidden)
        .background(WalletTheme.background)
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("New category")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(!isPresentedModally)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel", systemImage: "xmark", action: cancel)
                    .labelStyle(.iconOnly)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", systemImage: "checkmark", action: save)
                    .labelStyle(.iconOnly)
                    .accessibilityIdentifier("saveCategory")
                    .fontWeight(.semibold)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .confirmationDialog("Discard changes?", isPresented: $showsDiscardConfirmation, titleVisibility: .visible) {
            Button("Discard changes", role: .destructive) { dismiss() }
            Button("Keep editing", role: .cancel) { }
        }
        .alert("Unable to save category", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var selectionIndicator: some View {
        Image(systemName: "checkmark")
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(WalletTheme.surface)
            .frame(width: 18, height: 18)
            .background(Color.primary, in: Circle())
            .accessibilityHidden(true)
    }

    private func cancel() {
        if hasChanges {
            showsDiscardConfirmation = true
        } else {
            dismiss()
        }
    }

    private func save() {
        do {
            let category = try WalletStore.saveCategory(
                context: modelContext,
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                icon: icon,
                color: color,
                kind: kind
            )
            onSave?(category)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct CategoryBadge: View {
    let category: WalletCategory?
    var size: CGFloat = 32

    var body: some View {
        CategorySymbolBadge(
            symbol: category?.icon ?? "square.grid.2x2",
            color: category?.color ?? "colorGray",
            size: size
        )
    }
}

private struct CategorySymbolBadge: View {
    let symbol: String
    let color: String
    let size: CGFloat

    var body: some View {
        Image(systemName: WalletTheme.categorySymbol(symbol))
            .font(.system(size: size * 0.48, weight: .semibold))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(WalletTheme.categoryColor(color))
            .frame(width: size, height: size)
            .background(WalletTheme.categoryColor(color).opacity(0.12),
                        in: RoundedRectangle(cornerRadius: 9))
    }
}

private struct CategoryIconChoice: Identifiable {
    let symbol: String
    let title: String
    var id: String { symbol }

    static let all = [
        Self(symbol: "cart", title: "Groceries"),
        Self(symbol: "fork.knife", title: "Dining"),
        Self(symbol: "cup.and.saucer", title: "Coffee"),
        Self(symbol: "house", title: "Home"),
        Self(symbol: "car", title: "Car"),
        Self(symbol: "bus", title: "Transport"),
        Self(symbol: "airplane", title: "Travel"),
        Self(symbol: "bag", title: "Shopping"),
        Self(symbol: "tshirt", title: "Clothing"),
        Self(symbol: "heart", title: "Health"),
        Self(symbol: "pills", title: "Medicine"),
        Self(symbol: "gamecontroller", title: "Games"),
        Self(symbol: "film", title: "Entertainment"),
        Self(symbol: "graduationcap", title: "Education"),
        Self(symbol: "pawprint", title: "Pets"),
        Self(symbol: "gift", title: "Gifts"),
        Self(symbol: "briefcase", title: "Work"),
        Self(symbol: "banknote", title: "Cash"),
        Self(symbol: "creditcard", title: "Card"),
        Self(symbol: "building.columns", title: "Bank"),
        Self(symbol: "phone", title: "Phone"),
        Self(symbol: "sportscourt", title: "Sports"),
        Self(symbol: "sparkles", title: "Personal care"),
        Self(symbol: "folder", title: "Other")
    ]
}

private struct CategoryColorChoice: Identifiable {
    let asset: String
    let title: String
    var id: String { asset }

    static let all = [
        Self(asset: "colorBlue", title: "Blue"),
        Self(asset: "colorGreen", title: "Green"),
        Self(asset: "colorRed", title: "Red"),
        Self(asset: "colorYellow", title: "Yellow"),
        Self(asset: "colorPurple", title: "Purple"),
        Self(asset: "colorBrown", title: "Brown"),
        Self(asset: "colorGray", title: "Gray")
    ]
}

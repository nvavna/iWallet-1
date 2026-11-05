import SwiftUI
import SwiftData

struct CategoryListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WalletCategory.name) private var categories: [WalletCategory]
    @State private var kind: TransactionKind = .expense
    @State private var showsEditor = false
    @State private var pendingArchive: WalletCategory?
    @State private var errorMessage: String?

    private var activeCategories: [WalletCategory] {
        categories.filter { $0.kind == kind && !$0.isArchived }
    }

    var body: some View {
        NavigationStack {
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
                    ContentUnavailableView {
                        Label("Make room for what matters", systemImage: "square.grid.2x2")
                    } description: {
                        Text("Create categories that match your everyday life.")
                    } actions: {
                        Button("Add category", systemImage: "plus") { showsEditor = true }
                            .buttonStyle(.borderedProminent)
                    }
                    .listRowBackground(Color.clear)
                } else {
                    Section {
                        ForEach(activeCategories) { category in
                            HStack(spacing: 12) {
                                CategoryBadge(category: category)
                                    .accessibilityHidden(true)
                                Text(category.name)
                                    .font(.body.weight(.medium))
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: 0)
                            }
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
            .scrollContentBackground(.hidden)
            .background(WalletTheme.background)
            .navigationTitle("Categories")
            .toolbar {
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
}

struct CategoryEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var kind: TransactionKind
    @State private var name = ""
    @State private var icon = "cart"
    @State private var color = "colorBlue"
    @State private var errorMessage: String?
    private let onSave: ((WalletCategory) -> Void)?
    private let columns = [GridItem(.adaptive(minimum: 48), spacing: 12)]

    init(kind: TransactionKind = .expense, onSave: ((WalletCategory) -> Void)? = nil) {
        _kind = State(initialValue: kind)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Spacer()
                        Image(systemName: icon)
                            .font(.system(size: 32, weight: .medium))
                            .foregroundStyle(.black)
                            .frame(width: 80, height: 80)
                            .background(WalletTheme.categoryColor(color), in: RoundedRectangle(cornerRadius: 24))
                            .accessibilityHidden(true)
                        Spacer()
                    }
                    .padding(.vertical, 12)
                    .listRowBackground(Color.clear)
                }

                Section {
                    TextField("Category name", text: $name)
                        .accessibilityIdentifier("categoryName")
                        .textInputAutocapitalization(.sentences)
                        .submitLabel(.done)
                    Picker("Category type", selection: $kind) {
                        Text(LocalizedStringKey(TransactionKind.expense.localizedName)).tag(TransactionKind.expense)
                        Text(LocalizedStringKey(TransactionKind.income.localizedName)).tag(TransactionKind.income)
                    }
                    .pickerStyle(.segmented)
                }

                Section("Icon") {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(CategoryIconChoice.all) { choice in
                            Button {
                                icon = choice.symbol
                            } label: {
                                Image(systemName: choice.symbol)
                                    .font(.title3)
                                    .foregroundStyle(icon == choice.symbol ? WalletTheme.accent : Color.primary)
                                    .frame(width: 48, height: 48)
                                    .background(icon == choice.symbol ? WalletTheme.accent.opacity(0.12) : Color.clear,
                                                in: RoundedRectangle(cornerRadius: 14))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 14)
                                            .strokeBorder(icon == choice.symbol ? WalletTheme.accent : Color.secondary.opacity(0.18),
                                                          lineWidth: icon == choice.symbol ? 2 : 1)
                                    }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(Text(LocalizedStringKey(choice.title)))
                            .accessibilityAddTraits(icon == choice.symbol ? .isSelected : [])
                        }
                    }
                    .padding(.vertical, 8)
                }

                Section("Color") {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(CategoryColorChoice.all) { choice in
                            Button {
                                color = choice.asset
                            } label: {
                                Circle()
                                    .fill(WalletTheme.categoryColor(choice.asset))
                                    .frame(width: 40, height: 40)
                                    .overlay {
                                        if color == choice.asset {
                                            Image(systemName: "checkmark")
                                                .font(.body.weight(.bold))
                                                .foregroundStyle(.black)
                                        }
                                    }
                                    .frame(width: 48, height: 48)
                                    .contentShape(Rectangle())
                                    .overlay {
                                        Circle()
                                            .strokeBorder(color == choice.asset ? Color.primary : Color.clear, lineWidth: 2)
                                    }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(Text(LocalizedStringKey(choice.title)))
                            .accessibilityAddTraits(color == choice.asset ? .isSelected : [])
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .scrollContentBackground(.hidden)
            .background(WalletTheme.background)
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("New category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .accessibilityIdentifier("saveCategory")
                        .fontWeight(.semibold)
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
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

    var body: some View {
        Image(systemName: category?.icon ?? "square.grid.2x2")
            .font(.body.weight(.medium))
            .foregroundStyle(.black)
            .frame(width: 44, height: 44)
            .background(WalletTheme.categoryColor(category?.color ?? "colorGray"),
                        in: RoundedRectangle(cornerRadius: 14))
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

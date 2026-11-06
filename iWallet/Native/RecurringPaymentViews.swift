import SwiftUI
import SwiftData

struct RecurringPaymentListView: View {
    @Query(sort: \WalletRecurringPayment.nextDueDate) private var payments: [WalletRecurringPayment]
    @State private var showsEditor = false

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 60)) { timeline in
                List {
                    if payments.isEmpty {
                        ContentUnavailableView {
                            Label("No payments yet", systemImage: "calendar.badge.clock")
                        } description: {
                            Text("Plan subscriptions and other regular expenses.")
                        } actions: {
                            Button("New payment", systemImage: "plus") { showsEditor = true }
                                .buttonStyle(.borderedProminent)
                        }
                        .listRowBackground(Color.clear)
                    } else {
                        paymentSection("Overdue", payments: payments.filter { $0.isOverdue(asOf: timeline.date) }, now: timeline.date)
                        paymentSection("Upcoming", payments: payments.filter { $0.isActive && !$0.isOverdue(asOf: timeline.date) }, now: timeline.date)
                        paymentSection("Paused", payments: payments.filter { !$0.isActive }, now: timeline.date)
                        Section {
                            Text("Expenses are recorded only when you mark a payment as paid.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .listRowBackground(Color.clear)
                    }
                }
                .accessibilityIdentifier("recurringPaymentsList")
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .background(WalletTheme.background)
            }
            .navigationTitle("Payments")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        PaymentReminderSettingsView()
                    } label: {
                        Label("Reminders", systemImage: "bell")
                    }
                    .accessibilityIdentifier("paymentReminderSettings")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("New payment", systemImage: "plus") { showsEditor = true }
                        .accessibilityIdentifier("newRecurringPayment")
                }
            }
            .sheet(isPresented: $showsEditor) { RecurringPaymentEditorView() }
        }
    }

    @ViewBuilder
    private func paymentSection(_ title: LocalizedStringKey, payments: [WalletRecurringPayment], now: Date) -> some View {
        if !payments.isEmpty {
            Section(title) {
                ForEach(payments) { payment in
                    NavigationLink {
                        RecurringPaymentDetailView(payment: payment)
                    } label: {
                        RecurringPaymentRow(payment: payment, now: now)
                    }
                }
            }
        }
    }
}

private struct RecurringPaymentRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let payment: WalletRecurringPayment
    let now: Date

    private var scheduleDescription: String {
        [payment.isSubscription ? String(localized: "Subscription") : nil,
         payment.cadence.localizedName, payment.currencyCode].compactMap { $0 }.joined(separator: " · ")
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            CategoryBadge(category: payment.category).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                if dynamicTypeSize.isAccessibilitySize {
                    titleAndAmount
                } else {
                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            Text(payment.name).font(.body.weight(.medium)).fixedSize()
                            Spacer(minLength: 0)
                            amount.fixedSize()
                        }
                        titleAndAmount
                    }
                }
                Text(scheduleDescription).font(.caption).foregroundStyle(.secondary)
                if payment.isActive {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Image(systemName: payment.isOverdue(asOf: now) ? "exclamationmark.circle" : "calendar")
                            .accessibilityHidden(true)
                        if payment.isDueToday(asOf: now) {
                            Text("Due today")
                        } else {
                            Text(RecurringPaymentPresentation.date(payment.nextDueDate, for: payment))
                        }
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }

    private var amount: some View {
        Text(Money.format(payment.amountMinor, currencyCode: payment.currencyCode))
            .font(.body.weight(.semibold)).monospacedDigit()
    }

    private var titleAndAmount: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(payment.name).font(.body.weight(.medium))
            amount
        }
    }
}

struct RecurringPaymentDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.walletDidChange) private var didChange
    @Environment(\.scenePhase) private var scenePhase
    @State private var showsEditor = false
    @State private var confirmation: PaymentConfirmation?
    @State private var errorMessage: String?
    @State private var isWorking = false
    @State private var now = Date()
    let payment: WalletRecurringPayment

    init(payment: WalletRecurringPayment) {
        self.payment = payment
    }

    private var hasActiveCategory: Bool {
        payment.category.map { $0.kind == .expense && !$0.isArchived } ?? false
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text(payment.name).font(.title2.weight(.semibold))
                    Text(Money.format(payment.amountMinor, currencyCode: payment.currencyCode))
                        .font(.largeTitle.weight(.semibold)).monospacedDigit()
                    Text(payment.currencyCode).font(.subheadline).foregroundStyle(.secondary)
                    if payment.isSubscription {
                        Label("Subscription", systemImage: "repeat")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
                .padding(.vertical, 8)
            }
            Section("Schedule") {
                RecurringPaymentValueRow("Repeat", value: payment.cadence.localizedName)
                RecurringPaymentValueRow("Next payment", value: RecurringPaymentPresentation.date(payment.nextDueDate, for: payment))
                    .accessibilityIdentifier("recurringNextPayment")
                    .accessibilityValue(RecurringPaymentPresentation.date(payment.nextDueDate, for: payment))
                RecurringPaymentValueRow("Time zone", value: payment.timeZone.localizedName(for: .generic, locale: .current) ?? payment.timeZoneIdentifier)
                statusLabel.accessibilityIdentifier("recurringPaymentStatus")
            }
            Section("Category") {
                HStack(spacing: 12) {
                    CategoryBadge(category: payment.category).accessibilityHidden(true)
                    Text(payment.category?.name ?? String(localized: "Uncategorized"))
                        .fixedSize(horizontal: false, vertical: true)
                }
                if !hasActiveCategory {
                    Text("Choose an active expense category before recording this payment.")
                        .font(.subheadline).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("Edit payment") { showsEditor = true }
                }
            }
            Section {
                if payment.isActive {
                    Button("Mark as paid", systemImage: "checkmark.circle") { requestConfirmation(.paid) }
                        .disabled(!hasActiveCategory || isWorking)
                        .accessibilityIdentifier("markRecurringPaid")
                    Button("Skip this payment", systemImage: "forward.end") { requestConfirmation(.skip) }
                        .disabled(isWorking)
                        .accessibilityIdentifier("skipRecurringPayment")
                    Button("Pause payment", systemImage: "pause.circle") { setActive(false) }
                        .disabled(isWorking)
                        .accessibilityIdentifier("pauseRecurringPayment")
                } else {
                    Button("Resume payment", systemImage: "play.circle") { setActive(true) }
                        .disabled(isWorking)
                        .accessibilityIdentifier("resumeRecurringPayment")
                }
            } footer: {
                Text("Expenses are recorded only when you mark a payment as paid.")
            }
            Section {
                Button("Delete payment", systemImage: "trash", role: .destructive) { requestConfirmation(.delete) }
                    .disabled(isWorking)
                    .accessibilityIdentifier("deleteRecurringPayment")
            }
        }
        .accessibilityIdentifier("recurringPaymentDetail")
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(WalletTheme.background)
        .navigationTitle("Payment")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") { showsEditor = true }
                    .disabled(isWorking)
                    .accessibilityIdentifier("editRecurringPayment")
            }
        }
        .sheet(isPresented: $showsEditor) { RecurringPaymentEditorView(payment: payment) }
        .task { await refreshClock() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { now = Date() }
        }
        .confirmationDialog(confirmation?.kind.title ?? "Mark payment as paid?", isPresented: Binding(
            get: { confirmation != nil }, set: { if !$0 { confirmation = nil } }
        ), titleVisibility: .visible) {
            if let captured = confirmation {
                Button(captured.kind.actionTitle, role: captured.kind == .delete ? .destructive : nil) {
                    perform(captured)
                }
                .accessibilityIdentifier(captured.kind.confirmationIdentifier)
            }
            Button("Cancel", role: .cancel) { confirmation = nil }
        } message: {
            if let captured = confirmation {
                switch captured.kind {
                case .paid:
                    Text(String(format: NSLocalizedString("This records one expense of %@ on %@ and advances the payment by one period.", comment: "Payment confirmation"), captured.amount, captured.paidAt.formatted(date: .abbreviated, time: .omitted)))
                case .skip:
                    Text("This advances the payment by one period without recording an expense.")
                case .delete:
                    Text("Deleting this payment keeps all recorded expenses in your history.")
                }
            }
        }
        .alert("Unable to update payment", isPresented: Binding(
            get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    @ViewBuilder
    private var statusLabel: some View {
        if !payment.isActive {
            Label("Paused", systemImage: "pause.circle")
        } else if payment.isOverdue(asOf: now) {
            Label("Overdue", systemImage: "exclamationmark.circle")
        } else if payment.isDueToday(asOf: now) {
            Label("Due today", systemImage: "clock")
        } else {
            Label("Upcoming", systemImage: "calendar")
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

    private func requestConfirmation(_ kind: PaymentConfirmation.Kind) {
        confirmation = PaymentConfirmation(kind: kind, occurrence: payment.occurrence,
            amount: Money.format(payment.amountMinor, currencyCode: payment.currencyCode), paidAt: .now)
    }

    private func perform(_ captured: PaymentConfirmation) {
        guard !isWorking else { return }
        isWorking = true
        confirmation = nil
        defer { isWorking = false }
        do {
            switch captured.kind {
            case .paid:
                _ = try WalletStore.markRecurringPaymentPaid(context: context, payment: payment,
                    expectedOccurrence: captured.occurrence, paidAt: captured.paidAt)
            case .skip:
                try WalletStore.skipRecurringPaymentOccurrence(context: context, payment: payment,
                    expectedOccurrence: captured.occurrence)
            case .delete:
                try WalletStore.deleteRecurringPayment(context: context, payment: payment)
                dismiss()
            }
            didChange()
        } catch { errorMessage = error.localizedDescription }
    }

    private func setActive(_ active: Bool) {
        guard !isWorking else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            try WalletStore.setRecurringPaymentActive(context: context, payment: payment, isActive: active)
            didChange()
        } catch { errorMessage = error.localizedDescription }
    }
}

private struct PaymentConfirmation {
    enum Kind: Equatable {
        case paid, skip, delete
        var title: LocalizedStringKey {
            switch self {
            case .paid: "Mark payment as paid?"
            case .skip: "Skip this payment?"
            case .delete: "Delete payment?"
            }
        }
        var actionTitle: LocalizedStringKey {
            switch self {
            case .paid: "Mark as paid"
            case .skip: "Skip this payment"
            case .delete: "Delete payment"
            }
        }
        var confirmationIdentifier: String {
            switch self {
            case .paid: "confirmRecurringPaid"
            case .skip: "confirmRecurringSkip"
            case .delete: "confirmRecurringDelete"
            }
        }
    }
    let kind: Kind
    let occurrence: RecurringOccurrence
    let amount: String
    let paidAt: Date
}

struct RecurringPaymentEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.walletDidChange) private var didChange
    @AppStorage("preferredCurrencyCode") private var preferredCurrency = WalletDefaults.currencyCode
    @Query(sort: \WalletCategory.name) private var categories: [WalletCategory]
    private enum Field: Hashable { case name, amount }
    @FocusState private var focusedField: Field?
    @State private var name = ""
    @State private var amountText = ""
    @State private var currencyCode = "USD"
    @State private var categoryID: UUID?
    @State private var cadence: RecurringCadence = .monthly
    @State private var nextDueDate = Date()
    @State private var isSubscription = false
    @State private var timeZoneIdentifier = TimeZone.current.identifier
    @State private var initialDraft: Draft?
    @State private var showsCategoryEditor = false
    @State private var showsDiscardConfirmation = false
    @State private var amountError: String?
    @State private var saveError: String?
    @State private var isSaving = false
    var payment: WalletRecurringPayment? = nil

    private var activeCategories: [WalletCategory] { categories.filter { $0.kind == .expense && !$0.isArchived } }
    private var selectedCategory: WalletCategory? { activeCategories.first { $0.id == categoryID } }
    private var timeZone: TimeZone { TimeZone(identifier: timeZoneIdentifier) ?? .current }
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }
    private var draft: Draft {
        Draft(name: name, amount: amountText, currency: currencyCode, categoryID: categoryID,
              cadence: cadence, date: nextDueDate, subscription: isSubscription, timeZone: timeZoneIdentifier)
    }
    private var hasChanges: Bool { initialDraft.map { $0 != draft } ?? false }
    private var currencyName: String { WalletCurrency(rawValue: currencyCode)?.displayName ?? currencyCode }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Name", text: $name)
                        .textInputAutocapitalization(.sentences)
                        .focused($focusedField, equals: .name)
                        .accessibilityIdentifier("paymentName")
                    Toggle("Subscription", isOn: $isSubscription)
                        .accessibilityIdentifier("paymentSubscription")
                }
                Section {
                    TextField("0", text: $amountText)
                        .font(.largeTitle.weight(.medium)).monospacedDigit()
                        .keyboardType(.decimalPad)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                        .focused($focusedField, equals: .amount)
                        .accessibilityLabel("Amount")
                        .accessibilityIdentifier("paymentAmount")
                        .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
                    if let amountError {
                        Label(amountError, systemImage: "exclamationmark.circle")
                            .font(.footnote).foregroundStyle(.red)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("paymentAmountError")
                    }
                    Menu {
                        Picker("Currency", selection: $currencyCode) {
                            ForEach(WalletCurrency.allCases) { Text($0.displayName).tag($0.rawValue) }
                            if WalletCurrency(rawValue: currencyCode) == nil { Text(currencyCode).tag(currencyCode) }
                        }
                    } label: {
                        WalletFormMenuLabel("Currency", value: currencyName)
                    }
                    .accessibilityIdentifier("paymentCurrency")
                } header: {
                    Text("Amount")
                } footer: {
                    Text("Changing the currency keeps the entered amount. No conversion is performed.")
                }
                Section {
                    Menu {
                        Picker("Category", selection: $categoryID) {
                            Text("Choose a category").tag(UUID?.none)
                            ForEach(activeCategories) { category in
                                Label(category.name, systemImage: WalletTheme.categorySymbol(category.icon))
                                    .tag(Optional(category.id))
                            }
                        }
                    } label: {
                        WalletFormMenuLabel("Category", value: selectedCategory?.name ?? String(localized: "Choose a category"))
                    }
                    .accessibilityIdentifier("paymentCategory")
                    Button("New category", systemImage: "plus") {
                        focusedField = nil
                        showsCategoryEditor = true
                    }
                } header: {
                    Text("Category")
                } footer: {
                    Text("Choose an active expense category before recording this payment.")
                }
                Section {
                    Menu {
                        Picker("Repeat", selection: $cadence) {
                            ForEach(RecurringCadence.allCases) { value in
                                Text(value.localizedName).tag(value)
                            }
                        }
                    } label: {
                        WalletFormMenuLabel("Repeat", value: cadence.localizedName)
                    }
                    .accessibilityIdentifier("paymentCadence")
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Next payment").font(.subheadline).foregroundStyle(.secondary)
                        DatePicker("Next payment", selection: $nextDueDate, displayedComponents: .date)
                            .labelsHidden()
                            .environment(\.calendar, calendar)
                            .environment(\.timeZone, timeZone)
                            .accessibilityIdentifier("paymentDate")
                    }
                } header: {
                    Text("Schedule")
                } footer: {
                    Text("Expenses are recorded only when you mark a payment as paid.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(WalletTheme.background)
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(payment == nil ? Text("New payment") : Text("Edit payment"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark", action: cancel).labelStyle(.iconOnly)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", systemImage: "checkmark", action: save)
                        .labelStyle(.iconOnly)
                        .accessibilityIdentifier("saveRecurringPayment")
                        .disabled(isSaving || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                  || amountText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedCategory == nil)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focusedField = nil }
                }
            }
            .onAppear(perform: loadDraft)
            .onChange(of: amountText) { _, _ in amountError = nil }
            .onChange(of: currencyCode) { _, _ in amountError = nil }
            .navigationDestination(isPresented: $showsCategoryEditor) {
                CategoryEditorView(kind: .expense, isPresentedModally: false, allowKindSelection: false) { category in
                    categoryID = category.id
                }
            }
            .confirmationDialog("Discard changes?", isPresented: $showsDiscardConfirmation, titleVisibility: .visible) {
                Button("Discard changes", role: .destructive) { dismiss() }
                Button("Keep editing", role: .cancel) { }
            }
            .alert("Unable to save payment", isPresented: Binding(
                get: { saveError != nil }, set: { if !$0 { saveError = nil } }
            )) {
                Button("OK", role: .cancel) { saveError = nil }
            } message: {
                Text(saveError ?? "")
            }
        }
        .interactiveDismissDisabled(hasChanges || showsCategoryEditor)
    }

    private func loadDraft() {
        guard initialDraft == nil else { return }
        if let payment {
            name = payment.name
            amountText = Money.inputText(payment.amountMinor, currencyCode: payment.currencyCode)
            currencyCode = payment.currencyCode
            categoryID = activeCategories.first { $0.id == payment.category?.id }?.id
            cadence = payment.cadence
            nextDueDate = payment.nextDueDate
            isSubscription = payment.isSubscription
            timeZoneIdentifier = payment.timeZoneIdentifier
        } else {
            currencyCode = WalletCurrency(rawValue: preferredCurrency)?.rawValue ?? WalletDefaults.currencyCode
        }
        initialDraft = draft
    }

    private func cancel() {
        focusedField = nil
        if hasChanges { showsDiscardConfirmation = true } else { dismiss() }
    }

    private func save() {
        guard !isSaving else { return }
        let amountMinor: Int64
        do {
            amountMinor = try Money.parse(amountText, currencyCode: currencyCode)
        } catch {
            amountError = error.localizedDescription
            focusedField = .amount
            return
        }
        guard let selectedCategory else { return }
        isSaving = true
        do {
            _ = try WalletStore.saveRecurringPayment(context: context, payment: payment,
                name: name.trimmingCharacters(in: .whitespacesAndNewlines), amountMinor: amountMinor,
                currencyCode: currencyCode, category: selectedCategory, cadence: cadence,
                nextDueDate: nextDueDate, isSubscription: isSubscription, timeZoneIdentifier: timeZoneIdentifier)
            dismiss()
            didChange()
        } catch {
            isSaving = false
            saveError = error.localizedDescription
        }
    }

    private struct Draft: Equatable {
        let name: String
        let amount: String
        let currency: String
        let categoryID: UUID?
        let cadence: RecurringCadence
        let date: Date
        let subscription: Bool
        let timeZone: String
    }
}

private struct RecurringPaymentValueRow: View {
    let title: LocalizedStringKey
    let value: String
    init(_ title: LocalizedStringKey, value: String) {
        self.title = title; self.value = value
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.subheadline).foregroundStyle(.secondary)
            Text(value)
        }
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)
    }
}

private enum RecurringPaymentPresentation {
    static func date(_ date: Date, for payment: WalletRecurringPayment) -> String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.calendar = payment.calendar
        formatter.timeZone = payment.timeZone
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

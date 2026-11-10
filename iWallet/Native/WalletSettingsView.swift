import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct WalletSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.walletDidRestore) private var didRestore
    @AppStorage("preferredCurrencyCode") private var currency = WalletDefaults.currencyCode
    @State private var export: WalletExportDocument?
    @State private var showingExporter = false
    @State private var showingImporter = false
    @State private var pendingImport: ImportPreview?
    @State private var isReading = false
    @State private var errorMessage: String?
    @State private var importSummary: WalletBackup.ImportSummary?
    @State private var importResult: Result<WalletBackup.ImportSummary, Error>?
    var isPresentedModally = true

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    NavigationLink {
                        CategoryListView(isPushed: true)
                    } label: {
                        Label("Categories", systemImage: "square.grid.2x2")
                    }
                    .accessibilityIdentifier("settingsCategories")
                    NavigationLink {
                        WalletBudgetListView()
                    } label: {
                        Label("Monthly budgets", systemImage: "gauge.with.dots.needle.50percent")
                    }
                    .accessibilityIdentifier("settingsBudgets")
                }
                .listRowBackground(WalletTheme.surface)
                Section {
                    Menu {
                        Picker("Default currency", selection: $currency) {
                            ForEach(WalletCurrency.allCases) { item in
                                Text(item.displayName).tag(item.rawValue)
                            }
                        }
                    } label: {
                        WalletFormMenuLabel("Default currency",
                                            value: WalletCurrency(rawValue: currency)?.displayName ?? currency)
                    }
                    .accessibilityIdentifier("settingsDefaultCurrency")
                } footer: {
                    Text("Used for new transactions. Existing amounts keep their original currency; no conversion is performed.")
                }
                .listRowBackground(WalletTheme.surface)
                Section {
                    NavigationLink {
                        WalletCSVExportView()
                    } label: {
                        Label("Export transactions as CSV", systemImage: "tablecells")
                    }
                    .accessibilityIdentifier("settingsExportCSV")
                    Button(action: prepareExport) { Label("Export all data", systemImage: "square.and.arrow.up") }
                    Button { showingImporter = true } label: { Label("Import a backup", systemImage: "square.and.arrow.down") }
                        .disabled(isReading)
                    if isReading { ProgressView("Reading your backup") }
                } header: { Text("Your data") } footer: {
                    Text("Keep a JSON backup somewhere safe. Import adds missing records, skips identical records and stops if existing data conflicts.")
                }
                .listRowBackground(WalletTheme.surface)
                Section {
                    NavigationLink { privacyView } label: { Label("Privacy", systemImage: "hand.raised") }
                    Link(destination: URL(string: "mailto:idevnva@icloud.com")!) {
                        Label("Contact support", systemImage: "envelope")
                    }
                    NavigationLink {
                        ScrollView {
                            Text(Self.thirdPartyNotices)
                                .font(.footnote)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                        }
                        .background(WalletTheme.background)
                        .navigationTitle("Licenses")
                        .navigationBarTitleDisplayMode(.inline)
                    } label: {
                        Label("Licenses", systemImage: "doc.text")
                    }
                    LabeledContent("Version", value: version)
                    LabeledContent("Storage", value: String(localized: "On this device"))
                } header: { Text("About iWallet") }
                .listRowBackground(WalletTheme.surface)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(isPresentedModally ? .inline : .large)
            .symbolRenderingMode(.hierarchical)
            .labelStyle(SettingsRowLabelStyle())
            .scrollContentBackground(.hidden)
            .background(WalletTheme.background)
            .toolbar {
                if isPresentedModally {
                    ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
                }
            }
            .fileExporter(isPresented: $showingExporter, document: export, contentType: .json,
                          defaultFilename: "iWallet-backup-\(Date.now.formatted(.iso8601.year().month().day().dateSeparator(.dash)))") { result in
                if case .failure(let error) = result { errorMessage = error.localizedDescription }
            }
            .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.json]) { result in
                switch result {
                case .success(let url): Task { await readBackup(url) }
                case .failure(let error): errorMessage = error.localizedDescription
                }
            }
            .sheet(item: $pendingImport, onDismiss: presentImportResult) { preview in
                NavigationStack {
                    Form {
                        Section("Backup contents") {
                            LabeledContent("Categories", value: preview.backup.categories.count.formatted())
                            LabeledContent("Transactions", value: preview.backup.transactions.count.formatted())
                            LabeledContent("Payments", value: preview.backup.recurringPayments.count.formatted())
                            LabeledContent("Monthly budgets", value: preview.backup.budgets.count.formatted())
                            LabeledContent("Created", value: preview.backup.createdAt.formatted(date: .abbreviated, time: .shortened))
                        }
                        Section {
                            Text("Existing records will not be overwritten. If a matching record has changed, nothing will be imported.")
                        }
                        Section {
                            Button { restore(preview.backup) } label: {
                                Text("Import backup").frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets())
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .background(WalletTheme.background)
                    .navigationTitle("Review backup")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) { Button("Cancel") { pendingImport = nil } }
                    }
                }
            }
            .alert(importSummary == nil ? String(localized: "Unable to complete the operation") : String(localized: "Backup imported"),
                   isPresented: Binding(get: { errorMessage != nil || importSummary != nil }, set: { _ in })) {
                if importSummary != nil {
                    Button("Done") {
                        importSummary = nil
                        if isPresentedModally { dismiss() }
                        didRestore()
                    }
                } else {
                    Button("OK", role: .cancel) { errorMessage = nil }
                }
            } message: {
                if let summary = importSummary {
                    Text(String(format: NSLocalizedString("Added %d categories, %d transactions, %d payments and %d budgets. Skipped %d identical records.", comment: "Import result"), locale: .current,
                                summary.insertedCategories, summary.insertedTransactions, summary.insertedRecurringPayments, summary.insertedBudgets,
                                summary.skippedCategories + summary.skippedTransactions + summary.skippedRecurringPayments + summary.skippedBudgets))
                } else {
                    Text(errorMessage ?? "")
                }
            }
        }
    }

    private var privacyView: some View {
        List {
            Section {
                Label("Stored on your device", systemImage: "iphone")
                    .font(.headline)
                Text("Your categories, transactions, budgets and payment schedules are saved locally. iWallet does not send them to a server.")
                    .foregroundStyle(.secondary)
            }
            Section {
                Label("No tracking", systemImage: "eye.slash")
                    .font(.headline)
                Text("This version contains no advertising or analytics services and does not require an account.")
                    .foregroundStyle(.secondary)
            }
            Section {
                Label("You control your exports", systemImage: "square.and.arrow.up")
                    .font(.headline)
                Text("An exported file contains your financial history. Only share it with people and apps you trust.")
                    .foregroundStyle(.secondary)
            }
            Section {
                Link("Privacy policy", destination: URL(string: "https://github.com/nvavna/iWallet-1/blob/restoration/foundation/docs/PRIVACY.md")!)
            }
        }
        .navigationTitle("Privacy")
        .navigationBarTitleDisplayMode(.inline)
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(WalletTheme.background)
    }

    private var version: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
        return "\(version) (\(build))"
    }

    private static var thirdPartyNotices: String {
        guard let url = Bundle.main.url(forResource: "ThirdPartyNotices", withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8) else {
            return String(localized: "License information is unavailable.")
        }
        return text
    }

    private func prepareExport() {
        do {
            export = WalletExportDocument(data: try WalletBackup.snapshot(context: context).encodedData())
            showingExporter = true
        } catch { errorMessage = error.localizedDescription }
    }

    @MainActor
    private func readBackup(_ url: URL) async {
        isReading = true
        defer { isReading = false }
        do {
            let backup = try await Task.detached(priority: .userInitiated) {
                let scoped = url.startAccessingSecurityScopedResource()
                defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                let file = try FileHandle(forReadingFrom: url)
                defer { try? file.close() }
                var data = Data()
                while let chunk = try file.read(upToCount: 1_024 * 1_024), !chunk.isEmpty {
                    guard data.count + chunk.count <= WalletBackup.maximumFileSize else { throw WalletBackupError.fileTooLarge }
                    data.append(chunk)
                }
                return try WalletBackup.decode(data: data)
            }.value
            pendingImport = ImportPreview(backup: backup)
        } catch { errorMessage = error.localizedDescription }
    }

    private func restore(_ backup: WalletBackup) {
        do {
            let summary = try backup.restore(into: context)
            importResult = .success(summary)
            pendingImport = nil
        } catch {
            importResult = .failure(error)
            pendingImport = nil
        }
    }

    private func presentImportResult() {
        guard let result = importResult else { return }
        importResult = nil
        switch result {
        case .success(let summary): importSummary = summary
        case .failure(let error): errorMessage = error.localizedDescription
        }
    }
}

private struct SettingsRowLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 12) {
            configuration.icon
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(WalletTheme.accent)
                .frame(width: 32, height: 32)
                .background(WalletTheme.accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 10))
                .accessibilityHidden(true)
            configuration.title
                .foregroundStyle(WalletTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(minHeight: 44)
    }
}

private struct ImportPreview: Identifiable {
    let id = UUID()
    let backup: WalletBackup
}

private struct WalletCSVExportView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.calendar) private var calendar
    @Environment(\.timeZone) private var timeZone
    @Environment(\.locale) private var locale
    @State private var startDate = Calendar.current.dateInterval(of: .month, for: .now)?.start ?? .now
    @State private var endDate = Date.now
    @State private var isPreparing = false
    @State private var csv: WalletTransactionCSV?
    @State private var showingExporter = false
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section {
                DatePicker("Start date", selection: $startDate, displayedComponents: .date)
                    .accessibilityIdentifier("csvStartDate")
                    .onChange(of: startDate) { _, start in
                        if calendar.compare(start, to: endDate, toGranularity: .day) == .orderedDescending {
                            endDate = start
                        }
                    }
                DatePicker("End date", selection: $endDate, in: calendar.startOfDay(for: startDate)...,
                           displayedComponents: .date)
                    .accessibilityIdentifier("csvEndDate")
            } header: { Text("Period") } footer: {
                Text("Both dates are included. Amounts use their original currency. Expenses are negative and income is positive.")
            }
            Section {
                Button { isPreparing = true } label: {
                    HStack {
                        Label("Save CSV", systemImage: "square.and.arrow.up")
                        if isPreparing { Spacer(); ProgressView() }
                    }
                }
                .accessibilityIdentifier("exportCSV")
            }
        }
        .disabled(isPreparing)
        .scrollContentBackground(.hidden)
        .background(WalletTheme.background)
        .navigationTitle("Export transactions as CSV")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: isPreparing) {
            guard isPreparing else { return }
            await prepareExport()
        }
        .fileExporter(isPresented: $showingExporter, document: csv.map { WalletExportDocument(data: $0.data) },
                      contentType: .commaSeparatedText, defaultFilename: csv?.filename) { result in
            csv = nil
            if case .failure(let error) = result { errorMessage = error.localizedDescription }
        }
        .alert(errorMessage ?? "", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        }
    }

    @MainActor
    private func prepareExport() async {
        let container = context.container
        var exportCalendar = calendar
        exportCalendar.timeZone = timeZone
        let worker = Task.detached(priority: .userInitiated) { [startDate, endDate, locale, exportCalendar] in
            try WalletTransactionCSV.export(context: ModelContext(container), from: startDate, through: endDate,
                                            calendar: exportCalendar, locale: locale)
        }
        defer { isPreparing = false }
        do {
            let result = try await withTaskCancellationHandler {
                try await worker.value
            } onCancel: {
                worker.cancel()
            }
            try Task.checkCancellation()
            if let result {
                csv = result
                showingExporter = true
            } else {
                errorMessage = String(localized: "No transactions in this period")
            }
        } catch is CancellationError {
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct WalletExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json, .commaSeparatedText] }
    var data: Data

    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        guard let contents = configuration.file.regularFileContents else { throw CocoaError(.fileReadCorruptFile) }
        data = contents
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

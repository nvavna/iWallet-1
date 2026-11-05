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
                }
                Section {
                    Picker("Default currency", selection: $currency) {
                        ForEach(WalletCurrency.allCases) { item in
                            Text(item.displayName).tag(item.rawValue)
                        }
                    }
                } footer: {
                    Text("Used for new transactions. Existing amounts keep their original currency; no conversion is performed.")
                }
                Section {
                    Button(action: prepareExport) { Label("Export all data", systemImage: "square.and.arrow.up") }
                    Button { showingImporter = true } label: { Label("Import a backup", systemImage: "square.and.arrow.down") }
                        .disabled(isReading)
                    if isReading { ProgressView("Reading your backup") }
                    NavigationLink { privacyView } label: { Label("Privacy", systemImage: "hand.raised") }
                } header: { Text("Your data") } footer: {
                    Text("Keep a JSON backup somewhere safe. Import adds missing records, skips identical records and stops if existing data conflicts.")
                }
                Section {
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
                        .navigationTitle("Licenses")
                        .navigationBarTitleDisplayMode(.inline)
                    } label: {
                        Label("Licenses", systemImage: "doc.text")
                    }
                    LabeledContent("Version", value: version)
                    LabeledContent("Storage", value: String(localized: "On this device"))
                } header: { Text("About iWallet") } footer: {
                    Text("A clear view of your everyday finances.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(isPresentedModally ? .inline : .large)
            .symbolRenderingMode(.hierarchical)
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
                            LabeledContent("Categories", value: String(preview.backup.categories.count))
                            LabeledContent("Transactions", value: String(preview.backup.transactions.count))
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
                    Text(String(format: NSLocalizedString("Added %d categories and %d transactions. Skipped %d identical records.", comment: "Import result"),
                                summary.insertedCategories, summary.insertedTransactions,
                                summary.skippedCategories + summary.skippedTransactions))
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
                Text("Your categories, amounts and notes are saved locally. iWallet does not send them to a server.")
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

private struct ImportPreview: Identifiable {
    let id = UUID()
    let backup: WalletBackup
}

private struct WalletExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
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

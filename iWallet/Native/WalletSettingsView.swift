import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct WalletSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var categories: [WalletCategory]
    @Query private var transactions: [WalletTransaction]
    @AppStorage("preferredCurrencyCode") private var currency = WalletDefaults.currencyCode
    @State private var export: WalletExportDocument?
    @State private var showingExporter = false
    @State private var exportError: String?

    var body: some View {
        NavigationStack {
            Form {
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
                    Button(action: prepareExport) {
                        Label("Export all data", systemImage: "square.and.arrow.up")
                    }
                    NavigationLink {
                        privacyView
                    } label: {
                        Label("Privacy", systemImage: "hand.raised")
                    }
                } header: {
                    Text("Your data")
                } footer: {
                    Text("Export saves your categories and transactions as a JSON file. Keep it somewhere safe. Importing this file will be available in a future update.")
                }

                Section {
                    LabeledContent("Version", value: version)
                    LabeledContent("Storage", value: String(localized: "On this device"))
                } header: {
                    Text("About iWallet")
                } footer: {
                    Text("A clear view of your everyday finances.")
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .fileExporter(isPresented: $showingExporter, document: export, contentType: .json, defaultFilename: "iWallet-export-\(Date.now.formatted(.iso8601.year().month().day().dateSeparator(.dash)))") { result in
                if case .failure(let error) = result { exportError = error.localizedDescription }
            }
            .alert("Unable to export data", isPresented: Binding(get: { exportError != nil }, set: { if !$0 { exportError = nil } })) {
                Button("OK", role: .cancel) { exportError = nil }
            } message: { Text(exportError ?? "") }
        }
    }

    private var privacyView: some View {
        List {
            Section {
                Label("Stored on your device", systemImage: "iphone")
                Text("Your categories, amounts and notes are saved locally. iWallet does not send them to a server.")
            }
            Section {
                Label("No tracking", systemImage: "eye.slash")
                Text("This version contains no advertising or analytics services and does not require an account.")
            }
            Section {
                Label("You control your exports", systemImage: "square.and.arrow.up")
                Text("An exported file contains your financial history. Only share it with people and apps you trust.")
            }
        }
        .navigationTitle("Privacy")
    }

    private var version: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
        return "\(version) (\(build))"
    }

    private func prepareExport() {
        do {
            export = try WalletExportDocument(categories: categories, transactions: transactions)
            showingExporter = true
        } catch {
            exportError = error.localizedDescription
        }
    }
}

private struct WalletExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data

    init(categories: [WalletCategory], transactions: [WalletTransaction]) throws {
        let payload = WalletExport(
            formatVersion: 1,
            createdAt: Date(),
            categories: categories.map { .init(id: $0.id, name: $0.name, icon: $0.icon, color: $0.color, kind: $0.kindRaw, isArchived: $0.isArchived) },
            transactions: transactions.map { .init(id: $0.id, amountMinor: $0.amountMinor, currencyCode: $0.currencyCode, date: $0.date, note: $0.note, kind: $0.kindRaw, categoryID: $0.category?.id) }
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        data = try encoder.encode(payload)
    }

    init(configuration: ReadConfiguration) throws {
        guard let contents = configuration.file.regularFileContents else { throw CocoaError(.fileReadCorruptFile) }
        data = contents
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

private struct WalletExport: Encodable {
    let formatVersion: Int
    let createdAt: Date
    let categories: [CategoryRecord]
    let transactions: [TransactionRecord]

    struct CategoryRecord: Encodable {
        let id: UUID
        let name: String
        let icon: String
        let color: String
        let kind: String
        let isArchived: Bool
    }

    struct TransactionRecord: Encodable {
        let id: UUID
        let amountMinor: Int64
        let currencyCode: String
        let date: Date
        let note: String
        let kind: String
        let categoryID: UUID?
    }
}

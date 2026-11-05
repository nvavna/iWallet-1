import SwiftUI
import SwiftData

@main
struct iWalletApp: App {
    var body: some Scene {
        WindowGroup {
            WalletBootstrapView()
                .tint(WalletTheme.accent)
        }
    }
}

private struct WalletBootstrapView: View {
    @State private var container: ModelContainer?
    @State private var failure: String?
    @State private var legacyFiles: [URL] = []
    @State private var revision = 0

    var body: some View {
        Group {
            if let container {
                if !legacyFiles.isEmpty {
                    WalletMigrationView(sourceURLs: legacyFiles, container: container) {
                        openWallet()
                    }
                } else {
                    WalletRootView()
                        .id(revision)
                        .modelContainer(container)
                        .environment(\.walletDidRestore, { revision += 1 })
                }
            } else if let failure {
                ContentUnavailableView {
                    Label("Unable to open your wallet", systemImage: "externaldrive.badge.exclamationmark")
                } description: {
                    Text("Your data has not been reset. Free up space on your device and try again.")
                    Text(failure).font(.caption)
                } actions: {
                    Button("Try again", action: openWallet)
                        .buttonStyle(.borderedProminent)
                }
            } else {
                ProgressView("Opening your wallet")
            }
        }
        .task { if container == nil && failure == nil { openWallet() } }
    }

    @MainActor
    private func openWallet() {
        failure = nil
        let preferences = UserDefaults.standard
        if WalletCurrency(rawValue: preferences.string(forKey: "preferredCurrencyCode") ?? "") == nil {
            preferences.set(WalletDefaults.currencyCode, forKey: "preferredCurrencyCode")
        }
        do {
            let store = try WalletStore.makeContainer()
            let receipts = try store.mainContext.fetch(FetchDescriptor<WalletMigrationReceipt>())
            if let receipt = receipts.first(where: { $0.id == "realm-v1" }) {
                WalletStore.applyMigrationPreferences(receipt: receipt, preferences: preferences)
            }
            legacyFiles = receipts.contains(where: { $0.id == "realm-v1" }) ? [] : WalletStore.legacyStoreURLs()
            if legacyFiles.isEmpty { try WalletStore.seedIfNeeded(context: store.mainContext) }
            container = store
        } catch {
            container = nil
            failure = error.localizedDescription
        }
    }
}

private struct WalletRootView: View {
    var body: some View {
        TabView {
            WalletHomeView()
                .tabItem { Label("Overview", systemImage: "chart.pie") }
            TransactionListView(isPresentedModally: false)
                .tabItem { Label("Transactions", systemImage: "list.bullet.rectangle") }
            WalletSettingsView(isPresentedModally: false)
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
    }
}

private struct WalletDidRestoreKey: EnvironmentKey {
    static let defaultValue: () -> Void = {}
}

extension EnvironmentValues {
    var walletDidRestore: () -> Void {
        get { self[WalletDidRestoreKey.self] }
        set { self[WalletDidRestoreKey.self] = newValue }
    }
}

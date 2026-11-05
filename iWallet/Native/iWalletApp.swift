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

    var body: some View {
        Group {
            if !legacyFiles.isEmpty {
                ContentUnavailableView {
                    Label("Your previous wallet is safe", systemImage: "externaldrive.badge.checkmark")
                } description: {
                    Text("We found data from the previous version. This preview cannot import it yet. Your original wallet has not been changed. Please keep a backup until the transfer is ready.")
                } actions: {
                    ShareLink(items: legacyFiles) {
                        Label("Save a copy of previous data", systemImage: "square.and.arrow.up")
                    }
                }
                .padding()
            } else if let container {
                WalletTabView()
                    .modelContainer(container)
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
        legacyFiles = WalletStore.legacyStoreURLs()
        guard legacyFiles.isEmpty else { return }
        do {
            let store = try WalletStore.makeContainer()
            try WalletStore.seedIfNeeded(context: store.mainContext)
            container = store
        } catch {
            failure = error.localizedDescription
        }
    }
}

private struct WalletTabView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            WalletHomeView(showTransactions: { selectedTab = 1 })
                .tabItem { Label("Overview", systemImage: "square.grid.2x2") }
                .tag(0)
            TransactionListView()
                .tabItem { Label("Transactions", systemImage: "list.bullet.rectangle") }
                .tag(1)
            CategoryListView()
                .tabItem { Label("Categories", systemImage: "square.stack.3d.up") }
                .tag(2)
        }
    }
}

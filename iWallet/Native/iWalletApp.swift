import SwiftUI
import SwiftData

@main
struct iWalletApp: App {
    init() { PaymentReminders.installNotificationDelegate() }

    var body: some Scene {
        WindowGroup {
            WalletBootstrapView()
                .tint(WalletTheme.accent)
        }
    }
}

private enum WalletDestination: Hashable { case overview, transactions, payments, settings }

private struct WalletBootstrapView: View {
    @Environment(\.scenePhase) private var scenePhase
    private let reminders = PaymentReminders.shared
    @State private var container: ModelContainer?
    @State private var failure: String?
    @State private var legacyFiles: [URL] = []
    @State private var revision = 0
    @State private var selection: WalletDestination = .overview

    var body: some View {
        Group {
            if let container {
                if !legacyFiles.isEmpty {
                    WalletMigrationView(sourceURLs: legacyFiles, container: container) {
                        openWallet()
                    }
                } else {
                    WalletRootView(selection: $selection)
                        .id(revision)
                        .modelContainer(container)
                        .environment(\.walletDidRestore, reloadWallet)
                        .environment(\.walletDidChange, reloadWallet)
                        .task(id: scenePhase == .active ? revision : nil) {
                            guard scenePhase == .active else { return }
                            await reminders.refresh(context: container.mainContext)
                        }
                        .onChange(of: reminders.openPaymentsRequested, initial: true) { _, requested in
                            if requested {
                                selection = .payments
                                reminders.consumeOpenPaymentsRequest()
                            }
                        }
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
    private func reloadWallet() {
        openWallet()
        revision += 1
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
            Task { await reminders.refreshAfterReadFailure(error) }
        }
    }
}

private struct WalletRootView: View {
    @Binding var selection: WalletDestination

    var body: some View {
        TabView(selection: $selection) {
            WalletHomeView(showPayments: { selection = .payments })
                .tabItem { Label("Overview", systemImage: "chart.pie") }
                .tag(WalletDestination.overview)
            TransactionListView(isPresentedModally: false)
                .tabItem { Label("Transactions", systemImage: "list.bullet.rectangle") }
                .tag(WalletDestination.transactions)
            RecurringPaymentListView()
                .tabItem { Label("Payments", systemImage: "calendar") }
                .tag(WalletDestination.payments)
            WalletSettingsView(isPresentedModally: false)
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(WalletDestination.settings)
        }
    }
}

private struct WalletDidRestoreKey: EnvironmentKey {
    static let defaultValue: () -> Void = {}
}

private struct WalletDidChangeKey: EnvironmentKey {
    static let defaultValue: () -> Void = {}
}

extension EnvironmentValues {
    var walletDidChange: () -> Void {
        get { self[WalletDidChangeKey.self] }
        set { self[WalletDidChangeKey.self] = newValue }
    }
    var walletDidRestore: () -> Void {
        get { self[WalletDidRestoreKey.self] }
        set { self[WalletDidRestoreKey.self] = newValue }
    }
}

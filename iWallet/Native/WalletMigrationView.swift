import SwiftUI
import SwiftData

struct WalletMigrationView: View {
    let sourceURLs: [URL]
    let container: ModelContainer
    let onComplete: () -> Void

    @State private var currencyCode = ""
    @State private var preview: LegacyWalletMigration.Preview?
    @State private var isWorking = false
    @State private var failure: String?
    @State private var acceptsRounding = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Image(systemName: "wallet.bifold.fill")
                            .font(.largeTitle).foregroundStyle(WalletTheme.accent)
                        Text("Welcome back to iWallet").font(.title2.bold())
                        Text("Bring your previous history into your updated wallet. The original file will be kept safely on this device.")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 12)
                }
                if sourceURLs.count != 1 {
                    Section {
                        Label("More than one previous wallet was found", systemImage: "exclamationmark.triangle")
                        Text("Save copies of these files before continuing. They need to be reviewed separately to avoid mixing histories.")
                        ShareLink(items: sourceURLs) { Label("Save a copy of previous data", systemImage: "square.and.arrow.up") }
                    }
                } else {
                    Section {
                        Picker("Original wallet currency", selection: $currencyCode) {
                            Text("Choose a currency").tag("")
                            ForEach(WalletCurrency.allCases) { Text($0.displayName).tag($0.rawValue) }
                        }
                        .disabled(isWorking)
                        .accessibilityIdentifier("migrationCurrency")
                    } footer: {
                        Text("The previous app did not record a currency for each transaction. Confirm which currency your old amounts represent. No conversion will be performed.")
                    }
                    if let preview {
                        summary(preview)
                        Section {
                            ShareLink(items: [preview.snapshotURL, preview.reportURL]) {
                                Label("Save a copy of previous data", systemImage: "square.and.arrow.up")
                            }
                            Button(action: { Task { await finishImport(preview) } }) {
                                Label("Transfer my history", systemImage: "checkmark.shield")
                            }
                            .disabled(isWorking || (!preview.amountAdjustments.isEmpty && !acceptsRounding))
                            .accessibilityIdentifier("transferLegacyHistory")
                        }
                    } else {
                        Section {
                            Button { Task { await prepareImport() } } label: {
                                Label("Review my previous history", systemImage: "doc.text.magnifyingglass")
                            }
                            .disabled(currencyCode.isEmpty || isWorking)
                            .accessibilityIdentifier("reviewLegacyHistory")
                        }
                    }
                    if isWorking { ProgressView("Preparing your wallet").accessibilityIdentifier("migrationProgress") }
                }
                if let failure {
                    Section {
                        Label(failure, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                            .accessibilityIdentifier("migrationError")
                        ShareLink(items: sourceURLs) { Label("Save a copy of previous data", systemImage: "square.and.arrow.up") }
                    }
                }
            }
            .navigationTitle("Your history")
            .onAppear {
                guard currencyCode.isEmpty else { return }
                let candidates = LegacyWalletMigration.currencyCandidates(for: UserDefaults.standard.string(forKey: "currencySymbol"))
                if candidates.count == 1 { currencyCode = candidates[0].rawValue }
            }
            .onChange(of: currencyCode) { _, _ in
                preview = nil
                acceptsRounding = false
                failure = nil
            }
        }
    }

    private func summary(_ preview: LegacyWalletMigration.Preview) -> some View {
        Group {
            Section("Ready to transfer") {
                LabeledContent("Categories", value: String(preview.backup.categories.count))
                    .accessibilityIdentifier("migrationCategoryCount")
                    .accessibilityValue(String(preview.backup.categories.count))
                LabeledContent("Transactions", value: String(preview.backup.transactions.count))
                    .accessibilityIdentifier("migrationTransactionCount")
                    .accessibilityValue(String(preview.backup.transactions.count))
                LabeledContent("Currency", value: currencyCode)
                if let income = try? Money.sum(preview.backup.transactions.filter { $0.kind == TransactionKind.income.rawValue }.map(\.amountMinor)),
                   let expense = try? Money.sum(preview.backup.transactions.filter { $0.kind == TransactionKind.expense.rawValue }.map(\.amountMinor)) {
                    LabeledContent("Income", value: Money.format(income, currencyCode: currencyCode))
                    LabeledContent("Expense", value: Money.format(expense, currencyCode: currencyCode))
                }
            }
            if !preview.amountAdjustments.isEmpty {
                Section {
                    Text("Some old amounts need rounding to the currency's smallest unit. Review the changes before transferring.")
                    ForEach(preview.amountAdjustments.prefix(10)) { adjustment in
                        LabeledContent(adjustment.originalDecimal, value: Money.format(adjustment.amountMinor, currencyCode: currencyCode))
                    }
                    LabeledContent("Amounts requiring rounding", value: String(preview.amountAdjustments.count))
                    Text("The saved report contains every rounding change and the original values.")
                        .font(.footnote).foregroundStyle(.secondary)
                    Toggle("I have reviewed the rounding changes", isOn: $acceptsRounding)
                } header: { Text("Review amounts") }
            }
        }
    }

    @MainActor
    private func prepareImport() async {
        guard let source = sourceURLs.first, sourceURLs.count == 1 else { return }
        isWorking = true
        failure = nil
        defer { isWorking = false }
        let code = currencyCode
        do {
            preview = try await Task.detached(priority: .userInitiated) {
                try LegacyWalletMigration.prepare(from: source, currencyCode: code)
            }.value
        } catch { failure = error.localizedDescription }
    }

    @MainActor
    private func finishImport(_ prepared: LegacyWalletMigration.Preview) async {
        guard let source = sourceURLs.first else { return }
        isWorking = true
        failure = nil
        defer { isWorking = false }
        do {
            let digest = try await Task.detached(priority: .userInitiated) {
                try LegacyWalletMigration.sourceDigest(at: source)
            }.value
            guard digest == prepared.sourceDigest else { throw LegacyWalletMigrationError.sourceChanged }
            let receipt = WalletMigrationReceipt(sourceDigest: digest, currencyCode: currencyCode,
                transactionCount: prepared.backup.transactions.count, categoryCount: prepared.backup.categories.count)
            _ = try prepared.backup.restore(into: container.mainContext, migrationReceipt: receipt)
            onComplete()
        } catch { failure = error.localizedDescription }
    }
}

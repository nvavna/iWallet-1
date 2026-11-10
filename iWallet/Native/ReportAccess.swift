import StoreKit
import SwiftUI

@MainActor
final class ReportAccess: ObservableObject {
    static let productID = "com.idevnva.iwallet.spendingreports"

    @Published private(set) var isUnlocked: Bool?
    @Published private(set) var product: Product?
    @Published private(set) var isLoadingProduct = false
    @Published private(set) var isWorking = false
    @Published private(set) var message: LocalizedStringKey?
    private var entitlementRevision = 0

    func refreshEntitlement() async {
        entitlementRevision += 1
        let revision = entitlementRevision
        var unlocked = false
        for await result in StoreKit.Transaction.currentEntitlements {
            if case .verified(let transaction) = result, transaction.productID == Self.productID,
               transaction.revocationDate == nil {
                unlocked = true
                break
            }
        }
        if revision == entitlementRevision { isUnlocked = unlocked }
    }

    func observeTransactions() async {
        for await result in StoreKit.Transaction.updates {
            if case .verified(let transaction) = result, transaction.productID == Self.productID {
                await apply(transaction)
            }
        }
    }

    private func apply(_ transaction: StoreKit.Transaction) async {
        entitlementRevision += 1
        isUnlocked = transaction.revocationDate == nil
        message = nil
        await transaction.finish()
    }

    func loadProduct() async {
        guard product == nil, !isLoadingProduct else { return }
        isLoadingProduct = true
        defer { isLoadingProduct = false }
        do {
            product = try await Product.products(for: [Self.productID]).first { $0.type == .nonConsumable }
        } catch {
            product = nil
        }
    }

    func purchase() async {
        guard let product, !isWorking else { return }
        isWorking = true
        message = nil
        defer { isWorking = false }
        do {
            switch try await product.purchase() {
            case .success(.verified(let transaction)) where transaction.productID == Self.productID:
                await apply(transaction)
            case .userCancelled:
                break
            case .pending:
                message = "Your purchase is awaiting approval."
            default:
                message = "The purchase could not be verified."
            }
        } catch StoreKitError.userCancelled {
            return
        } catch {
            message = "The purchase could not be completed."
        }
    }

    func restore() async {
        guard !isWorking else { return }
        isWorking = true
        message = nil
        defer { isWorking = false }
        do {
            try await AppStore.sync()
            await refreshEntitlement()
            if isUnlocked == false { message = "No previous purchase was found." }
        } catch {
            message = "Purchases could not be restored."
        }
    }
}

struct SpendingReportDestination: View {
    let currencyCode: String
    @EnvironmentObject private var access: ReportAccess

    var body: some View {
        Group {
            if access.isUnlocked == true {
                SpendingReportView(currencyCode: currencyCode)
            } else if access.isUnlocked == nil {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                offer
            }
        }
        .task { await access.refreshEntitlement() }
        .task(id: access.isUnlocked) {
            if access.isUnlocked == false { await access.loadProduct() }
        }
    }

    private var offer: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 12) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.largeTitle).foregroundStyle(WalletTheme.accent).accessibilityHidden(true)
                    Text("Spending report").font(.largeTitle.bold())
                    Text("Compare spending for any dates, see totals by category, and save a PDF.")
                        .font(.body).foregroundStyle(WalletTheme.secondaryInk)
                    NavigationLink {
                        SpendingReportView(sampleCurrencyCode: currencyCode)
                    } label: {
                        Label("Sample report", systemImage: "doc.text").frame(minHeight: 44)
                    }
                    .accessibilityIdentifier("openSampleSpendingReport")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .walletSurface()
                VStack(alignment: .leading, spacing: 10) {
                    Text("One-time purchase").font(.headline)
                    if let product = access.product {
                        Button {
                            Task { await access.purchase() }
                        } label: {
                            ViewThatFits(in: .horizontal) {
                                HStack { Text("Unlock reports"); Spacer(); Text(verbatim: product.displayPrice).bold() }
                                VStack(alignment: .leading) { Text("Unlock reports"); Text(verbatim: product.displayPrice).bold() }
                            }.frame(maxWidth: .infinity, minHeight: 38)
                        }
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("buySpendingReports")
                    } else if access.isLoadingProduct {
                        ProgressView()
                    } else {
                        Text("The App Store price is unavailable.").foregroundStyle(WalletTheme.secondaryInk)
                        Button("Try again") { Task { await access.loadProduct() } }
                    }
                    Button("Restore purchases") { Task { await access.restore() } }
                        .frame(minHeight: 44).accessibilityIdentifier("restoreSpendingReports")
                    if access.isWorking { ProgressView() }
                    if let message = access.message {
                        Text(message).font(.callout).foregroundStyle(WalletTheme.ink)
                            .accessibilityIdentifier("reportPurchaseMessage")
                    }
                }
                .disabled(access.isWorking)
                .frame(maxWidth: .infinity, alignment: .leading)
                .walletSurface()
            }.padding(18)
        }
        .background(WalletTheme.background)
        .navigationBarTitleDisplayMode(.inline)
    }
}

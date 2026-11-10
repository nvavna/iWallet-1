// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "WalletCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "WalletCore", targets: ["WalletCore"])],
    dependencies: [
        // Transitional reader only. All new and imported records persist in SwiftData.
        .package(url: "https://github.com/realm/realm-swift.git", exact: "20.0.6")
    ],
    targets: [
        .target(name: "WalletCore", dependencies: [.product(name: "RealmSwift", package: "realm-swift")], path: "iWallet/Native",
                exclude: ["ReportAccess.swift", "SpendingReportView.swift", "SpendingReportPDF.swift", "PaymentReminderViews.swift", "WalletBudgetViews.swift", "WalletForecastViews.swift",
                          "RecurringPaymentViews.swift", "WalletAnalyticsViews.swift", "CategoryViews.swift", "TransactionViews.swift", "WalletHomeView.swift",
                          "WalletSettingsView.swift", "WalletMigrationView.swift", "WalletTheme.swift", "iWalletApp.swift", "PrivacyInfo.xcprivacy", "ThirdPartyNotices.txt"],
                sources: ["WalletTransactionCSV.swift", "PaymentReminders.swift", "WalletBudgets.swift", "WalletForecast.swift",
                          "RecurringPayments.swift", "WalletInsights.swift", "WalletModels.swift", "Money.swift", "WalletStore.swift", "WalletBackup.swift", "LegacyWalletMigration.swift"]),
        .testTarget(name: "WalletCoreTests", dependencies: ["WalletCore"], path: "Tests/WalletCoreTests"),
        .testTarget(name: "LegacyMigrationTests", dependencies: ["WalletCore", .product(name: "RealmSwift", package: "realm-swift")],
                    path: "Tests/LegacyMigrationTests")
    ]
)

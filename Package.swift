// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "WalletCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "WalletCore", targets: ["WalletCore"])],
    targets: [
        .target(name: "WalletCore", path: "iWallet/Native",
                exclude: ["CategoryViews.swift", "TransactionViews.swift", "WalletHomeView.swift",
                          "WalletSettingsView.swift", "WalletTheme.swift", "iWalletApp.swift", "PrivacyInfo.xcprivacy"],
                sources: ["WalletModels.swift", "Money.swift", "WalletStore.swift"]),
        .testTarget(name: "WalletCoreTests", dependencies: ["WalletCore"], path: "Tests/WalletCoreTests")
    ]
)

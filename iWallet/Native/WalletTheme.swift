import SwiftUI

enum WalletDefaults {
    static var currencyCode: String {
        WalletCurrency(rawValue: Locale.current.currency?.identifier ?? "USD")?.rawValue ?? "USD"
    }
}

enum WalletTheme {
    static let accent = Color("colorBalanceText")
    static let background = Color("colorBG")
    static let surface = Color("colorBalanceBG")

    static func categoryColor(_ name: String) -> Color {
        Color(name.isEmpty ? "colorBlue" : name)
    }
}

struct WalletSurface: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(WalletTheme.surface, in: RoundedRectangle(cornerRadius: 12))
    }
}

extension View {
    func walletSurface() -> some View { modifier(WalletSurface()) }
}

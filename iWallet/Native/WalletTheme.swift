import SwiftUI

enum WalletDefaults {
    static var currencyCode: String {
        WalletCurrency(rawValue: Locale.current.currency?.identifier ?? "USD")?.rawValue ?? "USD"
    }
}

enum WalletTheme {
    static let accent = Color.indigo
    static let background = Color(uiColor: .systemGroupedBackground)
    static let surface = Color(uiColor: .secondarySystemGroupedBackground)

    static func categoryColor(_ name: String) -> Color {
        Color(name.isEmpty ? "colorBlue" : name)
    }
}

struct WalletSurface: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(20)
            .background(WalletTheme.surface, in: RoundedRectangle(cornerRadius: 24))
    }
}

extension View {
    func walletSurface() -> some View { modifier(WalletSurface()) }
}

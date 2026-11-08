import SwiftUI

enum WalletDefaults {
    static var currencyCode: String {
        WalletCurrency(rawValue: Locale.current.currency?.identifier ?? "USD")?.rawValue ?? "USD"
    }
}

enum WalletTheme {
    static let accent = Color.blue
    static let background = Color(uiColor: .systemGroupedBackground)
    static let surface = Color(uiColor: .secondarySystemGroupedBackground)

    static func categorySymbol(_ name: String) -> String {
        UIImage(systemName: name) == nil ? "square.grid.2x2" : name
    }

    static func categoryColor(_ name: String) -> Color {
        // Keep legacy color identifiers in the store while presenting a legible,
        // consistent palette in both appearances.
        let palette: (light: UInt32, dark: UInt32)
        switch name {
        case let value where value.hasPrefix("colorGreen"): palette = (0x287447, 0x81CAA1)
        case let value where value.hasPrefix("colorRed"): palette = (0xB4434B, 0xF39BA2)
        case let value where value.hasPrefix("colorYellow"): palette = (0x8C6400, 0xE5BF73)
        case let value where value.hasPrefix("colorPurple"): palette = (0x7856C5, 0xBEA6EF)
        case let value where value.hasPrefix("colorBrown"): palette = (0x856047, 0xD6B498)
        case let value where value.hasPrefix("colorGray"): palette = (0x59616B, 0xABB2BD)
        default: palette = (0x2563B8, 0x8AB4F8)
        }
        return Color(uiColor: UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? palette.dark : palette.light
            return UIColor(red: CGFloat((hex >> 16) & 0xff) / 255,
                           green: CGFloat((hex >> 8) & 0xff) / 255,
                           blue: CGFloat(hex & 0xff) / 255, alpha: 1)
        })
    }
}

struct WalletSurface: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(WalletTheme.surface, in: RoundedRectangle(cornerRadius: 16))
    }
}

extension View {
    func walletSurface() -> some View { modifier(WalletSurface()) }
}

struct WalletEmptyListRow: View {
    let title: LocalizedStringKey
    let systemImage: String
    let message: LocalizedStringKey
    let actionTitle: LocalizedStringKey
    let actionIdentifier: String
    let action: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: systemImage)
                .font(.largeTitle)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            VStack(spacing: 6) {
                Text(title)
                    .font(.title2.bold())
                    .accessibilityAddTraits(.isHeader)
                Text(message)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            Button(action: action) {
                Text(actionTitle)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .accessibilityIdentifier(actionIdentifier)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }
}

struct WalletFormMenuLabel: View {
    let title: LocalizedStringKey
    let value: String
    init(_ title: LocalizedStringKey, value: String) { self.title = title; self.value = value }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.subheadline).foregroundStyle(Color(uiColor: .secondaryLabel))
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(value).foregroundStyle(WalletTheme.accent)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption.weight(.semibold)).accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

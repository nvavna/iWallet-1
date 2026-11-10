import SwiftUI

enum WalletDefaults {
    static var currencyCode: String {
        WalletCurrency(rawValue: Locale.current.currency?.identifier ?? "USD")?.rawValue ?? "USD"
    }
}

enum WalletTheme {
    static let accent = adaptive(0x28593E, 0xACE2AD)
    static let background = adaptive(0xF5F4ED, 0x131B17)
    static let surface = adaptive(0xFFFDF8, 0x202923)
    static let ink = adaptive(0x182B22, 0xF1F3E9)
    static let secondaryInk = adaptive(0x58655C, 0xB4C0B4)
    static let hairline = adaptive(0xD9DED3, 0x39463C)
    static let income = adaptive(0x277249, 0x93D6A5)
    static let expense = adaptive(0xA04734, 0xF1A58D)
    static let forest = Color(red: 0.075, green: 0.215, blue: 0.163)
    static let mint = Color(red: 0.82, green: 0.94, blue: 0.68)

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
        return adaptive(palette.light, palette.dark)
    }

    private static func adaptive(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
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
            .background(WalletTheme.surface, in: .rect(cornerRadius: 20))
            .overlay { RoundedRectangle(cornerRadius: 20).strokeBorder(WalletTheme.hairline, lineWidth: 0.6) }
    }
}

private struct WalletChoiceStyle: ViewModifier {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    func body(content: Content) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            content.pickerStyle(.menu)
                .font(.body)
                .frame(minHeight: 44)
        } else {
            content.pickerStyle(.segmented)
        }
    }
}

extension View {
    func walletChoiceStyle() -> some View { modifier(WalletChoiceStyle()) }
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
        VStack(spacing: 18) {
            Image(systemName: systemImage)
                .font(.title.weight(.medium))
                .foregroundStyle(WalletTheme.accent)
                .frame(width: 62, height: 62)
                .background(WalletTheme.accent.opacity(0.09), in: .rect(cornerRadius: 20))
                .accessibilityHidden(true)
            VStack(spacing: 6) {
                Text(title)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(WalletTheme.ink)
                    .accessibilityAddTraits(.isHeader)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(WalletTheme.secondaryInk)
            }
            Button(action: action) {
                Text(actionTitle)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
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
            Text(title).font(.subheadline).foregroundStyle(WalletTheme.secondaryInk)
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

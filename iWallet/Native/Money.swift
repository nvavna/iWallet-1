import Foundation

enum MoneyError: LocalizedError, Equatable {
    case invalidAmount
    case nonPositiveAmount
    case tooManyFractionDigits(Int)
    case amountTooLarge
    case unsupportedCurrency
    case overflow

    var errorDescription: String? {
        switch self {
        case .invalidAmount:
            return NSLocalizedString("Enter a valid amount using your decimal separator.", comment: "Amount error")
        case .nonPositiveAmount:
            return NSLocalizedString("The amount must be greater than zero.", comment: "Amount error")
        case .tooManyFractionDigits(let count):
            return String(format: NSLocalizedString("This currency allows %d decimal places.", comment: "Amount error"), count)
        case .amountTooLarge:
            return NSLocalizedString("This amount is too large.", comment: "Amount error")
        case .unsupportedCurrency:
            return NSLocalizedString("Choose a supported currency.", comment: "Amount error")
        case .overflow:
            return NSLocalizedString("The total exceeds the supported range.", comment: "Amount error")
        }
    }
}

enum Money {
    static let maximumAmountMinor: Int64 = 9_000_000_000_000

    /// Parses the entire input, never a numeric prefix. Grouping must match the locale.
    /// Decimal parsing and scaling avoid binary floating-point conversion.
    static func parse(_ text: String, currencyCode: String, locale: Locale = .current) throws -> Int64 {
        guard let currency = WalletCurrency(rawValue: currencyCode) else { throw MoneyError.unsupportedCurrency }
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        let decimalSeparator = formatter.decimalSeparator ?? "."
        let groupingSeparator = formatter.groupingSeparator ?? ","
        let trimmed = try normalizeDecimalDigits(text.trimmingCharacters(in: .whitespacesAndNewlines))
        guard !trimmed.isEmpty else { throw MoneyError.invalidAmount }
        guard !trimmed.hasPrefix("-"), !trimmed.hasPrefix("−") else { throw MoneyError.nonPositiveAmount }

        let parts = trimmed.components(separatedBy: decimalSeparator)
        guard parts.count <= 2 else { throw MoneyError.invalidAmount }
        let whole = try ungroup(parts[0], separator: groupingSeparator,
                                primarySize: formatter.groupingSize,
                                secondarySize: formatter.secondaryGroupingSize)
        let fraction = parts.count == 2 ? parts[1] : ""
        guard fraction.isEmpty || fraction.allSatisfy({ $0.isASCII && $0.isNumber }) else {
            throw MoneyError.invalidAmount
        }
        guard !whole.isEmpty || !fraction.isEmpty else { throw MoneyError.invalidAmount }
        guard fraction.count <= currency.fractionDigits else {
            throw MoneyError.tooManyFractionDigits(currency.fractionDigits)
        }
        // A separator with no fraction is valid while leaving an amount field ("12,").
        let normalized = (whole.isEmpty ? "0" : whole) + (fraction.isEmpty ? "" : "." + fraction)
        guard normalized.count <= 40,
              let decimal = Decimal(string: normalized, locale: Locale(identifier: "en_US_POSIX")) else {
            throw MoneyError.amountTooLarge
        }
        let minor = decimal * scale(for: currency)
        guard minor > 0 else { throw MoneyError.nonPositiveAmount }
        guard minor <= Decimal(maximumAmountMinor) else { throw MoneyError.amountTooLarge }
        return NSDecimalNumber(decimal: minor).int64Value
    }

    static func format(_ amountMinor: Int64, currencyCode: String, locale: Locale = .current) -> String {
        guard let currency = WalletCurrency(rawValue: currencyCode) else {
            return "\(amountMinor) \(currencyCode)"
        }
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .currency
        formatter.currencyCode = currency.rawValue
        formatter.minimumFractionDigits = currency.fractionDigits
        formatter.maximumFractionDigits = currency.fractionDigits
        let decimal = Decimal(amountMinor) / scale(for: currency)
        return formatter.string(from: NSDecimalNumber(decimal: decimal)) ?? "\(decimal) \(currencyCode)"
    }

    /// The editable equivalent of `format`, without a currency symbol or grouping.
    static func inputText(_ amountMinor: Int64, currencyCode: String, locale: Locale = .current) -> String {
        guard let currency = WalletCurrency(rawValue: currencyCode) else { return String(amountMinor) }
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = currency.fractionDigits
        let decimal = Decimal(amountMinor) / scale(for: currency)
        return formatter.string(from: NSDecimalNumber(decimal: decimal)) ?? "\(decimal)"
    }

    static func sum(_ amounts: [Int64]) throws -> Int64 {
        try amounts.reduce(0) { result, amount in
            let addition = result.addingReportingOverflow(amount)
            guard !addition.overflow else { throw MoneyError.overflow }
            return addition.partialValue
        }
    }

    /// A balance for each ISO currency. No implicit currency conversion or mixed total.
    static func totalsByCurrency(_ transactions: [WalletTransaction], kind: TransactionKind? = nil) throws -> [String: Int64] {
        var totals: [String: Int64] = [:]
        for transaction in transactions where kind == nil || transaction.kind == kind {
            guard WalletCurrency(rawValue: transaction.currencyCode) != nil else { throw MoneyError.unsupportedCurrency }
            guard transaction.amountMinor > 0, transaction.amountMinor <= maximumAmountMinor else { throw MoneyError.invalidAmount }
            let amount = kind == nil && transaction.kind == .expense ? -transaction.amountMinor : transaction.amountMinor
            totals[transaction.currencyCode] = try sum([totals[transaction.currencyCode, default: 0], amount])
        }
        return totals
    }

    private static func scale(for currency: WalletCurrency) -> Decimal {
        currency.fractionDigits == 0 ? 1 : 100
    }

    private static func normalizeDecimalDigits(_ text: String) throws -> String {
        var normalized = ""
        for scalar in text.unicodeScalars {
            if scalar.properties.numericType == .decimal {
                guard let value = Character(scalar).wholeNumberValue, (0...9).contains(value) else {
                    throw MoneyError.invalidAmount
                }
                normalized.append(String(value))
            } else {
                // Preserve separators for locale validation. Other numeric characters
                // (fractions, Roman numerals, superscripts) remain invalid input.
                normalized.unicodeScalars.append(scalar)
            }
        }
        return normalized
    }

    private static func ungroup(_ raw: String, separator: String, primarySize: Int, secondarySize: Int) throws -> String {
        var text = raw
        let grouping: String
        if separator.allSatisfy(\.isWhitespace) {
            // iOS keyboards and pasted values use several nonbreaking-space forms.
            for space in [" ", "\u{00A0}", "\u{202F}"] { text = text.replacingOccurrences(of: space, with: " ") }
            grouping = " "
        } else {
            grouping = separator
        }
        guard !text.isEmpty else { return "" }
        let groups = text.components(separatedBy: grouping)
        guard groups.allSatisfy({ !$0.isEmpty && $0.allSatisfy({ $0.isASCII && $0.isNumber }) }) else {
            throw MoneyError.invalidAmount
        }
        if groups.count > 1 {
            let primary = primarySize > 0 ? primarySize : 3
            let secondary = secondarySize > 0 ? secondarySize : primary
            guard groups.last?.count == primary,
                  let first = groups.first, (1...secondary).contains(first.count),
                  groups.dropFirst().dropLast().allSatisfy({ $0.count == secondary }) else {
                throw MoneyError.invalidAmount
            }
        }
        return groups.joined()
    }
}

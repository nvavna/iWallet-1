import Foundation
import SwiftData

enum TransactionKind: String, Codable, CaseIterable, Identifiable {
    case expense
    case income

    var id: String { rawValue }
    var localizedName: String {
        NSLocalizedString(self == .expense ? "Expense" : "Income", comment: "Transaction kind")
    }
}

@Model
final class WalletCategory {
    @Attribute(.unique) var id: UUID
    var name: String
    var icon: String
    var color: String
    var kindRaw: String
    var isArchived: Bool
    @Relationship(deleteRule: .nullify, inverse: \WalletTransaction.category)
    var transactions: [WalletTransaction] = []

    var kind: TransactionKind {
        get { TransactionKind(rawValue: kindRaw) ?? .expense }
        set { kindRaw = newValue.rawValue }
    }

    init(name: String, icon: String, color: String, kind: TransactionKind,
         isArchived: Bool = false, id: UUID = UUID()) {
        self.id = id
        self.name = name
        self.icon = icon
        self.color = color
        self.kindRaw = kind.rawValue
        self.isArchived = isArchived
    }
}

@Model
final class WalletTransaction {
    @Attribute(.unique) var id: UUID
    var amountMinor: Int64
    var currencyCode: String
    var date: Date
    var note: String
    var kindRaw: String
    var category: WalletCategory?

    var kind: TransactionKind {
        get { TransactionKind(rawValue: kindRaw) ?? .expense }
        set { kindRaw = newValue.rawValue }
    }

    init(amountMinor: Int64, currencyCode: String, date: Date = Date(),
         note: String = "", kind: TransactionKind, category: WalletCategory? = nil,
         id: UUID = UUID()) {
        self.id = id
        self.amountMinor = amountMinor
        self.currencyCode = currencyCode
        self.date = date
        self.note = note
        self.kindRaw = kind.rawValue
        self.category = category
    }
}

@Model
final class WalletMigrationReceipt {
    @Attribute(.unique) var id: String
    var sourceDigest: String
    var currencyCode: String
    var completedAt: Date
    var transactionCount: Int
    var categoryCount: Int

    init(id: String = "realm-v1", sourceDigest: String, currencyCode: String,
         completedAt: Date = Date(), transactionCount: Int, categoryCount: Int) {
        self.id = id
        self.sourceDigest = sourceDigest
        self.currencyCode = currencyCode
        self.completedAt = completedAt
        self.transactionCount = transactionCount
        self.categoryCount = categoryCount
    }
}

enum WalletCurrency: String, CaseIterable, Identifiable {
    case usd = "USD", eur = "EUR", jpy = "JPY", gbp = "GBP"
    case aud = "AUD", cad = "CAD", chf = "CHF", cny = "CNY", rub = "RUB"
    case inr = "INR", brl = "BRL", zar = "ZAR", `try` = "TRY", mxn = "MXN"
    case idr = "IDR", hkd = "HKD", sgd = "SGD", twd = "TWD", krw = "KRW"
    case thb = "THB", myr = "MYR", php = "PHP", vnd = "VND", kes = "KES"
    case egp = "EGP", byn = "BYN", uah = "UAH", kzt = "KZT", tmt = "TMT", czk = "CZK"

    var id: String { rawValue }
    var fractionDigits: Int {
        switch self {
        case .jpy, .krw, .vnd: return 0
        default: return 2
        }
    }
    var displayName: String {
        let name = Locale.current.localizedString(forCurrencyCode: rawValue) ?? rawValue
        return "\(rawValue) · \(name)"
    }
}

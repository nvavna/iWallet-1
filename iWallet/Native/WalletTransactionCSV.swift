import Foundation
import SwiftData

struct WalletTransactionCSV: Sendable {
    let data: Data
    let filename: String

    /// The period uses the same civil days shown by the date pickers, including the entire last day.
    static func export(context: ModelContext, from startDate: Date, through endDate: Date,
                       calendar: Calendar = .current, locale: Locale = .current) throws -> Self? {
        let start = calendar.startOfDay(for: startDate)
        guard let lastDay = calendar.dateInterval(of: .day, for: endDate), start < lastDay.end else {
            throw WalletStoreError.invalidDate
        }
        let end = lastDay.end
        var fetch = FetchDescriptor<WalletTransaction>(
            predicate: #Predicate { $0.date >= start && $0.date < end },
            sortBy: [SortDescriptor(\.date), SortDescriptor(\.id)]
        )
        fetch.relationshipKeyPathsForPrefetching = [\.category]

        let decimalSeparator = locale.decimalSeparator == "," ? "," : "."
        let delimiter = decimalSeparator == "," ? ";" : ","
        let dates = DateFormatter()
        dates.locale = Locale(identifier: "en_US_POSIX")
        dates.calendar = Calendar(identifier: .gregorian)
        dates.timeZone = calendar.timeZone
        dates.dateFormat = "yyyy-MM-dd"
        let filename = "iWallet-\(dates.string(from: start))_\(dates.string(from: lastDay.start))"
        dates.dateFormat = "yyyy-MM-dd HH:mm:ss"

        // Excel recognizes UTF-8 from the BOM. Use CRLF between records and retain newlines inside quoted fields.
        var data = Data([0xef, 0xbb, 0xbf])
        func appendRow(_ fields: [String]) {
            data.append(contentsOf: fields.joined(separator: delimiter).utf8)
            data.append(contentsOf: [0x0d, 0x0a])
        }
        let headers = ["Date", "Type", "Amount", "Currency", "Category", "Note"]
        appendRow(headers.map { quotedText(NSLocalizedString($0, comment: "CSV column")) })
        var hasTransactions = false
        try context.enumerate(fetch, batchSize: 500) { transaction in
            try Task.checkCancellation()
            guard let currency = WalletCurrency(rawValue: transaction.currencyCode) else {
                throw MoneyError.unsupportedCurrency
            }
            guard (1...Money.maximumAmountMinor).contains(transaction.amountMinor) else {
                throw MoneyError.invalidAmount
            }
            let magnitude = numericAmount(transaction.amountMinor, digits: currency.fractionDigits,
                                          separator: decimalSeparator)
            let amount = transaction.kind == .expense ? "-" + magnitude : magnitude
            let category = transaction.category?.name ?? NSLocalizedString("Uncategorized", comment: "CSV category")
            appendRow([dates.string(from: transaction.date), quotedText(transaction.kind.localizedName), amount,
                       currency.rawValue, quotedText(category), quotedText(transaction.note)])
            hasTransactions = true
        }
        return hasTransactions ? Self(data: data, filename: filename) : nil
    }

    private static func numericAmount(_ minor: Int64, digits: Int, separator: String) -> String {
        let raw = String(minor)
        guard digits > 0 else { return raw }
        let padded = String(repeating: "0", count: max(0, digits + 1 - raw.count)) + raw
        return padded.dropLast(digits) + separator + padded.suffix(digits)
    }

    private static func quotedText(_ text: String) -> String {
        // CSV quotes alone do not protect spreadsheet cells from formula evaluation.
        let ignoredPrefix = CharacterSet.whitespacesAndNewlines.union(.controlCharacters)
        let first = text.unicodeScalars.first { !ignoredPrefix.contains($0) }
        let formulaPrefixes = CharacterSet(charactersIn: "=+-@＝＋－＠")
        let prefix = first.map(formulaPrefixes.contains) == true ? "'" : ""
        return "\"" + prefix + text.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}

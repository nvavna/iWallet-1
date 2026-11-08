import Foundation
import SwiftData
import XCTest
@testable import WalletCore

final class WalletTransactionCSVTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return calendar
    }

    private func makeDate(_ value: String) throws -> Date {
        try XCTUnwrap(ISO8601DateFormatter().date(from: value))
    }

    @MainActor
    func testIncludesEntireSelectedDayAcrossDaylightSavingTimeAndHonorsLocalTimes() async throws {
        let container = try WalletStore.makeContainer(inMemory: true)
        let context = container.mainContext
        let dayStart = try makeDate("2026-03-08T08:00:00Z")
        let nextMidnight = try makeDate("2026-03-09T07:00:00Z")
        let records = [(dayStart.addingTimeInterval(-1), "before"), (nextMidnight, "after"),
                       (nextMidnight.addingTimeInterval(-0.125), "last"), (dayStart, "first")]
        for (date, note) in records {
            context.insert(WalletTransaction(amountMinor: 1, currencyCode: "USD", date: date, note: note, kind: .income))
        }
        try context.save()
        let localNoon = dayStart.addingTimeInterval(11 * 3600)
        let csv = try XCTUnwrap(WalletTransactionCSV.export(context: context, from: localNoon, through: localNoon,
                                                             calendar: calendar, locale: Locale(identifier: "en_US")))
        XCTAssertEqual(csv.filename, "iWallet-2026-03-08_2026-03-08")
        XCTAssertEqual(Array(csv.data.prefix(3)), [0xef, 0xbb, 0xbf])
        let rows = String(decoding: csv.data.dropFirst(3), as: UTF8.self).components(separatedBy: "\r\n")
        XCTAssertEqual(rows.count, 4)
        XCTAssertTrue(rows[1].hasPrefix("2026-03-08 00:00:00,"))
        XCTAssertTrue(rows[1].contains(",0.01,USD,"))
        XCTAssertTrue(rows[1].hasSuffix(",\"first\""))
        XCTAssertTrue(rows[2].hasPrefix("2026-03-08 23:59:59,"))
        XCTAssertTrue(rows[2].hasSuffix(",\"last\""))
        XCTAssertEqual(rows.last, "")
    }

    @MainActor
    func testRussianCSVPreservesCyrillicQuotesDelimitersAndEmbeddedNewlinesWithExactAmounts() async throws {
        let container = try WalletStore.makeContainer(inMemory: true)
        let context = container.mainContext
        let day = try makeDate("2026-11-08T20:00:00Z")
        let category = WalletCategory(name: "Кафе; \"Дом\"", icon: "cup.and.saucer", color: "colorBlue",
                                      kind: .expense, isArchived: true)
        context.insert(category)
        let rubles = WalletTransaction(amountMinor: Money.maximumAmountMinor - 1, currencyCode: "RUB",
                                       date: day, note: "Кофе, чай; \"с собой\"\r\nещё строка",
                                       kind: .expense, category: category)
        let yen = WalletTransaction(amountMinor: 123, currencyCode: "JPY", date: day.addingTimeInterval(1),
                                    note: "", kind: .income)
        context.insert(rubles)
        context.insert(yen)
        try context.save()
        let csv = try XCTUnwrap(WalletTransactionCSV.export(context: context, from: day, through: day,
                                                             calendar: calendar, locale: Locale(identifier: "ru_RU")))
        let text = String(decoding: csv.data.dropFirst(3), as: UTF8.self)
        let expense = TransactionKind.expense.localizedName
        let income = TransactionKind.income.localizedName
        let uncategorized = NSLocalizedString("Uncategorized", comment: "")
        XCTAssertTrue(text.contains("2026-11-08 12:00:00;\"\(expense)\";-89999999999,99;RUB;\"Кафе; \"\"Дом\"\"\";\"Кофе, чай; \"\"с собой\"\"\r\nещё строка\"\r\n"))
        XCTAssertTrue(text.hasSuffix("2026-11-08 12:00:01;\"\(income)\";123;JPY;\"\(uncategorized)\";\"\"\r\n"))
    }

    @MainActor
    func testSignOfExportedNumbersProducesCorrectBalanceIncludingYen() async throws {
        let container = try WalletStore.makeContainer(inMemory: true)
        let context = container.mainContext
        let day = try makeDate("2026-11-08T20:00:00Z")
        for (kind, amount, currency) in [(TransactionKind.expense, 920, "JPY"), (.income, 8400, "JPY"),
                                        (.income, 100, "USD"), (.expense, 1, "USD")] {
            context.insert(WalletTransaction(amountMinor: Int64(amount), currencyCode: currency,
                                             date: day, kind: kind))
        }
        try context.save()
        let csv = try XCTUnwrap(WalletTransactionCSV.export(context: context, from: day, through: day,
                                                             calendar: calendar, locale: Locale(identifier: "en_US")))
        let text = String(decoding: csv.data.dropFirst(3), as: UTF8.self)
        var sums = [String: Decimal]()
        for line in text.components(separatedBy: "\r\n").dropFirst() where !line.isEmpty {
            let fields = line.components(separatedBy: ",")
            let value = try XCTUnwrap(Decimal(string: fields[2], locale: Locale(identifier: "en_US_POSIX")))
            sums[fields[3], default: 0] += value
        }
        XCTAssertEqual(sums["JPY"], 7480)
        XCTAssertEqual(sums["USD"], Decimal(99) / 100)
    }

    @MainActor
    func testFormulaLikeCategoryAndNotesAreQuotedAsLiteralText() async throws {
        let container = try WalletStore.makeContainer(inMemory: true)
        let context = container.mainContext
        let day = try makeDate("2026-11-08T20:00:00Z")
        let category = WalletCategory(name: "=4+4", icon: "cart", color: "colorBlue", kind: .expense)
        context.insert(category)
        let notes = [" =1+1", "+2", "-3", "\t@sum", "＝4", "обычная заметка"]
        for (index, note) in notes.enumerated() {
            context.insert(WalletTransaction(amountMinor: 1000, currencyCode: "EUR",
                                             date: day.addingTimeInterval(Double(index)), note: note,
                                             kind: .expense, category: category))
        }
        try context.save()
        let csv = try XCTUnwrap(WalletTransactionCSV.export(context: context, from: day, through: day,
                                                             calendar: calendar, locale: Locale(identifier: "en_US")))
        let text = String(decoding: csv.data.dropFirst(3), as: UTF8.self)
        for note in notes.dropLast() {
            XCTAssertTrue(text.contains(",-10.00,EUR,\"'=4+4\",\"'\(note)\"\r\n"))
        }
        XCTAssertTrue(text.hasSuffix(",-10.00,EUR,\"'=4+4\",\"обычная заметка\"\r\n"))
    }

    @MainActor
    func testNoTransactionsProducesNoFileAndReversedDaysAreRejected() async throws {
        let container = try WalletStore.makeContainer(inMemory: true)
        let today = try makeDate("2026-06-15T12:00:00Z")
        let yesterday = try makeDate("2026-06-14T12:00:00Z")
        XCTAssertNil(try WalletTransactionCSV.export(context: container.mainContext, from: yesterday, through: today,
                                                     calendar: calendar))
        XCTAssertThrowsError(try WalletTransactionCSV.export(context: container.mainContext, from: today,
                                                              through: yesterday, calendar: calendar))
    }
}

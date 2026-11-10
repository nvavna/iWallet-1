import Foundation
import XCTest
@testable import WalletCore

final class MoneyTests: XCTestCase {
    private let us = Locale(identifier: "en_US")
    private let ru = Locale(identifier: "ru_RU")

    func testLocaleParsingPreservesExactMinorUnits() throws {
        XCTAssertEqual(try Money.parse("1,234,567.89", currencyCode: "USD", locale: us), 123_456_789)
        XCTAssertEqual(try Money.parse("1 234 567,89", currencyCode: "RUB", locale: ru), 123_456_789)
        XCTAssertEqual(try Money.parse("1\u{00A0}234,56", currencyCode: "RUB", locale: ru), 123_456)
        XCTAssertEqual(try Money.parse("1\u{202F}234,56", currencyCode: "RUB", locale: ru), 123_456)
        XCTAssertEqual(try Money.parse(" 0,01 ", currencyCode: "EUR", locale: ru), 1)
        XCTAssertEqual(try Money.parse(".01", currencyCode: "USD", locale: us), 1)
    }

    func testLargeAmountsDoNotLoseCents() throws {
        XCTAssertEqual(try Money.parse("1000000.01", currencyCode: "USD", locale: us), 100_000_001)
        XCTAssertEqual(try Money.parse("90000000000.00", currencyCode: "USD", locale: us), Money.maximumAmountMinor)
        XCTAssertThrowsError(try Money.parse("90000000000.01", currencyCode: "USD", locale: us))
        XCTAssertEqual(try Money.sum(Array(repeating: 1, count: 10_000)), 10_000)
    }

    func testRejectsNonPositiveAndMalformedAmounts() {
        for input in ["0", "0.00", "-1.20", "−1.20", "", " ", "NaN", "inf", "1e3", "+12", "12abc", "12.3.4", "12,34.56", "1,23,456.78", "$12", "1 234.56"] {
            XCTAssertThrowsError(try Money.parse(input, currencyCode: "USD", locale: us), input)
        }
        XCTAssertThrowsError(try Money.parse("12.34", currencyCode: "RUB", locale: ru))
        XCTAssertThrowsError(try Money.parse("1", currencyCode: "XYZ", locale: us))
    }

    func testRejectsExtraPrecisionInsteadOfRounding() {
        XCTAssertThrowsError(try Money.parse("1.001", currencyCode: "USD", locale: us)) {
            XCTAssertEqual($0 as? MoneyError, .tooManyFractionDigits(2))
        }
        XCTAssertThrowsError(try Money.parse("1.000", currencyCode: "USD", locale: us))
        XCTAssertThrowsError(try Money.parse("1.1", currencyCode: "JPY", locale: us))
    }

    func testCurrenciesWithNoFractionalUnits() throws {
        for code in ["JPY", "KRW", "VND"] {
            XCTAssertEqual(try Money.parse("1234", currencyCode: code, locale: us), 1234)
            XCTAssertFalse(Money.inputText(1234, currencyCode: code, locale: us).contains("."))
        }
        XCTAssertEqual(try Money.parse("1.23", currencyCode: "IDR", locale: us), 123)
    }

    func testInputFormattingRoundTripsWithoutBinaryRounding() throws {
        for locale in [us, ru] {
            for amount: Int64 in [1, 101, 100_000_001, Money.maximumAmountMinor] {
                let input = Money.inputText(amount, currencyCode: "RUB", locale: locale)
                XCTAssertEqual(try Money.parse(input, currencyCode: "RUB", locale: locale), amount)
            }
        }
        XCTAssertEqual(Money.format(100_000_001, currencyCode: "USD", locale: us), "$1,000,000.01")
        XCTAssertEqual(Money.format(-101, currencyCode: "USD", locale: us), "-$1.01")
    }

    func testAggregationReportsOverflow() {
        XCTAssertThrowsError(try Money.sum([Int64.max, 1])) {
            XCTAssertEqual($0 as? MoneyError, .overflow)
        }
        XCTAssertThrowsError(try Money.sum([Int64.min, -1]))
    }

    func testAverageUsesActiveDaysAndEmptyHistory() throws {
        // Three expenses on two active days must not be averaged per transaction.
        XCTAssertEqual(try Money.averagePerDay([100, 200, 600], activeDays: 2), 450)
        XCTAssertEqual(try Money.averagePerDay([1_234], activeDays: 1), 1_234)
        XCTAssertEqual(try Money.averagePerDay([], activeDays: 0), 0)
        XCTAssertEqual(try Money.averagePerDay([], activeDays: 3), 0)
        XCTAssertEqual(try Money.averagePerDay([0, 0], activeDays: 2), 0)
    }

    func testAverageRoundsHalfUpAtMinorUnit() throws {
        XCTAssertEqual(try Money.averagePerDay([1], activeDays: 2), 1)
        XCTAssertEqual(try Money.averagePerDay([2, 3], activeDays: 2), 3)
        XCTAssertEqual(try Money.averagePerDay([4], activeDays: 3), 1)
        XCTAssertEqual(try Money.averagePerDay([5], activeDays: 3), 2)
        XCTAssertEqual(try Money.averagePerDay([1], activeDays: 3), 0)
    }

    func testAverageHandlesFullInt64RangeWithoutIntermediateOverflow() throws {
        XCTAssertEqual(try Money.averagePerDay([Int64.max], activeDays: 1), Int64.max)
        XCTAssertEqual(try Money.averagePerDay([Int64.max - 1, 1], activeDays: 2), 4_611_686_018_427_387_904)
        let largestDivisor = Int64(Int.max)
        XCTAssertEqual(try Money.averagePerDay([largestDivisor], activeDays: Int.max), 1)
        XCTAssertEqual(try Money.averagePerDay([largestDivisor / 2], activeDays: Int.max), 0)
        XCTAssertEqual(try Money.averagePerDay([largestDivisor / 2 + 1], activeDays: Int.max), 1)
    }

    func testAverageRejectsNegativeAmountsAndInvalidDayCounts() {
        for (amounts, days): ([Int64], Int) in [
            ([-1], 1), ([100, -1], 2), ([Int64.min], 1),
            ([], -1), ([1], Int.min), ([1], 0), ([0], 0)
        ] {
            XCTAssertThrowsError(try Money.averagePerDay(amounts, activeDays: days)) {
                XCTAssertEqual($0 as? MoneyError, .invalidAmount)
            }
        }
    }

    func testAveragePropagatesAggregationOverflow() {
        // Even when the eventual average could fit, an overflowing total is rejected.
        XCTAssertThrowsError(try Money.averagePerDay([Int64.max, 1], activeDays: Int.max)) {
            XCTAssertEqual($0 as? MoneyError, .overflow)
        }
    }

    func testArabicAndPersianDigitsRoundTripExactly() throws {
        for identifier in ["ar_EG", "fa_IR"] {
            let locale = Locale(identifier: identifier)
            for amount: Int64 in [1, 101, 123_456, 100_000_001, Money.maximumAmountMinor] {
                let input = Money.inputText(amount, currencyCode: "EGP", locale: locale)
                XCTAssertEqual(try Money.parse(input, currencyCode: "EGP", locale: locale), amount, identifier)
            }
        }
        XCTAssertEqual(try Money.parse("١٬٢٣٤٫٥٦", currencyCode: "EGP", locale: Locale(identifier: "ar_EG")), 123_456)
        XCTAssertEqual(try Money.parse("۱٬۲۳۴٫۵۶", currencyCode: "EGP", locale: Locale(identifier: "fa_IR")), 123_456)
    }

    func testEditableAmountsRoundTripInEverySupportedLanguage() throws {
        for identifier in ["en_US", "ru_RU", "zh_CN", "hi_IN", "es_ES", "ar_EG",
                           "fr_FR", "bn_BD", "pt_BR", "pt_PT", "id_ID", "ur_PK"] {
            let locale = Locale(identifier: identifier)
            for value: Int64 in [1, 123_456, Money.maximumAmountMinor - 1] {
                for currency in ["USD", "JPY"] {
                    let input = Money.inputText(value, currencyCode: currency, locale: locale)
                    XCTAssertEqual(try Money.parse(input, currencyCode: currency, locale: locale), value, identifier)
                }
            }
        }
        XCTAssertEqual(try Money.parse("১২,৩৪,৫৬৭.৮৯", currencyCode: "USD",
                                       locale: Locale(identifier: "bn_BD")), 123_456_789)
    }

    func testUnicodeNumericSymbolsAreNotDecimalDigits() {
        for input in ["Ⅻ", "²", "½", "①", "1²", "1.½", "1️⃣"] {
            XCTAssertThrowsError(try Money.parse(input, currencyCode: "USD", locale: us), input)
        }
        let arabic = Locale(identifier: "ar_EG")
        for input in ["١٫٢٫٣", "١e٣", "١٫²", "١٬٢٣٫٤٥", "١٫٠٠١", "٠", "-١"] {
            XCTAssertThrowsError(try Money.parse(input, currencyCode: "EGP", locale: arabic), input)
        }
    }

    func testBalancesKeepCurrenciesSeparate() throws {
        let transactions = [
            WalletTransaction(amountMinor: 10_000, currencyCode: "USD", kind: .income),
            WalletTransaction(amountMinor: 2_000, currencyCode: "USD", kind: .expense),
            WalletTransaction(amountMinor: 30_000, currencyCode: "RUB", kind: .expense),
            WalletTransaction(amountMinor: 500, currencyCode: "JPY", kind: .income)
        ]
        XCTAssertEqual(try Money.totalsByCurrency(transactions), ["USD": 8_000, "RUB": -30_000, "JPY": 500])
        XCTAssertEqual(try Money.totalsByCurrency(transactions, kind: .expense), ["USD": 2_000, "RUB": 30_000])
        XCTAssertEqual(try Money.totalsByCurrency(transactions, kind: .income), ["USD": 10_000, "JPY": 500])
    }
}

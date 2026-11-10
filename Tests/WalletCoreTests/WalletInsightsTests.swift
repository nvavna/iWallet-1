import Foundation
import XCTest
@testable import WalletCore

final class WalletInsightsTests: XCTestCase {
    private var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.firstWeekday = 2
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12,
                      calendar: Calendar? = nil) -> Date {
        (calendar ?? utc).date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    private func entry(_ amount: Int64, _ day: Date, kind: TransactionKind = .expense,
                       currency: String = "USD", category: UUID? = nil, name: String? = nil) -> WalletInsights.Entry {
        .init(amountMinor: amount, currencyCode: currency, date: day, kind: kind,
              categoryID: category, categoryName: name)
    }

    func testMonthUsesCalendarToDateAndIsolatesCurrencies() throws {
        let snapshot = try WalletInsights.make(entries: [
            entry(100, date(2026, 11, 1, 0)),
            entry(200, date(2026, 11, 5, 23)), // The entire selected day is included.
            entry(400, date(2026, 11, 6, 0)),
            entry(800, date(2026, 10, 31, 23)),
            entry(900, date(2026, 11, 2), currency: "EUR"),
            entry(1_000, date(2026, 11, 3), kind: .income)
        ], currencyCode: "USD", period: .month, now: date(2026, 11, 5), calendar: utc)
        XCTAssertEqual(snapshot.interval?.start, date(2026, 11, 1, 0))
        XCTAssertEqual(snapshot.interval?.end, date(2026, 11, 6, 0))
        XCTAssertEqual(snapshot.incomeMinor, 1_000)
        XCTAssertEqual(snapshot.expenseMinor, 300)
        XCTAssertEqual(snapshot.netMinor, 700)
        XCTAssertEqual(snapshot.transactionCount, 3)
        XCTAssertEqual(snapshot.expenseActiveDays, 2)
        XCTAssertEqual(snapshot.expenseAverageMinor, 150)
        XCTAssertEqual(snapshot.buckets.count, 5)
    }

    func testComparisonUsesEqualElapsedDaysAndExcludesRemainingPriorMonth() throws {
        let snapshot = try WalletInsights.make(entries: [
            entry(150, date(2026, 11, 5)),
            entry(100, date(2026, 10, 5, 23)),
            entry(10_000, date(2026, 10, 6, 0))
        ], currencyCode: "USD", period: .month, now: date(2026, 11, 5), calendar: utc)
        let comparison = try XCTUnwrap(snapshot.expenseComparison)
        XCTAssertEqual(comparison.interval.start, date(2026, 10, 1, 0))
        XCTAssertEqual(comparison.interval.end, date(2026, 10, 6, 0))
        XCTAssertEqual(comparison.previousMinor, 100)
        XCTAssertEqual(comparison.changeMinor, 50)
        XCTAssertEqual(comparison.percentChange, Decimal(50))
    }

    func testPreviousShorterMonthIsClampedAtItsEnd() throws {
        let snapshot = try WalletInsights.make(entries: [
            entry(200, date(2025, 2, 28)), entry(100, date(2025, 3, 1))
        ], currencyCode: "USD", period: .month, now: date(2025, 3, 31), calendar: utc)
        XCTAssertEqual(snapshot.previousInterval?.start, date(2025, 2, 1, 0))
        XCTAssertEqual(snapshot.previousInterval?.end, date(2025, 3, 1, 0))
        XCTAssertEqual(snapshot.expenseComparison?.previousMinor, 200)
        XCTAssertEqual(snapshot.expenseComparison?.percentChange, Decimal(-50))
        XCTAssertEqual(snapshot.buckets.count, 31)
    }

    func testQuarterAndYearStartAtCalendarBoundaries() throws {
        let now = date(2026, 11, 5)
        let quarter = try WalletInsights.make(entries: [], currencyCode: "USD", period: .quarter, now: now, calendar: utc)
        XCTAssertEqual(quarter.interval?.start, date(2026, 10, 1, 0))
        XCTAssertEqual(quarter.interval?.end, date(2026, 11, 6, 0))
        XCTAssertEqual(quarter.previousInterval?.start, date(2026, 7, 1, 0))
        XCTAssertEqual(quarter.previousInterval?.end, date(2026, 8, 6, 0))
        XCTAssertLessThanOrEqual(quarter.buckets.count, 14)
        let year = try WalletInsights.make(entries: [], currencyCode: "USD", period: .year, now: now, calendar: utc)
        XCTAssertEqual(year.interval?.start, date(2026, 1, 1, 0))
        XCTAssertEqual(year.previousInterval?.start, date(2025, 1, 1, 0))
        XCTAssertEqual(year.previousInterval?.end, date(2025, 11, 6, 0))
        XCTAssertEqual(year.buckets.count, 11)
    }

    func testLeapYearComparisonUsesDayCountRatherThanMonthDay() throws {
        let snapshot = try WalletInsights.make(entries: [], currencyCode: "USD", period: .year,
                                               now: date(2025, 3, 1), calendar: utc)
        XCTAssertEqual(snapshot.interval?.end, date(2025, 3, 2, 0))
        XCTAssertEqual(snapshot.previousInterval?.end, date(2024, 3, 1, 0))
    }

    func testDSTBucketsAndActiveDaysFollowLocalCalendar() throws {
        var calendar = utc
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "America/New_York"))
        let snapshot = try WalletInsights.make(entries: [
            entry(100, date(2026, 3, 8, 1, calendar: calendar)),
            entry(200, date(2026, 3, 8, 23, calendar: calendar)),
            entry(300, date(2026, 3, 9, 0, calendar: calendar))
        ], currencyCode: "USD", period: .month,
           now: date(2026, 3, 9, calendar: calendar), calendar: calendar)
        XCTAssertEqual(snapshot.buckets.count, 9)
        XCTAssertEqual(snapshot.buckets[7].interval.duration, 23 * 60 * 60)
        XCTAssertEqual(snapshot.buckets[7].expenseMinor, 300)
        XCTAssertEqual(snapshot.expenseActiveDays, 2)
        XCTAssertEqual(snapshot.expenseAverageMinor, 300)
        XCTAssertEqual(snapshot.previousInterval?.end, date(2026, 2, 10, 0, calendar: calendar))
    }

    func testAllTimeIncludesRecordedFutureAndHasNoComparison() throws {
        let snapshot = try WalletInsights.make(entries: [
            entry(125, date(2023, 1, 15)), entry(275, date(2028, 5, 1))
        ], currencyCode: "USD", period: .allTime, now: date(2026, 11, 5), calendar: utc)
        XCTAssertEqual(snapshot.expenseMinor, 400)
        XCTAssertEqual(snapshot.transactionCount, 2)
        XCTAssertEqual(snapshot.interval?.start, date(2023, 1, 15, 0))
        XCTAssertEqual(snapshot.interval?.end, date(2028, 5, 2, 0))
        XCTAssertNil(snapshot.previousInterval)
        XCTAssertNil(snapshot.expenseComparison)
        XCTAssertLessThanOrEqual(snapshot.buckets.count, 24)
        XCTAssertEqual(try Money.sum(snapshot.buckets.map(\.expenseMinor)), 400)
    }

    func testAllTimeAcrossSupportedDateRangeHasBoundedContiguousBuckets() throws {
        let snapshot = try WalletInsights.make(entries: [
            entry(1, Date(timeIntervalSince1970: -62_135_596_800)),
            entry(2, Date(timeIntervalSince1970: 253_402_300_799))
        ], currencyCode: "USD", period: .allTime, now: date(2026, 11, 5), calendar: utc)
        XCTAssertLessThanOrEqual(snapshot.buckets.count, 24)
        XCTAssertEqual(snapshot.buckets.first?.interval.start, snapshot.interval?.start)
        XCTAssertEqual(snapshot.buckets.last?.interval.end, snapshot.interval?.end)
        for pair in zip(snapshot.buckets, snapshot.buckets.dropFirst()) {
            XCTAssertEqual(pair.0.interval.end, pair.1.interval.start)
        }
        XCTAssertEqual(try Money.sum(snapshot.buckets.map(\.expenseMinor)), 3)
    }

    func testEmptyAndSingleBucketDoNotInventTransactions() throws {
        let empty = try WalletInsights.make(entries: [], currencyCode: "USD", period: .allTime,
                                            now: date(2026, 11, 5), calendar: utc)
        XCTAssertNil(empty.interval)
        XCTAssertTrue(empty.buckets.isEmpty)
        XCTAssertTrue(empty.expenseDonutSegments.isEmpty)
        XCTAssertEqual(empty.expenseActiveDays, 0)
        XCTAssertEqual(empty.expenseAverageMinor, 0)
        let single = try WalletInsights.make(entries: [entry(123, date(2026, 11, 5))],
            currencyCode: "USD", period: .allTime, now: date(2026, 11, 5), calendar: utc)
        XCTAssertEqual(single.buckets.count, 1)
        XCTAssertEqual(single.expenseDonutSegments.count, 1)
        XCTAssertEqual(single.expenseDonutSegments.first?.id, .uncategorized)
        XCTAssertEqual(single.incomeMinor, 0)
    }

    func testCategoryIdentityAndTopFiveOtherConserveExactTotals() throws {
        let ids = (1...7).map { UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", $0))! }
        let entries = ids.enumerated().map { index, id in
            entry(Int64(100 - index), date(2026, 11, 5), category: id,
                  name: index == 0 ? "Other categories" : "Same name")
        } + [entry(1, date(2026, 11, 5))]
        let snapshot = try WalletInsights.make(entries: entries, currencyCode: "USD", period: .month,
                                               now: date(2026, 11, 5), calendar: utc)
        XCTAssertEqual(snapshot.expenseCategories.count, 8)
        XCTAssertEqual(snapshot.expenseDonutSegments.count, 6)
        XCTAssertEqual(snapshot.expenseDonutSegments.first?.id, .category(ids[0]))
        XCTAssertEqual(snapshot.expenseDonutSegments.last?.id, .other)
        XCTAssertEqual(snapshot.expenseDonutSegments.last?.amountMinor, 95 + 94 + 1)
        XCTAssertEqual(try Money.sum(snapshot.expenseDonutSegments.map(\.amountMinor)), snapshot.expenseMinor)
        XCTAssertEqual(try Money.sum(snapshot.expenseCategories.map(\.amountMinor)), snapshot.expenseMinor)
        XCTAssertEqual(try Money.sum(snapshot.buckets.map(\.expenseMinor)), snapshot.expenseMinor)
    }

    func testEqualCategoryTotalsHaveStableOrderIndependentOfInput() throws {
        let a = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let b = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        let entries = [entry(10, date(2026, 11, 5), category: b), entry(10, date(2026, 11, 5), category: a)]
        let first = try WalletInsights.make(entries: entries, currencyCode: "USD", period: .month,
                                            now: date(2026, 11, 5), calendar: utc)
        let second = try WalletInsights.make(entries: Array(entries.reversed()), currencyCode: "USD", period: .month,
                                             now: date(2026, 11, 5), calendar: utc)
        XCTAssertEqual(first.expenseCategories.map(\.id), [.category(a), .category(b)])
        XCTAssertEqual(first.expenseCategories.map(\.id), second.expenseCategories.map(\.id))
    }

    func testZeroPreviousPeriodDoesNotGenerateInfinitePercentage() throws {
        let snapshot = try WalletInsights.make(entries: [entry(100, date(2026, 11, 5))],
            currencyCode: "USD", period: .month, now: date(2026, 11, 5), calendar: utc)
        XCTAssertEqual(snapshot.expenseComparison?.previousMinor, 0)
        XCTAssertEqual(snapshot.expenseComparison?.changeMinor, 100)
        XCTAssertNil(snapshot.expenseComparison?.percentChange)
        let noCurrent = try WalletInsights.make(entries: [entry(100, date(2026, 10, 5))],
            currencyCode: "USD", period: .month, now: date(2026, 11, 5), calendar: utc)
        XCTAssertEqual(noCurrent.expenseComparison?.percentChange, Decimal(-100))
    }

    func testMoneyRemainsExactAcrossFullPositiveInt64Range() throws {
        let snapshot = try WalletInsights.make(entries: [
            entry(Int64.max, date(2026, 11, 5), kind: .income),
            entry(Int64.max - 1, date(2026, 11, 5))
        ], currencyCode: "USD", period: .month, now: date(2026, 11, 5), calendar: utc)
        XCTAssertEqual(snapshot.incomeMinor, Int64.max)
        XCTAssertEqual(snapshot.expenseMinor, Int64.max - 1)
        XCTAssertEqual(snapshot.netMinor, 1)
        XCTAssertEqual(snapshot.expenseAverageMinor, Int64.max - 1)
        XCTAssertEqual(snapshot.buckets.last?.incomeMinor, Int64.max)
    }

    func testOverflowFailsWholeSnapshotIncludingPreviousPeriod() {
        for dates in [[date(2026, 11, 1), date(2026, 11, 2)], [date(2026, 10, 1), date(2026, 10, 2)]] {
            let result = WalletInsights.result(entries: [entry(Int64.max, dates[0]), entry(1, dates[1])],
                currencyCode: "USD", period: .month, now: date(2026, 11, 5), calendar: utc)
            switch result {
            case .success: XCTFail("An overflowing sum must not become a partial chart")
            case .failure(let error): XCTAssertEqual(error as? MoneyError, .overflow)
            }
        }
    }

    func testRejectsInvalidSelectedAmountsDatesAndCurrency() {
        for amount: Int64 in [0, -1, Int64.min] {
            XCTAssertThrowsError(try WalletInsights.make(entries: [entry(amount, date(2026, 11, 5))],
                currencyCode: "USD", period: .month, now: date(2026, 11, 5), calendar: utc))
        }
        XCTAssertThrowsError(try WalletInsights.make(entries: [entry(1, Date(timeIntervalSince1970: .nan))],
            currencyCode: "USD", period: .month, now: date(2026, 11, 5), calendar: utc))
        XCTAssertThrowsError(try WalletInsights.make(entries: [], currencyCode: "XYZ", period: .month,
                                                      now: date(2026, 11, 5), calendar: utc))
    }

    @MainActor
    func testModelConvenienceCopiesValuesAndDoesNotRetainLiveCategory() async throws {
        let category = WalletCategory(name: "Original", icon: "cart", color: "colorGreen", kind: .expense)
        let transaction = WalletTransaction(amountMinor: 123, currencyCode: "USD", date: date(2026, 11, 5),
                                             kind: .expense, category: category)
        let copied = WalletInsights.Entry(transaction: transaction)
        category.name = "Edited"
        transaction.amountMinor = 999
        transaction.category = nil
        let snapshot = try WalletInsights.make(entries: [copied], currencyCode: "USD", period: .month,
                                               now: date(2026, 11, 5), calendar: utc)
        XCTAssertEqual(snapshot.expenseMinor, 123)
        XCTAssertEqual(snapshot.expenseCategories.first?.name, "Original")
        XCTAssertEqual(snapshot.expenseCategories.first?.id, .category(category.id))
    }
}

extension WalletInsightsTests {
    func testReportIncludesOnlyExpensesInSelectedCurrencyAndUsesHalfOpenBoundaries() throws {
        let previousStart = date(2024, 2, 26, 0)
        let start = date(2024, 2, 28, 0)
        let end = date(2024, 3, 1, 0)
        let report = try WalletInsights.spendingReport(entries: [
            entry(1, previousStart.addingTimeInterval(-0.001)), entry(2, previousStart),
            entry(4, start.addingTimeInterval(-0.001)), entry(8, start),
            entry(16, end.addingTimeInterval(-0.001)), entry(32, end),
            entry(64, previousStart, kind: .income), entry(128, start, kind: .income),
            entry(256, previousStart, currency: "EUR"), entry(512, start, currency: "EUR")
        ], currencyCode: "USD", start: date(2024, 2, 28, 23), end: date(2024, 2, 29, 1), calendar: utc)

        XCTAssertEqual(report.currencyCode, "USD")
        XCTAssertEqual(report.interval, DateInterval(start: start, end: end))
        XCTAssertEqual(report.previousInterval, DateInterval(start: previousStart, end: start))
        XCTAssertEqual(report.count, 2)
        XCTAssertEqual(report.totalMinor, 24)
        XCTAssertEqual(report.previousTotalMinor, 6)
        XCTAssertEqual(report.categories.map(\.id), [.uncategorized])
    }

    func testReportUsesCalendarDaysForBothChangesOfDST() throws {
        var calendar = utc
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "America/New_York"))
        for (month, day, hours) in [(3, 8, 23), (11, 1, 25)] {
            let dayStart = date(2026, month, day, 0, calendar: calendar)
            let nextDay = date(2026, month, day + 1, 0, calendar: calendar)
            let entries = [entry(1, dayStart), entry(2, nextDay.addingTimeInterval(-1)), entry(4, nextDay)]
            let report = try WalletInsights.spendingReport(entries: entries, currencyCode: "USD",
                start: date(2026, month, day, 23, calendar: calendar), end: dayStart, calendar: calendar)
            XCTAssertEqual(report.interval, DateInterval(start: dayStart, end: nextDay))
            XCTAssertEqual(report.interval.duration, Double(hours * 3_600))
            XCTAssertEqual(report.previousInterval.duration, 24 * 3_600)
            XCTAssertEqual(report.totalMinor, 3)

            let following = try WalletInsights.spendingReport(entries: entries, currencyCode: "USD",
                                                                start: nextDay, end: nextDay, calendar: calendar)
            XCTAssertEqual(following.previousInterval, report.interval)
            XCTAssertEqual(following.previousTotalMinor, 3)
            XCTAssertEqual(following.totalMinor, 4)
        }
    }

    func testReportHandlesDayWhoseMidnightWasSkipped() throws {
        var calendar = utc
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "America/Sao_Paulo"))
        let start = date(2018, 11, 4, calendar: calendar)
        let end = date(2018, 11, 5, calendar: calendar)
        let report = try WalletInsights.spendingReport(entries: [], currencyCode: "USD",
                                                        start: start, end: end, calendar: calendar)
        XCTAssertEqual(report.interval.start, date(2018, 11, 4, 1, calendar: calendar))
        XCTAssertEqual(report.interval.end, date(2018, 11, 6, 0, calendar: calendar))
        XCTAssertEqual(report.previousInterval.start, date(2018, 11, 2, 0, calendar: calendar))
        XCTAssertEqual(report.previousInterval.end, report.interval.start)
    }

    func testReportAcrossEntireSupportedDateRangeKeepsEqualPreviousPeriodInUTC() throws {
        let first = Date(timeIntervalSince1970: -62_135_596_800)
        let last = Date(timeIntervalSince1970: 253_402_300_799)
        let report = try WalletInsights.spendingReport(entries: [entry(3, first), entry(5, last)],
                                                        currencyCode: "USD", start: first, end: last, calendar: utc)
        XCTAssertEqual(report.interval.start, first)
        XCTAssertEqual(report.interval.end, last.addingTimeInterval(1))
        XCTAssertEqual(report.interval.duration, report.previousInterval.duration)
        XCTAssertEqual(report.previousInterval.end, first)
        XCTAssertEqual(report.totalMinor, 8)
        XCTAssertEqual(report.previousTotalMinor, 0)
    }

    func testReportPreservesCategoryIdentityAndPreviousOnlyRows() throws {
        let a = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let b = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        let c = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!
        let day = date(2026, 1, 1), priorDay = date(2025, 12, 31)
        let entries = [entry(12, day, category: b, name: "Same"), entry(7, day, category: a, name: "Same"),
                       entry(5, day, category: a, name: "Same"), entry(4, day),
                       entry(6, priorDay, category: a, name: "Old name"),
                       entry(99, priorDay, category: c, name: "Prior only"), entry(1, priorDay)]
        for input in [entries, Array(entries.reversed())] {
            let report = try WalletInsights.spendingReport(entries: input, currencyCode: "USD",
                                                            start: day, end: day, calendar: utc)
            XCTAssertEqual(report.categories.map(\.id), [.category(a), .category(b), .uncategorized, .category(c)])
            XCTAssertEqual(report.categories.map(\.name), ["Same", "Same",
                NSLocalizedString("Uncategorized", comment: "Category"), "Prior only"])
            XCTAssertEqual(report.categories.map(\.currentMinor), [12, 12, 4, 0])
            XCTAssertEqual(report.categories.map(\.previousMinor), [6, 0, 1, 99])
            XCTAssertEqual(report.count, 4)
            XCTAssertEqual(report.totalMinor, 28)
            XCTAssertEqual(report.previousTotalMinor, 106)
        }
    }

    func testReportKeepsEmptyAndPreviousOnlyPeriodsAndFullInt64Precision() throws {
        let day = date(2026, 1, 1), priorDay = date(2025, 12, 31)
        for (entries, current, previous, count) in [
            ([WalletInsights.Entry](), 0 as Int64, 0 as Int64, 0),
            ([entry(1, priorDay)], 0, 1, 0),
            ([entry(Int64.max, day)], Int64.max, 0, 1),
            ([entry(Int64.max - 1, day), entry(1, day), entry(Int64.max - 1, priorDay)], Int64.max, Int64.max - 1, 2)
        ] {
            let report = try WalletInsights.spendingReport(entries: entries, currencyCode: "USD",
                                                            start: day, end: day, calendar: utc)
            XCTAssertEqual(report.totalMinor, current)
            XCTAssertEqual(report.previousTotalMinor, previous)
            XCTAssertEqual(report.count, count)
            XCTAssertEqual(report.categories.count, entries.isEmpty ? 0 : 1)
            XCTAssertEqual(try Money.sum(report.categories.map(\.currentMinor)), current)
            XCTAssertEqual(try Money.sum(report.categories.map(\.previousMinor)), previous)
        }
    }

    func testReportRejectsOverflowInEitherPeriodWithinAndAcrossCategories() {
        let day = date(2026, 1, 1), priorDay = date(2025, 12, 31)
        for entryDate in [day, priorDay] {
            for category in [nil, UUID()] {
                let entries = [entry(Int64.max, entryDate), entry(1, entryDate, category: category)]
                XCTAssertThrowsError(try WalletInsights.spendingReport(entries: entries, currencyCode: "USD",
                                                                       start: day, end: day, calendar: utc)) {
                    XCTAssertEqual($0 as? MoneyError, .overflow)
                }
            }
        }
    }

    func testReportRejectsInvalidDatesCurrencyAndAmounts() {
        let day = date(2026, 1, 1)
        let invalid = Date(timeIntervalSince1970: .nan)
        for (start, end) in [(day, date(2025, 12, 31)), (invalid, day), (day, invalid)] {
            XCTAssertThrowsError(try WalletInsights.spendingReport(entries: [], currencyCode: "USD",
                                                                    start: start, end: end, calendar: utc)) {
                XCTAssertEqual($0 as? WalletStoreError, .invalidDate)
            }
        }
        XCTAssertThrowsError(try WalletInsights.spendingReport(entries: [], currencyCode: "XYZ",
                                                               start: day, end: day, calendar: utc)) {
            XCTAssertEqual($0 as? MoneyError, .unsupportedCurrency)
        }
        XCTAssertThrowsError(try WalletInsights.spendingReport(entries: [entry(0, day)], currencyCode: "USD",
                                                               start: day, end: day, calendar: utc)) {
            XCTAssertEqual($0 as? MoneyError, .nonPositiveAmount)
        }
    }
}

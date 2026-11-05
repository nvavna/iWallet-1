import SwiftUI
import Charts

struct WalletTimelineCard: View {
    let snapshot: WalletInsights.Snapshot
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var selectedBucketKey: String?

    private var rows: [TimelineRow] {
        snapshot.buckets.enumerated().map { TimelineRow(key: String($0.offset), bucket: $0.element) }
    }
    private var incomeName: String { TransactionKind.income.localizedName }
    private var expenseName: String { TransactionKind.expense.localizedName }
    private var selectedRow: TimelineRow? { rows.first { $0.key == selectedBucketKey } }
    private var axisKeys: [String] {
        let step = max(1, (rows.count + 4) / 5)
        return rows.enumerated().filter { $0.offset % step == 0 }.map { $0.element.key }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Income and expenses").font(.headline)
            if let interval = snapshot.interval {
                Text(AnalyticsText.interval(interval, calendar: snapshot.calendar, locale: locale))
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            if snapshot.transactionCount == 0 {
                Text("No transactions in this period").foregroundStyle(.secondary)
            } else {
                if dynamicTypeSize.isAccessibilitySize {
                    accessibleTimeline
                } else {
                    timeline
                    if let selectedRow { values(for: selectedRow.bucket) }
                }
                DisclosureGroup("Values") {
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(rows) { row in values(for: row.bucket) }
                    }.padding(.top, 8)
                }
            }
            if snapshot.transactionCount > 0 || (snapshot.incomeComparison?.previousMinor ?? 0) > 0 ||
                (snapshot.expenseComparison?.previousMinor ?? 0) > 0 {
                comparisons
            }
        }
        .walletSurface()
        .accessibilityIdentifier("timelineChartCard")
        .onChange(of: snapshot.interval) { _, _ in selectedBucketKey = nil }
        .onChange(of: snapshot.currencyCode) { _, _ in selectedBucketKey = nil }
    }

    // At accessibility sizes, a fixed-width chart cannot fit readable axes.
    // Keep every interval available through a native picker and exact text;
    // the full value disclosure below remains available in both layouts.
    private var accessibleTimeline: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let row = selectedRow ?? rows.last {
                Menu {
                    Picker("Period", selection: Binding(
                        get: { selectedBucketKey ?? row.key },
                        set: { selectedBucketKey = $0 }
                    )) {
                        ForEach(rows) { item in
                            Text(AnalyticsText.interval(item.bucket.interval, calendar: snapshot.calendar, locale: locale))
                                .tag(item.key)
                        }
                    }
                } label: {
                    WalletFormMenuLabel("Period", value: AnalyticsText.interval(row.bucket.interval,
                        calendar: snapshot.calendar, locale: locale))
                }
                .accessibilityIdentifier("analyticsInterval")
                Text("\(incomeName): \(money(row.bucket.incomeMinor))")
                    .font(.body).monospacedDigit()
                Text("\(expenseName): \(money(row.bucket.expenseMinor))")
                    .font(.body).monospacedDigit()
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var timeline: some View {
        Chart {
            ForEach(rows) { row in
                BarMark(x: .value("Period", row.key),
                        y: .value(snapshot.currencyCode, plotAmount(row.bucket.incomeMinor)))
                    .foregroundStyle(by: .value("Type", incomeName))
                    .position(by: .value("Type", incomeName))
                    .accessibilityLabel(Text("\(AnalyticsText.interval(row.bucket.interval, calendar: snapshot.calendar, locale: locale)), \(incomeName)"))
                    .accessibilityValue(Text(money(row.bucket.incomeMinor)))
                BarMark(x: .value("Period", row.key),
                        y: .value(snapshot.currencyCode, plotAmount(row.bucket.expenseMinor)))
                    .foregroundStyle(by: .value("Type", expenseName))
                    .position(by: .value("Type", expenseName))
                    .accessibilityLabel(Text("\(AnalyticsText.interval(row.bucket.interval, calendar: snapshot.calendar, locale: locale)), \(expenseName)"))
                    .accessibilityValue(Text(money(row.bucket.expenseMinor)))
            }
            if let selectedRow {
                RuleMark(x: .value("Period", selectedRow.key))
                    .foregroundStyle(.secondary.opacity(0.35))
                    .accessibilityHidden(true)
            }
        }
        .chartXScale(domain: rows.map(\.key))
        .chartForegroundStyleScale(domain: [incomeName, expenseName],
                                   range: [WalletTheme.categoryColor("colorGreen"), WalletTheme.categoryColor("colorBlue")])
        .chartLegend(position: .bottom, alignment: .leading)
        .chartXSelection(value: $selectedBucketKey)
        .chartXAxis {
            AxisMarks(values: axisKeys) { value in
                AxisValueLabel {
                    if let key = value.as(String.self), let row = rows.first(where: { $0.key == key }) {
                        Text(AnalyticsText.axisDate(row.bucket.interval.start, period: snapshot.period,
                                                   calendar: snapshot.calendar, locale: locale))
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let amount = value.as(Double.self) {
                        Text(amount, format: .number.notation(.compactName))
                    }
                }
            }
        }
        .chartYAxisLabel(snapshot.currencyCode, position: .topLeading)
        .frame(height: 220)
        .accessibilityLabel(Text("Income and expenses"))
    }

    private var comparisons: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let interval = snapshot.previousInterval {
                Text("Compared with previous period").font(.subheadline.weight(.medium))
                Text(AnalyticsText.interval(interval, calendar: snapshot.calendar, locale: locale))
                    .font(.caption).foregroundStyle(.secondary)
                ForEach(TransactionKind.allCases) { kind in
                    if let comparison = snapshot.comparison(for: kind) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(kind.localizedName).font(.subheadline)
                            if let percentage = comparison.percentChange {
                                Text("\(AnalyticsText.percentage(percentage, locale: locale)) · \(money(comparison.changeMinor))")
                                    .font(.subheadline.weight(.medium)).monospacedDigit()
                            } else {
                                Text("No amount in previous period").font(.subheadline).foregroundStyle(.secondary)
                            }
                        }.accessibilityElement(children: .combine)
                    }
                }
            }
        }
    }

    private func values(for bucket: WalletInsights.Bucket) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(AnalyticsText.interval(bucket.interval, calendar: snapshot.calendar, locale: locale))
                .font(.subheadline.weight(.medium))
            Text("\(incomeName): \(money(bucket.incomeMinor))")
                .font(.subheadline).monospacedDigit()
            Text("\(expenseName): \(money(bucket.expenseMinor))")
                .font(.subheadline).monospacedDigit()
        }.accessibilityElement(children: .combine)
    }

    private func plotAmount(_ minor: Int64) -> Double {
        Double(minor) / (WalletCurrency(rawValue: snapshot.currencyCode)?.fractionDigits == 0 ? 1 : 100)
    }

    private func money(_ minor: Int64) -> String {
        Money.format(minor, currencyCode: snapshot.currencyCode, locale: locale)
    }

    private struct TimelineRow: Identifiable {
        var id: String { key }
        let key: String
        let bucket: WalletInsights.Bucket
    }
}

struct WalletCategoryChartCard: View {
    let snapshot: WalletInsights.Snapshot
    let kind: TransactionKind
    @Environment(\.locale) private var locale
    @State private var selectedAngle: Double?

    private var segments: [WalletInsights.CategoryTotal] { snapshot.donutSegments(for: kind) }
    private var selectedSegment: WalletInsights.CategoryTotal? {
        guard let selectedAngle, selectedAngle.isFinite else { return nil }
        var lower: Double = 0
        for segment in segments {
            let upper = lower + Double(segment.amountMinor)
            if selectedAngle >= lower && selectedAngle < upper { return segment }
            lower = upper
        }
        return nil
    }
    private var displayedSegment: WalletInsights.CategoryTotal? { selectedSegment ?? segments.first }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(chartTitle).font(.headline)
            if segments.isEmpty {
                Text("No transactions in this period").foregroundStyle(.secondary)
            } else {
                Chart(segments) { segment in
                    SectorMark(angle: .value("Amount", Double(segment.amountMinor)),
                               innerRadius: .ratio(0.64), angularInset: segments.count > 1 ? 1.5 : 0)
                        .foregroundStyle(WalletTheme.categoryColor(segment.color))
                        .opacity(selectedSegment == nil || selectedSegment?.id == segment.id ? 1 : 0.4)
                        .accessibilityLabel(Text(segment.name))
                        .accessibilityValue(Text(money(segment.amountMinor)))
                }
                .chartAngleSelection(value: $selectedAngle)
                .frame(height: 210)
                .accessibilityLabel(Text(chartTitle))
                if let segment = displayedSegment {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(selectedSegment == nil
                             ? NSLocalizedString("Largest category", comment: "Chart summary")
                             : NSLocalizedString("Selected category", comment: "Chart selection"))
                            .font(.caption).foregroundStyle(.secondary)
                        Text(segment.name).font(.subheadline.weight(.medium))
                        Text(money(segment.amountMinor)).font(.headline).monospacedDigit()
                    }.accessibilityElement(children: .combine)
                }
                DisclosureGroup("Values") {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(segments) { segment in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(segment.name).font(.subheadline)
                                Text(money(segment.amountMinor)).font(.subheadline.weight(.medium)).monospacedDigit()
                            }.accessibilityElement(children: .combine)
                        }
                    }.padding(.top, 8)
                }
            }
        }
        .walletSurface()
        .accessibilityIdentifier("categoryChartCard")
        .onChange(of: kind) { _, _ in selectedAngle = nil }
        .onChange(of: snapshot.interval) { _, _ in selectedAngle = nil }
        .onChange(of: snapshot.currencyCode) { _, _ in selectedAngle = nil }
    }

    private func money(_ minor: Int64) -> String {
        Money.format(minor, currencyCode: snapshot.currencyCode, locale: locale)
    }

    private var chartTitle: String {
        kind == .expense
            ? NSLocalizedString("Expenses by category", comment: "Chart title")
            : NSLocalizedString("Income by category", comment: "Chart title")
    }
}

private enum AnalyticsText {
    static func interval(_ interval: DateInterval, calendar: Calendar, locale: Locale) -> String {
        let formatter = DateIntervalFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = locale
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        // The storage boundary is exclusive; the visible last day belongs to this interval.
        return formatter.string(from: interval.start, to: interval.end.addingTimeInterval(-1))
    }

    static func axisDate(_ date: Date, period: WalletInsights.Period, calendar: Calendar, locale: Locale) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate(period == .year ? "MMM" : period == .allTime ? "MMMy" : "dMMM")
        return formatter.string(from: date)
    }

    static func percentage(_ percentage: Decimal, locale: Locale) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 1
        if percentage > 0 { formatter.positivePrefix = "+" }
        return formatter.string(from: NSDecimalNumber(decimal: percentage / 100)) ?? "—"
    }
}

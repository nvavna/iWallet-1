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
        let maximum = snapshot.period == .allTime || snapshot.period == .quarter ? 3 : 4
        let step = max(1, (rows.count + maximum - 1) / maximum)
        return rows.enumerated().filter { $0.offset % step == 0 }.map { $0.element.key }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Income and expenses").font(.headline).accessibilityAddTraits(.isHeader)
                if let interval = snapshot.interval {
                    Text(AnalyticsText.interval(interval, calendar: snapshot.calendar, locale: locale))
                        .font(.caption).foregroundStyle(WalletTheme.secondaryInk)
                }
            }
            if snapshot.transactionCount == 0 {
                Text("No transactions in this period")
                    .font(.subheadline).foregroundStyle(WalletTheme.secondaryInk)
            } else {
                if dynamicTypeSize.isAccessibilitySize {
                    accessibleTimeline
                } else {
                    timeline
                    if let selectedRow { values(for: selectedRow.bucket) }
                }
                Divider()
                DisclosureGroup {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(rows) { row in values(for: row.bucket) }
                    }
                } label: {
                    Text("Values").font(.subheadline.weight(.medium)).frame(minHeight: 44)
                }
            }
            if let previous = snapshot.previousInterval,
               snapshot.transactionCount > 0 || (snapshot.incomeComparison?.previousMinor ?? 0) > 0 ||
                (snapshot.expenseComparison?.previousMinor ?? 0) > 0 {
                Divider()
                DisclosureGroup {
                    comparisons(in: previous)
                } label: {
                    Text("Compared with previous period")
                        .font(.subheadline.weight(.medium)).frame(minHeight: 44)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .walletSurface()
        .accessibilityIdentifier("timelineChartCard")
        .onChange(of: snapshot.period) { _, _ in selectedBucketKey = nil }
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
        let ticks = Set(axisKeys)
        return Chart {
            ForEach(rows) { row in
                BarMark(x: .value("Period", row.key),
                        y: .value(snapshot.currencyCode, plotAmount(row.bucket.incomeMinor)))
                    .cornerRadius(2)
                    .foregroundStyle(by: .value("Type", incomeName))
                    .position(by: .value("Type", incomeName))
                    .accessibilityLabel(Text("\(AnalyticsText.interval(row.bucket.interval, calendar: snapshot.calendar, locale: locale)), \(incomeName)"))
                    .accessibilityValue(Text(money(row.bucket.incomeMinor)))
                BarMark(x: .value("Period", row.key),
                        y: .value(snapshot.currencyCode, plotAmount(row.bucket.expenseMinor)))
                    .cornerRadius(2)
                    .foregroundStyle(by: .value("Type", expenseName))
                    .position(by: .value("Type", expenseName))
                    .accessibilityLabel(Text("\(AnalyticsText.interval(row.bucket.interval, calendar: snapshot.calendar, locale: locale)), \(expenseName)"))
                    .accessibilityValue(Text(money(row.bucket.expenseMinor)))
            }
            if let selectedRow {
                RuleMark(x: .value("Period", selectedRow.key))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    .foregroundStyle(WalletTheme.secondaryInk)
                    .accessibilityHidden(true)
            }
        }
        .chartXScale(domain: rows.map(\.key))
        .chartForegroundStyleScale(domain: [incomeName, expenseName],
                                   range: [WalletTheme.income, WalletTheme.expense])
        .chartLegend(position: .bottom, alignment: .leading)
        .chartXSelection(value: $selectedBucketKey)
        .chartXAxis {
            AxisMarks { value in
                if let key = value.as(String.self), ticks.contains(key),
                   let row = rows.first(where: { $0.key == key }) {
                    AxisValueLabel {
                        Text(AnalyticsText.axisDate(row.bucket.interval.start, period: snapshot.period,
                                                   calendar: snapshot.calendar, locale: locale))
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.8, dash: [3, 4]))
                    .foregroundStyle(WalletTheme.hairline)
                AxisValueLabel {
                    if let amount = value.as(Double.self) {
                        Text(amount, format: .number.notation(.compactName))
                    }
                }
            }
        }
        .chartYAxisLabel(snapshot.currencyCode, position: .topLeading)
        .frame(height: 160)
        .accessibilityLabel(Text("Income and expenses"))
    }

    private func comparisons(in interval: DateInterval) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(AnalyticsText.interval(interval, calendar: snapshot.calendar, locale: locale))
                .font(.caption).foregroundStyle(WalletTheme.secondaryInk)
            ForEach(TransactionKind.allCases) { kind in
                if let comparison = snapshot.comparison(for: kind) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(kind.localizedName).font(.subheadline.weight(.semibold))
                        if let percentage = comparison.percentChange {
                            Text("\(AnalyticsText.percentage(percentage, locale: locale)) · \(money(comparison.changeMinor))")
                                .font(.subheadline).monospacedDigit()
                        } else {
                            Text("No amount in previous period").font(.subheadline).foregroundStyle(WalletTheme.secondaryInk)
                        }
                    }.accessibilityElement(children: .combine)
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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
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
        VStack(alignment: .leading, spacing: 12) {
            Text(chartTitle).font(.headline).accessibilityAddTraits(.isHeader)
            if let segment = displayedSegment {
                let layout = dynamicTypeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
                    : AnyLayout(HStackLayout(alignment: .center, spacing: 18))
                layout {
                    donut(highlighting: segment)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(selectedSegment == nil
                             ? NSLocalizedString("Largest category", comment: "Chart summary")
                             : NSLocalizedString("Selected category", comment: "Chart selection"))
                            .font(.caption).foregroundStyle(WalletTheme.secondaryInk)
                        Text(segment.name).font(.subheadline.weight(.semibold))
                        Text(money(segment.amountMinor))
                            .font(.title3.weight(.semibold)).monospacedDigit()
                        if dynamicTypeSize.isAccessibilitySize {
                            Text(share(of: segment))
                                .font(.subheadline.weight(.medium)).monospacedDigit()
                                .foregroundStyle(WalletTheme.secondaryInk)
                        }
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityElement(children: .combine)
                }
                Divider()
                DisclosureGroup {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(segments) { segment in
                            let layout = dynamicTypeSize.isAccessibilitySize
                                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 3))
                                : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 8))
                            layout {
                                Label {
                                    Text(segment.name).font(.subheadline)
                                } icon: {
                                    Image(systemName: WalletTheme.categorySymbol(segment.icon))
                                        .foregroundStyle(WalletTheme.categoryColor(segment.color))
                                }
                                if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 0) }
                                Text(money(segment.amountMinor))
                                    .font(.subheadline.weight(.semibold)).monospacedDigit()
                            }
                            .accessibilityElement(children: .combine)
                        }
                    }
                } label: {
                    Text("Values").font(.subheadline.weight(.medium)).frame(minHeight: 44)
                }
            } else {
                Text("No transactions in this period")
                    .font(.subheadline).foregroundStyle(WalletTheme.secondaryInk)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .walletSurface()
        .accessibilityIdentifier("categoryChartCard")
        // A saved angle refers to a range of amounts. Editing a transaction can
        // move a different category under that angle without changing the period.
        .onChange(of: segments.map(\.id)) { _, _ in selectedAngle = nil }
        .onChange(of: segments.map(\.amountMinor)) { _, _ in selectedAngle = nil }
        .onChange(of: kind) { _, _ in selectedAngle = nil }
        .onChange(of: snapshot.interval) { _, _ in selectedAngle = nil }
        .onChange(of: snapshot.currencyCode) { _, _ in selectedAngle = nil }
    }

    private func donut(highlighting highlighted: WalletInsights.CategoryTotal) -> some View {
        Chart(segments) { segment in
            SectorMark(angle: .value("Amount", Double(segment.amountMinor)),
                       innerRadius: .ratio(0.72), angularInset: segments.count > 1 ? 1.2 : 0)
                .foregroundStyle(WalletTheme.categoryColor(segment.color))
                .opacity(selectedSegment == nil || selectedSegment?.id == segment.id ? 1 : 0.35)
                .accessibilityLabel(Text(segment.name))
                .accessibilityValue(Text("\(money(segment.amountMinor)), \(share(of: segment))"))
        }
        .chartAngleSelection(value: $selectedAngle)
        .frame(width: 112, height: 112)
        .overlay {
            if !dynamicTypeSize.isAccessibilitySize {
                Text(share(of: highlighted))
                    .font(.subheadline.weight(.semibold)).monospacedDigit()
                    .lineLimit(1).minimumScaleFactor(0.8)
                    .frame(width: 72)
                    .accessibilityHidden(true).allowsHitTesting(false)
            }
        }
        .accessibilityLabel(Text(chartTitle))
    }

    private func share(of segment: WalletInsights.CategoryTotal) -> String {
        let total = kind == .expense ? snapshot.expenseMinor : snapshot.incomeMinor
        let fraction = Decimal(segment.amountMinor) / Decimal(total)
        let style = Decimal.FormatStyle.Percent(locale: locale).precision(.fractionLength(0...1))
        // Tiny, nonzero categories can coexist with a dominant category. Keep
        // the one-decimal legend from falsely showing zero or the entire total.
        let step = Decimal(1) / 1_000
        if fraction < step { return "<" + step.formatted(style) }
        if fraction < 1, fraction > 1 - step { return ">" + (1 - step).formatted(style) }
        return fraction.formatted(style)
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
        let template: String
        switch period {
        case .month: template = "d" // The exact month and year are in the card header.
        case .quarter: template = "dMMM"
        case .year: template = "MMM"
        case .allTime: template = "MMMy"
        }
        formatter.setLocalizedDateFormatFromTemplate(template)
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

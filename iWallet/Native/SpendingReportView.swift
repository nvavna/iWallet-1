import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct SpendingReportView: View {
    private let currencyCode: String
    private let isSample: Bool

    @Environment(\.calendar) private var calendar
    @Environment(\.timeZone) private var timeZone
    @Environment(\.locale) private var locale

    init(currencyCode: String) {
        self.currencyCode = currencyCode
        isSample = false
    }

    /// The sample never creates a live query or reads the wallet.
    init(sampleCurrencyCode: String) {
        currencyCode = sampleCurrencyCode
        isSample = true
    }

    var body: some View {
        let localCalendar = {
            var result = calendar
            result.timeZone = timeZone
            return result
        }()
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if isSample {
                    Label("This report uses example expenses.", systemImage: "doc.text.magnifyingglass")
                        .font(.subheadline)
                        .foregroundStyle(WalletTheme.secondaryInk)
                        .accessibilityIdentifier("sampleReportNotice")
                    switch Result(catching: { try sampleReport(calendar: localCalendar) }) {
                    case .success(let report):
                        ReportSummary(report: report, calendar: localCalendar)
                    case .failure(let error):
                        ReportFailure(error: error)
                    }
                } else {
                    LiveSpendingReport(currencyCode: currencyCode, calendar: localCalendar)
                }
            }
            .frame(maxWidth: 680, alignment: .leading)
            .padding()
            .frame(maxWidth: .infinity)
        }
        .background(WalletTheme.background)
        .foregroundStyle(WalletTheme.ink)
        .tint(WalletTheme.accent)
        .navigationTitle(isSample ? Text("Sample report") : Text("Spending report"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func sampleReport(calendar: Calendar) throws -> WalletInsights.SpendingReport {
        // Fixed local civil dates keep the example separate from the user's actual reporting period.
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = calendar.timeZone
        func date(_ day: Int) throws -> Date {
            guard let date = gregorian.date(from: DateComponents(year: 2026, month: 3, day: day, hour: 12)) else {
                throw WalletStoreError.invalidDate
            }
            return date
        }
        guard let currency = WalletCurrency(rawValue: currencyCode) else { throw MoneyError.unsupportedCurrency }
        let unit: Int64 = currency.fractionDigits == 0 ? 1 : 100
        let groceries = UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1))
        let transport = UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2))
        func expense(_ amount: Int64, _ day: Int, category: UUID, name: String) throws -> WalletInsights.Entry {
            try WalletInsights.Entry(amountMinor: amount * unit, currencyCode: currencyCode, date: date(day),
                                     kind: .expense, categoryID: category, categoryName: name)
        }
        let food = String(localized: "Groceries", locale: locale)
        let travel = String(localized: "Transport", locale: locale)
        let entries = try [
            expense(72, 3, category: groceries, name: food), expense(28, 6, category: transport, name: travel),
            expense(45, 8, category: groceries, name: food), expense(36, 10, category: groceries, name: food),
            expense(18, 12, category: transport, name: travel)
        ]
        return try WalletInsights.spendingReport(entries: entries, currencyCode: currencyCode,
                                                 start: date(8), end: date(14), calendar: calendar)
    }
}

private struct LiveSpendingReport: View {
    let currencyCode: String
    let calendar: Calendar
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var start: Date
    @State private var end: Date

    init(currencyCode: String, calendar: Calendar) {
        self.currencyCode = currencyCode
        self.calendar = calendar
        let today = calendar.startOfDay(for: .now)
        _start = State(initialValue: calendar.dateInterval(of: .month, for: today)?.start ?? today)
        _end = State(initialValue: today)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            dateRow("Start date", id: "reportStartDate", selection: Binding(get: { start }, set: { newDate in
                start = calendar.startOfDay(for: newDate)
                end = max(start, end)
            }))
            Divider()
            dateRow("End date", id: "reportEndDate", selection: Binding(get: { end }, set: { newDate in
                end = calendar.startOfDay(for: newDate)
                start = min(start, end)
            }))
        }
        .walletSurface()

        switch Result(catching: { try WalletInsights.spendingReportIntervals(start: start, end: end, calendar: calendar) }) {
        case .success(let intervals):
            ReportTransactions(currencyCode: currencyCode, calendar: calendar, start: start, end: end,
                               lowerBound: intervals.previous.start, upperBound: intervals.selected.end)
        case .failure(let error):
            ReportFailure(error: error)
        }
    }

    private func dateRow(_ title: LocalizedStringKey, id: String, selection: Binding<Date>) -> some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
            : AnyLayout(HStackLayout(spacing: 8))
        return layout {
            Text(title).frame(maxWidth: .infinity, alignment: .leading).accessibilityHidden(true)
            DatePicker(title, selection: selection, displayedComponents: .date)
                .labelsHidden()
                .accessibilityLabel(title)
                .accessibilityIdentifier(id)
        }
        .frame(minHeight: 44)
    }
}

private struct ReportTransactions: View {
    let currencyCode: String
    let calendar: Calendar
    let start: Date
    let end: Date
    @Query private var transactions: [WalletTransaction]
    @Environment(\.locale) private var locale
    @State private var document: ReportPDFDocument?
    @State private var filename = ""
    @State private var exporting = false
    @State private var errorMessage: String?

    init(currencyCode: String, calendar: Calendar, start: Date, end: Date, lowerBound: Date, upperBound: Date) {
        self.currencyCode = currencyCode
        self.calendar = calendar
        self.start = start
        self.end = end
        let kind = TransactionKind.expense.rawValue
        _transactions = Query(filter: #Predicate<WalletTransaction> {
            $0.currencyCode == currencyCode && $0.kindRaw == kind && $0.date >= lowerBound && $0.date < upperBound
        })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            switch result {
            case .success(let report):
                ReportSummary(report: report, calendar: calendar)
                Button {
                    export(report)
                } label: {
                    Label("Save PDF", systemImage: "square.and.arrow.up")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .tint(WalletTheme.forest)
                .foregroundStyle(.white)
                .accessibilityIdentifier("exportSpendingReportPDF")
            case .failure(let error):
                ReportFailure(error: error)
            }
        }
        .fileExporter(isPresented: $exporting, document: document, contentType: .pdf,
                      defaultFilename: filename) { response in
            document = nil
            if case .failure(let error) = response, (error as? CocoaError)?.code != .userCancelled {
                errorMessage = error.localizedDescription
            }
        }
        .alert("Unable to complete the operation", isPresented: Binding(get: { errorMessage != nil }, set: {
            if !$0 { errorMessage = nil }
        })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var result: Result<WalletInsights.SpendingReport, Error> {
        Result {
            let entries = transactions.map { WalletInsights.Entry(transaction: $0) }
            if let error = _transactions.fetchError { throw error }
            return try WalletInsights.spendingReport(entries: entries, currencyCode: currencyCode,
                                                     start: start, end: end, calendar: calendar)
        }
    }

    private func export(_ report: WalletInsights.SpendingReport) {
        do {
            let data = try SpendingReportPDF.data(for: report, calendar: calendar, locale: locale)
            let style = Date.ISO8601FormatStyle(timeZone: calendar.timeZone).year().month().day()
            let from = report.interval.start.formatted(style)
            let through = report.interval.end.addingTimeInterval(-1).formatted(style)
            filename = "iWallet-\(report.currencyCode)-\(from)-\(through)"
            document = ReportPDFDocument(data: data)
            exporting = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct ReportSummary: View {
    let report: WalletInsights.SpendingReport
    let calendar: Calendar
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Selected period").font(.headline)
            Text(range(report.interval)).font(.subheadline)
            Text(money(report.totalMinor))
                .font(.largeTitle.weight(.semibold)).monospacedDigit()
                .accessibilityLabel(Text("Selected period") + Text(verbatim: ", ") + Text(money(report.totalMinor)))
                .accessibilityIdentifier("reportSelectedTotal")
            Divider().overlay(.white.opacity(0.5))
            LabeledContent("Transactions", value: report.count.formatted(.number.locale(locale)))
            LabeledContent("Currency", value: report.currencyCode)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .foregroundStyle(.white)
        .background(WalletTheme.forest, in: .rect(cornerRadius: 20))
        .accessibilityElement(children: .contain)

        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Previous period").font(.headline)
                Text(range(report.previousInterval)).font(.subheadline).foregroundStyle(WalletTheme.secondaryInk)
                Text(money(report.previousTotalMinor)).font(.title2.weight(.semibold)).monospacedDigit()
                    .accessibilityLabel(Text("Previous period") + Text(verbatim: ", ") + Text(money(report.previousTotalMinor)))
                    .accessibilityIdentifier("reportPreviousTotal")
            }
            Divider()
            let delta = report.totalMinor - report.previousTotalMinor
            metric("Change in spending", amount: (delta > 0 ? "+" : "") + money(delta))
                .accessibilityIdentifier("reportChange")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .walletSurface()

        LazyVStack(alignment: .leading, spacing: 14) {
            Text("Expenses by category").font(.title3.weight(.semibold))
                .accessibilityAddTraits(.isHeader)
            if report.categories.isEmpty {
                Text("No expenses in either period.")
                    .foregroundStyle(WalletTheme.secondaryInk)
            } else {
                if report.count == 0 {
                    Text("No expenses for this period").foregroundStyle(WalletTheme.secondaryInk)
                }
                ForEach(report.categories) { category in
                    Divider()
                    VStack(alignment: .leading, spacing: 5) {
                        Text(category.name).font(.headline)
                        metric("Selected period", amount: money(category.currentMinor))
                        metric("Previous period", amount: money(category.previousMinor))
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .walletSurface()
    }

    private func metric(_ label: LocalizedStringKey, amount: String) -> some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 2))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 8))
        return layout {
            Text(label).font(.subheadline).foregroundStyle(WalletTheme.secondaryInk)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(amount).font(.body.weight(.medium)).monospacedDigit()
        }
        .accessibilityElement(children: .combine)
    }

    private func range(_ interval: DateInterval) -> String {
        let formatter = DateIntervalFormatter()
        formatter.locale = locale
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: interval.start, to: interval.end.addingTimeInterval(-1))
    }

    private func money(_ amount: Int64) -> String {
        Money.format(amount, currencyCode: report.currencyCode, locale: locale)
    }
}

private struct ReportFailure: View {
    let error: Error

    var body: some View {
        ContentUnavailableView {
            Label("Unable to complete the operation", systemImage: "exclamationmark.circle")
        } description: {
            Text(error.localizedDescription)
        }
    }
}

private struct ReportPDFDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.pdf]
    let data: Data

    init(data: Data) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else { throw CocoaError(.fileReadCorruptFile) }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

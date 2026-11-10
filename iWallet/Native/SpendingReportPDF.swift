import CoreGraphics
import CoreText
import Foundation

/// Vector text stays selectable, searchable and sharp when the report is printed.
enum SpendingReportPDF {
    @MainActor
    static func data(for report: WalletInsights.SpendingReport, calendar: Calendar, locale: Locale) throws -> Data {
        let bytes = NSMutableData()
        var page = CGRect(x: 0, y: 0, width: 595, height: 842) // A4 in points.
        guard let consumer = CGDataConsumer(data: bytes) else { throw CocoaError(.fileWriteUnknown) }
        let language = Bundle.preferredLocalizations(from: Bundle.main.localizations,
                                                     forPreferences: [locale.identifier]).first
        let strings = language.flatMap { Bundle.main.url(forResource: $0, withExtension: "lproj") }
            .flatMap(Bundle.init(url:)) ?? .main
        let title = strings.localizedString(forKey: "Spending report", value: nil, table: nil)
        let metadata: [CFString: Any] = [kCGPDFContextTitle: title, kCGPDFContextCreator: "iWallet"]
        guard let context = CGContext(consumer: consumer, mediaBox: &page, metadata as CFDictionary) else {
            throw CocoaError(.fileWriteUnknown)
        }
        var layout = Layout(context: context, page: page, calendar: calendar, locale: locale,
                            strings: strings, report: report)
        layout.render()
        context.closePDF()
        return bytes as Data
    }

    private struct Layout {
        let context: CGContext
        let page: CGRect
        let calendar: Calendar
        let locale: Locale
        let strings: Bundle
        let report: WalletInsights.SpendingReport
        private(set) var pageNumber = 0
        private(set) var y: CGFloat = 0

        private let margin: CGFloat = 40
        private let ink = CGColor(srgbRed: 0.08, green: 0.16, blue: 0.12, alpha: 1)
        private let secondary = CGColor(srgbRed: 0.30, green: 0.36, blue: 0.32, alpha: 1)
        private let rule = CGColor(srgbRed: 0.82, green: 0.85, blue: 0.82, alpha: 1)
        private let wash = CGColor(srgbRed: 0.94, green: 0.96, blue: 0.93, alpha: 1)
        private var contentWidth: CGFloat { page.width - 2 * margin }
        private var contentBottom: CGFloat { page.height - 61 }
        private var rtl: Bool { locale.language.characterDirection == .rightToLeft }

        mutating func render() {
            startPage()
            let title = text(localize("Spending report"), size: 28, bold: true)
            y += draw(title, at: 0, top: y, width: contentWidth) + 18
            summary()
            y += 22
            let section = text(localize("Spending by category"), size: 15, bold: true)
            y += draw(section, at: 0, top: y, width: contentWidth) + 11
            if report.categories.isEmpty {
                _ = draw(text(localize("No expenses in either period."), size: 11, color: secondary),
                         at: 0, top: y, width: contentWidth)
            } else {
                tableHeader()
                for category in report.categories {
                    let values = [text(category.name, size: 11),
                                  text(money(category.currentMinor), size: 11, bold: true),
                                  text(money(category.previousMinor), size: 11, color: secondary)]
                    categoryRow(values)
                }
            }
            context.endPDFPage()
        }

        private func localize(_ key: String) -> String {
            strings.localizedString(forKey: key, value: nil, table: nil)
        }

        private func money(_ minor: Int64) -> String {
            Money.format(minor, currencyCode: report.currencyCode, locale: locale)
        }

        private func dateRange(_ interval: DateInterval) -> String {
            // Each report interval ends at the first instant of the excluded local day.
            let lastDay = calendar.date(byAdding: .day, value: -1, to: interval.end) ?? interval.start
            let formatter = DateIntervalFormatter()
            formatter.locale = locale
            formatter.calendar = calendar
            formatter.timeZone = calendar.timeZone
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            return formatter.string(from: interval.start, to: lastDay)
        }

        private mutating func startPage() {
            if pageNumber > 0 { context.endPDFPage() }
            context.beginPDFPage(nil)
            pageNumber += 1
            context.textMatrix = .identity
            _ = draw(text("iWallet", size: 13, bold: true), at: 0, top: 31, width: contentWidth / 2)
            _ = draw(text(report.currencyCode, size: 10, bold: true, color: secondary),
                     at: contentWidth / 2, top: 33, width: contentWidth / 2, trailing: true)
            line(at: 54)
            line(at: page.height - 44)
            _ = draw(text(pageNumber.formatted(.number.locale(locale)), size: 9, color: secondary),
                     at: 0, top: page.height - 36, width: contentWidth, trailing: true)
            y = 68
            if pageNumber > 1 { tableHeader() }
        }

        private mutating func summary() {
            let gap: CGFloat = 12
            let width = (contentWidth - gap) / 2
            let labels = [localize("Selected period"), localize("Previous period")]
            let amounts = [report.totalMinor, report.previousTotalMinor]
            let periods = [report.interval, report.previousInterval]
            let inset: CGFloat = 13
            let textWidth = width - 2 * inset
            var blocks: [[TextBlock]] = []
            for i in labels.indices {
                blocks.append([text(labels[i], size: 10, bold: true, color: secondary),
                               text(money(amounts[i]), size: 18, bold: true),
                               text(dateRange(periods[i]), size: 11, color: secondary)])
            }
            let transactions = String(format: localize("%@: %@"), locale: locale,
                                      localize("Transactions"), report.count.formatted(.number.locale(locale)))
            blocks[0].append(text(transactions, size: 10, color: secondary))
            let gaps: [CGFloat] = [7, 5, 3, 0]
            let heights = blocks.map { block in
                zip(block, gaps).reduce(2 * inset) { $0 + $1.0.height(in: textWidth) + $1.1 }
            }
            let height = heights.max() ?? 0
            for i in blocks.indices {
                let offset = CGFloat(i) * (width + gap)
                let rect = CGRect(x: x(offset, width), y: page.height - y - height, width: width, height: height)
                context.setFillColor(i == 0 ? wash : CGColor(gray: 0.965, alpha: 1))
                context.addPath(CGPath(roundedRect: rect, cornerWidth: 8, cornerHeight: 8, transform: nil))
                context.fillPath()
                var top = y + inset
                for (block, gapAfter) in zip(blocks[i], gaps) {
                    top += draw(block, at: offset + inset, top: top, width: textWidth) + gapAfter
                }
            }
            y += height
        }

        private var columns: [(offset: CGFloat, width: CGFloat)] {
            let gap: CGFloat = 12
            let name = (contentWidth - 2 * gap) * 0.40
            let amount = (contentWidth - 2 * gap - name) / 2
            return [(0, name), (name + gap, amount), (name + amount + 2 * gap, amount)]
        }

        private mutating func tableHeader() {
            let labels = [localize("Category"), localize("Selected period"), localize("Previous period")]
            var height: CGFloat = 0
            for (index, column) in columns.enumerated() {
                let label = text(labels[index], size: 10, bold: true, color: secondary)
                height = max(height, draw(label, at: column.offset, top: y, width: column.width, trailing: index > 0))
            }
            y += height + 7
            line(at: y)
            y += 4
        }

        private mutating func categoryRow(_ values: [TextBlock]) {
            let columns = columns
            let cells = zip(values, columns).map { $0.0.lines(in: $0.1.width) }
            let count = cells.map(\.count).max() ?? 0
            let lineHeights = (0..<count).map { index in
                cells.compactMap { index < $0.count ? $0[index].height : nil }.max() ?? 0
            }
            // Keep ordinary wrapped rows together. An exceptionally long name can flow
            // across pages without dropping either a grapheme or its associated amounts.
            let totalHeight = lineHeights.reduce(12, +)
            let fitsOnFreshPage = totalHeight <= contentBottom - 115
            if y + totalHeight > contentBottom && (fitsOnFreshPage || y + (lineHeights.first ?? 0) + 12 > contentBottom) {
                startPage()
            }
            y += 5
            for (index, height) in lineHeights.enumerated() {
                if y + height + 7 > contentBottom { startPage(); y += 5 }
                for (cell, column) in cells.enumerated() where index < column.count {
                    draw(column[index], at: columns[cell].offset, top: y, width: columns[cell].width, trailing: cell > 0)
                }
                y += height
            }
            y += 6
            line(at: y)
            y += 1
        }

        private func x(_ offset: CGFloat, _ width: CGFloat) -> CGFloat {
            rtl ? page.width - margin - offset - width : margin + offset
        }

        private func line(at top: CGFloat) {
            context.setFillColor(rule)
            context.fill(CGRect(x: margin, y: page.height - top, width: contentWidth, height: 0.7))
        }

        private func text(_ value: String, size: CGFloat, bold: Bool = false, color: CGColor? = nil) -> TextBlock {
            let font: CTFont
            if locale.language.script?.identifier == "Arab" {
                // This font retains Arabic characters in the PDF's searchable text.
                font = CTFontCreateWithName((bold ? "GeezaPro-Bold" : "GeezaPro") as CFString, size, nil)
            } else {
                font = CTFontCreateUIFontForLanguage(bold ? .emphasizedSystem : .system, size, locale.identifier as CFString)
                    ?? CTFontCreateWithName("Helvetica" as CFString, size, nil)
            }
            return TextBlock(value, font: font, color: color ?? ink)
        }

        @discardableResult
        private func draw(_ block: TextBlock, at offset: CGFloat, top: CGFloat, width: CGFloat,
                          trailing: Bool = false) -> CGFloat {
            var height: CGFloat = 0
            for line in block.lines(in: width) {
                draw(line, at: offset, top: top + height, width: width, trailing: trailing)
                height += line.height
            }
            return height
        }

        private func draw(_ line: TextLine, at offset: CGFloat, top: CGFloat, width: CGFloat, trailing: Bool) {
            let flush: CGFloat = trailing != rtl ? 1 : 0
            let dx = CTLineGetPenOffsetForFlush(line.line, Double(flush), Double(width))
            context.textPosition = CGPoint(x: x(offset, width) + CGFloat(dx), y: page.height - top - line.ascent)
            CTLineDraw(line.line, context)
        }
    }

    private struct TextLine {
        let line: CTLine
        let ascent: CGFloat
        let height: CGFloat
    }

    private struct TextBlock {
        let typesetter: CTTypesetter
        let string: NSString

        init(_ value: String, font: CTFont, color: CGColor) {
            let attributed = NSAttributedString(string: value, attributes: [
                NSAttributedString.Key(kCTFontAttributeName as String): font,
                NSAttributedString.Key(kCTForegroundColorAttributeName as String): color
            ])
            typesetter = CTTypesetterCreateWithAttributedString(attributed)
            string = value as NSString
        }

        func height(in width: CGFloat) -> CGFloat { lines(in: width).reduce(0) { $0 + $1.height } }

        func lines(in width: CGFloat) -> [TextLine] {
            var result: [TextLine] = []
            var start = 0
            while start < string.length {
                let suggested = CTTypesetterSuggestLineBreak(typesetter, start, Double(width))
                let count = suggested > 0 ? suggested : string.rangeOfComposedCharacterSequence(at: start).length
                let line = CTTypesetterCreateLine(typesetter, CFRange(location: start, length: count))
                var ascent: CGFloat = 0
                var descent: CGFloat = 0
                var leading: CGFloat = 0
                CTLineGetTypographicBounds(line, &ascent, &descent, &leading)
                result.append(TextLine(line: line, ascent: ascent, height: ceil(ascent + descent + max(leading, 1))))
                start += count
            }
            return result
        }
    }
}

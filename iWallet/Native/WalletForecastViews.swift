import SwiftUI

struct WalletForecastCard: View {
    let payments: [WalletRecurringPayment]
    let currencyCode: String
    let now: Date
    let showPayments: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.locale) private var locale
    @SceneStorage("wallet.overview.forecastDays") private var horizonDays = WalletForecast.Horizon.sevenDays.rawValue
    @State private var showsDates = false
    @State private var showsOverdueDates = false

    private var horizon: WalletForecast.Horizon { WalletForecast.Horizon(rawValue: horizonDays) ?? .sevenDays }

    var body: some View {
        let active = payments.filter { $0.isActive && $0.currencyCode == currencyCode }
        let byID = active.reduce(into: [UUID: WalletRecurringPayment]()) { $0[$1.id] = $1 }
        let result = Result {
            try WalletForecast.make(plans: active.map { try WalletForecast.Plan(payment: $0) },
                                    currencyCode: currencyCode, horizon: horizon, now: now)
        }
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Upcoming payments").font(.headline).accessibilityAddTraits(.isHeader)
                Spacer(minLength: 8)
                Button("All", action: showPayments)
                    .frame(minWidth: 44, minHeight: 44)
                    .accessibilityLabel("All payments")
            }
            Picker("Forecast period", selection: $horizonDays) {
                Text("7 days").tag(WalletForecast.Horizon.sevenDays.rawValue)
                    .accessibilityIdentifier("forecast7Days")
                Text("30 days").tag(WalletForecast.Horizon.thirtyDays.rawValue)
                    .accessibilityIdentifier("forecast30Days")
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("forecastHorizon")

            switch result {
            case .success(let forecast):
                total("Scheduled total", amount: forecast.upcomingMinor, identifier: "forecastUpcomingTotal")
                if !forecast.overdue.isEmpty {
                    total("Overdue", amount: forecast.overdueMinor, identifier: "forecastOverdueTotal")
                }
                Text("Includes today in each payment’s time zone.")
                    .font(.caption).foregroundStyle(.secondary)
                if forecast.upcoming.isEmpty {
                    Text("No payments scheduled in this period.")
                        .font(.subheadline).foregroundStyle(.secondary)
                } else {
                    scheduledDates(forecast.upcoming, payments: byID)
                }
                if !forecast.overdue.isEmpty {
                    Divider()
                    DisclosureGroup(isExpanded: $showsOverdueDates) {
                        LazyVStack(alignment: .leading, spacing: 8) {
                            Text("One open date per overdue plan. Later scheduled dates appear in the forecast.")
                                .font(.caption).foregroundStyle(.secondary)
                            ForEach(forecast.overdue) { occurrence in
                                Divider()
                                occurrenceRow(occurrence, payment: byID[occurrence.planID])
                            }
                        }
                    } label: {
                        Text("Overdue dates").font(.subheadline)
                    }
                    .accessibilityIdentifier("forecastOverdueOccurrences")
                }
            case .failure(let error):
                Label("Unable to calculate forecast", systemImage: "exclamationmark.triangle")
                Text(error.localizedDescription).font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .walletSurface()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("upcomingPayments")
    }

    private func total(_ title: LocalizedStringKey, amount: Int64, identifier: String) -> some View {
        let formatted = Money.format(amount, currencyCode: currencyCode, locale: locale)
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 12))
        return layout {
            Text(title).font(.subheadline.weight(.medium))
            if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 0) }
            Text(formatted).font(.headline).monospacedDigit()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(title))
        .accessibilityValue(Text(formatted))
        .accessibilityIdentifier(identifier)
    }

    @ViewBuilder
    private func scheduledDates(_ occurrences: [WalletForecast.Occurrence],
                                payments: [UUID: WalletRecurringPayment]) -> some View {
        if let first = occurrences.first {
            occurrenceRow(first, payment: payments[first.planID])
            if occurrences.count > 1 {
                DisclosureGroup(isExpanded: $showsDates) {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(occurrences.dropFirst()) { occurrence in
                            Divider()
                            occurrenceRow(occurrence, payment: payments[occurrence.planID])
                        }
                    }
                } label: {
                    Text("Scheduled dates").font(.subheadline)
                }
                .accessibilityIdentifier("forecastOccurrences")
            }
        }
    }

    @ViewBuilder
    private func occurrenceRow(_ occurrence: WalletForecast.Occurrence, payment: WalletRecurringPayment?) -> some View {
        if let payment, payment.nextDueDate == occurrence.date {
            NavigationLink {
                RecurringPaymentDetailView(payment: payment)
            } label: {
                rowContent(occurrence, navigates: true)
            }
            .buttonStyle(.plain)
        } else {
            rowContent(occurrence, navigates: false)
        }
    }

    private func rowContent(_ occurrence: WalletForecast.Occurrence, navigates: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(occurrence.name).font(.subheadline.weight(.medium))
            Text(Money.format(occurrence.amountMinor, currencyCode: currencyCode, locale: locale))
                .font(.subheadline).monospacedDigit()
            HStack {
                Text(displayDate(occurrence)).font(.caption).foregroundStyle(.secondary)
                Spacer(minLength: 4)
                if navigates {
                    Image(systemName: "chevron.forward").font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary).accessibilityHidden(true)
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private func displayDate(_ occurrence: WalletForecast.Occurrence) -> String {
        let zone = TimeZone(identifier: occurrence.timeZoneIdentifier) ?? .current
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        let date = occurrence.date.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted,
                                                               locale: locale, calendar: calendar, timeZone: zone))
        return zone.identifier == TimeZone.current.identifier ? date : "\(date) · \(zone.identifier)"
    }
}

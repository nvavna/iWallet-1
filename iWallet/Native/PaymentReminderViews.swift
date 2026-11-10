import SwiftData
import SwiftUI
import UIKit

struct PaymentReminderSettingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.openURL) private var openURL
    private let reminders = PaymentReminders.shared

    var body: some View {
        Form {
            Section {
                Toggle("Payment reminders", isOn: Binding(
                    get: { reminders.preferences.isEnabled },
                    set: { enabled in Task { await reminders.setEnabled(enabled, context: context) } }
                ))
                .disabled(reminders.isRequestingPermission ||
                          (reminders.permission == .denied && !reminders.preferences.isEnabled))
                .accessibilityIdentifier("paymentRemindersEnabled")
            } footer: {
                Text("Notifications hide payment names and amounts. Tap a reminder to open Payments.")
            }
            if reminders.permission == .denied {
                Section {
                    Text("Notifications are turned off in iOS Settings.")
                        .accessibilityIdentifier("paymentReminderStatus")
                    Button("Open notification settings") {
                        if let url = URL(string: UIApplication.openNotificationSettingsURLString) { openURL(url) }
                    }
                    .accessibilityIdentifier("openNotificationSettings")
                }
            }
            if reminders.preferences.isEnabled {
                Section {
                    Menu {
                        Picker("Remind me", selection: leadBinding) {
                            Text("On the due date").tag(0)
                            Text("The day before").tag(1)
                        }
                    } label: {
                        WalletFormMenuLabel("Remind me", value: reminders.preferences.daysBefore == 0
                            ? String(localized: "On the due date") : String(localized: "The day before"))
                    }
                    .accessibilityIdentifier("paymentReminderLead")
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Reminder time").font(.subheadline).foregroundStyle(.secondary)
                        DatePicker("Reminder time", selection: timeBinding, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                            .environment(\.calendar, Self.clock)
                            .environment(\.timeZone, Self.clock.timeZone)
                            .accessibilityIdentifier("paymentReminderTime")
                    }
                } footer: {
                    Text("Times follow each payment’s time zone. A reminder whose time has passed is skipped.")
                }
                if reminders.permission == .allowed {
                    Section {
                        LabeledContent("Scheduled alerts", value: reminders.scheduledCount.formatted())
                            .accessibilityIdentifier("paymentReminderStatus")
                    } footer: {
                        if reminders.scheduledCount == 0 {
                            Text("Check the next payment date and reminder time for your active plans.")
                        } else if reminders.scheduledCount >= 60 {
                            Text("iWallet schedules the next alert for up to 60 active payments. Open the app to refresh the queue.")
                        }
                    }
                }
            }
            if let error = reminders.errorMessage {
                Section {
                    Text(error).fixedSize(horizontal: false, vertical: true)
                    Button("Try again") { Task { await reminders.refresh(context: context) } }
                } header: { Text("Unable to update reminders") }
            }
        }
        .navigationTitle("Reminders")
        .navigationBarTitleDisplayMode(.inline)
        .task { await reminders.refresh(context: context) }
    }

    private var leadBinding: Binding<Int> {
        Binding(get: { reminders.preferences.daysBefore }, set: { days in
            Task { await reminders.setSchedule(daysBefore: days, hour: reminders.preferences.hour,
                                               minute: reminders.preferences.minute, context: context) }
        })
    }

    // The picker edits a clock time, independent of the device's current DST day.
    private static var clock: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private var timeBinding: Binding<Date> {
        Binding(get: {
            Date(timeIntervalSinceReferenceDate: Double(reminders.preferences.hour * 3600 + reminders.preferences.minute * 60))
        }, set: { time in
            let hour = Self.clock.component(.hour, from: time)
            let minute = Self.clock.component(.minute, from: time)
            Task { await reminders.setSchedule(daysBefore: reminders.preferences.daysBefore,
                                               hour: hour, minute: minute, context: context) }
        })
    }
}

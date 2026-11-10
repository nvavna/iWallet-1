import Foundation
import Observation
import SwiftData
import UserNotifications

struct PaymentReminderPreferences: Codable, Equatable {
    var isEnabled = false
    var daysBefore = 0
    var hour = 9
    var minute = 0

    static let key = "paymentReminders.preferences.v1"

    init() {}

    init(defaults: UserDefaults) {
        guard let data = defaults.data(forKey: Self.key),
              let saved = try? JSONDecoder().decode(Self.self, from: data),
              (0...1).contains(saved.daysBefore), (0..<24).contains(saved.hour), (0..<60).contains(saved.minute)
        else { return }
        self = saved
    }

    func save(to defaults: UserDefaults) {
        if let data = try? JSONEncoder().encode(self) { defaults.set(data, forKey: Self.key) }
    }
}

struct PaymentReminderPlan: Equatable {
    let id: UUID
    let occurrenceID: UUID
    let dueDate: Date
    let timeZoneIdentifier: String
    let isActive: Bool
}

struct PaymentReminderRequest: Equatable {
    static let prefix = "iwallet.payment-reminder.v1."
    let identifier: String
    let occurrence: String?
    let date: Date?
    let title: String
    let body: String
}

enum PaymentReminderPlanner {
    // Leave four of the app's 64 local slots free and account for other requests.
    static func requests(for plans: [PaymentReminderPlan], preferences: PaymentReminderPreferences,
                         now: Date, foreignCount: Int, delivered: [String: String]) -> [PaymentReminderRequest] {
        guard preferences.isEnabled else { return [] }
        let capacity = max(0, 60 - max(0, foreignCount))
        let title = NSLocalizedString("Payment reminder", comment: "Private notification title")
        let body = preferences.daysBefore == 0
            ? NSLocalizedString("A scheduled payment is due today.", comment: "Private notification body")
            : NSLocalizedString("A scheduled payment is due tomorrow.", comment: "Private notification body")
        let requests = plans.compactMap { plan -> PaymentReminderRequest? in
            guard plan.isActive, let zone = TimeZone(identifier: plan.timeZoneIdentifier) else { return nil }
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = zone
            let identifier = PaymentReminderRequest.prefix + plan.id.uuidString
            guard delivered[identifier] != plan.occurrenceID.uuidString,
                  let day = calendar.date(byAdding: .day, value: -preferences.daysBefore, to: plan.dueDate),
                  let date = calendar.date(bySettingHour: preferences.hour, minute: preferences.minute, second: 0,
                                           of: day, matchingPolicy: .nextTime, repeatedTimePolicy: .first),
                  calendar.isDate(date, inSameDayAs: day), date > now else { return nil }
            return PaymentReminderRequest(identifier: identifier, occurrence: plan.occurrenceID.uuidString,
                                          date: date, title: title, body: body)
        }.sorted { lhs, rhs in
            if lhs.date == rhs.date { return lhs.identifier < rhs.identifier }
            return (lhs.date ?? .distantFuture) < (rhs.date ?? .distantFuture)
        }
        return Array(requests.prefix(capacity))
    }
}

enum PaymentReminderPermission { case undetermined, allowed, denied }

@MainActor
protocol PaymentReminderCenter {
    func permission() async -> PaymentReminderPermission
    func requestPermission() async throws -> Bool
    func pending() async -> [PaymentReminderRequest]
    func delivered() async -> [String: String]
    func removePending(_ ids: [String])
    func removeDelivered(_ ids: [String])
    func add(_ request: PaymentReminderRequest) async throws
}

@MainActor
private struct SystemPaymentReminderCenter: PaymentReminderCenter {
    private var center: UNUserNotificationCenter { .current() }

    func permission() async -> PaymentReminderPermission {
        switch await center.notificationSettings().authorizationStatus {
        case .notDetermined: return .undetermined
        case .authorized, .provisional: return .allowed
        #if os(iOS)
        case .ephemeral: return .allowed
        #endif
        default: return .denied
        }
    }

    func requestPermission() async throws -> Bool { try await center.requestAuthorization(options: [.alert, .sound]) }

    func pending() async -> [PaymentReminderRequest] {
        await center.pendingNotificationRequests().map {
            PaymentReminderRequest(identifier: $0.identifier, occurrence: $0.content.userInfo["occurrence"] as? String,
                                  date: ($0.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate(),
                                  title: $0.content.title, body: $0.content.body)
        }
    }

    func delivered() async -> [String: String] {
        var occurrences: [String: String] = [:]
        for notification in await center.deliveredNotifications() {
            let request = notification.request
            if request.identifier.hasPrefix(PaymentReminderRequest.prefix) {
                occurrences[request.identifier] = request.content.userInfo["occurrence"] as? String ?? ""
            }
        }
        return occurrences
    }

    func removePending(_ ids: [String]) { center.removePendingNotificationRequests(withIdentifiers: ids) }
    func removeDelivered(_ ids: [String]) { center.removeDeliveredNotifications(withIdentifiers: ids) }

    func add(_ request: PaymentReminderRequest) async throws {
        guard let date = request.date, let occurrence = request.occurrence else { return }
        // Encode the selected instant in UTC. Travel or the repeated fall-back
        // hour must not reinterpret it in the current device's time zone.
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(secondsFromGMT: 0)!
        var components = utc.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        components.calendar = utc
        components.timeZone = utc.timeZone
        let content = UNMutableNotificationContent()
        content.title = request.title
        content.body = request.body
        content.sound = .default
        content.userInfo = ["occurrence": occurrence]
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        try await center.add(UNNotificationRequest(identifier: request.identifier, content: content, trigger: trigger))
    }
}

@MainActor
@Observable
final class PaymentReminders {
    static let shared = PaymentReminders(center: SystemPaymentReminderCenter(), defaults: .standard)
    private(set) var preferences: PaymentReminderPreferences
    private(set) var permission = PaymentReminderPermission.undetermined
    private(set) var scheduledCount = 0
    private(set) var errorMessage: String?
    private(set) var isRequestingPermission = false
    private(set) var openPaymentsRequested = false

    @ObservationIgnored private let center: PaymentReminderCenter
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private var latestPlans: [PaymentReminderPlan] = []
    @ObservationIgnored private var latestReadError: String?
    @ObservationIgnored private var wantsEnabled = false
    @ObservationIgnored private var revision: UInt = 0
    @ObservationIgnored private var worker: Task<Void, Never>?

    init(center: PaymentReminderCenter, defaults: UserDefaults, now: @escaping () -> Date = Date.init) {
        self.center = center
        self.defaults = defaults
        self.now = now
        preferences = PaymentReminderPreferences(defaults: defaults)
    }

    static func installNotificationDelegate() {
        UNUserNotificationCenter.current().delegate = PaymentReminderDelegate.shared
    }

    func consumeOpenPaymentsRequest() { openPaymentsRequested = false }
    fileprivate func openPayments() { openPaymentsRequested = true }

    /// Only this explicitly invoked user action can display the system prompt.
    func setEnabled(_ enabled: Bool, context: ModelContext) async {
        wantsEnabled = enabled
        if enabled {
            guard !isRequestingPermission else { return }
            isRequestingPermission = true
            defer { isRequestingPermission = false }
            do {
                var status = await center.permission()
                if status == .undetermined && wantsEnabled {
                    _ = try await center.requestPermission()
                    status = await center.permission()
                }
                guard wantsEnabled else { return }
                permission = status
                guard permission == .allowed else { return }
            } catch {
                if wantsEnabled { errorMessage = error.localizedDescription }
                return
            }
        }
        preferences.isEnabled = enabled
        preferences.save(to: defaults)
        await refresh(context: context)
    }

    func setSchedule(daysBefore: Int, hour: Int, minute: Int, context: ModelContext) async {
        guard (0...1).contains(daysBefore), (0..<24).contains(hour), (0..<60).contains(minute) else { return }
        preferences.daysBefore = daysBefore
        preferences.hour = hour
        preferences.minute = minute
        preferences.save(to: defaults)
        await refresh(context: context)
    }

    func refresh(context: ModelContext) async {
        do {
            let plans: [PaymentReminderPlan]
            if preferences.isEnabled {
                let reader = ModelContext(context.container)
                plans = try reader.fetch(FetchDescriptor<WalletRecurringPayment>()).map {
                    PaymentReminderPlan(id: $0.id, occurrenceID: $0.occurrenceID, dueDate: $0.nextDueDate,
                                        timeZoneIdentifier: $0.timeZoneIdentifier, isActive: $0.isActive)
                }
            } else { plans = [] }
            await refresh(plans: plans)
        } catch { await refreshAfterReadFailure(error) }
    }

    func refresh(plans: [PaymentReminderPlan]) async {
        latestPlans = plans
        latestReadError = nil
        await enqueue()
    }

    func refreshAfterReadFailure(_ error: Error) async {
        latestPlans = []
        latestReadError = error.localizedDescription
        await enqueue()
    }

    private func enqueue() async {
        revision &+= 1
        // UNUserNotificationCenter calls suspend. Drain the newest snapshot
        // serially so an older request can't be added after pausing or deleting.
        if worker == nil { worker = Task { await self.drain() } }
        await worker?.value
    }

    private func drain() async {
        while true {
            let current = revision
            let plans = latestPlans
            let readError = latestReadError
            let settings = preferences
            let authorization = await center.permission()
            let pending = await center.pending()
            let delivered = readError == nil ? await center.delivered() : [:]
            guard revision == current else { continue }
            permission = authorization
            errorMessage = readError
            let active = readError == nil && settings.isEnabled && authorization == .allowed
            let owned = pending.filter { $0.identifier.hasPrefix(PaymentReminderRequest.prefix) }
            let desired = active ? PaymentReminderPlanner.requests(for: plans, preferences: settings, now: now(),
                foreignCount: pending.count - owned.count, delivered: delivered) : []
            let desiredIDs = Set(desired.map(\.identifier))
            let obsolete = owned.map(\.identifier).filter { !desiredIDs.contains($0) }
            if !obsolete.isEmpty { center.removePending(obsolete) }
            let activeTokens = Dictionary(uniqueKeysWithValues: plans.filter(\.isActive).map {
                (PaymentReminderRequest.prefix + $0.id.uuidString, $0.occurrenceID.uuidString)
            })
            let staleDelivered = delivered.keys.filter {
                $0.hasPrefix(PaymentReminderRequest.prefix) && (!active || activeTokens[$0] != delivered[$0])
            }
            if !staleDelivered.isEmpty { center.removeDelivered(staleDelivered) }
            let existing = Dictionary(uniqueKeysWithValues: owned.map { ($0.identifier, $0) })
            var count = 0
            for request in desired {
                guard current == revision else { break }
                do {
                    if existing[request.identifier] != request { try await center.add(request) }
                    count += 1
                } catch {
                    // A failed replacement must not leave an alert for an old date.
                    if existing[request.identifier] != nil { center.removePending([request.identifier]) }
                    errorMessage = error.localizedDescription
                }
            }
            if current == revision {
                scheduledCount = count
                worker = nil
                return
            }
        }
    }
}

private final class PaymentReminderDelegate: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    static let shared = PaymentReminderDelegate()

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        notification.request.identifier.hasPrefix(PaymentReminderRequest.prefix) ? [.banner, .list, .sound] : []
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        guard response.actionIdentifier == UNNotificationDefaultActionIdentifier,
              response.notification.request.identifier.hasPrefix(PaymentReminderRequest.prefix) else { return }
        await PaymentReminders.shared.openPayments()
    }
}

import Foundation
import SwiftData
import XCTest
@testable import WalletCore

final class PaymentReminderTests: XCTestCase {
    private func moment(_ iso: String) throws -> Date { try XCTUnwrap(ISO8601DateFormatter().date(from: iso)) }

    private func plan(_ date: Date, zone: String = "UTC", active: Bool = true) -> PaymentReminderPlan {
        PaymentReminderPlan(id: UUID(), occurrenceID: UUID(), dueDate: date, timeZoneIdentifier: zone, isActive: active)
    }

    private func enabledSettings() -> PaymentReminderPreferences {
        var settings = PaymentReminderPreferences()
        settings.isEnabled = true
        return settings
    }

    private func defaults() throws -> UserDefaults {
        let suite = "iWallet.PaymentReminderTests." + UUID().uuidString
        let store = try XCTUnwrap(UserDefaults(suiteName: suite))
        addTeardownBlock { store.removePersistentDomain(forName: suite) }
        return store
    }

    func testPlannerUsesSavedZoneAndCalendarDayAcrossDSTInsteadOfSubtracting24Hours() throws {
        let now = try moment("2026-03-06T00:00:00Z")
        let nyc = plan(try moment("2026-03-09T04:00:00Z"), zone: "America/New_York")
        var settings = enabledSettings()
        settings.daysBefore = 1
        settings.hour = 2
        settings.minute = 30
        // March 8 jumps from 01:59 to 03:00. Use the first real instant after the gap.
        let spring = PaymentReminderPlanner.requests(for: [nyc], preferences: settings,
                                                      now: now, foreignCount: 0, delivered: [:])
        XCTAssertEqual(spring.first?.date, try moment("2026-03-08T07:00:00Z"))
        let fall = plan(try moment("2026-11-01T04:00:00Z"), zone: "America/New_York")
        settings.daysBefore = 0
        settings.hour = 1
        let repeated = PaymentReminderPlanner.requests(for: [fall], preferences: settings,
                                                        now: now, foreignCount: 0, delivered: [:])
        XCTAssertEqual(repeated.first?.date, try moment("2026-11-01T05:30:00Z"))
    }

    func testPlannerKeepsNearestEligibleOccurrencesWithinSharedDeviceLimit() throws {
        let now = try moment("2026-01-01T10:00:00Z")
        let tomorrow = try moment("2026-01-02T00:00:00Z")
        let first = plan(tomorrow)
        let second = plan(tomorrow.addingTimeInterval(86_400))
        let delivered = plan(tomorrow)
        let other = [plan(now), plan(tomorrow, active: false), plan(tomorrow, zone: "Invalid/Zone")]
        let rows = [second, first, delivered] + other
        let sent = [PaymentReminderRequest.prefix + delivered.id.uuidString: delivered.occurrenceID.uuidString]
        let result = PaymentReminderPlanner.requests(for: rows, preferences: enabledSettings(), now: now,
                                                     foreignCount: 59, delivered: sent)
        XCTAssertEqual(result.map(\.occurrence), [first.occurrenceID.uuidString])
        XCTAssertTrue(PaymentReminderPlanner.requests(for: rows, preferences: enabledSettings(), now: now,
                                                     foreignCount: 64, delivered: [:]).isEmpty)
        XCTAssertTrue(PaymentReminderPlanner.requests(for: rows, preferences: PaymentReminderPreferences(), now: now,
                                                     foreignCount: 0, delivered: [:]).isEmpty)
    }

    @MainActor
    func testPermissionPromptRequiresExplicitEnableAndDenialLeavesPreferenceOff() async throws {
        let settings = try defaults()
        let center = ReminderTestCenter()
        let service = PaymentReminders(center: center, defaults: settings)
        let container = try WalletStore.makeContainer(inMemory: true)
        await service.refresh(context: container.mainContext)
        XCTAssertEqual(center.promptCount, 0)
        await service.setEnabled(true, context: container.mainContext)
        XCTAssertEqual(center.promptCount, 1)
        XCTAssertEqual(service.permission, .denied)
        XCTAssertFalse(PaymentReminderPreferences(defaults: settings).isEnabled)
        await service.refresh(context: container.mainContext)
        await service.setEnabled(true, context: container.mainContext)
        XCTAssertEqual(center.promptCount, 1)
        center.access = .allowed // Person enabled permission in iOS Settings.
        await service.setEnabled(true, context: container.mainContext)
        XCTAssertTrue(PaymentReminderPreferences(defaults: settings).isEnabled)
        XCTAssertEqual(center.promptCount, 1)
    }

    @MainActor
    func testReconcileReadsCommittedPlansAndCleansPausedDeletedAndOldDeliveredOnly() async throws {
        let store = try defaults()
        let now = try moment("2026-01-01T00:00:00Z")
        let due = try moment("2026-01-02T00:00:00Z")
        let center = ReminderTestCenter()
        center.access = .allowed
        let service = PaymentReminders(center: center, defaults: store, now: { now })
        let container = try WalletStore.makeContainer(inMemory: true)
        let context = container.mainContext
        let plan = WalletRecurringPayment(name: "Private clinic", amountMinor: 98765, currencyCode: "USD", category: nil,
                                          cadence: .weekly, nextDueDate: due, anchorDay: 2, anchorMonth: 1,
                                          timeZoneIdentifier: "UTC")
        context.insert(plan)
        try context.save()
        center.requests["other.feature"] = PaymentReminderRequest(identifier: "other.feature", occurrence: nil,
            date: due, title: "Other", body: "Unrelated")
        await service.setEnabled(true, context: context)
        let id = PaymentReminderRequest.prefix + plan.id.uuidString
        let first = try XCTUnwrap(center.requests[id])
        XCTAssertFalse((first.title + first.body).contains(plan.name))
        XCTAssertFalse((first.title + first.body).contains("987"))
        XCTAssertEqual(service.scheduledCount, 1)
        await service.refresh(context: context)
        XCTAssertEqual(center.addCount, 1, "An unchanged request is not re-added on every foreground.")
        center.deliveredOccurrences[id] = plan.occurrenceID.uuidString
        plan.occurrenceID = UUID()
        plan.nextDueDate = due.addingTimeInterval(7 * 86_400)
        try context.save()
        await service.refresh(context: context)
        XCTAssertEqual(center.requests[id]?.occurrence, plan.occurrenceID.uuidString)
        XCTAssertNil(center.deliveredOccurrences[id])
        let restarted = PaymentReminders(center: center, defaults: store, now: { now })
        await restarted.refresh(context: context)
        XCTAssertEqual(center.addCount, 2)
        plan.isActive = false
        try context.save()
        await restarted.refresh(context: context)
        XCTAssertNil(center.requests[id])
        plan.isActive = true
        try context.save()
        await restarted.refresh(context: context)
        XCTAssertNotNil(center.requests[id])
        context.delete(plan)
        try context.save()
        await restarted.refresh(context: context)
        XCTAssertEqual(Set(center.requests.keys), ["other.feature"])
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<WalletTransaction>()), 0)
    }

    @MainActor
    func testDisabledOrRevokedAuthorizationCancelsOnlyOwnedNotifications() async throws {
        let settings = try defaults()
        enabledSettings().save(to: settings)
        let now = try moment("2026-01-01T00:00:00Z")
        let future = plan(now.addingTimeInterval(86_400))
        let center = ReminderTestCenter()
        center.access = .allowed
        let service = PaymentReminders(center: center, defaults: settings, now: { now })
        await service.refresh(plans: [future])
        XCTAssertEqual(service.scheduledCount, 1)
        let id = PaymentReminderRequest.prefix + future.id.uuidString
        center.deliveredOccurrences = [id: future.occurrenceID.uuidString, "other.feature": "foreign"]
        center.access = .denied
        await service.refresh(plans: [future])
        XCTAssertTrue(center.requests.isEmpty)
        XCTAssertEqual(center.deliveredOccurrences, ["other.feature": "foreign"])
        XCTAssertEqual(service.permission, .denied)
        XCTAssertEqual(center.promptCount, 0)
        let container = try WalletStore.makeContainer(inMemory: true)
        await service.setEnabled(false, context: container.mainContext)
        XCTAssertFalse(PaymentReminderPreferences(defaults: settings).isEnabled)
    }

    @MainActor
    func testNewSnapshotWinsEvenWhenOlderAddIsAlreadyInFlight() async throws {
        let settings = try defaults()
        enabledSettings().save(to: settings)
        let now = try moment("2026-01-01T00:00:00Z")
        let future = plan(now.addingTimeInterval(86_400))
        let center = ReminderTestCenter()
        center.access = .allowed
        let service = PaymentReminders(center: center, defaults: settings, now: { now })
        let started = expectation(description: "Older request has started scheduling")
        center.pauseAdd = { started.fulfill() }
        let original = Task { await service.refresh(plans: [future]) }
        await fulfillment(of: [started], timeout: 5)
        let deletion = Task { await service.refresh(plans: []) }
        await Task.yield()
        center.gate?.resume()
        await original.value
        await deletion.value
        XCTAssertTrue(center.requests.isEmpty)
        XCTAssertEqual(service.scheduledCount, 0)
    }

    @MainActor
    func testFailedReplacementRemovesStaleAlertAndCanRetry() async throws {
        let settings = try defaults()
        enabledSettings().save(to: settings)
        let now = try moment("2026-01-01T00:00:00Z")
        let old = plan(now.addingTimeInterval(86_400))
        let revised = PaymentReminderPlan(id: old.id, occurrenceID: UUID(), dueDate: now.addingTimeInterval(172_800),
                                          timeZoneIdentifier: "UTC", isActive: true)
        let center = ReminderTestCenter()
        center.access = .allowed
        let service = PaymentReminders(center: center, defaults: settings, now: { now })
        await service.refresh(plans: [old])
        center.failNextAdd = true
        await service.refresh(plans: [revised])
        XCTAssertNotNil(service.errorMessage)
        XCTAssertTrue(center.requests.isEmpty)
        await service.refresh(plans: [revised])
        XCTAssertNil(service.errorMessage)
        XCTAssertEqual(center.requests.values.map(\.occurrence), [revised.occurrenceID.uuidString])
    }

    @MainActor
    func testDisableWinsWhileSystemPermissionRequestIsInFlight() async throws {
        let store = try defaults()
        let center = ReminderTestCenter()
        let service = PaymentReminders(center: center, defaults: store)
        let container = try WalletStore.makeContainer(inMemory: true)
        let started = expectation(description: "System is asking permission")
        center.pausePrompt = { started.fulfill() }
        let enable = Task { await service.setEnabled(true, context: container.mainContext) }
        await fulfillment(of: [started], timeout: 5)
        await service.setEnabled(false, context: container.mainContext)
        center.promptGate?.resume()
        await enable.value
        XCTAssertEqual(center.access, .allowed)
        XCTAssertFalse(service.preferences.isEnabled)
        XCTAssertFalse(PaymentReminderPreferences(defaults: store).isEnabled)
        XCTAssertTrue(center.requests.isEmpty)
    }

    @MainActor
    func testReadFailureSupersedesOlderInFlightAddAndPreservesDeliveredUntilRetry() async throws {
        let settings = try defaults()
        enabledSettings().save(to: settings)
        let now = try moment("2026-01-01T00:00:00Z")
        let future = plan(now.addingTimeInterval(86_400))
        let center = ReminderTestCenter()
        center.access = .allowed
        let foreign = PaymentReminderRequest(identifier: "other.feature", occurrence: nil, date: now,
                                             title: "Other", body: "Unrelated")
        center.requests[foreign.identifier] = foreign
        let service = PaymentReminders(center: center, defaults: settings, now: { now })
        let started = expectation(description: "Older snapshot is already scheduling")
        center.pauseAdd = { started.fulfill() }
        let old = Task { await service.refresh(plans: [future]) }
        await fulfillment(of: [started], timeout: 5)
        let previous = PaymentReminderRequest.prefix + UUID().uuidString
        center.deliveredOccurrences[previous] = "previous"
        let readError = CocoaError(.fileReadCorruptFile)
        let failure = Task { await service.refreshAfterReadFailure(readError) }
        await Task.yield()
        center.gate?.resume()
        await old.value
        await failure.value
        XCTAssertEqual(center.requests, [foreign.identifier: foreign])
        XCTAssertEqual(center.deliveredOccurrences, [previous: "previous"])
        XCTAssertEqual(service.errorMessage, readError.localizedDescription)
        XCTAssertEqual(service.scheduledCount, 0)
        await service.refresh(plans: [future])
        XCTAssertNil(service.errorMessage)
        XCTAssertEqual(service.scheduledCount, 1)
    }
}

@MainActor
private final class ReminderTestCenter: PaymentReminderCenter {
    var access = PaymentReminderPermission.undetermined
    var promptCount = 0
    var addCount = 0
    var requests: [String: PaymentReminderRequest] = [:]
    var deliveredOccurrences: [String: String] = [:]
    var failNextAdd = false
    var pauseAdd: (() -> Void)?
    var gate: CheckedContinuation<Void, Never>?
    var pausePrompt: (() -> Void)?
    var promptGate: CheckedContinuation<Void, Never>?

    func permission() async -> PaymentReminderPermission { access }
    func requestPermission() async throws -> Bool {
        promptCount += 1
        if let prompt = pausePrompt {
            pausePrompt = nil
            await withCheckedContinuation { promptGate = $0; prompt() }
            promptGate = nil
            access = .allowed
            return true
        }
        access = .denied
        return false
    }
    func pending() async -> [PaymentReminderRequest] { Array(requests.values) }
    func delivered() async -> [String: String] { deliveredOccurrences }
    func removePending(_ ids: [String]) { for id in ids { requests.removeValue(forKey: id) } }
    func removeDelivered(_ ids: [String]) { for id in ids { deliveredOccurrences.removeValue(forKey: id) } }
    func add(_ request: PaymentReminderRequest) async throws {
        if let pause = pauseAdd {
            pauseAdd = nil
            await withCheckedContinuation { gate = $0; pause() }
            gate = nil
        }
        if failNextAdd { failNextAdd = false; throw CocoaError(.fileWriteUnknown) }
        addCount += 1
        requests[request.identifier] = request
    }
}

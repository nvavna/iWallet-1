import StoreKitTest
import XCTest

@MainActor
final class SpendingReportPurchaseTests: XCTestCase {
    private var session: SKTestSession!
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US", "-preferredCurrencyCode", "USD"]
        // On a new simulator Xcode installs the app on first launch. StoreKitTest
        // needs that installation to associate its catalog with our bundle.
        app.launch()
        app.terminate()
        let configuration = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "SpendingReports", withExtension: "storekit"))
        session = try SKTestSession(contentsOf: configuration)
        session.resetToDefaultState()
        session.disableDialogs = true
        session.clearTransactions()
        app.launch()
    }

    override func tearDown() {
        app?.terminate()
        session?.clearTransactions()
        session?.resetToDefaultState()
    }

    private func openReports() {
        let settings = app.tabBars.buttons["Settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 20))
        settings.tap()
        app.buttons["settingsSpendingReport"].tap()
    }

    func testUnavailableCatalogAllowsPreviewAndRetryWithoutBuying() async throws {
        try await session.setSimulatedError(.generic(.unknown), forAPI: .loadProducts)
        openReports()
        let unavailable = app.staticTexts["The App Store price is unavailable."]
        let buy = app.buttons["buySpendingReports"]
        XCTAssertTrue(unavailable.waitForExistence(timeout: 15))
        XCTAssertFalse(buy.exists)

        app.buttons["openSampleSpendingReport"].tap()
        XCTAssertTrue(app.staticTexts["This report uses example expenses."].waitForExistence(timeout: 5))
        let total = app.staticTexts["reportSelectedTotal"]
        let previous = app.staticTexts["reportPreviousTotal"]
        XCTAssertEqual(total.label, "Selected period, $99.00")
        XCTAssertEqual(previous.label, "Previous period, $100.00")
        XCTAssertTrue(app.datePickers["reportStartDate"].exists)
        attachSample("Sample pay period")
        app.datePickers["reportEndDate"].tap()
        let november8 = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "November 8")).firstMatch
        XCTAssertTrue(november8.waitForExistence(timeout: 5), app.debugDescription)
        november8.tap()
        if november8.exists {
            // The compact picker can stay open after selecting a day.
            let title = app.navigationBars["Sample report"]
            title.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            XCTAssertTrue(november8.waitForNonExistence(timeout: 5))
        }
        XCTAssertEqual(total.label, "Selected period, $81.00")
        XCTAssertEqual(previous.label, "Previous period, $28.00")
        XCTAssertFalse(app.buttons["exportSpendingReportPDF"].exists)
        XCTAssertFalse(buy.exists)
        attachSample("Sample after changing end date")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(unavailable.waitForExistence(timeout: 15))

        try await session.setSimulatedError(nil, forAPI: .loadProducts)
        app.buttons["Try again"].tap()
        XCTAssertTrue(buy.waitForExistence(timeout: 15))
        XCTAssertTrue(buy.label.contains("4.99"), buy.label)
        XCTAssertFalse(unavailable.exists)
        XCTAssertTrue(session.allTransactions().isEmpty)
    }

    private func attachSample(_ name: String) {
        let sample = XCTAttachment(screenshot: app.screenshot())
        sample.name = name
        sample.lifetime = .keepAlways
        add(sample)
    }

    func testPurchasePersistsOnRelaunchAndRefundLocksReport() throws {
        openReports()
        let buy = app.buttons["buySpendingReports"]
        XCTAssertTrue(buy.waitForExistence(timeout: 20), app.debugDescription)
        XCTAssertTrue(buy.label.contains("4.99"), buy.label)
        app.buttons["openSampleSpendingReport"].tap()
        let export = app.buttons["exportSpendingReportPDF"]
        XCTAssertFalse(export.exists)
        XCTAssertTrue(app.staticTexts["This report uses example expenses."].exists)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        buy.tap()
        XCTAssertTrue(export.waitForExistence(timeout: 15), app.debugDescription)
        let tx = try XCTUnwrap(session.allTransactions().first { $0.productIdentifier == "com.idevnva.iwallet.spendingreports" })
        app.terminate()
        app.launch()
        openReports()
        XCTAssertTrue(export.waitForExistence(timeout: 10))
        try session.refundTransaction(identifier: tx.identifier)
        XCTAssertTrue(buy.waitForExistence(timeout: 20), app.debugDescription)
        XCTAssertFalse(export.exists)
    }

    func testPendingPurchaseUnlocksOnlyWhenApproved() throws {
        session.askToBuyEnabled = true
        openReports()
        let buy = app.buttons["buySpendingReports"]
        XCTAssertTrue(buy.waitForExistence(timeout: 20))
        buy.tap()
        XCTAssertTrue(app.staticTexts["reportPurchaseMessage"].waitForExistence(timeout: 12))
        XCTAssertFalse(app.buttons["exportSpendingReportPDF"].exists)
        let tx = try XCTUnwrap(session.allTransactions().first(where: { $0.pendingAskToBuyConfirmation }))
        try session.approveAskToBuyTransaction(identifier: tx.identifier)
        XCTAssertTrue(app.buttons["exportSpendingReportPDF"].waitForExistence(timeout: 20), app.debugDescription)
    }

    func testExistingPurchaseOpensFromOverviewInRussian() async throws {
        app.terminate()
        _ = try await session.buyProduct(identifier: "com.idevnva.iwallet.spendingreports", options: [])
        app.launchArguments = ["-AppleLanguages", "(ru)", "-AppleLocale", "ru_RU"]
        app.launch()
        let overview = app.tabBars.buttons["Обзор"]
        XCTAssertTrue(overview.waitForExistence(timeout: 20))
        overview.tap()
        let reports = app.buttons["overviewSpendingReport"]
        for _ in 0..<7 where !reports.isHittable { app.swipeUp() }
        XCTAssertTrue(reports.isHittable)
        reports.tap()
        XCTAssertTrue(app.datePickers["reportStartDate"].waitForExistence(timeout: 15), app.debugDescription)
        XCTAssertTrue(app.navigationBars["Отчёт о расходах"].exists)
        XCTAssertFalse(app.buttons["buySpendingReports"].exists)
    }

    func testCancelledCheckoutAndEmptyRestoreLeaveReportsLocked() async throws {
        try await session.setSimulatedError(.generic(.userCancelled), forAPI: .purchase)
        openReports()
        let buy = app.buttons["buySpendingReports"]
        XCTAssertTrue(buy.waitForExistence(timeout: 20))
        buy.tap()
        let restore = app.buttons["restoreSpendingReports"]
        let enabled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == YES"), object: restore)
        await fulfillment(of: [enabled], timeout: 10)
        let message = app.staticTexts["reportPurchaseMessage"]
        XCTAssertFalse(message.exists)
        XCTAssertFalse(app.buttons["exportSpendingReportPDF"].exists)
        restore.tap()
        XCTAssertTrue(message.waitForExistence(timeout: 15), app.debugDescription)
        XCTAssertEqual(message.label, "No previous purchase was found.")
        XCTAssertTrue(session.allTransactions().isEmpty)
    }
}

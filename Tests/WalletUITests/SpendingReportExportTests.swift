import StoreKitTest
import XCTest

@MainActor
final class SpendingReportExportTests: XCTestCase {
    func testSaveReportToFiles() throws {
        continueAfterFailure = false
        // This test adds an expense and writes a real file on the simulated device.
        let device = ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] ?? ""
        try XCTSkipUnless(device.localizedCaseInsensitiveContains("QA"), "Run on a dedicated QA simulator.")

        let configuration = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "SpendingReports", withExtension: "storekit"))
        let session = try SKTestSession(contentsOf: configuration)
        session.resetToDefaultState()
        session.disableDialogs = true
        session.clearTransactions()
        let app = XCUIApplication()
        defer {
            app.terminate()
            session.clearTransactions()
            session.resetToDefaultState()
        }
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()

        let newExpense = app.buttons["quickAddExpense"]
        XCTAssertTrue(newExpense.waitForExistence(timeout: 20))
        newExpense.tap()
        let amount = app.textFields["transactionAmount"]
        XCTAssertTrue(amount.waitForExistence(timeout: 5))
        amount.tap()
        amount.typeText("42.75")
        app.buttons["Done"].firstMatch.tap()
        let category = app.buttons["transactionCategory"]
        reveal(category, in: app)
        category.tap()
        app.buttons["Food"].firstMatch.tap()
        app.buttons["saveTransaction"].tap()
        XCTAssertTrue(amount.waitForNonExistence(timeout: 10))

        app.tabBars.buttons["Settings"].tap()
        app.buttons["settingsSpendingReport"].tap()
        let purchase = app.buttons["buySpendingReports"]
        XCTAssertTrue(purchase.waitForExistence(timeout: 20))
        attach(app, "01-offer")
        app.buttons["openSampleSpendingReport"].tap()
        XCTAssertTrue(app.staticTexts["sampleReportNotice"].waitForExistence(timeout: 5))
        let savePDF = app.buttons["exportSpendingReportPDF"]
        XCTAssertFalse(savePDF.exists)
        XCTAssertFalse(app.datePickers["reportStartDate"].exists)
        attach(app, "02-sample")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        purchase.tap()
        XCTAssertTrue(app.datePickers["reportStartDate"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.datePickers["reportEndDate"].exists)
        let total = app.staticTexts["reportSelectedTotal"]
        XCTAssertTrue(total.exists)
        XCTAssertFalse(total.label.contains("$0.00"), total.label)
        attach(app, "03-live")
        reveal(savePDF, in: app)
        attach(app, "04-categories")
        savePDF.tap()

        let save = app.buttons["Save"].firstMatch
        XCTAssertTrue(save.waitForExistence(timeout: 45), app.debugDescription)
        attach(app, "05-files")
        save.tap()
        let keepBoth = app.buttons.matching(NSPredicate(format: "label IN %@", ["Keep Both", "Keep both"])).firstMatch
        if keepBoth.waitForExistence(timeout: 3) { keepBoth.tap() }
        XCTAssertTrue(save.waitForNonExistence(timeout: 15), app.debugDescription)
        XCTAssertTrue(savePDF.isHittable)
        XCTAssertFalse(app.alerts.firstMatch.exists)
    }

    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<8 where !element.isHittable { app.swipeUp() }
        XCTAssertTrue(element.isHittable, element.debugDescription)
    }

    private func attach(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

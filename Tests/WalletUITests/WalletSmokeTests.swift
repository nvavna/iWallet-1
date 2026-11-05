import XCTest

/// Run on a dedicated simulator. These tests create uniquely named records and
/// never reset, overwrite, or delete existing application data.
final class WalletSmokeTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
    }

    override func tearDownWithError() throws {
        if let app, app.state == .runningForeground {
            attachScreenshot("Final screen")
            app.terminate()
        }
        app = nil
    }

    func testExpenseCreateEditAndCategoryArchivePreservesHistory() throws {
        XCTAssertTrue(app.tabBars.buttons["Overview"].waitForExistence(timeout: 15), "Use a dedicated simulator without a pending legacy import.")
        attachScreenshot("Overview before recording")
        let suffix = String(UUID().uuidString.prefix(8))
        let categoryName = "AAA UI \(suffix)"
        let note = "Smoke expense \(suffix)"

        app.tabBars.buttons["Categories"].tap()
        app.navigationBars["Categories"].buttons["Add category"].tap()
        let name = app.textFields["categoryName"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText(categoryName)
        attachScreenshot("Create a category")
        app.buttons["saveCategory"].tap()
        let category = element(containing: categoryName)
        XCTAssertTrue(category.waitForExistence(timeout: 5))
        attachScreenshot("Categories with the new category")

        app.tabBars.buttons["Overview"].tap()
        app.buttons["New transaction"].tap()
        let amount = app.textFields["transactionAmount"]
        XCTAssertTrue(amount.waitForExistence(timeout: 5))
        amount.tap()
        amount.typeText("12.34")
        if app.buttons["Done"].firstMatch.isHittable { app.buttons["Done"].firstMatch.tap() }
        reveal(app.buttons["transactionCategory"])
        app.buttons["transactionCategory"].tap()
        app.buttons[categoryName].firstMatch.tap()
        let noteField = app.descendants(matching: .any).matching(identifier: "transactionNote").firstMatch
        reveal(noteField)
        noteField.tap()
        noteField.typeText(note)
        app.buttons["Done"].firstMatch.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 3), "Done must dismiss the note keyboard.")
        reveal(app.buttons["transactionCurrency"])
        app.buttons["transactionCurrency"].tap()
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "USD")).firstMatch.tap()
        attachScreenshot("Expense form with a decimal amount")
        app.buttons["saveTransaction"].tap()

        XCTAssertTrue(app.tabBars.buttons["Overview"].waitForExistence(timeout: 5))
        chooseOverviewUSD()
        let homeRow = element(containing: note, and: "$12.34")
        reveal(homeRow)
        XCTAssertTrue(homeRow.exists, "The new expense and its amount must appear on the overview.")
        attachScreenshot("Overview after recording an expense")

        app.tabBars.buttons["Transactions"].tap()
        findTransaction(note)
        let row = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", note)).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        XCTAssertTrue(amount.waitForExistence(timeout: 5))
        replaceText(in: amount, with: "23.45")
        attachScreenshot("Edit the expense")
        app.buttons["saveTransaction"].tap()
        XCTAssertTrue(element(containing: note, and: "$23.45").waitForExistence(timeout: 5))

        app.tabBars.buttons["Overview"].tap()
        let updatedHomeRow = element(containing: note, and: "$23.45")
        reveal(updatedHomeRow)
        XCTAssertTrue(updatedHomeRow.exists, "The overview must reflect the saved edit.")

        app.tabBars.buttons["Categories"].tap()
        let categoryRow = element(containing: categoryName)
        reveal(categoryRow)
        categoryRow.swipeLeft()
        app.buttons["Archive"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Archive category?"].waitForExistence(timeout: 5))
        app.buttons["Archive category"].firstMatch.tap()
        XCTAssertTrue(categoryRow.waitForNonExistence(timeout: 5))
        attachScreenshot("Category archived")

        app.tabBars.buttons["Transactions"].tap()
        findTransaction(note)
        let preserved = element(containing: note, and: "$23.45")
        XCTAssertTrue(preserved.waitForExistence(timeout: 5), "Archiving must preserve the financial history.")
        app.terminate()
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Transactions"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Transactions"].tap()
        findTransaction(note)
        XCTAssertTrue(element(containing: note, and: "$23.45").waitForExistence(timeout: 5), "Saved changes must survive relaunch.")
        attachScreenshot("History after archiving and relaunch")
    }

    /// The host supplies the synthetic old-engine fixture in Documents/default.realm
    /// before launch. A normal clean-install run intentionally skips this method.
    func testLegacyMigrationReviewAndTransfer() throws {
        guard app.navigationBars["Your history"].waitForExistence(timeout: 8) else {
            throw XCTSkip("No legacy fixture was supplied. Run this method separately after installing the synthetic legacy database.")
        }
        attachScreenshot("Previous wallet detected")
        app.buttons["migrationCurrency"].tap()
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "USD")).firstMatch.tap()
        app.buttons["reviewLegacyHistory"].tap()
        let count = app.descendants(matching: .any).matching(identifier: "migrationTransactionCount").firstMatch
        XCTAssertTrue(count.waitForExistence(timeout: 20))
        let categoryCount = app.descendants(matching: .any).matching(identifier: "migrationCategoryCount").firstMatch
        XCTAssertEqual(categoryCount.value as? String, "2")
        XCTAssertEqual(count.value as? String, "4")
        let transfer = app.buttons["transferLegacyHistory"]
        attachScreenshot("Legacy counts and amount review")
        reveal(transfer)
        XCTAssertFalse(transfer.isEnabled, "Rounding must be reviewed before importing this fixture.")
        let rounding = app.switches["I have reviewed the rounding changes"]
        reveal(rounding)
        XCTAssertEqual(rounding.value as? String, "0")
        // SwiftUI exposes the entire labeled row as a switch. Tap its trailing
        // control, because the label's center is not the toggle hit target.
        rounding.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
        XCTAssertEqual(rounding.value as? String, "1")
        reveal(transfer)
        XCTAssertTrue(transfer.isEnabled)
        transfer.tap()
        XCTAssertTrue(app.tabBars.buttons["Overview"].waitForExistence(timeout: 15))
        attachScreenshot("Overview after transferring previous history")
        app.terminate()
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Overview"].waitForExistence(timeout: 15))
        XCTAssertFalse(app.navigationBars["Your history"].exists, "The persisted receipt must prevent a second import.")
    }

    private func element(containing text: String, and other: String? = nil) -> XCUIElement {
        let predicate = other.map { NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", text, $0) }
            ?? NSPredicate(format: "label CONTAINS %@", text)
        return app.descendants(matching: .any).matching(predicate).firstMatch
    }

    private func reveal(_ element: XCUIElement) {
        for _ in 0..<7 {
            if element.exists && element.isHittable { return }
            app.swipeUp()
        }
        XCTAssertTrue(element.exists && element.isHittable, "Expected control was not reachable: \(element)")
    }

    private func findTransaction(_ note: String) {
        let search = app.searchFields.firstMatch
        if !search.exists { app.swipeDown() }
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        if search.value as? String != note {
            search.tap()
            let clear = search.buttons["Clear text"]
            if clear.exists { clear.tap() }
            search.typeText(note)
            XCTAssertEqual(search.value as? String, note)
        }
    }

    private func chooseOverviewUSD() {
        app.buttons["Display currency"].tap()
        app.buttons["USD"].firstMatch.tap()
    }

    private func replaceText(in element: XCUIElement, with text: String) {
        element.tap()
        let oldValue = element.value as? String ?? ""
        element.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: oldValue.count) + text)
    }

    private func attachScreenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

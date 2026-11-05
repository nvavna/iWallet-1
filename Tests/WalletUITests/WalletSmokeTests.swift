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
        XCTAssertTrue(home.waitForExistence(timeout: 15), "Use a dedicated simulator without a pending legacy import.")
        attachScreenshot("Overview before recording")
        let suffix = String(UUID().uuidString.prefix(8))
        let categoryName = "AAA UI \(suffix)"
        let note = "Smoke expense \(suffix)"

        openCategories()
        app.navigationBars["Categories"].buttons["Add category"].tap()
        let name = app.textFields["categoryName"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText(categoryName)
        attachScreenshot("Create a category")
        app.buttons["saveCategory"].tap()
        let category = categoryElement(containing: categoryName)
        XCTAssertTrue(category.waitForExistence(timeout: 5))
        attachScreenshot("Categories with the new category")

        goHome()
        app.buttons["New transaction"].tap()
        let amount = app.textFields["transactionAmount"]
        XCTAssertTrue(amount.waitForExistence(timeout: 5))
        amount.tap()
        amount.typeText("12.34")
        if app.buttons["Done"].firstMatch.isHittable { app.buttons["Done"].firstMatch.tap() }
        chooseTransactionUSD()
        reveal(app.buttons["transactionCategory"])
        app.buttons["transactionCategory"].tap()
        app.buttons[categoryName].firstMatch.tap()
        let noteField = app.descendants(matching: .any).matching(identifier: "transactionNote").firstMatch
        reveal(noteField)
        noteField.tap()
        noteField.typeText(note)
        app.buttons["Done"].firstMatch.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 3), "Done must dismiss the note keyboard.")
        attachScreenshot("Expense form with a decimal amount")
        app.buttons["saveTransaction"].tap()

        XCTAssertTrue(home.waitForExistence(timeout: 5))
        chooseOverviewUSD()
        let homeRow = element(containing: categoryName, and: "$12.34")
        reveal(homeRow)
        XCTAssertTrue(homeRow.exists, "The category's expense total must appear on the overview.")
        attachScreenshot("Overview after recording an expense")

        homeRow.tap()
        let categoryHistory = app.navigationBars[categoryName]
        XCTAssertTrue(categoryHistory.waitForExistence(timeout: 5))
        XCTAssertTrue(element(containing: note, and: "$12.34").waitForExistence(timeout: 5))
        attachScreenshot("History for the selected category")
        // Category history is pushed on the home's NavigationStack, so return
        // through its native leading Back button rather than dismissing a sheet.
        categoryHistory.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(categoryHistory.waitForNonExistence(timeout: 5))
        XCTAssertTrue(home.waitForExistence(timeout: 5))

        openHistory()
        findTransaction(note)
        let row = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", note)).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        XCTAssertTrue(amount.waitForExistence(timeout: 5))
        replaceText(in: amount, with: "23.45")
        attachScreenshot("Edit the expense")
        app.buttons["saveTransaction"].tap()
        XCTAssertTrue(element(containing: note, and: "$23.45").waitForExistence(timeout: 5))

        goHome()
        let updatedHomeRow = element(containing: categoryName, and: "$23.45")
        reveal(updatedHomeRow)
        XCTAssertTrue(updatedHomeRow.exists, "The overview must reflect the saved edit.")

        openCategories()
        let categoryRow = categoryElement(containing: categoryName)
        reveal(categoryRow)
        categoryRow.swipeLeft()
        app.buttons["Archive"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Archive category?"].waitForExistence(timeout: 5))
        app.buttons["Archive category"].firstMatch.tap()
        XCTAssertTrue(categoryRow.waitForNonExistence(timeout: 5))
        attachScreenshot("Category archived")

        openHistory()
        findTransaction(note)
        let preserved = element(containing: note, and: "$23.45")
        XCTAssertTrue(preserved.waitForExistence(timeout: 5), "Archiving must preserve the financial history.")
        app.terminate()
        app.launch()
        XCTAssertTrue(home.waitForExistence(timeout: 10))
        openHistory()
        findTransaction(note)
        XCTAssertTrue(element(containing: note, and: "$23.45").waitForExistence(timeout: 5), "Saved changes must survive relaunch.")
        attachScreenshot("History after archiving and relaunch")
    }

    func testTransactionDraftCancelKeepsInputUntilExplicitDiscard() throws {
        XCTAssertTrue(home.waitForExistence(timeout: 15), "Use a dedicated simulator without a pending legacy import.")
        let suffix = String(UUID().uuidString.prefix(8))
        let categoryName = "AAA Draft \(suffix)"
        let note = "Unsaved draft \(suffix)"

        openCategories()
        app.navigationBars["Categories"].buttons["Add category"].tap()
        let name = app.textFields["categoryName"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText(categoryName)
        app.buttons["saveCategory"].tap()
        XCTAssertTrue(categoryElement(containing: categoryName).waitForExistence(timeout: 5))

        goHome()
        app.buttons["New transaction"].tap()
        let amount = app.textFields["transactionAmount"]
        XCTAssertTrue(amount.waitForExistence(timeout: 5))
        amount.tap()
        amount.typeText("19.75")
        app.buttons["Done"].firstMatch.tap()
        chooseTransactionUSD()
        reveal(app.buttons["transactionCategory"])
        app.buttons["transactionCategory"].tap()
        app.buttons[categoryName].firstMatch.tap()
        let noteField = app.descendants(matching: .any).matching(identifier: "transactionNote").firstMatch
        reveal(noteField)
        noteField.tap()
        noteField.typeText(note)
        app.buttons["Done"].firstMatch.tap()
        XCTAssertTrue(app.buttons["saveTransaction"].isEnabled, "This must be a valid, unsaved transaction draft.")

        // A category editor is pushed within the transaction sheet. Canceling
        // that clean child editor must return to the unchanged parent draft.
        revealAbove(app.buttons["New category"])
        app.buttons["New category"].tap()
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        app.navigationBars["New category"].buttons["Cancel"].tap()
        XCTAssertTrue(name.waitForNonExistence(timeout: 5))
        assertDraft(amount: amount, noteField: noteField, note: note)

        app.navigationBars["New transaction"].buttons["Cancel"].tap()
        XCTAssertTrue(app.staticTexts["Discard changes?"].waitForExistence(timeout: 5))
        keepEditingDraft()
        assertDraft(amount: amount, noteField: noteField, note: note)
        attachScreenshot("Transaction draft preserved after keeping changes")

        app.navigationBars["New transaction"].buttons["Cancel"].tap()
        XCTAssertTrue(app.staticTexts["Discard changes?"].waitForExistence(timeout: 5))
        app.buttons["Discard changes"].tap()
        XCTAssertTrue(amount.waitForNonExistence(timeout: 5))
        XCTAssertTrue(home.waitForExistence(timeout: 5))

        // Relaunch checks that dismissal did not persist the valid draft.
        app.terminate()
        app.launch()
        XCTAssertTrue(home.waitForExistence(timeout: 10))
        openHistory()
        findTransaction(note)
        let emptyState = app.staticTexts.matching(NSPredicate(
            format: "label IN %@", ["No matching transactions", "Your story starts here"] as NSArray
        )).firstMatch
        XCTAssertTrue(emptyState.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", note)).firstMatch.exists,
                       "Explicitly discarding a draft must not save a transaction.")
        attachScreenshot("Discarded draft absent after relaunch")
    }

    func testRecurringPaymentRecordsOnlyConfirmedOccurrencesAndPreservesHistory() throws {
        XCTAssertTrue(home.waitForExistence(timeout: 15), "Use a dedicated simulator without a pending legacy import.")
        let suffix = String(UUID().uuidString.prefix(8))
        let categoryName = "AAA Recurring \(suffix)"
        let paymentName = "UI subscription \(suffix)"

        openCategories()
        app.navigationBars["Categories"].buttons["Add category"].tap()
        let categoryNameField = app.textFields["categoryName"]
        XCTAssertTrue(categoryNameField.waitForExistence(timeout: 5))
        categoryNameField.tap()
        categoryNameField.typeText(categoryName)
        app.buttons["saveCategory"].tap()
        XCTAssertTrue(categoryElement(containing: categoryName).waitForExistence(timeout: 5))
        let initialBalance = try overviewUSDBalance()

        openPayments()
        app.buttons["newRecurringPayment"].tap()
        let name = app.textFields["paymentName"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText(paymentName)
        app.buttons["Done"].firstMatch.tap()
        let subscription = app.switches["paymentSubscription"]
        reveal(subscription)
        subscription.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
        XCTAssertEqual(subscription.value as? String, "1")
        let amount = app.textFields["paymentAmount"]
        reveal(amount)
        amount.tap()
        amount.typeText("12.34")
        app.buttons["Done"].firstMatch.tap()
        reveal(app.buttons["paymentCurrency"])
        app.buttons["paymentCurrency"].tap()
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "USD")).firstMatch.tap()
        reveal(app.buttons["paymentCategory"])
        app.buttons["paymentCategory"].tap()
        app.buttons[categoryName].firstMatch.tap()
        reveal(app.buttons["paymentCadence"])
        app.buttons["paymentCadence"].tap()
        app.buttons["Weekly"].firstMatch.tap()
        attachScreenshot("Recurring payment draft")
        app.buttons["saveRecurringPayment"].tap()
        waitForPaymentsRoot()
        XCTAssertTrue(name.waitForNonExistence(timeout: 5))
        XCTAssertEqual(try overviewUSDBalance(), initialBalance, "Creating a plan must not change the ledger balance.")
        assertNoTransaction(named: paymentName)

        openPayment(named: paymentName)
        let originalDue = try recurringDueDate()
        reveal(app.buttons["markRecurringPaid"])
        app.buttons["markRecurringPaid"].tap()
        // Native iOS 27 confirmation popovers expose a nested button with the
        // same identifier. Select the first node of that one visible action.
        let paidConfirmation = app.buttons["confirmRecurringPaid"].firstMatch
        XCTAssertTrue(paidConfirmation.waitForExistence(timeout: 5))
        attachScreenshot("Confirm one recurring expense")
        paidConfirmation.tap()
        waitForPaymentsRoot()
        openPayment(named: paymentName)
        let paidDue = try recurringDueDate()
        XCTAssertGreaterThan(paidDue, originalDue, "Recording a payment must advance the due date.")
        let paidBalance = initialBalance.subtracting(NSDecimalNumber(string: "12.34"))
        XCTAssertEqual(try overviewUSDBalance(), paidBalance)
        assertSingleTransaction(named: paymentName, amount: "$12.34")

        openPayment(named: paymentName)
        reveal(app.buttons["skipRecurringPayment"])
        app.buttons["skipRecurringPayment"].tap()
        let skipConfirmation = app.buttons["confirmRecurringSkip"].firstMatch
        XCTAssertTrue(skipConfirmation.waitForExistence(timeout: 5))
        skipConfirmation.tap()
        waitForPaymentsRoot()
        openPayment(named: paymentName)
        let skippedDue = try recurringDueDate()
        XCTAssertGreaterThan(skippedDue, paidDue, "Skipping must advance the due date without recording a transaction.")
        XCTAssertEqual(try overviewUSDBalance(), paidBalance)
        assertSingleTransaction(named: paymentName, amount: "$12.34")

        openPayment(named: paymentName)
        reveal(app.buttons["pauseRecurringPayment"])
        app.buttons["pauseRecurringPayment"].tap()
        waitForPaymentsRoot()
        XCTAssertTrue(app.staticTexts["Paused"].exists)
        openPayment(named: paymentName)
        XCTAssertFalse(app.buttons["markRecurringPaid"].exists, "A paused plan must not offer payment recording.")
        XCTAssertEqual(try recurringDueDate(), skippedDue)
        reveal(app.buttons["resumeRecurringPayment"])
        app.buttons["resumeRecurringPayment"].tap()
        waitForPaymentsRoot()
        openPayment(named: paymentName)
        XCTAssertEqual(try recurringDueDate(), skippedDue, "Pause/resume must not silently reschedule a payment.")
        reveal(app.buttons["markRecurringPaid"])
        XCTAssertTrue(app.buttons["markRecurringPaid"].isEnabled)

        reveal(app.buttons["deleteRecurringPayment"])
        app.buttons["deleteRecurringPayment"].tap()
        let deleteConfirmation = app.buttons["confirmRecurringDelete"].firstMatch
        XCTAssertTrue(deleteConfirmation.waitForExistence(timeout: 5))
        deleteConfirmation.tap()
        waitForPaymentsRoot()
        XCTAssertTrue(paymentRow(named: paymentName).waitForNonExistence(timeout: 5))
        XCTAssertEqual(try overviewUSDBalance(), paidBalance)
        assertSingleTransaction(named: paymentName, amount: "$12.34")

        app.terminate()
        app.launch()
        XCTAssertTrue(home.waitForExistence(timeout: 15))
        XCTAssertEqual(try overviewUSDBalance(), paidBalance)
        openPayments()
        XCTAssertFalse(paymentRow(named: paymentName).exists, "A deleted plan must remain deleted after relaunch.")
        assertSingleTransaction(named: paymentName, amount: "$12.34")
        attachScreenshot("Recorded expense preserved after plan deletion and relaunch")
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
        XCTAssertTrue(home.waitForExistence(timeout: 15))
        attachScreenshot("Overview after transferring previous history")
        app.terminate()
        app.launch()
        XCTAssertTrue(home.waitForExistence(timeout: 15))
        XCTAssertFalse(app.navigationBars["Your history"].exists, "The persisted receipt must prevent a second import.")
    }

    private var home: XCUIElement { app.scrollViews["walletHome"] }

    private func goHome() {
        selectTab("Overview")
        XCTAssertTrue(home.waitForExistence(timeout: 5))
        scrollHomeToTop()
    }

    private func openCategories() {
        selectTab("Settings")
        // Each tab retains its navigation path when another tab is selected.
        if app.navigationBars["Categories"].exists { return }
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        app.buttons["settingsCategories"].tap()
        XCTAssertTrue(app.navigationBars["Categories"].waitForExistence(timeout: 5))
    }

    private func openHistory() {
        selectTab("Transactions")
        XCTAssertTrue(app.navigationBars["Transactions"].waitForExistence(timeout: 5))
    }

    private var paymentsList: XCUIElement {
        app.descendants(matching: .any).matching(identifier: "recurringPaymentsList").firstMatch
    }

    private func openPayments() {
        selectTab("Payments")
        if app.navigationBars["Payment"].exists {
            app.navigationBars["Payment"].buttons.element(boundBy: 0).tap()
        }
        XCTAssertTrue(paymentsList.waitForExistence(timeout: 5))
    }

    private func waitForPaymentsRoot() {
        // Successful isolated writes recreate the container and navigation
        // stack. Query the new root instead of reusing the old detail element.
        XCTAssertTrue(app.navigationBars["Payment"].waitForNonExistence(timeout: 10))
        XCTAssertTrue(app.navigationBars["Payments"].waitForExistence(timeout: 10))
        XCTAssertTrue(paymentsList.waitForExistence(timeout: 10))
        XCTAssertTrue(app.tabBars.buttons["Payments"].isSelected)
    }

    private func paymentRow(named name: String) -> XCUIElement {
        paymentsList.buttons.matching(NSPredicate(format: "label CONTAINS %@", name)).firstMatch
    }

    private func openPayment(named name: String) {
        openPayments()
        let row = paymentRow(named: name)
        reveal(row)
        row.tap()
        XCTAssertTrue(app.navigationBars["Payment"].waitForExistence(timeout: 5))
    }

    private func recurringDueDate() throws -> Date {
        let row = app.descendants(matching: .any).matching(identifier: "recurringNextPayment").firstMatch
        reveal(row)
        let value = try XCTUnwrap(row.value as? String, "The due date must expose its full accessible value.")
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = .current
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return try XCTUnwrap(formatter.date(from: value), "Unable to parse visible due date: \(value)")
    }

    private func overviewUSDBalance() throws -> NSDecimalNumber {
        goHome()
        chooseOverviewUSD()
        let balance = app.descendants(matching: .any).matching(identifier: "overviewBalance").firstMatch
        XCTAssertTrue(balance.waitForExistence(timeout: 5))
        let value = try XCTUnwrap(balance.value as? String)
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.generatesDecimalNumbers = true
        let parsed = try XCTUnwrap(formatter.number(from: value), "Unable to parse visible balance: \(value)")
        return NSDecimalNumber(decimal: parsed.decimalValue)
    }

    private func assertNoTransaction(named name: String) {
        openHistory()
        findTransaction(name)
        let empty = app.staticTexts.matching(NSPredicate(format: "label IN %@",
            ["No matching transactions", "Your story starts here"] as NSArray)).firstMatch
        XCTAssertTrue(empty.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", name)).firstMatch.exists)
    }

    private func assertSingleTransaction(named name: String, amount: String) {
        openHistory()
        findTransaction(name)
        let rows = app.buttons.matching(NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", name, amount))
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 5))
        XCTAssertEqual(rows.count, 1, "Only one confirmed occurrence may be recorded; skip/delete/relaunch must not add another.")
    }

    private func selectTab(_ title: String) {
        dismissActiveHistorySearch()
        let tab = app.tabBars.buttons[title]
        XCTAssertTrue(tab.waitForExistence(timeout: 5) && tab.isHittable)
        tab.tap()
        XCTAssertTrue(tab.isSelected)
    }

    private func dismissActiveHistorySearch() {
        let search = app.searchFields.firstMatch
        guard search.exists && search.isHittable else { return }
        for label in ["close", "Cancel"] {
            let close = app.buttons[label].firstMatch
            if close.exists && close.isHittable {
                close.tap()
                return
            }
        }
        // Older accessibility trees expose the active bottom-search close
        // control by position. It is outside, and to the right of, the field.
        if !app.tabBars.buttons["Overview"].isHittable {
            let field = search.frame
            let close = app.buttons.allElementsBoundByIndex.first { button in
                button.isHittable && button.frame.minX >= field.maxX
                    && abs(button.frame.midY - field.midY) < field.height / 2
            }
            guard let close else {
                XCTFail("The active history search must expose its close control.")
                return
            }
            close.tap()
        }
    }

    private func scrollHomeToTop() {
        let currency = app.buttons["Display currency"]
        for _ in 0..<7 {
            if currency.exists && currency.isHittable { return }
            home.swipeDown()
        }
        XCTAssertTrue(currency.exists && currency.isHittable, "The top of the overview must be reachable.")
    }

    private func element(containing text: String, and other: String? = nil) -> XCUIElement {
        let predicate = other.map { NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", text, $0) }
            ?? NSPredicate(format: "label CONTAINS %@", text)
        return app.descendants(matching: .any).matching(predicate).firstMatch
    }

    private func categoryElement(containing text: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: "walletCategoryList").firstMatch
            .descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    }

    private func reveal(_ element: XCUIElement) {
        for _ in 0..<7 {
            if element.exists && element.isHittable { return }
            app.swipeUp()
        }
        XCTAssertTrue(element.exists && element.isHittable, "Expected control was not reachable: \(element)")
    }

    private func revealAbove(_ element: XCUIElement) {
        for _ in 0..<7 {
            if element.exists && element.isHittable { return }
            app.swipeDown()
        }
        XCTAssertTrue(element.exists && element.isHittable, "Expected control above was not reachable: \(element)")
    }

    private func assertDraft(amount: XCUIElement, noteField: XCUIElement, note: String) {
        revealAbove(amount)
        XCTAssertEqual(amount.value as? String, "19.75")
        reveal(noteField)
        XCTAssertEqual(noteField.value as? String, note)
        XCTAssertTrue(app.buttons["saveTransaction"].isEnabled)
    }

    private func keepEditingDraft() {
        let keepEditing = app.buttons["Keep editing"]
        if keepEditing.exists && keepEditing.isHittable {
            keepEditing.tap()
        } else {
            // iOS 27's native popover omits the cancel-role action. The recorded
            // failure exposes PopoverDismissRegion around it; this observed
            // point is below the toolbar, above Type, and outside the popover.
            let dismissRegion = app.otherElements["PopoverDismissRegion"]
            XCTAssertTrue(dismissRegion.waitForExistence(timeout: 5))
            dismissRegion.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.18)).tap()
        }
        XCTAssertTrue(app.staticTexts["Discard changes?"].waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.textFields["transactionAmount"].exists, "Keeping changes must leave the editor open.")
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
            // The native search field can report its first typed character
            // before its accessibility snapshot catches up with the screen.
            let enteredText = XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "value == %@", note), object: search)
            XCTAssertEqual(XCTWaiter.wait(for: [enteredText], timeout: 5), .completed,
                           "Search must contain the entire requested note before checking results.")
        }
    }

    private func chooseOverviewUSD() {
        scrollHomeToTop()
        app.buttons["Display currency"].tap()
        app.buttons["USD"].firstMatch.tap()
    }

    private func chooseTransactionUSD() {
        reveal(app.buttons["transactionCurrency"])
        app.buttons["transactionCurrency"].tap()
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "USD")).firstMatch.tap()
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

/// Opt-in App Store captures seed newly created simulators through normal forms.
/// The separate visual QA method reuses a seeded simulator without adding data.
final class WalletAppStoreScreenshotTests: XCTestCase {
    func testCaptureRussian() throws { try capture(language: "ru", seedWallet: true, attachmentPrefix: "AppStore") }
    func testCaptureEnglish() throws { try capture(language: "en", seedWallet: true, attachmentPrefix: "AppStore") }
    func testRefreshRussian() throws { try capture(language: "ru", seedWallet: false, attachmentPrefix: "AppStore") }
    func testRefreshEnglish() throws { try capture(language: "en", seedWallet: false, attachmentPrefix: "AppStore") }

    /// The host configures dark appearance or Dynamic Type on an already seeded
    /// dedicated simulator. This opt-in pass does not add or edit wallet records.
    func testCaptureRussianVisualQA() throws {
        try capture(language: "ru", seedWallet: false, attachmentPrefix: "QA")
    }

    private func capture(language: String, seedWallet: Bool, attachmentPrefix: String) throws {
        guard ProcessInfo.processInfo.environment["IWALLET_CAPTURE_APP_STORE"] == "1" else {
            throw XCTSkip("Opt-in screenshots: use Scripts/capture-app-store-screenshots.py on fresh simulators, or explicitly enable visual QA on a seeded dedicated simulator.")
        }
        continueAfterFailure = false
        let russian = language == "ru"
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(\(language))", "-AppleLocale", russian ? "ru_RU" : "en_US"]
        app.launch()
        defer { app.terminate() }
        let overview = russian ? "Обзор" : "Overview"
        let transactions = russian ? "Операции" : "Transactions"
        let add = russian ? "Новая операция" : "New transaction"
        let done = russian ? "Готово" : "Done"
        let currencyCode = russian ? "RUB" : "USD"
        let home = app.scrollViews["walletHome"]
        XCTAssertTrue(home.waitForExistence(timeout: 15))

        selectTab(app, title: transactions)
        XCTAssertTrue(app.navigationBars[transactions].waitForExistence(timeout: 5))
        let emptyWallet = app.staticTexts[russian ? "Пока нет операций" : "Your story starts here"]
        if seedWallet {
            // Refuse a populated wallet: seeding must never modify personal data.
            XCTAssertTrue(app.buttons[russian ? "Добавить операцию" : "Add transaction"].exists)
            XCTAssertTrue(emptyWallet.exists, "Create a fresh dedicated simulator before capturing screenshots.")
            selectTab(app, title: russian ? "Платежи" : "Payments")
            XCTAssertTrue(app.staticTexts[russian ? "Пока нет платежей" : "No payments yet"].waitForExistence(timeout: 5),
                          "Fresh capture must not add demo plans to an existing wallet.")
        } else {
            XCTAssertFalse(emptyWallet.exists, "Read-only capture requires the already seeded dedicated screenshot simulator.")
        }
        selectTab(app, title: overview)
        XCTAssertTrue(home.waitForExistence(timeout: 5))

        let rows: [(Bool, String, String, String)] = russian ? [
            (true, "Зарплата", "185000", "Зарплата за месяц"),
            (true, "Подработка", "12000", "Дизайн-проект"),
            (false, "Дом", "6890", "Коммунальные услуги"),
            (false, "Продукты", "4286", "Продукты на неделю"),
            (false, "Транспорт", "650", "Поездки по городу"),
            (false, "Еда вне дома", "2450", "Ужин с друзьями"),
            (false, "Развлечения", "1250", "Вечер в кино")
        ] : [
            (true, "Wage", "4800", "Monthly salary"),
            (true, "Part time job", "350", "Design project"),
            (false, "House", "148", "Monthly utilities"),
            (false, "Food", "86.40", "Weekly groceries"),
            (false, "Transport", "24.50", "Trips around town"),
            (false, "Eating out", "38.90", "Dinner with friends"),
            (false, "Entertainment", "25.90", "Movie night")
        ]
        if seedWallet {
            for (income, category, amount, note) in rows {
                app.buttons[add].tap()
                let amountField = app.textFields["transactionAmount"]
                XCTAssertTrue(amountField.waitForExistence(timeout: 5))
                if income { app.segmentedControls["transactionType"].buttons[russian ? "Доход" : "Income"].tap() }
                amountField.tap()
                amountField.typeText(amount)
                app.buttons[done].firstMatch.tap()
                reveal(app.buttons["transactionCurrency"], in: app)
                app.buttons["transactionCurrency"].tap()
                app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", currencyCode)).firstMatch.tap()
                reveal(app.buttons["transactionCategory"], in: app)
                app.buttons["transactionCategory"].tap()
                app.buttons[category].firstMatch.tap()
                let noteField = app.descendants(matching: .any).matching(identifier: "transactionNote").firstMatch
                reveal(noteField, in: app)
                noteField.tap()
                noteField.typeText(note)
                app.buttons[done].firstMatch.tap()
                app.buttons["saveTransaction"].tap()
                XCTAssertTrue(amountField.waitForNonExistence(timeout: 5))
                XCTAssertTrue(home.waitForExistence(timeout: 5))
            }
            seedPayments(app, language: language)
        }

        // All modes capture the same nine resting screens. Only the fresh
        // mode seeds plans; refresh/QA change no stored data or editor fields.
        app.terminate()
        app.launch()
        XCTAssertTrue(home.waitForExistence(timeout: 10))
        captureScreens(app, language: language, prefix: "\(attachmentPrefix)-\(language)")
    }

    private func captureScreens(_ app: XCUIApplication, language: String, prefix: String) {
        let russian = language == "ru"
        let overview = russian ? "Обзор" : "Overview"
        let transactions = russian ? "Операции" : "Transactions"
        let categories = russian ? "Категории" : "Categories"
        let settings = russian ? "Настройки" : "Settings"
        let payments = russian ? "Платежи" : "Payments"
        let newTransaction = russian ? "Новая операция" : "New transaction"
        let newCategory = russian ? "Новая категория" : "New category"
        let cancel = russian ? "Отмена" : "Cancel"
        let home = app.scrollViews["walletHome"]

        selectTab(app, title: overview)
        XCTAssertTrue(home.waitForExistence(timeout: 5))
        screenshot(app, name: "\(prefix)-01-overview")

        selectTab(app, title: transactions)
        XCTAssertTrue(app.navigationBars[transactions].waitForExistence(timeout: 5))
        screenshot(app, name: "\(prefix)-02-transactions")

        openCategories(app, settings: settings, categories: categories)
        screenshot(app, name: "\(prefix)-03-categories")

        selectTab(app, title: overview)
        app.buttons[newTransaction].tap()
        let amount = app.textFields["transactionAmount"]
        XCTAssertTrue(amount.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["saveTransaction"].isEnabled)
        screenshot(app, name: "\(prefix)-04-new-transaction")
        app.navigationBars[newTransaction].buttons[cancel].tap()
        XCTAssertTrue(amount.waitForNonExistence(timeout: 5))

        openCategories(app, settings: settings, categories: categories)
        app.navigationBars[categories].buttons[russian ? "Добавить категорию" : "Add category"].tap()
        let categoryName = app.textFields["categoryName"]
        XCTAssertTrue(categoryName.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["saveCategory"].isEnabled)
        screenshot(app, name: "\(prefix)-05-new-category")
        app.navigationBars[newCategory].buttons[cancel].tap()
        XCTAssertTrue(categoryName.waitForNonExistence(timeout: 5))

        XCTAssertTrue(app.navigationBars[categories].waitForExistence(timeout: 5))
        app.navigationBars[categories].buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.navigationBars[settings].waitForExistence(timeout: 5))
        screenshot(app, name: "\(prefix)-06-settings")

        selectTab(app, title: payments)
        XCTAssertTrue(app.navigationBars[payments].waitForExistence(timeout: 5))
        screenshot(app, name: "\(prefix)-07-payments")

        selectTab(app, title: overview)
        XCTAssertTrue(home.waitForExistence(timeout: 5))
        scrollToChart(app, identifier: "timelineChartCard")
        screenshot(app, name: "\(prefix)-08-analytics")
        scrollToChart(app, identifier: "categoryChartCard")
        screenshot(app, name: "\(prefix)-09-category-chart")
    }

    private func seedPayments(_ app: XCUIApplication, language: String) {
        let russian = language == "ru"
        let payments = russian ? "Платежи" : "Payments"
        let done = russian ? "Готово" : "Done"
        let currency = russian ? "RUB" : "USD"
        let rows: [(String, String, String)] = russian ? [
            ("Музыка", "399", "Развлечения"),
            ("Облачное хранилище", "149", "Дом")
        ] : [
            ("Music", "10.99", "Entertainment"),
            ("Cloud storage", "2.99", "House")
        ]
        selectTab(app, title: payments)
        for (name, amount, category) in rows {
            app.buttons["newRecurringPayment"].tap()
            let nameField = app.textFields["paymentName"]
            XCTAssertTrue(nameField.waitForExistence(timeout: 5))
            nameField.tap()
            nameField.typeText(name)
            app.buttons[done].firstMatch.tap()
            let subscription = app.switches["paymentSubscription"]
            reveal(subscription, in: app)
            subscription.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
            XCTAssertEqual(subscription.value as? String, "1")
            let amountField = app.textFields["paymentAmount"]
            reveal(amountField, in: app)
            amountField.tap()
            amountField.typeText(amount)
            app.buttons[done].firstMatch.tap()
            reveal(app.buttons["paymentCurrency"], in: app)
            app.buttons["paymentCurrency"].tap()
            app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", currency)).firstMatch.tap()
            reveal(app.buttons["paymentCategory"], in: app)
            app.buttons["paymentCategory"].tap()
            app.buttons[category].firstMatch.tap()
            app.buttons["saveRecurringPayment"].tap()
            XCTAssertTrue(nameField.waitForNonExistence(timeout: 10))
            XCTAssertTrue(app.navigationBars[payments].waitForExistence(timeout: 10))
            XCTAssertTrue(app.tabBars.buttons[payments].isSelected, "Saving a plan must preserve the selected tab.")
        }
    }

    private func scrollToChart(_ app: XCUIApplication, identifier: String) {
        let charts = app.descendants(matching: .any).matching(identifier: identifier)
        let navigation = app.navigationBars.firstMatch
        let top = navigation.frame.maxY + 12
        let bottom = app.tabBars.firstMatch.frame.minY - 12
        let viewportHeight = bottom - top
        let allowsOversizedCard = ProcessInfo.processInfo.environment["IWALLET_QA_SCROLL"] == "1"
        func cardFrame() -> CGRect? {
            let frames = charts.allElementsBoundByIndex.map(\.frame).filter {
                !$0.isEmpty && !$0.isNull && !$0.isInfinite &&
                $0.minX.isFinite && $0.minY.isFinite && $0.maxX.isFinite && $0.maxY.isFinite
            }
            guard let first = frames.first else { return nil }
            return frames.dropFirst().reduce(first) { $0.union($1) }
        }
        let geometry = XCTAttachment(string: charts.debugDescription)
        geometry.name = "Chart accessibility geometry \(identifier)"
        geometry.lifetime = .keepAlways
        add(geometry)
        func isReady(_ frame: CGRect?) -> Bool {
            guard let frame else { return false }
            if frame.height <= viewportHeight {
                return frame.minY >= top && frame.maxY <= bottom
            }
            // Accessibility QA captures the top, then additional lower pages.
            // Normal App Store captures must contain the entire card.
            return allowsOversizedCard && frame.minY >= top && frame.minY <= top + 60
        }
        for _ in 0..<10 {
            let frame = cardFrame()
            if isReady(frame) { return }
            let targetTop = frame.map { top + max(0, (viewportHeight - $0.height) / 2) } ?? top
            let distance = frame.map { $0.minY - targetTop } ?? 250
            // A short flick coasted past the target on iOS 27, oscillating
            // above and below it. Approach with a damped, held drag instead.
            let shift = min(max(distance * 0.5, -200), 200)
            // Drag along the scroll view's margin rather than across the
            // interactive chart, preserving its unselected resting state.
            let origin = app.coordinate(withNormalizedOffset: .zero)
            let startY = (top + bottom) / 2
            origin.withOffset(CGVector(dx: 8, dy: startY)).press(forDuration: 0.1,
                thenDragTo: origin.withOffset(CGVector(dx: 8, dy: startY - shift)),
                withVelocity: .slow, thenHoldForDuration: 0.2)
        }
        XCTAssertTrue(isReady(cardFrame()),
                      "The real chart card \(identifier) must fit between navigation and tabs before capturing it. Frame: \(String(describing: cardFrame())), viewport: \(top)...\(bottom).")
    }

    private func selectTab(_ app: XCUIApplication, title: String) {
        let tab = app.tabBars.buttons[title]
        XCTAssertTrue(tab.waitForExistence(timeout: 5) && tab.isHittable)
        tab.tap()
        XCTAssertTrue(tab.isSelected)
    }

    private func openCategories(_ app: XCUIApplication, settings: String, categories: String) {
        selectTab(app, title: settings)
        if app.navigationBars[categories].exists { return }
        XCTAssertTrue(app.navigationBars[settings].waitForExistence(timeout: 5))
        app.buttons["settingsCategories"].tap()
        XCTAssertTrue(app.navigationBars[categories].waitForExistence(timeout: 5))
    }

    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<7 {
            if element.exists && element.isHittable { return }
            app.swipeUp()
        }
        XCTAssertTrue(element.exists && element.isHittable, "Expected control was not reachable: \(element)")
    }

    private func screenshot(_ app: XCUIApplication, name: String) {
        captureAttachment(app, name: name)
        if name.hasPrefix("QA-"), ProcessInfo.processInfo.environment["IWALLET_QA_SCROLL"] == "1" {
            for page in 1...2 {
                app.swipeUp()
                captureAttachment(app, name: "\(name)-lower-\(page)")
            }
            if name.hasSuffix("-02-transactions") {
                let lastTransaction = app.buttons.matching(NSPredicate(
                    format: "label CONTAINS %@ OR label CONTAINS %@", "Зарплата за месяц", "Monthly salary"))
                captureBottom(app, matching: lastTransaction, name: "\(name)-bottom")
            } else if name.hasSuffix("-06-settings") {
                let storage = app.staticTexts.matching(NSPredicate(
                    format: "label CONTAINS %@ OR label CONTAINS %@ OR label IN %@ OR value IN %@",
                    "Хранение", "Storage",
                    ["На этом устройстве", "On this device"] as NSArray,
                    ["На этом устройстве", "On this device"] as NSArray))
                captureBottom(app, matching: storage, name: "\(name)-bottom")
            }
        }
    }

    private func captureBottom(_ app: XCUIApplication, matching elements: XCUIElementQuery, name: String) {
        func targetFrame() -> CGRect? {
            let frames = elements.allElementsBoundByIndex.map(\.frame).filter {
                !$0.isEmpty && !$0.isNull && !$0.isInfinite && $0.minY.isFinite && $0.maxY.isFinite
            }
            guard let first = frames.first else { return nil }
            return frames.dropFirst().reduce(first) { $0.union($1) }
        }
        func visibleRange() -> ClosedRange<CGFloat> {
            var top = app.navigationBars.firstMatch.frame.maxY + 12
            let search = app.searchFields.firstMatch
            if search.exists && search.isHittable { top = max(top, search.frame.maxY + 12) }
            return top...(app.tabBars.firstMatch.frame.minY - 12)
        }
        func isVisible(_ frame: CGRect?, in range: ClosedRange<CGFloat>) -> Bool {
            guard let frame else { return false }
            return frame.minY >= range.lowerBound && frame.maxY <= range.upperBound
        }
        for _ in 0..<10 {
            let frame = targetFrame()
            let range = visibleRange()
            if isVisible(frame, in: range) {
                captureAttachment(app, name: name)
                return
            }
            let middle = (range.lowerBound + range.upperBound) / 2
            let distance = frame.map { $0.midY - middle } ?? 400
            let shift = min(max(distance * 0.5, -200), 200)
            let origin = app.coordinate(withNormalizedOffset: .zero)
            origin.withOffset(CGVector(dx: 8, dy: middle)).press(forDuration: 0.1,
                thenDragTo: origin.withOffset(CGVector(dx: 8, dy: middle - shift)),
                withVelocity: .slow, thenHoldForDuration: 0.2)
        }
        captureAttachment(app, name: name)
        XCTAssertTrue(isVisible(targetFrame(), in: visibleRange()),
                      "The last seeded row must be entirely visible above the tab bar. \(elements.debugDescription)")
    }

    private func captureAttachment(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

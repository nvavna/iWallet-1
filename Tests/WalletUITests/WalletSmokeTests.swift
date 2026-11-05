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
        let search = app.searchFields.firstMatch
        let historyDone = app.navigationBars["Transactions"].buttons["Done"]
        if search.exists && search.isHittable && !(historyDone.exists && historyDone.isHittable) {
            let cancelSearch = app.buttons["Cancel"].firstMatch
            if cancelSearch.exists && cancelSearch.isHittable {
                cancelSearch.tap()
            } else {
                // iOS 27's active bottom search hides the navigation bar. The
                // observed close control is a separate button to the right of
                // the search field, unlike Clear text inside that field.
                let field = search.frame
                let closeSearch = app.buttons.allElementsBoundByIndex.first { button in
                    button.isHittable && button.frame.minX >= field.maxX
                        && abs(button.frame.midY - field.midY) < field.height / 2
                }
                guard let closeSearch else {
                    XCTFail("The active history search must expose its close control.")
                    return
                }
                closeSearch.tap()
            }
            XCTAssertTrue(historyDone.waitForExistence(timeout: 5), "Closing search must restore the history's Done button.")
        }
        // Categories is presented over Settings; history may be presented over
        // either Home or Settings. Dismiss the top sheet before its presenter.
        for title in ["Categories", "Transactions", "Settings"] {
            let navigation = app.navigationBars[title]
            let done = navigation.buttons["Done"]
            if done.exists && done.isHittable {
                done.tap()
                XCTAssertTrue(navigation.waitForNonExistence(timeout: 5))
            }
        }
        XCTAssertTrue(home.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Settings"].isHittable, "The home toolbar must be visible after dismissing its sheets.")
        scrollHomeToTop()
    }

    private func openCategories() {
        goHome()
        let settings = app.buttons["Settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 5))
        settings.tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        app.buttons["settingsCategories"].tap()
        XCTAssertTrue(app.navigationBars["Categories"].waitForExistence(timeout: 5))
    }

    private func openHistory() {
        goHome()
        let history = app.buttons["showTransactions"]
        reveal(history)
        history.tap()
        XCTAssertTrue(app.navigationBars["Transactions"].waitForExistence(timeout: 5))
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
        scrollHomeToTop()
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

/// Opt-in App Store captures on newly created simulators only. This workflow
/// enters synthetic records through the same forms used by customers.
final class WalletAppStoreScreenshotTests: XCTestCase {
    func testCaptureRussian() throws { try capture(language: "ru") }
    func testCaptureEnglish() throws { try capture(language: "en") }

    private func capture(language: String) throws {
        guard ProcessInfo.processInfo.environment["IWALLET_CAPTURE_APP_STORE"] == "1" else {
            throw XCTSkip("Opt-in screenshots: use Scripts/capture-app-store-screenshots.py on fresh simulators.")
        }
        continueAfterFailure = false
        let russian = language == "ru"
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(\(language))", "-AppleLocale", russian ? "ru_RU" : "en_US"]
        app.launch()
        defer { app.terminate() }
        let transactions = russian ? "Операции" : "Transactions"
        let categories = russian ? "Категории" : "Categories"
        let settings = russian ? "Настройки" : "Settings"
        let add = russian ? "Новая операция" : "New transaction"
        let done = russian ? "Готово" : "Done"
        let home = app.scrollViews["walletHome"]
        XCTAssertTrue(home.waitForExistence(timeout: 15))

        // Refuse a populated wallet: this workflow must never modify personal data.
        openHistory(app, title: transactions)
        XCTAssertTrue(app.buttons[russian ? "Добавить операцию" : "Add transaction"].exists)
        XCTAssertTrue(app.staticTexts[russian ? "Пока нет операций" : "Your story starts here"].exists,
                      "Create a fresh dedicated simulator before capturing screenshots.")
        app.navigationBars[transactions].buttons[done].tap()
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
        for (income, category, amount, note) in rows {
            app.buttons[add].tap()
            let amountField = app.textFields["transactionAmount"]
            XCTAssertTrue(amountField.waitForExistence(timeout: 5))
            if income { app.segmentedControls["transactionType"].buttons[russian ? "Доход" : "Income"].tap() }
            amountField.tap()
            amountField.typeText(amount)
            app.buttons[done].firstMatch.tap()
            app.buttons["transactionCategory"].tap()
            app.buttons[category].firstMatch.tap()
            let noteField = app.textFields["transactionNote"]
            noteField.tap()
            noteField.typeText(note)
            app.buttons[done].firstMatch.tap()
            app.buttons["saveTransaction"].tap()
            XCTAssertTrue(home.waitForExistence(timeout: 5))
        }

        // Relaunch to capture the normal resting overview, with no keyboard/menu.
        app.terminate()
        app.launch()
        XCTAssertTrue(home.waitForExistence(timeout: 10))
        screenshot(app, name: "AppStore-\(language)-01-overview")
        openHistory(app, title: transactions)
        screenshot(app, name: "AppStore-\(language)-02-transactions")
        app.navigationBars[transactions].buttons[done].tap()
        XCTAssertTrue(home.waitForExistence(timeout: 5))
        app.buttons[settings].tap()
        XCTAssertTrue(app.navigationBars[settings].waitForExistence(timeout: 5))
        app.buttons["settingsCategories"].tap()
        XCTAssertTrue(app.navigationBars[categories].waitForExistence(timeout: 5))
        screenshot(app, name: "AppStore-\(language)-03-categories")
    }

    private func openHistory(_ app: XCUIApplication, title: String) {
        let history = app.buttons["showTransactions"]
        for _ in 0..<7 {
            if history.exists && history.isHittable { break }
            app.scrollViews["walletHome"].swipeUp()
        }
        XCTAssertTrue(history.exists && history.isHittable)
        history.tap()
        XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 5))
    }

    private func screenshot(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

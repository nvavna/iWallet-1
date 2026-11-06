import XCTest

/// Opt-in previews for the dedicated Russian Build 5 screenshot wallet.
final class PlanningPreviewTests: XCTestCase {
    @MainActor
    func testCaptureRussianPlanningPreviews() throws {
        let environment = ProcessInfo.processInfo.environment
        guard environment["IWALLET_BUILD6_PREVIEWS"] == "1" else {
            throw XCTSkip("Set IWALLET_BUILD6_PREVIEWS=1 in the dedicated screenshot runner.")
        }
        #if targetEnvironment(simulator)
        guard let expected = environment["IWALLET_PREVIEW_DEVICE"].flatMap(UUID.init(uuidString:)),
              let actual = environment["SIMULATOR_UDID"].flatMap(UUID.init(uuidString:)),
              expected == actual else {
            throw failure("The runner's simulator must match the explicit IWALLET_PREVIEW_DEVICE.")
        }
        #else
        throw XCTSkip("Planning previews run only on a dedicated simulator.")
        #endif

        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(ru)", "-AppleLocale", "ru_RU"]
        app.launch()
        defer { app.terminate() }
        try verifyDemoWallet(app)
        try captureForecast(app)
        try captureBudget(app)
        try captureReminders(app)
    }

    @MainActor
    private func verifyDemoWallet(_ app: XCUIApplication) throws {
        try selectTab("Обзор", in: app)
        let balance = element("overviewBalance", in: app)
        try require(balance.waitForExistence(timeout: 8) && compact(contents(balance)).contains("181474,00"),
                    "The expected Russian demo balance is 181474.00 RUB.")
        try selectTab("Операции", in: app)
        let all = app.segmentedControls["transactionFilter"].buttons["Все"].firstMatch
        try tap(all)
        let expected = [
            ("Зарплата", "Зарплата за месяц", "185000,00"), ("Подработка", "Дизайн-проект", "12000,00"),
            ("Дом", "Коммунальные услуги", "6890,00"), ("Продукты", "Продукты на неделю", "4286,00"),
            ("Транспорт", "Поездки по городу", "650,00"), ("Еда вне дома", "Ужин с друзьями", "2450,00"),
            ("Развлечения", "Вечер в кино", "1250,00")
        ]
        // A second viewport includes the last salary row below the system tab bar.
        var ledger: Set<String> = []
        for pass in 0..<2 {
            ledger.formUnion(moneyRowLabels(app))
            if pass == 0 { app.swipeUp() }
        }
        try require(ledger.count == expected.count, "Expected exactly seven distinct demo transaction rows, found \(ledger.count).")
        for (category, note, amount) in expected {
            try require(ledger.contains { row in
                row.contains(category) && row.contains(note) && compact(row).contains(amount) && row.contains("RUB")
            }, "The named demo transaction is missing: \(note).")
        }

        try selectTab("Платежи", in: app)
        let plans = moneyRowLabels(app)
        try require(plans.count == 2, "Expected exactly two synthetic subscription plans.")
        for (name, amount) in [("Музыка", "399,00"), ("Облачное хранилище", "149,00")] {
            try require(plans.contains { row in
                row.contains(name) && compact(row).contains(amount) && row.contains("Подписка") && row.contains("RUB")
            }, "Missing expected demo subscription: \(name).")
        }
    }

    @MainActor
    private func captureForecast(_ app: XCUIApplication) throws {
        try selectTab("Обзор", in: app)
        try positionForecast(in: app)
        let horizon = app.segmentedControls["forecastHorizon"].firstMatch
        let thirty = horizon.buttons["30 дней"].firstMatch
        try tap(thirty)
        try require(thirty.isSelected, "The forecast must cover 30 days.")
        try positionForecast(in: app)
        let sum = element("forecastUpcomingTotal", in: app)
        try require(compact(contents(sum)).contains("548,00"),
                    "Expected the scheduled demonstration total of 548.00 RUB in the current preview window.")
        let overdue = element("forecastOverdueTotal", in: app)
        try require(compact(contents(overdue)).contains("548,00"), "Expected both open November demo payments.")
        attach(app, "Planning-ru-01-forecast")
    }

    @MainActor
    private func positionForecast(in app: XCUIApplication) throws {
        let navigationBottom = app.navigationBars.firstMatch.frame.maxY
        let tabTop = app.tabBars.firstMatch.frame.minY
        let height = tabTop - navigationBottom
        let top = navigationBottom + height * 0.02
        let bottom = tabTop - height * 0.02
        let margin = app.frame.width * 0.02
        let elements = app.descendants(matching: .any)
        for _ in 0..<15 {
            let heading = app.staticTexts["Ближайшие платежи"].firstMatch
            let picker = element("forecastHorizon", in: app)
            let total = element("forecastUpcomingTotal", in: app)
            let overdue = element("forecastOverdueTotal", in: app)
            let required = [heading, picker, total, overdue]
            let visible = required.allSatisfy { item in
                guard item.exists else { return false }
                let frame = item.frame
                return !frame.isEmpty && !frame.isNull && !frame.isInfinite && frame.minY >= top && frame.maxY <= bottom
            }
            if visible && heading.frame.midY <= top + height / 3 { return }
            let frames = elements.matching(identifier: "upcomingPayments").allElementsBoundByIndex.map(\.frame)
                .filter { !$0.isEmpty && !$0.isNull && !$0.isInfinite }
            let card = frames.reduce(CGRect.null) { $0.union($1) }
            let y = heading.exists ? heading.frame.minY : card.minY
            let desired = top + height * 0.09
            let step = height * 0.27
            let shift = y.isFinite ? min(step, max(-step, (y - desired) * 0.7)) : step
            let origin = app.coordinate(withNormalizedOffset: .zero)
            let mid = (top + bottom) * 0.5
            origin.withOffset(CGVector(dx: margin, dy: mid)).press(forDuration: 0.1,
                thenDragTo: origin.withOffset(CGVector(dx: margin, dy: mid - shift)),
                withVelocity: .slow, thenHoldForDuration: 0.2)
        }
        throw failure("Could not frame the heading in the upper third with both forecast amounts above the tabs.")
    }

    @MainActor
    private func captureBudget(_ app: XCUIApplication) throws {
        try selectTab("Настройки", in: app)
        try tap(app.buttons["settingsBudgets"].firstMatch)
        let month = element("budgetMonth", in: app)
        try require(month.waitForExistence(timeout: 5) && contents(month).lowercased().contains("ноябр")
                    && contents(month).contains("2026"), "The demo expenses belong to November 2026.")
        let rows = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "budgetRow-"))
        if rows.count == 0 {
            try require(app.staticTexts["В этом месяце бюджетов нет"].firstMatch.exists ||
                        app.staticTexts["Задайте лимит расходов для категории."].firstMatch.exists,
                        "Create a demo budget only when this month is verified empty.")
            try tap(app.buttons["newBudget"].firstMatch)
            try tap(app.buttons["budgetCategory"].firstMatch)
            try tap(app.buttons["Дом"].firstMatch)
            try tap(app.buttons["budgetCurrency"].firstMatch)
            try tap(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "RUB")).firstMatch)
            let amount = app.textFields["budgetAmount"].firstMatch
            try tap(amount)
            amount.typeText("12000")
            let done = app.buttons["Готово"].firstMatch
            if done.exists && done.isHittable { done.tap() }
            try tap(app.buttons["saveBudget"].firstMatch)
        }
        let row = rows.firstMatch
        try require(row.waitForExistence(timeout: 6) && rows.count == 1, "Expected exactly one demo budget.")
        let text = compact(contents(row))
        for value in ["Дом", "RUB", "12000,00", "6890,00", "5110,00"] {
            try require(text.contains(value), "The persisted demo budget must match category, limit, spent and remaining: \(value).")
        }
        attach(app, "Planning-ru-02-budget")
    }

    @MainActor
    private func captureReminders(_ app: XCUIApplication) throws {
        try selectTab("Платежи", in: app)
        try tap(app.buttons["paymentReminderSettings"].firstMatch)
        let toggle = app.switches["paymentRemindersEnabled"].firstMatch
        try require(toggle.waitForExistence(timeout: 5), "Reminder settings did not open.")
        guard let initial = toggle.value as? String, ["0", "1"].contains(initial) else {
            throw failure("The original reminder toggle state is unknown.")
        }
        let lead = app.buttons["paymentReminderLead"].firstMatch
        var restoreDueDay = false
        defer {
            // This runs before the outer defer terminates the app, including on thrown verification errors.
            if restoreDueDay && lead.exists && lead.isHittable {
                lead.tap()
                let due = app.buttons["В день платежа"].firstMatch
                if due.waitForExistence(timeout: 2) { due.tap() } else { XCTFail("Could not restore the original reminder lead.") }
                XCTAssertTrue(waitUntil { self.contents(lead).contains("В день платежа") })
            }
            if initial == "0" && toggle.exists && (toggle.value as? String) == "1" {
                toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
                XCTAssertTrue(waitUntil { (toggle.value as? String) == "0" }, "Restore reminders to the original off state.")
            }
        }
        if initial == "0" {
            try require(toggle.isEnabled, "Notification permission is denied on the dedicated demo simulator.")
            toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
            let system = XCUIApplication(bundleIdentifier: "com.apple.springboard")
            let alert = system.alerts.firstMatch
            if alert.waitForExistence(timeout: 3) {
                let title = ([alert.label] + alert.staticTexts.allElementsBoundByIndex.map(\.label)).joined(separator: " ").lowercased()
                try require(title.contains("iwallet") && (title.contains("уведомлен") || title.contains("notification")),
                            "Expected the iWallet notification permission alert.")
                let allowed = alert.buttons.matching(NSPredicate(format: "label IN %@", ["Разрешить", "Allow"])).firstMatch
                try tap(allowed)
            }
        }
        try require(lead.waitForExistence(timeout: 8) && (toggle.value as? String) == "1",
                    "The reminder schedule requires simulator notification permission.")
        let originalLead = contents(lead)
        try require(originalLead.contains("В день платежа") || originalLead.contains("Накануне"),
                    "The original reminder lead is unknown.")
        if originalLead.contains("В день платежа") {
            restoreDueDay = true
            try tap(lead)
            try tap(app.buttons["Накануне"].firstMatch)
        }
        try require(waitUntil { self.contents(lead).contains("Накануне") }, "Select the day before.")
        try require(element("paymentReminderTime", in: app).exists, "The real reminder time picker must be visible.")
        attach(app, "Planning-ru-03-reminders")
    }

    @MainActor
    private func moneyRowLabels(_ app: XCUIApplication) -> Set<String> {
        let rows = app.buttons.matching(NSPredicate(format: "label MATCHES %@", "(?s).*\\b[A-Z]{3}\\b.*"))
        return Set(rows.allElementsBoundByIndex.map(\.label))
    }

    @MainActor
    private func contents(_ element: XCUIElement) -> String {
        element.label + " " + (element.value as? String ?? "")
    }

    private func compact(_ text: String) -> String { text.filter { !$0.isWhitespace } }

    @MainActor
    private func selectTab(_ title: String, in app: XCUIApplication) throws {
        let tab = app.tabBars.buttons[title].firstMatch
        try tap(tab)
        try require(tab.isSelected, "Expected selected tab \(title).")
    }

    @MainActor
    private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    @MainActor
    private func tap(_ item: XCUIElement) throws {
        try require(item.waitForExistence(timeout: 5) && item.isHittable && item.isEnabled,
                    "Expected a reachable enabled control: \(item).")
        item.tap()
    }

    @MainActor
    private func waitUntil(_ condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(5)
        while Date() < deadline {
            if condition() { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.15))
        }
        return condition()
    }

    @MainActor
    private func attach(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func require(_ passed: Bool, _ message: String) throws {
        if !passed { throw failure(message) }
    }

    private func failure(_ message: String) -> NSError {
        NSError(domain: "PlanningPreviewTests", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }
}

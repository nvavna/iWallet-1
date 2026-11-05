# Тексты App Store для iWallet

> **Текущая локальная работа — build 5.** Четыре вкладки: Overview / Transactions / Payments / Settings; графики доходов, расходов и категорий; ручной учёт регулярных платежей и подписок; JSON-копии формата 2 с импортом совместимого формата 1. Описания, What’s New и единый Review Notes ниже подготовлены **только локально и не отправлены**. Проверены 96 unit-тестов, четыре UI-сценария, 18 RU/EN-снимков, Dark и максимальный AX. Подписанный build 5 загружен в Apple; завершение обработки ещё не подтверждено. В черновике магазина он не выбран.

**В App Store Connect по-прежнему выбран и сохранён build 2.** В черновике [2.0.0](https://appstoreconnect.apple.com/apps/6447585809/distribution/ios/version/inflight) сохранены его RU/EN-описания, What’s New, Review Notes и шесть снимков (по три на язык); миниатюры обработаны и проверены. Статус — «Подготовка к отправке», выпуск ручной. Версия не отправлена на App Review и не опубликована. Карточка `6447585809` восстановлена; Bundle ID `com.idevnva.iwallet`, SKU `001`, прежняя версия `1.1.8` (1). Баннер о снятии прежнего приложения с продажи сохраняется.

Build 2 прошёл 60 unit-тестов (44 WalletCore + 16 LegacyMigration), два UI-сценария без ошибок и пропусков, проверку подписанного архива/IPA и обработку Apple; доказательства перечислены в [APP-STORE-RELEASE.md](APP-STORE-RELEASE.md). Исторический build 1 также был загружен и обработан после повторной загрузки `e8c9f1ce-1906-4211-9860-f95247d7f8c3`; его 55 unit- и два UI-теста не подтверждают последующие изменения.

Build 4 завершил симуляторную проверку: `build/UITests-Design4-Smoke-Final.xcresult` — 2 PASS, `build/UITests-Design4-Migration.xcresult` — 1 PASS, без ошибок и пропусков. Сняты и просмотрены 12 RU/EN, 6 Dark и 18 AX-кадров; ограничения крупного текста и прежнее предупреждение Invalid frame при клавиатуре сохранены в QA-документах. Build 4 не подписывался и не загружался. Эти результаты относятся к предыдущему интерфейсу с тремя вкладками и не являются проверкой build 5. Физический iPhone, iOS 17 и полная матрица VoiceOver остаются открытыми проверками.

Названия, subtitle, promotional text и keywords ниже сохраняют прежний текст. Лимиты: название и subtitle — до 30 символов, promotional text — до 170, description — до 4000. Для keywords используется предел 100 байт UTF-8. [App information](https://developer.apple.com/help/app-store-connect/reference/app-information/app-information/), [Platform version information](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information/)

## Русский

| Поле | Текст |
| --- | --- |
| Название, основной вариант | iWallet: расходы и доходы |
| Название, альтернатива | iWallet: учёт денег |
| Subtitle | Личные финансы под контролем |
| Keywords | кошелёк,доходы,траты,баланс,категории,учёт |

### Promotional text — сохранённый текст

```text
Записывайте доходы и расходы, находите операции и следите за тратами по категориям. Понятный обзор, разные валюты и данные на вашем устройстве.
```

### Полное описание — локальная подготовка build 5, не отправлено

```text
iWallet помогает вести личные финансы: записывайте доходы и расходы, смотрите баланс, изучайте траты и планируйте регулярные платежи.

ОБЗОР И ГРАФИКИ
Баланс показывает всю историю выбранной валюты. Для доходов, расходов и графиков выберите месяц, квартал, год или всё время. По умолчанию открыт текущий месяц. Текущие календарные периоды включают данные до конца сегодняшнего дня; сравнение показывает соответствующую часть предыдущего периода с точными датами. Если прежняя сумма равна нулю, процентное изменение не рассчитывается.

Сравнивайте доходы и расходы на столбчатом графике и смотрите распределение по категориям на круговой диаграмме. Выбирайте элементы графиков или раскрывайте точные значения. Средний расход рассчитывается по календарным дням, в которые были расходы.

БЫСТРЫЙ УЧЁТ
Четыре вкладки — Обзор, Операции, Платежи и Настройки — разделяют сводку, историю и планы. Добавьте сумму, категорию, дату и заметку. Находите операции по заметке, категории или валюте, редактируйте и удаляйте записи. Из списка категорий в обзоре можно открыть всю историю выбранной категории в той же валюте.

РЕГУЛЯРНЫЕ ПЛАТЕЖИ И ПОДПИСКИ
Сохраните название, сумму, валюту, категорию, периодичность и следующую дату. Различайте предстоящие, просроченные и приостановленные планы. Действие «Отметить оплаченным» записывает один расход и переносит следующую дату на один период. Пропуск переносит дату без расхода. План можно приостановить или удалить, сохранив уже записанные операции. Деньги автоматически не списываются.

ВАШИ КАТЕГОРИИ И ВАЛЮТЫ
Создавайте категории с названиями, системными значками и цветами. Архивируйте ненужные категории, сохраняя операции. Суммы разных валют учитываются отдельно; изменение валюты не выполняет обмен по курсу.

ЛОКАЛЬНЫЕ ДАННЫЕ И КОПИИ
Категории, операции и планы платежей хранятся на устройстве. Для учёта не нужны регистрация или подключение банка. Приложение не содержит рекламы и аналитических сервисов.

Экспортируйте данные в JSON-файл и самостоятельно выбирайте, где его сохранить или кому передать. Импорт совместимой копии добавляет отсутствующие записи, пропускает идентичные и останавливается при конфликте. Поддерживаются совместимые копии предыдущего формата без планов платежей. Настройки приложения в копию не входят.

Интерфейс доступен на русском и английском языках. Требуется iOS 17 или новее.
```

### Что нового — локальная подготовка build 5, не отправлено

```text
iWallet получил обновлённый интерфейс и новое локальное хранилище.

• Четыре вкладки: Обзор, Операции, Платежи и Настройки.
• График доходов и расходов, диаграмма категорий и точные значения.
• Периоды месяц, квартал, год и всё время; сравнение с предыдущим периодом.
• Планы регулярных платежей и подписок: отметить оплаченным, пропустить или приостановить. Расход записывается только после вашего действия.
• Раздельный учёт валют, поиск и редактирование операций.
• Категории с системными значками и архивирование без потери истории.
• JSON-копии включают планы платежей; поддерживается импорт совместимых прежних копий.

Новая версия требует iOS 17 или новее.
```

## English

| Field | Text |
| --- | --- |
| Name, primary option | iWallet: Expense Tracker |
| Name, alternative | iWallet: Money Journal |
| Subtitle | Income, spending and clarity |
| Keywords | spending,income,money,ledger,categories,offline,currency,balance,export |

### Promotional text — saved text

```text
Keep track of income and expenses, find transactions, and see spending by category. A clear overview, multiple currencies, and data stored on your device.
```

### Full description — local build 5 preparation, not submitted

```text
iWallet helps you keep a clear record of your finances. Record income and expenses, check your balance, explore spending, and plan recurring payments.

OVERVIEW AND CHARTS
Your balance covers all recorded history in the selected currency. Choose month, quarter, year or all time for income, expenses and charts. The current month opens by default. Current calendar periods include data through today; comparisons show the corresponding part of the previous period with explicit dates. No percentage change is calculated when the previous amount is zero.

Compare income and expenses in a bar chart and explore a category donut chart. Select chart elements or expand their exact values. The expense average uses calendar days with spending.

QUICK ENTRY
Four tabs — Overview, Transactions, Payments and Settings — organize your summary, history and plans. Add an amount, category, date and note. Find transactions by note, category or currency, then edit or delete records. Open a category from Overview to see its full history in the same currency.

RECURRING PAYMENTS AND SUBSCRIPTIONS
Save a name, amount, currency, category, repeat schedule and next date. See upcoming, overdue and paused plans. Mark as paid records one expense and advances the next date by one period. Skip advances the date without recording an expense. Pause or delete a plan while keeping previously recorded transactions. The app does not charge you or move money automatically.

YOUR CATEGORIES AND CURRENCIES
Create categories with names, system symbols and colors. Archive categories while keeping their transactions. Different currencies have separate totals; changing a currency does not perform an exchange-rate conversion.

LOCAL DATA AND BACKUPS
Your categories, transactions and payment plans are stored on your device. No account or bank connection is needed. The app contains no advertising or analytics services.

Export your data as a JSON file and choose where to save it or who receives it. Import a compatible backup to add missing records and skip identical ones; a conflict stops the import. Compatible backups in the previous format, without payment plans, are supported. Backups do not include app preferences.

Available in English and Russian. Requires iOS 17 or later.
```

### What's New — local build 5 preparation, not submitted

```text
iWallet has a refreshed interface and new local storage.

• Four tabs: Overview, Transactions, Payments and Settings.
• Income and expense bars, a category donut chart, and exact values.
• Month, quarter, year and all-time periods, with previous-period comparisons.
• Recurring payment and subscription plans: mark as paid, skip or pause. An expense is recorded only after your action.
• Separate currency totals, transaction search and editing.
• Categories with system symbols and archiving that keeps your history.
• JSON backups now include payment plans and support importing compatible older backups.

This version requires iOS 17 or later.
```

## App Review Notes — единый локальный текст build 5, не отправлен

Это подготовленная замена; в App Store Connect пока сохранены Review Notes build 2. Перед заменой требуется завершить QA и подготовку build 5. Существующие review-контакты сохранены; личные контактные данные в документ не копируются.

```text
iWallet is a manual personal income and expense tracker. No sign-in is required. It does not connect to banks, provide banking services, move money or perform currency exchange. Totals are separate for each currency. Payment plans are user-entered records, not purchases or subscriptions sold by this app.

Clean-install review flow:
1. The four native tabs are Overview, Transactions, Payments and Settings. Overview defaults to the current month. Its balance always covers all recorded history in the selected currency. Choose month, quarter, year or all time for cash flow and charts. Current periods run through today; the previous comparison uses the same elapsed calendar-day count, clamped to the preceding period, with explicit dates. A zero previous amount has no percentage comparison. Expense average uses only calendar days with spending.
2. Select Expense or Income in Overview and tap the toolbar plus. Enter an amount, category, date and optional note, then Save. Select chart bars or category sectors to inspect values, or expand Values for exact amounts. A category's history opens in the selected currency across all dates. Transactions provides search, editing and deletion.
3. Open Payments and tap plus. Enter a name, amount, currency, active expense category, repeat schedule and next date; optionally label the plan Subscription. Save, open the plan and choose Mark as paid, then confirm. This creates one expense dated at confirmation preparation and advances the due date by one period. Skip advances the date without an expense. Pause suspends the plan; deleting a plan keeps recorded expenses. No automatic charges or reminder notifications are implemented.
4. Open Settings > Categories to create or archive a category. Archiving keeps recorded transactions. New categories can also be created within transaction or payment forms. Changed drafts require a discard decision when cancelled.
5. Settings > Export all data saves a JSON file using the system file exporter. Format 2 includes categories, transactions and recurring payment plans. Import a backup also accepts compatible format 1 files without plans. Missing records are added, identical ones skipped, and conflicts stop import without replacing current records. Preferences are not included.

Data is stored locally with SwiftData. There is no account system, advertising, analytics service or developer-operated data server. The user chooses where exported files are saved.

Upgrade migration:
This transitional release includes Realm Swift only to read supported legacy local wallet data (schema 15 from version 1.1.8). It does not use Atlas Device Sync. When supported previous data is detected, Your history asks the user to confirm the original currency, review counts and totals, and acknowledge any rounding changes. The original file and a snapshot are retained. Data and a migration receipt are saved together, preventing a repeat transfer after relaunch. Unsupported schemas or multiple old wallet files show an explanation instead of opening an empty wallet.

Prepared for version 2.0.0 (5), iOS 17 or later.
```

## Поля карточки и финальная сверка

| Поле | Подтверждённое состояние / оставшаяся сверка |
| --- | --- |
| Support URL | [Поддержка iWallet](https://github.com/nvavna/iWallet-1/blob/restoration/foundation/docs/SUPPORT.md) — опубликовано в `ffb019b`, HTTP 200 без авторизации проверен |
| Privacy Policy URL | [Политика iWallet](https://github.com/nvavna/iWallet-1/blob/restoration/foundation/docs/PRIVACY.md) — опубликовано в `ffb019b`, HTTP 200 без авторизации проверен |
| Support email | `idevnva@icloud.com` — одобрен пользователем |
| Marketing URL | Пусто для RU/EN, сохранение проверено. Прежний `https://idevnva.com/iwallet` недоступен: DNS resolution failure, HTTP 000 |
| Copyright | Сверить существующее значение карточки при финальном review; новый правообладатель не выдумывался |
| App Review contact | Существующие контакты сохранены; владелец может проверить актуальность перед финальной отправкой |
| Версия / build / выпуск | Черновик `2.0.0`, ручной выпуск. Build 2 обработан Apple, выбран и сохранён. Build 5 не загружен |
| Категория | Сверить с действующей карточкой при финальном review; изменение категории не заявлено |
| Возрастной рейтинг | `4+` рассчитан и сохранён после семишаговой анкеты для предыдущего состава функций; финальная сверка build 5 ещё впереди |
| App Privacy / DSA | Сохранены прежний Data Not Collected и явно выбранный пользователем non-trader; compliance Active |
| Соглашение | Free app agreement Active с 1 ноября 2026 по 8 марта 2027 |
| Тексты / Review Notes | В ASC — build 2. Тексты выше — локальная подготовка build 5, не отправлены |
| Скриншоты | В ASC — 3 RU + 3 EN build 2. Для build 5 сняты и проверены 9 на язык, включая Payments, timeline и category chart; оба capture PASS. Новые изображения ещё не загружены. [Сценарий](APPSTORE-SCREENSHOTS.md) |

Support/Privacy URL сохранены в обоих языках; необязательный Privacy Choices URL удалён. Проверка ссылок из финальной установленной сборки остаётся в плане. `ITSAppUsesNonExemptEncryption=false` ранее подтверждён в подписанных артефактах build 1/2; это не проверка будущего IPA build 5. Окончательное решение об отправке версии и правовые заявления проверяются при финальном review. Сохранённые поля не требуют повторного ввода без соответствующих изменений.

Не заявлять автоматические списания, напоминания, банковское подключение, синхронизацию, бюджеты/лимиты, Face ID, шифрование базы или поддержку всех старых баз, если проверенной функции нет в релизе. JSON-импорт не заменяет изменённые текущие записи и не восстанавливает настройки. Фразы о локальности и отсутствии сбора окончательно сверяются с [APP-STORE-RELEASE.md](APP-STORE-RELEASE.md) и фактическим Privacy Report.

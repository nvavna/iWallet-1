# Тексты App Store для iWallet

Материалы для версии **2.0.0 (6)** подготовлены локально. Ниже приведены описания и «Что нового» для двух языков, затем единый английский текст для App Review. Названия, подзаголовки, ключевые слова и рекламный текст сохранены из предыдущего комплекта.

Последняя зафиксированная сверка App Store Connect относится к 5 ноября 2026 года. Тогда в черновике 2.0.0 был выбран build 2 с его текстами и тремя снимками на язык, для выпуска был выбран ручной режим. 6 ноября Xcode подтвердил загрузку build 6 и начало обработки Apple. Фактическое состояние карточки, обработки и выбора сборки нужно сверить в App Store Connect при подготовке отправки build 6. [Карточка iWallet](https://appstoreconnect.apple.com/apps/6447585809/distribution/ios/version/inflight) · [Журнал подготовки выпуска](APP-STORE-RELEASE.md)

Apple допускает до 30 символов в названии и подзаголовке, 170 в рекламном тексте, 4000 в описании и 4000 в «Что нового». Для ключевых слов предел составляет 100 байт, для единых App Review Notes — 4000 байт. [App information](https://developer.apple.com/help/app-store-connect/reference/app-information/app-information/) · [Platform version information](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information/)

## Русский

| Поле | Текст |
| --- | --- |
| Название, основной вариант | iWallet: расходы и доходы |
| Название, альтернатива | iWallet: учёт денег |
| Subtitle | Личные финансы под контролем |
| Keywords | кошелёк,доходы,траты,баланс,категории,учёт |

### Рекламный текст

```text
Записывайте доходы и расходы, находите операции и следите за тратами по категориям. Понятный обзор, разные валюты и данные на вашем устройстве.
```

### Полное описание для сборки 6

```text
iWallet помогает понять, сколько денег осталось, на что они уходят и какие платежи предстоят. Записывайте доходы и расходы вручную. Кошелёк работает без регистрации и подключения к банку.

Баланс и история
В «Обзоре» выберите валюту, чтобы увидеть баланс за всё время. Сравните доходы и расходы за месяц, квартал или год, посмотрите распределение трат по категориям или раскройте точные суммы. В «Операциях» можно найти покупку по заметке, категории или валюте, исправить запись или удалить её. Создавайте свои категории и архивируйте ненужные с сохранением истории.

Бюджеты на месяц
Задайте лимит для категории расходов, календарного месяца и валюты. Например, выделите 20 000 ₽ на продукты в ноябре. После каждой записанной покупки iWallet показывает, сколько потрачено и сколько осталось. Если вы превысили лимит, увидите сумму превышения. Для следующего месяца можно задать другой лимит.

Платежи и подписки
Добавьте регулярный платёж, укажите его сумму, следующую дату и периодичность. В «Обзоре» доступен прогноз на 7 или 30 дней, включая сегодня. Он суммирует предстоящие даты активных планов в выбранной валюте. По каждому просроченному плану одна открытая дата показана отдельно. Когда вы подтверждаете оплату, iWallet записывает один расход и переносит дату на следующий период. Платёж можно пропустить или приостановить.

Напоминания
Во вкладке «Платежи» нажмите на колокольчик, чтобы включить напоминания на этом устройстве. Выберите время в день платежа или накануне. iWallet учитывает часовой пояс плана. На экране блокировки появится общее напоминание без названия и суммы. Нажмите на него, чтобы перейти во вкладку «Платежи».

Ваши данные
Категории, операции, планы и бюджеты хранятся на устройстве. Сохраните JSON-копию в выбранном месте. Новый формат 3 включает бюджеты, также можно импортировать совместимые копии форматов 1 и 2. Импорт добавляет недостающие записи и пропускает совпадающие. При конфликте данные кошелька сохраняются. Настройки напоминаний остаются на устройстве.

Интерфейс доступен на русском и английском. Требуется iOS 17 или новее.
```

### Что нового в версии 2.0.0

```text
В «Обзоре» появился прогноз регулярных платежей на 7 и 30 дней. В прогноз входят планы в выбранной валюте. Просроченные открытые платежи видны отдельно.

В «Бюджетах на месяц» можно установить лимит для категории и следить за остатком по записанным расходам. У каждого лимита свой месяц и валюта.

Во вкладке «Платежи» теперь можно включить локальные напоминания в день платежа или накануне. Вы выбираете время, название и сумма остаются скрытыми. Расход записывается при подтверждении оплаты.

JSON-копии формата 3 сохраняют бюджеты вместе с категориями, операциями и планами. Импорт принимает совместимые копии форматов 1 и 2.
```

## English

| Field | Text |
| --- | --- |
| Name, primary option | iWallet: Expense Tracker |
| Name, alternative | iWallet: Money Journal |
| Subtitle | Income, spending and clarity |
| Keywords | spending,income,money,ledger,categories,offline,currency,balance,export |

### Promotional text

```text
Keep track of income and expenses, find transactions, and see spending by category. A clear overview, multiple currencies, and data stored on your device.
```

### Full description for build 6

```text
iWallet helps you see what you have, where your money goes and which payments are coming up. Record income and expenses yourself. You can use your wallet without an account or a bank connection.

Balance and history
Choose a currency in Overview to see its balance across your recorded history. Compare income and expenses by month, quarter or year, explore spending by category, or expand the charts for exact amounts. Find a transaction by note, category or currency to edit or delete it. Create your own categories and archive the ones you no longer use while keeping their history.

Monthly budgets
Set a spending limit for an expense category, calendar month and currency. For example, set aside $300 for groceries in November. As you record purchases, iWallet shows what you spent and how much remains. If you go over budget, you can see the difference. Choose a different limit for the next month.

Payments and subscriptions
Give a recurring payment an amount, next due date and repeat schedule. Overview shows the next 7 or 30 days, including today. The forecast totals upcoming dates from active plans in the selected currency. Each overdue plan has one outstanding date listed separately. Confirm Mark as paid to record one expense and advance the due date by one period. You can also skip a payment or pause a plan.

Reminders
Tap the bell in Payments to turn on local reminders if you want them. Choose a time on the due date or the day before. Each reminder follows the payment's time zone. The Lock Screen shows a general message that keeps the name and amount private. Tap it to open Payments.

Your data
Your categories, transactions, payment plans and budgets stay on your device. Export a JSON backup to a location you choose. Format 3 includes budgets, and you can import compatible format 1 and 2 backups. Import adds missing records and skips identical ones. If records conflict, your existing wallet is preserved. Reminder preferences stay on the device.

Available in English and Russian. Requires iOS 17 or later.
```

### What's New in version 2.0.0

```text
Overview now shows recurring payments scheduled over the next 7 or 30 days. See the total in your selected currency and check outstanding overdue payments separately.

Set a monthly spending limit for an expense category and see how much remains as you record purchases. Each limit has its own month and currency.

Turn on local reminders in Payments to get an alert on the due date or the day before. Choose the time. Payment names and amounts stay private. Confirming payment records the expense.

Format 3 JSON backups include budgets alongside categories, transactions and payment plans. Compatible format 1 and 2 backups can still be imported.
```

## App Review Notes для версии 2.0.0 (6)

```text
iWallet 2.0.0 (6) is a manual personal finance tracker for iOS 17 and later. Review it on a clean install without signing in. Entries stay on the device. Payment plans describe the user's existing commitments. Recording an expense does not charge a bank account or purchase a subscription.

1. Overview and Transactions. Choose a currency in Overview. Add an income or expense with the plus button, choose a category and save. The balance covers all recorded history in that currency. The selected period controls the charts and period comparisons. Tap chart elements or expand Values for exact amounts. Search, edit or delete the entry in Transactions. Settings > Categories also lets you create and archive categories.

2. Payments and forecast. In Payments, tap plus and create a weekly plan in the same currency with its next date tomorrow. Overview > Upcoming payments lets you switch between 7 and 30 days and expand Scheduled dates. The window includes today in each plan's time zone. The scheduled total includes projected occurrences of active plans in that currency. To see the overdue section, set a plan's next date to last week. Each overdue plan contributes one outstanding occurrence separately. Open a plan and confirm Mark as paid to create one expense and advance one period. Skip advances one period without an expense. Pause excludes the plan from forecasts and reminders. Deleting a plan keeps recorded expenses.

3. Optional local notifications. Open the bell in Payments and turn on Payment reminders. Only this action requests iOS notification permission. After granting permission, choose the due date or the day before and the alert time. For a quick check, set a plan due today and choose a reminder time a few minutes ahead in its saved time zone. Scheduled alerts shows the queue count. A notification contains a general message without the payment name or amount. Tapping it opens Payments. A schedule change updates its reminder. The switch turns reminders off. If permission was denied, Open notification settings takes you to iOS Settings. The ledger works with reminders off.

4. Budgets. Open Settings > Monthly budgets, choose a month, tap plus and set a limit for an expense category and currency. Enter an expense using the same category, month and currency. The budget shows spending, the remaining amount or the amount over budget. A planned payment affects spending when it is recorded as an expense.

5. Backups. Settings > Export all data creates a format 3 JSON file with categories, transactions, recurring plans and budgets. Import a backup also accepts compatible format 1 files (categories and transactions) and format 2 files (also recurring plans). Missing records are added, identical records are skipped, and a conflict stops the import. Device preferences, including reminder choices, are excluded.

Upgrade from 1.1.8. On supported local Realm schema 15, Your history asks for the original currency and shows counts, totals and any rounding to review before transfer. The original file and a snapshot are retained. SwiftData saves the imported records and a receipt together to prevent duplicate transfer. Multiple or unsupported old files show an explanation. There is no bank connection, developer-operated data server, advertising or analytics service.
```

## Поля карточки для сверки

Значения ниже перенесены из последней записанной проверки. При подготовке отправки следует сверить их с карточкой App Store Connect.

| Поле | Зафиксированное значение |
| --- | --- |
| Карточка | Apple ID `6447585809`, Bundle ID `com.idevnva.iwallet`, SKU `001`, прежняя версия `1.1.8` (1) |
| Support URL | [Поддержка iWallet](https://github.com/nvavna/iWallet-1/blob/restoration/foundation/docs/SUPPORT.md) |
| Privacy Policy URL | [Политика iWallet](https://github.com/nvavna/iWallet-1/blob/restoration/foundation/docs/PRIVACY.md) |
| Support email | `idevnva@icloud.com` |
| Marketing URL | Поле было пустым в обеих локализациях |
| Copyright и категория | Сверить значения в существующей карточке |
| App Review contact | Использовать существующие контакты владельца из App Store Connect |
| Версия и выпуск | При последней сверке в черновике `2.0.0` был сохранён build 2, выпуск ручной |
| Возрастной рейтинг | Ранее рассчитан `4+` |
| App Privacy и DSA | Ранее сохранены Data Not Collected и выбранный владельцем статус non-trader |
| Соглашение | При последней сверке Free app agreement действовало с 1 ноября 2026 года по 8 марта 2027 года |
| Тексты и снимки | В черновике были материалы build 2, включая 3 RU и 3 EN снимка. Локальный комплект build 5 содержал 9 снимков на язык. [Подготовка снимков](APPSTORE-SCREENSHOTS.md) |

Перед отправкой сверить выбранную сборку, тексты, обязательные снимки, URL и декларацию App Privacy с фактическим содержимым релизного архива. [Журнал выпуска и проверок](APP-STORE-RELEASE.md)

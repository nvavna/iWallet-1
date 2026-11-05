# Тексты App Store для iWallet

**Состояние на 5 ноября 2026 года: в черновике App Store Connect сохранены обновлённые RU/EN-описания, What’s New и единый текст Review Notes для build 2. Загружены шесть новых снимков интерфейса; все миниатюры обработаны и визуально проверены.** Названия, subtitle, promotional text и keywords не меняются. Карточка приложения `6447585809` восстановлена. Подтверждены Bundle ID `com.idevnva.iwallet`, SKU `001` и прежняя версия `1.1.8`, build `1`. Новая версия не отправлена на App Review и не опубликована; альтернативные названия и дополнительный абзац миграции остаются вариантами этого документа.

В App Store Connect создан [черновик 2.0.0](https://appstoreconnect.apple.com/apps/6447585809/distribution/ios/version/inflight) со статусом «Подготовка к отправке». Выбран ручной выпуск; баннер о снятии прежнего приложения с продажи остаётся. **Build 1 подписан, экспортирован, загружен и обработан Apple**: повторная загрузка `e8c9f1ce-1906-4211-9860-f95247d7f8c3` — «Завершено», 2.0.0 (1) — «Готово к отправке» в TestFlight (`build/QA/testflight-build1-processed.jpg`). Ошибка входа Xcode устранена. У build 1 прошли 55 unit-тестов, 2 UI-теста и deep/strict codesign; RealmSwift, четыре privacy manifest и полный текст лицензий проверены. Эти результаты относятся к тестовому build 1, который после решения обновить дизайн не считается финальным кандидатом на выпуск.

Для текущего **build 2** прошли **60 тестов (44 WalletCore + 16 LegacyMigration)**, `/tmp/iwallet-build2-core-tests.log`; сборка UI-тестов для симулятора завершилась **TEST BUILD SUCCEEDED**, `/tmp/iwallet-build2-simulator-final.log`. Оба UI-сценария build 2 прошли без ошибок и пропусков. Шесть новых RU/EN-снимков, подписанный архив и экспортированный IPA проверены; upload и обработка Apple завершены. Build 2 выбран в черновике App Store. Это не результат App Review или физической проверки на iPhone.

Семь шагов возрастной анкеты пройдены по фактическим функциям и содержимому: рейтинг **4+** рассчитан и сохранён. Прежний **Data Not Collected** оставлен без изменений. Пользователь явно выбрал DSA non-trader, настройка сохранена; compliance показывает Active. Соглашение для бесплатных приложений Active с 1 ноября 2026 по 8 марта 2027. RU dark, EN light и RU large text прошли визуальную проверку в build 1; новый интерфейс build 2, физический iPhone, iOS 17 и полная матрица VoiceOver ещё требуют проверки.

Лимиты: название и subtitle — до 30 символов, promotional text — до 170, description — до 4000. Для keywords использован более строгий предел **100 байт UTF-8** из справочника App Store Connect; он также укладывается в 100 символов. [App information](https://developer.apple.com/help/app-store-connect/reference/app-information/app-information/), [Platform version information](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information/)

## Русский

| Поле | Текст | Длина |
| --- | --- | --- |
| Название, основной вариант | iWallet: расходы и доходы | 25 / 30 |
| Название, альтернатива | iWallet: учёт денег | 19 / 30 |
| Subtitle | Личные финансы под контролем | 28 / 30 |
| Keywords | кошелёк,доходы,траты,баланс,категории,учёт | 42 символа, 79 байт / 100 |

### Promotional text — 143 / 170

```text
Записывайте доходы и расходы, находите операции и следите за тратами по категориям. Понятный обзор, разные валюты и данные на вашем устройстве.
```

### Полное описание — сохранено для build 2

```text
iWallet помогает вести личные финансы: записывайте доходы и расходы, смотрите баланс и разбирайтесь, на что уходят деньги.

ПОНЯТНЫЙ ОБЗОР
Четыре карточки показывают баланс, средний расход, доходы и расходы. Баланс включает всю историю выбранной валюты. Для остальных итогов выберите текущий месяц или всё время; по умолчанию открывается вся история. Средний расход рассчитывается по календарным дням, в которые были расходы в выбранном периоде.

БЫСТРЫЙ УЧЁТ
Нажмите «+» на главном экране: выбранные тип операции и валюта уже подставлены. Добавьте сумму, категорию, дату и заметку. История доступна с главного экрана и из настроек: исправляйте операции и находите записи по заметке, категории или валюте.

ВАШИ КАТЕГОРИИ
Переключайтесь между доходами и расходами и открывайте историю категории прямо из списка на главном экране. Она сохраняет выбранную валюту. В настройках создавайте категории с удобными названиями, значками и цветами. Архивируйте ненужные категории, сохраняя связанные операции в истории.

РАЗНЫЕ ВАЛЮТЫ
Выбирайте валюту для каждой операции и смотрите отдельные итоги. Суммы разных валют не смешиваются; изменение валюты не выполняет обмен по курсу.

ЛОКАЛЬНЫЕ ДАННЫЕ
Категории и операции хранятся на устройстве. Для учёта не нужны регистрация или подключение банковского счёта. Приложение не содержит рекламы и аналитических сервисов.

КОПИИ ИСТОРИИ
Сохраните категории и операции в JSON-файл через системное меню экспорта. Вы сами выбираете, где хранить файл и кому его передавать. Импорт совместимого файла добавит отсутствующие записи, пропустит идентичные и остановится при конфликте с текущими данными.

Интерфейс доступен на русском и английском языках. Требуется iOS 17 или новее.
```

### Что нового — сохранено для build 2

```text
iWallet получил обновлённый интерфейс и новое локальное хранилище.

• Четыре карточки: баланс, средний расход, доходы и расходы.
• Средний расход за день с тратами, меню периода и валюты.
• Полные списки категорий доходов и расходов с переходом в их историю.
• Плавающий «+» и навигация через главный экран и настройки.
• Раздельный учёт операций в разных валютах.
• Поиск по истории и удобное редактирование записей.
• Архивирование категорий с сохранением операций.
• Экспорт категорий и операций в JSON и импорт совместимых копий с проверкой конфликтов.

Новая версия требует iOS 17 или новее.
```

Дополнительный абзац миграции ниже не входит в подготовленный базовый What’s New и не сохранён в карточке. Импортёр и synthetic fixture настоящего формата Realm 2023 года проверены; полный UI-сценарий повторно прошёл для build 2 без ошибок и пропусков. Обновление на физическом устройстве ещё ожидается:

```text
При обновлении приложение предложит перенести поддерживаемые данные предыдущей версии в новое локальное хранилище. Перед переносом подтвердите прежнюю валюту и проверьте изменения округления, если они потребуются.
```

## English

| Field | Text | Length |
| --- | --- | --- |
| Name, primary option | iWallet: Expense Tracker | 24 / 30 |
| Name, alternative | iWallet: Money Journal | 22 / 30 |
| Subtitle | Income, spending and clarity | 28 / 30 |
| Keywords | spending,income,money,ledger,categories,offline,currency,balance,export | 71 characters/bytes / 100 |

### Promotional text — 154 / 170

```text
Keep track of income and expenses, find transactions, and see spending by category. A clear overview, multiple currencies, and data stored on your device.
```

### Full description — saved for build 2

```text
iWallet helps you keep a clear record of your everyday finances. Add income and expenses, check your balance, and understand where your money goes.

A CLEAR OVERVIEW
Four cards show your balance, expense average, income and expenses. The balance covers all history in the selected currency. Choose this month or all time for the other totals; all time is the default. The expense average uses only calendar days with spending in the selected period.

QUICK ENTRY
Tap the floating plus button on the main screen to start with your selected transaction type and currency. Add an amount, category, date and note. Open history from the main screen or Settings to edit transactions and find records by note, category or currency.

YOUR OWN CATEGORIES
Switch between income and expenses, then open a category's history directly from the main screen. It keeps your selected currency. Create categories with names, icons and colors in Settings. Archive categories you no longer need while keeping their transactions in your history.

MULTIPLE CURRENCIES
Choose a currency for each transaction and view separate totals. Different currencies are kept separate. Changing a currency does not perform an exchange-rate conversion.

LOCAL DATA
Your categories and transactions are stored on your device. No account or bank connection is needed to keep your records. The app contains no advertising or analytics services.

HISTORY BACKUPS
Save your categories and transactions as a JSON file using the system export interface. You choose where the file is saved and who receives it. Import a compatible file to add missing records, skip identical records, and stop if the file conflicts with your current data.

Available in English and Russian. Requires iOS 17 or later.
```

### What's New — saved for build 2

```text
iWallet has a refreshed interface and new local storage.

• Four cards for balance, expense average, income and expenses.
• Average expense per day with spending, plus period and currency menus.
• Complete income and expense category lists that open their history.
• A floating plus button and navigation through the main screen and Settings.
• Separate transaction totals for different currencies.
• History search and easier transaction editing.
• Category archiving that keeps your transactions.
• JSON export and import of compatible backups with conflict checks.

This version requires iOS 17 or later.
```

The optional migration paragraph below is separate from the prepared base What's New and has not been saved in the store draft. The importer and a synthetic database in the actual 2023 Realm format passed validation; the simulator UI flow passed again for build 2 without failures or skips. A physical-device upgrade test is pending:

```text
When updating, the app offers to transfer supported data from the previous version into its new local storage. Confirm the original currency and review any rounding changes before transferring your history.
```

## App Review Notes — сохранённый единый текст для build 2

Ниже единственный текст для новой навигации build 2. Он сохранён в App Store Connect и повторно прочитан после переключения языка на русский. Существующие review-контакты карточки сохранены; личные контактные данные в этот документ не включены.

```text
iWallet is a manual personal income and expense tracker. No sign-in is required. It does not connect to banks, provide banking services, move money, or perform currency exchange. Totals are separate for each currency.

Clean-install review flow:
1. On the main iWallet screen, use the currency and period menus. All time is selected initially. The four cards show balance, expense average, income and expenses. Balance always covers all history in the selected currency. The other cards use the selected period; the expense average divides expenses by the number of calendar days with spending.
2. Select Expense or Income, then tap the floating plus button. The editor starts with that type and currency. Enter an amount, category, date and optional note, then save.
3. Tap a category on the main screen to open its history in the same currency. This history includes all dates. Adding from an active category's history preselects that category; archived category history has no add button.
4. Open Transactions from the main screen or Settings to search, edit or delete records. Open Settings > Categories to create or archive a category. Archiving retains its transactions. The full Transactions and Categories sheets both have a Done button. There is no tab bar.
5. In Settings, choose Export all data to save a JSON file using the system file exporter. Choose Import a backup to review and restore a compatible file. Missing records are added, identical records are skipped, and conflicts stop the import without replacing existing data.

Data is stored locally with SwiftData. The app has no account system, advertising, analytics service or developer-operated data server. The user chooses where exported files are saved. JSON backups contain categories and transactions, but not app preferences.

Upgrade migration:
This transitional release includes Realm Swift only to read legacy local wallet data (schema 15 from version 1.1.8). No Atlas Device Sync or cloud migration is used. When a supported previous wallet is detected, the Your history screen asks the user to confirm the original currency, review record counts and totals, and acknowledge any rounding changes before transferring the history. The original file and a snapshot are retained. Data and a migration receipt are saved together, so the transfer does not repeat after relaunch. Unsupported schemas or multiple old wallet files show an explanation instead of opening an empty wallet.

Prepared for version 2.0.0 (2), iOS 17 or later.
```

## Поля карточки и финальная сверка

| Поле | Подтверждённое состояние / оставшаяся сверка |
| --- | --- |
| Support URL | [Поддержка iWallet](https://github.com/nvavna/iWallet-1/blob/restoration/foundation/docs/SUPPORT.md) — опубликовано в `ffb019b`, HTTP 200 без авторизации проверен |
| Privacy Policy URL | [Политика iWallet](https://github.com/nvavna/iWallet-1/blob/restoration/foundation/docs/PRIVACY.md) — опубликовано в `ffb019b`, HTTP 200 без авторизации проверен |
| Support email | `idevnva@icloud.com` — одобрен пользователем |
| Marketing URL | Необязательное поле пусто; сохранение и пустое значение подтверждены для RU/EN. Прежний `https://idevnva.com/iwallet` недоступен: curl (6), DNS resolution failure, HTTP 000 |
| Copyright | Сверить существующее значение карточки при финальном review; новый правообладатель не выдумывался |
| App Review contact | Существующие контакты сохранены; владелец может проверить актуальность перед финальной отправкой |
| Версия / build / выпуск | Черновик `2.0.0`, ручной выпуск. Build 2 обработан Apple, TestFlight «Готово к отправке», выбран и сохранён в черновике |
| Категория | Сверить с действующей карточкой при финальном review; изменение категории не заявлено |
| Возрастной рейтинг | `4+` рассчитан и сохранён после актуальной семишаговой анкеты |
| App Privacy / DSA | Прежний Data Not Collected сохранён; non-trader явно выбран пользователем и сохранён, compliance Active |
| Тексты / Review Notes | Новые RU/EN-описания, What’s New и единый Review Notes build 2 сохранены в карточке |
| Скриншоты | В карточку загружены по 3 снимка RU/EN build 2 (обзор, история, категории), 1206×2622 RGB PNG; все миниатюры обработаны и проверены. [Воспроизведение](APPSTORE-SCREENSHOTS.md) |

Документы политики и поддержки опубликованы в `ffb019b`, публичный HTTP 200 проверен 5 ноября 2026. Support URL и Privacy Policy URL сохранены в обоих языках черновика; прежний необязательный Privacy Choices URL удалён. Проверка ссылок из финальной установленной сборки остаётся в плане. Криптографический состав проверен, `ITSAppUsesNonExemptEncryption=false` подтверждён в подписанном архиве build 1; тот же Boolean подтверждён и в подписанном IPA build 2. Неизменившиеся сохранённые поля не требуют повторного ввода. Описания, What’s New и Review Notes обновлены под build 2; новые скриншоты загружены, все миниатюры обработаны и проверены; окончательное решение об отправке версии и правовые заявления проверяются при финальном review.

Не заявлять в метаданных автоматическую синхронизацию, подключение банков, бюджеты/лимиты, Face ID, шифрование базы или полную поддержку всех старых баз, если соответствующей проверенной функции нет в релизе. JSON-импорт не заменяет текущие изменённые записи и не восстанавливает настройки. Фразы о локальности и отсутствии сбора окончательно сверить с [APP-STORE-RELEASE.md](APP-STORE-RELEASE.md) и фактическим Privacy Report.

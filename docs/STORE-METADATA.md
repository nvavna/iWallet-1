# Тексты App Store для iWallet

**Состояние на 5 ноября 2026 года: названия, subtitle, описания, promotional text, keywords и базовые What’s New сохранены в русском и английском черновиках 2.0.0; новая версия в магазине не опубликована.** Карточка приложения `6447585809` восстановлена. Подтверждены Bundle ID `com.idevnva.iwallet`, SKU `001` и прежняя версия `1.1.8`, build `1`. Основные тексты ниже подготовлены для 2.0.0; альтернативные названия и дополнительный абзац миграции остаются вариантами этого документа.

В App Store Connect создан [черновик 2.0.0](https://appstoreconnect.apple.com/apps/6447585809/distribution/ios/version/inflight) со статусом «Подготовка к отправке». Выбран ручной выпуск; баннер о снятии прежнего приложения с продажи остаётся. Прошли 55 unit-тестов (39 WalletCore + 16 LegacyMigration) и 2 UI-теста. **Финальный signed archive 2.0.0(1) и App Store IPA с уведомлениями о лицензиях и исправлением крупного текста успешно собраны и проверены.** Извлечённое IPA-приложение подписано Apple Distribution командой `4243BL8MP3`, deep/strict codesign PASS; RealmSwift, четыре privacy manifest и полный текст лицензий на месте. Загрузка заблокирована входом Xcode Accounts (`missing Xcode-Username`), этот шаг передан пользователю. Обработанного Apple build пока нет; отправка на review не выполнена.

Семь шагов возрастной анкеты пройдены по фактическим функциям и содержимому: рейтинг **4+** рассчитан и сохранён. Прежний **Data Not Collected** оставлен без изменений. Пользователь явно выбрал DSA non-trader, настройка сохранена; compliance показывает Active. Соглашение для бесплатных приложений Active с 1 ноября 2026 по 8 марта 2027. RU dark, EN light и RU large text прошли визуальную проверку; физический iPhone, iOS 17 и полная матрица VoiceOver ещё остаются в плане.

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

### Полное описание

```text
iWallet помогает вести личные финансы: записывайте доходы и расходы, смотрите баланс и разбирайтесь, на что уходят деньги.

ПОНЯТНЫЙ ОБЗОР
Баланс, доходы и расходы собраны на одном экране. Смотрите итоги за текущий месяц или за всё время и распределение расходов по категориям.

БЫСТРЫЙ УЧЁТ
Добавляйте сумму, категорию, дату и заметку. Исправляйте операции и находите нужные записи по заметке, категории или валюте.

ВАШИ КАТЕГОРИИ
Создавайте категории с удобными названиями, значками и цветами. Архивируйте ненужные категории, сохраняя связанные операции в истории.

РАЗНЫЕ ВАЛЮТЫ
Выбирайте валюту для каждой операции и смотрите отдельные итоги. Суммы разных валют не смешиваются; изменение валюты не выполняет обмен по курсу.

ЛОКАЛЬНЫЕ ДАННЫЕ
Категории и операции хранятся на устройстве. Для учёта не нужны регистрация или подключение банковского счёта. Приложение не содержит рекламы и аналитических сервисов.

КОПИИ ИСТОРИИ
Сохраните категории и операции в JSON-файл через системное меню экспорта. Вы сами выбираете, где хранить файл и кому его передавать. Импорт совместимого файла добавит отсутствующие записи, пропустит идентичные и остановится при конфликте с текущими данными.

Интерфейс доступен на русском и английском языках. Требуется iOS 17 или новее.
```

### Что нового — базовый текст

```text
iWallet получил обновлённый интерфейс и новое локальное хранилище.

• Обзор баланса и расходов по категориям.
• Итоги за текущий месяц и за всё время.
• Раздельный учёт операций в разных валютах.
• Поиск по истории и удобное редактирование записей.
• Архивирование категорий с сохранением операций.
• Экспорт категорий и операций в JSON и импорт совместимых копий с проверкой конфликтов.

Новая версия требует iOS 17 или новее.
```

Дополнительный абзац миграции ниже не входит в подтверждённый сохранённый базовый What’s New. Импортёр, synthetic fixture настоящего формата Realm 2023 года и полный UI-сценарий переноса на симуляторе проверены. Проверка обновления на физическом устройстве ещё не выполнена:

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

### Full description

```text
iWallet helps you keep a clear record of your everyday finances. Add income and expenses, check your balance, and understand where your money goes.

A CLEAR OVERVIEW
See your balance, income and expenses in one place. Review this month or all time, with spending grouped by category.

QUICK ENTRY
Add an amount, category, date and note. Edit your transactions and find records by note, category or currency.

YOUR OWN CATEGORIES
Create categories with names, icons and colors that work for you. Archive categories you no longer need while keeping their transactions in your history.

MULTIPLE CURRENCIES
Choose a currency for each transaction and view separate totals. Different currencies are kept separate. Changing a currency does not perform an exchange-rate conversion.

LOCAL DATA
Your categories and transactions are stored on your device. No account or bank connection is needed to keep your records. The app contains no advertising or analytics services.

HISTORY BACKUPS
Save your categories and transactions as a JSON file using the system export interface. You choose where the file is saved and who receives it. Import a compatible file to add missing records, skip identical records, and stop if the file conflicts with your current data.

Available in English and Russian. Requires iOS 17 or later.
```

### What's New — base text

```text
iWallet has a refreshed interface and new local storage.

• A clear balance and spending overview.
• This-month and all-time summaries.
• Separate transaction totals for different currencies.
• History search and easier transaction editing.
• Category archiving that keeps your transactions.
• JSON export and import of compatible backups with conflict checks.

This version requires iOS 17 or later.
```

The optional migration paragraph below is separate from the confirmed saved base What's New. The importer, a synthetic database in the actual 2023 Realm format, and the complete simulator migration flow passed validation. A physical-device upgrade test has not yet been completed:

```text
When updating, the app offers to transfer supported data from the previous version into its new local storage. Confirm the original currency and review any rounding changes before transferring your history.
```

## App Review Notes — сохранённый текст

Ниже точный текст, сохранённый в App Store Connect и повторно прочитанный после переключения на русский язык. Существующие review-контакты карточки сохранены; личные контактные данные в этот документ не включены. Подготовительные альтернативы удалены.

```text
iWallet is a manual personal income and expense tracker. No sign-in is required. It does not connect to banks, provide banking services, move money, or perform currency exchange. Totals are separate for each currency.

Clean-install review flow:
1. Open Overview and choose New transaction. Enter an amount, category, date and optional note, then save.
2. Open Transactions to search, edit or delete a record.
3. Open Categories to create or archive a category. Archiving retains its existing transactions.
4. In Overview > Settings, choose Export all data to save a JSON file using the system file exporter. Choose Import a backup to review and restore a compatible file. Missing records are added, identical records are skipped, and conflicts stop the import without replacing existing data.

Data is stored locally with SwiftData. The app has no account system, advertising, analytics service or developer-operated data server. The user chooses where exported files are saved. JSON backups contain categories and transactions, but not app preferences.

Upgrade migration:
This transitional release includes Realm Swift only to read legacy local wallet data (schema 15 from version 1.1.8). No Atlas Device Sync or cloud migration is used. When a supported previous wallet is detected, the Your history screen asks the user to confirm the original currency, review record counts and totals, and acknowledge any rounding changes before transferring the history. The original file and a snapshot are retained. Data and a migration receipt are saved together, so the transfer does not repeat after relaunch. Unsupported schemas or multiple old wallet files show an explanation instead of opening an empty wallet.

Prepared version: 2.0.0 (1), iOS 17 or later.
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
| Версия / build / выпуск | Черновик `2.0.0`, проверенный archive `2.0.0(1)`, ручной выпуск; после обработки Apple выбрать соответствующий build |
| Категория | Сверить с действующей карточкой при финальном review; изменение категории не заявлено |
| Возрастной рейтинг | `4+` рассчитан и сохранён после актуальной семишаговой анкеты |
| App Privacy / DSA | Прежний Data Not Collected сохранён; non-trader явно выбран пользователем и сохранён, compliance Active |
| Скриншоты | По 3 реальных снимка RU/EN (обзор, история, категории) загружены в черновик: iPhone с Dynamic Island, средний дисплей, 1206×2622 RGB PNG. [Воспроизведение](APPSTORE-SCREENSHOTS.md) |

Документы политики и поддержки опубликованы в `ffb019b`, публичный HTTP 200 проверен 5 ноября 2026. Support URL и Privacy Policy URL сохранены в обоих языках черновика; прежний необязательный Privacy Choices URL удалён. Проверка ссылок из финальной установленной сборки остаётся в плане. Криптографический состав проверен, `ITSAppUsesNonExemptEncryption=false` подтверждён в подписанном архиве. Уже сохранённые поля не требуют повторного ввода; окончательное решение об отправке версии и правовые заявления проверяются при финальном review.

Не заявлять в метаданных автоматическую синхронизацию, подключение банков, бюджеты/лимиты, Face ID, шифрование базы или полную поддержку всех старых баз, если соответствующей проверенной функции нет в релизе. JSON-импорт не заменяет текущие изменённые записи и не восстанавливает настройки. Фразы о локальности и отсутствии сбора окончательно сверить с [APP-STORE-RELEASE.md](APP-STORE-RELEASE.md) и фактическим Privacy Report.

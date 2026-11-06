# Снимки для App Store

> **В App Store Connect остаются шесть снимков build 2: по три RU/EN.** Текущая локальная работа — build 5 с вкладками «Обзор / Операции / Платежи / Настройки», графиками и регулярными платежами. Скрипт и UI-сценарий согласованы на **девять экранов на язык, 18 PNG всего**. Оба capture-теста прошли; все 18 PNG визуально проверены. Новые снимки не загружены в Apple.

Проверенная 5 ноября 2026 спецификация Apple: для используемого iPhone 18 Pro подходит портретный размер **1206 × 2622**. PNG должен быть без alpha channel. Источник: [Apple — Screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/). Рецепт capture ниже ничего не публикует в App Store Connect.

## Набор build 5 — получен и проверен

`Scripts/capture-app-store-screenshots.py` вызывает opt-in `WalletAppStoreScreenshotTests.testCaptureRussian` / `testCaptureEnglish`. На новом пустом демонстрационном симуляторе каждый сценарий через обычные формы создаёт **семь синтетических операций и два плана подписок**: два дохода, пять бытовых расходов, музыка и облачное хранилище. RU использует RUB, EN — USD. Планы не отмечаются оплаченными и не добавляют расходы в историю. Демонстрационные операции датируются днём съёмки; график показывает фактическую распределённость этих данных, а не выдуманную историю за месяц.

| Файл | Содержимое |
| --- | --- |
| `01-overview.png` | Верх обзора: общий баланс, период, сводка и четыре вкладки |
| `02-transactions.png` | Вкладка Операции с историей |
| `03-categories.png` | Категории, открытые из Настроек |
| `04-new-transaction.png` | Форма новой операции |
| `05-new-category.png` | Форма новой категории |
| `06-settings.png` | Вкладка Настройки |
| `07-payments.png` | Вкладка Платежи с демонстрационными планами |
| `08-analytics.png` | Столбчатый график доходов и расходов в обзоре |
| `09-category-chart.png` | Диаграмма распределения по категориям в обзоре |

Формы для снимков открываются без ввода и закрываются без сохранения дополнительных записей. Иконка приложения не менялась. Изображения — реальные снимки работающего интерфейса: без ретуши, масштабирования или добавленных графических элементов.

Нужны Xcode с iOS 27.2 Simulator, Python 3 и два **новых пустых** симулятора. Существующие QA-устройства и личный кошелёк не использовать. Fresh capture проверяет отсутствие операций и планов; заполненный кошелёк не очищается. Для повторной съёмки выделенного демонстрационного устройства предусмотрен read-only режим ниже.

Команды — рецепт, а не доказательство завершённого запуска. Каталог build 5 отделён от исторических артефактов:

```sh
RU_DEVICE=$(xcrun simctl create 'iWallet App Store Build5 RU' com.apple.CoreSimulator.SimDeviceType.iPhone-18-Pro com.apple.CoreSimulator.SimRuntime.iOS-27-2)
EN_DEVICE=$(xcrun simctl create 'iWallet App Store Build5 EN' com.apple.CoreSimulator.SimDeviceType.iPhone-18-Pro com.apple.CoreSimulator.SimRuntime.iOS-27-2)
xcrun simctl boot "$RU_DEVICE"
xcrun simctl boot "$EN_DEVICE"
xcrun simctl bootstatus "$RU_DEVICE" -b
xcrun simctl bootstatus "$EN_DEVICE" -b
for STORE_DEVICE in "$RU_DEVICE" "$EN_DEVICE"; do
  xcrun simctl ui "$STORE_DEVICE" appearance light
  xcrun simctl ui "$STORE_DEVICE" content_size large
  xcrun simctl status_bar "$STORE_DEVICE" override --time '9:41' --dataNetwork wifi --wifiMode active --wifiBars 3 --cellularMode active --cellularBars 4 --batteryState charged --batteryLevel 100
done
xcodebuild build-for-testing -project iWallet.xcodeproj -scheme iWallet \
  -destination "id=$RU_DEVICE" -derivedDataPath build/DerivedData \
  -clonedSourcePackagesDirPath build/SourcePackages -jobs 2 CODE_SIGNING_ALLOWED=NO
python3 Scripts/capture-app-store-screenshots.py --language ru --device "$RU_DEVICE" \
  --xctestrun build/DerivedData/Build/Products/iWallet_iphonesimulator27.2-arm64.xctestrun \
  --output build/AppStore-Screenshots-build5
python3 Scripts/capture-app-store-screenshots.py --language en --device "$EN_DEVICE" \
  --xctestrun build/DerivedData/Build/Products/iWallet_iphonesimulator27.2-arm64.xctestrun \
  --output build/AppStore-Screenshots-build5
```

Скрипт временно включает `IWALLET_CAPTURE_APP_STORE=1` в отдельной копии `.xctestrun`, исполняет нужный XCTest и извлекает screenshot attachments. Обычный тестовый запуск пропускает opt-in методы. Проверяются **все девять имён**, отсутствие дубликатов, размер **1206 × 2622** и RGB PNG без alpha; изображения не преобразуются. `.xcresult` и исходные attachments сохраняются рядом с PNG. При другой версии SDK используйте фактически созданное имя `.xctestrun`. Если актуальные products уже готовы, повторная сборка не нужна; во время исполнения тестов их нельзя пересобирать.

Перед загрузкой требуется просмотреть **все 18 PNG**: язык, порядок, читаемость подписей и денежных сумм, видимость обеих диаграмм, отсутствие клавиатуры и переходных состояний, соответствие установленному build 5. Наличие файлов и успешный XCTest не заменяют визуальную проверку.

### Повторная съёмка без изменения данных

Добавьте `--existing-demo` к команде скрипта: будут вызваны `testRefreshRussian` / `testRefreshEnglish`. Они открывают те же девять экранов, не создают и не редактируют операции, категории или планы, не заполняют поля и отменяют формы. Такой запуск предназначен только для уже подготовленного отдельного демонстрационного симулятора. Он не добавит планы, если на устройстве остались только данные build 4; для полного нового набора используйте fresh capture на новом устройстве. По умолчанию скрипт по-прежнему требует пустой кошелёк.

## Дополнительная визуальная QA build 5

`WalletAppStoreScreenshotTests.testCaptureRussianVisualQA` использует заполненный выделенный RU capture-симулятор. Данные не меняются. Тему и размер текста задаёт хост через `simctl`.

1. В отдельной копии актуального `.xctestrun` установите `IWALLET_CAPTURE_APP_STORE=1` в `EnvironmentVariables` test target. Для дополнительных снимков прокрутки добавьте `IWALLET_QA_SCROLL=1`. Переменные передаются XCTest runner, а не только shell или приложению.
2. Выберите тему/размер текста и запустите отдельный read-only метод, например:

```sh
xcrun simctl ui "$RU_DEVICE" appearance dark
xcrun simctl ui "$RU_DEVICE" content_size accessibility-extra-extra-extra-large
xcodebuild test-without-building -xctestrun "$IWALLET_QA_XCTESTRUN" \
  -destination "id=$RU_DEVICE" -parallel-testing-enabled NO \
  '-only-testing:iWalletUITests/WalletAppStoreScreenshotTests/testCaptureRussianVisualQA' \
  -resultBundlePath "$IWALLET_QA_RESULT"
```

`IWALLET_QA_XCTESTRUN` — подготовленная копия конфигурации, `IWALLET_QA_RESULT` — новый уникальный `.xcresult`. Сам тест тему и Dynamic Type не переключает.

3. Без `IWALLET_QA_SCROLL` сохраняются девять кадров `QA-ru-01-overview` … `QA-ru-09-category-chart`. С переменной после каждого верхнего кадра выполняются два swipe вверх и сохраняются `-lower-1` / `-lower-2`: 27 базовых QA attachments плюс два снимка конца истории/настроек: **29 всего**. Для последних строк выполняется отдельная ограниченная прокрутка с проверкой видимости. На непрокручиваемом экране кадры могут совпадать.
4. Проверьте доступность нижних полей/кнопок и точных значений графиков при крупном тексте, перенос сумм, подписи осей и читаемость выбранного сектора. Отдельно требуется VoiceOver: успешный capture не доказывает правильность чтения графиков. После QA верните демонстрационный симулятор к нужной теме и размеру текста.

QA-кадры отделены от 18 магазинных PNG и автоматически не загружаются. Подтверждённые результаты приведены ниже.

## История: build 4 проверен локально

5 ноября 2026 сборка симулятора прошла; `build/UITests-Design4-Smoke-Final.xcresult` — **2 PASS**, `build/UITests-Design4-Migration.xcresult` — **1 PASS**, без ошибок и пропусков. Исходный Realm и snapshot сохранили SHA-256 `b427523b505ddf61179a6b4af00870756efbcc1cd1bdbf3eef059f2ecad19bdd`.

Сняты и просмотрены **12 RU/EN** кадров в `build/AppStore-Screenshots-build4/{ru,en}/`, **6 Dark** и **18 AX**. На этих снимках три вкладки, без графиков и платежей. AX-проверка ограничена: некоторые значения системного Picker/placeholder сокращаются, низ всех длинных экранов полностью не проверен. В smoke сохраняется прежнее предупреждение Invalid frame при клавиатуре. VoiceOver, физический iPhone и iOS 17 остаются открытыми проверками. Build 4 не подписывался и не загружался; эти результаты не подтверждают build 5.

## История: build 2 сохранён в App Store Connect

Набор **iWallet 2.0.0 (2)**: `build/AppStore-Screenshots-build2/{ru,en}/`, по три кадра на язык — `01-overview.png`, `02-transactions.png`, `03-categories.png`. Обзор показывает прежние карточки 2×2 и круглую кнопку добавления; нижних вкладок нет. Все шесть кадров загружены в черновик и обработанные миниатюры проверены. Это действующие материалы ASC, не иллюстрация build 5.

Оба opt-in capture-теста build 2 прошли 5 ноября 2026: **RU — PASS, 177,8 секунды; EN — PASS, 119,2 секунды**. Все шесть PNG просмотрены: читаемые заголовки и суммы, без тестовых UUID; RGB 1206 × 2622 без alpha. Размеры и SHA-256 — `build/AppStore-Screenshots-build2/validated-screenshots.json`.

- `capture-ru-2d265fea.xcresult` — RU, симулятор `B762050D-82B6-4BF7-8039-7FD50EC7815B`;
- `capture-en-6863e57a.xcresult` — EN, симулятор `A5D18946-CDF3-4E99-B77C-119CCAC1732A`.

Дополнительно проверены RU Home dark и максимальный AX-размер: `build/QA/build2-overview-ru-dark.png`, `build2-overview-ru-large.png`, `build2-overview-ru-light.png`. Эти кадры не входят в шесть магазинных PNG. Подтверждения окончательных наборов ASC: `build/QA/appstore-build2-screenshots-ru.jpg`, `build/QA/appstore-build2-screenshots-en.jpg`.

Набор `build/AppStore-Screenshots/` относится к build 1 и ранее заменён в черновике кадрами build 2. Превью `build/QA/home-compact-*.png` относятся к промежуточному build 3. Неиспользуемые дубликаты остаются в Библиотеке материалов. Загрузка проводилась отдельно от capture; App Review и публикация не выполнялись.

## Подтверждённые снимки build 5

- RU read-only refresh: `build/AppStore-Screenshots-build5/capture-ru-30837b54.xcresult`, PASS. Начальное заполнение семью операциями и двумя планами завершилось ранее; повторный проход данные не менял.
- EN fresh capture: `build/AppStore-Screenshots-build5/capture-en-fc4d1d7a.xcresult`, PASS.
- 18 оригинальных PNG в `build/AppStore-Screenshots-build5/{ru,en}/`, 1206×2622, RGB без alpha; SHA-256 в `validated-screenshots.json`. Девять RU-копий сохранены в `docs/images/design5/`.
- Балансы: RU 197 000 − 15 526 = 181 474 RUB; EN 5 150 − 323,70 = 4 826,30 USD. Планы не изменили эти суммы.

Съёмка графиков сначала выявила колебания тестовой прокрутки; исправлен helper и повторён read-only capture. Эти сбои не меняли записи. При максимальном AX обнаружено наложение осей: production-layout заменён выбором интервала и точными текстовыми значениями; финальная перепроверка этого режима фиксируется отдельно.

## Финальная проверка Dark и крупного текста

`build/UITests-Build5-Dark-Final.xcresult` — PASS, 81,936 с; девять оригинальных кадров в `build/QA/design5-dark-final/`. Оба графика визуально помещаются над tab bar, подписи и значения читаемы.

`build/UITests-Build5-AX-Final.xcresult` — PASS, 162,530 с; 29 кадров в `build/QA/design5-ax-final/`. Проверен альтернативный текстовый просмотр временных интервалов без наложения осей, перенос суммы/категории/заметки. Дополнительные bottom assertions и изображения подтверждают видимость последней операции и строки хранения над tab bar. Русский симулятор после проверки возвращён в light/large.

Capture-helper объединяет frames всех элементов с ID карты: SwiftUI переносит этот ID на несколько дочерних AX-элементов. Геометрия записана в attachments. Это исправление съёмки, не изменение финансовых данных. Эти результаты не заменяют VoiceOver и физический iPhone.

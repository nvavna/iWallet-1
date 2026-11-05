# Снимки для App Store

> В App Store Connect сохранены снимки **build 2**. Текущий локальный **build 4** использует три нативные вкладки «Обзор / Операции / Настройки», компактный Home без дублирующих переходов и единые SF-badges. Capture-сценарий реализован для **шести экранов на язык, 12 кадров всего**; русский capture и smoke ещё выполняются, PASS пока не подтверждён. Превью `build/QA/home-compact-*.png` относятся к промежуточному build 3, не к build 4.

Проверено 5 ноября 2026 года: Apple требует снимки iPhone with Dynamic Island (medium display). Для iPhone 18 Pro подходит портретный размер **1206 × 2622**. PNG не должен содержать alpha channel. Источник: [Apple — Screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/).

Сохранённый в App Store Connect набор для **iWallet 2.0.0 (2)** находится в `build/AppStore-Screenshots-build2/{ru,en}/`. Все шесть кадров загружены в черновик; обработанные миниатюры визуально проверены для обоих языков. В каждом наборе сохранён порядок: обзор, история, категории. Эти кадры остаются историческим подтверждением build 2 и не изображают новую навигацию build 4.

- `01-overview.png` — единый главный экран с четырьмя показателями, категориями и круглой кнопкой добавления;
- `02-transactions.png` — история операций;
- `03-categories.png` — категории расходов.

Это реальные снимки запущенного приложения. Данные синтетические: зарплата, дополнительный доход и пять бытовых расходов. Сценарий вводит их через обычную форму; production-код, настройки хранилища, версия и Release IPA не изменяются. Категории и заметки соответствуют языку. Изображения не ретушируются и не масштабируются.

В build 2 восстановлена близкая к оригиналу структура: нейтральные карточки 2×2, средний расход за день, список категорий с цветными маркерами, сумма слева в истории. Нижних вкладок нет; история доступна с главного экрана и из настроек, категории — из настроек. Все демонстрационные операции созданы в день съёмки, поэтому средний расход по дням с тратами совпадает с общей суммой расходов.

## Набор build 4 — сценарий реализован, результат ещё ожидается

`Scripts/capture-app-store-screenshots.py` и opt-in `WalletAppStoreScreenshotTests.testCaptureRussian` / `testCaptureEnglish` подготовлены под текущую навигацию. На новом пустом симуляторе каждый сценарий вводит через обычные формы **семь синтетических операций**: два дохода и пять расходов. RU использует RUB, EN — USD. Затем снимаются шесть экранов, по одному комплекту для каждого языка:

| Файл | Содержимое |
| --- | --- |
| `01-overview.png` | Обзор: главный баланс, компактная сводка, категории и native tab bar |
| `02-transactions.png` | Вкладка Операции с историей |
| `03-categories.png` | Категории, открытые push-переходом из Настроек |
| `04-new-transaction.png` | Форма новой операции |
| `05-new-category.png` | Форма новой категории |
| `06-settings.png` | Вкладка Настройки |

Формы для снимков открываются без ввода и закрываются без создания дополнительных записей. Сохраняются системная навигация и новая палитра. Иконка приложения остаётся прежней; изображения не ретушируются и не масштабируются.

Подготовительная сборка UI-тестов завершилась **TEST BUILD SUCCEEDED** (`/tmp/iwallet-design4-test-build.log`), `CFBundleVersion=4`. В RU/EN совпадают наборы из **263 ключей** локализации; это не подтверждение визуального качества переводов. Русский capture и smoke сейчас выполняются, их итог не объявляется успешным. EN capture, все 12 файлов и дополнительная QA-приёмка ещё требуют подтверждения.

Команды ниже — рецепт capture, не доказательство завершённого запуска. Результаты записываются в отдельный каталог; артефакты build 2 не перезаписываются.

Нужны Xcode с iOS 27.2 Simulator, Python 3 и два **новых пустых** симулятора. Существующие QA-устройства и данные пользователя не использовать. Повторный запуск на уже заполненном кошельке намеренно завершается ошибкой; создайте новый симулятор вместо очистки старого.

```sh
RU_DEVICE=$(xcrun simctl create 'iWallet App Store Build4 RU' com.apple.CoreSimulator.SimDeviceType.iPhone-18-Pro com.apple.CoreSimulator.SimRuntime.iOS-27-2)
EN_DEVICE=$(xcrun simctl create 'iWallet App Store Build4 EN' com.apple.CoreSimulator.SimDeviceType.iPhone-18-Pro com.apple.CoreSimulator.SimRuntime.iOS-27-2)
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
  --output build/AppStore-Screenshots-build4
python3 Scripts/capture-app-store-screenshots.py --language en --device "$EN_DEVICE" \
  --xctestrun build/DerivedData/Build/Products/iWallet_iphonesimulator27.2-arm64.xctestrun \
  --output build/AppStore-Screenshots-build4
```

Скрипт временно включает `IWALLET_CAPTURE_APP_STORE=1` только в копии `.xctestrun`, вызывает нужный XCTest и экспортирует **шесть** screenshot attachments. Обычный запуск тестов пропускает эти opt-in методы. Проверяется точный набор из шести имён выше, отсутствие дубликатов, нативный размер **1206×2622** и RGB PNG без alpha; преобразований изображений нет. `.xcresult` и исходные attachments остаются рядом с итоговыми файлами для проверки происхождения. При другой версии SDK изменится имя `.xctestrun` — используйте файл, созданный `build-for-testing`. Если подходящие products уже собраны, повторять сборку не нужно. Во время исполнения тестов не пересобирайте используемые ими products.

Перед загрузкой следует проверить **все 12 файлов**, а не только Overview. Нужны читаемые значения/подписи, правильная локаль и порядок, отсутствие клавиатуры/переходного состояния и соответствие текущему build. Сам сценарий ничего не отправляет в App Store Connect.

## Дополнительная визуальная QA build 4 — без изменения записей

`WalletAppStoreScreenshotTests.testCaptureRussianVisualQA` использует **уже заполненный отдельный RU capture-симулятор**. Он не создаёт и не редактирует операции/категории: открывает те же шесть экранов, обе новые формы отменяет без сохранения. Проверка не предназначена для личного кошелька или нового пустого симулятора.

1. В отдельной копии актуального `.xctestrun` установите `IWALLET_CAPTURE_APP_STORE=1` в `EnvironmentVariables` test target. Для проверки прокрутки добавьте туда же `IWALLET_QA_SCROLL=1`; переменные нужны XCTest runner, а не только shell или приложению.
2. На хосте задайте appearance и размер текста через `xcrun simctl ui`. Пример для максимального AX-текста в тёмной теме:

```sh
xcrun simctl ui "$RU_DEVICE" appearance dark
xcrun simctl ui "$RU_DEVICE" content_size accessibility-extra-extra-extra-large
xcodebuild test-without-building -xctestrun "$IWALLET_QA_XCTESTRUN" \
  -destination "id=$RU_DEVICE" -parallel-testing-enabled NO \
  '-only-testing:iWalletUITests/WalletAppStoreScreenshotTests/testCaptureRussianVisualQA' \
  -resultBundlePath "$IWALLET_QA_RESULT"
```

`IWALLET_QA_XCTESTRUN` — путь к подготовленной копии, `IWALLET_QA_RESULT` — новый уникальный путь `.xcresult`. Они задаются для конкретного прогона. Сам QA-метод appearance и Dynamic Type не переключает.

3. Без `IWALLET_QA_SCROLL` сохраняются шесть верхних кадров `QA-ru-01-overview` … `QA-ru-06-settings`. При `IWALLET_QA_SCROLL=1` после каждого из них выполняются два swipe вверх и сохраняются `-lower-1` / `-lower-2`: **18 QA attachments всего**. Они позволяют проверить достижимость нижних полей и кнопок при крупном тексте; если экран не прокручивается, нижние кадры могут совпадать.
4. Экспортируйте attachments из `.xcresult` и просмотрите верхние и нижние части каждого экрана. Окончание теста само по себе не доказывает отсутствие обрезания, достаточный контраст или поддержку VoiceOver. После QA верните выделенный демонстрационный симулятор к нужной теме/размеру текста для следующего capture.

Эти QA-кадры отделены от 12 магазинных PNG и не загружаются в карточку автоматически. Результаты новых QA-прогонов ещё не подтверждены.

## Исторический проверенный результат build 2

Оба opt-in XCTest-сценария build 2 прошли 5 ноября 2026 года: **RU — PASS, 177,8 секунды; EN — PASS, 119,2 секунды**. Все шесть кадров просмотрены: заголовки и суммы читаемы, на снимках нет тестовых UUID или названий smoke. Все файлы — RGB PNG 1206 × 2622 без alpha. Их размеры и SHA-256 записаны в `build/AppStore-Screenshots-build2/validated-screenshots.json`.

Результаты XCTest в том же каталоге:

- `capture-ru-2d265fea.xcresult` — RU, симулятор `B762050D-82B6-4BF7-8039-7FD50EC7815B`;
- `capture-en-6863e57a.xcresult` — EN, симулятор `A5D18946-CDF3-4E99-B77C-119CCAC1732A`.

Дополнительно проверен русский главный экран в тёмной теме и с максимальным размером текста `accessibility-extra-extra-extra-large`. При крупном тексте показатели переходят в одну колонку; видимые суммы и подписи не обрезаны. QA-снимки: `build/QA/build2-overview-ru-dark.png`, `build2-overview-ru-large.png` и `build2-overview-ru-light.png`. После проверки демонстрационный RU-симулятор возвращён к светлой теме и стандартному размеру текста. Эти дополнительные QA-кадры не входят в набор из шести App Store PNG.

Предыдущий набор в `build/AppStore-Screenshots/` относится к дизайну build 1 и заменён в черновике новыми снимками build 2. Удалённые привязки и неиспользуемые дубликаты остаются в Библиотеке материалов. Подтверждения окончательных наборов: `build/QA/appstore-build2-screenshots-ru.jpg` и `build/QA/appstore-build2-screenshots-en.jpg`. Загрузка выполнена отдельно от capture-сценария; публикация не выполнялась.

## Зафиксированный результат build 4

5 ноября 2026: сборка симулятора прошла; `UITests-Design4-Smoke-Final.xcresult` — 2 PASS, `UITests-Design4-Migration.xcresult` — 1 PASS, без ошибок и пропусков. Исходный Realm и сохранённый snapshot имеют прежний SHA-256 `b427523b505ddf61179a6b4af00870756efbcc1cd1bdbf3eef059f2ecad19bdd`. Сняты и просмотрены 12 RU/EN-кадров в `build/AppStore-Screenshots-build4/{ru,en}/`, 6 Dark и 18 AX-кадров. AX-проверка ограничена: отдельные значения системного Picker/placeholder сокращаются, низ всех длинных экранов не проверен полностью. VoiceOver/физический iPhone/iOS 17 остаются открытыми. В smoke сохраняется прежнее предупреждение Invalid frame при клавиатуре.

Build 4 не подписан и не загружен; в App Store Connect сохранены build 2 и его материалы. Следующий запрос владельца расширяет приложение графиками и регулярными платежами; результаты build 4 не подтверждают ещё не реализованное расширение.

Для повторной съёмки уже подготовленного демонстрационного симулятора доступен `--existing-demo`: используются `testRefreshRussian`/`testRefreshEnglish`, новые записи не создаются. По умолчанию по-прежнему требуется пустой кошелёк.

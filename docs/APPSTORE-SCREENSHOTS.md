# Снимки для App Store

> Набор ниже фиксирует build 2, сохранённый в App Store Connect. Для рабочего build 3 подготовлены превью компактного Home в `build/QA/home-compact-*.png`; новый магазинный набор следует получить отдельно после завершения следующего релизного артефакта.

Проверено 5 ноября 2026 года: Apple требует снимки iPhone with Dynamic Island (medium display). Для iPhone 18 Pro подходит портретный размер **1206 × 2622**. PNG не должен содержать alpha channel. Источник: [Apple — Screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/).

Актуальный набор для **iWallet 2.0.0 (2)** находится в `build/AppStore-Screenshots-build2/{ru,en}/`. Все шесть кадров загружены в черновик App Store Connect; обработанные миниатюры визуально проверены для обоих языков. В каждом наборе сохранён порядок: обзор, история, категории.

- `01-overview.png` — единый главный экран с четырьмя показателями, категориями и круглой кнопкой добавления;
- `02-transactions.png` — история операций;
- `03-categories.png` — категории расходов.

Это реальные снимки запущенного приложения. Данные синтетические: зарплата, дополнительный доход и пять бытовых расходов. Сценарий вводит их через обычную форму; production-код, настройки хранилища, версия и Release IPA не изменяются. Категории и заметки соответствуют языку. Изображения не ретушируются и не масштабируются.

В build 2 восстановлена близкая к оригиналу структура: нейтральные карточки 2×2, средний расход за день, список категорий с цветными маркерами, сумма слева в истории. Нижних вкладок нет; история доступна с главного экрана и из настроек, категории — из настроек. Все демонстрационные операции созданы в день съёмки, поэтому средний расход по дням с тратами совпадает с общей суммой расходов.

## Воспроизведение

Нужны Xcode с iOS 27.2 Simulator, Python 3 и два **новых пустых** симулятора. Существующие QA-устройства и данные пользователя не использовать. Повторный запуск на уже заполненном кошельке намеренно завершается ошибкой; создайте новый симулятор вместо очистки старого.

```sh
RU_DEVICE=$(xcrun simctl create 'iWallet App Store Build2 RU' com.apple.CoreSimulator.SimDeviceType.iPhone-18-Pro com.apple.CoreSimulator.SimRuntime.iOS-27-2)
EN_DEVICE=$(xcrun simctl create 'iWallet App Store Build2 EN' com.apple.CoreSimulator.SimDeviceType.iPhone-18-Pro com.apple.CoreSimulator.SimRuntime.iOS-27-2)
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
  --output build/AppStore-Screenshots-build2
python3 Scripts/capture-app-store-screenshots.py --language en --device "$EN_DEVICE" \
  --xctestrun build/DerivedData/Build/Products/iWallet_iphonesimulator27.2-arm64.xctestrun \
  --output build/AppStore-Screenshots-build2
```

Скрипт временно включает `IWALLET_CAPTURE_APP_STORE=1` только в копии `.xctestrun`, вызывает нужный XCTest и экспортирует три screenshot attachments. Обычный запуск тестов пропускает эти opt-in методы. Скрипт проверяет нативный размер и RGB PNG без прозрачности; преобразований изображений нет. `.xcresult` и исходные attachments остаются рядом с итоговыми файлами для проверки происхождения. При другой версии SDK изменится имя `.xctestrun` — используйте файл, созданный `build-for-testing`. Если подходящие products уже собраны, повторять сборку не нужно. Во время исполнения тестов не пересобирайте используемые ими products.

Перед загрузкой следует визуально проверить все шесть файлов. Это материалы для черновика карточки приложения; сам сценарий ничего не отправляет в App Store Connect.

## Проверенный результат

Оба opt-in XCTest-сценария build 2 прошли 5 ноября 2026 года: **RU — PASS, 177,8 секунды; EN — PASS, 119,2 секунды**. Все шесть кадров просмотрены: заголовки и суммы читаемы, на снимках нет тестовых UUID или названий smoke. Все файлы — RGB PNG 1206 × 2622 без alpha. Их размеры и SHA-256 записаны в `build/AppStore-Screenshots-build2/validated-screenshots.json`.

Результаты XCTest в том же каталоге:

- `capture-ru-2d265fea.xcresult` — RU, симулятор `B762050D-82B6-4BF7-8039-7FD50EC7815B`;
- `capture-en-6863e57a.xcresult` — EN, симулятор `A5D18946-CDF3-4E99-B77C-119CCAC1732A`.

Дополнительно проверен русский главный экран в тёмной теме и с максимальным размером текста `accessibility-extra-extra-extra-large`. При крупном тексте показатели переходят в одну колонку; видимые суммы и подписи не обрезаны. QA-снимки: `build/QA/build2-overview-ru-dark.png`, `build2-overview-ru-large.png` и `build2-overview-ru-light.png`. После проверки демонстрационный RU-симулятор возвращён к светлой теме и стандартному размеру текста. Эти дополнительные QA-кадры не входят в набор из шести App Store PNG.

Предыдущий набор в `build/AppStore-Screenshots/` относится к дизайну build 1 и заменён в черновике новыми снимками build 2. Удалённые привязки и неиспользуемые дубликаты остаются в Библиотеке материалов. Подтверждения окончательных наборов: `build/QA/appstore-build2-screenshots-ru.jpg` и `build/QA/appstore-build2-screenshots-en.jpg`. Загрузка выполнена отдельно от capture-сценария; публикация не выполнялась.

# Снимки для App Store

Проверено 5 ноября 2026 года: Apple требует снимки iPhone with Dynamic Island (medium display). Для iPhone 18 Pro подходит портретный размер **1206 × 2622**. PNG не должен содержать alpha channel. Источник: [Apple — Screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/).

Итоговые файлы находятся в `build/AppStore-Screenshots/{ru,en}/`:

- `01-overview.png` — обзор и текущий баланс;
- `02-transactions.png` — история операций;
- `03-categories.png` — категории расходов.

Это реальные снимки запущенного приложения. Данные синтетические: зарплата, дополнительный доход и пять бытовых расходов. Сценарий вводит их через обычную форму; production-код, настройки хранилища, версия и Release IPA не изменяются. Категории и заметки соответствуют языку. Изображения не ретушируются и не масштабируются.

## Воспроизведение

Нужны Xcode с iOS 27.2 Simulator, Python 3 и два **новых пустых** симулятора. Существующие QA-устройства и данные пользователя не использовать. Повторный запуск на уже заполненном кошельке намеренно завершается ошибкой; создайте новый симулятор вместо очистки старого.

```sh
RU_DEVICE=$(xcrun simctl create 'iWallet App Store RU' com.apple.CoreSimulator.SimDeviceType.iPhone-18-Pro com.apple.CoreSimulator.SimRuntime.iOS-27-2)
EN_DEVICE=$(xcrun simctl create 'iWallet App Store EN' com.apple.CoreSimulator.SimDeviceType.iPhone-18-Pro com.apple.CoreSimulator.SimRuntime.iOS-27-2)
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
  --xctestrun build/DerivedData/Build/Products/iWallet_iphonesimulator27.2-arm64.xctestrun
python3 Scripts/capture-app-store-screenshots.py --language en --device "$EN_DEVICE" \
  --xctestrun build/DerivedData/Build/Products/iWallet_iphonesimulator27.2-arm64.xctestrun
```

Скрипт временно включает `IWALLET_CAPTURE_APP_STORE=1` только в копии `.xctestrun`, вызывает нужный XCTest и экспортирует три screenshot attachments. Обычный запуск тестов пропускает эти opt-in методы. Скрипт проверяет нативный размер и RGB PNG без прозрачности; преобразований изображений нет. `.xcresult` и исходные attachments остаются рядом с итоговыми файлами для проверки происхождения. При другой версии SDK изменится имя `.xctestrun` — используйте файл, созданный `build-for-testing`.

Перед загрузкой следует визуально проверить все шесть файлов. Это материалы для черновика карточки приложения; сам сценарий ничего не отправляет в App Store Connect.

## Проверенный результат

Оба opt-in XCTest-сценария прошли 5 ноября 2026 года: RU — 190 секунд, EN — 176 секунд. Все шесть изображений просмотрены. В App Store Connect в черновике 2.0.0 загружены три снимка для каждого языка в размер iPhone с Dynamic Island (средний дисплей); интерфейс показывает «3 из 10». Новые материалы заменили использование унаследованных снимков в этом размере. Это не публикация версии.

Подписанный Release IPA после подготовки снимков не изменился: SHA-256 `eb0d853fd0df36298f9074193ce34a089ba2b2a063dc91b6b19b184c1aa608b0`.

В обеих локализациях от черновика также отвязаны старые наборы `001.jpg`–`004.jpg` для Dynamic Island большого размера и iPhone с кнопкой «Домой» большого размера. Диалог Apple подтвердил сохранение файлов в Библиотеке материалов. В черновике остались новые три снимка для обязательного среднего размера; версии 1.1.8 и библиотека не очищались. Предпросмотр обзора появился после обработки Apple; пробный дубликат убран из черновика.

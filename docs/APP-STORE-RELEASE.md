# Подготовка переходного релиза iWallet

Состояние на **5 ноября 2026 года**: существующая карточка восстановлена, черновик **2.0.0** сохранён в App Store Connect. **Build 2 собран, проверен, загружен и обработан Apple.** TestFlight показывает `2.0.0 (2)` со статусом «Готово к отправке». Build 2 выбран и сохранён в черновике App Store; режим выпуска остаётся ручным. Версия на review не отправлена, приглашения тестировщикам не отправлялись, публикации нет.

Пользователь выбрал дизайн ближе к оригиналу: Home с сеткой 2×2, нейтральные карточки, плавающая кнопка «+» и исходная композиция строк. **Build 2 после рестайлинга собран, экспортирован, независимо проверен и успешно обработан Apple.** Build 1 остаётся историческим тестовым вариантом. Для build 2 прошли 60 unit-тестов и оба UI-сценария без пропусков. Шесть новых RU/EN-снимков и главный экран в тёмной теме/с максимальным текстом проверены.

## Идентификаторы и карточка

| Поле | Подготовленное значение / статус |
| --- | --- |
| Репозиторий | [nvavna/iWallet-1](https://github.com/nvavna/iWallet-1) |
| Bundle ID | `com.idevnva.iwallet` — сохранить для обновления прежнего приложения |
| Apple ID | `6447585809` — подтверждён в App Store Connect |
| SKU | `001` — подтверждён в App Store Connect |
| Последняя прежняя версия | `1.1.8`, build `1` — подтверждена в App Store Connect |
| Версия и build | `2.0.0(2)` обработан Apple, TestFlight «Готово к отправке»; build 2 выбран и сохранён в черновике App Store. Build 1 — исторический тестовый вариант |
| Черновик App Store Connect | [2.0.0 — «Подготовка к отправке»](https://appstoreconnect.apple.com/apps/6447585809/distribution/ios/version/inflight), создание подтверждено |
| Режим выпуска и доступность | Выбран ручной выпуск; баннер о снятии старого приложения с продажи остаётся |
| Метаданные | RU/EN descriptions и What’s New обновлены для build 2 и сохранены; остальные текстовые поля не менялись. Новые снимки 3+3 загружены, все обработанные превью визуально проверены |
| Review Notes | Единый обновлённый сценарий build 2 сохранён; текст — [STORE-METADATA.md](STORE-METADATA.md) |
| Marketing URL | Необязательное поле пусто, сохранение и пустое значение подтверждены для RU/EN. Прежний `https://idevnva.com/iwallet` не разрешается в DNS: curl (6), HTTP 000 |
| Возрастной рейтинг | Семь шагов актуальной анкеты заполнены по фактическим функциям и содержимому; рассчитан и сохранён рейтинг `4+` |
| DSA | Пользователь явно выбрал non-trader; настройка сохранена, интерфейс показывает выполнение всех compliance requirements и статус Active |
| Соглашение о бесплатных приложениях | Active, срок 1 ноября 2026 — 8 марта 2027 |
| Минимальная iOS | iOS 17 для нативной версии на SwiftData |
| Доступ и состояние | Аккаунт доступен; iWallet найден в «Удалённых приложениях» с датой удаления 10 марта 2026 года. Восстановление карточки выполнено 5 ноября 2026 года |

До восстановления публичная [страница приложения](https://apps.apple.com/app/id6447585809) не была доступна через инструмент чтения, а Apple lookup для [России](https://itunes.apple.com/lookup?id=6447585809&country=ru) и [США](https://itunes.apple.com/lookup?id=6447585809&country=us) вернул `resultCount: 0`. После входа в App Store Connect существующая карточка и её идентификаторы подтверждены. После восстановления действие Restore исчезло, доступны Transfer, Edit user access и Delete app. Это подтверждает восстановление записи в аккаунте, **но не доступность новой версии для загрузки из магазина**.

Создание черновика 2.0.0 не означает отправку на review или возобновление продаж. Причину удаления 10 марта не следует подменять предположением об App Store Improvements. Восстановление удалённой записи и выпуск новой версии — разные действия. [Восстановление записи](https://developer.apple.com/help/app-store-connect/create-an-app-record/remove-an-app)

## Подтверждённая проверка данных и её пределы

### Текущий build 2

Прошли **60 unit-тестов: 44 WalletCore + 16 LegacyMigration**, без ошибок (`/tmp/iwallet-build2-core-tests.log`). Включены проверки денег/локалей, среднего расхода по активным дням, JSON, сохранения и миграции. Сборка UI-тестов завершилась `TEST BUILD SUCCEEDED` (`/tmp/iwallet-build2-simulator-final.log`).

UI-миграция прошла: **1 passed, 0 failed, 0 skipped**, 31,542 с, `build/UITests-Build2-Migration.xcresult`; лог `/tmp/iwallet-build2-ui-migration.log`. SHA-256 исходной базы до и после переноса и сохранённого snapshot одинаков: `b427523b505ddf61179a6b4af00870756efbcc1cd1bdbf3eef059f2ecad19bdd`. Доказательство — `build/QA/migration-build2-verification.json`.

Smoke-сценарий build 2 также прошёл: **1 passed, 0 failed, 0 skipped**, 115,051 с, `build/UITests-Build2-Smoke-4.xcresult`, `/tmp/iwallet-build2-ui-smoke-4.log`. Проверены создание/редактирование расхода, архивирование категории и перезапуск. Итого **2 UI-сценария PASS без пропусков**. Последняя правка касалась только тестового helper закрытия поиска, production-приложение и IPA не менялись. В smoke остаётся runtime warning `Invalid frame dimension (negative or non-finite)`; его устранение не заявлено. У миграционного прогона runtime warnings нет.

Оба сценария захвата снимков build 2 прошли: RU — PASS, EN — PASS. Подготовлены и просмотрены шесть RGB PNG 1206×2622 в `build/AppStore-Screenshots-build2/{ru,en}/`. Отдельно проверен русский главный экран в тёмной теме и с максимальным accessibility-размером текста; карточки переходят в одну колонку, видимые суммы и подписи не обрезаны. Это не полная проверка VoiceOver. Подробности — [APPSTORE-SCREENSHOTS.md](APPSTORE-SCREENSHOTS.md).

Архив `build/iWallet-2.0.0-build2.xcarchive` завершился `ARCHIVE SUCCEEDED`, экспорт `build/AppStore-build2/iWallet.ipa` — `EXPORT SUCCEEDED`; логи `/tmp/iwallet-build2-archive.log` и `/tmp/iwallet-build2-export.log`. IPA **11 549 549 байт**, SHA-256 `ac1650f45f4c7355b8a263ce8e3ac932da64d0e6f1cb5a95eb72b2726afbe9b3`. Независимо распакован в `build/IPA-Verification-build2/`: ZIP цел, Bundle ID `com.idevnva.iwallet`, версия `2.0.0(2)`, minimum iOS `17.0`, SDK `iphoneos27.2`, Apple Distribution, team `4243BL8MP3`; `codesign --verify --deep --strict` — PASS.

RealmSwift вложен, **10 854 800 байт**; четыре privacy manifest прочитаны, tracking отключён и collected data пуст. `ThirdPartyNotices.txt` точно совпадает с исходником и SHA-256 `3d6729c9937fdecf61642a6e2ff1fd90de563584c49074f50707762dad602d4d`. `ITSAppUsesNonExemptEncryption` — Boolean `false`. `nm`/`otool` повторно подтвердили системные CryptoKit/CommonCrypto. Полный машинно-читаемый результат — `build/QA/build2-ipa-verification.json`; криптографическая проверка — [EXPORT-COMPLIANCE-TECHNICAL.md](EXPORT-COMPLIANCE-TECHNICAL.md). Наличие manifests не заменяет сводный Privacy Report.

**Upload и обработка build 2 завершены:** `/tmp/iwallet-build2-upload.log` содержит `Upload succeeded`, `Uploaded iWallet`, `EXPORT SUCCEEDED`. В TestFlight строка загрузки `fc82dc7d-2780-4b33-afa3-dd08cdf88f8b` — «Завершено», `2.0.0 (2)` — «Готово к отправке»; подтверждение `build/QA/testflight-build2-processed.jpg`. Этот build выбран и сохранён в черновике App Store. Это не отправка на App Review, публикация или приглашение тестировщикам. Результаты физического iPhone, минимальной iOS 17, полной матрицы VoiceOver и обновления установленной старой версии ещё не подтверждены. В JSON проверки IPA зафиксирован более ранний момент — до начала upload.

### Исторические проверки build 1

Следующие результаты 55 unit-тестов, 2 UI-тестов, визуальной проверки, signing и экспорта относятся к **build 1** и сохранены для прослеживаемости.

Пользователь сообщил, что его исходная пользовательская база не сохранилась. Проверка на ней невозможна; это не означает, что у других старых пользователей нет данных.

Прошла проверка переноса **синтетической базы, созданной настоящим Realm 10.40.0 выпуска 2023 года**, с исходной schema 15. Она подтверждает чтение старого формата, а не сохранность неизвестных реальных баз. Прошли **55 тестов: 39 WalletCore и 16 LegacyMigration**. Проверены JSON roundtrip длинных полей, атомарное сохранение данных и receipt, повторный импорт, отказ без изменений при конфликте, сохранение receipt после правок, восстановление валюты после прерывания post-commit шага и сохранность старых файлов. Исходные проверки: [legacy tests](../Tests/LegacyMigrationTests/LegacyWalletMigrationTests.swift), [описание fixture](../Tests/Fixtures/README.md).

На симуляторе iOS 27.2 (`24B8117`) прошли ещё **2 UI-теста**: создание и редактирование расхода, архивирование категории и сохранность после перезапуска; полный интерфейс переноса старой базы с проверкой и подтверждением. Удаление операции покрыто unit-тестами, но отдельного UI-теста удаления не было. [UI-тесты](../Tests/WalletUITests/WalletSmokeTests.swift)

Визуально проверены RU в тёмной теме, EN в светлой теме и RU с крупным текстом. Исправленный заголовок баланса проверен на максимальном размере шрифта. Физический iPhone, минимальная iOS 17 и полная матрица VoiceOver ещё не проверены; эти проверки не подменяются результатами симулятора.

Архив build 1 `build/iWallet-2.0.0-signed.xcarchive` завершился с `ARCHIVE SUCCEEDED`, экспорт `build/AppStore/iWallet.ipa` — с `EXPORT SUCCEEDED`; логи: `/tmp/iwallet-signed-archive-final.log` и `/tmp/iwallet-appstore-export-final.log`. IPA размером **11 505 090 байт**, SHA-256 `eb0d853fd0df36298f9074193ce34a089ba2b2a063dc91b6b19b184c1aa608b0`. Извлечённое `build/IPA-Verification/Payload/iWallet.app` прошло `codesign --verify --deep --strict`, подписано Apple Distribution командой `4243BL8MP3`, версия `2.0.0(1)`. Вложены RealmSwift, все четыре privacy manifest и полный [ThirdPartyNotices.txt](../iWallet/Native/ThirdPartyNotices.txt) с проверенным SHA-256 `3d6729c9937fdecf61642a6e2ff1fd90de563584c49074f50707762dad602d4d`. Исправление Dynamic Type входит в build 1. Наличие manifests не объявляется готовым сводным Privacy Report.

Загрузка build 1 подтверждена `/tmp/iwallet-appstore-upload-after-login.log`: `Upload succeeded`, `Uploaded iWallet`, `EXPORT SUCCEEDED`. Xcode восстановился после ошибки создания `buildUploadFile` через новый upload; в логе остаются предупреждения о fallback и пропуске validation из-за non-validation error. Поэтому успех загрузки не объявляется прохождением полной серверной validation. В TestFlight подтверждена успешная повторная загрузка: после строки «Сбой» появилась строка «Завершено», а `2.0.0 (1)` имеет статус «Готово к отправке». Доказательство: `build/QA/testflight-build1-processed.jpg`. Это подтверждает обработку build, но не объявляет прохождение всех проверок метаданных или App Review.

## Требования Apple, подтверждённые на дату проверки

| Область | Требование и действие |
| --- | --- |
| Инструменты | С **28 апреля 2026**: Xcode 26+ и iOS/iPadOS 26 SDK+. В проверенном архиве — Xcode 27.2 и `iphoneos27.2` |
| Deployment target | С **9 сентября 2026**: iOS/iPadOS 13+. Выбранный iOS 17 удовлетворяет этому минимуму; он исключает обновление на устройствах, которые не поддерживают iOS 17 |
| Возрастной рейтинг | С **31 января 2026** обязательна новая анкета. Для текущих функций она пройдена, `4+` рассчитан и сохранён |
| ЕС | DSA non-trader выбран пользователем и сохранён; интерфейс compliance показывает Active |

Даты и минимумы: [Apple Upcoming Requirements](https://developer.apple.com/news/upcoming-requirements/). Это требования к загрузке, а не гарантия прохождения review. Xcode новее минимума также должен быть допустимой для submission версией.

## Временный Realm в переходной версии

Пользователь разрешил включить Realm как временный reader для переноса старых локальных данных. Основное хранилище новой версии — SwiftData. Решение временно использовать SDK уточняет первоначальный план полностью убрать сторонний runtime сразу: убрать reader можно после решения вопроса пользователей, которые пропускают промежуточные обновления.

Проверены исходники **Realm Swift v20.0.6**, а не произвольный `master`:

- [Package.swift](https://github.com/realm/realm-swift/blob/v20.0.6/Package.swift) содержит source targets `Realm` и `RealmSwift`, а не `binaryTarget`; Realm Core закреплён на `20.1.5`. Требуется Swift tools 6.2.1.
- Оба target копируют собственные `PrivacyInfo.xcprivacy` как ресурсы. В [Realm manifest](https://github.com/realm/realm-swift/blob/v20.0.6/Realm/PrivacyInfo.xcprivacy) и [RealmSwift manifest](https://github.com/realm/realm-swift/blob/v20.0.6/RealmSwift/PrivacyInfo.xcprivacy) указаны: `NSPrivacyTracking=false`, пустые collected data/tracking domains, `FileTimestamp: C617.1`, `DiskSpace: E174.1`.
- [Release v20.0.6](https://github.com/realm/realm-swift/releases/tag/v20.0.6) исправляет сборку/упаковку для Xcode 27 и перечисляет совместимость Xcode 26.1–27.0. Для Xcode 27.2 здесь подтверждены собственная сборка, вложение framework, подпись архива и экспорт IPA; это результаты проекта, а не расширенное обещание совместимости от Realm.
- В [CHANGELOG](https://github.com/realm/realm-swift/blob/v20.0.6/CHANGELOG.md) указано: в v20.0.0 удалены Atlas App Services и Device Sync; с v20.0.4 готовые бинарные поставки больше не подписываются MongoDB. Поэтому не заменять source SPM на скачанный prebuilt XCFramework без отдельной проверки требований подписи.

RealmSwift входит в [перечень Apple SDK](https://developer.apple.com/support/third-party-SDK-requirements/), для которых нужны privacy manifests. Apple требует подписи SDK в соответствующих случаях использования **бинарных зависимостей**. Вывод для выбранной поставки: source SPM не является скачанным prebuilt binary SDK, поэтому правило об отдельной подписи поставщика бинарного SDK к этому способу подключения не применяется. Обычная подпись приложения и встроенных исполняемых компонентов командой разработчика остаётся обязательной.

В архиве build 1 и извлечённых IPA build 1/build 2 проверены manifests приложения, Realm, RealmSwift и Realm Core, вложенный framework и уведомления о лицензиях; точные версии/revisions закреплены в `Package.resolved`. Полный сводный Privacy Report пока не отмечен выполненным. Технические доказательства — [EXPORT-COMPLIANCE-TECHNICAL.md](EXPORT-COMPLIANCE-TECHNICAL.md).

## App Privacy и работа с данными

В App Store Connect проверен и сохранён прежний ответ **Data Not Collected**; он не менялся на новую декларацию. Текущая реализация соответствует описанной локальной работе:

| Данные / компонент | Реализованная работа переходной версии | Подтверждение / границы |
| --- | --- | --- |
| Суммы, даты, заметки, категории | Локальное хранение SwiftData | Нет передачи на сервер разработчика или SDK |
| Старая база Realm | Локальное чтение для импорта с сохранением оригинала | Нет Atlas/Sync, загрузки базы на сервер или финансовых данных в логах |
| Настройки приложения | Собственный UserDefaults | `CA92.1` прочитан из manifest подписанного архива |
| Экспорт / JSON-импорт | Файл создаётся или выбирается по действию пользователя; импорт выполняется локально | Приложение не отправляет файл автоматически; объяснить содержимое и аддитивный режим импорта |
| Аналитика, реклама, tracking | Не предусмотрены в текущем приложении | Проверить зависимости и release binary; не добавлять ATT без реального tracking |

Apple не считает сбором данные, обрабатываемые только на устройстве и не передаваемые за его пределы разработчику/партнёрам. Это основание для сохранённого ответа применительно к текущей локальной реализации. [App Privacy Details](https://developer.apple.com/app-store/app-privacy-details/)

Проверенные manifests приложения и Realm-компонентов содержат `tracking=false` и пустые collected data/tracking domains. Опубликованная политика объясняет пользовательский экспорт, сохранённые legacy-файлы и добровольную переписку с поддержкой; она не обещает поведение резервных копий ОС. Privacy URL сохранён для обоих языков. Окончательное решение об отправке версии и согласованности правовых заявлений с release candidate остаётся частью финального review.

Для собственных настроек применим `CA92.1`; manifests Realm, RealmSwift и Core содержат FileTimestamp `C617.1` и DiskSpace `E174.1`. Эти причины проверены в ресурсах подписанного архива. [Официальные категории и причины](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype)

**Криптографическая проверка выполнена:** CommonCrypto Realm разрешается в системную `libSystem`, SHA-256 приложения — в CryptoKit. В подписанном `Info.plist` установлен Boolean `ITSAppUsesNonExemptEncryption=false`; вывод об использовании криптографии Apple OS подтверждён исходниками и Mach-O. Наличие `REALM_ENABLE_ENCRYPTION=1` не оставлено самостоятельным блокером. Подробности и пределы — [техническая записка](EXPORT-COMPLIANCE-TECHNICAL.md); [официальная таблица Apple](https://developer.apple.com/help/app-store-connect/reference/app-information/export-compliance-documentation-for-encryption).

## Условия допуска переходной версии

Исторические результаты build 1 сохранены выше; текущая готовность build 2:

- [x] 60 unit-тестов (44 WalletCore + 16 LegacyMigration), включая schema 15, суммы/ID/связи/даты, оригиналы, retry, receipt, JSON и средний расход.
- [x] UI-миграция build 2: 1 passed, 0 failed, 0 skipped; SHA исходника и snapshot не изменился.
- [x] Smoke build 2: создание/редактирование расхода, архивирование категории и перезапуск; 1 passed, 0 failed, 0 skipped. Вместе с миграцией — 2 UI PASS. Удаление покрыто unit-тестами; предупреждение Invalid frame сохраняется.
- [x] Шесть новых снимков RU/EN получены успешными capture-сценариями и визуально проверены; русский Home проверен в тёмной теме и с максимальным текстом.
- [x] Build 2: signed archive 2.0.0(2), App Store IPA export и независимая deep/strict codesign проверка Apple Distribution приложения; team `4243BL8MP3`.
- [x] RealmSwift, четыре manifests, точный текст лицензий и Boolean `ITSAppUsesNonExemptEncryption=false` проверены в IPA build 2.
- [x] Описания RU/EN, What’s New и Review Notes обновлены под build 2 и сохранены. Публичные support/privacy URL, ручной выпуск, рейтинг 4+, non-trader и активное соглашение подтверждены.
- [x] Вход Xcode подтверждён; build 1 загружен и обработан Apple.
- [ ] Завершить сводный Privacy Report и проверить ссылки из установленной финальной сборки.
- [ ] Проверить физический iPhone, минимальную iOS 17, полный сценарий VoiceOver и обновление установленной старой версии на устройстве.
- [x] Все превью новых 3+3 снимков build 2 в App Store Connect обработаны и визуально проверены; порядок — обзор, история, категории. [Воспроизведение](APPSTORE-SCREENSHOTS.md).
- [x] Build 2 успешно загружен в Apple; upload-лог прочитан.
- [x] Build 2 обработан Apple: строка загрузки «Завершено», TestFlight «Готово к отправке».
- [x] Build 2 выбран и сохранён в черновике App Store; обновлённые Review Notes прочитаны после сохранения.
- [ ] Перед отправкой сверить актуальность сохранённых review-контактов. Ручной выпуск остаётся отдельным действием после одобрения.

Проверка симулятора не утверждает результат физического обновления или TestFlight. План миграции — [LEGACY-MIGRATION.md](LEGACY-MIGRATION.md); тексты карточки — [STORE-METADATA.md](STORE-METADATA.md).

## Сведения карточки и финальная сверка

### Повторный экспорт и загрузка готового архива

Команды приведены как справка для build 2; архив, экспорт и upload уже завершены. Повторная загрузка того же build не требуется. На компьютере установлены две версии Xcode; `DEVELOPER_DIR` выбирает проверенную `/Applications/Xcode.app`. Вход в аккаунт команды `4243BL8MP3` подтверждён.

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -exportArchive \
  -archivePath build/iWallet-2.0.0-build2.xcarchive \
  -exportOptionsPlist Configuration/ExportOptions-AppStore.plist \
  -exportPath build/AppStore-build2 -allowProvisioningUpdates
```

Следующая команда отправляет сборку в App Store Connect. Она не отправляет версию на App Review и не публикует приложение:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -exportArchive \
  -archivePath build/iWallet-2.0.0-build2.xcarchive \
  -exportOptionsPlist Configuration/UploadOptions-AppStore.plist \
  -exportPath build/AppStoreUpload-build2 -allowProvisioningUpdates
```

Загрузка и завершение обработки `2.0.0 (1)` и `2.0.0 (2)` подтверждены; оба build видны в TestFlight как «Готово к отправке». Build 2 выбран и сохранён в черновике App Store; режим выпуска остаётся ручным. Пароли, app-specific passwords и API keys не добавляются в репозиторий.

### Сохранённые поля

| Поле | Значение подготовки |
| --- | --- |
| Support URL | [Поддержка iWallet](https://github.com/nvavna/iWallet-1/blob/restoration/foundation/docs/SUPPORT.md) — опубликовано, HTTP 200 без авторизации проверен 5 ноября 2026 |
| Privacy Policy URL | [Политика iWallet](https://github.com/nvavna/iWallet-1/blob/restoration/foundation/docs/PRIVACY.md) — опубликовано, HTTP 200 без авторизации проверен 5 ноября 2026 |
| Support email | `idevnva@icloud.com` — одобрен пользователем |
| Review contact | Существующие контакты карточки сохранены; новые имя/телефон не выдумывались. Владелец может подтвердить их актуальность перед финальной отправкой |
| Copyright / категория | Сверить значения действующей карточки при финальном review; новые значения этой проверкой не устанавливались |
| Версия/build | `2.0.0(2)` обработан Apple; выбран и сохранён в черновике App Store. Build 1 — исторический тестовый вариант |
| Проверка миграции | Build 2: 16 legacy unit-тестов и 1 UI-тест PASS без пропуска; schema 15 / Realm 10.40.0 synthetic fixture, исходные байты и snapshot сохранены. Реальные исходные данные владельца отсутствуют |
| Signing / archive | Build 2: archive/export SUCCEEDED; независимая проверка IPA — Apple Distribution, team `4243BL8MP3`, deep/strict codesign PASS |
| Загрузка Apple | Build 2: строка `fc82dc7d-2780-4b33-afa3-dd08cdf88f8b` — «Завершено», TestFlight «Готово к отправке»; App Review, публикации и приглашений нет |

Публичные тексты опубликованы в ветке `restoration/foundation`, commit `ffb019b`. Обе страницы вернули HTTP 200 без авторизации 5 ноября 2026; ссылки содержат одобренный email. Support URL и Privacy Policy URL сохранены для русского и английского черновиков 2.0.0; необязательный прежний Privacy Choices URL удалён. Ссылку внутри выбранной релизной сборки ещё проверить на устройстве. Build 2 обработан Apple; он выбран и сохранён в черновике. Отправка на review не выполнена.

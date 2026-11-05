# Подготовка переходного релиза iWallet

Состояние на **5 ноября 2026 года**: существующая карточка восстановлена, черновик **2.0.0** сохранён в App Store Connect. **Финальный подписанный archive и App Store IPA с уведомлениями о лицензиях и исправлением Dynamic Type собраны и проверены.** Загрузка в Apple заблокирована входом Xcode Accounts (`missing Xcode-Username`); выполняется передача этого шага пользователю. Обработанной Apple сборки нет, версия на review не отправлена и не выпущена.

## Идентификаторы и карточка

| Поле | Подготовленное значение / статус |
| --- | --- |
| Репозиторий | [nvavna/iWallet-1](https://github.com/nvavna/iWallet-1) |
| Bundle ID | `com.idevnva.iwallet` — сохранить для обновления прежнего приложения |
| Apple ID | `6447585809` — подтверждён в App Store Connect |
| SKU | `001` — подтверждён в App Store Connect |
| Последняя прежняя версия | `1.1.8`, build `1` — подтверждена в App Store Connect |
| Версия и build | `2.0.0`, build `1` — проверены в подписанном архиве |
| Черновик App Store Connect | [2.0.0 — «Подготовка к отправке»](https://appstoreconnect.apple.com/apps/6447585809/distribution/ios/version/inflight), создание подтверждено |
| Режим выпуска и доступность | Выбран ручной выпуск; баннер о снятии старого приложения с продажи остаётся |
| Метаданные | Названия, subtitle, description, promotional text, keywords и базовые What’s New сохранены для RU/EN |
| Review Notes | Краткий сценарий и описание локальной legacy-миграции сохранены; тот же текст повторно прочитан после переключения языка на RU. Точная копия — [STORE-METADATA.md](STORE-METADATA.md) |
| Marketing URL | Необязательное поле пусто, сохранение и пустое значение подтверждены для RU/EN. Прежний `https://idevnva.com/iwallet` не разрешается в DNS: curl (6), HTTP 000 |
| Возрастной рейтинг | Семь шагов актуальной анкеты заполнены по фактическим функциям и содержимому; рассчитан и сохранён рейтинг `4+` |
| DSA | Пользователь явно выбрал non-trader; настройка сохранена, интерфейс показывает выполнение всех compliance requirements и статус Active |
| Соглашение о бесплатных приложениях | Active, срок 1 ноября 2026 — 8 марта 2027 |
| Минимальная iOS | iOS 17 для нативной версии на SwiftData |
| Доступ и состояние | Аккаунт доступен; iWallet найден в «Удалённых приложениях» с датой удаления 10 марта 2026 года. Восстановление карточки выполнено 5 ноября 2026 года |

До восстановления публичная [страница приложения](https://apps.apple.com/app/id6447585809) не была доступна через инструмент чтения, а Apple lookup для [России](https://itunes.apple.com/lookup?id=6447585809&country=ru) и [США](https://itunes.apple.com/lookup?id=6447585809&country=us) вернул `resultCount: 0`. После входа в App Store Connect существующая карточка и её идентификаторы подтверждены. После восстановления действие Restore исчезло, доступны Transfer, Edit user access и Delete app. Это подтверждает восстановление записи в аккаунте, **но не доступность новой версии для загрузки из магазина**.

Создание черновика 2.0.0 не означает отправку на review или возобновление продаж. Причину удаления 10 марта не следует подменять предположением об App Store Improvements. Восстановление удалённой записи и выпуск новой версии — разные действия. [Восстановление записи](https://developer.apple.com/help/app-store-connect/create-an-app-record/remove-an-app)

## Подтверждённая проверка данных и её пределы

Пользователь сообщил, что его исходная пользовательская база не сохранилась. Проверка на ней невозможна; это не означает, что у других старых пользователей нет данных.

Прошла проверка переноса **синтетической базы, созданной настоящим Realm 10.40.0 выпуска 2023 года**, с исходной schema 15. Она подтверждает чтение старого формата, а не сохранность неизвестных реальных баз. Прошли **55 тестов: 39 WalletCore и 16 LegacyMigration**. Проверены JSON roundtrip длинных полей, атомарное сохранение данных и receipt, повторный импорт, отказ без изменений при конфликте, сохранение receipt после правок, восстановление валюты после прерывания post-commit шага и сохранность старых файлов. Исходные проверки: [legacy tests](../Tests/LegacyMigrationTests/LegacyWalletMigrationTests.swift), [описание fixture](../Tests/Fixtures/README.md).

На симуляторе iOS 27.2 (`24B8117`) прошли ещё **2 UI-теста**: создание и редактирование расхода, архивирование категории и сохранность после перезапуска; полный интерфейс переноса старой базы с проверкой и подтверждением. Удаление операции покрыто unit-тестами, но отдельного UI-теста удаления не было. [UI-тесты](../Tests/WalletUITests/WalletSmokeTests.swift)

Визуально проверены RU в тёмной теме, EN в светлой теме и RU с крупным текстом. Исправленный заголовок баланса проверен на максимальном размере шрифта. Физический iPhone, минимальная iOS 17 и полная матрица VoiceOver ещё не проверены; эти проверки не подменяются результатами симулятора.

Финальный `build/iWallet-2.0.0-signed.xcarchive` завершился с `ARCHIVE SUCCEEDED`, экспорт `build/AppStore/iWallet.ipa` — с `EXPORT SUCCEEDED`; логи: `/tmp/iwallet-signed-archive-final.log` и `/tmp/iwallet-appstore-export-final.log`. IPA размером **11 505 090 байт**, SHA-256 `eb0d853fd0df36298f9074193ce34a089ba2b2a063dc91b6b19b184c1aa608b0`. Извлечённое `build/IPA-Verification/Payload/iWallet.app` прошло `codesign --verify --deep --strict`, подписано Apple Distribution командой `4243BL8MP3`, версия `2.0.0(1)`. Вложены RealmSwift, все четыре privacy manifest и полный [ThirdPartyNotices.txt](../iWallet/Native/ThirdPartyNotices.txt) с проверенным SHA-256 `3d6729c9937fdecf61642a6e2ff1fd90de563584c49074f50707762dad602d4d`. Исправление Dynamic Type входит в финальную сборку. Наличие manifests не объявляется готовым сводным Privacy Report.

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

В финальном архиве и извлечённом IPA проверены manifests приложения, Realm, RealmSwift и Realm Core, вложенный framework и уведомления о лицензиях; точные версии/revisions закреплены в `Package.resolved`. Полный сводный Privacy Report пока не отмечен выполненным. Технические доказательства — [EXPORT-COMPLIANCE-TECHNICAL.md](EXPORT-COMPLIANCE-TECHNICAL.md).

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

Подтверждённые результаты и оставшиеся действия разделены по фактическому состоянию:

- [x] 55 unit-тестов, включая schema 15, проверку сумм/ID/связей/дат, оригиналов, retry, receipt и JSON-импорта.
- [x] 2 UI-теста: создание/редактирование расхода, архивирование категории/перезапуск и полный сценарий миграции на симуляторе; удаление проверено unit-тестами.
- [x] RU dark, EN light, RU large text; исправленный баланс при максимальном размере текста.
- [x] Финальный signed archive 2.0.0(1), App Store IPA export и deep/strict codesign извлечённого Apple Distribution приложения.
- [x] RU/EN метаданные, Review Notes и публичные support/privacy URL сохранены; ручной выпуск, рейтинг 4+, non-trader и активное соглашение подтверждены.
- [x] Финальная сборка с ThirdPartyNotices и Dynamic Type fix; RealmSwift, четыре manifests и точный текст лицензий проверены в IPA.
- [ ] Завершить сводный Privacy Report и проверить ссылки из установленной финальной сборки.
- [ ] Проверить физический iPhone, минимальную iOS 17, полный сценарий VoiceOver и обновление установленной старой версии на устройстве.
- [x] Подготовлены и визуально проверены 6 реальных скриншотов RU/EN (1206×2622, RGB PNG); в черновик загружены по 3 снимка каждого языка для iPhone с Dynamic Island (средний дисплей). [Воспроизведение](APPSTORE-SCREENSHOTS.md).
- [ ] Выбрать обработанный Apple build и сверить review notes/контакты перед отправкой.
- [ ] Завершить вход пользователя в Xcode Accounts, устранить `missing Xcode-Username`, загрузить IPA и дождаться обработки Apple; затем отдельно отправить версию на review. Ручной выпуск остаётся отдельным действием после одобрения.

Проверка симулятора не утверждает результат физического обновления или TestFlight. План миграции — [LEGACY-MIGRATION.md](LEGACY-MIGRATION.md); тексты карточки — [STORE-METADATA.md](STORE-METADATA.md).

## Сведения карточки и финальная сверка

### Повторный экспорт и загрузка готового архива

Команды выполняются из корня проекта. На компьютере установлены две версии Xcode; `DEVELOPER_DIR` ниже выбирает проверенную `/Applications/Xcode.app` только для этой команды. Перед загрузкой в её **Settings → Apple Accounts** должен быть выполнен вход в аккаунт команды `4243BL8MP3`.

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -exportArchive \
  -archivePath build/iWallet-2.0.0-signed.xcarchive \
  -exportOptionsPlist Configuration/ExportOptions-AppStore.plist \
  -exportPath build/AppStore -allowProvisioningUpdates
```

Следующая команда отправляет сборку в App Store Connect. Она не отправляет версию на App Review и не публикует приложение:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -exportArchive \
  -archivePath build/iWallet-2.0.0-signed.xcarchive \
  -exportOptionsPlist Configuration/UploadOptions-AppStore.plist \
  -exportPath build/AppStoreUpload -allowProvisioningUpdates
```

После успешной загрузки дождаться обработки Apple и проверить появление `2.0.0 (1)` в TestFlight. Повторный экспорт сам по себе это не подтверждает. Пароли, app-specific passwords и API keys не добавляются в репозиторий.

### Сохранённые поля

| Поле | Значение подготовки |
| --- | --- |
| Support URL | [Поддержка iWallet](https://github.com/nvavna/iWallet-1/blob/restoration/foundation/docs/SUPPORT.md) — опубликовано, HTTP 200 без авторизации проверен 5 ноября 2026 |
| Privacy Policy URL | [Политика iWallet](https://github.com/nvavna/iWallet-1/blob/restoration/foundation/docs/PRIVACY.md) — опубликовано, HTTP 200 без авторизации проверен 5 ноября 2026 |
| Support email | `idevnva@icloud.com` — одобрен пользователем |
| Review contact | Существующие контакты карточки сохранены; новые имя/телефон не выдумывались. Владелец может подтвердить их актуальность перед финальной отправкой |
| Copyright / категория | Сверить значения действующей карточки при финальном review; новые значения этой проверкой не устанавливались |
| Версия/build | `2.0.0(1)` подтверждён в архиве; после загрузки сопоставить с обработанным Apple build |
| Проверка миграции | Schema 15 / Realm 10.40.0 synthetic fixture, 16 legacy unit-тестов и UI-сценарий; реальные исходные данные владельца отсутствуют |
| Signing / archive | Финальные signed archive и App Store IPA проверены; Apple Distribution, team `4243BL8MP3`, deep/strict codesign PASS |
| Загрузка Apple | Заблокирована Xcode Accounts / `missing Xcode-Username`; вход передан пользователю. Обработанной сборки пока нет |

Публичные тексты опубликованы в ветке `restoration/foundation`, commit `ffb019b`. Обе страницы вернули HTTP 200 без авторизации 5 ноября 2026; ссылки содержат одобренный email. Support URL и Privacy Policy URL сохранены для русского и английского черновиков 2.0.0; необязательный прежний Privacy Choices URL удалён. Ссылку внутри финальной установленной сборки ещё проверить на устройстве. Готовый IPA пока не загружен из-за входа Xcode; отправка на review не выполнена.

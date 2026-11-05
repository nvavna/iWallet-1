# Криптография: техническая проверка переходной версии

Проверено **5 ноября 2026 года**, повторно для **build 2, версия 2.0.0(2)**. Независимо проверен `build/AppStore-build2/iWallet.ipa`, извлечённый в новый каталог `build/IPA-Verification-build2/`. В подписанном приложении `ITSAppUsesNonExemptEncryption` — Boolean **`false`**. Проверка не меняла исходники, настройки сборки или ответы App Store Connect и не запускала build/upload. Записан артефакт проверки `build/QA/build2-ipa-verification.json`.

## Текущий артефакт build 2

Архив `build/iWallet-2.0.0-build2.xcarchive` и экспорт `build/AppStore-build2/iWallet.ipa` завершены: `/tmp/iwallet-build2-archive.log` содержит `ARCHIVE SUCCEEDED`, `/tmp/iwallet-build2-export.log` — `EXPORT SUCCEEDED`. ZIP цел; `com.idevnva.iwallet`, версия `2.0.0`, build `2`, SDK `iphoneos27.2`, minimum iOS `17.0`. `codesign --verify --deep --strict` для извлечённого приложения — PASS; подпись **Apple Distribution**, команда **`4243BL8MP3`**.

| Артефакт build 2 | SHA-256 / размер |
| --- | --- |
| `build/AppStore-build2/iWallet.ipa` | `ac1650f45f4c7355b8a263ce8e3ac932da64d0e6f1cb5a95eb72b2726afbe9b3`, **11 549 549 байт** |
| IPA `iWallet` executable | `db1221528a1e9639073bd58d209de9d6a8e82804925baf69783bc682a2519103` |
| IPA `Frameworks/RealmSwift.framework/RealmSwift` | `a0a707a75d323ff666798af420839bd0488f9974f81086dad36f8da4dafccd07`, **10 854 800 байт** |
| IPA `ThirdPartyNotices.txt` | `3d6729c9937fdecf61642a6e2ff1fd90de563584c49074f50707762dad602d4d`, точное совпадение с исходником |

Для executable и RealmSwift из IPA build 2 повторно выполнены `otool -L` и `nm -m`: SHA256 приложения разрешается в системный CryptoKit; все восемь криптографических/случайных символов Realm ниже — внешние импорты `from libSystem`. OpenSSL/libcrypto/libssl в зависимостях нет; поиск символов `EVP_*`, `OPENSSL*`, `AES_*`, `sha_init`, `sha_process`, `sha_done` не дал совпадений. Это подтверждает прежний технический вывод для конкретного нового артефакта.

Прочитаны все четыре manifests из IPA build 2: приложения (`CA92.1`), Realm, RealmSwift и Realm Core (`C617.1`, `E174.1`). У всех `NSPrivacyTracking=false`, tracking domains и collected data пусты. Наличие и содержимое manifests не объявляются готовым сводным Xcode Privacy Report.

Build 2 прошёл 60 unit-тестов (44 native + 16 legacy), UI-миграцию с неизменными байтами исходника и snapshot, а также smoke-сценарий создания/редактирования расхода, архивирования категории и перезапуска. RU/EN capture-сценарии и визуальная проверка русского Home в тёмной теме/с максимальным текстом прошли. В smoke-логе остаётся `Invalid frame dimension (negative or non-finite)`; результат не объявляет устранение предупреждения или завершение проверки физического iPhone/iOS 17/VoiceOver. Детали — [APP-STORE-RELEASE.md](APP-STORE-RELEASE.md).

После проверки IPA build 2 отдельно загружен в Apple: `/tmp/iwallet-build2-upload.log` содержит `Upload succeeded`, `Uploaded iWallet`, `EXPORT SUCCEEDED`. Обработка подтверждена в TestFlight: строка загрузки `fc82dc7d-2780-4b33-afa3-dd08cdf88f8b` — «Завершено», `2.0.0 (2)` — «Готово к отправке». Подтверждение — `build/QA/testflight-build2-processed.jpg`. Build 2 выбран и сохранён в черновике App Store; режим выпуска остаётся ручным. JSON проверки IPA сохраняет состояние на момент его создания — до upload. Отправка версии на review, публикация и приглашения тестировщикам не выполнялись.

## Историческая проверка build 1

Archive и App Store IPA export build 1 с уведомлениями о лицензиях и исправлением Dynamic Type завершены: `/tmp/iwallet-signed-archive-final.log` содержит `ARCHIVE SUCCEEDED`, `/tmp/iwallet-appstore-export-final.log` — `EXPORT SUCCEEDED`. Извлечённое `build/IPA-Verification/Payload/iWallet.app` проверено отдельно. После подтверждённого входа Xcode build 1 успешно загружен: `/tmp/iwallet-appstore-upload-after-login.log` содержит `Upload succeeded`, `Uploaded iWallet` и `EXPORT SUCCEEDED`.

Upload-лог также содержит восстановленный fallback после ошибки `buildUploadFile` и пропуск validation из-за non-validation error. Повторная загрузка успешно обработана Apple: в TestFlight после первой строки «Сбой» подтверждена строка «Завершено», `2.0.0 (1)` показывает «Готово к отправке» (`build/QA/testflight-build1-processed.jpg`). Это не утверждение о прохождении всех проверок метаданных. Отправка на review, публикация и приглашения тестировщикам не выполнялись.

**Build 1 не является финальным release candidate:** пользователь выбрал рестайлинг ближе к оригиналу — Home 2×2, нейтральные карточки, плавающий «+» и исходную композицию строк. Исторические результаты и хеши build 1 сохранены ниже; текущий build 2 проверен отдельно выше.

**Вывод для build 1 и build 2:** установленное `ITSAppUsesNonExemptEncryption = false` технически соответствует проверенной Apple-конфигурации и классификации «криптография, предоставляемая Apple OS». Приложение использует системный CryptoKit; криптографические примитивы Realm реализуются системным CommonCrypto. Собственная поставляемая реализация AES/SHA/HMAC или OpenSSL в проверенных библиотеках не обнаружена. Повторная проверка executable и вложенного RealmSwift в IPA build 2 подтвердила тот же состав зависимостей и вызовов.

## Что говорит Apple

В официальной таблице категория **“Your app uses encryption limited to that within the Apple operating system”** не требует загрузки документации в App Store Connect. Стандартный алгоритм, реализованный вне Apple OS, выделен отдельно. [Export compliance documentation for encryption](https://developer.apple.com/help/app-store-connect/reference/app-information/export-compliance-documentation-for-encryption)

Apple разрешает `ITSAppUsesNonExemptEncryption = NO`, если приложение **вместе со сторонними библиотеками** не использует криптографию либо использует только освобождённые формы. Поэтому `false` не означает, что в бинарнике вообще нет криптографических вызовов. [Документация ключа](https://developer.apple.com/documentation/bundleresources/information-property-list/itsappusesnonexemptencryption)

Анкета учитывает используемую, доступную и включённую криптографию, в том числе функции Apple OS. Из одного отсутствия `encryptionKey` нельзя заключить «криптографии нет». [Overview of export compliance](https://developer.apple.com/help/app-store-connect/manage-app-information/overview-of-export-compliance)

## Исходники и условия компиляции

Версии подтверждены обоими `Package.resolved` и `git rev-parse HEAD` локальных checkout:

- Realm Swift **20.0.6**, revision `a40ced79265b644a896e393b0f3a37e7916e7de3`.
- Realm Core **20.1.5**, revision `b4192c46305570577c4d08df790fddec5ab3aa04`.

| Участок | Подтверждённое поведение |
| --- | --- |
| [LegacyWalletMigration.swift](../iWallet/Native/LegacyWalletMigration.swift), `stableID` и `sourceDigest` | `CryptoKit.SHA256` вычисляет стабильные ID и контрольные суммы файлов. Это хеширование, не шифрование пользовательской базы |
| `Realm.Configuration` и `schemaVersionAtURL` в импортёре | `encryptionKey` не передаётся; в [Configuration](https://github.com/realm/realm-swift/blob/a40ced79265b644a896e393b0f3a37e7916e7de3/RealmSwift/RealmConfiguration.swift#L79) и [Migration](https://github.com/realm/realm-swift/blob/a40ced79265b644a896e393b0f3a37e7916e7de3/RealmSwift/Migration.swift#L53) default — `nil` |
| [Core file.cpp](https://github.com/realm/realm-core/blob/b4192c46305570577c4d08df790fddec5ab3aa04/src/realm/util/file.cpp#L1656) | `File::set_encryption_key` создаёт `EncryptedFile` только при ненулевом ключе; иначе сбрасывает слой шифрования |
| [Core features.h](https://github.com/realm/realm-core/blob/b4192c46305570577c4d08df790fddec5ab3aa04/src/realm/util/features.h#L239) | На Darwin (`__APPLE__` + `__MACH__`) задаёт `REALM_PLATFORM_APPLE = 1` |
| [Core encrypted_file_mapping.cpp](https://github.com/realm/realm-core/blob/b4192c46305570577c4d08df790fddec5ab3aa04/src/realm/util/encrypted_file_mapping.cpp#L286) | Apple-ветка вызывает `CCCryptorCreate` с AES/256-битным ключом, затем `CCCryptorReset`, `CCCryptorUpdate`, `CCCryptorRelease`; это CommonCrypto AES-CBC. Начальный случайный буфер — системный `arc4random_buf` |
| [Core sha_crypto.cpp](https://github.com/realm/realm-core/blob/b4192c46305570577c4d08df790fddec5ab3aa04/src/realm/util/sha_crypto.cpp#L184) | Apple-ветки вызывают `CC_SHA1`, `CC_SHA256`, `CCHmac` для SHA-224/SHA-256. Файловый слой использует HMAC-SHA-224 |
| [Core Package.swift](https://github.com/realm/realm-core/blob/b4192c46305570577c4d08df790fddec5ab3aa04/Package.swift#L355) | `REALM_ENABLE_ENCRYPTION = 1` включает поддержку файлового шифрования. Target исключает `external`; зависимости Core — Bid/s2geometry, системные Foundation/Security. OpenSSL не подключён |

Realm содержит собственную логику страниц, IV, HMAC и формата файла, но в Apple-ветке криптографические алгоритмы выполняет CommonCrypto. Наличие этой обвязки и `REALM_ENABLE_ENCRYPTION = 1` само по себе не доказывает поставку собственной реализации алгоритмов. Не-Apple ветки OpenSSL/Windows и bundled SHA fallback существуют в исходниках, но не выбираются в проверенной Apple-сборке.

## Что находится в собранных библиотеках

Проверены `otool -L`, `nm -u`, `nm -m` для исходных build products, затем повторно для executable приложения и вложенного RealmSwift из подписанного архива:

| Обозначение | Файл |
| --- | --- |
| macOS Debug | `.build/out/Products/Debug/libRealmSwift.dylib` |
| iOS Simulator Debug | `build/DerivedData/Build/Products/Debug-iphonesimulator/iWallet.app/Frameworks/RealmSwift.framework/RealmSwift` |
| iOS Release product | `build/DerivedData/Build/Intermediates.noindex/ArchiveIntermediates/iWallet/IntermediateBuildFilesPath/UninstalledProducts/iphoneos/RealmSwift.framework/RealmSwift` |
| Signed archive RealmSwift | `build/iWallet-2.0.0-signed.xcarchive/Products/Applications/iWallet.app/Frameworks/RealmSwift.framework/RealmSwift` |
| Signed archive app | `build/iWallet-2.0.0-signed.xcarchive/Products/Applications/iWallet.app/iWallet` |
| Build 1 IPA RealmSwift | `build/IPA-Verification/Payload/iWallet.app/Frameworks/RealmSwift.framework/RealmSwift` |
| Build 1 IPA app | `build/IPA-Verification/Payload/iWallet.app/iWallet` |
| Build 2 IPA RealmSwift | `build/IPA-Verification-build2/Payload/iWallet.app/Frameworks/RealmSwift.framework/RealmSwift` |
| Build 2 IPA app | `build/IPA-Verification-build2/Payload/iWallet.app/iWallet` |

В проверенных RealmSwift binaries, включая framework из IPA build 1 и build 2, `nm -m` показывает один набор внешних символов **`from libSystem`**:

```text
CCCryptorCreate, CCCryptorRelease, CCCryptorReset, CCCryptorUpdate
CCHmac, CC_SHA1, CC_SHA256, arc4random_buf
```

В `otool -L` есть системные `Security.framework` и `libSystem.B.dylib`; библиотек OpenSSL/libcrypto/libssl нет. Поиск таблиц символов не обнаружил `EVP_*`, `OPENSSL*`, собственных `AES_*`, `SHA*`, `sha_init`, `sha_process` или `sha_done`. Это подтверждает проверенные условные ветки исходников, а не отдельное доказательство отсутствия любых возможных алгоритмов во всех будущих сборках.

У iOS Debug `iWallet.debug.dylib`, Release executable, executable из подписанного архива и IPA build 1/build 2 присутствует зависимость `/System/Library/Frameworks/CryptoKit.framework/CryptoKit`; импорты `SHA256`/`SHA256Digest` разрешаются в CryptoKit.

SHA-256 ранних build products (историческая проверка):

```text
macOS Debug:           76a241d2faadd2b665d40d753f93f18e4f315c2ff8a9f1a9988bb452523ae3d6
iOS Simulator Debug:  7d4de43f14cbad887df3c76d383a002365c637e980dbfde377b7204ecbc961ea
iOS Release product:  75408f31fa6414eddd5566ec64c6e373f8d6a328d3922111957acae5f4faf1c7
```

SHA-256 проверенных артефактов build 1. Хеши executable/framework в archive и IPA различаются после переподписи для distribution:

```text
Build 1 archive app:        8ed3443c3a30eec99fc2aa10f7acc6f9de755b5abe75143aee7e98ee240037d5
Build 1 archive RealmSwift: d7477b30386898537243ca75e06d6370f20ee07e1914973373678307915dfb23
Build 1 IPA app:            8474503dd24542bc2fed32e5bea8217bfdf870cf7d2d5b22f4cc4d6da0d6608a
Build 1 IPA RealmSwift:     92743c9c40d572a48752e6444dabaa44e581e32efbb425d49b05339188222a37
ThirdPartyNotices.txt:    3d6729c9937fdecf61642a6e2ff1fd90de563584c49074f50707762dad602d4d
build/AppStore/iWallet.ipa:
eb0d853fd0df36298f9074193ce34a089ba2b2a063dc91b6b19b184c1aa608b0
```

Размер проверенного IPA build 1 — **11 505 090 байт**. Хеш встроенного ThirdPartyNotices совпадает с проверенным полным текстом лицензий.

## Подписанный архив и manifests build 1

В подписанном `Info.plist` проверены: Bundle ID `com.idevnva.iwallet`, версия `2.0.0`, build `1`, SDK `iphoneos27.2`, `ITSAppUsesNonExemptEncryption = false` типа Boolean. Вложенный `RealmSwift.framework/RealmSwift` присутствует и занимает **10 854 800 байт**.

`codesign --verify --deep --strict` прошёл для подписанного архива build 1 и повторно для приложения, извлечённого из его IPA. Archive использует **Apple Development**, команда `4243BL8MP3`, сертификат `QV5HFTMMF5`; извлечённое distribution-приложение использует **Apple Distribution**, команда `4243BL8MP3`. Экспорт и последующая загрузка build 1 в Apple успешно завершены.

Внутри подписанного `iWallet.app` build 1 прочитаны все четыре property-list manifest; их наличие повторно проверено в его IPA:

| Файл | Required Reason API |
| --- | --- |
| `PrivacyInfo.xcprivacy` | UserDefaults — `CA92.1` |
| `Realm_Realm.bundle/PrivacyInfo.xcprivacy` | FileTimestamp — `C617.1`; DiskSpace — `E174.1` |
| `Realm_RealmSwift.bundle/PrivacyInfo.xcprivacy` | FileTimestamp — `C617.1`; DiskSpace — `E174.1` |
| `RealmDatabase_RealmCoreResources.bundle/PrivacyInfo.xcprivacy` | FileTimestamp — `C617.1`; DiskSpace — `E174.1` |

Во всех четырёх `NSPrivacyTracking = false`, `NSPrivacyTrackingDomains = []` и `NSPrivacyCollectedDataTypes = []`. Это проверка наличия и содержимого manifest в подписанном архиве; сводный Xcode Privacy Report этим не объявляется сформированным или проверенным.

Подпись, ресурсы и криптографические зависимости IPA build 1 и build 2 проверены; оба экспорта, загрузки и обработка Apple завершены успешно. Build 2 виден в TestFlight как «Готово к отправке», он выбран и сохранён в черновике App Store. Отправка на review, публикация и приглашения тестировщикам не выполнялись. При изменении зависимостей или криптографического кода нужно повторно проверить артефакт и пересмотреть технический вывод.

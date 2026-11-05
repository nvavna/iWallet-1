# Криптография: техническая проверка переходной версии

Проверено **5 ноября 2026 года**, включая фактическое содержимое `build/iWallet-2.0.0-signed.xcarchive`. В подписанном приложении `ITSAppUsesNonExemptEncryption` уже установлен в Boolean **`false`**. Эта повторная проверка была read-only: исходники, настройки сборки и ответы App Store Connect не менялись.

После этой проверки App Store IPA export успешно завершён после входа пользователя в Xcode. Финальная пересборка архива и повторный экспорт с уведомлениями о лицензиях и исправлением Dynamic Type сейчас выполняются. Приведённые ниже хеши относятся к проверенному предыдущему артефакту; они не объявляются хешами ещё не завершённой пересборки. Загрузка сборки в Apple и финальная отправка на review пока не подтверждены.

**Вывод:** установленное `ITSAppUsesNonExemptEncryption = false` технически соответствует проверенной Apple-конфигурации и классификации «криптография, предоставляемая Apple OS». Приложение использует системный CryptoKit; криптографические примитивы Realm реализуются системным CommonCrypto. Собственная поставляемая реализация AES/SHA/HMAC или OpenSSL в проверенных библиотеках не обнаружена. Повторная проверка executable и вложенного RealmSwift в подписанном архиве подтвердила тот же состав зависимостей и вызовов.

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

Во всех четырёх проверенных RealmSwift binaries `nm -m` показывает один набор внешних символов **`from libSystem`**:

```text
CCCryptorCreate, CCCryptorRelease, CCCryptorReset, CCCryptorUpdate
CCHmac, CC_SHA1, CC_SHA256, arc4random_buf
```

В `otool -L` есть системные `Security.framework` и `libSystem.B.dylib`; библиотек OpenSSL/libcrypto/libssl нет. Поиск таблиц символов не обнаружил `EVP_*`, `OPENSSL*`, собственных `AES_*`, `SHA*`, `sha_init`, `sha_process` или `sha_done`. Это подтверждает проверенные условные ветки исходников, а не отдельное доказательство отсутствия любых возможных алгоритмов во всех будущих сборках.

У iOS Debug `iWallet.debug.dylib`, Release executable и executable из подписанного архива присутствует зависимость `/System/Library/Frameworks/CryptoKit.framework/CryptoKit`; импорты `SHA256`/`SHA256Digest` разрешаются в CryptoKit.

SHA-256 проверенных файлов, чтобы отличать эту проверку от последующих пересборок:

```text
macOS Debug:           76a241d2faadd2b665d40d753f93f18e4f315c2ff8a9f1a9988bb452523ae3d6
iOS Simulator Debug:  7d4de43f14cbad887df3c76d383a002365c637e980dbfde377b7204ecbc961ea
iOS Release product:  75408f31fa6414eddd5566ec64c6e373f8d6a328d3922111957acae5f4faf1c7
Signed RealmSwift:    9adf853f68e8c40a4487215bd53c55ef135dfa3077502bff8e9fde9adc6e09b5
Signed app:           63e064345032af8e3f408092d12b08775daf27f90318d0a63ac7d507bc45ca2d
```

## Подписанный архив и manifests

В подписанном `Info.plist` проверены: Bundle ID `com.idevnva.iwallet`, версия `2.0.0`, build `1`, SDK `iphoneos27.2`, `ITSAppUsesNonExemptEncryption = false` типа Boolean. Вложенный `RealmSwift.framework/RealmSwift` присутствует и занимает **10 854 800 байт**.

`codesign --verify --deep --strict` прошёл: подпись приложения на диске корректна и удовлетворяет Designated Requirement. Подпись проверенного архива — **Apple Development**, команда `4243BL8MP3`, сертификат `QV5HFTMMF5`. Последующий App Store IPA export завершился успешно; экспорт и загрузка в Apple — разные этапы, загрузка ещё не подтверждена.

Внутри `iWallet.app` прочитаны все четыре property-list manifest:

| Файл | Required Reason API |
| --- | --- |
| `PrivacyInfo.xcprivacy` | UserDefaults — `CA92.1` |
| `Realm_Realm.bundle/PrivacyInfo.xcprivacy` | FileTimestamp — `C617.1`; DiskSpace — `E174.1` |
| `Realm_RealmSwift.bundle/PrivacyInfo.xcprivacy` | FileTimestamp — `C617.1`; DiskSpace — `E174.1` |
| `RealmDatabase_RealmCoreResources.bundle/PrivacyInfo.xcprivacy` | FileTimestamp — `C617.1`; DiskSpace — `E174.1` |

Во всех четырёх `NSPrivacyTracking = false`, `NSPrivacyTrackingDomains = []` и `NSPrivacyCollectedDataTypes = []`. Это проверка наличия и содержимого manifest в подписанном архиве; сводный Xcode Privacy Report этим не объявляется сформированным или проверенным.

Повторная криптографическая проверка подписанного архива завершена, App Store IPA export выполнен. Последняя пересборка добавляет уведомления о лицензиях и исправление Dynamic Type; после неё нужно зафиксировать результат archive/export и состав окончательного артефакта. При изменении зависимостей или добавлении криптографического кода вывод нужно пересмотреть. Эта записка не подтверждает загрузку, обработку сборки Apple или отправку версии на review.

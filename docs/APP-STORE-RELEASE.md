# Подготовка переходного релиза iWallet

## 8 ноября 2026 — сборка 2.0.0 (7)

Исправлены кнопки первого добавления в пустых списках операций, регулярных платежей и категорий. На iPhone 13 в сборке 6 вместо подписи отображалась узкая вертикальная кнопка. Теперь у кнопки есть собственная текстовая метка, а заголовок и пояснение поддерживают системный размер шрифта.

- Прошли 107 тестов основной логики и 16 тестов перехода с Realm.
- Симулятор iPhone 13, iOS 27.2, русский язык. Проверены открытие формы и отмена из пустых списков операций, платежей и категорий дохода в светлой теме с обычным и максимальным системным шрифтом. Для операций и платежей сценарий также прошёл в тёмной теме. При максимальном шрифте до кнопок можно прокрутить список, подписи переносятся целиком. Во всех трёх прогонах нет пропусков. Снимки находятся в `build/QA/build7/`.
- Подписанный локальный пакет для App Store находится в `build/AppStore-build7/iWallet.ipa`. Проверены подпись Apple Distribution, версия 2.0.0 (7), минимальная iOS 17.0 и четыре privacy manifest. SHA-256 `4b2e629fa0b6da805afe6426de2ea9d327bb756f6a033743124549e1ff4a71a3`. Загрузка этой сборки в App Store Connect и отправка на проверку ещё предстоят.

## 6 ноября 2026 — сборка 2.0.0 (6)

Apple приняла загрузку в 07:21 по Москве и начала обработку. Проверка готовности к установке в TestFlight требует входа в App Store Connect. Последняя подтверждённая сверка выбора сборки в карточке была 5 ноября. Тексты для build 6 подготовлены локально.

- Полный `swift test -j 2` прошёл для 123 тестов (107 core и 16 legacy). Установка поверх демонстрационной базы build 5 сохранила все значения 7 операций, 12 категорий и 2 регулярных планов. Результат в `build/QA/build6/build5-to-build6.json`.
- Оба сценария в `build/UITests-Build6-Planning.xcresult` прошли без пропусков. Проверены открытие и правка бюджета, превышение и остаток, разница прогнозов 7/30 дней, системное разрешение iOS, очередь и повторный запуск. Прежнее предупреждение UI runtime о размере frame встречается при клавиатуре. Отдельная проверка на устройстве описана ниже.
- Физический iPhone 13, iOS 27.0, установка build 6 из архива через Xcode. План на 1 ₽ появился в прогнозе без изменения баланса. В 07:48 МСК при свёрнутом приложении пришло локальное напоминание: на экране блокировки видны только общий заголовок и текст без названия плана и суммы. Нажатие на уведомление с iPhone в Центре уведомлений Mac открыло вкладку «Платежи» через «Видеоповтор iPhone», хотя приложение было свёрнуто с вкладки «Обзор». Это проверка сборки на устройстве, а не установки через TestFlight.
- Три русских превью получены в `build/UITests-Build6-Previews-Final.xcresult`. [Прогноз](images/planning/forecast.png) · [Бюджет](images/planning/budget.png) · [Напоминания](images/planning/reminders.png)
- Архив `build/iWallet-2.0.0-build6.xcarchive` и App Store IPA `build/AppStore-build6/iWallet.ipa` проверены. Размер 12 400 181 байт, SHA-256 `b738a18c349211559c1ec0b28141c99bb518b1a4c645018cd2c53d8ef154a38a`. Подтверждены `Apple Distribution`, team `4243BL8MP3`, deep/strict codesign, минимальная iOS 17.0, четыре privacy manifest, лицензии и encryption flag. Лог `/tmp/iwallet-build6-upload.log` содержит `Upload succeeded`.

## Журнал на 5 ноября 2026


> Build 5: четыре вкладки, интерактивные графики и регулярные платежи/подписки. Финальный test build, 95 unit PASS полным прогоном плюс один отдельный regression, четыре уникальных UI-сценария, RU/EN/Dark/AX и подписанный IPA проверены. Upload успешен; завершение обработки Apple ещё не подтверждено. Выбранным в App Store Connect остаётся build 2 с его материалами; build 5 не выбран. App Review и публикации нет.

Состояние на **5 ноября 2026 года**: существующая карточка восстановлена, черновик **2.0.0** сохранён в App Store Connect. **Build 5 подписан, экспортирован, проверен и загружен.** Лог подтверждает начало обработки, но не её завершение. **Build 2** ранее обработан Apple, TestFlight показывает «Готово к отправке»; именно он остаётся выбранным в черновике с прежними RU/EN-материалами. Выпуск ручной. Версия на review не отправлена, приглашения тестировщикам не отправлялись, публикации нет.

Исторические build 2 и build 4 имеют отдельные подтверждения ниже: build 2 прошёл signing/export/upload и выбран в App Store Connect; build 4 зафиксирован после трёх UI PASS, RU/EN/Dark/AX-проверок. Текущий build 5 расширяет приложение графиками и регулярными платежами по [DESIGN.md](DESIGN.md); его собственные результаты приведены отдельно.

## Идентификаторы и карточка

| Поле | Подготовленное значение / статус |
| --- | --- |
| Репозиторий | [nvavna/iWallet-1](https://github.com/nvavna/iWallet-1) |
| Bundle ID | `com.idevnva.iwallet` — сохранить для обновления прежнего приложения |
| Apple ID | `6447585809` — подтверждён в App Store Connect |
| SKU | `001` — подтверждён в App Store Connect |
| Последняя прежняя версия | `1.1.8`, build `1` — подтверждена в App Store Connect |
| Версия и build | `2.0.0(5)` загружен, начало обработки подтверждено логом, завершение ещё не подтверждено. `2.0.0(2)` обработан Apple и остаётся выбранным в черновике App Store |
| Черновик App Store Connect | [2.0.0 — «Подготовка к отправке»](https://appstoreconnect.apple.com/apps/6447585809/distribution/ios/version/inflight), создание подтверждено |
| Режим выпуска и доступность | Выбран ручной выпуск; баннер о снятии старого приложения с продажи остаётся |
| Метаданные | RU/EN descriptions и What’s New обновлены для build 2 и сохранены; остальные текстовые поля не менялись. Новые снимки 3+3 загружены, все обработанные превью визуально проверены |
| Review Notes | В App Store Connect сохранён сценарий build 2. Локальные тексты в [STORE-METADATA.md](STORE-METADATA.md) перед выпуском нужно сверить с финальным build 5; новые материалы не отправлены |
| Marketing URL | Необязательное поле пусто, сохранение и пустое значение подтверждены для RU/EN. Прежний `https://idevnva.com/iwallet` не разрешается в DNS: curl (6), HTTP 000 |
| Возрастной рейтинг | Семь шагов актуальной анкеты заполнены по фактическим функциям и содержимому; рассчитан и сохранён рейтинг `4+` |
| DSA | Пользователь явно выбрал non-trader; настройка сохранена, интерфейс показывает выполнение всех compliance requirements и статус Active |
| Соглашение о бесплатных приложениях | Active, срок 1 ноября 2026 — 8 марта 2027 |
| Минимальная iOS | iOS 17 для нативной версии на SwiftData |
| Доступ и состояние | Аккаунт доступен; iWallet найден в «Удалённых приложениях» с датой удаления 10 марта 2026 года. Восстановление карточки выполнено 5 ноября 2026 года |

До восстановления публичная [страница приложения](https://apps.apple.com/app/id6447585809) не была доступна через инструмент чтения, а Apple lookup для [России](https://itunes.apple.com/lookup?id=6447585809&country=ru) и [США](https://itunes.apple.com/lookup?id=6447585809&country=us) вернул `resultCount: 0`. После входа в App Store Connect существующая карточка и её идентификаторы подтверждены. После восстановления действие Restore исчезло, доступны Transfer, Edit user access и Delete app. Это подтверждает восстановление записи в аккаунте, **но не доступность новой версии для загрузки из магазина**.

Создание черновика 2.0.0 не означает отправку на review или возобновление продаж. Причину удаления 10 марта не следует подменять предположением об App Store Improvements. Восстановление удалённой записи и выпуск новой версии — разные действия. [Восстановление записи](https://developer.apple.com/help/app-store-connect/create-an-app-record/remove-an-app)

## Подтверждённая проверка данных и её пределы

### Проверенный и загруженный build 5

Четыре native-вкладки: Overview / Transactions / Payments / Settings. На Home добавлены интерактивные Swift Charts доходов/расходов и категорий, сравнение периодов и переход к платежам. Точные денежные расчёты остаются `Int64`/`Decimal`, валюты не объединяются. Системные формы и защита черновиков сохранены.

Регулярные расходы/подписки повторяются еженедельно, ежемесячно или ежегодно. Исходный день и часовой пояс сохраняются; пауза не меняет дату. Только явное подтверждение оплаты создаёт один расход и сдвигает один период; пропуск не создаёт расход. Автоматических проводок и уведомлений нет. Сохранённый occurrence token защищает от повторов. Архивирование категории не удаляет план, но оплата требует активной категории расходов.

Все recurring-изменения фиксируются одним save в изолированном контексте; после успеха UI открывает свежий контейнер с сохранением выбранной вкладки. JSON v2 включает планы, принимает старые v1 и отклоняет конфликты до записи. Экспорт использует свежий контекст, чтобы не выгрузить устаревший UI-кэш.

Подтверждены **95 unit PASS** — 79 core (19 recurring, 16 analytics) + 16 legacy, `/tmp/iwallet-build5-core-tests.log`. Проверены календарь/DST, месячные/високосные даты, повторные подтверждения, сохранность после перезапуска, атомарный rollback и обновление прежней SwiftData-схемы. Дополнительный тест ручного INSERT отдельно прошёл для пустой и заполненной истории (`/tmp/iwallet-manual-insert-regression.log`); полного единого прогона 96 тестов здесь не заявляется.

`/tmp/iwallet-build5-app-build.log` — **BUILD SUCCEEDED** приложения для симулятора. Фактическая установка build 5 поверх установленного native build 4 сохранила 7 операций и 12 категорий со всеми пользовательскими полями: `build/QA/design5-upgrade/comparison.json`. Изменение `Z_ENT` — внутренний индекс сущности расширенной схемы. Это синтетические данные симулятора, не проверка обновления версии 1.1.8 на устройстве.

Финальный test build — **TEST BUILD SUCCEEDED** (`/tmp/iwallet-build5-test-build-final.log`). Четыре уникальных UI-сценария прошли в отдельных прогонах, проверены 18 RU/EN, 9 Dark и 29 AX-кадров. Signed archive, IPA export и проверка упаковки завершены; upload успешен. Подробные доказательства — в последнем разделе. Завершение обработки Apple, совокупный Privacy Report и выбор build 5 пока не подтверждены; в карточке остаются build 2 и его материалы. App Review/публикация не выполнялись.

### Зафиксированная основа build 4

Commit `ae80369`: три нативные вкладки, системные формы и SF-badges. `build/UITests-Design4-Smoke-Final.xcresult` — 2 PASS; `build/UITests-Design4-Migration.xcresult` — 1 PASS, ноль ошибок/пропусков. Сняты 12 RU/EN, 6 Dark и 18 AX-кадров; ограничения AX и предупреждение клавиатуры сохранены в историческом протоколе в конце документа. Build 4 не подписывался и не загружался.

### Историческая локальная проверка build 3

Компактный Home прошёл сборку (`/tmp/iwallet-compact-home-verified-build.log`) и smoke-сценарий: `build/UITests-CompactHome.xcresult`, 1 PASS / 0 ошибок / 0 пропусков. Превью — `build/QA/home-compact-*.png`. Эти результаты не подтверждают новые вкладки/формы build 4; архив и публикация build 3 не заявляются.

### Проверенный и сохранённый в App Store Connect build 2

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
| Суммы, даты, заметки, категории, расписания платежей | Локальное хранение SwiftData | Нет передачи на сервер разработчика или SDK |
| Старая база Realm | Локальное чтение для импорта с сохранением оригинала | Нет Atlas/Sync, загрузки базы на сервер или финансовых данных в логах |
| Настройки приложения | Собственный UserDefaults | `CA92.1` прочитан из manifest подписанного архива |
| Экспорт / JSON-импорт | Файл создаётся или выбирается по действию пользователя; импорт выполняется локально | Приложение не отправляет файл автоматически; объяснить содержимое и аддитивный режим импорта |
| Аналитика, реклама, tracking | Не предусмотрены в текущем приложении | Проверить зависимости и release binary; не добавлять ATT без реального tracking |

Apple не считает сбором данные, обрабатываемые только на устройстве и не передаваемые за его пределы разработчику/партнёрам. Это основание для сохранённого ответа применительно к текущей локальной реализации. [App Privacy Details](https://developer.apple.com/app-store/app-privacy-details/)

Проверенные manifests приложения и Realm-компонентов содержат `tracking=false` и пустые collected data/tracking domains. Опубликованная политика объясняет пользовательский экспорт, сохранённые legacy-файлы и добровольную переписку с поддержкой; она не обещает поведение резервных копий ОС. Privacy URL сохранён для обоих языков. Окончательное решение об отправке версии и согласованности правовых заявлений с release candidate остаётся частью финального review.

Для собственных настроек применим `CA92.1`; manifests Realm, RealmSwift и Core содержат FileTimestamp `C617.1` и DiskSpace `E174.1`. Эти причины проверены в ресурсах подписанного архива. [Официальные категории и причины](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype)

**Криптографическая проверка build 2 выполнена:** CommonCrypto Realm разрешается в системную `libSystem`, SHA-256 приложения — в CryptoKit. В подписанном `Info.plist` установлен Boolean `ITSAppUsesNonExemptEncryption=false`; вывод об использовании криптографии Apple OS подтверждён исходниками и Mach-O. Наличие `REALM_ENABLE_ENCRYPTION=1` не оставлено самостоятельным блокером. Подробности и пределы — [техническая записка](EXPORT-COMPLIANCE-TECHNICAL.md); [официальная таблица Apple](https://developer.apple.com/help/app-store-connect/reference/app-information/export-compliance-documentation-for-encryption).

## Условия допуска переходной версии

Текущая приёмка build 5:

- [x] Реализованы четыре вкладки, графики, регулярные платежи и JSON v2; приложение для симулятора собрано.
- [x] Полный unit-прогон: 95 PASS; отдельно проверен новый regression ручного INSERT.
- [x] Native build 4 → 5 установлен поверх прежних данных симулятора; пользовательские поля 7 операций и 12 категорий сохранены.
- [x] Четыре уникальных UI-сценария: CRUD/архив/перезапуск, защита черновика, цикл регулярного платежа и перенос Realm. У первоначального bundle был сбой recurring harness; финальный отдельный recurring-прогон прошёл.
- [x] RU/EN capture PASS: 18 проверенных снимков; DarkFinal — 9, AXFinal — 29 кадров, включая последние строки Settings/History. Полный VoiceOver/Accessibility Inspector остаётся отдельной проверкой.
- [x] Signed archive/IPA build 5, Apple Distribution/deep strict codesign, RealmSwift, четыре manifests, лицензии и encryption flag проверены. Совокупный Privacy Report остаётся открытым.
- [x] Build 5 успешно загружен: `/tmp/iwallet-build5-upload.log`, `Upload succeeded`, начало обработки Apple.
- [ ] Подтвердить завершение обработки, сверить тексты/Review Notes с финальными функциями и сохранить выбор build 5 с актуальными снимками. Сейчас выбран build 2.

Исторические результаты build 2 и текущее состояние карточки:

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

Публичные тексты опубликованы в ветке `restoration/foundation`, commit `ffb019b`. Обе страницы вернули HTTP 200 без авторизации 5 ноября 2026; ссылки содержат одобренный email. Support URL и Privacy Policy URL сохранены для русского и английского черновиков 2.0.0; необязательный прежний Privacy Choices URL удалён. Ссылку внутри выбранной релизной сборки ещё проверить на устройстве. Build 2 обработан Apple и остаётся выбранным в черновике. Build 5 загружен, завершение его обработки ещё не подтверждено; новые материалы карточки не сохранены. Отправка на review не выполнена.

## Зафиксированный результат build 4

5 ноября 2026: сборка симулятора прошла; `UITests-Design4-Smoke-Final.xcresult` — 2 PASS, `UITests-Design4-Migration.xcresult` — 1 PASS, без ошибок и пропусков. Исходный Realm и сохранённый snapshot имеют прежний SHA-256 `b427523b505ddf61179a6b4af00870756efbcc1cd1bdbf3eef059f2ecad19bdd`. Сняты и просмотрены 12 RU/EN-кадров в `build/AppStore-Screenshots-build4/{ru,en}/`, 6 Dark и 18 AX-кадров. AX-проверка ограничена: отдельные значения системного Picker/placeholder сокращаются, низ всех длинных экранов не проверен полностью. VoiceOver/физический iPhone/iOS 17 остаются открытыми. В smoke сохраняется прежнее предупреждение Invalid frame при клавиатуре.

Build 4 не подписывался и не загружался; в App Store Connect сохранены build 2 и его материалы. Графики и регулярные платежи реализованы в следующем build 5; его собственные результаты приведены ниже.

## Подтверждённые сценарии build 5

Полный `swift test -j 2` — 95 PASS (79 core + 16 legacy). Отдельный новый `testFailedNewTransactionDoesNotAppearInHistoryOrCategory` — PASS для пустой и заполненной истории: всего 96 проверенных тестов, без утверждения о повторном полном прогоне 96.

- `build/UITests-Build5-Smoke.xcresult`: создание/правка расхода, архив/перезапуск и защита черновика — два PASS без пропусков. В первоначальном bundle есть один сбой recurring harness: два вложенных AX-узла одной системной кнопки. Этот bundle не является целиком успешным.
- `build/UITests-Build5-Recurring-Final.xcresult`: один PASS, 310,660 с, без пропусков. Создание плана без расхода, оплата ровно одной операции, новая дата, пропуск без расхода, пауза/возобновление, удаление плана с сохранением истории, перезапуск. Harness использует наблюдаемый firstMatch системного подтверждения и ждёт обновления AX-значения поиска после ввода.
- `build/UITests-Build5-Migration.xcresult`: один PASS, 34,475 с, без пропусков. Исходник и snapshot сохранили SHA-256 `b427523b505ddf61179a6b4af00870756efbcc1cd1bdbf3eef059f2ecad19bdd`; доказательство `build/QA/design5-migration-source.json`.
- RU/EN capture PASS: по 9 проверенных оригинальных PNG для каждого языка, всего 18. [Рецепт и результаты](APPSTORE-SCREENSHOTS.md).
- `build/UITests-Build5-Dark-Final.xcresult`: 1 PASS / 0 ошибок / 0 пропусков, 81,936 с; 9 кадров в `build/QA/design5-dark-final/`.
- `build/UITests-Build5-AX-Final.xcresult`: 1 PASS / 0 ошибок / 0 пропусков, 162,530 с; 29 кадров в `build/QA/design5-ax-final/`. Последние строки Settings/History достигнуты и видимы над tab bar. Наложение осей при крупном тексте устранено: accessibility-вариант использует выбор интервала и точные текстовые значения; обычные Swift Charts сохранены.

Финальная сборка тестов: `/tmp/iwallet-build5-test-build-final.log`, **TEST BUILD SUCCEEDED**. Все 18 RU/EN-кадров просмотрены; девять русских превью сохранены в `docs/images/design5/` (относительно корня репозитория).

Подписанный архив `build/iWallet-2.0.0-build5.xcarchive` и экспорт `build/AppStore-build5/iWallet.ipa` завершились успешно (`/tmp/iwallet-build5-archive.log`, `/tmp/iwallet-build5-export.log`). IPA: **12 065 904 байта**, SHA-256 `bc1b5cc32e9a1beac146a3fc17a11155f5441d8db8216ffb0940eb512ab5dec7`. Проверка `build/QA/build5-ipa-validation.json` подтверждает `2.0.0(5)`, Bundle ID `com.idevnva.iwallet`, minimum iOS 17.0, Apple Distribution/team `4243BL8MP3`, deep/strict codesign PASS, вложенный RealmSwift и четыре privacy manifest. `get-task-allow=false`, `ITSAppUsesNonExemptEncryption=false`. SHA-256 `ThirdPartyNotices.txt` внутри IPA совпадает с исходником: `3d6729c9937fdecf61642a6e2ff1fd90de563584c49074f50707762dad602d4d`.

**Upload build 5 успешен:** `/tmp/iwallet-build5-upload.log` в 18:35:45 содержит `Upload succeeded`, `Uploaded package is processing` и `EXPORT SUCCEEDED`. Это подтверждает доставку и начало обработки; завершение обработки Apple пока не подтверждено. В черновике App Store остаются выбранный build 2 и его RU/EN-метаданные/снимки. Build 5 не выбран, на App Review не отправлен, публикации нет.

Предупреждение `Invalid frame dimension (negative or non-finite)` при клавиатуре остаётся. Физический iPhone, минимальная iOS 17, полный VoiceOver и реальное обновление бинарника 1.1.8 не подтверждены.

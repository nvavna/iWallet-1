# Восстановление iWallet

> Текущий локальный build 4: нативные вкладки «Обзор / Операции / Настройки», компактный Home без дублирующих кнопок истории/настроек, системные формы, единые SF-badges и новая палитра. Сборка симулятора прошла; основные UI-проверки завершены, полная матрица доступности остаётся открытой. В App Store Connect остаются выбранный и сохранённый build 2, его тексты и снимки. Build 4 не загружен, отправки на App Review и публикации нет.

Дата аудита: 5 ноября 2026 года. Документ описывает исходное приложение, выбранное направление и условия выпуска. Он не подтверждает готовность новой версии к App Store.

## Что сохранено

- Исходный проект: [iWalletTeam/iWallet](https://github.com/iWalletTeam/iWallet).
- Копия с историей: [nvavna/iWallet-1](https://github.com/nvavna/iWallet-1). Локальный `origin` указывает на копию, `upstream` — на исходник.
- Исходная точка аудита: `b521ad4ce499273e427894501250d416a3433359` от 1 июля 2023 года; версия проекта — `1.1.8`.
- Bundle ID `com.idevnva.iwallet` сохраняется. Не менять его ради восстановления сборки: он связывает обновление с существующей карточкой App Store.
- Доступ к Apple Developer / App Store Connect подтверждён. Прежняя карточка восстановлена через интерфейс аккаунта. Новая сборка ещё не опубликована; восстановление карточки не заменяет signing, TestFlight и App Review.
- Подписанный архив и App Store IPA **2.0.0 (2)** успешно собраны и проверены. Загрузка завершилась успешно; обработка Apple подтверждена: upload row — «Завершено», build 2 в TestFlight — «Готово к отправке». Это не подтверждает проверку на физическом устройстве или прохождение App Review. Build 1 также обработан Apple, но содержит предыдущее оформление.
- Для build 2 сохранены описания RU/EN, What’s New и Review Notes, загружены шесть новых реальных скриншотов; все миниатюры визуально проверены. Support/privacy URL, возрастной рейтинг 4+ и ручной выпуск сохранены. Build 2 выбран и сохранён в черновике App Store 2.0.0 со статусом «Подготовка к отправке». По выбору владельца сохранён DSA non-trader; compliance и соглашение бесплатных приложений имеют активный статус.
- Реализована новая версия на SwiftUI + SwiftData, iOS 17+. По согласованному решению переходный релиз включает Realm Swift 20.0.6 только для чтения рабочей копии старой базы; все новые и перенесённые записи сохраняются в SwiftData.

## Аудит исходного кода

| Область | Что найдено | Что меняем / проверяем |
| --- | --- | --- |
| Интерфейс | SwiftUI, обзор баланса и категорий, история, добавление/редактирование операций, настройки; русский и английский языки | Сохранить основные сценарии, выстроить иерархию обзора, унифицировать отступы, типографику, состояния и навигацию |
| Хранение | Realm, `schemaVersion: 15`; модели `Category` и `TransactionItem` | SwiftData; реализован и проверен reader schema 15, исходник и резервная копия сохраняются |
| Деньги | `Float` в модели, вводе и суммировании | Хранить `Int64` в минимальных единицах валюты, использовать ISO-код и её число дробных знаков; валидировать ввод и переполнение |
| Валюта | Общая настройка `currencySymbol`; в транзакции валюты нет | Хранить ISO-код. Символы `$`, `¥`, `£` неоднозначны; импорт требует выбора пользователя |
| Зависимости | Старый `Package.resolved` закрепляет Realm Swift по ревизии ветки `master`, Realm Core 13.13.0 | Временный reader Realm Swift 20.0.6 читает отдельную копию; постоянное хранилище — SwiftData |
| Ошибки | `try!` при создании категорий; часть ошибок БД выводится только в консоль | Показывать ошибки сохранения/загрузки, не подменять недоступную базу пустой и не сообщать об успехе после ошибки |
| Удаление | Удаление категории удаляет её транзакции | Архивирование сохраняет историю; связь SwiftData `.nullify` не удаляет операции |
| Приватность | В исходном Swift-коде не найдены аналитические SDK или сетевые запросы; есть внешние ссылки. В консоль выводится объект сохранённой операции | Новую версию строить локально, без tracking и аналитики; исключить финансовые данные из диагностических логов; проверить итоговый архив |
| Доступность | В карточке баланса принудительно задан `.dynamicTypeSize(.small)` | Уважать настройки размера текста; проверить VoiceOver, контраст, Reduce Motion и длинные значения |
| Метаданные | Настройки показывают `1.1.7`, проект содержит `1.1.8` | Показывать версию из bundle; согласовать номер следующего релиза с App Store Connect |
| Проверки | В исходном дереве не обнаружен набор автоматических тестов | Проверять финансовую логику, сохранение и миграцию; провести ручную проверку основных сценариев и дизайна |

Наблюдения сделаны по исходному коду. Это не результаты запуска или визуальной проверки приложения на устройстве.

## План работ

1. **Рабочая нативная основа.** SwiftData-модели, отдельное хранилище, точные суммы, валюта, создание и редактирование операций и категорий, обработка ошибок. Существующие Realm-файлы не удалять и не перезаписывать.
2. **Сохранность данных.** Мост Realm → WalletBackup → SwiftData и JSON-восстановление реализованы. Проверены атомарность, идемпотентность, отказ на конфликтах и настоящая историческая фикстура. Остаётся проверка обновления на устройстве/TestFlight; границы поддержки описаны в [LEGACY-MIGRATION.md](LEGACY-MIGRATION.md).
3. **Обновление интерфейса.** Build 4 реализует три нативные вкладки, компактный баланс/сводку и системные формы по [DESIGN.md](DESIGN.md). Сборка симулятора прошла; поведение, доступность и новый магазинный набор ещё требуют проверки. Доказательства UI/capture build 2 и компактного Home build 3 сохраняются как исторические.
4. **Доступность и локализация.** Светлая/тёмная темы, крупный текст, VoiceOver, достаточные области нажатия, длинные суммы и названия. Проверить русский и английский, десятичные разделители, календарь и часовые пояса.
5. **Проверка релиза.** Сборка и запуск, сохранение после перезапуска, реальное обновление поверх старой версии с данными, TestFlight на устройстве, финальный архив и privacy report. Подготовить актуальные скриншоты, описание, support URL и политику приватности.
6. **Возвращение в App Store.** Прежняя карточка восстановлена; build 2 подписан, загружен, обработан Apple и выбран в сохранённом черновике, его материалы RU/EN сохранены. Предстоит завершить проверку материалов, пройти TestFlight на устройстве и review. Новая версия ещё не опубликована.

## Текущий локальный интерфейс build 4

- Три native `TabView`-раздела: Обзор, Операции, Настройки, каждый со своей навигацией. На Home нет дублирующих переходов к полной истории или настройкам.
- Главный баланс и одна компактная сводка доходов, расходов и среднего; системные фоны и синий action tint. Большой текст меняет компоновку, а не смысл данных.
- По умолчанию «Всё время». Баланс включает всю историю выбранной валюты; доходы, расходы и среднее относятся к выбранному периоду. Среднее делится на количество календарных дней с расходами; валюты не смешиваются и не конвертируются.
- Переключатель Расход/Доход показывает полный список категорий с операциями выбранных типа, валюты и периода. История категории открывается push-переходом и сохраняет валюту, но включает все даты.
- Добавление — системная toolbar-кнопка; Home подставляет тип и валюту. В истории активной категории подставляются категория и валюта; у архивной категории добавление скрыто.
- Категории открываются push из Настроек. Создание/редактирование — формы; новая категория внутри операции — push в текущем sheet. Её явный Cancel защищает изменённый черновик; системный Back редактора скрыт.
- Единый SF-badge: декоративные 32 pt в списках / 28 pt в Home, доступное название масштабируется отдельно. Палитра адаптируется к light/dark, неизвестный цвет отображается синим без изменения сохранённых данных. App icon не перерабатывался.
- Перенос прежней истории остаётся отдельным consent flow; preview/округление/receipt и аддитивный JSON-импорт сохраняют смысл.

Сборка симулятора — **BUILD SUCCEEDED**, `/tmp/iwallet-design4-build.log`; runtime-/UI- и визуальная приёмка build 4 ещё не завершены. Для glyph на 12% tint поверх белого / `#1c1c1e` рассчитан минимальный контраст **4,54:1 / 6,35:1**. Это ограниченная математическая проверка палитры, не полный Accessibility Inspector и не доказательство VoiceOver. Подробные критерии — [DESIGN.md](DESIGN.md).

Исторический build 2 использовал четыре карточки 2×2, floating plus и навигацию без вкладок; его два UI-сценария, шесть RU/EN-снимков и подписанный IPA проверены. Промежуточный build 3 ввёл компактный Home; `build/UITests-CompactHome.xcresult` — 1 PASS / 0 ошибок / 0 пропусков, `/tmp/iwallet-compact-home-verified-build.log` — TEST BUILD SUCCEEDED; превью `build/QA/home-compact-*.png`. Эти результаты не подтверждают новый TabView и формы build 4.

## Условия Apple на дату аудита

| Требование | Значение для iWallet | Источник |
| --- | --- | --- |
| С 28 апреля 2026: Xcode 26+ и iOS/iPadOS 26 SDK+ | Собирать актуальным поддерживаемым Xcode. Это версия SDK сборки, а не требование ограничить пользователей iOS 26 | [Upcoming Requirements](https://developer.apple.com/news/upcoming-requirements/) |
| С 9 сентября 2026: deployment target iOS/iPadOS 13+ | Выбранный iOS 17+ соответствует этому минимуму; отдельно оценить, какие старые устройства перестанут получать обновления | [Upcoming Requirements](https://developer.apple.com/news/upcoming-requirements/) |
| С 31 января 2026: обновлённая анкета возрастного рейтинга | Анкета сохранена в существующей карточке, рейтинг 4+ | [Upcoming Requirements](https://developer.apple.com/news/upcoming-requirements/) |
| Required-reason APIs | Декларировать фактическое использование API в `PrivacyInfo.xcprivacy`; для собственных настроек UserDefaults применим `CA92.1` | [API reasons](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype) |
| App Privacy | Указать реальную обработку данных приложения и библиотек; сверить с итоговым архивом | [App Privacy Details](https://developer.apple.com/app-store/app-privacy-details/) |
| Privacy Policy | Доступный URL в App Store Connect и ссылка внутри приложения обязательны; текст должен соответствовать реальной работе версии | [Review Guidelines, 5.1.1](https://developer.apple.com/app-store/review/guidelines/#data-collection-and-storage) |
| SDK manifests/signatures | Переходный релиз содержит RealmSwift 20.0.6; проверить его manifest и совокупный privacy report. Требования подписей зависят в том числе от способа поставки SDK | [Third-party SDK requirements](https://developer.apple.com/support/third-party-SDK-requirements/) |
| Выпуск в ЕС | По выбору владельца сохранён non-trader; compliance имеет активный статус | [Digital Services Act](https://developer.apple.com/help/app-store-connect/manage-compliance-information/manage-european-union-digital-services-act-trader-requirements/) |

Если Apple сняла приложение в рамках App Store Improvements, подать исправленное обновление можно без срока давности при активной подписке Developer Program. Это не подтверждение причины снятия именно iWallet. [App Store Improvements](https://developer.apple.com/help/app-review/safe-and-trusted-store/app-store-improvements)

После загрузки сборки Bundle ID карточки нельзя менять. Сохраняем существующий идентификатор и проверяем возможность обновления старой карточки. Перенос между аккаунтами нужен только при фактической смене команды; его инициирует прежний Account Holder. [Bundle ID](https://developer.apple.com/documentation/xcode/changing-the-bundle-identifier), [app transfer](https://developer.apple.com/help/app-store-connect/transfer-an-app/overview-of-app-transfer/)

## Privacy manifest новой версии

Подготовлен `iWallet/Native/PrivacyInfo.xcprivacy`: tracking отключён, список собираемых данных пуст, для UserDefaults указан `CA92.1`. Основание — собственные локальные настройки приложения: новая реализация использует `@AppStorage("preferredCurrencyCode")`; старая использовала `@AppStorage` для тактильного отклика, первого запуска, валюты и округления. Код причины не разрешает читать настройки других приложений или системы. [Официальное описание CA92.1](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype)

В подписанном архиве build 1 и извлечённом IPA build 2 проверены четыре privacy manifest: приложения, Realm, RealmSwift и Realm Core. Realm декларирует FileTimestamp `C617.1` и DiskSpace `E174.1`; собственный код использует UserDefaults `CA92.1`. Политика и support URL опубликованы и сохранены в карточке. Наличие manifests не заменяет совокупный Privacy Report и итоговую сверку App Privacy с релизным архивом; завершение этих отдельных проверок здесь не заявлено. Подробности — в [проверке пакета релиза](APP-STORE-RELEASE.md).

## Блокеры выпуска

- **Build 4 ещё требует приёмки и релизного артефакта.** Подтверждена сборка симулятора, но не новые runtime-/UI-проверки. Нужны актуальные снимки, signed archive/IPA, проверка упаковки, загрузка и выбор новой сборки. Описания/Review Notes build 4 подготовлены локально в [STORE-METADATA.md](STORE-METADATA.md), не отправлены.

- **Проверка миграции на устройстве/TestFlight ещё требуется.** Reader schema 15 прошёл тесты на настоящем формате 2023 года. У владельца нет личной старой базы; синтетическая фикстура не доказывает совместимость со всеми базами прежних пользователей. Новые согласованные производственные варианты проверяются отдельно; неизвестные схемы отклоняются.
- **Проверки на устройствах и доступности ещё требуются.** 60 тестов хранения и денег, два UI-сценария build 2 и проверки RU light/dark, EN light и максимального accessibility-размера прошли. Полная матрица экранов/тем/размеров, физический iPhone, минимальная iOS 17 и VoiceOver ещё не подтверждены. В актуальном smoke-result осталось предупреждение `Invalid frame dimension (negative or non-finite)`; успешный тест не подтверждает его устранение.
- **Карточка подготовлена, релиз не опубликован.** Build 2 подписан, экспортирован, загружен и обработан Apple, в TestFlight — «Готово к отправке». TestFlight на устройстве и App Review ещё не пройдены.
- **Пакет релиза требует итоговой проверки.** Новые тексты RU/EN, What’s New и Review Notes сохранены, шесть снимков build 2 загружены; все миниатюры визуально проверены. Build 2 выбран и сохранён в черновике. Остаются совокупный Privacy Report, итоговая сверка App Privacy и допуск после TestFlight.

## Журнал проверки

- Build 4: `/tmp/iwallet-design4-build.log` — **BUILD SUCCEEDED** для симулятора. Runtime-/UI-результаты нового дизайна ещё ожидаются; дальнейшие результаты в этом журнале относятся к явно указанным предыдущим сборкам.

- Полный `swift test -j 2` для build 2, 5 ноября 2026: **60 тестов, 0 ошибок** — 44 `WalletCoreTests` и 16 `LegacyMigrationTests`; лог `/tmp/iwallet-build2-core-tests.log`. Покрыты деньги/локали, средний расход, даты, CRUD, архивирование, дисковое сохранение, JSON roundtrip/конфликты, receipt, восстановление валютной настройки, миграция, сохранность источника и ошибки snapshot/retry. Предыдущий build 1 прошёл 55 тестов (39 native + 16 legacy).
- Сборка UI-тестов build 2 для симулятора завершилась **TEST BUILD SUCCEEDED**. Оба сценария затем выполнены с новой навигацией: `build/UITests-Build2-Smoke-4.xcresult` и `build/UITests-Build2-Migration.xcresult`, каждый — **1 passed, 0 failed, 0 skipped**.
- Историческая [фикстура](../Tests/Fixtures/README.md) действительно записана официальным Realm Cocoa 10.40.0 / Core 13.13.0, соответствующим Core исходного проекта. Схема iWallet 15, файловый формат 23, 2 категории и 4 операции. Три независимых генерации дали одинаковые 16,384 байта и SHA-256 `b427523b505ddf61179a6b4af00870756efbcc1cd1bdbf3eef059f2ecad19bdd`.
- Production-reader Realm 20 обновил только одноразовую рабочую копию формата 23→24; исходные байты сохранились. Проверены поля, стабильные ID, дробные даты, суммы, одно явное округление и запись SwiftData с receipt. Это синтетические данные, а не личная база прежнего пользователя.
- Записи и `WalletMigrationReceipt` фиксируются одним `save()` в отдельном ModelContext того же контейнера. Read-only disk failure проверяет rollback и отсутствие частичных записей в основном контексте. Receipt переживает перезапуск и последующее редактирование; настройки восстанавливаются после прерывания между commit и UserDefaults.
- Холодная snapshot-копия проверяется по SHA-256 и переиспользуется при повторе. Исходник не открывается Realm. Частичные staging/working-каталоги очищаются, подтверждённая резервная копия остаётся.
- JSON export/import реализованы. Одинаковые ID с одинаковыми полями пропускаются; конфликт любого ID отклоняет весь файл. Импорт не перезаписывает историю и не затрагивает несохранённый пользовательский черновик.
- UI smoke build 2: `build/UITests-Build2-Smoke-4.xcresult`, **1 passed, 0 failed, 0 skipped**. Создание категории и расхода `12.34 USD`, закрытие клавиатуры заметки кнопкой Done, переход из обзора в историю выбранной категории, изменение на `23.45 USD`, обновление обзора, архивирование категории и сохранение операции после перезапуска. Прогон выполнен на отдельном `iWallet UI QA`, UUID `CA023AC3-30BB-4937-A802-2638D30174EB`.
- UI migration build 2: `build/UITests-Build2-Migration.xcresult`, **1 passed, 0 failed, 0 skipped**, без runtime warnings в summary. Экран переноса показал 2 категории / 4 операции; выбран USD, запись была заблокирована до согласия с округлением. После переноса и перезапуска открыт обычный кошелёк, повторный импорт не предложен. SHA-256 исходной фикстуры и snapshot не изменился. Отдельный simulator `iWallet Migration Build2`, UUID `0FDF2D63-6481-4D61-A730-577762115AF5`.
- Оба UI-прогона build 2 выполнены Xcode 27.2 на iPhone 18 Pro Simulator / iOS 27.2, с английским интерфейсом и `en_US`. Для активного нижнего поиска iOS 27 исправлен только `goHome()` в UI-тесте: сначала закрывается поиск, затем используется вернувшаяся кнопка Done. Production-код ради этого исправления не менялся. В актуальном smoke-result присутствует runtime warning `Invalid frame dimension (negative or non-finite)`; его устранение не заявлено и не связано с исправлением test helper.
- Визуальная проверка build 2: русский обзор в `build/QA/build2-overview-ru-light.png`, `build2-overview-ru-dark.png` и `build2-overview-ru-large.png`; английский — в `build/AppStore-Screenshots-build2/en/01-overview.png`. На максимальном accessibility-размере карточки идут в одну колонку, проверенные суммы и подписи читаемы. Шесть снимков обзора, истории и категорий RU/EN сохранены в `build/AppStore-Screenshots-build2/{ru,en}/`: реальные RGB PNG 1206×2622 без alpha и обработки изображений. Оба отдельных capture-прогона прошли; [команды и ограничения](APPSTORE-SCREENSHOTS.md). Эти проверки не объявляются решением предупреждения при появлении клавиатуры.
- Подписанный `build/iWallet-2.0.0-signed.xcarchive` версии 2.0.0 (1) собран; `codesign --verify --deep --strict` прошёл. Динамический `Frameworks/RealmSwift.framework/RealmSwift` вложен, размер бинарника 10,854,800 байт. Прежняя ошибка отсутствующего framework устранена.
- Для build 1 после входа владельца в Xcode экспорт App Store IPA успешно выполнен: `build/AppStore/iWallet.ipa`. В IPA build 1 проверены целостность ZIP, вложенный RealmSwift и полный `ThirdPartyNotices.txt`; SHA-256 notices совпадает с исходником: `3d6729c9937fdecf61642a6e2ff1fd90de563584c49074f50707762dad602d4d`. Лицензии доступны в Settings; их полнота независимо сверена с закреплёнными source packages. `ITSAppUsesNonExemptEncryption = false` обоснован в [технической проверке](EXPORT-COMPLIANCE-TECHNICAL.md).
- Build 1 успешно загружен после корректного входа в Xcode: `/tmp/iwallet-appstore-upload-after-login.log`. Повторная загрузка после сбоя обработана Apple: строка `e8c9f1ce-1906-4211-9860-f95247d7f8c3` — «Завершено», 2.0.0 (1) — «Готово к отправке». Подтверждение: `build/QA/testflight-build1-processed.jpg`. Это не утверждение о прохождении проверки метаданных или TestFlight-проверки на устройстве.
- Build 2: подписанный архив `build/iWallet-2.0.0-build2.xcarchive` и App Store IPA `build/AppStore-build2/iWallet.ipa` успешно получены и проверены, включая подпись и вложенный RealmSwift. Размер IPA — **11 549 549 байт**, SHA-256 `ac1650f45f4c7355b8a263ce8e3ac932da64d0e6f1cb5a95eb72b2726afbe9b3`.
- Build 2 успешно загружен: `/tmp/iwallet-build2-upload.log` содержит `Upload succeeded` и `EXPORT SUCCEEDED`. Последующее состояние подтверждено в TestFlight: upload row `fc82dc7d-2780-4b33-afa3-dd08cdf88f8b` — «Завершено», сборка 2.0.0 (2) — «Готово к отправке». Подтверждение: `build/QA/testflight-build2-processed.jpg`.
- Для build 2 в App Store Connect сохранены описания RU/EN, What’s New и Review Notes, загружены шесть новых снимков; все миниатюры визуально проверены. Build 2 выбран и сохранён в черновике 2.0.0, статус — «Подготовка к отправке», выпуск ручной. Финальная отправка на App Review и публикация не выполнены.

## UI-тесты и воспроизведение

Подтверждённые результаты предыдущего раздела по старой навигации относятся к build 2; оба сценария тогда прошли без пропусков. Для текущих вкладок и форм build 4 тесты обновляются; их новый результат ещё не подтверждён. Команды — способ воспроизведения с актуальным кодом, а не утверждение о завершённом прогоне build 4.

Тесты находятся в `Tests/WalletUITests/WalletSmokeTests.swift`, target `iWalletUITests`. Они создают записи с уникальными названиями и не сбрасывают данные. Для повторения используйте **новый отдельный simulator**: уже перенесённая база содержит receipt, поэтому повторный migration-тест на ней будет пропущен. Команды ниже не удаляют существующие приложения или кошельки. Выполнять из корня репозитория с установленными Xcode 27.2 и iOS 27.2 Simulator runtime; для другого runtime выбрать его доступный идентификатор.

```sh
IWALLET_QA_RUN=$(date -u +%Y%m%dT%H%M%SZ)
IWALLET_QA_DEVICE=$(xcrun simctl create "iWallet QA $IWALLET_QA_RUN" \
  com.apple.CoreSimulator.SimDeviceType.iPhone-18-Pro \
  com.apple.CoreSimulator.SimRuntime.iOS-27-2)
export IWALLET_QA_DEVICE
xcrun simctl boot "$IWALLET_QA_DEVICE"
xcrun simctl bootstatus "$IWALLET_QA_DEVICE" -b

xcodebuild test -project iWallet.xcodeproj -scheme iWallet \
  -destination "id=$IWALLET_QA_DEVICE" -derivedDataPath build/DerivedData \
  -clonedSourcePackagesDirPath build/SourcePackages -jobs 2 \
  -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO \
  '-only-testing:iWalletUITests/WalletSmokeTests/testExpenseCreateEditAndCategoryArchivePreservesHistory' \
  -resultBundlePath "build/UITests-Smoke-$IWALLET_QA_RUN.xcresult"
```

Успешный smoke-тест завершает приложение. Затем поместите **только синтетическую фикстуру репозитория** в его контейнер. Запись ниже открывает назначение в режиме `xb` и отказывается перезаписывать существующий `default.realm`:

```sh
python3 - <<'PY'
import hashlib, os, pathlib, shutil, subprocess
device = os.environ['IWALLET_QA_DEVICE']
container = pathlib.Path(subprocess.check_output([
    'xcrun', 'simctl', 'get_app_container', device, 'com.idevnva.iwallet', 'data'
], text=True).strip())
source = pathlib.Path('Tests/Fixtures/iwallet-schema15-realm-10.40.0.realm')
expected = 'b427523b505ddf61179a6b4af00870756efbcc1cd1bdbf3eef059f2ecad19bdd'
assert hashlib.sha256(source.read_bytes()).hexdigest() == expected
destination = container / 'Documents/default.realm'
destination.parent.mkdir(parents=True, exist_ok=True)
with source.open('rb') as src, destination.open('xb') as dst:
    shutil.copyfileobj(src, dst)
assert hashlib.sha256(destination.read_bytes()).hexdigest() == expected
print('Synthetic fixture staged:', destination)
PY

xcodebuild test -project iWallet.xcodeproj -scheme iWallet \
  -destination "id=$IWALLET_QA_DEVICE" -derivedDataPath build/DerivedData \
  -clonedSourcePackagesDirPath build/SourcePackages -jobs 2 \
  -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO \
  '-only-testing:iWalletUITests/WalletSmokeTests/testLegacyMigrationReviewAndTransfer' \
  -resultBundlePath "build/UITests-Migration-$IWALLET_QA_RUN.xcresult"

python3 - <<'PY'
import hashlib, os, pathlib, subprocess
container = pathlib.Path(subprocess.check_output([
    'xcrun', 'simctl', 'get_app_container', os.environ['IWALLET_QA_DEVICE'],
    'com.idevnva.iwallet', 'data'
], text=True).strip())
expected = 'b427523b505ddf61179a6b4af00870756efbcc1cd1bdbf3eef059f2ecad19bdd'
paths = [container / 'Documents/default.realm',
         container / 'Library/Application Support/iWalletLegacyMigration' / expected / 'default.realm']
for path in paths:
    assert hashlib.sha256(path.read_bytes()).hexdigest() == expected, path
    print('Original bytes preserved:', path)
PY
```

Сверьте в обоих `.xcresult` **Passed**, один выполненный тест и ноль skipped; отсутствие legacy-файла намеренно приводит к skip migration-теста. Скриншоты приложены к результатам. Этот сценарий проверяет реальную миграцию файла формата 23 через UI и перезапуск приложения. Старый бинарник 1.1.8 здесь не устанавливается; проверка обновления установленного приложения на физическом устройстве/TestFlight остаётся отдельным этапом.

## Зафиксированный результат build 4

5 ноября 2026: сборка симулятора прошла; `UITests-Design4-Smoke-Final.xcresult` — 2 PASS, `UITests-Design4-Migration.xcresult` — 1 PASS, без ошибок и пропусков. Исходный Realm и сохранённый snapshot имеют прежний SHA-256 `b427523b505ddf61179a6b4af00870756efbcc1cd1bdbf3eef059f2ecad19bdd`. Сняты и просмотрены 12 RU/EN-кадров в `build/AppStore-Screenshots-build4/{ru,en}/`, 6 Dark и 18 AX-кадров. AX-проверка ограничена: отдельные значения системного Picker/placeholder сокращаются, низ всех длинных экранов не проверен полностью. VoiceOver/физический iPhone/iOS 17 остаются открытыми. В smoke сохраняется прежнее предупреждение Invalid frame при клавиатуре.

Build 4 не подписан и не загружен; в App Store Connect сохранены build 2 и его материалы. Следующий запрос владельца расширяет приложение графиками и регулярными платежами; результаты build 4 не подтверждают ещё не реализованное расширение.

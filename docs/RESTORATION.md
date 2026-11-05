# Восстановление iWallet

Дата аудита: 5 ноября 2026 года. Документ описывает исходное приложение, выбранное направление и условия выпуска. Он не подтверждает готовность новой версии к App Store.

## Что сохранено

- Исходный проект: [iWalletTeam/iWallet](https://github.com/iWalletTeam/iWallet).
- Копия с историей: [nvavna/iWallet-1](https://github.com/nvavna/iWallet-1). Локальный `origin` указывает на копию, `upstream` — на исходник.
- Исходная точка аудита: `b521ad4ce499273e427894501250d416a3433359` от 1 июля 2023 года; версия проекта — `1.1.8`.
- Bundle ID `com.idevnva.iwallet` сохраняется. Не менять его ради восстановления сборки: он связывает обновление с существующей карточкой App Store.
- Доступ к Apple Developer / App Store Connect подтверждён. Прежняя карточка восстановлена через интерфейс аккаунта. Новая сборка ещё не опубликована; восстановление карточки не заменяет signing, TestFlight и App Review.
- Подписанный архив и экспорт App Store IPA успешно получены. Сохранены метаданные RU/EN, support/privacy URL, возрастной рейтинг 4+ и ручной выпуск. По выбору владельца сохранён DSA non-trader; compliance и соглашение бесплатных приложений имеют активный статус. Загрузка сборки пока не выполнена.
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
3. **Обновление интерфейса.** Понятный обзор с главным балансом и выбранным периодом; быстрый ввод операции; согласованные цвета доходов/расходов, категории и история; полезные пустые состояния. Системные материалы и анимации применять только там, где они помогают чтению и навигации.
4. **Доступность и локализация.** Светлая/тёмная темы, крупный текст, VoiceOver, достаточные области нажатия, длинные суммы и названия. Проверить русский и английский, десятичные разделители, календарь и часовые пояса.
5. **Проверка релиза.** Сборка и запуск, сохранение после перезапуска, реальное обновление поверх старой версии с данными, TestFlight на устройстве, финальный архив и privacy report. Подготовить актуальные скриншоты, описание, support URL и политику приватности.
6. **Возвращение в App Store.** Прежняя карточка восстановлена, метаданные RU/EN заполнены. Предстоит загрузить проверенную сборку, пройти TestFlight и review. Новая версия ещё не опубликована.

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

В подписанном архиве проверены четыре privacy manifest: приложения, Realm, RealmSwift и Realm Core. Realm декларирует FileTimestamp `C617.1` и DiskSpace `E174.1`; собственный код использует UserDefaults `CA92.1`. Политика и support URL опубликованы и сохранены в карточке. Наличие manifests не заменяет совокупный Privacy Report и App Privacy в App Store Connect; завершение этих отдельных проверок здесь не заявлено.

## Блокеры выпуска

- **Проверка миграции на устройстве/TestFlight ещё требуется.** Reader schema 15 прошёл тесты на настоящем формате 2023 года. У владельца нет личной старой базы; синтетическая фикстура не доказывает совместимость со всеми базами прежних пользователей. Новые согласованные производственные варианты проверяются отдельно; неизвестные схемы отклоняются.
- **Проверки физического iPhone, минимальной iOS 17 и VoiceOver ещё требуются.** Два UI-теста прошли на iPhone 18 Pro Simulator / iOS 27.2; отдельно проверены RU light/dark, EN light и русский обзор с максимальным accessibility-размером. Полная матрица экранов/тем/размеров ещё не подтверждена; в smoke-прогоне осталось диагностическое предупреждение о размере frame при появлении клавиатуры.
- **Карточка подготовлена, релиз не опубликован.** Signing и экспорт IPA прошли; впереди загрузка/обработка сборки Apple, TestFlight и review.
- **Пакет релиза требует итоговой проверки.** Подготовлены RU/EN, support/privacy URL, возрастная анкета и режим выпуска; остаются App Privacy/совокупный Privacy Report, проверка выбранной сборки, скриншоты App Store и допуск после TestFlight.

## Журнал проверки

- Полный `swift test -j 2`, 5 ноября 2026: **55 тестов, 0 ошибок** — 39 `WalletCoreTests` и 16 `LegacyMigrationTests`. Покрыты деньги/локали, даты, CRUD, архивирование, дисковое сохранение, JSON roundtrip/конфликты, receipt, восстановление валютной настройки, миграция, сохранность источника и ошибки snapshot/retry.
- Историческая [фикстура](../Tests/Fixtures/README.md) действительно записана официальным Realm Cocoa 10.40.0 / Core 13.13.0, соответствующим Core исходного проекта. Схема iWallet 15, файловый формат 23, 2 категории и 4 операции. Три независимых генерации дали одинаковые 16,384 байта и SHA-256 `b427523b505ddf61179a6b4af00870756efbcc1cd1bdbf3eef059f2ecad19bdd`.
- Production-reader Realm 20 обновил только одноразовую рабочую копию формата 23→24; исходные байты сохранились. Проверены поля, стабильные ID, дробные даты, суммы, одно явное округление и запись SwiftData с receipt. Это синтетические данные, а не личная база прежнего пользователя.
- Записи и `WalletMigrationReceipt` фиксируются одним `save()` в отдельном ModelContext того же контейнера. Read-only disk failure проверяет rollback и отсутствие частичных записей в основном контексте. Receipt переживает перезапуск и последующее редактирование; настройки восстанавливаются после прерывания между commit и UserDefaults.
- Холодная snapshot-копия проверяется по SHA-256 и переиспользуется при повторе. Исходник не открывается Realm. Частичные staging/working-каталоги очищаются, подтверждённая резервная копия остаётся.
- JSON export/import реализованы. Одинаковые ID с одинаковыми полями пропускаются; конфликт любого ID отклоняет весь файл. Импорт не перезаписывает историю и не затрагивает несохранённый пользовательский черновик.
- UI smoke: `build/UITests-Smoke-3.xcresult`, **1 passed, 0 failed, 0 skipped**, 82.9 с. Создание категории и расхода `12.34 USD`, закрытие клавиатуры заметки кнопкой Done, изменение на `23.45 USD`, обновление обзора, архивирование категории и сохранение операции после перезапуска.
- UI migration: `build/UITests-Migration-3.xcresult`, **1 passed, 0 failed, 0 skipped**, 25.95 с. Экран переноса показал 2 категории / 4 операции; выбран USD, запись была заблокирована до согласия с округлением. После переноса и перезапуска открыт обычный кошелёк, повторный импорт не предложен. SHA-256 исходной фикстуры в контейнере не изменился.
- Оба UI-прогона выполнены Xcode 27.2 на отдельном `iWallet UI QA`, iPhone 18 Pro Simulator / iOS 27.2, с английским интерфейсом и `en_US`. В smoke-result присутствует runtime warning `Invalid frame dimension (negative or non-finite)` при появлении клавиатуры. Стек приложения и подтверждённый визуальный дефект не выявлены; предупреждение не считается устранённым.
- Визуальная проверка: `build/QA/overview-ru-light.png`, `overview-ru-dark.png`, `overview-en-light.png`, `overview-ru-large.png`. На максимальном accessibility-размере устранено сжатие «Баланс»: заголовок и USD располагаются вертикально; обновлённый экран проверен. Это исправление не объявляется решением отдельного предупреждения при появлении клавиатуры.
- Подписанный `build/iWallet-2.0.0-signed.xcarchive` собран; `codesign --verify --deep --strict` прошёл. Динамический `Frameworks/RealmSwift.framework/RealmSwift` вложен, размер бинарника 10,854,800 байт. Прежняя ошибка отсутствующего framework устранена.
- После входа владельца в Xcode экспорт App Store IPA успешно выполнен: `build/AppStore/iWallet.ipa`. В текущем IPA проверены целостность ZIP, вложенный RealmSwift и полный `ThirdPartyNotices.txt`; SHA-256 notices совпадает с исходником: `3d6729c9937fdecf61642a6e2ff1fd90de563584c49074f50707762dad602d4d`. Лицензии доступны в Settings; их полнота независимо сверена с закреплёнными source packages. `ITSAppUsesNonExemptEncryption = false` обоснован в [технической проверке](EXPORT-COMPLIANCE-TECHNICAL.md).
- Прежняя карточка восстановлена, метаданные RU/EN и настройки выпуска сохранены. Экспорт IPA не является загрузкой Apple: upload, TestFlight-проверка обновления и публикация ещё не подтверждены.

## UI-тесты и воспроизведение

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

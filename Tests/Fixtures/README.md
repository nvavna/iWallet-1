# Historical iWallet schema 15 fixture

`iwallet-schema15-realm-10.40.0.realm` is a **synthetic database actually written by Realm Cocoa 10.40.0 / Realm Core 13.13.0**, not a current Realm database carrying an old application schema number. It contains no user data.

The original iWallet `Package.resolved` pinned Realm Swift commit `eed598a7aa9b56fcf7273ea4279a516af8f7d3f3` and Realm Core 13.13.0. That commit's [Package.swift](https://github.com/realm/realm-swift/blob/eed598a7aa9b56fcf7273ea4279a516af8f7d3f3/Package.swift) declares Cocoa 10.40.0 and Core 13.13.0. The official [v10.40.0 release](https://github.com/realm/realm-swift/releases/tag/v10.40.0), published May 26, 2023, uses the same Core version. The fixture writer uses that release's macOS arm64 Objective-C binary; it does not require an obsolete Swift compiler.

This validates the old storage engine/file format and original persisted schema. It is not a copy of a former customer's database, nor proof that every historical iWallet schema is supported.

## Provenance and checksums

- Official archive: [Carthage.xcframework.zip](https://github.com/realm/realm-swift/releases/download/v10.40.0/Carthage.xcframework.zip), 87,744,003 bytes.
- Downloaded archive SHA-256: `53e5b0976eb223205325a7fa3c62dcc0b38d1e00960db4d157768256f5180f6e`.
- Only `Realm.xcframework/macos-arm64_x86_64/Realm.framework` was extracted. Its `CFBundleShortVersionString` is `10.40.0`; its binary contains the Core version `13.13.0`.
- Fixture: 16,384 bytes; SHA-256 `b427523b505ddf61179a6b4af00870756efbcc1cd1bdbf3eef059f2ecad19bdd`.
- Realm header file-format bytes at offsets 20–21 are `0x17 0x17` (format 23). The **application** schema version is 15; these are separate version numbers.
- Two independent runs of the old writer on macOS 27.0.1 / Apple silicon produced byte-identical files with the fixture checksum above.

The archive checksum was calculated from the official downloaded asset and pinned by this project; it is not represented as a separately published vendor checksum. Framework binaries are not included in this repository or the app's dependency graph.

## Reproduce

From the repository root on macOS Apple silicon with Xcode command-line tools:

```sh
bash Scripts/generate-legacy-realm-fixture.sh /tmp/iwallet-regenerated.realm
shasum -a 256 /tmp/iwallet-regenerated.realm Tests/Fixtures/iwallet-schema15-realm-10.40.0.realm
```

The output path must not exist. The script downloads the fixed official release, verifies its archive checksum and framework version, compiles the Objective-C generator, and writes a new temporary Realm. It copies only the closed durable `.realm` file to the requested output and removes its own temporary download/build directory. It never opens an existing wallet. About 200 MB of temporary disk space is sufficient.

`generate-legacy-realm-fixture.m` defines the original persisted class/property names, primary keys, required strings/ObjectIds, `Float` amount, date, list relationship and derived backlink. `objc_runtime_name("Category")` preserves the original schema name while avoiding the Objective-C runtime's `Category` typedef. Income/expense enum values are stored as the original `Income` / `Expense` strings. No currency was present in the historical schema; a migration test explicitly chooses RUB.

## Deterministic contents

Category `64a000000000000000000001`: `Продукты`, `cart.fill`, `colorPurple`, `Expense`.

Category `64a000000000000000000003`: `Salary`, `banknote.fill`, `colorGreen`, `Income`.

| Transaction ObjectId suffix | Category suffix | Original Float literal | Unix timestamp | Note | Expected RUB minor units |
| --- | --- | --- | --- | --- | --- |
| `002` | `001` | `12.34f` | `1700000000.125` | `Milk / молоко` | 1234 |
| `005` | `001` | `0.01f` | `1700000001.5` | `Smallest cent` | 1 |
| `006` | `001` | `12.345f` | `1700000002.75` | `Explicit rounding case` | 1235 |
| `004` | `003` | `123.45f` | `1700000003.875` | `Synthetic income` | 12345 |

All ObjectId values share prefix `64a000000000000000000`. The `12.345f` record deliberately exercises the migration's explicit rounding report. Float precision already lost in an old database cannot be reconstructed.

Tests must copy this immutable fixture to a temporary directory before invoking the transition reader. They should verify its source bytes remain unchanged, converted record fields and stable identities, and atomic SwiftData receipt persistence. Opening the committed fixture directly with a newer Realm writer would upgrade it and destroy its historical-format value.

`LegacyWalletMigrationTests.testOriginalRealm1040FixtureTransfersIntoSwiftDataWithoutChangingSource` exercises this file through the production Realm 20 transition reader. The verified run upgraded only its disposable working copy from file format 23 to 24, preserved the fixture/source SHA-256, checked all four converted values and fractional dates, and committed the SwiftData records plus migration receipt. The old-format test and all 15 other legacy tests passed on November 5, 2026.

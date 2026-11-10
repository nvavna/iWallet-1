#!/bin/bash
set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 OUTPUT.realm (must not already exist)" >&2
  exit 2
fi
if [ "$(uname -s)" != "Darwin" ] || [ "$(uname -m)" != "arm64" ]; then
  echo "This verified generator requires macOS on Apple silicon and Xcode command-line tools." >&2
  exit 2
fi
if [ -e "$1" ]; then
  echo "Refusing to overwrite an existing fixture or wallet." >&2
  exit 2
fi

IWALLET_FIXTURE_SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
IWALLET_FIXTURE_TMP="$(mktemp -d "${TMPDIR:-/tmp}/iwallet-realm1040.XXXXXX")"
trap 'rm -rf "$IWALLET_FIXTURE_TMP"' EXIT
IWALLET_FIXTURE_ARCHIVE="$IWALLET_FIXTURE_TMP/Carthage.xcframework.zip"
IWALLET_FIXTURE_URL="https://github.com/realm/realm-swift/releases/download/v10.40.0/Carthage.xcframework.zip"
IWALLET_FIXTURE_ARCHIVE_SHA="53e5b0976eb223205325a7fa3c62dcc0b38d1e00960db4d157768256f5180f6e"

curl --fail --location --retry 2 --silent --show-error "$IWALLET_FIXTURE_URL" --output "$IWALLET_FIXTURE_ARCHIVE"
printf '%s  %s\n' "$IWALLET_FIXTURE_ARCHIVE_SHA" "$IWALLET_FIXTURE_ARCHIVE" | shasum -a 256 -c -
unzip -q "$IWALLET_FIXTURE_ARCHIVE" 'Realm.xcframework/macos-arm64_x86_64/*' -d "$IWALLET_FIXTURE_TMP"
IWALLET_FIXTURE_FRAMEWORK_DIR="$IWALLET_FIXTURE_TMP/Realm.xcframework/macos-arm64_x86_64"
IWALLET_FIXTURE_VERSION="$(plutil -extract CFBundleShortVersionString raw -o - "$IWALLET_FIXTURE_FRAMEWORK_DIR/Realm.framework/Resources/Info.plist")"
if [ "$IWALLET_FIXTURE_VERSION" != "10.40.0" ]; then
  echo "The downloaded framework has an unexpected version." >&2
  exit 1
fi
xcrun clang -fobjc-arc -arch arm64 \
  -F "$IWALLET_FIXTURE_FRAMEWORK_DIR" -framework Foundation -framework Realm \
  -Wl,-rpath,"$IWALLET_FIXTURE_FRAMEWORK_DIR" \
  "$IWALLET_FIXTURE_SCRIPT_DIR/generate-legacy-realm-fixture.m" \
  -o "$IWALLET_FIXTURE_TMP/generate-fixture"

# Let the old writer create its own transient lock/management files in the
# temporary directory. Export only the closed durable database to the caller.
"$IWALLET_FIXTURE_TMP/generate-fixture" "$IWALLET_FIXTURE_TMP/default.realm"
mkdir -p "$(dirname "$1")"
cp -n "$IWALLET_FIXTURE_TMP/default.realm" "$1"
shasum -a 256 "$1"

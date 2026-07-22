#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT="${PROJECT:-Clippa.xcodeproj}"
SCHEME="${SCHEME:-Clippa}"
CONFIGURATION="${CONFIGURATION:-Release}"
DESTINATION="${DESTINATION:-platform=macOS}"
OUTPUT_DIR="${OUTPUT_DIR:-outputs}"
APP_NAME="${APP_NAME:-Clippa}"
SMOKE_LAUNCH="${SMOKE_LAUNCH:-0}"
SKIP_TEST="${SKIP_TEST:-0}"

DERIVED_DATA_DIR="$(mktemp -d /tmp/clippa-release-derived-data.XXXXXX)"
CHECK_DIR="$(mktemp -d /tmp/clippa-release-check.XXXXXX)"

cleanup() {
    rm -rf "$CHECK_DIR"
    if [[ "${KEEP_DERIVED_DATA:-0}" != "1" ]]; then
        rm -rf "$DERIVED_DATA_DIR"
    fi
}
trap cleanup EXIT

cd "$ROOT_DIR"
mkdir -p "$OUTPUT_DIR"

if [[ "$SKIP_TEST" != "1" ]]; then
    echo "==> Test"
    xcodebuild \
        -project "$PROJECT" \
        -scheme "$SCHEME" \
        -destination "$DESTINATION" \
        test
else
    echo "==> Test skipped"
fi

echo "==> Build $CONFIGURATION"
xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -destination "$DESTINATION" \
    -derivedDataPath "$DERIVED_DATA_DIR" \
    build

APP_PATH="$DERIVED_DATA_DIR/Build/Products/$CONFIGURATION/$APP_NAME.app"
ZIP_PATH="$OUTPUT_DIR/$APP_NAME.app.zip"

if [[ ! -d "$APP_PATH" ]]; then
    echo "Missing app bundle at $APP_PATH" >&2
    exit 1
fi

echo "==> Package"
rm -f "$ZIP_PATH"
ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"

echo "==> Verify"
ditto -x -k "$ZIP_PATH" "$CHECK_DIR"
EXTRACTED_APP="$CHECK_DIR/$APP_NAME.app"
test -x "$EXTRACTED_APP/Contents/MacOS/$APP_NAME"
codesign --verify --deep --strict "$EXTRACTED_APP"

BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$EXTRACTED_APP/Contents/Info.plist")"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$EXTRACTED_APP/Contents/Info.plist")"
BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$EXTRACTED_APP/Contents/Info.plist")"
LSUI_ELEMENT="$(/usr/libexec/PlistBuddy -c 'Print :LSUIElement' "$EXTRACTED_APP/Contents/Info.plist")"

if [[ "$LSUI_ELEMENT" != "true" ]]; then
    echo "Expected LSUIElement=true, got $LSUI_ELEMENT" >&2
    exit 1
fi

if [[ "$SMOKE_LAUNCH" == "1" ]]; then
    echo "==> Smoke launch"
    open -n "$EXTRACTED_APP"
    sleep 2
    pgrep -x "$APP_NAME" >/dev/null
    osascript -e "tell application id \"$BUNDLE_ID\" to quit" >/dev/null 2>&1 || true
    sleep 1
    if pgrep -x "$APP_NAME" >/dev/null; then
        pkill -x "$APP_NAME" || true
    fi
fi

stat -f "Built %N (%z bytes)" "$ZIP_PATH"
echo "Bundle: $BUNDLE_ID"
echo "Version: $VERSION ($BUILD)"

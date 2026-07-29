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
: "${DEVELOPER_ID_APPLICATION:?Set DEVELOPER_ID_APPLICATION to a Developer ID Application certificate name.}"
: "${APPLE_TEAM_ID:?Set APPLE_TEAM_ID to the signing team identifier.}"

DERIVED_DATA_DIR="$(mktemp -d /tmp/clippa-release-derived-data.XXXXXX)"
CHECK_DIR="$(mktemp -d /tmp/clippa-release-check.XXXXXX)"
NOTARY_TEMP_DIR="$(mktemp -d /tmp/clippa-notary.XXXXXX)"
NOTARY_ZIP="$NOTARY_TEMP_DIR/Clippa.app.zip"

cleanup() {
    rm -rf "$CHECK_DIR"
    rm -rf "$NOTARY_TEMP_DIR"
    if [[ "${KEEP_DERIVED_DATA:-0}" != "1" ]]; then
        rm -rf "$DERIVED_DATA_DIR"
    fi
}
trap cleanup EXIT

cd "$ROOT_DIR"
mkdir -p "$OUTPUT_DIR"

if ! security find-identity -v -p codesigning | grep -F "$DEVELOPER_ID_APPLICATION" >/dev/null; then
    echo "Developer ID identity is not installed: $DEVELOPER_ID_APPLICATION" >&2
    exit 1
fi

NOTARY_ARGUMENTS=()
if [[ -n "${APPLE_NOTARY_KEYCHAIN_PROFILE:-}" ]]; then
    NOTARY_ARGUMENTS=(--keychain-profile "$APPLE_NOTARY_KEYCHAIN_PROFILE")
elif [[ -n "${APPLE_NOTARY_PRIVATE_KEY_PATH:-}" ]] &&
     [[ -n "${APPLE_NOTARY_KEY_ID:-}" ]] &&
     [[ -n "${APPLE_NOTARY_ISSUER_ID:-}" ]]; then
    NOTARY_ARGUMENTS=(
        --key "$APPLE_NOTARY_PRIVATE_KEY_PATH"
        --key-id "$APPLE_NOTARY_KEY_ID"
        --issuer "$APPLE_NOTARY_ISSUER_ID"
    )
else
    echo "Set APPLE_NOTARY_KEYCHAIN_PROFILE or all three App Store Connect API key variables." >&2
    exit 1
fi

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
    CODE_SIGN_STYLE=Manual \
    CODE_SIGN_IDENTITY="$DEVELOPER_ID_APPLICATION" \
    DEVELOPMENT_TEAM="$APPLE_TEAM_ID" \
    ENABLE_HARDENED_RUNTIME=YES \
    OTHER_CODE_SIGN_FLAGS="--timestamp" \
    build

APP_PATH="$DERIVED_DATA_DIR/Build/Products/$CONFIGURATION/$APP_NAME.app"
ZIP_PATH="$OUTPUT_DIR/$APP_NAME.app.zip"
CHECKSUM_PATH="$ZIP_PATH.sha256"

if [[ ! -d "$APP_PATH" ]]; then
    echo "Missing app bundle at $APP_PATH" >&2
    exit 1
fi

echo "==> Verify Developer ID signature"
codesign --verify --deep --strict --verbose=2 "$APP_PATH"
SIGNATURE_DETAILS="$(codesign -dv --verbose=4 "$APP_PATH" 2>&1)"
grep -F "Authority=Developer ID Application:" <<<"$SIGNATURE_DETAILS" >/dev/null
grep -E "flags=.*runtime" <<<"$SIGNATURE_DETAILS" >/dev/null
grep -F "TeamIdentifier=$APPLE_TEAM_ID" <<<"$SIGNATURE_DETAILS" >/dev/null

echo "==> Notarize"
ditto -c -k --keepParent "$APP_PATH" "$NOTARY_ZIP"
xcrun notarytool submit "$NOTARY_ZIP" "${NOTARY_ARGUMENTS[@]}" --wait
xcrun stapler staple "$APP_PATH"
xcrun stapler validate "$APP_PATH"
spctl --assess --type execute --verbose=4 "$APP_PATH"

echo "==> Package notarized app"
rm -f "$ZIP_PATH" "$CHECKSUM_PATH"
ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"

echo "==> Verify final archive"
ditto -x -k "$ZIP_PATH" "$CHECK_DIR"
EXTRACTED_APP="$CHECK_DIR/$APP_NAME.app"
test -x "$EXTRACTED_APP/Contents/MacOS/$APP_NAME"
codesign --verify --deep --strict --verbose=2 "$EXTRACTED_APP"
xcrun stapler validate "$EXTRACTED_APP"
spctl --assess --type execute --verbose=4 "$EXTRACTED_APP"

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

shasum -a 256 "$ZIP_PATH" > "$CHECKSUM_PATH"
stat -f "Built %N (%z bytes)" "$ZIP_PATH"
echo "Checksum: $CHECKSUM_PATH"
echo "Bundle: $BUNDLE_ID"
echo "Version: $VERSION ($BUILD)"

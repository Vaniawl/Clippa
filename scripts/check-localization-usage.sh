#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMP_DIR="$(mktemp -d /tmp/clippa-localization-usage.XXXXXX)"
trap 'rm -rf "$TEMP_DIR"' EXIT

cd "$ROOT_DIR"
xcodebuild \
    -exportLocalizations \
    -project Clippa.xcodeproj \
    -localizationPath "$TEMP_DIR" \
    -exportLanguage en \
    CODE_SIGNING_ALLOWED=NO \
    >/dev/null

XLIFF="$TEMP_DIR/en.xcloc/Localized Contents/en.xliff"

extract_sources() {
    local file_pattern="$1"
    local output="$2"
    awk -v file_pattern="$file_pattern" '
        /<file original=/ { file=$0 }
        /<source>/ {
            line=$0
            sub(/^.*<source>/, "", line)
            sub(/<\/source>.*$/, "", line)
            if (file ~ file_pattern) print line
        }
    ' "$XLIFF" |
        sed 's/&quot;/"/g;s/&amp;/\&/g;s/&apos;/'"'"'/g;s/&lt;/</g;s/&gt;/>/g' |
        grep -Ev '^ ?%(@|d|lld)$' |
        LC_ALL=C sort -u > "$output"
}

catalog_keys() {
    sed -n 's/^"\(.*\)" = .*/\1/p' "$1" | LC_ALL=C sort -u
}

extract_sources \
    'Clippa/Resources/en\.lproj/Localizable\.strings' \
    "$TEMP_DIR/macOS-sources"
extract_sources \
    'ClippaIOS/Resources/en\.lproj/Localizable\.strings' \
    "$TEMP_DIR/iOS-sources"

catalog_keys "Clippa/Resources/en.lproj/Localizable.strings" > "$TEMP_DIR/macOS-catalog"
catalog_keys "ClippaIOS/Resources/en.lproj/Localizable.strings" > "$TEMP_DIR/iOS-catalog"

FAILURE=0
for platform in macOS iOS; do
    if missing="$(comm -23 "$TEMP_DIR/$platform-sources" "$TEMP_DIR/$platform-catalog")" &&
       [[ -n "$missing" ]]; then
        echo "$platform localization is missing extracted keys:" >&2
        echo "$missing" >&2
        FAILURE=1
    fi
done

if [[ "$FAILURE" -ne 0 ]]; then
    exit 1
fi
echo "Xcode localization usage check passed."

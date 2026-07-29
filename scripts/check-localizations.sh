#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMP_DIR="$(mktemp -d /tmp/clippa-localization-check.XXXXXX)"
trap 'rm -rf "$TEMP_DIR"' EXIT

check_catalog() {
    local catalog_root="$1"
    local name="$2"
    local english="$catalog_root/en.lproj/Localizable.strings"
    local ukrainian="$catalog_root/uk.lproj/Localizable.strings"
    local english_keys="$TEMP_DIR/$name-en.keys"
    local ukrainian_keys="$TEMP_DIR/$name-uk.keys"

    test -f "$english"
    test -f "$ukrainian"
    sed -n 's/^"\(.*\)" = .*/\1/p' "$english" | LC_ALL=C sort > "$english_keys"
    sed -n 's/^"\(.*\)" = .*/\1/p' "$ukrainian" | LC_ALL=C sort > "$ukrainian_keys"

    if [[ -n "$(uniq -d "$english_keys")" ]] || [[ -n "$(uniq -d "$ukrainian_keys")" ]]; then
        echo "$name localization contains duplicate keys." >&2
        uniq -d "$english_keys" >&2
        uniq -d "$ukrainian_keys" >&2
        return 1
    fi

    if ! diff -u "$english_keys" "$ukrainian_keys"; then
        echo "$name English/Ukrainian localization keys differ." >&2
        return 1
    fi
}

cd "$ROOT_DIR"
check_catalog "Clippa/Resources" "macOS"
check_catalog "ClippaIOS/Resources" "iOS"
grep -F "AA0001010000000000000032 /* Localizable.strings in Resources */" \
    Clippa.xcodeproj/project.pbxproj >/dev/null

echo "Localization parity passed."

#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

xcodebuild \
  -project Clippa.xcodeproj \
  -scheme Clippa \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO \
  test

IOS_DESTINATION="$(
  xcrun simctl list devices available |
    awk -F '[()]' '/iPhone/ { print "platform=iOS Simulator,id=" $2; exit }'
)"
if [[ -z "$IOS_DESTINATION" ]]; then
  echo "No available iPhone simulator found" >&2
  exit 1
fi

CLIPPA_DISABLE_AUTOMATIC_CLIPBOARD_CAPTURE=1 \
xcodebuild \
  -project Clippa.xcodeproj \
  -scheme 'Clippa iOS' \
  -destination "$IOS_DESTINATION" \
  CODE_SIGNING_ALLOWED=NO \
  test

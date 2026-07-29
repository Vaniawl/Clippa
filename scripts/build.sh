#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

xcodebuild \
  -project Clippa.xcodeproj \
  -scheme Clippa \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO \
  build

xcodebuild \
  -project Clippa.xcodeproj \
  -scheme 'Clippa iOS' \
  -sdk iphonesimulator \
  CODE_SIGNING_ALLOWED=NO \
  build

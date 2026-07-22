# Clippa

Clippa is a macOS menu-bar clipboard history app built with SwiftUI. It keeps text, links, images, and file references locally, encrypts stored history with AES-GCM using a Keychain-backed key, and supports quick paste from a global shortcut.

Website: https://vaniawl.github.io/Clippa/

## Requirements

- macOS 26.0 or newer
- Xcode 26.6 or newer

## Install

Fast install from GitHub:

```bash
npx github:Vaniawl/Clippa
```

After the npm package is published:

```bash
npx clippa-macos
```

Or download `outputs/Clippa.app.zip`, unzip it, move `Clippa.app` to `/Applications`, then open it. macOS may require Accessibility permission for automatic paste. Without Accessibility permission, Clippa still copies the selected item to the clipboard.

## Build

```bash
xcodebuild -project Clippa.xcodeproj -scheme Clippa -destination 'platform=macOS' test
xcodebuild -project Clippa.xcodeproj -scheme Clippa -configuration Release -destination 'platform=macOS' build
```

## Release

Use the release script so tests, packaging, and bundle verification run the same way every time:

```bash
./scripts/release.sh
```

The distributable app archive is written to:

```bash
outputs/Clippa.app.zip
```

To also launch the built app once as a smoke test:

```bash
SMOKE_LAUNCH=1 ./scripts/release.sh
```

## npm Publish

The npm package is prepared as `clippa-macos`. Publishing requires an authenticated npm session:

```bash
npm adduser
npm publish --access public
```

## Update From Git

For an existing checkout:

```bash
git pull origin main
```

For a fresh checkout:

```bash
git clone https://github.com/Vaniawl/Clippa.git
cd Clippa
```

## Production Notes

- Bundle identifier: `com.ivandovhosheia.Clippa`
- Version: `1.0.0`
- Release builds use hardened runtime.
- Clipboard history is stored under Application Support and encrypted locally.
- Pinned items are retained until deleted; unpinned history is limited to 100 active items and seven days since last activity.

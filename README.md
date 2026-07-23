<p align="center">
  <img src="docs/assets/app-icon.png" width="96" height="96" alt="Clippa icon">
</p>

<h1 align="center">Clippa</h1>

<p align="center">
  A small, private macOS clipboard app built around one shortcut: press Command-Shift-V, choose a clip, paste.
</p>

<p align="center">
  <a href="https://vaniawl.github.io/Clippa/">Website</a>
  ·
  <a href="https://github.com/Vaniawl/Clippa/releases">Releases</a>
  ·
  <a href="#privacy">Privacy</a>
</p>

<p align="center">
  <img src="docs/assets/screenshot-panel.svg" alt="Clippa clipboard panel" width="900">
</p>

## Install Clippa

Install from npm:

```bash
npx clippa
```

Or install the command globally:

```bash
npm install -g clippa
clippa
```

GitHub install is also available:

```bash
npx github:Vaniawl/Clippa
```

Do not use `npx install clippa`: npm treats `install` as the package name in that command. The correct npx command is `npx clippa`.

After it opens, grant Accessibility access when macOS asks. Clippa needs that permission only to paste the selected item into the app where your cursor is already active.

Useful installer options:

```bash
npx clippa -- --no-open
npx clippa -- --install-dir ~/Applications
npx github:Vaniawl/Clippa -- --no-open
npx github:Vaniawl/Clippa -- --install-dir ~/Applications
```

You can also download `Clippa.app.zip` from the latest GitHub release, unzip it, move `Clippa.app` to `/Applications`, and open it.

## How It Works

- Runs quietly in the background as a menu-bar app.
- Press `Command-Shift-V` while your cursor is in a text field.
- Use `Up` / `Down` to choose a clipboard item.
- Press `Enter` or click an item to paste it.
- Press `Esc` or click outside the panel to close it.
- Stores recent text, links, images, and file references locally on your Mac.

## Privacy

Clippa does not upload clipboard contents, does not use analytics, and does not require an account. Clipboard history is stored only on your Mac and encrypted locally with a per-user AES-GCM key file in Application Support. Clippa does not read or write Keychain items at startup, so locally signed reinstall builds do not trigger Keychain password prompts.

Accessibility permission is only used to confirm there is an editable field under the cursor and to paste the selected clip into that frontmost app.

## Requirements

- macOS 26.0 or newer
- Xcode 26.6 or newer, only if you want to build from source

## Build From Source

```bash
git clone https://github.com/Vaniawl/Clippa.git
cd Clippa
xcodebuild -project Clippa.xcodeproj -scheme Clippa -destination 'platform=macOS' test
SMOKE_LAUNCH=1 ./scripts/release.sh
```

The packaged app is written to:

```bash
outputs/Clippa.app.zip
```

## npm Publish

The npm installer package is prepared as `clippa`. Publishing to npm requires an authenticated npm session:

```bash
npm adduser
npm publish --access public
```

## Update From Git

For an existing checkout:

```bash
git pull origin main
```

## Production Notes

- Bundle identifier: `com.ivandovhosheia.Clippa`
- Version: `1.0.0`
- Release builds use hardened runtime.
- Recent history is limited to 100 active items and stored only on this Mac.

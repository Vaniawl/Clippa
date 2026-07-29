# Architecture Overview

## Shape

Clippa is one Xcode project with four targets:

- `Clippa`: a macOS `MenuBarExtra`, a non-activating clipboard panel, and a Settings
  window. `AppState` wires services and coordinates application actions.
- `ClippaTests`: macOS unit and integration tests.
- `Clippa iOS`: an iPhone companion using SwiftUI, UIKit pasteboard APIs, and App Intents.
- `ClippaIOSTests`: companion-store tests.

The macOS flow is:

`NSPasteboard` → `PasteboardMonitor` → `ClipboardStore` → `EncryptedHistoryStore`

Selection reverses the flow through `PasteService`, which restores the prior application
and sends Command-V when Accessibility permission is available.

## Ownership

- `AppSettings` owns user preferences.
- `ClipboardStore` owns ordered in-memory item metadata and UI selection/filter state.
- `EncryptedHistoryStore` owns the committed manifest.
- `EncryptedBlobStore` owns encrypted binary payload files.
- `LocalHistoryKeyStore` owns acquisition and migration of the AES key.
- `PanelController` and `SettingsWindowController` own AppKit window lifecycles.
- `IOSClipStore` owns iPhone clip state; its persistence adapter owns the on-disk archive.

## Persistence

The macOS manifest and image blobs are AES-GCM encrypted with a 256-bit key. New
installations store that key in the macOS Data Protection Keychain. Existing local key
files are migrated only after Keychain write and read-back verification.

History saves follow a commit protocol:

1. Write missing immutable content-addressed blobs.
2. Encode and atomically replace the encrypted manifest.
3. Remove orphaned blobs after the manifest commit.

The committed manifest is authoritative. Orphan blobs are safe; a manifest referencing a
missing or corrupt blob degrades only that item and produces an observable recovery error.

See ADR 0001 for migration and rollback decisions.

## Trust boundaries

- The system clipboard and selected import files are untrusted input.
- Accessibility APIs and synthetic events cross from Clippa into another application.
- Keychain and Application Support are OS-managed persistence boundaries.
- GitHub/npm/Homebrew release artifacts cross a public supply-chain boundary.

The detailed controls are in `docs/security/threat-model.md`.

## Known structural debt

- Some UI/controller files are larger than ideal and mix presentation with orchestration.
- File bookmarks are captured but not yet resolved after file moves.
- Installer version metadata is duplicated in several files.
- Full macOS UI automation is not yet present.

Structural changes require an ADR in `docs/adr/`.

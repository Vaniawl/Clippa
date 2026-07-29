# Changelog

All notable product changes are documented here.

## Unreleased

### Added

- Cross-provider enterprise agent framework and repository quality gates.
- Architecture, threat model, test strategy, runbook, and release checklist.
- Configurable global shortcut recorder, registration status, and menu-bar fallback.
- Plain-text paste with Command-Return and contextual advanced-search help.
- English/Ukrainian localization for macOS and iPhone with parity and Xcode extraction gates.
- Configurable macOS disk budget, SwiftUI previews, and a rendered panel fixture.
- Destination-aware panel header, persistent keyboard-command footer, Pinned/Recent
  grouping, and inline Undo feedback.

### Changed

- macOS encrypted history now commits blobs before the manifest, cleans only after commit,
  loads images lazily, avoids unchanged rewrites, rejects stale save generations, and
  preserves unrelated items when a blob is missing.
- New encryption keys live in Keychain; legacy file keys migrate only after verified
  Keychain read-back and retain a downgrade backup.
- iPhone history moved from one `UserDefaults` value to a protected Application Support
  manifest with separate image files and verified legacy migration.
- Import/capture payloads are bounded and untrusted archive metadata is rebuilt.
- macOS row clicks now select safely; Return or double-click performs the paste. Pinned
  items remain visible in All and in content-type filters.
- Release packaging now requires Developer ID signing and notarization, staples and
  Gatekeeper-assesses the final app, and emits a SHA-256 checksum.

## 1.0.13

- Current public macOS release and iPhone companion baseline.

# Operational Runbook

## Health

- The menu-bar paperclip is present.
- The configured global shortcut opens the panel, or the menu-bar fallback opens it.
- Settings reports the shortcut registration and Accessibility state.
- The panel does not display a persistence/recovery error banner.
- New copied content appears unless capture is paused or its source is excluded.

## Startup and shutdown

At startup Clippa loads the last committed manifest, registers the shortcut, then begins
clipboard monitoring. At normal termination it stops monitoring, unregisters the hotkey,
and flushes the current snapshot before replying to macOS termination.

## Backup and restore

macOS history is stored under `~/Library/Application Support/Clippa/`; its encryption key
is in Keychain. Copying only the encrypted files without the Keychain item is not a usable
backup. Pinned clips can be exported to a local JSON archive for user-controlled backup.

The iPhone companion stores its archive under Application Support and participates in the
device backup policy unless excluded by the OS.

## Failures

- **Shortcut unavailable:** use the menu-bar Open History command, choose another
  shortcut, and retry registration.
- **Accessibility unavailable:** selected content remains on the system clipboard; open
  System Settings from Clippa and enable Accessibility.
- **History manifest corrupt:** Clippa isolates the manifest and reports its filename.
- **Binary payload unavailable:** Clippa retains other items, reports the affected item,
  and permits its removal.
- **Save failed:** Clippa retains in-memory history, shows an error, and retries on the
  next mutation or explicit retry.
- **Key migration failed:** Clippa leaves the legacy key intact and refuses to replace the
  existing encrypted history with a new key.

## Diagnostics

- Run `./scripts/test.sh` for product tests.
- Run `./scripts/ci.sh` for framework and product gates.
- Inspect `~/Library/Application Support/Clippa/` metadata only; never attach history or
  key files to a public issue.
- Use Console filtered by the Clippa process for OS-level Accessibility/Keychain errors.
- Run `codesign -dv --verbose=4 Clippa.app` and `spctl -a -vv --type execute Clippa.app`
  on a release candidate.

## Escalation

Security or privacy problems use GitHub private vulnerability reporting as documented in
`SECURITY.md`. Public bug reports must contain synthetic clipboard content only.

## Rollback

Application rollback is a replacement of `Clippa.app`. Persistence migrations must keep
the previous manifest until the new manifest and Keychain key are verified. If rollback
to a pre-Keychain version is required, restore the legacy key backup before launch; this
is a temporary migration compatibility path and must be removed only in a major release.

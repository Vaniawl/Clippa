# Threat Model

## Assets

- Clipboard text, links, images, file paths, source-application identifiers, and timestamps.
- Pinned archives selected for import/export.
- The AES-GCM history key in Keychain and any temporary legacy migration copy.
- Accessibility permission and the ability to synthesize paste keystrokes.
- Release-signing/notarization credentials, which are CI secrets and never repository data.
- Provider credentials and plaintext agent-run logs introduced by the agent framework.

## Actors

- The local user.
- Another local process able to write hostile clipboard representations.
- A malicious or malformed pinned archive.
- A process with the same user account’s filesystem access.
- A compromised release mirror, npm package, Homebrew formula, or GitHub workflow.
- A malicious repository/web document read by an automated coding agent.

## Trust boundaries and data flows

1. **System pasteboard → monitor:** pasteboard types, URLs, images, and files are untrusted.
   Concealed/transient markers and excluded source applications are rejected before capture.
2. **Monitor → in-memory store → encrypted persistence:** content is normalized, bounded,
   hashed, encrypted, and committed atomically. Failures preserve the prior snapshot.
3. **Application Support ↔ Keychain:** the manifest/blob files and encryption key are
   deliberately separated. Migration verifies the Keychain copy before legacy cleanup.
4. **Pinned archive ↔ user-selected file:** archive version, byte size, item count, payload
   consistency, URLs, and binary size are validated before state mutation.
5. **Clippa → target application:** Accessibility focus restoration and synthetic Command-V
   operate only on the application captured before the panel opened.
6. **Source repository → CI → public artifact:** pinned actions, secret scanning,
   dependency scanning, Developer ID signing, notarization, Gatekeeper assessment, and
   checksums establish artifact provenance.
7. **Agent framework → provider CLI:** project instructions and fetched content are
   untrusted input; framework permission, drift, timeout, and evidence gates constrain it.

## Controls

- No network client or analytics SDK exists in the product targets.
- AES-GCM provides confidentiality and authentication for manifests and blobs.
- Content-addressed filenames are generated from SHA-256, not external paths.
- History directories and legacy key material use user-only filesystem permissions.
- Keychain items use a device-only accessibility class.
- Import and clipboard binary payloads have explicit size and count limits.
- Persistence errors are visible and never trigger a new key over unreadable history.
- Release secrets are environment/CI inputs and are excluded by `.gitignore`/secret scans.

## Open findings

- **Blocking for public release:** the current 1.0.13 ZIP remains ad-hoc signed and
  rejected by Gatekeeper. The new pipeline is fail-closed, but a credentialed,
  notarized replacement artifact is still required for a Go verdict.
- **Important:** existing installations temporarily retain a rollback copy of the legacy
  key during migration; it preserves downgrade recovery but weakens at-rest separation.
- **Important:** bookmarks are resolved before file use, but stale successful bookmarks
  are not yet refreshed back into the encrypted manifest.
- **Important:** macOS UI automation and real Accessibility paste testing are limited.

## Not assessed

- Organization-managed Macs with nonstandard MDM Accessibility/Keychain policy:
  `NOT ASSESSED` because no managed-device environment is available.
- iCloud/device-backup extraction resistance for iPhone Application Support:
  `NOT ASSESSED` because backup policy depends on the user’s device configuration.

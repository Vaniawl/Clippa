# Test Strategy

## Quality risks

- Silent clipboard-history loss during partial writes, migration, or termination.
- A corrupt image blob resetting unrelated history.
- Keychain denial or malformed legacy key data causing fail-open behavior.
- Shortcut conflicts making the primary UI unreachable.
- Large image histories causing excessive memory, CPU, or disk activity.
- iOS persistence blocking the main actor or losing state across relaunch.
- A release package passing `codesign --verify` but failing Gatekeeper.

## Test levels

- Unit tests cover payload classification, cleaning, search, retention, shortcut mapping,
  privacy filtering, paste decisions, and iPhone store behavior.
- Storage integration tests use temporary directories and injected key stores.
- Failure-injection tests cover missing/corrupt blobs, failed commits, failed Keychain
  migration, and invalid imports.
- UI-level checks cover keyboard actions, accessibility actions, empty/error states, and
  screenshot fixtures where automation is available.
- Release checks exercise build, archive structure, code signature, notarization status,
  smoke launch, and installer metadata.

## Commands

- `./scripts/build.sh` builds macOS and iOS targets without requiring local signing.
- `./scripts/test.sh` runs macOS and iOS tests.
- `./scripts/ci.sh` runs repository/framework validation followed by build and tests.
- `SMOKE_LAUNCH=1 ./scripts/release.sh` creates and smoke-tests the release archive.

## Environments and data

Tests use synthetic text, URLs, generated pixels, temporary directories, isolated
`UserDefaults` suites, and mock pasteboards. Real clipboard contents, credentials,
signing identities, and user Application Support data must never enter fixtures.

## Failure paths that matter most

1. Manifest write fails after blob preparation.
2. Cleanup fails after a successful manifest commit.
3. One image blob is missing or fails authentication.
4. Keychain lookup/write fails or a legacy key has the wrong size.
5. The configured global shortcut is already registered by another application.
6. Import data is oversized, malformed, inconsistent, or from a future archive version.
7. Disk is full during macOS or iOS persistence.

## Performance and resource safety

- Measure launch and panel responsiveness with histories containing the maximum item count.
- Confirm immutable blobs are not rewritten on metadata-only changes.
- Record peak resident memory for a representative large-image history.
- CI output is streamed; generated framework tests retain explicit provider timeouts.

## Release gates

No release is Go without both platform test suites, framework drift checks, a clean
security review for changed boundaries, migration evidence, and a Gatekeeper assessment
of the exact candidate artifact. Missing credentials make notarization `NOT RUN`, not pass.

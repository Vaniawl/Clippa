# ADR 0001: Durable Local Persistence and Keychain Migration

- Status: Accepted
- Date: 2026-07-29
- Owners: Vaniawl and Clippa contributors
- Traceability: CLP-001, CLP-002, CLP-003, CLP-005, CLP-012

## Context

The existing macOS store writes encrypted image blobs, removes blobs absent from the new
snapshot, and only then atomically replaces the manifest. A failure between cleanup and
manifest replacement can leave the last committed manifest referencing deleted data.
Loading also decrypts every image into memory, and every save rewrites every image blob.

The history AES key is stored as a user-readable file beside the ciphertext. File
permissions prevent other accounts from reading it but do not separate the key from the
data for processes acting as the same user.

The iPhone companion encodes all clips, including image bytes, into one `UserDefaults`
value on the main actor.

## Decision

### macOS commit protocol

- Image blobs are immutable and addressed by the payload SHA-256.
- A save writes only missing blobs, atomically commits the encrypted manifest, then
  performs best-effort orphan cleanup.
- Cleanup failure never invalidates a successful commit; it is observable and retried.
- A missing/corrupt image blob affects only that item. The manifest is isolated only when
  the manifest itself cannot be authenticated or decoded.
- Stored images are represented by metadata and an encrypted blob reference. Binary data
  is decrypted on demand for paste, preview, OCR, drag, or export.

### Key storage and migration

- New keys are stored in the macOS Data Protection Keychain with a device-only
  accessibility class.
- On upgrade, a valid legacy 32-byte key is written to Keychain and read back before any
  cleanup.
- A migration failure leaves the legacy key and existing encrypted history unchanged.
- A time-bounded legacy backup is retained for downgrade recovery and documented as a
  residual risk. New installations never create a local key file.
- An unreadable existing store never causes automatic generation of a replacement key.

### iPhone persistence

- Clip metadata is stored as an atomically replaced archive in Application Support.
- Image bytes are stored as separate content-addressed files.
- Legacy `UserDefaults` data migrates once after the file archive is committed.
- Persistence work is serialized away from UI rendering, and the store exposes a flush
  operation for lifecycle/tests.

### Limits and input validation

- Clipboard and import payloads have explicit per-item and total byte limits.
- Archive versions, counts, payload kinds, hashes, and paths are validated before state
  mutation.

## Alternatives

- **Keep the local key file:** rejected because it provides weak same-user separation.
- **Use one encrypted database:** deferred; it adds a runtime/storage dependency and a
  larger migration surface without being necessary for the current item limits.
- **Delete old blobs before commit:** rejected because it is not crash-safe.
- **Continue loading all image data at launch:** rejected because memory grows with total
  image history rather than visible/active content.
- **Keep iPhone history in UserDefaults:** rejected because preferences are not a bulk
  binary store and writes block the main actor.

## Consequences

- Paste/preview/export paths that require image bytes become asynchronous.
- Existing manifest decoding remains supported; its image blob references already contain
  the information needed for lazy materialization.
- Temporary orphan blobs are possible after a crash but are safe and cleaned later.
- Keychain access failures become explicit user-visible storage errors.
- Downgrading across the key migration boundary requires restoring the documented legacy
  backup.

## Validation

- Storage integration tests cover round trip, missing/corrupt blob isolation, manifest
  corruption, commit failure, orphan cleanup, and unchanged-blob reuse.
- Key tests cover new creation, legacy migration, read-back verification failure, invalid
  key length, and no replacement key on existing-store failure.
- iPhone tests cover legacy migration, archive round trip, image blobs, and write failure.
- Resource tests/measurements compare launch memory and metadata-only saves with the
  maximum configured history.

## Rollback

- The previous manifest remains recoverable until the new manifest commit succeeds.
- Orphan cleanup is never required for correctness.
- During the compatibility window, restoring the legacy key backup permits rollback to
  1.0.13. Removing that backup requires a later explicit migration decision.

# Backlog

Now/Next items are approved by the product owner in the 2026-07-29 hardening request.
Candidates remain unapproved until explicitly promoted.

## Now

- [x] CLP-001 Make encrypted history and binary-blob commits crash-safe and observable.
- [x] CLP-002 Move new history keys to Keychain and migrate legacy local key files safely.
- [x] CLP-003 Avoid eagerly loading and repeatedly rewriting every stored image.
- [x] CLP-004 Make the global panel shortcut configurable, persistent, and recoverable
      when registration fails.
- [x] CLP-005 Move iPhone clip archives out of `UserDefaults` into file-backed storage.
- [x] CLP-006 Surface save/import/export/OCR failures with actionable UI.
- [x] CLP-007 Complete English/Ukrainian localization and add localization drift checks.
- [x] CLP-008 Prepare Developer ID signing, notarization, Gatekeeper verification, and
      reproducible release metadata.
- [x] CLP-009 Fill and validate the adopted enterprise agent-framework project files.

## Next

- [x] CLP-010 Add paste-as-plain-text as a first-class keyboard and context-menu action.
- [x] CLP-011 Add discoverable help for advanced search tokens.
- [x] CLP-012 Add a configurable on-disk byte budget in addition to item retention.
- [x] CLP-013 Add macOS UI previews and screenshot-regression fixtures.
- [x] CLP-014 Make mouse selection safe and add destination context, truthful All results,
      keyboard-command guidance, and inline Undo to the macOS panel.

## Later

- [ ] Add failure-injection coverage for app termination during an in-flight save.
- [ ] Refresh stale file bookmarks after successful moved-file resolution.
- [ ] Add installer tests for redirects, archive validation, and upgrade rollback.

## Candidates

Unapproved ideas, findings, and out-of-scope proposals land here. Nothing in this
section is implemented without explicit product-owner approval (scope-control policy).

- Optional peer-to-peer clipboard synchronization. This would introduce a new network
  trust boundary and requires separate product approval and threat modeling.
- Rich clipboard editing or transformation pipelines beyond plain-text paste.

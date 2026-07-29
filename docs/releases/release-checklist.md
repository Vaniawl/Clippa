# Release Checklist

Ticked entries carry evidence for the exact candidate commit and artifact. An unticked
entry is a real gap, never a formality. `NOT RUN` is stated, never silently passed.

## Product

- [ ] Approved backlog criteria are complete.
- [ ] macOS and iOS test suites pass on the candidate commit.
- [ ] Repository validation, framework drift, secret scan, and dependency scan pass.
- [ ] Security and resource-safety reviews have no unresolved Blocking findings.
- [ ] Keyboard/accessibility and visual-regression checks are recorded for UI changes.
- [ ] English and Ukrainian localization parity checks pass.

## Migration and recovery

- [ ] Upgrade from the previous release preserves text, link, file, image, and pinned data.
- [ ] Legacy key migration succeeds and its failure path preserves the old store.
- [ ] Missing/corrupt blob recovery preserves unrelated history.
- [ ] Save interruption and disk-full behavior preserve the previous committed manifest.
- [ ] Downgrade/rollback procedure and its key implications are documented.

## Distribution

- [ ] Release build uses hardened runtime and a Developer ID Application identity.
- [ ] `codesign --verify --deep --strict --verbose=2` passes.
- [ ] `notarytool` submission is accepted and the ticket is stapled.
- [ ] `stapler validate` and `spctl --assess --type execute` pass.
- [ ] ZIP checksum is published and installer metadata matches the Xcode version.
- [ ] Fresh install, upgrade install, smoke launch, and uninstall/rollback are exercised.

## Documentation and decision

- [ ] README, changelog, privacy/security docs, notices, and website are current.
- [ ] Known limitations are classified as blocking or accepted.
- [ ] A human product owner records Go / Conditional Go / No-Go.

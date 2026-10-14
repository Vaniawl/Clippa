# Release checklist — <version> / <build>

Candidate revision and dirty-diff identity:
Artifact/archive identifier:
Platform, SDK/toolchain, supported OS versions:
Owner and decision date:
Evidence dossier:

Create a fresh copy for each candidate; unchecked fields are not passed gates. Record PASS,
FAIL, NOT RUN or N/A (with reason) and evidence for each applicable item. A corrected build
needs evidence on the corrected candidate. This checklist does not authorize delivery.

- [ ] Acceptance criteria map to candidate-specific evidence.
- [ ] Relevant tests and independent risk-required reviews completed; reruns disclosed.
- [ ] Fresh install and supported previous-version upgrades verified.
- [ ] Data/commerce compatibility and supported recovery exercised or justified N/A.
- [ ] Archive/export/signing and symbols verified for the intended distribution route.
- [ ] Metadata, localized screenshots, support/privacy URLs and actual feature claims agree.
- [ ] Privacy/SDK/required-reason declarations, permissions, age/export/territory requirements assessed.
- [ ] Accessibility claims reflect actual tested tasks/devices; missing evidence is explicit.
- [ ] TestFlight/App Review requirements and current SDK submission rules checked.
- [ ] Monitoring, incident owner and recovery/containment procedure available.
- [ ] Release notes and known limitations prepared; unresolved gates have owners.
- [ ] Human release decision and separately authorized external actions recorded.

Decision: Go / Conditional Go / No-Go (not evaluated by default)
Conditions, owners and deadlines:
External delivery status: NOT RUN

For App Store delivery, pausing a phased release does not reverse updates already installed.
Plan a corrected version and supported containment; do not invent remote controls in the app.

# Definition of Done Contract

A task, slice, or release is Done only when every applicable line below is satisfied **with evidence** (see evidence policy). Non-applicable lines are marked N/A with a reason, not skipped silently.

## Task-level DoD

- [ ] Acceptance criteria from the task contract met — evidence per criterion.
- [ ] Focused tests exist for changed behavior, including at least one failure path.
- [ ] Validation commands run with actual output recorded.
- [ ] No changes outside owned files.
- [ ] Unrelated findings filed as backlog candidates, not implemented.

## Slice-level DoD (adds)

- [ ] Broader validation gate run (`./scripts/ci.sh` or project equivalent).
- [ ] Security impact assessed; threat model updated if a trust boundary changed.
- [ ] Accessibility checked for UI changes (see ui-ux-review skill).
- [ ] Documentation affected by the change updated.
- [ ] Compatibility/migration impact stated.
- [ ] Traceability: change references its requirement/backlog item.

## Release-level DoD (adds)

- [ ] A new version/build/revision-specific checklist, initialized from `agent-framework/templates/release-checklist.md`, is complete with evidence. Historical checked starter reports are not inputs for a new candidate.
- [ ] Install, supported upgrades and technology-specific recovery validated; mark genuine N/A with a reason. Recovery is rollback where supported, backup/restore or forward-fix where necessary; unsupported reversal is never claimed.
- [ ] Observability adequate for operating the change.
- [ ] Known limitations documented.
- [ ] Human approval recorded. Releases are never agent-approved.

## Apple UI DoD (adds when native Apple UI changes)

Use the compact `agent-framework/canonical/policies/apple-product-engineering.md` router
and the native procedure in `ui-ux-review/references/native-apple.md`; original standard
sections 73–74 remain in `policies/apple-product-engineering-reference.md`. Read only
applicable criteria for affected native UI. Verify relevant normal/loading/empty/error/
disabled states, long content, appearances, adaptive sizes, keyboard/pointer/touch behavior,
scroll continuity, purposeful motion, Reduce Motion, and accessibility. Reuse the existing
architecture and components, compile affected targets, and resolve avoidable new warnings.
Record runtime and visual evidence separately from build results. Mark unavailable checks
NOT RUN and genuinely inapplicable criteria N/A with reasons; do not claim full UI polish
from source inspection alone.

New or materially redesigned screens have a product-specific visual direction and composition
specified before implementation using `apple-experience-design`. Compare inspected runtime
captures against screen-specific polish criteria and record corrections/re-review of significant
visual findings. Existing specifications cover mechanical changes. Passing compilation or UI
element assertions alone does not satisfy visual-design acceptance.

For screen-building requests, the coordinator carries out the first-request UI procedure
through the approved implementation and correction cycle. Handover includes representative
capture paths and actual inspected criteria for the tested revision, conditions and states;
open significant findings are explicit. A scaffold or design specialist handoff alone does
not complete a product-building request. Unavailable visual inspection leaves visual
acceptance NOT RUN rather than silently converting a build pass into professional polish.

## Enforcement

- Reaching DoD completes the current approved outcome; finish its handover and stop unless broader work is explicitly authorized.
- A DoD claim without per-line evidence is invalid; reviewers reject it as unverified.
- While `scripts/build.sh`/`scripts/test.sh` remain stubs, test-related lines can only be `NOT RUN` — they must never be reported as passing.

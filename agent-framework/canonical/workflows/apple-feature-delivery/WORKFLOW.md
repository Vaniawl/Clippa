---
id: apple-feature-delivery
title: Apple Feature Delivery
description: Deliver an approved Apple feature through applicable requirements, native design, implementation,
  tests and independent risk review.
roles:
- orchestrator
- product-manager
- user-researcher
- ui-ux-designer
- software-architect
- implementation-engineer
- qa-test-engineer
- code-reviewer
- accessibility-reviewer
- security-privacy-reviewer
- localization-specialist
entry_criteria:
- The user requests this bounded outcome; execution is limited to authorized scope.
exit_criteria:
- Acceptance criteria have evidence, ownership is respected and required independent gates are resolved
  or explicitly open.
---

# Apple Feature Delivery

Roles below define responsibility, not mandatory agent calls. The coordinator may work
directly; significant/risky changes retain independent review under the delegation policy.
Use available task-relevant methods only and respect each role's write ownership.

1. Coordinator confirms the approved user outcome, acceptance criteria, platform and changed risk. Use supplied research; PM/research/design/architecture expertise is invoked only for an actual gap.
2. For new/materially redesigned UI define native interaction, states and visual criteria; routine edits reuse the existing specification. Structural changes use the approved ADR path.
3. Implement a bounded vertical slice with task-relevant available methods, meaningful failure/recovery behavior and deployment-target compatibility. Parallel writers have disjoint ownership.
4. Run relevant focused tests and affected native/runtime checks. QA owns distinct test work, localization owns assigned resources, and unavailable device/manual evidence remains NOT RUN.
5. Apply the delegation risk matrix to the actual diff. Required independent code/security/accessibility reviewers receive raw evidence and the tested revision. Author fixes findings; review the corrected revision.
6. Coordinator integrates evidence and affected docs, states material limits and stops at the approved feature. No automatic release, new capability or instrumentation.

Handoff: objective, candidate/data identity, artifacts and actual commands/results, unresolved
gates with owner and next action. NOT RUN/UNKNOWN never becomes PASS by omission.

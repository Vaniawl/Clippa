---
name: ios-quality
description: Use when asked to review native iOS accessibility, performance, memory, privacy and distribution readiness for changes that affect those areas.
---

# iOS quality review

Use the compact Apple product-engineering router for the affected native product work.
Load only the relevant section in [concerns.md](references/concerns.md):

- Accessibility/interaction: use that section and ui-ux-review's native runtime evidence
  procedure for changed UI. Independent accessibility review remains a separate gate.
- Performance/resource ownership: measure the reproducible scenario first; resource-safety
  applies when resource growth or lifetime is implicated.
- Security/privacy: inspect actual data flows, manifests and SDKs; use security-review for
  the affected boundary. No UI matrix is required for a privacy-only question.
- Distribution: use that section when preparing signing/release work, with the release role
  and separately authorized external actions.

Do not turn a small text change into a full release audit. A Simulator build proves neither
manual accessibility nor signing/archive/submission readiness. An uninspected empty privacy
manifest does not establish no data collection. Return concrete findings with evidence,
impact and correction; distinguish PASS, NOT RUN and NOT ASSESSED.

## Research when needed

Use applicable supplied/local primary sources or actually available web/docs tools permitted
by the active role and task. Callable tools do not expand authority, and role permissions
do not provision access. If the active role lacks the `web` tool or permission and local
evidence is insufficient, request a deep-researcher task via the orchestrator when available,
or mark the claim UNKNOWN and continue independent work. Do not guess current support,
simulate research or add a dependency to avoid verification.

---
name: ios-development
description: Use when asked to implement and review SwiftUI features, state ownership, module boundaries, and Swift concurrency in native iOS apps.
---


<!-- GENERATED from agent-framework/canonical/skills/ios-development/SKILL.md — edit the canonical source, then run: python3 scripts/agent-framework/render.py -->
# Native iOS development

Use the compact Apple product-engineering router for the affected native task. Read only
relevant sections: state/concurrency for behavior, native interaction for UI, verification
for affected checks. Keep existing targets/architecture; UI work uses the native ui-ux-review
reference. Framework-only tasks do not require this domain skill.

Read the approved product requirement; read relevant architecture/ADRs when the change touches structural boundaries or contracts. Resolve platform and toolchain constraints from the existing Xcode project, xcconfig files
and any package manifests. The starter uses an Xcode composition root plus a local Swift
package; an adopting application may use another established layout. Preserve that layout
and dependency direction unless an architecture change is explicitly in scope.

## Implementation decisions

- Keep the domain layer free of UI and concrete infrastructure; AppDomain is the starter
  example. Inject domain protocols at the existing app composition root. Add a module only when dependency direction or separate ownership
  needs enforcement; do not add an abstraction for every type.
- Give each observable model one clear owner. Use state for owned observable instances and
  bindings for editing externally owned values. Keep views focused on rendering and events;
  avoid I/O, task creation, and expensive transformations in body evaluation.
- Choose actor isolation deliberately at module boundaries. Do not suppress concurrency
  errors with unchecked Sendable or nonisolated(unsafe) without a documented invariant.
  Review actor reentrancy across each await and stale responses after user selection changes.
- Tie async work to an explicit lifetime. Propagate cancellation, cancel superseded loads,
  and prevent an older response from replacing newer state. A cancelled task must not show
  an error alert. Avoid detached tasks to hide isolation errors.
- Model loading, content, empty, failure, and retry when data is asynchronous. Preserve user
  input on recoverable errors; do not display raw server or internal diagnostic messages.
- Use NavigationStack or adaptive navigation according to product needs, with one owner of
  route state. Do not manufacture a coordinator/router before navigation requires it.
- Use system semantic presentation or the product's established tokens. Keep text localizable,
  interactive elements accessible, and layouts adaptable to larger text and iPad widths.
- Gate APIs above the deployment target and implement a usable fallback. Verify unfamiliar
  or version-sensitive behavior in official Apple/Swift documentation or installed SDK interfaces.

## Evidence

For changed behavior, add a focused test including the important failure/cancellation path.
Run repository validation and the relevant package/native checks. Record exact commands,
actual outputs, toolchain, and any unsupported environment. Use ios-testing for execution
and ios-quality when the change affects accessibility, performance, or privacy.

## Research when needed

Use applicable supplied/local primary sources or actually available web/docs tools permitted
by the active role and task. Callable tools do not expand authority, and role permissions
do not provision access. If the active role lacks the `web` tool or permission and local
evidence is insufficient, request a deep-researcher task via the orchestrator when available,
or mark the claim UNKNOWN and continue independent work. Do not guess current support,
simulate research or add a dependency to avoid verification.

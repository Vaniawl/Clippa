---
name: ios-development
description: Use when asked to implement and review SwiftUI features, state ownership, module boundaries, and Swift concurrency in native iOS apps.
---

# Native iOS development

Before implementing, designing, debugging, or reviewing an Apple feature, read
`agent-framework/canonical/policies/apple-product-engineering.md` from the repository root.
Apply its reconnaissance → product → interaction → visual → motion → implementation →
verification → polish workflow within the approved scope. Keep deployment targets and
existing architecture; resolve normal design details autonomously. UI work also uses the
native Apple procedure in `ui-ux-review`.

Read the product requirement and relevant ADR before changing code. Resolve platform and toolchain constraints from the existing Xcode project, xcconfig files
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

For version-sensitive Apple or Swift behavior, use official documentation or installed SDK
interfaces. If the active role lacks the `web` tool and local evidence is insufficient,
request a deep-researcher task via the orchestrator. Mark unresolved behavior UNKNOWN and
continue independent work; do not guess support or add a dependency to avoid verification.

# Native quality evidence

## Accessibility

Choose affected common tasks and actual device/settings. Inspect semantic controls, readable
labels/values, order/focus, contrast, largest supported Dynamic Type, Reduce Motion and meaningful
loading/error feedback. Test VoiceOver, Voice Control and Switch Control where relevant; do not
apply browser ARIA attributes to SwiftUI. XCTest accessibility audits can find problems but do
not replace manual task completion. Runtime captures alone do not prove assistive-technology use.
Record tested tasks/devices for Accessibility Nutrition Labels and check current Apple rules
before declarations. Significant interaction/semantics changes need independent review under
the delegation policy; routine edits retain focused applicable checks.

## Performance and reliability

Use supplied measurements or the ios-observability method when available for cold/warm launch,
hangs, termination, memory, energy and disk/network work. Compare equivalent workloads and
record device/build/sample. Source suspicion is not measured regression or improvement.

## Privacy and distribution

Use security-review's native reference for actual data flows, credentials, SDKs and manifests.
Match declarations to behavior; no-data-collection claims require inspected dependencies too.
Use a fresh candidate-specific release checklist and apple-signing-distribution when available
for signing/archive/store preparation. Missing account/device/CI access stays NOT RUN.

Sources and applicability: [source registry](../../../references/apple-source-registry.md).

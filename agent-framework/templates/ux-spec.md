# UX specification: <bounded flow>

Mode/status: <advise proposal / execute approved>. Requirement: <link>. Base revision: <revision>.
Audience/platform/targets: <user context, iOS/macOS and deployment targets>.

- Intent and primary action: <what the user achieves; dominant action>.
- Entry/exit and navigation: <routes, back/dismiss behavior, restoration and focus>.
- Information hierarchy: <content priorities; existing components and design-system references>.
- Visual direction: <audience/purpose, adopted style and rationale; supplied references or native precedents; reuse an existing direction where possible>.
- Screen composition: <realistic content, focal point, grouping, dominant action and useful whitespace; component/layout reference or sketch where needed>.
- Visual system: <type hierarchy, spacing rhythm, alignment, semantic color roles, surfaces, icons and required image/illustration assets>.
- Assumptions and reference interpretation: <routine choices made within the approved request; which visual properties are reused; material decisions still needed>.
- Design surface: <existing specification, composition sketch/SwiftUI previews, or selected available design tool; optional-tool fallback>.

| Applicable state | Trigger/data | Visible content and copy | Available actions | Transition/recovery | Acceptance evidence |
| --- | --- | --- | --- | --- | --- |
| Idle / loading / empty / content / error / offline / permission / cancelled | <select relevant states; explain omissions> | <realistic copy> | <prevent duplicate/unsafe actions> | <retry, preserve work, fallback> | <observable criterion> |

- Recovery discoverability: <status/action remain reachable at preserved deep scroll/selection, including largest text and narrow layouts; specify any persistent fallback>.
- Content fixtures: <real, long, empty, localized and edge-case content>.
- Accessibility: <labels, order, focus, contrast, VoiceOver, Dynamic Type for iOS; keyboard/menu/focus for Mac>.
- Appearance and adaptive layout: <light/dark, compact/large windows, orientation/size changes, overflow>.
- Motion: <purpose, interruption/cancellation, Reduce Motion alternative>.
- Product copy: <terminology, error explanation and concrete recovery>.
- Visual acceptance: <screen-specific, observable hierarchy, alignment, spacing, content density, asset/copy quality and native interaction criteria>.
- Implementation comparison: <matching runtime captures inspected against this specification; concrete findings, corrections and re-review evidence; unavailable review is NOT RUN>.
- Visual handover: <capture paths, tested revision, device/window, appearance and content state; criterion-by-criterion observations and open significant findings>.
- Verification matrix: <device/window, OS, locale, appearance, accessibility condition, expected behavior>.
- Risks and decisions: <unknowns and material tradeoffs>.

Implementation evidence records revision, build, destination and conditions. Manual/runtime checks not performed are NOT RUN. Specification approval is not runtime evidence.

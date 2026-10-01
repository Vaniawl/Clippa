# UX specification: <bounded flow>

Mode/status: <advise proposal / execute approved>. Requirement: <link>. Base revision: <revision>.
Audience/platform/targets: <user context, iOS/macOS and deployment targets>.

- Intent and primary action: <what the user achieves; dominant action>.
- Entry/exit and navigation: <routes, back/dismiss behavior, restoration and focus>.
- Information hierarchy: <content priorities; existing components and design-system references>.

| Applicable state | Trigger/data | Visible content and copy | Available actions | Transition/recovery | Acceptance evidence |
| --- | --- | --- | --- | --- | --- |
| Idle / loading / empty / content / error / offline / permission / cancelled | <select relevant states; explain omissions> | <realistic copy> | <prevent duplicate/unsafe actions> | <retry, preserve work, fallback> | <observable criterion> |

- Recovery discoverability: <status/action remain reachable at preserved deep scroll/selection, including largest text and narrow layouts; specify any persistent fallback>.
- Content fixtures: <real, long, empty, localized and edge-case content>.
- Accessibility: <labels, order, focus, contrast, VoiceOver, Dynamic Type for iOS; keyboard/menu/focus for Mac>.
- Appearance and adaptive layout: <light/dark, compact/large windows, orientation/size changes, overflow>.
- Motion: <purpose, interruption/cancellation, Reduce Motion alternative>.
- Product copy: <terminology, error explanation and concrete recovery>.
- Visual acceptance: <hierarchy, alignment, spacing, content clarity and native interaction criteria>.
- Verification matrix: <device/window, OS, locale, appearance, accessibility condition, expected behavior>.
- Risks and decisions: <unknowns and material tradeoffs>.

Implementation evidence records revision, build, destination and conditions. Manual/runtime checks not performed are NOT RUN. Specification approval is not runtime evidence.

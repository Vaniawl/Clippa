# Product Vision

## Purpose

Clippa makes clipboard reuse feel like a native extension of macOS: invoke one shortcut,
find the right item, paste it, and return to work. Privacy is a product behavior rather
than a policy promise—history stays local, sensitive sources can be excluded, capture can
be paused, and failures do not silently upload or discard data.

## Users

- A keyboard-first professional reusing snippets, links, screenshots, and files.
- A privacy-conscious user who wants useful history without an account or cloud database.
- A first-time user who needs clear Accessibility onboarding and a reliable fallback.
- An expert who expects filtering, search tokens, pinning, Quick Look, OCR, and drag/drop.

## Value

- Immediate retrieval through a global shortcut and keyboard navigation.
- Native macOS behavior with focused, low-friction UI.
- Local encrypted persistence and explicit privacy controls.
- A companion iPhone workflow that respects platform clipboard limitations.

## Success measures

- A user can install, grant access, open history, and paste without documentation.
- A shortcut conflict never makes history unreachable.
- A crash or failed write cannot corrupt the last committed history snapshot.
- Large image histories remain responsive within configured item and byte limits.
- Gatekeeper accepts public release artifacts.
- All shipped strings are localized in supported languages.

## Strategic non-goals

- No account system, advertising, analytics, or mandatory cloud service.
- No background clipboard behavior on iOS that the platform does not permit.
- No cross-device synchronization without a separately approved privacy design.
- No Electron/web runtime or server dependency for the core product.
- No silent destructive migration of clipboard history.

# Clippa macOS Design Proposal

## Product shape

Clippa should keep the current `Command-Shift-V` interaction as its fastest surface, while adding a full library window for browsing, organizing, and understanding synchronized history.

### Quick panel

- Target size: 620 × 420 pt, centered near the active cursor or text field.
- One search field at the top, with search tokens suggested as lightweight chips.
- A narrow filter rail for All, Pinned, Text, Links, Images, and Files.
- Dense clip rows with source, relative time, sync origin, and a single-line preview.
- The selected row exposes only the primary actions: Paste, Copy, Pin, and Preview.
- A quiet iCloud state appears in the footer and never competes with the paste action.

### Library window

- Three-column `NavigationSplitView`: collections, history, inspector.
- The sidebar owns global filters and a device section for This Mac and iPhone.
- The center column supports selection, search, sort, and multi-select deletion.
- The inspector shows the complete text, image, or link preview, metadata, pin control, and copy/paste actions.
- The toolbar contains search, Sync Now, Pause Capture, and Settings.

## Visual language

- Native macOS materials and vibrancy, with opaque content rows for reliable contrast.
- 12–14 pt corner radii, restrained shadows, and one blue accent reserved for selection and sync readiness.
- SF Symbols, system typography, and native control sizes.
- Content-first density: approximately seven clips visible in the quick panel without scrolling.
- Full keyboard operation and VoiceOver labels on every icon-only action.

## Sync behavior in the interface

- `checkmark.icloud.fill`: synchronized.
- `arrow.triangle.2.circlepath.icloud`: active transfer.
- `icloud.slash`: no iCloud account or missing entitlement.
- `exclamationmark.icloud`: retryable CloudKit failure.
- File references show “On this Mac” because local paths and bookmarks are intentionally excluded from cloud sync.
- Items above the 20 MB sync limit show “Local only” in the inspector.

## Recommended implementation order

1. Refine the current quick panel into the two-column rail + results layout.
2. Add the optional library window using the same row and preview components.
3. Add device/origin metadata once both clients have shipped with sync.
4. Add multi-select actions only in the library window; keep the quick panel single-selection and fast.

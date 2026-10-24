# Templates, quick paste and clipboard fixes

- Mode: execute; owner instruction in this Codex chat on 2026-10-24: fix the reported issues, add text templates and quick paste, promote a pasted item to first place.
- Base revision: 4d86475db3bf69135e5274a2f228a6d025905f44.
- Workflow: apple-feature-delivery; scope, design, build and verify apply.
- Owned: Clippa/Models, Clippa/Services/ClipboardStore.swift, Clippa/Services/PanelController.swift, Clippa/Storage/EncryptedHistoryStore.swift, Clippa/UI, Clippa/Resources/*/Localizable.strings, Clippa/ClippaApp.swift, ClippaTests/ClipboardCoreTests.swift, Clippa.xcodeproj/project.pbxproj, README.md, docs/adr and this task folder.
- Prohibited: agent framework, credentials, iOS sources, cloud sync PR, release/publication configuration.

## Acceptance criteria

1. Search retains normal caret/editing shortcuts, panel-only actions never intercept template windows, and the configured global shortcut survives restart.
The original request to launch Clippa also authorizes a discoverable Show Clipboard History menu action and normal app reopen behavior for this menu-bar utility.

2. All and kind filters include pinned clips; most recently copied/used clips sort first, including after encrypted reload.
3. Create, edit, group, search, delete/undo and reuse encrypted text templates; old history still loads and templates survive export/import. Custom variables are filled explicitly; date/time variables resolve locally; cancellation pastes nothing.
4. Command-1 through Command-9 paste the corresponding visible result, respect filters and safely ignore missing positions. Hints match actual ordering.
5. OCR, import/export and persistence failures present readable recovery feedback.
6. Affected Mac tests/build, actual native template/panel journeys and independent code/accessibility reviews carry evidence.

## Validation

xcodebuild -project Clippa.xcodeproj -scheme Clippa -destination 'platform=macOS' -derivedDataPath <workspace>/work/ClippaDerivedData test
python3 scripts/agent-framework/validate.py
python3 scripts/agent-framework/check-drift.py
git diff --check

Stop after this scope is implemented and checked. Multi-select, automatic OCR indexing and CloudKit sync are outside this request.

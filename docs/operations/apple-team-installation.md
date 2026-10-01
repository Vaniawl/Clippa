# Apple-team installation evidence

Date: 2026-10-01. Target: `Vaniawl/Clippa`.

- Product base revision: `4b65f7dd36b594fc298f4d6f0fb6526412209464`.
- Reviewed framework source: `Vaniawl/ios-starter` at `70e79b5c47b2e55c00b715c7d176a6b615875488`.
- Proven legacy source ancestors: `e25257e02b609e8abd5e164d1ae6c01fed5f0ff0`, `eac38651a507dfbec78a106eef1ed5c81fd8de20`.
- Installation: guarded `install-apple-team.py`; source payload hashes pinned in `.framework-payload.json`.
- Mode: `advise`; worker cap: three, lowered by host/project restrictions. Codex models/effort inherit user settings.

| Check | Result |
|---|---|
| Framework validation | PASS |
| Render and manifest drift | PASS |
| Read-only capability preflight | PASS, structural only |
| Identical reinstallation preview | PASS, zero changes |
| Existing native app files vs base (33 files) | PASS, byte-identical |
| Existing CI/workflows and product documents | Preserved; task-specific guide/memory additions recorded |
| Independent installer safety tests | 12 PASS |
| Native app builds/tests for this adoption | NOT RUN, native app source unchanged |
| Per-product live provider delegation | NOT RUN |
| Manual runtime UI/accessibility | NOT RUN |
| Hosted CI | Pending GitHub draft PR checks |

The full framework suite passed 228 tests with six skips at source `5c8b71bee7d642e9b3e04b551c053ba6861e04d8`.
Later installer-only changes passed their focused 12-test suite. Source-template
runtime evidence is distinct from this application's native execution evidence.

Previously absent build/test entrypoint scripts deliberately emit NOT RUN and
exit 2 until configured for this product. Their existence passes reference checks;
it does not establish app build/test success. Existing Xcode settings remain intact.

The retained template design-system examples and historical upstream reports are
reference material; they do not define this product's brand or prove its readiness.
Review the diff and [coordinator guide](apple-team.md). Rollback is an ordinary
revert of the adoption commit. No global configuration, app analytics, SDK,
subscription, backend, signing or publishing configuration is introduced.

# Evidence ledger — 2026-10-24

Environment: native macOS 26.6.2 arm64 (Mac mini); Xcode 27.1 (27A9275), macOS 27 SDK, app target macOS 26+. Base 4d86475db3bf69135e5274a2f228a6d025905f44; branch codex/templates-quick-paste. Tested/reviewed implementation: local commit 14672ab4102816b1cbba75fb5285a660c297a13c (subsequent changes are task documentation only).

| Claim | Actual command / observation | Result |
| --- | --- | --- |
| Native tests, including templates, all 9 mappings, native keyboard controls, shortcut reload, same-second encrypted ordering, legacy decode, burst saves and save failure | `xcodebuild -project Clippa.xcodeproj -scheme Clippa -destination 'platform=macOS' -derivedDataPath /tmp/clippa-codex-20261024 test` | PASS, 46/46, 0 failed/skipped. xcresult: /tmp/clippa-codex-20261024/Logs/Test/Test-Clippa-2026.10.24_15-35-49-+0200.xcresult. `xcresulttool get test-results summary` independently parsed into workspace work/clippa-test-summary.json. |
| Framework integrity | `python3 scripts/agent-framework/validate.py` | PASS: 0 errors, 0 warnings. |
| Generated configuration integrity | `python3 scripts/agent-framework/check-drift.py` | PASS: generated files match canonical sources/manifest. |
| Patch whitespace | `git diff --check` | PASS. |
| Actual native launch and editor accessibility tree | CUA launch built Debug app, reopen through Finder, New Template | Actual history panel contained quick-paste hints, Templates filter and New Template button. New Template window exposed persistent Name/Folder labels, Template text editor, Cancel and disabled Save for empty input. |
| Runtime interaction/visual limitations | CUA window changes during attempts to fill editor; two copies with same bundle ID were running | Full create-fill-paste journey, clipboard target restoration, appearance variants, VoiceOver, measured contrast and Reduce Motion: NOT RUN to completion. No screenshot-only or source-only accessibility certification claimed. |
| Independent code/accessibility source review | Independent reviewer under canonical code-reviewer/accessibility-reviewer contracts | Reported stale persistence, lost subsecond order, native-control interception and labels/preview; corrected source re-reviewed with no remaining Blocking/Important findings. Reviewer independently read successful raw test log. Runtime accessibility remains open. |

Initial failed checks are preserved in workspace logs/history: first Documents-derived build failed code signing due iCloud FinderInfo; moving build artifacts to /tmp followed the existing release script's convention. First encrypted reload regression failed because canceled old writes could overwrite a flush; serialized save/flush fixed it. The final 46-test run passed after all product source changes.

Local Release packaging: `SKIP_TEST=1 OUTPUT_DIR=<workspace>/outputs ./scripts/release.sh` completed with BUILD SUCCEEDED, Package, Verify and `Built .../outputs/Clippa.app.zip (2786261 bytes)`. The script unzipped to a fresh /tmp folder and ran `codesign --verify --deep --strict`. Bundle app.clippa.Clippa, local candidate version 1.0.13 (13), existing hardened Release settings retained. No smoke launch, notarization, external publication or merge.

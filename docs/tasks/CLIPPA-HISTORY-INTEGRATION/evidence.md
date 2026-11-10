# Evidence

Product code tested and independently source-reviewed at `f21580e`. The temporary visual fixture only populated the actual SwiftUI panel with synthetic data and was removed after rendering.

| Criterion | Command or observation | Result |
| --- | --- | --- |
| macOS build and tests | `xcodebuild -project Clippa.xcodeproj -scheme Clippa -destination 'platform=macOS,arch=arm64' -configuration Debug build-for-testing`, then `xcodebuild -xctestrun <isolated test plan> -destination 'platform=macOS,arch=arm64' test-without-building` | 50 functional tests and one temporary render test passed |
| Scroll appearance | Cached native SwiftUI hosting view in light and dark with synthetic entries, at the top and while scrolled | First row stays clear at the top; clipped history softens at both ends while scrolled |
| Source review | Independent code and accessibility reviews on `f21580e` | Approved after resolving startup, focus, scrollbar and localization findings |
| Repository hygiene | `git diff --check origin/main f21580e`, `plutil -lint` for both string tables, `python3 scripts/agent-framework/validate.py`, and `python3 scripts/agent-framework/check-drift.py` | Passed |
| VoiceOver and full desktop traversal | Manual system settings and physical keyboard | Not run |

# Contributing to Clippa

Clippa welcomes focused bug fixes and improvements that preserve its native,
local-first design.

## Development setup

You need macOS 26 or newer and Xcode 26.6 or newer.

```bash
git clone https://github.com/Vaniawl/Clippa.git
cd Clippa
xcodebuild -project Clippa.xcodeproj -scheme Clippa -destination 'platform=macOS' test
```

Open `Clippa.xcodeproj` in Xcode for development. A local build may request
Accessibility permission when you test automatic paste.

## Before opening a pull request

1. Keep the change focused and consistent with the existing SwiftUI patterns.
2. Add or update tests for changed behavior.
3. Run the full test command above.
4. Update English and Ukrainian strings for new user-facing text.
5. Do not include clipboard history, credentials, signing identities, or other
   machine-specific data.

Use the pull request template to describe the user impact and validation.

# Build and delivery evidence

- Resolve actual project/workspace, schemes, configurations, bundle IDs, capabilities and SDK
  submission requirements. A required SDK upgrade does not automatically raise the minimum OS.
- Use pinned/recorded toolchain and dependency resolution. Validate package/unit tests separately
  from Simulator/native builds and device archives. Capture revision plus dirty-diff identity.
- Document automatic/manual signing, entitlements, provisioning/profile match and secure access to
  certificates/API keys. Check expiry/rotation and runner keychain lifecycle without exposing values.
- Archive/export for the intended route with the project's scripts; record exit status and archive
  identifier. Validate app/extension entitlements, resources, privacy manifests and dSYM association.
  Signing/archive evidence requires real access; Simulator compilation cannot substitute.
- CI may use existing Xcode Cloud, GitHub Actions or fastlane; none is mandatory. Minimize permissions
  and untrusted-PR secret exposure. Do not add a service or dependency without approved need.
- Start a fresh [release checklist](../../../../templates/release-checklist.md). Confirm TestFlight,
  review metadata, declarations and candidate identity with the release manager. Account/legal/finance
  decisions remain with the human owner.
- Define supported containment/recovery and monitoring. A phased-release pause affects automatic
  rollout; it does not roll installed clients back. Emergency fixes need a corrected version.

Sources: [Xcode Cloud](https://developer.apple.com/documentation/xcode/xcode-cloud),
[App Store submission](https://developer.apple.com/app-store/submitting/),
[TestFlight](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview/),
[App Store Connect API](https://developer.apple.com/documentation/appstoreconnectapi),
[secure GitHub Actions](https://docs.github.com/en/actions/reference/security/secure-use),
[optional fastlane](https://docs.fastlane.tools/getting-started/ios/setup/).
Applicability: [source registry](../../../references/apple-source-registry.md).

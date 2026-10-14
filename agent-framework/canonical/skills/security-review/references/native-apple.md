# Native Apple security and privacy

- Map sensitive data from entry to storage, logs, network, backups, extensions and third-party
  SDKs. Inspect entitlements, permission descriptions and actual accesses; declarations alone
  do not implement controls. Scope applicable MASVS categories and concrete MASTG checks.
- Inspect Keychain accessibility/access groups and Data Protection for the data/lifecycle need.
  Check sign-out/account change, device lock and biometric denial/fallback. Biometrics establish
  a local interaction condition, not server authorization or guaranteed identity semantics.
- Verify transport policy and trust behavior, token storage/expiry/refresh, OAuth/callback handling,
  universal/custom links, imported files and notification payload validation. Do not add certificate
  pinning automatically; assess actual threat and certificate rotation/recovery constraints.
- Ensure sensitive data is absent from logs, crash attachments, clipboard, screenshots/previews
  and caches where the product requires protection. Test unauthorized/error paths and shared-state
  boundaries. Client restrictions cannot protect server objects without server-side checks.
- Inventory embedded SDKs and inspect actual collection, required-reason API use and manifests.
  Reconcile App Privacy details, purpose strings, consent and third-party requirements with real
  data flows. ATT applicability follows actual tracking; not every measurement operation is tracking.
- Record inspected code/config and test evidence; mark unsupported device/attack checks NOT RUN.
  Report specific risk and correction without issuing blanket security/compliance claims.

Sources: [MASVS](https://mas.owasp.org/MASVS/), [MASTG](https://mas.owasp.org/MASTG/),
[Keychain](https://developer.apple.com/documentation/security/keychain-services),
[App Privacy](https://developer.apple.com/app-store/app-privacy-details/),
[SDK requirements](https://developer.apple.com/support/third-party-SDK-requirements/).
Applicability: [source registry](../../../references/apple-source-registry.md).

# Deep links and extensions

- Universal links require actual associated-domain configuration and hosted association evidence;
  custom schemes need validation and collision/security considerations. Parse routes as untrusted
  input and preserve auth/authorization checks before displaying or mutating protected data.
- Specify cold/warm launch, invalid/expired links, sign-in continuation and navigation ownership.
  Do not turn a URL into arbitrary file/network execution. Test fallback when association fails.
- Extensions run in a separate process/lifecycle with framework-specific limits. Share only the
  necessary state through approved App Groups/keychain access groups; verify entitlement match and
  process-safe storage rather than assuming an in-memory singleton is shared.
- Test interrupted/failed extension work and main-app compatibility. Keep extension-specific APIs
  and minimum versions distinct; actual device/service setup is required for runtime claims.

Sources: [associated domains](https://developer.apple.com/documentation/xcode/supporting-associated-domains),
[app extensions](https://developer.apple.com/app-extensions/).
Applicability: [source registry](../../../references/apple-source-registry.md).

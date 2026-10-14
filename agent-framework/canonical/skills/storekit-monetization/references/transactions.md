# Transactions and entitlement evidence

- Confirm the actual product type, region/storefront, offer eligibility and current Apple policy.
  Keep StoreKit client identifiers separate from server secrets. Check API availability.
- Establish one owner for purchase state and a lifecycle-bound transaction-update listener. Handle
  verified/unverified transactions, cancellation, pending approval, interrupted delivery and retry.
  Grant durable entitlement only from the approved verified rule; finish transactions after the
  required delivery/processing succeeds. Make repeated updates idempotent.
- Reconcile current entitlements at launch/resume where needed, including expiry, revocation,
  refunds, billing retry/grace and account changes. Provide an appropriate user-initiated restore
  path; do not continuously prompt account authentication on launch.
- If a server exists, specify signed-payload verification, environment separation, authenticated
  ownership mapping, duplicate/out-of-order notifications and reconciliation. Never trust a client
  flag as server authorization or invent server validation for an app without that architecture.
- Test success, user cancellation, pending, verification failure, restore/reinstall, duplicate
  updates, expiry/refund and offline behavior. Distinguish local StoreKit configuration, sandbox,
  TestFlight and production evidence. Never purchase or change live pricing without authorization.

Sources: [StoreKit](https://developer.apple.com/documentation/storekit),
[testing environments](https://developer.apple.com/documentation/storekit/testing-at-all-stages-of-development-with-xcode-and-the-sandbox),
[Server API](https://developer.apple.com/documentation/appstoreserverapi),
[server notifications](https://developer.apple.com/documentation/appstoreservernotifications).
Applicability: [source registry](../../../references/apple-source-registry.md).

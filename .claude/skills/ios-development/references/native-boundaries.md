# Native boundary decisions

## Lifecycle and navigation

Identify app/scene/view lifetimes and one owner for routes and asynchronous state. Handle
cold launch, foreground/resume, multiple scenes where supported, interrupted requests and
deep-link continuation through authentication. Navigation inputs are untrusted data. Preserve
selected state/input on recoverable failures; reject superseded results explicitly.

Use UIKit bridging only where the product or platform requires it. Define coordinator/delegate
ownership, teardown and state synchronization; avoid repeated creation or I/O during view
updates. Keep OS availability/fallback separate from the SDK used to compile.

## Concurrency

Inspect actual compiler language mode/default isolation and package/target settings before
choosing annotations. Identify actor ownership, await reentrancy and Sendable boundaries.
Test cancellation before/after suspension, replacement requests and noncooperative dependencies.
Do not use detached tasks or unchecked Sendable as a blanket compiler workaround. Separate UI
isolation from expensive work without assuming every async function runs off the main actor.

## Networking and authentication

Keep transport/credential handling behind the existing approved boundary. Define HTTP errors,
timeouts, retry/idempotency, offline behavior and token expiry/refresh with one refresh owner.
Validate response shape and incoming URLs; redact diagnostics. Credentials belong in appropriate
secure storage, not UserDefaults or app logs. Client UI state never replaces server authorization.
Test malformed/unauthorized responses and concurrent refresh/cancellation. Introduce a dependency
or a server only through the product's approved architecture decision.

Sources and version applicability: [source registry](../../../../agent-framework/canonical/references/apple-source-registry.md).

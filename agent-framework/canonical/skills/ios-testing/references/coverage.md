# Native test coverage

- Use Swift Testing for suitable new unit tests and parameterized pure behavior. Retain XCTest
  for UI/performance and existing suites; both can coexist, but do not mix their APIs inside a
  single test. Select actual package/test targets and supported SDK interfaces.
- Async tests synchronize on state/events rather than arbitrary sleeps. Inject clock/transport
  only when behavior needs control; test cancellation, stale response suppression, duplicate
  delivery, timeout, malformed data and a meaningful recovery path where affected.
- UI tests use stable identifiers and semantic assertions for the result of a user action, not
  only element existence. Reset state through approved fixtures; do not delete shared data.
  Include permission denial/revocation, offline, interruptions and cold launch where relevant.
- Persistence/release changes test fresh install and upgrades from every supported prior model
  with realistic synthetic data. Commerce tests identify local configuration versus sandbox.
- Use test plans for appropriate configurations/locales/devices without requiring the full matrix
  for every edit. Record actual simulator/device/OS, candidate revision and result bundle.
- On a flaky failure preserve the first evidence, inspect order/state/parallelism and make a new
  hypothesis. Reruns do not erase the original failure; quarantine requires owner/reason/follow-up.
  Serialize native builds in a checkout or isolate derived data and simulator state.
- A framework fixture, host unit pass, native build, UI assertion, visual capture and manual
  assistive-technology run prove different things. Unexecuted levels remain NOT RUN.

Sources: [Swift Testing](https://developer.apple.com/documentation/testing),
[XCTest](https://developer.apple.com/documentation/xctest).
Applicability: [source registry](../../../references/apple-source-registry.md).

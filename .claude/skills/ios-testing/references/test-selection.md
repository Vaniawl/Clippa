# Select affected tests

## Select the right test

- Put pure domain/model behavior in the existing unit-test target or package test directory
  (Modules/Tests in the starter), with injected deterministic fakes.
  Cover cancellation, retry, stale response ordering, and failure recovery where they matter.
  Avoid arbitrary sleeps; use controllable async dependencies or expectations.
- Use the existing app test target (AppTests in the starter) for composition and app-only
  integration. Use its UI-test target (AppUITests in the starter) for user journeys
  and recovery with stable accessibility identifiers. An existence assertion alone does not
  prove an action succeeded: assert the resulting state.
- Keep fake launch scenarios deterministic. Do not let test credentials or live service
  access become requirements for a clean template checkout.
- For UI changes, exercise a compact iPhone and a larger layout, accessibility text size,
  and affected light/dark states. Capture before/after proof of the actual changed screen.


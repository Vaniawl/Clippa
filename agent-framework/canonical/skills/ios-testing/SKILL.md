---
name: ios-testing
description: Use when asked to build, run, and test native iOS apps with Swift package tests, XCTest and Simulator; diagnose failures and record reproducible evidence.
---

# iOS testing and Simulator evidence

For Apple feature verification, read the definition of done and final self-review in
`agent-framework/canonical/policies/apple-product-engineering.md` from the repository root.
Cover applicable behavior, visual, interaction, motion, and accessibility states. Record
what actually ran; a build or static screenshot alone does not certify all those criteria.

Use the repository's build/test scripts first after reading their behavior. Tools supplied by
an optional Xcode plugin may help, but the template must remain usable with Xcode CLI alone.

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

## Execution

Read existing build scripts and resource-limit helpers; the starter uses
scripts/lib/resource-limits.sh. Keep build concurrency and output bounded, and avoid
unbounded background commands when an adopter has no helper. Check xcodebuild -version,
the real shared scheme and simulator availability. Use the existing simulator resolver
(scripts/resolve-ios-simulator.sh in the starter), or inspect available destinations. Do not invent device UUIDs, destinations,
platform support, or success when the simulator service is unavailable.

Use the repository's actual build and test commands; scripts/build.sh and scripts/test.sh
are the starter defaults. Run package or bootstrap suites only when the adopting project
actually has those components. During iteration use a focused equivalent command;
state clearly which layers it covers. Keep derived data and result bundles in ignored/local
locations. Do not erase simulators or terminate unrelated processes to repair an environment.

## Failure investigation and output

Distinguish compile errors, product failures, test failures, and infrastructure failures.
Capture the failing command and its output before changing code. Re-run only affected checks
when a change or an unresolved failure justifies it. Never report repeated retries as stability.

Return commands, exit codes, test counts, simulator/OS and Xcode version, evidence location,
and NOT RUN checks with reason. A host macOS Swift package test does not prove an iOS app
build or Simulator interaction. Screenshots do not replace behavioral assertions.

## Research when needed

For version-sensitive Apple or Swift behavior, use official documentation or installed SDK
interfaces. If the active role lacks the `web` tool and local evidence is insufficient,
request a deep-researcher task via the orchestrator. Mark unresolved behavior UNKNOWN and
continue independent work; do not guess support or add a dependency to avoid verification.

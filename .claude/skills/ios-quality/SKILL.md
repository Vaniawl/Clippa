---
name: ios-quality
description: Use when asked to review native iOS accessibility, performance, memory, privacy and distribution readiness for changes that affect those areas.
---


<!-- GENERATED from agent-framework/canonical/skills/ios-quality/SKILL.md — edit the canonical source, then run: python3 scripts/agent-framework/render.py -->
# iOS quality review

Read `agent-framework/canonical/policies/apple-product-engineering.md` from the repository
root for the Apple product-quality bar. Use its visual, interaction, motion, accessibility,
platform, and final self-review criteria for affected surfaces, together with the native
Apple procedure in `ui-ux-review`. Judge usable product behavior, not compilation alone.

Inspect only areas affected by the requested change. Use separate reviewers where an
independent gate is required; do not turn a small text change into a full release audit.

## Accessibility and interaction

Check VoiceOver labels, traits, order and focus after navigation, sheets and errors. Prefer
native controls; avoid announcing every render. Exercise Dynamic Type at accessibility sizes,
contrast in supported appearances, Reduce Motion and alternatives to color-only meaning.
Verify tappable areas, keyboard avoidance, safe areas, and compact/iPad layouts. Record device,
OS, text size and appearance alongside screenshots; disclose manual checks not performed.

## Performance and resource ownership

Measure a reproducible symptom before optimizing. Inspect expensive work in SwiftUI body,
unstable list identity, observation invalidation scope, oversized images and unbounded caches.
Trace task, timer, observer and subscription lifetime. Profile latency with Instruments or
available equivalent tooling, and memory with allocations/leaks or a memgraph when needed.
Compare the same scenario before and after; never infer a leak solely from one high RSS value.
Run build/profiling work under repository resource bounds and keep captured output bounded.

## Security and privacy

Review actual collected data, purpose strings, entitlements, network transport, storage and
logs. Keep secrets out of UserDefaults and source; use appropriate protected storage for
credentials when credentials are an approved feature. A privacy manifest must describe the
implemented app and its SDKs; the starter's empty manifest is not blanket compliance.
Use security-review for trust boundaries, remote input, authentication and persistence.

## Distribution

Use the devops-release-engineer for signing, archives and delivery tooling. Confirm bundle ID,
version/build, icons, supported devices, Release build and the relevant privacy declarations.
Check current Apple submission requirements against official sources when preparing delivery.
TestFlight/App Store upload or publication requires user authorization for that action; a
request to review readiness alone is not upload permission. Do not invent signing identities.

## Verdict

Return concrete findings by severity with file/evidence, impact and required fix. Distinguish
PASS from NOT RUN and NOT ASSESSED. A Simulator build does not prove device signing, archive,
App Store validation, accessibility on device, or production network behavior.

## Research when needed

For version-sensitive Apple or Swift behavior, use official documentation or installed SDK
interfaces. If the active role lacks the `web` tool and local evidence is insufficient,
request a deep-researcher task via the orchestrator. Mark unresolved behavior UNKNOWN and
continue independent work; do not guess support or add a dependency to avoid verification.

---
name: ios-testing
description: Use when asked to build, run, and test native iOS apps with Swift package tests, XCTest and Simulator; diagnose failures and record reproducible evidence.
---


<!-- GENERATED from agent-framework/canonical/skills/ios-testing/SKILL.md — edit the canonical source, then run: python3 scripts/agent-framework/render.py -->
# iOS testing and Simulator evidence

Use the compact Apple product-engineering router for affected native feature verification.
Read test strategy when selecting or changing test coverage, not for unrelated framework work.

- Pure domain/model behavior: read [test-selection.md](references/test-selection.md) for
  relevant boundary/failure-path tests; run the actual package/unit command. Host tests
  do not require Simulator discovery and cannot establish an app build or UI behavior.
- App integration, native builds or UI journeys: additionally read
  [native-execution.md](references/native-execution.md). Inspect scripts before invoking
  them, resolve real schemes/destinations, serialize native work or use isolated scratch
  directories, and preserve repository resource/output bounds.
- Changed UI: use ui-ux-review's native evidence procedure for representative affected
  states. Do not require a complete unrelated visual matrix for pure logic or tooling.

## Failure investigation and output

Distinguish compile errors, product failures, test failures, and infrastructure failures.
Capture the failing command and its output before changing code. Re-run only affected checks
when a change or an unresolved failure justifies it. Never report repeated retries as stability.

Return commands, exit codes, test counts, simulator/OS and Xcode version, evidence location,
and NOT RUN checks with reason. A host macOS Swift package test does not prove an iOS app
build or Simulator interaction. Screenshots do not replace behavioral assertions.

## Research when needed

Use applicable supplied/local primary sources or actually available web/docs tools permitted
by the active role and task. Callable tools do not expand authority, and role permissions
do not provision access. If the active role lacks the `web` tool or permission and local
evidence is insufficient, request a deep-researcher task via the orchestrator when available,
or mark the claim UNKNOWN and continue independent work. Do not guess current support,
simulate research or add a dependency to avoid verification.

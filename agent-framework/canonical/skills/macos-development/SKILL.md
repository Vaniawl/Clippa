---
name: macos-development
description: Use when implementing, testing, or reviewing a native macOS or Mac Catalyst app; resolve the actual platform and preserve desktop interaction, lifecycle, sandbox, and signing boundaries.
---

# macOS and Mac Catalyst development

Use the compact Apple product-engineering router and only task-relevant sections. For
changed desktop UI select pointer, keyboard/focus, navigation, resizing and window ownership;
for model-only work select state/concurrency. UI verification uses ui-ux-review's native
reference; a stretched iPad layout does not establish native desktop interaction.

Read the existing Xcode targets, shared schemes, build settings and product requirements.
Distinguish a native macOS app from a Mac Catalyst build and from an iPad app merely allowed
on Apple silicon Macs. Selecting this skill does not create a macOS target or promise Mac
support. Add platform support only when the task actually includes that product change.

## Implementation and interaction

- Preserve the project's architecture. Share domain logic where its dependencies permit;
  keep AppKit/UIKit integration at the relevant platform boundary. Inspect the installed
  SDK before choosing availability or targetEnvironment conditions; Catalyst is not a
  substitute for native AppKit compilation.
- Bind state and tasks to the appropriate app, scene, window or document lifetime. Check
  multiple-window ownership, activation/deactivation and closing a window during async work.
  Avoid singleton UI state that mixes independent documents or windows.
- Use the existing desktop navigation, menu commands, shortcuts, focus and selection rules.
  Exercise keyboard-only operation, window resizing, toolbar actions, sheets and VoiceOver.
  Do not assume touch gestures or iPhone geometry cover the Mac interaction contract.
- For file access, inspect the actual sandbox entitlements and user-selected file flow.
  Balance security-scoped access where required, handle denied or stale access, and avoid
  retaining access beyond its owner. Do not add broad entitlements to conceal a failure.
- Treat app groups, keychain, clipboard, capture permissions, extensions and background work
  as separate boundaries with platform-specific evidence. Do not copy iOS signing or privacy
  settings into a Mac target and assume they describe its behavior.

## Build and validation

Use the adopting project's scripts and resource bounds first. Inspect xcodebuild -list and
-showdestinations for the actual project and scheme. Choose the listed native macOS or Mac
Catalyst destination; do not invent a scheme, architecture or deployment minimum. If the
project has no suitable Mac destination, report that limitation before claiming a Mac build.

Run focused domain tests, then the affected native target and relevant desktop journeys.
Record platform, architecture, toolchain, command and actual result. An iOS Simulator build
or a host Swift package test does not prove a Mac app build, desktop UI, entitlements, or
sandbox behavior. Keep outputs bounded and record unavailable native services as NOT RUN.

Signing, archive creation, notarization and distribution use the devops-release-engineer.
A request for Mac development does not authorize publication, credential changes, removing
sandbox restrictions, or disabling hardened runtime. Verify distribution requirements using
current official documentation only when that delivery work is requested.

## Research when needed

Use applicable supplied/local primary sources or actually available web/docs tools permitted
by the active role and task. Callable tools do not expand authority, and role permissions
do not provision access. If the active role lacks the `web` tool or permission and local
evidence is insufficient, request a deep-researcher task via the orchestrator when available,
or mark the claim UNKNOWN and continue independent work. Do not guess current support,
simulate research or add a dependency to avoid verification.

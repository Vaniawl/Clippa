# Clippa

## Purpose

Clippa is a keyboard-first, local-only clipboard history application for macOS with an
explicit iPhone companion. It captures supported clipboard content, lets people find and
reuse it quickly, and keeps history private on the device.

## Status

Production. The current public release is 1.0.13. The repository contains the macOS app,
the iPhone companion, their tests, the npm installer, the static product website, and the
release packaging workflow.

## Users

- People who repeatedly reuse text, links, images, and file references on a Mac.
- Keyboard-focused users who expect the clipboard panel to appear without interrupting
  the active application.
- Privacy-conscious users who do not want clipboard contents uploaded to a service.
- iPhone users who accept iOS clipboard restrictions and want an explicit local history.

## Scope

The approved product boundary is documented in `docs/product/pov-scope.md`. The current
hardening milestone is tracked in `BACKLOG.md`.

## Stack

- Swift 6, SwiftUI, Observation, AppKit, CryptoKit, Vision, and Security.
- macOS 26+ for the menu-bar application.
- iOS 17+ for the companion application.
- Xcode 26.6+ and `xcodebuild` for builds and tests.
- Node.js for the npm installer.
- GitHub Actions for CI and release-package verification.

## Owner

Vaniawl and Clippa contributors.

## Constraints

- Clipboard content remains local and is never used for analytics.
- Accessibility access is used only for focus restoration and synthetic paste.
- Existing encrypted history must migrate without silent loss.
- A failed save, import, migration, or release gate must be visible and recoverable.
- The application remains native and avoids runtime dependencies.

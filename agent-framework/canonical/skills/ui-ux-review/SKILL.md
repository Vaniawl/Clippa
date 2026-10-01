---
name: ui-ux-review
description: Review user interfaces for accessibility (keyboard, contrast, focus), responsive behavior, error/loading/empty states, first-time-user clarity, expert efficiency, and design-token conformance, with visual regression evidence. Use when a change adds or modifies any user-facing UI, screen, component, or flow, or before shipping UI to users.
---

# UI/UX Review

## Purpose

Verify that a UI change is usable, accessible, consistent with the design system, and evidenced by screenshots — not just "looks fine on my machine". Findings are reported as Blocking / Important / Optional. This skill is the review *procedure*; it does not by itself satisfy the independent-gate requirement — the accessibility-reviewer role is the independent check that runs or verifies this procedure per the autonomy-policy continuation ladder (step 4), and a builder self-running this checklist on its own change does not substitute for that independent review.

## When to use

- A diff adds or modifies screens, components, styles, or user-facing copy.
- Before a release gate that includes user-facing UI.
- When a UI is reported as confusing, inaccessible, or visually broken.

## When not to use

- Pure backend/API changes with no rendered surface.
- Deep visual design exploration or rebranding — that is design work, not review.

## Select only the applicable procedure

- Native Apple UI: use the compact Apple product-engineering router, then read
  [native-apple.md](references/native-apple.md) for the affected journey and evidence.
  Browser/CSS/skip-link breakpoints do not apply to native screens.
- Web UI or adopted extracted-brand token governance: read
  [web-branded.md](references/web-branded.md). Native branded UI uses that token
  governance and the native interaction procedure. Mixed surfaces get the applicable
  procedure for each rendered surface, not both full checklists by default.
- SwiftUI source review: use installed swiftui-pro when available; it remains optional
  and does not replace runtime evidence or the independent accessibility gate.

## Evidence and verdict

Follow the evidence policy. Keep before/after screenshot pairs for representative affected
sizes/states, or explicitly report the missing baseline/capture as NOT RUN. Inspect the
images; runtime observations/assertions support interaction and motion claims. Contrast
claims include the measuring tool and ratios. Record actual revision, environment, steps
and evidence paths; mark inapplicable checks N/A with reason and unavailable checks NOT RUN.

Return inspected surfaces, evidence, unassessed areas and concrete Blocking / Important /
Optional findings with impact and required correction, then pass / pass after Blocking
fixes / fail. A self-check does not substitute for a required independent review.

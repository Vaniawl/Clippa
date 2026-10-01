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

## Choose the platform procedure

For native iOS, iPadOS, macOS, Mac Catalyst, or SwiftUI surfaces, read
`agent-framework/canonical/policies/apple-product-engineering.md` from the repository root
and use the **Native Apple procedure** below instead of the web/branded procedure and
checklist. Browser viewport, CSS, skip-link, forced-colors, and fixed web-breakpoint checks
do not apply to a native screen. For mixed apps, review each rendered surface with its
applicable procedure; a WebView does not exempt its web content from browser checks.

## Native Apple procedure

1. **Product and repository fit.** Identify the user's goal, primary/secondary actions,
   entry point, destination, affected states, and existing navigation/components. Check
   that the change solves the approved requirement without invented features, duplicate
   architecture, or unrelated restyling.
2. **Design-system fit.** Use the product's adopted components and tokens or native semantic
   controls, typography, colors, materials, and layout defaults. Framework example-brand
   tokens are not an unbranded app's design system. A missing recurring custom scale may
   be established coherently inside approved work, as master-prompt section 5 permits.
   Adopted proposed-derived brand tokens still require documented brand-owner approval.
3. **Visual composition.** Review hierarchy, grouping, alignment, spacing rhythm, readable
   secondary content, primary-action emphasis, icons, control/hit-area sizes, and nested
   surfaces. Remove arbitrary borders, cards, radii, shadows, gradients, and empty regions.
   Inspect light/dark appearance and relevant contrast settings with actual content.
4. **Adaptive layout.** Use the app's actual minimum and typical device/window sizes.
   Exercise compact and larger iPhone layouts, supported landscape and keyboard-visible
   states; iPad split/resizable windows and pointer/keyboard where supported; native Mac
   minimum/typical/wide windows, sidebar states, and toolbar changes. Check long localized
   content and accessibility Dynamic Type where supported. Record sizes, do not assume web
   breakpoints or add platform targets just to review them.
5. **Interaction and focus.** Exercise applicable idle, pressed, hover, focused, selected,
   disabled, loading, editing, expanded/collapsed, drag/drop, and destructive states.
   Controls acknowledge input immediately without exaggerated motion or hover layout jumps.
   Primary functionality remains discoverable without hover or context menus. Verify
   keyboard-only journeys, selection, Return/Escape, conventional shortcuts, and focus
   restoration on desktop and keyboard-enabled iPad workflows.
6. **Navigation and continuity.** Check hierarchy versus peer destinations, sheets, popovers,
   inspectors, and windows. Preserve expected selection, input, search/filter state, and
   scroll position across detail navigation, insertion/removal, retries, and dismissal.
   Verify safe areas, gesture ergonomics, and platform-appropriate presentation.
7. **Motion.** Identify what each animation communicates. Exercise transitions and repeated
   input for responsiveness, interruption, spatial continuity, distracting bounce, and
   rendering stability. Test Reduce Motion with the setting enabled and preserve useful
   feedback. Use haptics only for meaningful supported interactions. Static screenshots
   cannot certify animation quality; record runtime observation or capture evidence.
8. **Accessibility.** Exercise VoiceOver names, values, reading order, grouping, focus, and
   decorative exclusions; keyboard access, large text, contrast, Reduce Transparency, and
   color-independent meaning where relevant. Native controls may provide labels and press/
   focus behavior without custom wrappers. Record actual checks and measured contrast for
   uncertain/custom combinations; do not infer accessibility from a build alone.
9. **State and recovery.** Verify applicable normal/loading/empty/error/success/disabled
   states, duplicate-action prevention, cancellation, retry, preserved input, useful copy,
   and recoverable destructive actions. Loading remains stable and proportionate to the
   operation; obvious resulting success does not need another modal. Do not invent missing
   operations, artificial delays, or irrelevant states for checklist coverage.
10. **Engineering and performance.** Review state ownership, actor isolation, task lifetime,
    stable IDs, image sizing/loading, body work, and scrolling. Reuse motion helpers and
    styling only where useful. Confirm API availability against actual targets, build the
    changed target, run meaningful affected tests, and resolve avoidable new warnings.
11. **Visual evidence and final polish.** Capture before/after views at the same representative
    supported sizes and states; inspect differences for unintended shifts, clipping, or
    truncation. Run master-prompt sections 49–51 and 74 before handover. Keep evidence
    proportional to affected surfaces and report every unavailable runtime/visual check
    as NOT RUN with its reason. A self-review does not replace a required independent gate.

### Native Apple verification checklist

- [ ] Approved user goal, hierarchy, navigation, and repository/component reuse checked
- [ ] Adopted product design system or native system semantics respected
- [ ] Spacing, alignment, type, icons, surfaces, and primary-action emphasis reviewed
- [ ] Relevant light/dark and contrast settings, long content, adaptive sizes checked
- [ ] Touch, press, hover, keyboard, focus, selection, and disabled states exercised as applicable
- [ ] Navigation, scroll, search/filter, selection, and input continuity verified
- [ ] Motion purpose, interruption, repetition, Reduce Motion, and applicable haptics reviewed
- [ ] VoiceOver, Dynamic Type where supported, Reduce Transparency, contrast, and hit areas checked
- [ ] Applicable loading/empty/error/success/retry/cancellation and destructive recovery exercised
- [ ] Affected builds/tests run; API availability and new warnings reviewed
- [ ] Before/after visual evidence inspected; runtime evidence supports interaction/motion claims
- [ ] Final self-review complete; missing checks NOT RUN, inapplicable checks N/A with reasons

## Web/branded procedure

The following token governance, procedure, and checklist apply to web surfaces and products
that have adopted the extracted framework brand. Native branded surfaces keep their adopted
token governance but use the native interaction/accessibility procedure above.

### Design tokens — hard rule for adopted extracted brands

All colors, spacing, typography, radii, and elevation values MUST come from the extracted design tokens in `agent-framework/design-system/tokens/`. NEVER invent colors, spacing values, font sizes, or one-off hex codes — a value not in the token set is a finding (Blocking if it breaks visual consistency on a shipped surface, Important otherwise). If a needed token does not exist, file a token request as a `Candidate` per the scope-control policy; do not improvise a value.

**Extracted vs proposed-derived governance:** only tokens carrying `$status: extracted` (currently `tokens/light.json`, `tokens/base.json`) are authoritative for shipping product. Tokens carrying `$status: proposed-derived` (currently `tokens/dark.json`, `tokens/high-contrast.json`) are brand-owner proposals, not certified values — they REQUIRE documented brand-owner approval before use in a shipped product. A change that uses `proposed-derived` token values without recorded brand-owner approval attached is a review FAILURE (Blocking), not a pass with a note — the mere existence of the `$status` field on the token file does not itself constitute approval.

### Web procedure

1. **Identify the surfaces.** List changed screens/components and the user flows they participate in. Capture BEFORE screenshots of each affected surface at the review breakpoints (or retrieve the prior baseline).
2. **Token conformance.** Diff the styles against `agent-framework/design-system/tokens/`. Flag every literal color/spacing/typography value that bypasses a token.
3. **Keyboard navigation.** Operate every changed flow with keyboard only: Tab/Shift-Tab order is logical, all interactive elements reachable and operable (Enter/Space/arrows as appropriate), no keyboard traps, skip mechanisms where flows are long.
4. **Focus visibility.** Focus indicator is clearly visible on every interactive element in every state and theme; focus is not lost or reset unexpectedly on dialogs, route changes, or list updates; focus returns sensibly when overlays close.
5. **Contrast (WCAG 2.2 AA).** Check text and meaningful non-text contrast against WCAG 2.2 AA (W3C Recommendation, 12 Dec 2024, https://www.w3.org/TR/WCAG22/, accessed 2026-07-18): 4.5:1 normal text, 3:1 large text and UI components/graphical objects. Record the tool used and measured ratios for anything near the limit.
6. **Responsive checks at defined breakpoints.** Verify layout at the project's defined breakpoints from the design-system tokens; if the project defines none, review at minimum 360 px (small phone), 768 px (tablet), 1280 px (laptop), and 1920 px (desktop) widths. No horizontal body scroll, no clipped/overlapping controls, touch targets adequate on small sizes.
7. **Motion, zoom, and forced-colors (binding design-system rules).** `prefers-reduced-motion` is honored everywhere — verify with the OS/browser setting enabled that non-essential animation/transition/autoplay is removed or reduced. User zoom is never disabled — verify no `user-scalable=no` / `maximum-scale=1` in viewport meta and pinch-zoom actually works. `forced-colors` mode is respected — verify the surface remains usable and does not lose meaning under a forced-colors/system high-contrast palette (no `forced-color-adjust: none` without a documented reason). A skip link is present and operable on every page/entry surface (first Tab reaches it, activating it moves focus past repeated navigation).
8. **Error recovery.** Trigger realistic failures (validation errors, network failure, save conflict). Errors are visible, human-readable, non-destructive (user input preserved), and offer a way forward (retry/fix). No dead ends, no silent failures.
9. **Loading states.** Every async operation has a visible loading/progress state; UI prevents duplicate submissions; slow paths do not look frozen; skeletons/spinners appear where waits are perceptible.
10. **Empty states.** First-run and zero-data views explain what the area is for and offer the next action — never a blank panel or a raw "0 results" with no guidance.
11. **First-time-user clarity.** Walk the flow as a novice: is the next step obvious, is jargon avoided or explained, are destructive actions guarded and labeled by consequence?
12. **Expert efficiency.** Frequent tasks have short paths: sensible defaults, keyboard shortcuts where established, bulk operations where lists are large, no forced modal detours for routine actions.
13. **Visual regression evidence.** Capture AFTER screenshots at the same breakpoints/states as the BEFORE set and diff them. Every intentional visual change is listed; every unintentional difference is a finding.

### Web verification checklist

- [ ] Keyboard navigation: full flows operable, no traps, logical order
- [ ] Contrast measured against WCAG 2.2 AA, tool + ratios recorded
- [ ] Focus visibility verified on all interactive elements and overlays
- [ ] Responsive verified at the defined breakpoints (listed in the report)
- [ ] `prefers-reduced-motion` honored everywhere (verified with the setting enabled)
- [ ] User zoom is never disabled (no `user-scalable=no`/`maximum-scale=1`; pinch-zoom works)
- [ ] `forced-colors` mode respected; surface stays usable under system high-contrast
- [ ] Skip link present and operable on every page/entry surface
- [ ] Error recovery exercised with real failure injection
- [ ] Loading states present for all async operations
- [ ] Empty states informative with a next action
- [ ] First-time-user walkthrough performed
- [ ] Expert-efficiency pass performed
- [ ] Before/after screenshots captured, diffed, and attached
- [ ] All style values traced to `agent-framework/design-system/tokens/`; no invented values

## Evidence requirements

Follow `agent-framework/canonical/policies/evidence-policy.md`. Screenshot pairs (before/after, per breakpoint and state) are mandatory evidence and must be stored at a referenced path. Contrast claims carry measured ratios and the measuring tool. Checks not performed (e.g., no device available) are `NOT RUN` with a reason, never assumed to pass.

## Output format

```
## UI/UX Review: <change>
Surfaces: <screens/components>
Breakpoints used: <list>
Screenshots: <path to before/after sets>

### Blocking   (inaccessible, data-losing, dead-end, or token-breaking on shipped surface)
- <finding> — surface/breakpoint — evidence (screenshot/ratio) — required fix

### Important
- ...

### Optional
- ...

### Verdict
<pass | pass after Blocking fixes | fail>
```

# Web and adopted-brand UI review

## Web/branded procedure

The following token governance, procedure, and checklist apply to web surfaces and products
that have adopted the extracted framework brand. Native branded surfaces keep their adopted
token governance; when reviewing native branded UI, use the
[native interaction/accessibility procedure](native-apple.md).

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


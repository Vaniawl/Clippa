# Native Apple UI evidence

Use only the procedure items relevant to changed surfaces. The preserved standard is
`agent-framework/canonical/policies/apple-product-engineering-reference.md`; numbered
sections below refer to that reference, not the compact router. Do not load the full guide.

## Capture and exercise the affected journey

1. Identify the tested revision/diff, actual app target, bundle ID, supported device/window
   and deterministic launch scenario from existing project/test configuration. Choose one
   representative primary journey and its affected recovery path before expanding coverage.
2. Use existing build/install/test scripts or the authorized platform runner. On iOS,
   inspect `xcrun simctl list devices booted` and available destinations before choosing a
   UDID. Launch the already-installed app with `xcrun simctl launch <UDID> <bundle-id>`
   only after resolving both values. For Mac, launch the actual built app using the project's
   existing procedure. Do not invent a runner, scheme, platform or launch argument.
3. Capture the baseline and changed screen with the same data, state and dimensions. For
   an inspected Simulator, `xcrun simctl io <UDID> screenshot <ignored-artifact-path>` is
   one available capture method. Use available screenshots/window capture on Mac. Inspect
   the images, rather than treating successful capture as a visual pass. Store bounded
   evidence in ignored/local artifacts and reference exact paths.
4. Operate the primary action and recovery using existing UI automation or manual input.
   Record expected and observed resulting state, not just element existence. Include long
   content/deep scroll or large text when they affect the changed flow; make status/recovery
   reachable without losing input, selection or scroll position. Record a short runtime
   observation/capture for motion and repeated input that static images cannot demonstrate.
5. For affected accessibility, actually enable relevant settings and exercise VoiceOver
   reading order, labels and focus; large text, Reduce Motion, appearance and keyboard-only
   operation as applicable. Name which checks were manual versus automated. If tools cannot
   operate those settings or input, state NOT RUN and request the required independent gate;
   do not claim accessibility from source inspection or a screenshot.
6. Report revision, device/window dimensions, OS/toolchain, content/scenario, steps/settings,
   assertions/observations and artifact paths. Add representative variants only where the
   change creates a risk. Missing baseline, launch access or runtime capabilities stay
   explicit; a source-only review is not runtime, visual or accessibility sign-off.

## Native Apple procedure

1. **Product and repository fit.** Identify the user's goal, primary/secondary actions,
   entry point, destination, affected states, and existing navigation/components. Check
   that the change solves the approved requirement without invented features, duplicate
   architecture, or unrelated restyling.
2. **Design-system fit.** Use the product's adopted components and tokens or native semantic
   controls, typography, colors, materials, and layout defaults. Framework example-brand
   tokens are not an unbranded app's design system. A missing recurring custom scale may
   be established coherently inside approved work, as original-reference section 5 permits.
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
    truncation. Read original-reference sections 49–51 and 74 for final review of the affected UI. Keep evidence
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


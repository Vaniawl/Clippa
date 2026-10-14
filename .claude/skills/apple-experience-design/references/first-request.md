# From one request to a finished native UI

Use this procedure when the user asks to build or redesign native Apple screens. The
coordinator owns the complete requested outcome; a design specialist owns only its assigned
specification or critique. Advice-only requests return a proposal without product writes.
Small edits reuse the established composition and need only the affected checks.

## Turn the request into a usable visual brief

Read the requested scenario, existing screens and product context. Resolve the audience,
primary task, platform and existing visual language. Treat an explicit request to build
specified screens as authorization to design, implement and verify those screens. Do not
stop after a scaffold or a specification, or request another approval for routine visual
choices within that outcome. Ask only when a missing decision materially changes the product,
scope or permissions; otherwise state reasonable assumptions and continue.

Routine assumptions resolve visual presentation and the interactions needed for the stated
journey. They do not authorize extra product features, storage, integrations or automatic
restoration across launches. Keep a feature that is not needed for the requested journey as
a proposal; do not implement it merely to make a demonstration feel more complete.

Use supplied references first. Identify which properties matter: hierarchy, content density,
type, spacing, color roles or interaction. Preserve an existing product's adopted style.
Without references, select an appropriate native direction from the task and realistic
content. A reading application and a frequent-use utility should not inherit the same
decorative composition. Neither the starter demo nor the framework's example brand is the
generated product's visual specification.

Define a compact brief before coding using the UX template: the key screen's first focal
point, information order, dominant action, grouping, navigation and recovery; text roles,
spacing rhythm, semantic colors, surfaces and asset needs. Choose native typography and
controls where appropriate. Establish shared custom tokens only for genuinely repeated
styling. Use representative product copy and long-content fixtures instead of starter
architecture messages. Complete the other screens requested by the user in the same visual
language; designing the first screen does not reduce the approved outcome.

Write observable, screen-specific acceptance criteria. Examples, adapted to the actual task:

- A reading screen makes the content title and reading action distinct from metadata;
  long titles wrap without pushing recovery out of reach.
- A task utility exposes its frequent action in the toolbar or normal content hierarchy;
  item titles and supporting details have visibly different emphasis.
- Repeated sections use the same alignment and spacing roles. At larger text sizes,
  actions remain usable without clipped text or overlapping controls.

These examples are guidance, not mandatory features or layouts. Native lists are appropriate
for repeated information; configure their hierarchy and grouping deliberately. Cards,
illustrations, gradients and motion need a content or interaction purpose.

## Choose the smallest useful design surface

For a new visual direction or a complex flow, use an available design tool when it helps
resolve composition before implementation. Respect a user-selected Figma, Penpot or other
tool. For an established style or a simple native screen, a concrete composition sketch and
SwiftUI previews can be sufficient to begin. A design-tool file is optional; no paid service,
plugin installation, login or external publication is a prerequisite for the local workflow.
If an optional tool is unavailable, continue through the available native path and disclose
the substitution. Actual required access and unresolved product decisions remain blockers.

The coordinator can design and implement directly. Delegate only for needed expertise,
useful independent work or a required independent review under the delegation policy.
Do not force a designer/engineer/reviewer chain on every screen. A specialist's handoff
returns to the coordinator; it does not finish the user's implementation request.

## Build, inspect and correct

Implement the chosen composition using the existing architecture and reusable components.
Cover applicable content, loading, empty, error and recovery states. Preserve input and
navigation context; keep recovery reachable at long/deep content positions. Run affected
build and behavior checks with the project's platform tools.

Use the native UI review procedure to launch and capture the actual changed screens.
Inspect the images against the brief: focal point, hierarchy, content density, grouping,
alignment, spacing, secondary text, primary action and coherent surfaces across states.
Exercise the primary journey and its recovery. Inspect relevant small/typical layouts,
light/dark appearances and large text where supported; expand coverage only for affected
risks. Record runtime observations for interaction/motion and actual accessibility checks
separately from screenshot review.

Fix concrete significant visual findings and inspect fresh captures of the corrected state.
Continue within the requested outcome until its applicable criteria are met or a specific
decision/access/budget limit prevents completion. If two attempts produce the same failure,
change the approach or report the precise limit rather than repeating blind retries.
Keep required independent gates independent.

## Handover with visual evidence

Return the implemented outcome with representative capture paths, tested revision,
device/window, appearance and content state, plus the criteria checked and corrections made.
Summarize any open significant finding. State unavailable launch, capture, image inspection,
interaction or accessibility checks as NOT RUN with a reason. Completion of a specification,
compilation or image capture alone cannot be reported as verified professional UI quality.
When visual inspection is unavailable, report implementation and visual acceptance separately.

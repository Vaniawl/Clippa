---
name: apple-experience-design
description: Specify Apple-native flows and visual composition for new or materially changed interfaces; critique supplied runtime captures against the assigned design.
---


<!-- GENERATED from agent-framework/canonical/skills/apple-experience-design/SKILL.md — edit the canonical source, then run: python3 scripts/agent-framework/render.py -->
# Apple Experience Design

## Trigger and inputs
Use when specifying a new flow or significant interface change before implementation, or critiquing supplied runtime captures against an assigned design. Inputs: approved outcome or proposal, audience, existing screens/navigation/design system, platform and deployment targets; for critique, the assigned specification, captures and their revision/scenario. Use the compact Apple product-engineering router and only its task-relevant UI/interaction reference sections; use native semantics or the product's adopted brand, never the framework example brand by default.

## Method and output
For a request to build or redesign native screens, use the
[first-request UI procedure](references/first-request.md) to establish a concrete brief
and hand off the visual criteria for implementation and runtime correction. A coordinator
continues the complete authorized outcome; this skill does not expand a design specialist's
write authority. Reuse the existing brief for a small mechanical edit.

Use `agent-framework/templates/ux-spec.md`. Define user intent, primary action, entry/exit and navigation, information hierarchy and applicable idle/loading/empty/content/error/offline/permission/cancellation states. State why omitted states are not relevant. Include failure recovery and preservation of user work. Keep status and recovery reachable at every preserved scroll/selection position, including largest supported text sizes and long lists. Include realistic and long content, UI copy, motion purpose and Reduce Motion behavior. Specify accessibility labels/focus, Dynamic Type where supported, keyboard/menu behavior for Mac, contrast, light/dark appearance, size changes and adaptive layouts. Reuse existing controls/components; create a small token scale only if recurring custom styling needs it.

Give observable implementation and visual acceptance criteria, representative preview content and a runtime review matrix. Advice returns a specification in conversation. Execution permits only assigned design documents/resources, never product code. An approved design is not implementation evidence.

## Visual craft

Before a new or materially redesigned screen is implemented, specify its visual direction
from the audience, purpose and adopted style. Describe the actual composition with realistic
content: first focal point, information order, dominant action, grouping and useful whitespace.
Reuse the product's established direction; for a new direction explain the choice using supplied
references or native precedents. Additional variants are useful only for an unresolved choice.

Make type hierarchy, spacing rhythm, alignment, color roles, surface treatment, icons and any
illustration/image needs concrete. Prefer native semantics for an unbranded Apple product;
custom styling must serve its identity or content and remain coherent across screens/states.
Account for content density, number/date formatting, long copy and meaningful transitions.
Avoid placeholder product copy and incidental decoration in final product surfaces.

Write screen-specific visual acceptance criteria a builder and reviewer can observe. Include
an existing component/layout reference or a composition sketch when needed to communicate the
design; naming a theme or saying "make it premium" is insufficient. After implementation,
inspect supplied runtime captures against those criteria and return precise corrections for
the builder. Capture or interaction evidence that is unavailable remains NOT RUN; professional
quality is an evaluated product outcome, not guaranteed by installing this skill.

## Verification and stop
Walk primary and failure paths for dead ends, duplicate actions, lost input and long-content overflow. Confirm a clear primary action and product-compatible navigation. Mark platform/tool-dependent checks NOT RUN; accessibility review of implemented UI remains independent when the delegation risk matrix requires it; routine edits retain focused applicable checks. Stop at a decision-ready UX specification, assigned resource revision or delivered capture critique with precise corrections and a builder handoff; request a product decision only if the design changes the agreed outcome.

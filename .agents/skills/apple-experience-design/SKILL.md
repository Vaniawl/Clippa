---
name: apple-experience-design
description: Specify Apple-native user flows, meaningful states, recovery, copy, motion and adaptive layout for a new or materially changed interface.
---


<!-- GENERATED from agent-framework/canonical/skills/apple-experience-design/SKILL.md — edit the canonical source, then run: python3 scripts/agent-framework/render.py -->
# Apple Experience Design

## Trigger and inputs
Use when specifying a new flow or significant interface change before implementation. Inputs: approved outcome or proposal, audience, existing screens/navigation/design system, platform and deployment targets. Use the compact Apple product-engineering router and only its task-relevant UI/interaction reference sections; use native semantics or the product's adopted brand, never the framework example brand by default.

## Method and output
Use `agent-framework/templates/ux-spec.md`. Define user intent, primary action, entry/exit and navigation, information hierarchy and applicable idle/loading/empty/content/error/offline/permission/cancellation states. State why omitted states are not relevant. Include failure recovery and preservation of user work. Keep status and recovery reachable at every preserved scroll/selection position, including largest supported text sizes and long lists. Include realistic and long content, UI copy, motion purpose and Reduce Motion behavior. Specify accessibility labels/focus, Dynamic Type where supported, keyboard/menu behavior for Mac, contrast, light/dark appearance, size changes and adaptive layouts. Reuse existing controls/components; create a small token scale only if recurring custom styling needs it.

Give observable implementation and visual acceptance criteria, representative preview content and a runtime review matrix. Advice returns a specification in conversation. Execution permits only assigned design documents/resources, never product code. An approved design is not implementation evidence.

## Verification and stop
Walk primary and failure paths for dead ends, duplicate actions, lost input and long-content overflow. Confirm a clear primary action and product-compatible navigation. Mark platform/tool-dependent checks NOT RUN; accessibility review of implemented UI remains independent. Stop at a decision-ready UX specification or assigned resource revision; request a product decision only if the design changes the agreed outcome.

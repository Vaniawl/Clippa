---
name: product-discovery
description: Turn an Apple product idea or ambiguous feature into a product brief and a falsifiable recommendation before implementation.
---


<!-- GENERATED from agent-framework/canonical/skills/product-discovery/SKILL.md — edit the canonical source, then run: python3 scripts/agent-framework/render.py -->
# Product Discovery

## Trigger and inputs
Use when the problem, audience, value or success criteria are unclear. Read the request, existing vision/PROJECT, approved constraints and real research or feedback supplied. Missing data is not proof of demand. Ask only consequential product questions after repository inspection.

## Method and output
Draft the brief using `agent-framework/templates/product-brief.md`: problem in context, specific audience and business owner, alternatives, value, non-goals, hypotheses, constraints, observable success and the cheapest useful validation step. Separate verified facts, inferences and unknowns. Avoid assuming consumer subscriptions or enterprise procurement; the product determines its business model. Recommend one direction and explain any material tradeoff. A new direction remains a recommendation pending owner approval.

## Verification and stop
Each acceptance criterion describes observable behavior or measurable evidence. Each demand/feedback claim identifies actual data or is a hypothesis. Check traceability to existing vision; explicitly flag proposed changes. Return the brief in the conversation in advice mode, with no file writes. Stop once the requested brief/recommendation and unresolved owner decisions are clear; do not begin implementation.

# Invoke specialists only when needed

The default route is the coordinator working directly with relevant skills. This table is a
responsibility guide, not a list of mandatory calls. Invoke only the role whose expertise,
independent work or review is needed for the current outcome.

| Need | Available specialist | Result |
| --- | --- | --- |
| Unresolved product framing or priorities | product-manager | Problem, audience, value and observable success |
| Substantial external market/technical evidence | market-opportunity-researcher or deep-researcher | Sourced findings and explicit unknowns |
| Complex flows, visual system or UX expertise | ui-ux-designer | Applicable states, recovery and adaptive specification |
| Structural decisions or changed contracts | software-architect; integration/data roles when relevant | ADR and compatibility decision |
| Useful independent implementation slice | implementation-engineer | Scoped changes and actual validation evidence |
| Significant/risky implementation or an explicit review request | code-reviewer; relevant security/accessibility reviewer | Independent findings on the actual changed revision |
| Missing reproduction or distinct runtime/failure coverage | qa-test-engineer | Reproduction and regression/runtime evidence |
| Measured performance concern | performance-reliability-engineer | Measurements and bounded optimization |
| Positioning, launch or measurement expertise | marketing/growth roles as needed | Substantiated materials, metrics or experiment interpretation |
| Packaging/signing/delivery readiness expertise | devops-release-engineer | Readiness evidence; no automatic publication |
| Consequential disputed claim | skeptical-reviewer | Falsification and evidence limits |

A typo, simple known calculation, contained advice or routine scoped edit can finish with
zero workers. A one-line authorization or data-loss change can still need independent review:
judge consequences, not size. If the coordinator authors a significant/risky change, invoke
an independent reviewer after implementation; an extra implementation worker is not required.
If the reviewer finds a defect, the author fixes it and the corrected revision is reviewed.

Do not summon QA just to repeat existing deterministic tests, a researcher without a research
question, or a designer/reviewer for every recommendation. Do not turn a marketing request
into automatic research+growth fan-out. Methods and applicable quality obligations remain
binding regardless of whether work is direct or delegated. Persona simulations remain
hypotheses; interviews, TestFlight results and metric outcomes require real supplied data.

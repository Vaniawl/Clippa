# Routing an Apple product request

| Request | Minimal route | Deliverable |
| --- | --- | --- |
| New idea | PM + market researcher; designer after problem framing | Product brief, evidence gaps, next falsifiable probe |
| Develop a feature proposal | PM + designer; architect for structural changes | UX specification and bounded implementation recommendation |
| Implement agreed option | Engineer → independent reviewer; QA for integration/runtime gaps | Changed behavior with revision-specific evidence |
| Fix a bug | QA/reproducer → engineer → independent reviewer | Cause, minimal fix and regression evidence |
| Professional UI/design | Designer proposal; execute only when requested | Applicable state/recovery specification, then visual/accessibility evidence |
| Prepare promotion | Marketing + researcher + growth analyst | Positioning, local materials and experiment plan |
| Release readiness | Release engineer + relevant quality reviewers | Go / Conditional Go / No-Go with reasons; no automatic publication |

Add accessibility for meaningful UI, security/privacy for changed trust boundaries, performance for measured concerns, and skeptical review for complex decisions/final milestones. Integration, data, technical research and persona simulation are optional specialists. Do not invoke every role. Persona simulation is hypothesis generation; interviews and TestFlight feedback require real supplied data.

Role IDs remain provider-neutral: product-manager, market-opportunity-researcher, ui-ux-designer, software-architect, implementation-engineer, code-reviewer, qa-test-engineer, accessibility-reviewer, performance-reliability-engineer, security-privacy-reviewer, product-marketing-strategist, growth-analyst, devops-release-engineer, technical-writer and skeptical-reviewer. Select method skills separately from role permissions.

For a fully specified, small pure-function change with existing reproducible tests, use one writer and one independent reviewer. Do not add a third worker solely to repeat the same deterministic checks. QA joins for missing reproduction, integration/runtime evidence or independent failure-path coverage. Keep routing proportional.

A contained UX advice request can use one designer and coordinator integration. Add independent skeptical review for a complex or consequential decision, and implementation/accessibility review for executed UI. Do not make a second advice reviewer automatic when the scope and evidence gaps are already clear.

# Invoke specialists only when needed

The default route is the coordinator working directly with relevant skills. This table is a
responsibility guide, not a list of mandatory calls. Invoke only the role whose expertise,
independent work or review is needed for the current outcome.

| Need | Available specialist | Result |
| --- | --- | --- |
| Unresolved product framing or priorities | product-manager | Problem, audience, value and observable success |
| Substantial external market/technical evidence | market-opportunity-researcher or deep-researcher | Sourced findings and explicit unknowns |
| New screens needing visual direction, complex flows or professional-design expertise | ui-ux-designer | Visual direction, screen composition, meaningful states and polish criteria |
| Structural decisions or changed contracts | software-architect; integration/data roles when relevant | ADR and compatibility decision |
| Useful independent implementation slice | implementation-engineer | Scoped changes and actual validation evidence |
| Significant/risky implementation or an explicit review request | code-reviewer; relevant security/accessibility reviewer | Independent findings on the actual changed revision |
| Missing reproduction or distinct runtime/failure coverage | qa-test-engineer | Reproduction and regression/runtime evidence |
| Measured performance concern | performance-reliability-engineer | Measurements and bounded optimization |
| Positioning, launch or measurement expertise | marketing/growth roles as needed | Substantiated materials, metrics or experiment interpretation |
| Packaging/signing/delivery readiness expertise | devops-release-engineer | Readiness evidence; no automatic publication |
| Consequential disputed claim | skeptical-reviewer | Falsification and evidence limits |
| Actual interviews/usability/TestFlight observations | user-researcher | Traceable real-evidence synthesis or a study plan |
| String catalogs, plurals, RTL or regional resources | localization-specialist | Assigned localized resources and locale/layout evidence |
| TestFlight/App Review/metadata/rollout coordination | app-store-release-manager | Fresh candidate-specific release dossier and open gates |
| Sanitized support feedback and response drafts | customer-support-specialist | Reproduction, support draft and escalation |
| Icons/store screenshots/previews/campaign assets | brand-creative-designer | Truthful local assets, editable sources and exports |

## Matching workflow and optional method

Select only a matching outcome in the workflow catalog: apple-feature-delivery,
app-store-delivery, apple-data-commerce-change, apple-incident-response or
apple-growth-experiment. Workflow role lists assign responsibility; they do not mandate calls.

Persistence/sync uses apple-data-sync; purchases use storekit-monetization; packaging/signing
uses apple-signing-distribution; locale work uses app-localization; measured diagnostics uses
ios-observability; real study work uses user-research; campaign assets use
marketing-creative-production. apple-platform-capabilities routes approved notifications,
background work, links, extensions, widgets/activities/intents and specialized native SDKs.
Check installed or supplied canonical entrypoints before loading. If a method is absent,
state the missing capability rather than pretending catalog discovery installed it.

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

# Apple team coverage and ownership

The starter supplies 26 role contracts and 41 skill definitions. All roles are discoverable;
the coordinator starts without workers and invokes a specialist only for a concrete need.
Fifteen shared methods plus the project-selected native methods form the installed base.
The eight new domain skills remain optional; availability does not add an app capability.

| Responsibility | Role contract | Relevant methods | Evidence/result |
| --- | --- | --- | --- |
| Coordination | orchestrator | apple-team | Bounded outcome, applicable gates, integrated evidence |
| Product priorities | product-manager | product-discovery | User value, acceptance criteria, owner decisions |
| Architecture | software-architect | architecture-review, ios-development | Approved structure/compatibility and ADR |
| Native implementation | implementation-engineer | ios-development, feature-slice; applicable domain method | Owned feature and failure-path checks |
| Independent correctness | code-reviewer | ios-development; changed domain method | Revision-specific prioritized findings |
| Test engineering | qa-test-engineer | ios-testing | Unit/UI/performance/failure evidence |
| Security/privacy | security-privacy-reviewer | security-review, ios-quality | Actual flows, controls and declaration impact |
| Build/signing/CI | devops-release-engineer | apple-signing-distribution, release-readiness | Reproducible archive/export/symbol evidence |
| Persistence/sync | data-database-engineer | apple-data-sync | Supported migration, compatibility and recovery |
| External boundaries | integration-architect | architecture-review, apple-platform-capabilities, storekit-monetization | Current sourced API/Apple-service contract |
| Product UX | ui-ux-designer | apple-experience-design, product-copy | Native flow, states, prototype/handoff |
| Accessibility | accessibility-reviewer | ui-ux-review, ios-quality | Tested common tasks/assistive technology |
| Performance/reliability | performance-reliability-engineer | ios-observability, resource-safety | Equivalent before/after and field-data limits |
| Developer/operating docs | technical-writer | Relevant source/domain method | DocC, onboarding and usable runbooks |
| Technical research | deep-researcher | Primary-source registry | Dated, version-applicable findings |
| Market opportunity | market-opportunity-researcher | market-validation | Segment/geography evidence and limitations |
| Simulated journeys | end-user-simulator | Relevant persona | Explicit hypotheses, never empirical users |
| Claim falsification | skeptical-reviewer | Evidence policy | CONFIRMED/REFUTED/UNVERIFIABLE with severity |
| Stuck-task diagnosis | rubber-duck | debug-systematically when useful | Diagnostic questions and next discriminating check |
| Positioning/ASO/launch | product-marketing-strategist | product-positioning, app-store-marketing | Truthful local brief and experiment proposal |
| Growth/revenue analysis | growth-analyst | product-measurement | Reproducible real-data analysis; read-only |
| Real user evidence | user-researcher | user-research | Sanitized observation-linked synthesis; read-only |
| Languages/regions | localization-specialist | app-localization, product-copy | Owned catalogs/assets, plurals/RTL evidence |
| Store release coordination | app-store-release-manager | release-readiness, app-store-marketing | Candidate dossier, review/rollout gates |
| Customer support | customer-support-specialist | product-copy, ios-observability | Assigned docs/drafts, repro and escalation |
| Brand/marketing creative | brand-creative-designer | marketing-creative-production | Assigned source assets and truthful exports |

## Select optional methods

Add only needed IDs to `project.yaml` → `agent_framework.skills`, then render in authorized
configuration scope. Default discovery installs no new domain skills. Canonical method
entrypoints remain readable when the framework payload supplies them; provider automatic
skill discovery uses installed copies. A catalog entry alone guarantees neither presence
nor external tools. Preserve existing selections and local provider/model overrides.

Native macOS remains conditional on project platforms and its existing methods. Use framework
capability references to route media/location/Bluetooth/HealthKit/HomeKit/CarPlay/AR/ML needs;
verify actual hardware/OS/entitlements. Server or specialist compliance work needs separately
scoped expertise and is not represented as automatically verified by an iOS agent.

Framework maintenance belongs to the template maintainer/coordinator: canonical contracts,
renderer/adapters, source registry, evals and migration fixtures. No sixth product role is
installed merely for maintaining the starter.

## Complete outcomes

Five focused workflows cover feature delivery, App Store delivery, data/commerce changes,
incidents and growth experiments. Use the existing broader lifecycle only when appropriate.
Role lists are responsibility maps. QA does not repeat deterministic checks just to fill a
stage; reviewers do not write fixes; DevOps does not own marketing strategy; store release
coordination does not grant permission to publish. Independent review follows changed risk.

Initialize a fresh checklist from `agent-framework/templates/release-checklist.md`. Keep
historical evidence labelled with its version. Production CloudKit schema and installed App
Store binaries need supported forward recovery, not a claimed universal reverse migration.

Sources: [primary-source registry](apple-source-registry.md).
Behavioral scenarios and their execution status live under `agent-framework/evals/`;
structural generation is distinct from actual model/runtime evidence.

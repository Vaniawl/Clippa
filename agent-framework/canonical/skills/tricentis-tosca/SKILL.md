---
name: tricentis-tosca
description: Work involving Tricentis Tosca — a commercial test automation platform — at the level of scope framing, terminology hygiene, and official-source discipline. Use when a task concerns Tosca-based test automation design, execution, or integration, to enforce consulting current Tricentis documentation instead of guessed product detail.
license: Proprietary
metadata:
  status: incomplete
  kind: domain
  last-reviewed: "2026-07-18"
---

# Tricentis Tosca

> **HONEST STUB.** No detailed module procedures, object names, or configuration steps are included, because they were not verified during authoring. Tosca is a versioned commercial platform (cloud and on-premises documentation lines exist); details must come from current Tricentis documentation for the customer's version.

## Trigger

Load this skill when the task involves Tricentis Tosca: designing or reviewing Tosca test automation, planning Tosca execution in pipelines, integrating Tosca with test management or ALM tools, or assessing Tosca suitability/coverage for an application landscape (SAP and other enterprise apps are common targets).

## Scope

General orientation only: Tosca is Tricentis's test automation platform; this skill defines research discipline and boundaries.

## Non-goals

- Providing module names, scan/steering details, licensing mechanics, or menu paths from memory — look them up in Tricentis docs for the exact version.
- General test strategy (use the core skills) or other vendors' tooling.

## Official-source policy

Consult official Tricentis sources FIRST and prefer them over this file:

- Tricentis documentation portal (all products): https://docs.tricentis.com/all/home.htm (verified — title "Tricentis Documentation | Product Documentation for All Tricentis Products", listing Tosca Cloud, Tosca on-premises, qTest, and others; accessed 2026-07-18).
- Tosca on-premises all-versions manuals: https://docs.tricentis.com/all/manuals/tosca_op.htm (located via search on the official domain, 2026-07-18).

Record URL, product line, version, and access date for every claim.

Use actually available web/docs tools only when permitted by the active role and task, or applicable supplied/local primary sources. A role's permitted_tools list does not provision access or enforce a sandbox; callable tools do not expand authority. If the active role lacks the `web` tool or permission and local evidence is insufficient, request a deep-researcher task via the orchestrator when available, or mark the claim UNKNOWN; do not cite current official-source claims from memory or simulate a lookup.

## Version awareness

Identify the customer's Tosca line and version before advising: the official portal distinguishes Tosca Cloud from Tosca on-premises (verified 2026-07-18), and search results on the official domain showed versioned on-premises documentation sets including LTS-labeled lines (e.g., titles referencing "2025.1 LTS" and "2026.1 LTS", located 2026-07-18 — treat as directory evidence, confirm at use time). Behavior differs across versions; never carry claims between them unchecked.

## Required citations

Every recommendation about Tosca capabilities, configuration, or integrations must cite a specific Tricentis documentation page with product line + version + access date. Uncited claims are `UNKNOWN`.

## Terminology

Verified at general level only: "Tricentis Tosca" (test automation platform), "Tosca Cloud" and "Tosca on-premises" as distinct documented lines (official portal, accessed 2026-07-18). Verify all internal object/module terminology against the version-specific manual before using it in deliverables.

## Common workflows

Categories of work (no invented click-paths):

- Designing model-based test automation portfolios for enterprise applications on Tosca.
- Reviewing existing Tosca assets for maintainability, reuse, and coverage against requirements.
- Planning scheduled/distributed or pipeline-triggered Tosca execution per official integration docs.
- Connecting Tosca results to test management (e.g., qTest — see `tricentis-qtest`) and defect tracking.

## Integration boundaries

At a general level, Tosca deployments commonly interact with: applications under test (SAP and other enterprise systems, web, APIs), test management/ALM tools, CI/CD pipelines, and reporting platforms. Confirm the customer's actual integration set from their landscape and official docs.

## Verification checklist

- [ ] Tosca line (Cloud vs. on-premises) and exact version identified
- [ ] Every product claim cites Tricentis docs + version + access date
- [ ] No module/object names used without version-specific verification
- [ ] Execution/integration designs validated against official integration docs
- [ ] Unknowns listed as `UNKNOWN`

## References

See `references/SOURCES.md` in this skill's directory. Status `incomplete` — consult official docs at use time and record findings there.

## Last reviewed: 2026-07-18 (status: incomplete-stub)

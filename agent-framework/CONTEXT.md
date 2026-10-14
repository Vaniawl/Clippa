# Framework context map

Purpose: route one request to the smallest relevant set of instructions. Paths are
relative to this file. Read a selected document; do not preload the entire table.

## Entry and authority

1. Read [operating instructions](canonical/operating-instructions.md) before work.
   They preserve scope, authorization, security, evidence and independent-review gates.
2. Use [apple-team](canonical/skills/apple-team/SKILL.md) and the
   [orchestrator role](canonical/roles/orchestrator.yaml) for coordination.
3. Select a route below. Read its `CONTEXT.md`, then the applicable parts of its
   `WORKFLOW.md`. Roles describe responsibilities, not mandatory subagent calls.

## Select a workflow

| Request | Local contract | Additional inputs only when relevant |
| --- | --- | --- |
| Approved Apple feature or screen | [Feature delivery](canonical/workflows/apple-feature-delivery/CONTEXT.md) | Requirement, affected components, UX/ADR |
| Technical question requiring sources | [Deep research](canonical/workflows/deep-research/CONTEXT.md) | Question, versions, actual docs/web access |
| Audience, competitors or demand | [Market research](canonical/workflows/market-research/CONTEXT.md) | Audience, product hypothesis, dated sources |
| Product lifecycle spanning several concerns | [Software lifecycle](canonical/workflows/software-lifecycle/CONTEXT.md) | Only applicable stages and their inputs |
| Persona simulation | [Persona validation](canonical/workflows/persona-validation/CONTEXT.md) | Supplied product and persona; simulation is not customer evidence |
| App Store preparation | [App Store delivery](canonical/workflows/app-store-delivery/CONTEXT.md) | Exact candidate/version and delivery authorization |
| Persistence, sync or commerce | [Data/commerce change](canonical/workflows/apple-data-commerce-change/CONTEXT.md) | Schema, compatibility, recovery and trust boundaries |
| Bug or incident | [Incident response](canonical/workflows/apple-incident-response/CONTEXT.md) | Reproduction and sanitized diagnostics |
| Growth or measurement experiment | [Growth experiment](canonical/workflows/apple-growth-experiment/CONTEXT.md) | Approved hypothesis and supplied measurements |
| Explicitly supervised long run | [Autonomous session](canonical/workflows/autonomous-session/CONTEXT.md) | User-selected scope, budget, duration and isolated worktree |

For a contained framework/configuration task, read the affected sources and applicable
contracts directly; do not force an Apple workflow. Use the
[role](catalogs/role-catalog.yaml), [skill](catalogs/skill-catalog.yaml) and
[workflow](catalogs/workflow-catalog.yaml) catalogs only when discovery is needed.

## Context boundaries

- Product intent: `PROJECT.md`, approved `BACKLOG.md` item and relevant vision/scope.
- Structure: relevant architecture overview and ADRs. Trust/privacy: threat model and
  [security policy](canonical/policies/security-policy.md). Testing: relevant test strategy.
- Delegation: [task contract](canonical/contracts/agent-task-contract.md) and
  [delegation policy](canonical/policies/delegation-policy.md); pass bounded inputs.
- Completion: [evidence policy](canonical/policies/evidence-policy.md),
  [definition of done](canonical/contracts/definition-of-done-contract.md) and
  [handover](canonical/contracts/agent-handover-contract.md).

## Working artifacts

Stable instructions stay in canonical/templates; project task artifacts live in `docs/tasks/`.
For authorized execution, copy [the task folder](templates/task-folder/CONTEXT.md) to
`docs/tasks/<task-id>/`. Read the project's `docs/tasks/CONTEXT.md` first. Advice creates
no tracked task folder unless saving is requested. Raw logs stay in ignored artifacts.
Existing code, ADRs and reports keep their homes; link to them from the task folder.
Use `docs/adr/0010-icm-context-navigation.md` in this source repository for
the design rationale; adopters use their own approved architecture decisions.

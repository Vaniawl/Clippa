# Task context

Purpose: execute or resume the single approved outcome in [task.md](task.md).
This folder is a template until copied and filled for authorized work.

## Inputs

| Input | Location | Scope |
| --- | --- | --- |
| Approval, ownership, criteria and selected workflow | [task.md](task.md) | Entire task contract |
| Prior decisions | [decisions.md](decisions.md) | Only decisions affecting this task |
| Actual validation results | [evidence.md](evidence.md) | Applicable criteria and tested revision |
| Last confirmed state | [handover.md](handover.md) | Verify revision before trusting claims |
| Binding execution rules | [Operating instructions](../../../agent-framework/canonical/operating-instructions.md) | Mandatory; load extra policies only as applicable |

## Process

1. Confirm approval and checkout revision. Unfilled placeholders are not authorization.
2. Follow the local contract of the workflow selected in `task.md`; load its scoped inputs.
3. Select applicable stages below in `task.md`; perform one bounded unit and write its
   handoff before consuming it. Revisit the responsible stage when inputs change or checks fail.
4. Record real evidence and update handover without widening scope or inventing success.

| Stage | Contract | Editable handoff |
| --- | --- | --- |
| 01: scope | [Scope](01-scope/CONTEXT.md) | `01-scope/output/scope.md` |
| 02: design | [Design](02-design/CONTEXT.md) | `02-design/output/plan.md` |
| 03: build | [Build](03-build/CONTEXT.md) | `03-build/output/changes.md` |
| 04: verify | [Verify](04-verify/CONTEXT.md) | `04-verify/output/verification.md` |

Use all four for substantial delivery. A tiny fix may select fewer in `task.md`, stating
why and which input replaces an omitted handoff. No empty directory implies completion.

## Outputs and review

- Implementation artifacts stay within the owned paths in `task.md`.
- `decisions.md` links authoritative decisions; `evidence.md` records commands and results.
- `handover.md` records status, revision, remaining work and one concrete next action.
- Required human approvals and independent gates come from the existing policies/workflow.
  Routine steps do not gain new approval requirements. A copied template is not a completed task.

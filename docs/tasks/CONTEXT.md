# Project task workspaces

For authorized execution, copy `agent-framework/templates/task-folder/` to a new `docs/tasks/<task-id>/` directory; never overwrite an existing task. Advice creates no tracked workspace unless saving is requested.

## Inputs

Use the [framework map](../../agent-framework/CONTEXT.md), approved outcome, relevant requirement and current checkout revision.

## Process

Fill task.md (approval, ownership, criteria, workflow, selected stages and checks); use the template's numbered stages and editable output/ handoffs for substantial work. Explain omitted stages/replacement inputs in task.md. Keep decision links in decisions.md, actual commands/results in evidence.md, and revision/status/next action in handover.md. Verify the handover revision on resume.

## Outputs and gates

Project-owned task folders contain CONTEXT.md, task.md, decisions.md, evidence.md and handover.md. Code, ADRs and reports keep their existing homes; link to them. Existing approval, independent review and evidence policies apply. Raw logs stay ignored; folder presence does not prove completion. Autonomous supervisor state remains in agent-framework/runs/.

## Foundation rollout — 2026-10-14

[ICM-GITHUB-01](ICM-GITHUB-01/CONTEXT.md) records this owner-approved foundation change.
Read its current handover/evidence before resuming; it does not approve product features.

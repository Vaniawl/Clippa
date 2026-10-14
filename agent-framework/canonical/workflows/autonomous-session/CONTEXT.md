# Run one explicitly authorized supervised session

Purpose: run one explicitly authorized supervised session. This is the local context boundary;
[WORKFLOW.md](WORKFLOW.md) remains authoritative for detailed steps and gates.

## Inputs

| Source | Scope / why |
| --- | --- |
| User request or saved task contract | Human-reviewed run config; approved backlog/scope; explicit user-selected duration and budget; isolated worktree and actual provider access. |
| [Workflow](WORKFLOW.md) | Entry/exit criteria and only applicable stages |
| [Operating instructions](../../operating-instructions.md) | Mandatory execution/authority rules; read once per confirmed context |

## Process

Follow WORKFLOW.md configuration/preflight; run the bounded supervisor only when authorized; inspect checkpoints, actual evidence and termination; resume through its supported state.

Load only the references required by the current step. Retain confirmed context;
when a dependency is unavailable, record the specific gap instead of inventing evidence.

## Outputs

Supervisor-owned run-state.json, handover-N.md, exec-plan.md, logs and morning-report.md under the configured ignored run directory; task folder links only.

## Human and independent gates

No run starts from this context file alone. Budget/deadline, network/command policy, restart caps and external-action approvals remain binding; task handover does not replace supervisor state.
Advice stays in conversation unless saving is requested; existing role ownership applies.

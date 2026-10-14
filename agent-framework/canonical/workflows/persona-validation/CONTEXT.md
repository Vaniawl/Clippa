# Simulate specified user tasks against the product

Purpose: simulate specified user tasks against the product. This is the local context boundary;
[WORKFLOW.md](WORKFLOW.md) remains authoritative for detailed steps and gates.

## Inputs

| Source | Scope / why |
| --- | --- |
| User request or saved task contract | Assigned persona; product/build and target tasks; available runtime/UI access; relevant UX criteria. |
| [Workflow](WORKFLOW.md) | Entry/exit criteria and only applicable stages |
| [Operating instructions](../../operating-instructions.md) | Mandatory execution/authority rules; read once per confirmed context |

## Process

Select the assigned persona; attempt its tasks; record observed simulation friction with reproductions; return findings to the owner.

Load only the references required by the current step. Retain confirmed context;
when a dependency is unavailable, record the specific gap instead of inventing evidence.

## Outputs

AI-persona simulation report, actual captures/observations and gaps; saved only when authorized and linked from the task folder.

## Human and independent gates

A simulation is not customer research. Simulator roles stay read-only; do not implement fixes or silently change persona goals.
Advice stays in conversation unless saving is requested; existing role ownership applies.

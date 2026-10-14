# Deliver one approved Apple feature

Purpose: deliver one approved apple feature. This is the local context boundary;
[WORKFLOW.md](WORKFLOW.md) remains authoritative for detailed steps and gates.

## Inputs

| Source | Scope / why |
| --- | --- |
| User request or saved task contract | Approved requirement and affected components; relevant UX specification/ADR; platform and changed risk. |
| [Workflow](WORKFLOW.md) | Entry/exit criteria and only applicable stages |
| [Operating instructions](../../operating-instructions.md) | Mandatory execution/authority rules; read once per confirmed context |

## Process

Select applicable requirements/design steps; implement the bounded slice; run affected tests and runtime checks; obtain required independent review; integrate corrections and evidence.

Load only the references required by the current step. Retain confirmed context;
when a dependency is unavailable, record the specific gap instead of inventing evidence.

## Outputs

Owned source/test changes; links to UX/ADRs; criterion evidence and handover in the task folder.

## Human and independent gates

Scope/architecture approval and independent risk gates from WORKFLOW.md. Native UI requires runtime inspection; unavailable checks remain NOT RUN.
Advice stays in conversation unless saving is requested; existing role ownership applies.

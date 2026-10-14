# Change one approved persistence, sync or commerce boundary

Purpose: change one approved persistence, sync or commerce boundary. This is the local context boundary;
[WORKFLOW.md](WORKFLOW.md) remains authoritative for detailed steps and gates.

## Inputs

| Source | Scope / why |
| --- | --- |
| User request or saved task contract | Approved requirement/ADR; affected schema/state/entitlement contracts; threat model; compatibility and recovery constraints. |
| [Workflow](WORKFLOW.md) | Entry/exit criteria and only applicable stages |
| [Operating instructions](../../operating-instructions.md) | Mandatory execution/authority rules; read once per confirmed context |

## Process

Design the contract and failure/recovery semantics before implementation; build the scoped change; validate upgrade/recovery and failure paths; obtain required independent review.

Load only the references required by the current step. Retain confirmed context;
when a dependency is unavailable, record the specific gap instead of inventing evidence.

## Outputs

Owned implementation and tests; authoritative ADR/threat-model updates where needed; compatibility/recovery evidence and handover links.

## Human and independent gates

Architecture and destructive-operation approval rules apply. Independent code/security review follows actual changed risk; unsupported rollback is never claimed.
Advice stays in conversation unless saving is requested; existing role ownership applies.

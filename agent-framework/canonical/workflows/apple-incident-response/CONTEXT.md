# Diagnose and correct one bounded defect or incident

Purpose: diagnose and correct one bounded defect or incident. This is the local context boundary;
[WORKFLOW.md](WORKFLOW.md) remains authoritative for detailed steps and gates.

## Inputs

| Source | Scope / why |
| --- | --- |
| User request or saved task contract | Reproduction, sanitized diagnostics and affected revision/environment; expected behavior and user impact. |
| [Workflow](WORKFLOW.md) | Entry/exit criteria and only applicable stages |
| [Operating instructions](../../operating-instructions.md) | Mandatory execution/authority rules; read once per confirmed context |

## Process

Reproduce and minimize; rank evidence-based hypotheses; test one at a time; fix the cause; run regression/adjacent failure checks and applicable review.

Load only the references required by the current step. Retain confirmed context;
when a dependency is unavailable, record the specific gap instead of inventing evidence.

## Outputs

Reproduction/root-cause findings; authorized source/test changes; actual diagnostics/check results and handover links.

## Human and independent gates

Do not claim a cause without evidence or widen into unrelated fixes. Privacy, operational and independent-review gates apply to the actual change.
Advice stays in conversation unless saving is requested; existing role ownership applies.

# Confirm one approved outcome

Purpose: one delivery stage; task.md selects applicability.

## Inputs

| Source | Section / scope | Why |
| --- | --- | --- |
| [Task contract](../task.md) | Approval, ownership, constraints and criteria | Authority |
| [Operating instructions](../../../../agent-framework/canonical/operating-instructions.md) | Mandatory rules; retain confirmed context | Execution gates |

## Process

1. Confirm the user-authorized outcome and base revision in task.md.
2. Inspect only affected sources and identify unknowns, acceptance criteria and checks.
3. Record requirement/source links and open questions in output/scope.md.
4. Resolve material scope ambiguity before downstream implementation.

## Outputs

`output/scope.md`: Markdown with requirement links, affected components, observed gaps,
criterion IDs and unresolved questions. Link to task.md rather than duplicating its contract.

## Audit

| Check | Pass condition |
| --- | --- |
| Authorization | Every proposed change is covered by task.md; no Candidate silently promoted. |
| Evidence | Observations identify inspected files/revisions; unknowns remain explicit. |

## Checkpoints

If scope is materially ambiguous, present the bounded question to the owner. Existing
authorization is sufficient for routine choices; see the operating instructions.

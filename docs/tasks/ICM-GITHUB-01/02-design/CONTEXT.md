# Plan the bounded change

Purpose: one delivery stage; task.md selects applicability.

## Inputs

| Source | Section / scope | Why |
| --- | --- | --- |
| [Task contract](../task.md) | Constraints, ownership and criteria | Authority |
| [Scope handoff](../01-scope/output) | scope.md, or explicit replacement in task.md | Observed problem |
| [Decision links](../decisions.md) | Only decisions affecting this slice | Durable constraints |

## Process

1. Read the latest scope handoff, including human edits, and affected authoritative references.
2. Define the smallest end-to-end change and relevant failure/recovery paths.
3. Record required ADR/UX decisions in their established homes; link from decisions.md.
4. Write output/plan.md with criterion-to-change/check mapping and applicable gates.

## Outputs

`output/plan.md`: Markdown linking approved decisions/specifications, affected paths,
failure paths, validation commands and any decision still pending. Describe outcomes
and boundaries; implementation details belong to the build stage.

## Audit

| Check | Pass condition |
| --- | --- |
| Decisions | Required ADR/design decisions exist before structural/UI implementation. |
| Coverage | Each criterion has an observable check and each changed boundary an owner. |

## Checkpoints

Present a concrete draft when product direction or an unresolved architecture decision
requires human steering. Routine implementation/design choices use existing authorization;
apply the selected workflow's human and independent gates.

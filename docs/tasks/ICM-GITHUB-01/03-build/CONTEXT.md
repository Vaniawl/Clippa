# Implement the planned slice

Purpose: one delivery stage; task.md selects applicability.

## Inputs

| Source | Section / scope | Why |
| --- | --- | --- |
| [Task contract](../task.md) | Owned files, constraints and criteria | Write boundary |
| [Design handoff](../02-design/output) | plan.md, or explicit replacement in task.md | Implementation contract |
| [Decision links](../decisions.md) | Affected ADR/specification only | Canonical references |

## Process

1. Read the latest plan, including human edits; inspect only affected symbols and tests.
2. Implement the scoped slice and failure paths using the applicable workflow/methods.
3. Run focused checks; fix failures without expanding scope.
4. Write output/changes.md and record actual commands/results in evidence.md.

## Outputs

Owned source/test/document changes stay in their established homes.
`output/changes.md`: Markdown linking changed paths, criterion IDs, current revision/diff,
focused evidence entries and remaining risks. Do not copy full code or command logs here.

## Audit

| Check | Pass condition |
| --- | --- |
| Ownership | Diff stays inside task.md ownership and preserves approved boundaries. |
| Behavior | Focused success/failure checks pass or their exact unresolved failure is recorded. |

## Checkpoints

Use the selected workflow's gates; do not add a pause to each routine edit. Return to
design/scope when a material decision or scope expansion is needed.

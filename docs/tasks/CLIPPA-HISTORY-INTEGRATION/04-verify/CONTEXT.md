# Verify and hand over the result

Purpose: one delivery stage; task.md selects applicability.

## Inputs

| Source | Section / scope | Why |
| --- | --- | --- |
| [Task contract](../task.md) | Criteria, checks and stopping condition | Definition of done |
| [Build handoff](../03-build/output) | changes.md, or explicit replacement in task.md | Actual change |
| [Evidence ledger](../evidence.md) | Current revision commands/results only | Verification |
| [Decision links](../decisions.md) | Affected decisions only | Conformance |

## Process

1. Verify the handoff against the actual diff and run the applicable broader gates.
2. Obtain required independent review; return findings to the responsible stage and recheck.
3. Map every criterion to actual evidence; identify skipped, failed and unavailable checks.
4. Write output/verification.md; update evidence.md and handover.md with revision and next action.

## Outputs

`output/verification.md`: Markdown with criterion verdicts, evidence/review links, tested
and reviewed revisions, limitations and completion/blocker status. evidence.md owns command
results; handover.md owns current resumable state. No file-presence-only completion claim.

## Audit

| Check | Pass condition |
| --- | --- |
| Evidence | Every criterion has current evidence or an explicit unresolved status. |
| Review | Required independent findings are resolved and the corrected revision checked. |
| Handover | Revision, status, limitations and one concrete next action are recorded. |

## Checkpoints

External delivery and unresolved scope/architecture decisions use existing authorization
rules. Do not convert an unavailable test or review into a pass.

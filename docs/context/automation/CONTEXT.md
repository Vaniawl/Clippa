# Repository automation context

## Inputs

| Source | Section / scope | Why |
| --- | --- | --- |
| [GitHub workflows](../../../.github) | Affected workflow/job only | Hosted commands and permissions |
| [Project](../../../PROJECT.md) | Approved outcome only | Scope |

## Process

Inspect the existing job and invoked scripts. Preserve project branch/review policy.
Run applicable local checks before delivery and inspect actual hosted results separately.
Unavailable hosted jobs remain NOT RUN; billing or access limits are not test passes.

## Outputs

Authorized automation changes, command evidence and revision-specific delivery status
in the active task. Existing CI is project-owned, independent of template scaffolding.

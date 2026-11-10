# History panel and template integration

The owner asked to soften the clipped scroll edges, show the result, and bring the template version and the preceding background optimizations into the latest main branch.

- Execute the macOS feature delivery workflow using all four stages.
- Base the change on main at `4d86475` and the template implementation at `95ddd0e`.
- Limit ownership to the macOS target, its tests and localizations, the affected README and ADR, and the task records. Keep iOS, sync, and release configuration outside this change.

## Acceptance

1. Scrolled history softens only the edges that clip content. Increased contrast and reduced transparency preserve ordinary scroll presentation.
2. New Template, editing, local encrypted persistence and quick paste work through the existing panel.
3. Hiding the status item keeps capture and access to settings available. Encrypted images resolve on demand and remain recoverable during undo.
4. Verify the native build, functional tests, independent review, rendered panel and GitHub checks.

## Stopping condition

The verified integration reaches main, or a concrete merge blocker and next step are recorded.

# Task contract

- ID: ICM-GITHUB-01
- Mode: execute
- Approval: owner request 2026-10-14 to apply the current template/ICM foundation to all GitHub Apple apps, explicitly including macOS.
- Objective: preserve Clippa while adopting reusable ICM routing/task contracts.
- Base revision: 56ae8ee0a922b9ea74077236fd7cabee6d2c7ba9, GitHub default main.
- Selected workflow: direct framework adoption; guarded current-source foundation installation.
- Selected stages: 01-scope, 02-design, 03-build, 04-verify.
- Owned files: shared framework/generated provider outputs and provenance; root/context maps, docs/context/**, this task; focused ICM regression tests. Source-home or compatibility edits are explicitly recorded in evidence.
- Prohibited: native app/assets/targets/dependencies, existing product docs, identity/signing, CI/build scripts, custom provider restrictions and original local worktrees.
- Inputs: actual repository instructions, committed ios-starter e6e2e3d, guarded plan and preservation hashes.

## Acceptance criteria

1. Existing application/product/CI/provider policy remains preserved.
2. Root/component contexts and numbered editable task stages are reachable.
3. Actual validation/drift/context mutation checks pass before independent review/publication.
4. GitHub update follows this project's existing delivery policy with remote revision evidence.

## Validation commands

- python3 scripts/agent-framework/validate.py
- python3 scripts/agent-framework/check-drift.py
- python3 -m unittest -v tests/agent-framework/test_icm_workspace.py
- Focused existing context/preservation suites as supported by this framework variant.
- git diff --check; before/after preservation hashes; remote ref verification.

## Stopping condition

Complete scoped foundation delivery with evidence, or record a precise external delivery blocker.
Native/live-provider execution is N/A: no application behavior change is part of this task.

# Task contract

- ID: <task-id>
- Mode: <advise | execute; inherit the user's authorization>
- Approved outcome: <quote/link to the user's instruction and relevant requirement>
- Objective: <one bounded result>
- Constraints/non-goals: <scope and product/platform constraints>
- Base revision: <commit and working-diff digest>
- Selected workflow: <repository-relative path to its CONTEXT.md, or direct framework task>
- Selected stages: <01-scope, 02-design, 03-build, 04-verify; explain omissions and replacement inputs>
- Inputs: <only relevant files/sections>
- Owned files: <explicit paths/globs, including this task's artifacts>
- Prohibited files: <everything outside ownership; include specific sensitive paths>
- Required capabilities: <actual tools/access; state unavailable capabilities>

## Acceptance criteria

1. <observable result and how to verify it>

## Validation commands

- <exact command; required checks must not be stubs>

## Stopping condition

<Complete the approved outcome with evidence, or return a classified blocker and next action.>

Delegated work additionally uses the canonical agent-task-contract fields; this folder
does not grant a role new authority or replace a bounded delegation contract.

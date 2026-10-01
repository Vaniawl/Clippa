# Agent Task Contract

Every delegated task uses this structure. A delegation missing `owned_files` or `stopping_condition` is invalid and must be rejected by the receiving agent.

```yaml
task:
  mode: advise             # advise | execute; inherits current authorization
  approved_outcome: ""     # link or quoted owner-approved result
  product_constraints: []  # scope, audience, non-goals, platform constraints
  required_capabilities: [] # actual tools/access needed; unavailable is a blocker
  dependencies: []         # task IDs and completion requirements
  base_revision: ""        # starting commit plus dirty-diff digest if needed
  review_revision: ""      # revision/diff digest actually reviewed
  retry_limit: 2           # identical failures require a new approach or blocker
  objective: ""            # one sentence, outcome-oriented
  context: ""              # links/paths to required background; not a repo dump
  role: ""                 # role id from the role catalog
  skills: []               # only skills relevant to this task
  owned_files: []          # files/globs this task may create or modify
  prohibited_files: []     # explicitly off-limits (defaults: everything not owned)
  expected_output: ""      # artifact type and location (report, diff, file set)
  acceptance_criteria: []  # objectively checkable statements
  validation_commands: []  # commands the agent runs and reports with output
  stopping_condition: ""   # when the agent must stop, even if unfinished
  task_weight: ""          # trivial | light | standard | heavy
  model_class: ""          # legacy metadata only; model inherits user settings
  may_delegate: false      # subagent delegation allowed only if true
```

## Rules

- Read-only roles receive `owned_files: []` and never write repository files. A writable reports-only role in authorized execute mode may own exactly the report/coordination path named in `expected_output`, subject to the role's prohibitions. The coordinator may save read-only recommendations directly when authorized; use technical-writer only when its responsibility is needed.
- `validation_commands` are the completion test. The agent runs them and reports actual output per the evidence policy; the orchestrator re-runs or cites them at integration.
- Work outside `owned_files` is a scope violation: stop, report, and file the proposal as a backlog candidate.
- If acceptance criteria cannot be met within the stopping condition, the agent returns a handover (see handover contract) rather than a partial success claim.

- Advice mode forbids tracked-file writes even for a normally write-capable role.
- Revision evidence includes commit plus diff digest when changes are uncommitted.

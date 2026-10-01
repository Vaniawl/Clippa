# Delegation Policy

Canonical source: `agent-framework/canonical/policies/delegation-policy.md`.

## When to delegate

For projects with team configuration, use the smaller of three workers, `max_parallel_workers`, and host capacity, plus one coordinator. Missing settings preserve legacy provider concurrency behavior. Delegate when work is genuinely independent and the delegation overhead is smaller than the work. Avoid unnecessary fan-out for trivial edits: the coordinator may issue one bounded writer task. Do not delegate work whose scope is still materially ambiguous or which requires unresolved coordinator context.

## Task definition

Every delegated task MUST be expressed using the agent task contract (`agent-framework/canonical/contracts/agent-task-contract.md`): objective, context, owned files/component, prohibited files, expected output, acceptance criteria, validation commands, stopping condition. A delegation without owned files and a stopping condition is invalid.

## Ownership and isolation

- Parallel writers must own non-overlapping file sets, or work in separate Git worktrees (`scripts/create-worktree.sh`).
- Read-only roles (reviewers, researchers, personas, rubber-duck) never edit files. If a read-only role concludes an edit is needed, it reports the finding; the orchestrator assigns it to a writer role.
- `write_ownership: reports-only` permits only the report/coordination artifact named in `expected_output`, when execute mode authorizes saving and the role explicitly permits writing. `read_only: true` forbids all repository writes; return the report in conversation or assign saving to technical-writer. Role prohibitions take precedence over this ownership label.
- No unbounded recursive delegation: a subagent may delegate only when its task contract explicitly permits it.
- Avoid duplicate whole-repository investigations; scope each investigator to a distinct area or question.

## Role selection

- Use the role catalog (`agent-framework/catalogs/role-catalog.yaml`). Select only roles the current task needs; most tasks need one or two.
- A persistent role is justified only by: different tool permissions, different decision role, isolated context, different output contract, or different review responsibility. Technology expertise is a skill, not a role.
- Load only domain skills relevant to the task's technology. Do not preload the whole domain catalogue.

## Model inheritance

Inherit user model and reasoning settings. `model_class` and `fallback_model_class` remain
legacy descriptive metadata for schema compatibility, not runtime selection instructions.
Never automatically downgrade or replace the user's model. Preserve local user overrides.

## Severity ladder

Every reviewer role's findings are rated on one canonical severity ladder: **Blocking** (must be fixed before the change proceeds) / **Important** (should be fixed; does not by itself block) / **Optional** (worth doing, no urgency). Reviewer role outputs reference these three terms verbatim. This ladder rates severity only; skeptical-reviewer additionally uses CONFIRMED / REFUTED / UNVERIFIABLE as claim verdicts, which are orthogonal to severity.

## Integration

- Integrate frequently; no long-lived divergent agent branches.
- The orchestrator reviews every subagent result against the task's acceptance criteria before integrating. A subagent's own claim of success is not sufficient (see evidence policy).

## Revision and evidence

Ownership is a task contract plus inspection of the actual diff; it is not a filesystem sandbox
unless the provider enforces one. Serialize builds/native tests in a checkout or use distinct
scratch directories. Review tasks receive requirements, acceptance criteria, diff, tested revision
and raw evidence; implementer conclusions are hypotheses. Findings return to the assigned writer.
Review again at the corrected revision. Resolve Blocking findings; fix Important findings or record
an explicit rationale and residual-risk decision. Architect resolves structural conflicts; PM
routes changes to approved product outcomes to the owner. Do not repeat entire repository audits
when scoped context is sufficient.

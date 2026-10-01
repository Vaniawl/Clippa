---
name: apple-team
description: Coordinate an Apple product request through discovery, design, implementation, review, or marketing using bounded role contracts. Use at the main coordinator entrypoint; specialists load their own domain skills.
---

# Apple Team

## Trigger and inputs
Use when coordinating a natural-language iOS/macOS product request. Read PROJECT, product vision, the relevant BACKLOG item, ADRs and latest handover; check their revision against the checkout. Inputs are the request, approved outcome (if any), product constraints and available runtime capabilities. Inspect repository facts before asking questions. Batch independent context reads and revision/status/diff checks; retain already confirmed context instead of reloading it. Specialists load their task methods; the coordinator reads role authority and selects methods without duplicating a specialist’s full domain audit.

## Select the mode and route
Use `agent_framework.team.default_mode` when present. New starters default to `advise`; absent settings preserve legacy policy. An explicit request to implement, fix, or execute an agreed result authorizes `execute` for that outcome. Advice returns in the conversation and changes no tracked product files; saving a recommendation requires an explicit request or agreed execution scope.

Read [routing.md](references/routing.md) for the task's route. Give one recommended result; show alternatives only for a material tradeoff. Bundle unresolved product questions. Do not add analytics, subscriptions, onboarding or a backend merely to fill a checklist.

## Coordinate execution
Inspect actual delegation tool fields before selecting native named agents. If no named-role
selector exists but spawning is available, load the selected canonical role instructions and
relevant skills explicitly into the task payload and spawn/wait for a real worker. This is a
role-contract adapter: normalize task names to the host grammar (for example hyphens to underscores), while keeping the canonical role ID in the task. Disclose native named discovery as unavailable/unverified. If spawning
is unavailable, report the exact capability blocker and continue independent available work.
Use the canonical task contract and evidence policy instead of repeating them here. Read the selected canonical role before issuing or presenting its contract; validate its write authority first. A worktree resolves file overlap, not role permissions: designer owns UX documents/resources, while product-code edits go to the engineer. Pass only relevant context, required skills, dependencies, approved result, capability requirements, base revision, owned/prohibited files and retry limit. Specialists cannot delegate by default. Use at most three concurrent workers, or the configured/environment lower limit. Inherit the user's model; role model-class fields are legacy metadata, not permission to downgrade it.

Inspect the actual diff against ownership; file ownership is a contract, not a provider sandbox. Parallel writers need disjoint files or worktrees. Serialize native builds/tests in one checkout or assign separate scratch directories. Independent reviewers get the task, criteria, diff, revision and raw evidence, with author conclusions labeled as claims. Return findings to the responsible writer, then review the revised change. Resolve Blocking findings; fix Important findings or record an explicit rationale and residual-risk decision. Architecture conflicts go to the architect; product-direction changes go through PM and the owner.

After approval, run implementation, review, tests, corrections and relevant documentation without asking again for these steps. Stop at the agreed outcome; do not consume the whole backlog. After two identical failures change the hypothesis or return the precise blocker, while continuing independent work. External delivery, a direction change or necessary scope expansion requires its own authorization under repository policy.

## Output and verification
Return a team summary: outcome, recommendation or changed behavior, participating roles, criteria linked to evidence, unresolved risks and NOT RUN checks. Distinguish generated configuration, preflight capability and live execution evidence. During approved execution maintain a compact handover with goal, mode, decisions, revision, completed evidence, blockers and next step; raw logs remain in ignored artifacts. On resume verify revision and continue from the last evidenced state.

Stop when the requested recommendation or bounded execution is complete, or when further dependent work requires a specific missing decision/access. Never claim success from a role's narrative alone.

---
name: apple-team
description: Handle Apple product requests through one coordinator; invoke specialists only for needed expertise, useful independent work or independent review.
---

# Apple Team

Use when handling natural-language Apple product requests. Read only task-relevant PROJECT/vision,
approved BACKLOG, ADRs, test strategy or threat model; on resume verify the relevant handover
and checkout revision. Framework-only work skips Apple-domain audits. Retain confirmed context.

## Work directly; delegate when needed

The main coordinator handles the request itself by default. Zero subagents is a valid route
for advice and authorized implementation. Load the domain methods needed for your actual
work; consult [routing.md](references/routing.md) when a specialist responsibility is needed.
Do not load every role, skill or lifecycle stage to decide a simple request.

Invoke specialists only for a concrete expertise gap, useful independent parallel work,
risk-required independent review, or explicit user delegation. Record one short reason for
an invoked role. Significant/risky changes require independent review under the
[delegation policy](../../policies/delegation-policy.md); author self-checks are not independent.
Low-risk edits and contained recommendations may finish directly with relevant evidence.

When delegating, read the selected role's authority and use the
[task contract](../../contracts/agent-task-contract.md) with only relevant context and methods.
Use actual native role selection when exposed, or explicitly pass role instructions to real
spawn/wait tools and disclose the role-contract adapter. Missing required delegation is a
blocker for that gate; continue independent work without inventing a completed review.
Ownership is verified through the diff. Writers have disjoint files/worktrees; serialize
native builds in one checkout. Inherit the user's model and reasoning; at most three workers
or the lower project/host limit, with specialist subdelegation disabled by default.

## Authorization and completion

Use configured advise/execute mode; explicit implementation requests authorize execute for
that outcome. Advice writes no tracked product files. Direct implementation obeys the same
scope, relevant Apple methods, failure-path checks and evidence obligations as a worker.
Complete the approved outcome through applicable checks, needed review, corrections and docs;
stop at that outcome. Product direction, scope expansion and external actions retain their
approval boundaries. After two identical failures change the approach or state the blocker.

Return the result, relevant evidence and material unknowns. Mention participating specialists
when any were invoked; do not create an empty-team report or list unrelated stages. During
execution keep a compact handover when continuity needs it; raw logs stay ignored. Separate
structural/preflight evidence from live execution; NOT RUN remains explicit.

For actual Codex/OpenAI questions use installed openai-docs when available; for SwiftUI code
review use installed swiftui-pro when available. These optional methods need no global
installation and grant no extra permissions. Never infer tool access from a role's tool list.

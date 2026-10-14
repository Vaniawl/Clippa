---
id: apple-data-commerce-change
title: Apple Data or Commerce Change
description: Verify approved persistence, sync or StoreKit changes with compatibility, transaction invariants
  and supported recovery.
roles:
- orchestrator
- software-architect
- data-database-engineer
- integration-architect
- implementation-engineer
- qa-test-engineer
- code-reviewer
- security-privacy-reviewer
entry_criteria:
- The user requests this bounded outcome; execution is limited to authorized scope.
exit_criteria:
- The relevant branch has verified invariants, compatibility and supported recovery plus resolved independent
  gates or explicit limitations.
---

# Apple Data or Commerce Change

Roles below define responsibility, not mandatory agent calls. The coordinator may work
directly; significant/risky changes retain independent review under the delegation policy.
Use available task-relevant methods only and respect each role's write ownership.

1. Choose the applicable persistence or commerce branch; do not require both. Confirm the approved data/entitlement rules, architecture and supported client/model versions.
2. Persistence: specify schema versions, forward migration, isolation, offline/conflict/delete semantics and recovery. CloudKit production schema cannot be treated as reversible development changes.
3. Commerce: specify verified entitlement transitions, transaction lifetime, cancellation/pending, idempotent delivery, restore/revocation/refund and environment. Server/API notifications apply only if that boundary exists.
4. Builders implement owned files. Test fresh/upgrade or purchase/restore paths and meaningful interrupted/duplicate/offline/failure cases with synthetic data/local configuration and available sandbox evidence.
5. Require independent code review and relevant security review for sensitive trust/entitlement changes. Review compatibility/recovery evidence on the actual candidate, including supported old clients.
6. Report tested versus written recovery, irreversible constraints and missing sandbox/device access. Shared/production destructive migrations or live purchases/pricing changes need explicit authorization; this workflow does not grant it.

Handoff: objective, candidate/data identity, artifacts and actual commands/results, unresolved
gates with owner and next action. NOT RUN/UNKNOWN never becomes PASS by omission.

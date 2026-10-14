---
id: apple-incident-response
title: Apple Incident Response
description: Triage supplied Apple runtime/support evidence, reproduce, contain within authorized scope
  and verify a corrected candidate.
roles:
- orchestrator
- customer-support-specialist
- performance-reliability-engineer
- qa-test-engineer
- implementation-engineer
- data-database-engineer
- security-privacy-reviewer
- code-reviewer
- devops-release-engineer
- app-store-release-manager
entry_criteria:
- The user requests this bounded outcome; execution is limited to authorized scope.
exit_criteria:
- Triage, corrected-candidate evidence or a precise blocker, recovery status and follow-up are delivered
  without unsupported production-resolution claims.
---

# Apple Incident Response

Roles below define responsibility, not mandatory agent calls. The coordinator may work
directly; significant/risky changes retain independent review under the delegation policy.
Use available task-relevant methods only and respect each role's write ownership.

1. Coordinator establishes actual impact/severity, affected build/device/cohort and available sanitized evidence. Support responsibility drafts responses and reproduction details; no automatic contact.
2. Diagnose with matching symbols, reproducible workload and supplied metrics/logs. Separate source hypotheses, measured local behavior and observed field evidence; missing data stays UNKNOWN.
3. Select supported containment and owner. External rollout changes, user contact and destructive data operations retain their authorization boundaries; do not invent an app kill switch.
4. Assigned builder fixes the root cause within scope. QA provides a meaningful failing-then-passing regression when feasible; performance changes use equivalent before/after workload.
5. Apply independent risk review to the corrected revision and repeat relevant checks. For delivery use the App Store workflow; a local fix is not a production resolution.
6. Record timeline, impact, evidence, residual risk and follow-up/runbook. Stop at the authorized incident outcome, preserving explicitly unperformed communication/delivery.

Handoff: objective, candidate/data identity, artifacts and actual commands/results, unresolved
gates with owner and next action. NOT RUN/UNKNOWN never becomes PASS by omission.

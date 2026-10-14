---
id: app-store-delivery
title: App Store Delivery
description: Prepare candidate-specific Apple signing, beta/store metadata, declarations, review and rollout
  readiness.
roles:
- orchestrator
- devops-release-engineer
- app-store-release-manager
- qa-test-engineer
- security-privacy-reviewer
- accessibility-reviewer
- localization-specialist
- brand-creative-designer
- product-marketing-strategist
entry_criteria:
- The user requests this bounded outcome; execution is limited to authorized scope.
exit_criteria:
- A candidate-specific readiness verdict, evidence, conditions/owners and actual external-action status
  are delivered.
---

# App Store Delivery

Roles below define responsibility, not mandatory agent calls. The coordinator may work
directly; significant/risky changes retain independent review under the delegation policy.
Use available task-relevant methods only and respect each role's write ownership.

1. Coordinator identifies version/build/revision, distribution route and scope. Initialize a fresh release checklist from the template; historical starter reports do not apply.
2. DevOps responsibility covers recorded toolchain, CI, tests, archive/export, signing/entitlements and matching symbols. Simulator compilation cannot establish signed distribution readiness.
3. Release-manager responsibility assembles the dossier, actual metadata/URLs, TestFlight/App Review inputs, privacy/SDK/required-reason and applicable age/export/territory declarations. Human owners decide account agreements/financial matters.
4. Use localization/creative/marketing expertise only where needed. Claims and captured assets match the shipping candidate; accessibility claims reflect actual tested tasks/devices.
5. Apply release-readiness to evidence and unknowns. Confirm current SDK/submission requirements; do not raise minimum supported OS from an SDK rule alone.
6. Upload, submission, user messaging and availability changes occur only when separately explicitly authorized and tools/access exist. Otherwise deliver a local readiness dossier with external actions NOT RUN. Readiness is not release approval.
7. For an authorized rollout specify monitoring, owner, supported containment and corrected-version delivery. Phased rollout pause does not reverse installed updates.

Handoff: objective, candidate/data identity, artifacts and actual commands/results, unresolved
gates with owner and next action. NOT RUN/UNKNOWN never becomes PASS by omission.

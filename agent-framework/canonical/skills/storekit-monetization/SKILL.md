---
name: storekit-monetization
description: Use when implementing or reviewing approved Apple in-app purchases, subscription entitlements and StoreKit tests.
---

# StoreKit monetization

Read the approved commercial model, product identifiers, entitlement rules and supported
platforms. Use [transactions.md](references/transactions.md) for purchase/restore/server work.
Do not add subscriptions, paywalls or a server merely because this method is available.

Keep displayed offers truthful and localized; model pending, cancellation, failure, refund and
expiry independently from successful purchase. Verify transaction/entitlement evidence before
granting access. Deliver a tested entitlement state machine and precise test environment;
Xcode configuration tests alone do not establish sandbox or production integration.

## Research when needed

Use supplied/local primary sources or actually available web/docs tools permitted by the role
and task. If the active role lacks the `web` tool or access and local evidence is insufficient,
request a deep-researcher task via the orchestrator when available, or mark the claim UNKNOWN
and continue independent work. Do not infer access from a catalog or simulate source verification.

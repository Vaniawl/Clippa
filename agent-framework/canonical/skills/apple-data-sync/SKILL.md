---
name: apple-data-sync
description: Use when designing or verifying SwiftData, Core Data or CloudKit persistence, migrations and offline sync in an Apple app.
---

# Apple data and sync

Read the approved persistence decision, actual model history and minimum supported versions.
Use [migration-and-sync.md](references/migration-and-sync.md) for migration, account/sync or
recovery work. Preserve the established storage technology; this method adds no database.

Specify source of truth, identity, isolation, delete/conflict semantics and supported old
clients. Test forward upgrades and interrupted/error paths with synthetic representative data.
Select a technology-supported recovery strategy rather than demanding universal reversal.
Return changed model versions, compatibility matrix, commands/results and recovery evidence.
Shared/production destructive operations retain explicit authorization requirements.

## Research when needed

Use supplied/local primary sources or actually available web/docs tools permitted by the role
and task. If the active role lacks the `web` tool or access and local evidence is insufficient,
request a deep-researcher task via the orchestrator when available, or mark the claim UNKNOWN
and continue independent work. Do not infer access from a catalog or simulate source verification.

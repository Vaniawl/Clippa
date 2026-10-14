---
name: apple-signing-distribution
description: Use when preparing reproducible Apple archives, signing and CI, TestFlight or App Store distribution evidence without automatic delivery.
---

# Apple signing and distribution

Identify the actual schemes/targets, distribution route, deployment targets, Xcode/SDK and
available account access. Use [delivery.md](references/delivery.md) for archive/signing/release
preparation. Keep signing material out of source and logs; use the project's established CI.

DevOps owns build/signing automation; the release manager owns the version-specific store
dossier. Preparation does not authorize upload, submission or availability changes. Return
artifact identity, build/export evidence, symbol handling and remaining access/review gates.

## Research when needed

Use supplied/local primary sources or actually available web/docs tools permitted by the role
and task. If the active role lacks the `web` tool or access and local evidence is insufficient,
request a deep-researcher task via the orchestrator when available, or mark the claim UNKNOWN
and continue independent work. Do not infer access from a catalog or simulate source verification.

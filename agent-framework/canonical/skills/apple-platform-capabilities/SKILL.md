---
name: apple-platform-capabilities
description: Use when designing or verifying approved Apple notifications, background work, deep links, extensions, widgets, Live Activities or App Intents.
---

# Apple platform capabilities

Inspect the approved capability, target OS/devices, entitlements and user journey. Load only
the matching reference: [notifications and background](references/notifications-background.md),
[links and extensions](references/links-extensions.md),
[widgets, activities and intents](references/widgets-intents.md), or
[specialized frameworks](references/specialized-frameworks.md).

Specify permissions, lifecycle, shared-state isolation and unavailable/denied behavior.
Validate actual device/service prerequisites; a configured entitlement is not working runtime
evidence. Do not add capabilities, services or dependencies because they are in this catalog.

## Research when needed

Use supplied/local primary sources or actually available web/docs tools permitted by the role
and task. If the active role lacks the `web` tool or access and local evidence is insufficient,
request a deep-researcher task via the orchestrator when available, or mark the claim UNKNOWN
and continue independent work. Do not infer access from a catalog or simulate source verification.

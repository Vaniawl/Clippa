# Widgets, Live Activities and App Intents

- WidgetKit timelines/reload requests obey system budgets. Choose a snapshot/data source, placeholder
  and meaningful stale/offline behavior; do not promise arbitrary refresh frequency.
- ActivityKit state, lifecycle and push updates are separate from widgets. Handle start/update/end,
  expiry, permission/unavailable conditions and sensitive lock-screen content. Verify current API/OS
  support and device constraints before promising a surface or update path.
- App Intents exposes user actions beyond the app UI. Specify parameter validation, authorization,
  confirmation where actually needed, supported execution contexts and discoverability. Avoid leaking
  protected state in summaries or using an intent as an authorization bypass.
- Reuse domain logic and approved shared-state boundaries. Test supported sizes/surfaces, cold state,
  unavailable data and actual device interactions; source configuration alone proves no runtime path.

Sources: [WidgetKit](https://developer.apple.com/documentation/widgetkit),
[ActivityKit](https://developer.apple.com/documentation/activitykit),
[App Intents](https://developer.apple.com/documentation/appintents).
Applicability: [source registry](../../../references/apple-source-registry.md).

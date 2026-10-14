# Notifications and background execution

- Distinguish local notifications from remote APNs; specify token/account association, environment,
  rotation, payload minimization and server authorization when relevant. Request permission in a
  meaningful user context and support denied/revoked permission without blocking unrelated tasks.
- Define routing from notification actions into existing navigation and validate external payloads.
  Handle duplicate delivery and cold/warm launch. Service/content extensions have separate resource
  and lifecycle constraints; do not assume main-app state exists there.
- BackgroundTasks execution is system-scheduled, not an exact timer or guaranteed daemon. Register
  appropriate tasks, handle expiration/cancellation, persist resumable progress and verify allowed
  modes. A simulated trigger proves that test condition, not real scheduling reliability.
- Test device permission states and foreground/background/terminated cases supported by the actual
  capability; identify unavailable APNs/server/device access as NOT RUN.

Sources: [UserNotifications](https://developer.apple.com/documentation/usernotifications),
[BackgroundTasks](https://developer.apple.com/documentation/backgroundtasks).
Applicability: [source registry](../../../references/apple-source-registry.md).

# Diagnostics and incident measurement

- Retain version/build, symbol UUID association, device/OS, timestamps, scenario and sample coverage.
  Symbolicate crash/hang evidence with matching symbols; do not infer causality from a stack alone.
- Separate cold/warm launch, foreground/resume, hangs, watchdog termination, memory pressure and
  crashes. Use Instruments/Xcode tools appropriate to the hypothesis; compare equivalent workload,
  device, build configuration and environment. Simulator energy/timing is not device proof.
- MetricKit provides on-device metrics/diagnostics subject to framework delivery/availability.
  Record the actual collection window and sample; absence of a delivered report proves no result.
- Measure before optimizing. Check retained tasks/subscriptions, actor/main-thread work, disk/net
  activity and battery cost. Set a product-appropriate regression threshold; avoid invented universal
  performance budgets and repeated runs without a reason.
- Incidents: severity and affected cohorts, safe reproduction, supported containment, responsible
  author, corrected-candidate checks and follow-up. Do not delete production data or publish a fix
  from a diagnostic task. Record which monitoring remains unavailable.
- Sanitize logs/support exports and redact credentials, personal data and account identifiers.
  Do not commit customer payloads. Specify access/retention only for actual approved collection.

Source: [MetricKit](https://developer.apple.com/documentation/metrickit).
Applicability: [source registry](../../../references/apple-source-registry.md).

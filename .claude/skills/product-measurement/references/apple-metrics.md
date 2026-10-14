# Apple metrics and attribution

- Identify App Analytics, Sales and Trends, financial reports, server events or supplied exports.
  Usage reporting coverage/consent and privacy thresholds differ from transaction reporting;
  sales/estimated proceeds differ from settled financial proceeds. Preserve source time zones,
  currencies, reporting windows, refunds and adjustments.
- Define funnel, activation and retention with cohort/denominator and data availability. Downloads
  are not active users. Analyze subscription churn/grace/refunds only from applicable data; avoid
  summing repeated entitlement notifications as independent purchases.
- CAC needs actual attributable acquisition cost and a defensible acquired-customer denominator.
  LTV needs observed horizon/assumptions, net revenue treatment and uncertainty; modeled future
  value is not measured revenue. Missing channel spend or cohort data leaves the result UNKNOWN.
- Distinguish AdServices campaign attribution, privacy-preserving AdAttributionKit and actual
  cross-app tracking/ATT requirements. Follow current first-party documentation for supported
  identifiers/windows; do not imply that every dataset can be joined at user level.
- Check sample, missingness, allocation, exposure contamination, confounders and practical effect.
  Aggregate/manual measurement may suffice; an analysis task never silently installs an SDK.
  Return reproducible local calculations and sanitized inputs or exact source pointers.

Sources: [reporting tools](https://developer.apple.com/help/app-store-connect/measure-app-performance/overview-of-reporting-tools),
[AdServices](https://developer.apple.com/documentation/adservices),
[AdAttributionKit](https://developer.apple.com/documentation/adattributionkit),
[ATT](https://developer.apple.com/documentation/apptrackingtransparency).
Applicability: [source registry](../../../../agent-framework/canonical/references/apple-source-registry.md).

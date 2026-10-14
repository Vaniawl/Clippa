# Apple team primary-source registry

Review baseline: 2026-10-03. Dates below are retrieval/review dates, not publication dates.
This is a maintained index of first-party procedures and standards, not a copied manual or
a claim that every SDK has been audited. `Reviewed` means the relevant guidance informed this
team update; `Indexed` means a primary reference is provided and task-specific verification
is still required. Apple JS-only documentation can be read through its official Markdown/JSON
representation; a successful HTTP response alone is not content verification.

Before relying on time-sensitive facts, check the current source and installed SDK, record
the relevant section/version and update its date. Recheck on toolchain/provider upgrades,
new capabilities, privacy/SDK changes and before submission or a marketing experiment.
Framework-only maintenance does not require reading this entire registry. The deep-researcher
maintains source evidence; the named domain owner interprets applicability for the task.

| Topic / primary references | Responsible role | Methods / applicability | State / checked |
| --- | --- | --- | --- |
| [SwiftUI](https://developer.apple.com/documentation/swiftui), [Swift concurrency migration](https://www.swift.org/migration/documentation/swift-6-concurrency-migration-guide/migrationstrategy/) | software-architect, implementation-engineer | ios-development; target/toolchain-specific isolation and availability | Reviewed / 2026-10-03 |
| [Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/) | ui-ux-designer | apple-experience-design; native interaction and adaptive surfaces | Reviewed / 2026-10-03 |
| [Swift Testing](https://developer.apple.com/documentation/testing), [XCTest](https://developer.apple.com/documentation/xctest) | qa-test-engineer | ios-testing; unit versus UI/performance evidence | Reviewed / 2026-10-03 |
| [Accessibility audits](https://developer.apple.com/documentation/xcuiautomation/xcuiapplication/performaccessibilityaudit(for:_:)), [Accessibility Nutrition Labels](https://developer.apple.com/help/app-store-connect/manage-app-accessibility/overview-of-accessibility-nutrition-labels) | accessibility-reviewer | ios-quality, ui-ux-review; actual tasks/devices, current declaration rules | Reviewed / 2026-10-03 |
| [SwiftData migration](https://developer.apple.com/documentation/swiftdata/schemamigrationplan), [CloudKit production schema](https://developer.apple.com/documentation/cloudkit/deploying-an-icloud-container-s-schema) | data-database-engineer | apple-data-sync; supported forward migration and recovery | Reviewed / 2026-10-03 |
| [Core Data](https://developer.apple.com/documentation/coredata) | data-database-engineer | apple-data-sync; actual store/model/context constraints | Indexed / task-specific review pending |
| [String Catalogs](https://developer.apple.com/documentation/xcode/localizing-and-varying-text-with-a-string-catalog) | localization-specialist | app-localization; plurals, interpolation, RTL/runtime verification | Reviewed / 2026-10-03 |
| [MetricKit](https://developer.apple.com/documentation/metrickit) | performance-reliability-engineer | ios-observability; availability, collection windows and actual diagnostics | Reviewed / 2026-10-03 |
| [Keychain](https://developer.apple.com/documentation/security/keychain-services), [LocalAuthentication](https://developer.apple.com/documentation/localauthentication), [AuthenticationServices](https://developer.apple.com/documentation/authenticationservices) | security-privacy-reviewer | security-review; native credential/auth boundaries | Reviewed / 2026-10-03 |
| [App privacy details](https://developer.apple.com/app-store/app-privacy-details/), [required-reason APIs](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api), [SDK requirements](https://developer.apple.com/support/third-party-SDK-requirements/) | security-privacy-reviewer, app-store-release-manager | security-review, ios-quality; actual app/SDK data flows and declarations | Reviewed / 2026-10-03 |
| [MASVS](https://mas.owasp.org/MASVS/), [MASTG](https://mas.owasp.org/MASTG/) | security-privacy-reviewer | security-review; applicable controls and concrete testing, not blanket certification | Reviewed / 2026-10-03 |
| [StoreKit](https://developer.apple.com/documentation/storekit), [purchase testing](https://developer.apple.com/documentation/storekit/testing-at-all-stages-of-development-with-xcode-and-the-sandbox), [Server API](https://developer.apple.com/documentation/appstoreserverapi), [server notifications](https://developer.apple.com/documentation/appstoreservernotifications) | implementation-engineer, integration-architect | storekit-monetization; entitlement rules, environments and server boundary if present | Reviewed / 2026-10-03 |
| [UserNotifications](https://developer.apple.com/documentation/usernotifications), [BackgroundTasks](https://developer.apple.com/documentation/backgroundtasks) | integration-architect, implementation-engineer | apple-platform-capabilities; permission, delivery and scheduling constraints | Reviewed / 2026-10-03 |
| [WidgetKit](https://developer.apple.com/documentation/widgetkit), [ActivityKit](https://developer.apple.com/documentation/activitykit), [App Intents](https://developer.apple.com/documentation/appintents) | implementation-engineer | apple-platform-capabilities; target/device/surface-specific applicability | Reviewed / 2026-10-03 |
| [Associated domains](https://developer.apple.com/documentation/xcode/supporting-associated-domains), [extensions](https://developer.apple.com/app-extensions/) | integration-architect | apple-platform-capabilities; hosted association, process boundaries and entitlement evidence | Indexed / task-specific review pending |
| [Xcode Cloud](https://developer.apple.com/documentation/xcode/xcode-cloud), [optional fastlane](https://docs.fastlane.tools/getting-started/ios/setup/), [GitHub Actions security](https://docs.github.com/en/actions/reference/security/secure-use) | devops-release-engineer | apple-signing-distribution; use established CI, secrets and reproducible artifacts | Reviewed / 2026-10-03 |
| [TestFlight](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview/), [App Store Connect API](https://developer.apple.com/documentation/appstoreconnectapi), [App Review](https://developer.apple.com/app-store/review/guidelines/), [phased release](https://developer.apple.com/help/app-store-connect/update-your-app/release-a-version-update-in-phases) | app-store-release-manager | apple-signing-distribution, release-readiness; candidate-specific store/delivery gates | Reviewed / 2026-10-03 |
| [Current and upcoming submission requirements](https://developer.apple.com/app-store/submitting/), [April 2026 requirement](https://developer.apple.com/news/upcoming-requirements/?id=04282026a) | devops-release-engineer, app-store-release-manager | apple-signing-distribution; recheck before release; SDK minimum differs from supported OS | Reviewed / 2026-10-03 |
| [Marketing guidelines](https://developer.apple.com/app-store/marketing/guidelines/), [product page optimization](https://developer.apple.com/help/app-store-connect/create-product-page-optimization-tests/overview-of-product-page-optimization/), [custom product pages](https://developer.apple.com/help/app-store-connect/create-custom-product-pages/configure-multiple-product-page-versions), [Apple Ads](https://ads.apple.com/app-store/help) | product-marketing-strategist | app-store-marketing; actual placement requirements, hypothesis and authorized delivery | Reviewed / 2026-10-03 |
| [Screenshots and previews](https://developer.apple.com/help/app-store-connect/manage-app-information/upload-app-previews-and-screenshots/) | brand-creative-designer | marketing-creative-production; verify current asset requirements before export readiness | Indexed / task-specific review pending |
| [Reporting tools](https://developer.apple.com/help/app-store-connect/measure-app-performance/overview-of-reporting-tools), [AdServices](https://developer.apple.com/documentation/adservices), [AdAttributionKit](https://developer.apple.com/documentation/adattributionkit), [ATT](https://developer.apple.com/documentation/apptrackingtransparency) | growth-analyst | product-measurement; data-source coverage, attribution and privacy distinctions | Reviewed / 2026-10-03 |
| [Tester feedback](https://developer.apple.com/help/app-store-connect/test-a-beta-version/view-tester-feedback), [review responses](https://developer.apple.com/help/app-store-connect/monitor-ratings-and-reviews/respond-to-reviews) | user-researcher, customer-support-specialist | user-research, product-copy; real feedback and separately authorized contact | Reviewed / 2026-10-03 |
| [Codex subagents](https://learn.chatgpt.com/docs/agent-configuration/subagents), [AGENTS](https://learn.chatgpt.com/docs/agent-configuration/agents-md), [skills](https://learn.chatgpt.com/docs/build-skills), [agent evals](https://developers.openai.com/api/docs/guides/agent-evals) | orchestrator, framework maintainer | apple-team; actual native selection versus generic role-contract adapter and evidence | Reviewed / 2026-10-03 |
| [Agent Skills specification](https://agentskills.io/specification), [Claude agents](https://code.claude.com/docs/en/sub-agents), [Claude skills](https://code.claude.com/docs/en/skills), [OpenCode agents](https://opencode.ai/docs/agents/), [permissions](https://opencode.ai/docs/permissions/), [Kimi agents](https://moonshotai.github.io/kimi-code/en/customization/agents) | framework maintainer | generation and provider capability matrix; source configuration is not live runtime proof | Reviewed / 2026-10-03 |

## Decisions grounded by these sources

- Use Swift Testing for new unit tests where appropriate; retain XCTest for UI/performance.
- CloudKit production types/fields cannot be treated as reversible development-schema changes.
- App Store phased rollout control is not rollback of installed binaries.
- Accessibility declarations need actual task/device evidence and current rules; do not declare
  them mandatory from historical rollout announcements alone.
- App Analytics coverage/privacy limits, Sales and Trends transactions and financial proceeds
  are different inputs. Attribution and ATT applicability depend on the actual data flow.
- Preserve the starter's iOS 17+/macOS 14+ support unless a product decision changes it; consult
  current SDK submission rules without confusing them with minimum deployment versions.
- Provider-generated files, deterministic checks and a model's observed behavior are separate
  evidence classes. No productivity or runtime-support claim follows from generation alone.

---
name: selenium
description: Author and review Selenium WebDriver browser automation — locator strategies, explicit waits, page objects, Grid execution, and flake control. Use when writing, debugging, migrating, or reviewing Selenium-based test suites.
license: Proprietary
metadata:
  status: complete
  kind: domain
  last-reviewed: "2026-07-18"
---

# Selenium

## Trigger

Load this skill when the task involves: writing or reviewing Selenium WebDriver tests; stabilizing or modernizing an existing Selenium suite; configuring Selenium Grid or driver management; deciding between Selenium and other web-automation stacks.

## Scope

Browser automation with Selenium WebDriver (the W3C WebDriver-standard-based component), test architecture around it (waits, page objects, data handling), and distributed execution with Selenium Grid. Selenium is an umbrella project — WebDriver, Grid, IDE, and Selenium Manager (per official docs, accessed 2026-07-18).

## Non-goals

- Native mobile automation — use the `appium` skill (Appium speaks a WebDriver-derived protocol but is its own project).
- New-project framework selection advocacy; present trade-offs, cite docs.
- Record-and-playback maintenance strategy for Selenium IDE beyond pointing to official docs.

## Official-source policy

Consult first, and prefer current official docs over this file:

- Selenium documentation: https://www.selenium.dev/documentation/ (verified, accessed 2026-07-18; documents WebDriver, Grid, IDE, Selenium Manager, six language bindings).

Use actually available web/docs tools only when permitted by the active role and task, or applicable supplied/local primary sources. A role's permitted_tools list does not provision access or enforce a sandbox; callable tools do not expand authority. If the active role lacks the `web` tool or permission and local evidence is insufficient, request a deep-researcher task via the orchestrator when available, or mark the claim UNKNOWN; do not cite current official-source claims from memory or simulate a lookup.

## Version awareness

Identify the Selenium version and language binding in the project's dependency manifest before advising. The current documented major line at access date is Selenium 4.x (docs homepage labeled v4.0, accessed 2026-07-18); Selenium 4 is W3C-WebDriver-protocol based and 3.x-era idioms (e.g., desired-capabilities patterns) may not apply. Browser/driver compatibility is version-coupled — check the binding's release notes.

## Required citations

API and protocol behavior claims must cite the official Selenium docs (or the W3C WebDriver specification at https://www.w3.org/TR/webdriver/ for protocol-level questions). Locator or wait advice contradicting project conventions should cite both docs and the convention.

## Terminology

Verified terms from official docs: WebDriver, browser driver, Selenium Grid (hub/node roles), Selenium Manager, locator strategies (id, name, CSS selector, XPath, link text, tag name), implicit wait, explicit wait, expected conditions, page object model, stale element reference.

## Common workflows

1. **Locator strategy.** Prefer stable, semantic locators (id, name, well-chosen CSS) over brittle absolute XPath; centralize locators in page objects; treat locator churn as a signal to add stable test hooks in the application.
2. **Waiting discipline.** Use explicit waits with expected conditions for every dynamic interaction; never mix implicit and explicit waits blindly (interaction between them causes unpredictable timeouts — verify current guidance in official docs); unconditional sleeps are a review finding.
3. **Page objects.** Encapsulate page structure and interactions behind an API of user intents; tests read as scenarios, not element manipulation; keep assertions in tests, not page objects.
4. **Session/driver management.** Fresh, isolated sessions per test; deterministic browser/driver provisioning (Selenium Manager or pinned drivers); headless execution parity checked before relying on it in CI.
5. **Grid execution.** Scale via Grid for cross-browser/parallel runs; keep tests parallel-safe (no shared mutable state or data records); collect logs/screenshots on failure from the executing node.
6. **Flake control.** Diagnose with failure artifacts before patching waits; classify root cause (timing, environment, coupling, product bug); quarantine flaky tests with owners rather than deleting or blindly retrying.

## Integration boundaries

Automates web frontends across browsers; executes locally, on Selenium Grid, or on commercial browser clouds; integrates with CI for scheduling/artifacts and with test-management tools via standard report formats (e.g., JUnit XML).

## Verification checklist

- [ ] Selenium version, binding, and browser/driver versions identified
- [ ] Locators reviewed for stability; page-object layering respected
- [ ] All dynamic interactions use explicit waits; no unconditional sleeps
- [ ] Tests independent and parallel-safe (verified by an actual parallel run)
- [ ] Failure artifacts (screenshots/logs) captured and retrievable
- [ ] Suite executed with actual results recorded per the evidence policy
- [ ] Behavior claims cite official docs for the version in use

## References

See `references/SOURCES.md` in this skill's directory for official URLs and access dates.

## Last reviewed: 2026-07-18 (status: complete)

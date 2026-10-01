# Apple product-engineering router

Use this router for work on native iOS, iPadOS, macOS, Mac Catalyst or SwiftUI
product behavior. Framework configuration, generic documentation and market-only
research do not require an Apple-domain audit. The coordinator selects relevant
methods; the specialist performs the scoped inspection.

The original user-supplied standard is preserved verbatim in
[apple-product-engineering-reference.md](apple-product-engineering-reference.md).
Do not load that whole reference by default. Select only the numbered sections
below that change a decision or an applicable acceptance criterion. Search headings
with `rg -n '^## (38|41|42)\.' agent-framework/canonical/policies/apple-product-engineering-reference.md`
(for state/concurrency/networking), then read the matching sections through the next
heading. Section numbers are stable routing keys, not file line numbers.

| Task or concern | Reference sections / heading search terms | Method to load when needed |
| --- | --- | --- |
| Repository/product fit, reuse and scope | 0–2, 54–58, 67–71: repository, dependencies, availability, requirements | Existing requirement and affected components; PROJECT/vision only when product context matters |
| Architecture, state or async behavior | 1, 38–43, 48, 52–54, 65: state management, concurrency, cancellation, networking, persistence | ios-development or macos-development; architecture-review for structural/contract changes |
| New or materially changed native UI | 3–14, 22–40, 61–63: hierarchy, platform, interaction, navigation, adaptive layout | apple-experience-design for proposals; ui-ux-review native reference for implemented UI |
| Motion or animated interaction | 15–21, 46, 51: motion, springs, Reduce Motion, transitions | Native UI review only for affected motion |
| Accessibility | 6–9, 13, 18, 32, 36–37, 74: typography, keyboard, focus, VoiceOver | ios-quality accessibility reference; independent accessibility-reviewer when required |
| Measured performance/resource concern | 41, 44–46, 65: task lifetime, performance, images, animation | ios-quality performance reference; resource-safety only for lifecycle/resource-growth concerns |
| Tests, runtime evidence and final review | 47–51, 64–66, 73–74: previews, testing, build, definition of done, self-review | ios-testing for relevant test execution; ui-ux-review for affected surfaces |

Preserve these obligations within the approved outcome:

- Reuse the existing architecture, components and adopted design system. Resolve
  platforms, deployment targets and API availability from the actual project.
- Keep one clear state/task owner, deliberate isolation, cancellation and recovery.
  Preserve user work; do not invent product features or rewrite unrelated code.
- Native UI must remain usable, adaptive and accessible with purposeful motion.
  Choose representative affected states and interactions, not an unrelated full-app matrix.
- Build/test affected behavior and inspect applicable runtime/visual evidence before
  claiming completion. A build or static screenshot alone cannot certify interaction,
  motion or accessibility. Report unavailable checks as NOT RUN and inapplicable ones
  as N/A with a reason. Independent gates remain independent.
- Role ownership, read-only restrictions, user model inheritance, scope/ADR policy,
  resource bounds and security/privacy obligations remain binding. This router grants
  no tools, sandbox enforcement, dependencies, signing identities or external authorization.

Optional installed methods: use swiftui-pro for a SwiftUI code review when available,
in addition to the repository's ownership and independent-review requirements. Use
openai-docs for an actual Codex/OpenAI product or configuration question when available;
merely running the task in Codex does not trigger it. Inspect the session skill catalog
and read the installed skill's entrypoint. Neither method is bundled or required to be
installed globally; if absent, use local evidence and available authorized documentation
access, marking unresolved facts UNKNOWN.

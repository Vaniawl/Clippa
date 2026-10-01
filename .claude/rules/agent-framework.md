<!-- GENERATED from agent-framework/canonical/ — edit the canonical source, then run: python3 scripts/agent-framework/render.py -->

# Agent framework (pointer digest)

- Core instructions: `AGENTS.md` managed block (imported via `CLAUDE.md`).
- Policies: `agent-framework/canonical/policies/` (autonomy, delegation, evidence, research, scope-control, security).
- Contracts: `agent-framework/canonical/contracts/` (task, handover, definition-of-done).
- Catalogs: `agent-framework/catalogs/` (roles, skills, workflows, personas, provider capability matrix).
- UI: use the product's adopted design system; native Apple surfaces follow system semantics and `agent-framework/canonical/policies/apple-product-engineering.md`, not the framework's example brand.
- Integrity: `python3 scripts/agent-framework/check-drift.py` must pass before commit.

# SKYPhoenix Cross-Provider Agent Framework

Version: see `VERSION`. Provider-neutral agent framework for Claude Code, OpenAI
Codex, Kimi Code, OpenCode (incl. local LLMs), and JetBrains AI Assistant/Junie.

## Architecture

```
canonical/            SOURCE OF TRUTH — edit here only
  core-instructions.md  -> AGENTS.md / CLAUDE.md managed blocks
  policies/             autonomy, delegation, evidence, research, scope-control, security
  contracts/            task, handover, definition-of-done
  roles/                19 role definitions (YAML)
  skills/               open-spec Agent Skills (core + domain)
  workflows/            software-lifecycle, deep-research, market-research,
                        persona-validation, autonomous-session
  personas/             12 user-validation personas
providers/            adapter definitions per provider (mapping documentation)
catalogs/             role/skill/workflow/persona catalogs + provider capability matrix
design-system/        extracted SKYPhoenix brand tokens + guidelines (source-ledger backed)
schemas/              JSON Schemas (autonomous-run, run-state)
evals/                deterministic checks (artifact/mutation/dry-run); live-model
                      rubrics for behaviors needing runtime observation are
                      separate (evals/rubrics.md), marked NOT RUN unless executed
reports/              audit, research, security review, migration guide, release reports
runs/                 autonomous-session run state (gitignored)
```

Generated provider files (`.claude/`, `.agents/skills/`, `.codex/`, `.kimi-code/`,
`.opencode/`, `.aiassistant/rules/`, `opencode.json`, and the managed blocks in
`AGENTS.md`/`CLAUDE.md`) are **build artifacts**. Never edit them directly.

## Commands

```bash
python3 scripts/agent-framework/render.py          # regenerate provider files
python3 scripts/agent-framework/render.py --check  # fail if generated files drifted
python3 scripts/agent-framework/validate.py        # validate canonical content
python3 scripts/agent-framework/check-drift.py     # render-check + manifest integrity
python3 scripts/agent-framework/run-autonomous-session.py --config run.json --dry-run
python3 scripts/agent-framework/evals/run-evals.py # deterministic checks (see evals/rubrics.md for live-model rubrics, NOT RUN by this command)
```

`validate-repository.sh` (and therefore CI) runs validate + check-drift.
Script dependency: Python 3.9+ and PyYAML. `scripts/agent-framework/*.sh` are Bash
programs — Bash is required; they are invocable from fish/zsh as executables but
are not fish-syntax-compatible and must not be sourced into a non-Bash shell.

## Workflow for changes

1. Edit files under `canonical/` (or catalogs/design-system).
2. `python3 scripts/agent-framework/render.py`
3. `python3 scripts/agent-framework/validate.py && python3 scripts/agent-framework/check-drift.py`
4. Commit canonical + generated files together.

## Adopting or updating this framework in another repository

One idempotent command handles both the first migration and every later upgrade:

```bash
python3 scripts/agent-framework/update-framework.py            # --dry-run to preview
```

It syncs the framework payload, bootstraps the project-side requirements, renders, and
runs the full gate — refusing (exit 2) rather than overwriting anything it cannot prove
the framework owns. It also installs `.github/workflows/framework-update.yml`, which
opens a gated update pull request weekly. Full instructions, including the bootstrap
one-liner for repositories that do not have the script yet:
`reports/migration-guide.md`.

Running it against THIS repository is refused — the template is the framework source
(marked by `.framework-source`); edit canonical sources and render instead.

Domain skills are installed per project via `project.yaml` → `agent_framework.skills`
(core skills always installed; never install the whole domain catalogue).

## Key documents

- `reports/current-state-audit.md` — pre-redesign audit
- `reports/provider-research.md` + `catalogs/provider-capability-matrix.yaml` — dated provider facts
- `canonical/workflows/autonomous-session/WORKFLOW.md` — long-run supervisor design
- `reports/migration-guide.md` — adopting/upgrading the framework in existing repos

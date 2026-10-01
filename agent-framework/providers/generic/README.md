# Generic adapter — local LLMs / OpenAI-compatible endpoints

Status: supported-through-adapter. For agents driven through OpenCode with a local
model, or any harness speaking the OpenAI-compatible API.

## Recommended path: OpenCode + local provider

Add a provider block to `opencode.json` (documented at opencode.ai/docs/providers,
accessed 2026-07-18) — see `opencode.local-llm.example.json` in this directory for
Ollama / LM Studio / llama.cpp examples; every model entry there declares
`limit.context`/`limit.output` (≥ 16384 context) since a copy-paste example with no
context limit silently runs at the endpoint's default. The renderer only ever
touches the `$schema` and `permission` keys of `opencode.json` — the `provider`
block (including this one) is preserved verbatim across re-renders and framework
upgrades; you do not need to re-add it after `render.py` runs. Then everything in
this framework works unchanged: AGENTS.md managed block, `.agents/skills/`,
`.opencode/agents/` roles and permissions.

**Ollama context window is a server-side setting.** The opencode.json `limit` key
only tells OpenCode/the model SDK the context size to *assume* when packing
requests — it does not raise Ollama's own context window. Ollama's actual context
window (`num_ctx`) is configured on the Ollama server, independently, via either:
a `PARAMETER num_ctx 32768` line in the model's `Modelfile` (then `ollama create`
to rebuild the model with that parameter baked in), or the `OLLAMA_CONTEXT_LENGTH`
environment variable when starting `ollama serve` (applies to all models served).
Setting only the opencode.json `limit` without also raising the server-side
setting leaves Ollama running at its own default context window regardless of
what the client declares — tool calls and long prompts will still truncate. Both
sides must be set consistently (≥ 16384, framework guidance: 16k–32k). LM Studio
and llama.cpp expose their context size at model-load time (LM Studio: per-model
load settings; llama.cpp: `llama-server --ctx-size`), with the same requirement —
the opencode.json `limit` value should match, not exceed, what the server was
actually started with.

Model tiering: local models are the `economy` class. Do not hand premium-class work
(architecture, security review, adversarial review, final synthesis) to a small local
model; the role catalog records each role's `model_class` and fallback.

## Direct OpenAI-compatible integration (no OpenCode)

A custom harness must assemble the context itself:

1. System prompt: root `AGENTS.md` (managed block included) + the role brief from
   `.opencode/agents/<role>.md` or `.kimi-code/agents/<role>.md` (same content).
2. Skills: no discovery exists — inline the selected `SKILL.md` bodies (respect the
   skill-catalog default_install + project.yaml selection; never inline the whole
   domain catalogue).
3. Permissions: the endpoint enforces nothing. The harness owns command/network
   policy; apply agent-framework/canonical/policies/security-policy.md in the
   harness (e.g., the autonomous supervisor's command_policy/network_policy).
4. Evidence and scope rules apply unchanged; small models drift more, so keep tasks
   `trivial`/`light` weight and validate outputs deterministically.

## Live local-model benchmark

The framework includes a direct, bounded smoke/behavior benchmark for an
OpenAI-compatible Chat Completions endpoint:

```bash
python3 scripts/agent-framework/evals/run-local-model-benchmark.py \
  --provider local-litellm \
  --report /tmp/local-model-benchmark.json
```

By default it reads the selected provider's endpoint, environment-backed API key, and all
model IDs from the repository's `opencode.json`. For Ollama or LM Studio without an API
key, an explicit invocation is enough:

```bash
python3 scripts/agent-framework/evals/run-local-model-benchmark.py \
  --base-url http://127.0.0.1:11434/v1 \
  --model qwen3-coder:30b
```

Every case is sent with an output budget of at least 250 tokens (`--max-tokens` defaults
to 250 and rejects anything lower). The model may emit fewer tokens when its complete
answer is shorter. `--dry-run` validates and prints the plan without making requests.
Exit 0 means every live assertion passed; exit 1 means a model/endpoint/assertion failed;
exit 2 means the configuration was refused. API keys are accepted only through an
environment-variable reference and are excluded from output and reports. Loopback HTTP
works for local services; remote endpoints require HTTPS plus
`--allow-remote-endpoint`.

This command benchmarks model responses, not autonomous tool execution. The OpenCode
provider shim remains the integration path for supervised agent runs.

## Long-running / autonomous-session support is bring-your-own

`long_running_tasks` for the `generic` provider is honestly a **bring-your-own
shim**, not a shipped adapter: the autonomous-session supervisor
(`scripts/agent-framework/run-autonomous-session.py`) drives providers through a
per-provider shim contract defined in `scripts/agent-framework/provider-common.sh`
(env in: `AF_PROMPT_FILE`, `AF_SESSION_REF`, `AF_MODEL`, `AF_WORKDIR`, `AF_PHASE`,
`AF_NETWORK_MODE`, `AF_COMMAND_MODE`, `AF_DRY_RUN`, …; stdout out: a single JSON
object as the last non-empty line — `{"session_ref","text","cost_usd","tokens",
"exit_kind"}`), and only `provider-claude.sh`, `provider-codex.sh`,
`provider-kimi.sh`, and `provider-opencode.sh` ship today. There is no
`provider-generic.sh`, and the
supervisor's config schema (`agent-framework/schemas/autonomous-run.schema.json`)
does not accept `provider: generic`. To use the supervisor with a local model or a
custom OpenAI-compatible harness, write your own `provider-<name>.sh` implementing
the same shim contract (session open/resume, phase-result emission, cost/token
reporting) and point your run config at OpenCode instead (which does have a
shipped shim and can itself be pointed at a local model per the section above).
Do not assume the supervisor works unattended against an arbitrary OpenAI-compatible
endpoint without that shim.

The benchmark bounds its client-side requests and responses but does not start or contain
the model server process. Run Ollama, LM Studio, llama.cpp, or LiteLLM under an appropriate
host/container memory and CPU limit when testing large or third-party model artifacts.

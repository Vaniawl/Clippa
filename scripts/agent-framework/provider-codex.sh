#!/usr/bin/env bash
# OpenAI Codex shim. Headless: `codex exec` / `codex exec resume <SESSION_ID>` with
# --json JSONL events. Docs (accessed 2026-07-18): learn.chatgpt.com/docs/non-interactive-mode.
# Sandbox mapped from AF_COMMAND_MODE. IMPORTANT (review finding CXR-002/KF-H13):
# `codex exec resume` does NOT accept -s/--sandbox; the sandbox for resumed sessions
# is set via the supported `-c sandbox_mode=...` config override. Verified against
# codex-cli 0.144.6 and 0.159.3 (`codex exec resume --help`). Supervised calls
# explicitly deny sandbox command egress rather than relying on trust-gated
# project config. Offline also disables web search; MCP/plugin/model connections
# are separate, so the supervisor requires an acknowledgment of that limitation.
#
# SUPPORTED CLI VERSIONS: codex-cli 0.144.x and 0.159.x. The version gate below FAILS
# (exit 2) on any other installed version before invoking the CLI — resume argv
# is version-specific and a silent mismatch produced dead commands in the past
# (CXR-002/KF-H13). Direct-shim attended pilots can use AF_ACCEPT_UNSUPPORTED_CLI=1;
# the supervisor deliberately does not forward this override.
source "$(dirname "$0")/provider-common.sh"
af_guard_real_run
af_require_cli_version codex "0.144" "0.159"

cd "$AF_WORKDIR"
SANDBOX="workspace-write"
[[ "${AF_COMMAND_MODE:-}" == "read-only" ]] && SANDBOX="read-only"

# These CLI overrides apply to both new and resumed sessions, even when Codex
# skips the project's .codex/config.toml. A headless call cannot grant escalation.
POLICY_ARGS=(-c 'approval_policy="never"' -c 'sandbox_workspace_write.network_access=false')
case "${AF_NETWORK_MODE:-offline}" in
  offline) POLICY_ARGS+=(-c 'web_search="disabled"') ;;
  open|allowlist) ;; # Preserve the conservative egress default; no allowlist adapter ships.
  *) echo "provider shim: REFUSED — invalid AF_NETWORK_MODE" >&2; exit 2 ;;
esac

RAW_FILE="$(af_mktemp_raw)"
trap 'rm -f "$RAW_FILE"' EXIT
set +e
if [[ -n "${AF_SESSION_REF:-}" ]]; then
  af_with_timeout codex exec resume "$AF_SESSION_REF" --json -c "sandbox_mode=\"$SANDBOX\"" "${POLICY_ARGS[@]}" \
    -m "$AF_MODEL" - <"$AF_PROMPT_FILE" >"$RAW_FILE" 2>>"${AF_LOG_FILE:-/dev/null}"
else
  af_with_timeout codex exec --json --sandbox "$SANDBOX" "${POLICY_ARGS[@]}" -m "$AF_MODEL" - \
    <"$AF_PROMPT_FILE" >"$RAW_FILE" 2>>"${AF_LOG_FILE:-/dev/null}"
fi
RC=$?
set -e

python3 - "$RC" "$RAW_FILE" <<'PY'
import json, sys
rc = int(sys.argv[1]); ref = None; text = []; tokens = 0; kind = "completed"
with open(sys.argv[2], encoding="utf-8", errors="replace") as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        try:
            ev = json.loads(line)
        except json.JSONDecodeError:
            continue
        t = ev.get("type", "")
        if t == "thread.started":
            ref = ev.get("thread_id") or ev.get("session_id") or ref
        elif t.startswith("item.") and ev.get("item", {}).get("type") == "agent_message":
            text.append(ev["item"].get("text", ""))
        elif t == "turn.completed":
            u = ev.get("usage") or {}
            # cached_input_tokens is a subset of input_tokens, not an extra count.
            tokens += (u.get("input_tokens") or 0) + (u.get("output_tokens") or 0)
        elif t == "turn.failed":
            kind = "crashed"
if rc == 124:  # coreutils timeout: shim-level call bound hit (AF_CALL_TIMEOUT_SECONDS)
    kind = "timeout"
elif rc != 0 and kind == "completed":
    kind = "crashed"
if not text and kind == "completed":
    kind = "crashed"  # empty output from a "successful" call is not trustworthy
print(json.dumps({"session_ref": ref, "text": "\n".join(text), "cost_usd": 0.0,
                  "tokens": tokens, "exit_kind": kind}))
PY

#!/usr/bin/env python3
"""Opt-in native Codex delegation smoke in a disposable product fixture.

Requires --live (uses real model calls and the user's inherited model settings).
No global config is changed. Raw runtime logs are kept only with --artifacts-dir;
point that option at ignored artifacts. Structural checks are not a live pass.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import signal
from pathlib import Path
import secrets
import queue
import threading
import shutil
import subprocess
import sys
import tempfile
import time
import tomllib
import yaml

sys.path.insert(0, str(Path(__file__).resolve().parent))
from _lib import REPO_ROOT


def snapshot(root: Path) -> dict:
    return {str(p.relative_to(root)): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in root.rglob("*") if p.is_file() and ".git" not in p.relative_to(root).parts}


def stop_process_group(process) -> None:
    """Kill/reap the complete local process group on success, error or interrupt."""
    try:
        os.killpg(process.pid, signal.SIGTERM)
    except ProcessLookupError:
        pass
    try:
        process.wait(timeout=5)
    except subprocess.TimeoutExpired:
        pass
    try:
        os.killpg(process.pid, signal.SIGKILL)
    except ProcessLookupError:
        pass
    process.wait()


def run_bounded(command: list[str], timeout: float, cwd: Path | None = None):
    process = subprocess.Popen(command, cwd=cwd, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                               text=True, stdin=subprocess.DEVNULL, start_new_session=True)
    try:
        stdout, stderr = process.communicate(timeout=max(timeout, 0.1))
        return subprocess.CompletedProcess(command, process.returncode, stdout, stderr)
    finally:
        stop_process_group(process)


def run_appserver(cli: str, fixture: Path, prompt: str, timeout: int) -> subprocess.CompletedProcess:
    """Opt-in raw app-server transport; unlike exec JSON it retains code-mode calls."""
    command = [cli, "app-server", "--stdio", "--strict-config", "-c",
               f'projects.{json.dumps(str(fixture))}.trust_level="trusted"']
    process = subprocess.Popen(command, cwd=fixture, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                               stderr=subprocess.PIPE, text=True, start_new_session=True)
    messages = queue.Queue()
    lines, errors = [], []
    def read_stdout():
        for line in process.stdout:
            lines.append(line)
            try:
                messages.put(json.loads(line))
            except ValueError:
                pass
        messages.put(None)
    def read_stderr():
        errors.extend(process.stderr.readlines())
    readers = [threading.Thread(target=read_stdout, daemon=True), threading.Thread(target=read_stderr, daemon=True)]
    for reader in readers:
        reader.start()
    deadline = time.monotonic() + timeout
    def send(message):
        process.stdin.write(json.dumps(message) + "\n")
        process.stdin.flush()
    def receive(expected_id=None, complete_thread=None):
        while True:
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                raise subprocess.TimeoutExpired(command, timeout)
            try:
                message = messages.get(timeout=remaining)
            except queue.Empty:
                raise subprocess.TimeoutExpired(command, timeout)
            if message is None:
                raise RuntimeError("app-server terminated before completed turn")
            if expected_id is not None and message.get("id") == expected_id:
                if "error" in message:
                    raise RuntimeError(str(message["error"]))
                return message.get("result", {})
            if (complete_thread and message.get("method") == "turn/completed"
                    and message.get("params", {}).get("threadId") == complete_thread):
                return message["params"]
            if "id" in message and "method" in message:
                send({"id": message["id"], "error": {"code": -32601, "message": "noninteractive smoke cannot authorize external actions"}})
    try:
        send({"id": 1, "method": "initialize", "params": {"clientInfo": {"name": "apple_team_smoke", "version": "1"},
             "capabilities": {"experimentalApi": True}}})
        receive(expected_id=1)
        send({"method": "initialized", "params": {}})
        send({"id": 2, "method": "thread/start", "params": {"cwd": str(fixture), "sandbox": "workspace-write",
             "approvalPolicy": "never", "experimentalRawEvents": True, "ephemeral": False}})
        started = receive(expected_id=2)
        thread_id = started["thread"]["id"]
        send({"id": 3, "method": "turn/start", "params": {"threadId": thread_id,
             "input": [{"type": "text", "text": prompt, "text_elements": []}]}})
        receive(expected_id=3)
        terminal = receive(complete_thread=thread_id)
        failed = terminal.get("turn", {}).get("status") != "completed"
        return subprocess.CompletedProcess(command, int(failed), "".join(lines), "".join(errors))
    except BaseException as exc:
        exc.output = "".join(lines)
        exc.stderr = "".join(errors)
        raise
    finally:
        stop_process_group(process)
        for reader in readers:
            reader.join(timeout=2)


def source_digest(root: Path) -> str:
    """Hash Git-visible source only, excluding ignored artifacts and dependencies."""
    listed = subprocess.run(["git", "-C", str(root), "ls-files", "--cached", "--others", "--exclude-standard", "-z"],
                            capture_output=True)
    if listed.returncode:
        raise ValueError("source digest requires a Git worktree")
    digest = hashlib.sha256()
    for relative in sorted(set(name for name in listed.stdout.split(b"\0") if name)):
        path = root / os.fsdecode(relative)
        if not path.is_file() or path.is_symlink():
            continue
        digest.update(relative + b"\0")
        with path.open("rb") as stream:
            for chunk in iter(lambda: stream.read(1024 * 1024), b""):
                digest.update(chunk)
    return digest.hexdigest()


def collaboration_items(events: list[dict]) -> list[dict]:
    """Normalize structured CLI, app-server and code-mode activity evidence."""
    items = []
    raw_calls = {}
    for event in events:
        item = event.get("item", event.get("params", {}).get("item", {}))
        if not isinstance(item, dict):
            continue
        if event.get("method") == "rawResponseItem/completed" and item.get("type") == "function_call" and item.get("name") == "spawn_agent":
            try:
                raw_calls[item.get("call_id")] = json.loads(item.get("arguments", "{}"))
            except ValueError:
                pass
        if item.get("type") in ("collab_tool_call", "collab_agent_tool_call", "collabAgentToolCall"):
            items.append(item)
        # Code-mode hosts omit spawnAgent collab items from exec JSON. The
        # app-server's structured activity links a real call ID to a child thread.
        if (event.get("method") == "item/completed" and item.get("type") == "subAgentActivity"
                and item.get("kind") == "started" and item.get("agentThreadId")):
            args = raw_calls.get(item.get("id"), {})
            items.append({"id": item["id"], "type": "collabAgentToolCall", "tool": "spawnAgent", "status": "completed",
                          "receiverThreadIds": [item["agentThreadId"]], "agentPath": item.get("agentPath"),
                          "model": args.get("model"), "reasoningEffort": args.get("reasoning_effort"),
                          "agentType": args.get("agent_type"), "evidence_source": "subAgentActivity"})
        if event.get("method") == "turn/completed":
            params = event.get("params", {})
            turn = params.get("turn", {})
            text = "\n".join(entry.get("text", "") for entry in turn.get("items", []) if entry.get("type") == "agentMessage")
            items.append({"id": turn.get("id"), "tool": "workerResult", "status": "completed",
                          "agentsStates": {params.get("threadId"): {"status": turn.get("status"), "message": text}},
                          "evidence_source": "childTurnCompleted"})
    return items


def verify_events(events: list[dict], markers: list[str], role_markers: dict[str, str] | None = None, review_markers: tuple[str, str] | None = None) -> dict:
    items = collaboration_items(events)
    spawned = [item for item in items if item.get("tool") in ("spawn_agent", "spawnAgent")
               and item.get("status") in ("completed", "success")]
    waited = [item for item in items if item.get("tool") in ("wait", "wait_agent")
              and item.get("status") in ("completed", "success")]
    receiver_ids = {receiver for item in spawned for receiver in item.get("receiver_thread_ids", item.get("receiverThreadIds", []))}
    completed_workers = {}
    failed_workers = set()
    for item in waited + [entry for entry in items if entry.get("tool") == "workerResult"]:
        for worker_id, state in item.get("agents_states", item.get("agentsStates", {})).items():
            status = state.get("status") if isinstance(state, dict) else state
            if status == "completed":
                completed_workers[worker_id] = state.get("message", "") if isinstance(state, dict) else ""
            elif status in ("errored", "failed", "interrupted", "notFound", "not_found"):
                failed_workers.add(worker_id)
    completed_ids = set(completed_workers) & receiver_ids
    main_thread = next((event.get("result", {}).get("thread", {}).get("id") for event in events
                        if event.get("id") == 2 and event.get("result", {}).get("thread", {}).get("id")), None)
    completed = any(event.get("type") == "turn.completed" or (event.get("method") == "turn/completed"
                    and event.get("params", {}).get("threadId") == main_thread
                    and event.get("params", {}).get("turn", {}).get("status") == "completed") for event in events)
    final_messages = [event.get("item", {}).get("text", "") for event in events
                      if event.get("type") == "item.completed" and event.get("item", {}).get("type") == "agent_message"]
    final_messages += [event.get("params", {}).get("item", {}).get("text", "") for event in events
                       if event.get("method") == "item/completed" and event.get("params", {}).get("threadId") == main_thread
                       and event.get("params", {}).get("item", {}).get("type") == "agentMessage"]
    final = "\n".join(final_messages)
    successful_results = "\n".join(str(completed_workers[worker]) for worker in completed_ids)
    role_propagated = all(marker in successful_results for marker in markers)
    if role_markers:
        role_propagated = all(any(
            marker in str(completed_workers.get(worker, ""))
            for item in spawned if str(item.get("agentPath", "")).endswith("/" + role.replace("-", "_"))
            for worker in item.get("receiver_thread_ids", item.get("receiverThreadIds", [])) if worker in completed_ids)
            for role, marker in role_markers.items())
    # Certify the actual author -> reviewer order, including retries. A QA or
    # unrelated worker completing first cannot stand in for the implementation.
    def role_of(item):
        path = str(item.get("agentPath", ""))
        return path.rsplit("/", 1)[-1].replace("_", "-") if path else item.get("agentType")
    author_ids = {worker for item in spawned if role_of(item) == "implementation-engineer"
                  for worker in item.get("receiver_thread_ids", item.get("receiverThreadIds", []))}
    if review_markers is None and len(markers) >= 2:
        review_markers = (markers[0], markers[1])
    reviewer_ids = {worker for item in spawned if role_of(item) == "code-reviewer"
                    for worker in item.get("receiver_thread_ids", item.get("receiverThreadIds", []))}
    if review_markers:
        author_marker, reviewer_marker = review_markers
        author_ids = {worker for worker in completed_ids if author_marker in str(completed_workers[worker])}
        reviewer_ids = {worker for worker in completed_ids if reviewer_marker in str(completed_workers[worker])} - author_ids
        if role_markers:
            author_roles = {role for role, marker in role_markers.items() if marker == author_marker}
            reviewer_roles = {role for role, marker in role_markers.items() if marker == reviewer_marker}
            author_ids &= {worker for item in spawned if role_of(item) in author_roles
                           for worker in item.get("receiver_thread_ids", item.get("receiverThreadIds", []))}
            reviewer_ids &= {worker for item in spawned if role_of(item) in reviewer_roles
                             for worker in item.get("receiver_thread_ids", item.get("receiverThreadIds", []))}
    author_terminals = []
    seen_raw_turns = set()
    last_author_result = {}
    for index, item in enumerate(items):
        for worker, state in item.get("agents_states", item.get("agentsStates", {})).items():
            if worker not in author_ids or not isinstance(state, dict) or state.get("status") != "completed":
                continue
            message = state.get("message", "")
            if item.get("evidence_source") == "childTurnCompleted":
                identity = (worker, item.get("id"))
                if identity in seen_raw_turns:
                    continue
                seen_raw_turns.add(identity)
            elif worker in last_author_result and last_author_result[worker] == message:
                # A later wait can repeat an already completed author's state;
                # it is not another implementation revision.
                continue
            author_terminals.append(index)
            last_author_result[worker] = message
    author_spawns = [index for index, item in enumerate(items) if item in spawned and
                     bool(set(item.get("receiver_thread_ids", item.get("receiverThreadIds", []))) & author_ids)]
    reviewer_spawns = [index for index, item in enumerate(items) if item in spawned
                       and any(worker in completed_ids and worker in reviewer_ids and worker not in author_ids
                               for worker in item.get("receiver_thread_ids", item.get("receiverThreadIds", [])))]
    sequential_review = bool(author_ids and author_terminals and reviewer_spawns and
                             any(index > max(author_terminals + author_spawns) for index in reviewer_spawns))
    return {"real_spawn": bool(spawned), "real_wait": bool(waited), "turn_completed": completed,
            "workers_completed": bool(receiver_ids) and receiver_ids <= completed_ids and not bool(receiver_ids & failed_workers),
            "completed_worker_ids": sorted(completed_ids), "failed_worker_ids": sorted(failed_workers & receiver_ids),
            "role_instruction_propagation": role_propagated,
            "role_marker_relay": all(marker in final for marker in markers),
            "spawn_count": len({item.get('id') for item in spawned}),
            "explicit_model_overrides": [item.get("model") for item in spawned if item.get("model")],
            "explicit_reasoning_overrides": [item.get("reasoning_effort", item.get("reasoningEffort"))
                                            for item in spawned if item.get("reasoning_effort", item.get("reasoningEffort"))],
            "spawned_receiver_ids": sorted(receiver_ids), "independent_review_sequence": sequential_review,
            "tools_observed": sorted({item.get("tool", "") for item in items}),
            "agent_types_observed": sorted({item.get("agentType") for item in spawned if item.get("agentType")})}


def contract(role: str, task: str, owned: str, mode: str) -> str:
    return (f"Delegate to named agent {role}. Task contract: objective={task}; mode={mode}; "
            "approved_outcome=current fixture scenario; product_constraints=offline local Python fixture; "
            "skills=read role's relevant required methods only; required_capabilities=shell and files; "
            f"owned_files={owned}; prohibited_files=everything else; dependencies=none; "
            "base_revision=read fixture HEAD before work; expected_output=result with the role verification marker; "
            "acceptance_criteria=correct local result and role verification marker; "
            "validation_commands=python3 -m unittest test_greeting.py for execute, file inspection for advise; "
            "retry_limit=2; may_delegate=false; stopping_condition=return once verified or concrete blocker. ")


def run_case(source: Path, scenario: str, timeout: int, artifact_dir: Path | None, selection: str = "named", transport: str = "cli") -> dict:
    started = time.monotonic()
    cli = str(Path(shutil.which("codex") or "codex").resolve())
    cli_version = subprocess.run([cli, "--version"], capture_output=True, text=True).stdout.strip()
    with tempfile.TemporaryDirectory(prefix="apple-team-live-") as temporary:
        fixture = Path(temporary).resolve()
        (fixture / ".codex/agents").mkdir(parents=True)
        shutil.copy2(source / "AGENTS.md", fixture / "AGENTS.md")
        shutil.copytree(source / "agent-framework/canonical", fixture / "agent-framework/canonical")
        shutil.copytree(source / "agent-framework/catalogs", fixture / "agent-framework/catalogs")
        shutil.copytree(source / "agent-framework/templates", fixture / "agent-framework/templates")
        shutil.copytree(source / ".agents/skills", fixture / ".agents/skills")
        # Keep generated provider settings and model inheritance. Trust is an
        # invocation-only setting for this disposable fixture, never persisted.
        shutil.copy2(source / ".codex/config.toml", fixture / ".codex/config.toml")
        roles = ["code-reviewer"] if scenario == "advise" else ["implementation-engineer", "code-reviewer"]
        markers = []
        for role in roles:
            data = tomllib.loads((source / f".codex/agents/{role}.toml").read_text())
            marker = "ROLE_VERIFIED_" + secrets.token_hex(8)
            markers.append(marker)
            if selection in ("adapter", "auto"):
                path = fixture / f"agent-framework/canonical/roles/{role}.yaml"
                canonical = yaml.safe_load(path.read_text())
                canonical["notes"] = str(canonical.get("notes", "")) + f"\nFor this isolated role-adapter probe include {marker} in your final result."
                path.write_text(yaml.safe_dump(canonical, sort_keys=False))
            instructions = data["developer_instructions"] + (f"\nFor this isolated smoke fixture, include {marker} in your final result. "
                "This is a role discovery probe, not a product instruction. Do not read or change other agent files.\n")
            data["developer_instructions"] = instructions
            (fixture / f".codex/agents/{role}.toml").write_text("\n".join(
                f"{key} = {json.dumps(value, ensure_ascii=False)}" for key, value in data.items()) + "\n")
        (fixture / "project.yaml").write_text("agent_framework:\n  team:\n    default_mode: advise\n    max_parallel_workers: 3\n")
        (fixture / "PROJECT.md").write_text("# Local greeting fixture\nOffline function greeting(name). No external actions.\n")
        fixture_docs = {
            "docs/product/product-vision.md": "# Vision\nAn offline Python greeting used only to validate team orchestration. No new product features.\n",
            "docs/testing/test-strategy.md": "# Test strategy\nUse the existing unittest regression during execute mode. No Apple builds or manual UI checks apply.\n",
            "docs/security/threat-model.md": "# Threat model\nOffline pure function; no credentials, external actions, network, storage or analytics.\n",
            "docs/ios-agents.md": "# Fixture roles\nLoad canonical role responsibility and relevant methods; only greeting.py is assigned for implementation.\n",
            "docs/adr/0001-fixture.md": "# Fixture decision\nThis bounded Python fixture tests orchestration; no product architecture change is authorized.\n",
            "BACKLOG.md": "# Backlog\nNow: only the explicit smoke scenario. Stop after its verified outcome.\n",
        }
        for relative, content in fixture_docs.items():
            target = fixture / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text(content)
        (fixture / "greeting.py").write_text('def greeting(name):\n    return "Hello, " + name\n')
        (fixture / "test_greeting.py").write_text('import unittest\nfrom greeting import greeting\nclass GreetingTests(unittest.TestCase):\n    def test_known_name(self):\n        self.assertEqual(greeting("Ada"), "Hello, Ada!")\n')
        subprocess.run(["git", "init", "-q", str(fixture)], check=True, capture_output=True)
        subprocess.run(["git", "-C", str(fixture), "add", "."], check=True, capture_output=True)
        subprocess.run(["git", "-C", str(fixture), "-c", "user.name=Team Smoke", "-c", "user.email=smoke@example.invalid",
                        "commit", "-q", "-m", "Isolated smoke baseline"], check=True, capture_output=True)
        before = snapshot(fixture)
        fixture_digest = hashlib.sha256(json.dumps(before, sort_keys=True).encode()).hexdigest()
        if scenario == "advise":
            prompt = ("This is an isolated native team smoke. Remain in advise mode. " + contract(
                "code-reviewer", "inspect greeting.py and test_greeting.py and recommend the minimal correction without writing any files", "none", "advise") +
                "Use the native named agent tool, wait for its completed response, and relay the returned role verification marker. "
                "Do not read agent TOML files yourself or simulate delegation. Do not run tests or save reports in advice mode.")
        else:
            prompt = ("Execute this approved outcome in an isolated fixture: make the greeting test pass. " + contract(
                "implementation-engineer", "fix the missing punctuation and run the existing regression test", "greeting.py", "execute") +
                "After implementation completes, " + contract("code-reviewer", "independently review the changed greeting.py against the test; return findings and marker without writes", "none", "execute") +
                "Use native named agents, wait for both completed results, verify the test yourself, and relay both role verification markers. "
                "Do not implement the fix yourself, read agent TOML files yourself, change any other files, or continue through a backlog. "
                "Use PYTHONDONTWRITEBYTECODE=1 for Python commands. No coordination documents need to be saved in this tiny fixture.")
        if selection in ("adapter", "auto"):
            prompt = prompt.replace("named agent", "generic subagent acting as canonical role").replace("native named agent tool", "available real subagent tool").replace("native named agents", "available real subagent tools")
            prompt += (" Prefer native named selection if the host exposes it; otherwise use this adapter automatically. " if selection == "auto" else "")
            prompt += (" The installed host may expose only generic spawning. Use fork_turns=none and task_name equal to the role ID with hyphens replaced by underscores; pass the fixture absolute path and complete role contract in the message. "
                       "The coordinator must read the chosen agent-framework/canonical/roles/<role>.yaml and relevant skill entrypoints, "
                       "then include their responsibilities, restrictions and method instructions explicitly in the bounded spawn message. "
                       "Each specialist returns the role verification marker from its role notes in its completed result. "
                       "This is an explicit canonical role adapter, not native named-agent discovery. "
                       "Do not read custom agent TOML files to simulate native selection.")
        else:
            prompt += (" If the tool exposes task_name rather than agent_type, try task_name equal to the exact named role ID "
                       "without loading specialist instructions yourself. Report unavailable native role selection accurately.")
        command = [cli, "--no-daemon", "-a", "never", "-c",
                   f'projects.{json.dumps(str(fixture))}.trust_level="trusted"',
                   "exec", "--strict-config", "--sandbox", "workspace-write", "--json", "--cd", str(fixture), prompt]
        try:
            result = run_appserver(cli, fixture, prompt, timeout) if transport == "app-server" else run_bounded(command, timeout)
        except subprocess.TimeoutExpired as exc:
            if artifact_dir:
                artifact_dir.mkdir(parents=True, exist_ok=True)
                (artifact_dir / f"{scenario}.timeout.txt").write_text(f"Native run exceeded {timeout}s; complete process group terminated.\n")
                for suffix, value in (("jsonl", getattr(exc, "output", "")), ("stderr.log", getattr(exc, "stderr", ""))):
                    if isinstance(value, bytes):
                        value = value.decode(errors="replace")
                    (artifact_dir / f"{scenario}.{suffix}").write_text(value or "")
            return {"scenario": scenario, "cli_version": cli_version, "selection": selection, "status": "BLOCKED", "reason": f"native run exceeded {timeout}s", "elapsed_seconds": round(time.monotonic() - started, 2)}
        except (OSError, RuntimeError) as exc:
            return {"scenario": scenario, "cli_version": cli_version, "selection": selection, "status": "BLOCKED", "reason": str(exc), "elapsed_seconds": round(time.monotonic() - started, 2)}
        events = []
        for line in result.stdout.splitlines():
            try:
                event = json.loads(line)
                if isinstance(event, dict):
                    events.append(event)
            except ValueError:
                pass
        evidence = verify_events(events, markers, dict(zip(roles, markers)))
        after = snapshot(fixture)
        changed = sorted(key for key in set(before) | set(after) if before.get(key) != after.get(key))
        permitted = [] if scenario == "advise" else ["greeting.py"]
        evidence["ownership_respected"] = not bool(set(changed) - set(permitted))
        evidence["changed_files"] = changed
        if scenario == "execute":
            try:
                test = run_bounded([sys.executable, "-B", "-m", "unittest", "test_greeting.py"],
                                   min(15, max(0.1, timeout - (time.monotonic() - started))), cwd=fixture)
                evidence["independent_regression_test"] = test.returncode == 0
            except subprocess.TimeoutExpired:
                evidence["independent_regression_test"] = False
                evidence["regression_blocker"] = "independent regression exceeded bounded deadline"
        else:
            evidence["advice_no_writes"] = not changed
        required = ("real_spawn", "real_wait", "turn_completed", "role_instruction_propagation", "workers_completed", "ownership_respected")
        passed = result.returncode == 0 and all(evidence[key] for key in required)
        if scenario == "execute":
            evidence["independent_reviewer"] = len(evidence["completed_worker_ids"]) >= 2 and evidence["independent_review_sequence"]
            passed = passed and evidence["independent_reviewer"]
        passed = passed and (evidence.get("independent_regression_test", True)) and not evidence["explicit_model_overrides"] and not evidence["explicit_reasoning_overrides"]
        usage = [event.get("usage") for event in events if event.get("type") == "turn.completed"]
        usage += [event.get("params", {}).get("usage") for event in events if event.get("method") == "rawResponse/completed"]
        if artifact_dir:
            artifact_dir.mkdir(parents=True, exist_ok=True)
            (artifact_dir / f"{scenario}.jsonl").write_text(result.stdout)
            (artifact_dir / f"{scenario}.stderr.log").write_text(result.stderr)
        parent_settings = next((event.get("result", {}) for event in events if event.get("id") == 2 and "model" in event.get("result", {})), {})
        return {"scenario": scenario, "cli_version": cli_version, "selection": selection, "status": "PASS" if passed else ("BLOCKED" if not evidence["real_spawn"] else "FAIL"), "exit_code": result.returncode,
                "elapsed_seconds": round(time.monotonic() - started, 2), "fixture_content_digest": fixture_digest, "evidence": evidence,
                "usage": usage, "cost": "not exposed by CLI", "parent_model": parent_settings.get("model", "not exposed"),
                "parent_reasoning_effort": parent_settings.get("reasoningEffort", "not exposed"),
                "effective_child_model": "inherited by absence of explicit override; resolved child settings not exposed",
                "error_events": [event for event in events if event.get("type") in ("error", "turn.failed")]}


def named_discovery_verified(results: list[dict]) -> bool:
    """Only observed native selector metadata proves named discovery."""
    return bool(results) and all(
        result["status"] == "PASS" and set(result["evidence"].get("agent_types_observed", [])) ==
        ({"code-reviewer"} if result["scenario"] == "advise" else {"implementation-engineer", "code-reviewer"})
        for result in results)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--live", action="store_true")
    parser.add_argument("--root", type=Path, default=REPO_ROOT)
    parser.add_argument("--scenario", choices=("advise", "execute", "all"), default="all")
    parser.add_argument("--transport", choices=("cli", "app-server"), default="app-server", help="app-server raw experimental events can expose calls hidden by CLI JSON")
    parser.add_argument("--selection", choices=("auto", "named", "adapter"), default="auto", help="native named discovery or explicit canonical-role generic-tool fallback")
    parser.add_argument("--timeout", type=int, default=300)
    parser.add_argument("--artifacts-dir", type=Path)
    args = parser.parse_args()
    if not args.live:
        print(json.dumps({"native_execution": "NOT RUN", "reason": "opt in with --live; this uses real model calls"}))
        return 0
    if not shutil.which("codex"):
        print(json.dumps({"native_execution": "BLOCKED", "reason": "codex CLI is unavailable"}))
        return 2
    version = subprocess.run(["codex", "--version"], capture_output=True, text=True).stdout.strip()
    revision = subprocess.run(["git", "-C", str(args.root), "rev-parse", "HEAD"], capture_output=True, text=True).stdout.strip()
    scenarios = ("advise", "execute") if args.scenario == "all" else (args.scenario,)
    digest = source_digest(args.root)
    results = [run_case(args.root.resolve(), scenario, args.timeout, args.artifacts_dir, args.selection, args.transport) for scenario in scenarios]
    named_verified = args.selection != "adapter" and named_discovery_verified(results)
    report = {"cli_version": version, "source_revision": revision, "source_content_digest": digest, "role_selection": args.selection,
              "transport": args.transport, "results": results,
              "native_named_discovery": "PASS" if named_verified else "NOT VERIFIED",
              "native_execution": "PASS" if all(result["status"] == "PASS" for result in results) else "FAIL"}
    if args.artifacts_dir:
        args.artifacts_dir.mkdir(parents=True, exist_ok=True)
        (args.artifacts_dir / "smoke-report.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report, indent=2))
    return 0 if report["native_execution"] == "PASS" else 1


if __name__ == "__main__":
    sys.exit(main())

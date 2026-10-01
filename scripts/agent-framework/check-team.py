#!/usr/bin/env python3
"""Read-only Apple team preflight. Default: no inference, build, install, or config edits.

--session-probe queries an ephemeral session catalog without inference.
--research-probe explicitly opts in to a bounded read-only model retrieval turn.

Structural validity is separate from native execution, which requires the opt-in
smoke-team.py run. JSON output is suitable for a capability report.
"""
from __future__ import annotations

import argparse
import importlib.util
import json
import os
import re
from pathlib import Path
import shutil
import subprocess
import sys
import tomllib
from urllib.parse import urlsplit
import yaml

sys.path.insert(0, str(Path(__file__).resolve().parent))
from _lib import REPO_ROOT
from _project import team_options


def smoke_tools():
    spec = importlib.util.spec_from_file_location("team_capability_transport", Path(__file__).with_name("smoke-team.py"))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def session_inventory(cli: str, root: Path, timeout: int = 30) -> dict:
    """Observe an ephemeral installed session, without inference or configuration writes.

    Configured server names do not prove connection or tool availability. Return
    only allowlisted metadata: never effective config, headers, URLs, or tool bodies.
    """
    try:
        result = smoke_tools().run_appserver(cli, root, None, timeout, queries=[
            {"method": "config/read", "params": {"cwd": str(root), "includeLayers": False}},
            {"method": "mcpServerStatus/list", "params": {"detail": "toolsAndAuthOnly", "limit": 100}, "thread_scoped": True},
        ])
        values = json.loads(result.stdout)
        config = values.get("config/read", {}).get("config", {})
        inventory = values.get("mcpServerStatus/list", {})
        if not isinstance(config, dict) or not isinstance(inventory.get("data"), list):
            return {"status": "UNAVAILABLE", "reason": "installed session returned no usable MCP inventory"}
        servers = []
        for server in inventory.get("data", []):
            connected = server.get("runtimeStatus") == "connected" and not server.get("toolsError")
            servers.append({"name": server.get("name"), "connection": server.get("runtimeStatus", "unknown"),
                            "auth_status": server.get("authStatus", "unknown"),
                            "available_tools": sorted(server.get("tools", {})) if connected else [],
                            "availability": "AVAILABLE" if connected else "NOT VERIFIED",
                            "live_retrieval": "NOT RUN"})
        web = config.get("web_search")
        return {"status": "PASS" if "query_error_code" not in inventory else "UNAVAILABLE",
                "scope": "queried ephemeral installed Codex session; not every future session",
                "configured_mcp_servers": sorted(config.get("mcp_servers", {})),
                "web_search": {"configured": web if web in ("live", "cached", "disabled") else "unknown/inherited",
                               "available": "NOT VERIFIED", "live_retrieval": "NOT RUN"},
                "mcp_servers": servers, "inventory_complete": not bool(inventory.get("nextCursor")),
                "query_error_code": inventory.get("query_error_code"),
                "note": "A connected catalog proves advertised availability, not successful research retrieval."}
    except (OSError, ValueError, RuntimeError, subprocess.TimeoutExpired):
        # Exception text and transport traces may contain private MCP settings.
        return {"status": "UNAVAILABLE", "reason": "installed session inventory query did not complete; no live tool availability proven"}


def retrieval_evidence(events: list[dict]) -> dict:
    """Only successful tool results establish retrieval; model prose is insufficient."""
    tools = []
    attempted = []
    for event in events:
        if event.get("method") != "item/completed":
            continue
        item = event.get("params", {}).get("item", {})
        if item.get("type") in ("mcpToolCall", "webSearch"):
            attempted.append({"kind": item.get("type"), "status": item.get("status", "unknown"),
                              "server": item.get("server"), "tool": item.get("tool")})
        if item.get("type") != "mcpToolCall" or item.get("status") != "completed" or item.get("error"):
            continue
        result = item.get("result") or {}
        if result.get("isError"):
            continue
        # Recognized page operations and a returned document body are both
        # required. Search/index metadata can contain the same URL and words.
        # Unknown tools or result formats remain unverified.
        tool = str(item.get("tool", "")).lower()
        page_operation = re.fullmatch(r"(?:fetch(?:_(?:docs|openai_doc|document|page|url))?|read_(?:page|document)|open_(?:page|url)|get_(?:page|document))", tool)
        if not page_operation:
            continue
        bodies = []
        for entry in result.get("content", []):
            if entry.get("type") != "text" or not isinstance(entry.get("text"), str):
                continue
            body = entry["text"]
            # Plain Markdown needs an explicit source line, not an arbitrary
            # backlink somewhere in a document from another origin.
            source_line = next((line.strip() for line in body.splitlines() if line.strip()), "")
            source_url = source_line.removeprefix("Source:").strip()
            try:
                document = json.loads(body)
            except ValueError:
                document = None
            if document is not None:
                # Only explicit single-document envelopes are recognized.
                # Results/snippets are search metadata, even from a fetch tool.
                if (not isinstance(document, dict)
                        or any(key in document for key in ("results", "items", "snippet", "snippets", "score"))):
                    continue
                source_url = document.get("url", document.get("source_url", ""))
                body = next((document[key] for key in ("markdown", "body", "content")
                             if isinstance(document.get(key), str)), "")
            try:
                origin = urlsplit(source_url) if isinstance(source_url, str) else None
                official_source = (origin is not None and origin.scheme == "https"
                                   and origin.hostname == "learn.chatgpt.com"
                                   and origin.path == "/docs/agent-configuration/subagents"
                                   and not origin.query and not origin.fragment
                                   and not origin.username and not origin.password and origin.port is None)
            except ValueError:
                official_source = False
            if (official_source
                    and re.search(r"(?m)^#{1,6} +\S", body)
                    and not re.search(r"(?mi)^\s*(?:snippet|score|search results)\s*:", body)
                    and "standalone" in body.lower()
                    and all(field in body for field in ("developer_instructions", "description", "name"))):
                bodies.append(body)
        if bodies:
            tools.append({"server": item.get("server"), "tool": item.get("tool")})
    return {"status": "VERIFIED" if tools else "NOT VERIFIED", "verified_tools": tools, "observed_tool_attempts": attempted,
            "note": "Web actions or final prose without a returned source body do not prove retrieval."}


def research_probe(cli: str, root: Path, timeout: int = 90) -> dict:
    """Explicit opt-in read-only model turn; never install a server or use shell HTTP."""
    import tempfile
    runtime = smoke_tools()
    with tempfile.TemporaryDirectory(prefix="apple-team-research-") as temporary:
        fixture = Path(temporary).resolve()
        (fixture / ".codex").mkdir()
        if (root / ".codex/config.toml").is_file():
            shutil.copy2(root / ".codex/config.toml", fixture / ".codex/config.toml")
        before = runtime.snapshot(fixture)
        prompt = ("Read-only tool capability probe. Use an already available web or documentation MCP retrieval tool to fetch "
                  "https://learn.chatgpt.com/docs/agent-configuration/subagents and report the required standalone custom-agent fields. "
                  "No delegation, file writes, server installation, configuration changes, or shell/network fetching. "
                  "If retrieval is unavailable report that exact limitation; memory and model prose are not retrieval evidence.")
        try:
            result = runtime.run_appserver(cli, fixture, prompt, timeout, read_only=True)
            events = [json.loads(line) for line in result.stdout.splitlines() if line.startswith("{")]
            evidence = retrieval_evidence(events)
            evidence["no_file_writes"] = runtime.snapshot(fixture) == before
            if result.returncode or not evidence["no_file_writes"]:
                evidence["status"] = "FAIL"
            return evidence
        except (OSError, ValueError, RuntimeError, subprocess.TimeoutExpired):
            return {"status": "BLOCKED", "reason": "bounded read-only retrieval probe did not complete; retrieval not verified"}


def probe(command: list[str], root: Path, timeout: int = 20) -> dict:
    try:
        result = subprocess.run(command, cwd=root, capture_output=True, text=True,
                                stdin=subprocess.DEVNULL, timeout=timeout)
        return {"status": "PASS" if result.returncode == 0 else "UNAVAILABLE",
                "exit_code": result.returncode, "stdout": result.stdout, "stderr": result.stderr}
    except (OSError, subprocess.TimeoutExpired) as exc:
        return {"status": "UNAVAILABLE", "reason": str(exc)}


def load_toml(path: Path) -> dict:
    return tomllib.loads(path.read_text(encoding="utf-8")) if path.is_file() else {}


def preflight(root: Path, native_probe: bool = False, session_probe: bool = False, live_research: bool = False) -> dict:
    checks = {}
    errors = []
    try:
        team = team_options(root)
        config = load_toml(root / ".codex/config.toml")
        if not config:
            raise ValueError("missing .codex/config.toml")
        checks["config"] = {"status": "PASS", "project_trust_required": True,
                            "model_override": "model" in config,
                            "research_web_search": config.get("web_search", "inherited; not verified"),
                            "shell_network": config.get("sandbox_workspace_write", {}).get("network_access", "inherited")}
        workers = (team or {}).get("max_parallel_workers")
        limits = []
        user_config = Path(os.environ.get("CODEX_HOME", str(Path.home() / ".codex"))) / "config.toml"
        for scope in (config, load_toml(user_config)):
            agents = scope.get("agents", {})
            cap = agents.get("max_concurrent_threads_per_session", agents.get("max_threads"))
            if type(cap) is int and cap > 0:
                limits.append(cap)
        checks["team"] = {"status": "PASS", "settings": team,
                          "coordinator_worker_limit": min([workers] + limits) if workers else min(limits, default=None),
                          "native_project_worker_limit": config.get("agents", {}).get("max_concurrent_threads_per_session", config.get("agents", {}).get("max_threads")),
                          "runtime_limit": "not independently queried; coordinator respects lower environment and user limits"}
    except (SystemExit, ValueError, OSError, yaml.YAMLError) as exc:
        errors.append(str(exc))
        checks["config"] = {"status": "FAIL", "reason": str(exc)}
    agent_errors = len(errors)
    agents = []
    names = set()
    for path in sorted((root / ".codex/agents").glob("*.toml")):
        try:
            data = load_toml(path)
            for key in ("name", "description", "developer_instructions"):
                if not isinstance(data.get(key), str) or not data[key].strip():
                    raise ValueError(f"{path.name}: missing {key}")
            if data["name"] in names:
                raise ValueError(f"duplicate named agent {data['name']}")
            names.add(data["name"])
            agents.append({"name": data["name"], "model": "overridden" if "model" in data else "inherited",
                           "reasoning": "overridden" if "model_reasoning_effort" in data else "inherited"})
        except (ValueError, OSError) as exc:
            errors.append(str(exc))
    if not agents or "orchestrator" not in names:
        errors.append("named orchestrator is missing")
    checks["agents"] = {"status": "FAIL" if len(errors) > agent_errors else "PASS",
                        "discovery": "structural only; native discovery requires live smoke", "roles": agents}
    skills = [p.parent.name for p in sorted((root / ".agents/skills").glob("*/SKILL.md"))]
    checks["skills"] = {"status": "PASS" if "apple-team" in skills else "FAIL", "installed": skills}
    if "apple-team" not in skills:
        errors.append("apple-team skill is not installed")
    codex = shutil.which("codex")
    version = probe([codex, "--version"], root) if codex else {"status": "UNAVAILABLE"}
    checks["cli"] = {"status": version["status"], "version": version.get("stdout", "").strip()}
    checks["session_tools"] = session_inventory(codex, root) if session_probe and codex else {
        "status": "NOT RUN", "command": "--session-probe", "scope": "configured access is not session tool availability"}
    if native_probe and codex:
        prompt = probe([codex, "debug", "prompt-input", "Read-only team preflight"], root)
        # Do not expose personal instructions, paths, tokens, or MCP configuration.
        rendered = prompt.get("stdout", "")
        coordinator_loaded = ("Coordinator entrypoint" in rendered and "Act as `orchestrator`" in rendered
                              and "agent-framework/canonical/skills/apple-team/SKILL.md" in rendered)
        checks["main_context"] = {"status": ("PASS" if coordinator_loaded else "FAIL") if prompt["status"] == "PASS" else prompt["status"],
                                  "coordinator_loaded": coordinator_loaded,
                                  "note": "local prompt inspection; no inference or delegation"}
    else:
        checks["main_context"] = {"status": "NOT RUN", "command": "--native-probe"}
    xcode = shutil.which("xcodebuild")
    apple = probe([xcode, "-version"], root) if xcode else {"status": "UNAVAILABLE"}
    checks["xcode"] = {"status": apple["status"], "version": apple.get("stdout", "").strip()}
    xcrun = shutil.which("xcrun")
    destinations = probe([xcrun, "simctl", "list", "devices", "available", "--json"], root) if xcrun else {"status": "UNAVAILABLE"}
    try:
        devices = json.loads(destinations.get("stdout", "{}"))["devices"]
        checks["destinations"] = {"status": destinations["status"],
                                  "available_simulator_devices": sum(len(values) for values in devices.values()),
                                  "mac_destination": "My Mac" if apple["status"] == "PASS" else "UNAVAILABLE",
                                  "runtimes": sorted(devices)}
    except (ValueError, KeyError):
        checks["destinations"] = {"status": "UNAVAILABLE", "reason": "simulator destinations could not be listed"}
    checks["research"] = research_probe(codex, root) if live_research and codex else {
        "status": "NOT RUN", "command": "--research-probe (real model call)",
        "note": "web/MCP access and evidence retrieval depend on the active session; configured access is not proof"}
    return {"structural": "FAIL" if errors else "PASS", "native_execution": "NOT RUN",
            "checks": checks, "errors": errors,
            "limitations": ["owned_files is a reviewed contract, not a provider filesystem sandbox",
                            "this preflight does not prove real delegation or manual UI/accessibility checks",
                            "project config and agents require Codex trust; global settings remain unchanged"]}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=REPO_ROOT)
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--native-probe", action="store_true", help="inspect local model-visible prompt without inference")
    parser.add_argument("--session-probe", action="store_true", help="query ephemeral installed-session MCP catalog without inference; no server installation")
    parser.add_argument("--research-probe", action="store_true", help="opt in to a bounded real model turn attempting read-only official-source retrieval")
    args = parser.parse_args()
    report = preflight(args.root.resolve(), args.native_probe, args.session_probe, args.research_probe)
    if args.json:
        print(json.dumps(report, indent=2))
    else:
        print(f"Structural: {report['structural']}; native execution: NOT RUN")
        for name, check in report["checks"].items():
            print(f"{name}: {check['status']}")
        for error in report["errors"]:
            print(f"ERROR: {error}")
    return 1 if report["structural"] == "FAIL" else 0


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
"""Read-only Apple team preflight. No inference, build, install, or global config edits.

Structural validity is separate from native execution, which requires the opt-in
smoke-team.py run. JSON output is suitable for a capability report.
"""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tomllib
import yaml

sys.path.insert(0, str(Path(__file__).resolve().parent))
from _lib import REPO_ROOT
from _project import team_options


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


def preflight(root: Path, native_probe: bool = False) -> dict:
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
    checks["research"] = {"status": "NOT RUN", "note": "web/MCP access and evidence retrieval depend on the active session; configured access is not proof"}
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
    args = parser.parse_args()
    report = preflight(args.root.resolve(), args.native_probe)
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

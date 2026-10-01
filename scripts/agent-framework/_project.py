"""Validated project-owned OpenCode adapter options shared by rendering and evals."""
from __future__ import annotations

import re
import json
import hashlib
import yaml
from _lib import REPO_ROOT


def opencode_options(role_ids: set[str]) -> tuple[bool, dict[str, str]]:
    path = REPO_ROOT / "project.yaml"
    project = yaml.safe_load(path.read_text(encoding="utf-8")) if path.exists() else {}
    if project is None:
        project = {}
    if not isinstance(project, dict):
        raise SystemExit("project.yaml must contain a mapping")
    framework = project.get("agent_framework", {})
    if framework is None:
        framework = {}
    if not isinstance(framework, dict):
        raise SystemExit("agent_framework must contain a mapping")
    options = framework.get("opencode", {})
    if not isinstance(options, dict) or set(options) - {"preserve_project_config", "role_aliases"}:
        raise SystemExit("agent_framework.opencode has unknown or invalid options")
    preserve = options.get("preserve_project_config", False)
    aliases = options.get("role_aliases", {})
    if type(preserve) is not bool or not isinstance(aliases, dict):
        raise SystemExit("OpenCode preservation must be boolean and role_aliases a mapping")
    for role, name in aliases.items():
        if role not in role_ids or not isinstance(name, str) or not re.fullmatch(r"[a-z0-9][a-z0-9-]*", name):
            raise SystemExit("OpenCode aliases require a known role and a safe output ID")
    names = [aliases.get(role, role) for role in role_ids]
    if len(names) != len(set(names)) or set(names) & {"af-supervised-writer", "af-supervised-readonly"}:
        raise SystemExit("OpenCode role aliases collide with another generated agent")
    if preserve:
        config = REPO_ROOT / "opencode.json"
        if config.is_symlink() or not config.is_file():
            raise SystemExit("OpenCode preservation requires an existing regular opencode.json")
        try:
            data = json.loads(config.read_text(encoding="utf-8"))
        except (ValueError, UnicodeError) as exc:
            raise SystemExit("Preserved opencode.json must contain valid UTF-8 JSON") from exc
        if not isinstance(data, dict):
            raise SystemExit("Preserved opencode.json must contain a JSON object")
        manifest_path = REPO_ROOT / "agent-framework/generated-manifest.json"
        prior = json.loads(manifest_path.read_text(encoding="utf-8")) if manifest_path.exists() else {}
        for name in ("af-supervised-writer", "af-supervised-readonly"):
            rel = f".opencode/agents/{name}.md"
            profile = REPO_ROOT / rel
            if any(parent.is_symlink() for parent in (REPO_ROOT / ".opencode", profile.parent, profile)):
                raise SystemExit("Preserved OpenCode mode refuses symlinked reserved profiles")
            if not profile.exists():
                continue
            entry = prior.get("files", {}).get(rel, {})
            if (not profile.is_file() or entry.get("mode") != "full"
                    or entry.get("sha256") != hashlib.sha256(profile.read_bytes()).hexdigest()):
                raise SystemExit("Preserved OpenCode mode refuses unowned or modified reserved profiles")
    return preserve, aliases


def team_options(root=None) -> dict | None:
    """Return validated opt-in team settings; omission preserves legacy behavior."""
    path = (root or REPO_ROOT) / "project.yaml"
    project = yaml.safe_load(path.read_text(encoding="utf-8")) if path.exists() else {}
    if project is None:
        project = {}
    if not isinstance(project, dict):
        raise SystemExit("project.yaml must contain a mapping")
    framework = project.get("agent_framework", {})
    if framework is None:
        framework = {}
    if not isinstance(framework, dict):
        raise SystemExit("agent_framework must contain a mapping")
    if "team" not in framework:
        return None
    team = framework["team"]
    if not isinstance(team, dict) or set(team) - {"default_mode", "max_parallel_workers"}:
        raise SystemExit("agent_framework.team has unknown or invalid options")
    mode = team.get("default_mode", "advise")
    workers = team.get("max_parallel_workers", 3)
    if mode not in ("advise", "execute"):
        raise SystemExit("agent_framework.team.default_mode must be advise or execute")
    if type(workers) is not int or not 1 <= workers <= 3:
        raise SystemExit("agent_framework.team.max_parallel_workers must be an integer from 1 to 3")
    return {"default_mode": mode, "max_parallel_workers": workers}

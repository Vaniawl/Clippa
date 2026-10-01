#!/usr/bin/env python3
"""Add the Apple team to an existing app without replacing its app tooling.

Requires a local, committed ios-starter checkout and Python with PyYAML. There
are no network calls, global settings changes, native tests, or CI replacements.
An explicit source ancestor --baseline-ref can prove legacy template bytes;
there is deliberately no --adopt escape hatch for customized framework files.
Dry-run performs the same render in isolation and leaves the target untouched.
"""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import shutil
import stat
import subprocess
import sys
import tempfile

try:
    import yaml
except ImportError:
    raise SystemExit("install-apple-team.py requires PyYAML; use a Python environment with PyYAML installed")

SOURCE_URL = "https://github.com/Vaniawl/ios-starter.git"
SCRIPT_DIR = Path(__file__).resolve().parent
ROOTS = ("agent-framework", "scripts/agent-framework", "tests/agent-framework",
         ".agents", ".claude", ".codex", ".kimi-code", ".opencode", ".aiassistant")
ROOT_FILES = ("AGENTS.md", "CLAUDE.md", "project.yaml", ".gitignore", "opencode.json")
REQUIRED_SKILLS = ("apple-team", "product-discovery", "market-validation",
                   "apple-experience-design", "product-copy", "product-positioning",
                   "app-store-marketing", "product-measurement", "architecture-review",
                   "feature-slice", "resource-safety", "security-review", "ui-ux-review",
                   "debug-systematically", "release-readiness", "ios-development",
                   "ios-testing", "ios-quality")
EXCLUDED = {"scripts/ci.sh", "scripts/validate-repository.sh"}
PAYLOAD_MANIFEST = "agent-framework/.framework-payload.json"
GENERATED_MANIFEST = "agent-framework/generated-manifest.json"
ADDITIVE_FILES = {
    "BACKLOG.md": "# Backlog\n\n## Candidates\n\nUnapproved ideas and findings; implementation needs owner authorization.\n",
    "docs/adr/.gitkeep": "",
    "scripts/build.sh": "#!/usr/bin/env bash\nset -euo pipefail\necho 'NOT RUN: configure this script with the existing app build command before using it as evidence.' >&2\nexit 2\n",
    "scripts/test.sh": "#!/usr/bin/env bash\nset -euo pipefail\necho 'NOT RUN: configure this script with the existing app test command before using it as evidence.' >&2\nexit 2\n",
}


class Refused(Exception):
    """Unproven ownership, invalid input, or a concurrent edit."""


def load_module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


def digest(data):
    return hashlib.sha256(data).hexdigest()


def git(source, *args):
    result = subprocess.run(["git", "-C", str(source), *args], capture_output=True,
                            timeout=30, check=False)
    if result.returncode:
        raise Refused("git source check failed: " + result.stderr.decode(errors="replace").strip())
    return result.stdout


def safe_path(root, rel):
    if not isinstance(rel, str) or not rel or "\0" in rel:
        raise Refused(f"invalid managed path: {rel!r}")
    p = Path(rel)
    if p.is_absolute() or ".." in p.parts:
        raise Refused(f"unsafe managed path: {rel!r}")
    out = root
    for part in p.parts:
        out = out / part
        if out.is_symlink():
            raise Refused(f"symlink in managed path: {rel}")
    if out.exists() and not out.is_file():
        raise Refused(f"managed file is not a regular file: {rel}")
    return out


def read_manifest(root, rel):
    path = safe_path(root, rel)
    if not path.exists():
        return {"files": {}}
    try:
        value = json.loads(path.read_text())
    except (ValueError, UnicodeError) as exc:
        raise Refused(f"invalid {rel}: {exc}") from exc
    if not isinstance(value, dict) or not isinstance(value.get("files"), dict):
        raise Refused(f"{rel} must contain a files mapping")
    for key in value["files"]:
        safe_path(root, key)
    return value


def scoped(rel):
    return (rel in ROOT_FILES or any(rel == p or rel.startswith(p + "/") for p in ROOTS)
            or rel == "scripts/create-worktree.sh")


def block_body(data):
    text = data.decode("utf-8")
    matches = list(re.finditer(r"<!-- AGENT-FRAMEWORK:BEGIN[^\n]*\n(.*?)<!-- AGENT-FRAMEWORK:END -->", text, re.S))
    if len(matches) > 1 or ("AGENT-FRAMEWORK:BEGIN" in text and not matches):
        raise Refused("malformed or duplicate framework managed blocks")
    return matches[0].group(1).encode() if matches else None


def source_provenance(source, baseline_refs):
    if Path(git(source, "rev-parse", "--show-toplevel").decode().strip()).resolve() != source:
        raise Refused("--from must name the source Git repository root")
    head = git(source, "rev-parse", "HEAD^{commit}").decode().strip()
    refs = [head]
    for ref in baseline_refs:
        if ref.startswith("-"):
            raise Refused("baseline refs cannot start with '-'")
        commit = git(source, "rev-parse", "--verify", ref + "^{commit}").decode().strip()
        git(source, "merge-base", "--is-ancestor", commit, head)
        if commit not in refs:
            refs.append(commit)
    hashes, blocks, head_hashes = {}, {}, {}
    for commit in refs:
        entries = git(source, "ls-tree", "-rz", commit).split(b"\0")
        candidates = []
        for entry in entries:
            if not entry:
                continue
            info, name = entry.split(b"\t", 1)
            mode, kind, blob = info.split()
            rel = name.decode("utf-8")
            if kind == b"blob" and mode != b"120000" and scoped(rel):
                candidates.append((rel, blob))
        # A single bounded Git batch avoids a subprocess per skill/provider file.
        result = subprocess.run(["git", "-C", str(source), "cat-file", "--batch"],
                                input=b"".join(blob + b"\n" for _, blob in candidates),
                                capture_output=True, timeout=30, check=True)
        offset = 0
        for rel, _ in candidates:
            end = result.stdout.index(b"\n", offset)
            size = int(result.stdout[offset:end].rsplit(b" ", 1)[1])
            data = result.stdout[end + 1:end + 1 + size]
            offset = end + 2 + size
            hashes.setdefault(rel, set()).add(digest(data))
            if commit == head:
                head_hashes[rel] = digest(data)
            if rel in ("AGENTS.md", "CLAUDE.md"):
                body = block_body(data)
                if body is not None:
                    blocks.setdefault(rel, set()).add(digest(body))
            if rel == PAYLOAD_MANIFEST:
                # Only metadata read from an approved SOURCE commit contributes
                # legacy vendor hashes, never arbitrary target declarations.
                old = json.loads(data)
                for path, value in old.get("files", {}).items():
                    if scoped(path) and isinstance(value, str) and re.fullmatch(r"[0-9a-f]{64}", value):
                        hashes.setdefault(path, set()).add(value)
    return head, refs[1:], hashes, blocks, head_hashes


def project_options(stage, source, prior_generated, hashes):
    path = safe_path(stage, "project.yaml")
    text = path.read_text() if path.exists() else ""
    data = yaml.safe_load(text)
    if data is None:
        data = {}
    if not isinstance(data, dict):
        raise Refused("project.yaml must contain a mapping")
    framework = data.get("agent_framework") or {}
    if not isinstance(framework, dict):
        raise Refused("agent_framework must contain a mapping")
    skills = framework.get("skills", [])
    if not isinstance(skills, list) or any(not isinstance(item, str) for item in skills):
        raise Refused("agent_framework.skills must contain skill IDs")
    framework["skills"] = list(dict.fromkeys(skills + list(REQUIRED_SKILLS)))
    # Existing explicit preferences are user-owned, including sequential teams.
    framework.setdefault("team", {"default_mode": "advise", "max_parallel_workers": 3})
    if "macos" in json.dumps(data).lower() or "multiplatform" in json.dumps(data).lower():
        if "macos-development" not in framework["skills"]:
            framework["skills"].append("macos-development")
    config = safe_path(stage, "opencode.json")
    if config.exists():
        if not isinstance(json.loads(config.read_text()), dict):
            raise Refused("opencode.json must contain an object")
        options = framework.setdefault("opencode", {})
        if not isinstance(options, dict):
            raise Refused("agent_framework.opencode must contain a mapping")
        options["preserve_project_config"] = True
        aliases = options.setdefault("role_aliases", {})
        if not isinstance(aliases, dict):
            raise Refused("OpenCode role aliases must contain a mapping")
        roles = [p.stem for p in (source / "agent-framework/canonical/roles").glob("*.yaml")]
        occupied = {aliases.get(role, role) for role in roles}
        for role in sorted(roles):
            rel = f".opencode/agents/{aliases.get(role, role)}.md"
            profile = safe_path(stage, rel)
            if not profile.exists():
                continue
            current = digest(profile.read_bytes())
            entry = prior_generated.get("files", {}).get(rel, {})
            if current == entry.get("sha256") or current in hashes.get(rel, set()):
                continue
            if entry or "GENERATED from" in profile.read_text() or "GENERATED by scripts/agent-framework/render.py" in profile.read_text():
                raise Refused(f"customized generated profile: {rel}")
            candidate = "apple-team-" + role
            count = 2
            while candidate in occupied or (stage / f".opencode/agents/{candidate}.md").exists():
                candidate = f"apple-team-{role}-{count}"
                count += 1
            aliases[role] = candidate
            occupied.add(candidate)
    # Replace only the framework node. All text outside it stays byte-identical.
    node = yaml.compose(text)
    span = None
    if node:
        for key, value in node.value:
            if key.value == "agent_framework":
                if span is not None:
                    raise Refused("duplicate agent_framework blocks")
                span = (key.start_mark.index, value.end_mark.index)
    replacement = yaml.safe_dump({"agent_framework": framework}, sort_keys=False)
    if span:
        text = text[:span[0]] + replacement + text[span[1]:]
    else:
        text += ("\n" if text and not text.endswith("\n") else "") + replacement
    path.write_text(text)


def snapshot(root):
    files = {}
    for parent, dirs, names in os.walk(root, followlinks=False):
        dirs[:] = [d for d in dirs if d not in {"__pycache__", ".git", "runs", ".pytest_cache"}]
        for name in names:
            path = Path(parent) / name
            rel = path.relative_to(root).as_posix()
            if path.is_symlink():
                raise Refused(f"symlink in selected framework scope: {rel}")
            files[rel] = (digest(path.read_bytes()), stat.S_IMODE(path.stat().st_mode))
        for name in dirs:
            if (Path(parent) / name).is_symlink():
                raise Refused(f"symlink in selected framework scope: {(Path(parent) / name).relative_to(root)}")
    return files


def copy_selected(target, stage, updater):
    for rel in ROOTS:
        src = target / rel
        if src.is_symlink():
            raise Refused(f"symlink in managed root: {rel}")
        if src.exists():
            shutil.copytree(src, stage / rel, symlinks=True,
                            ignore=shutil.ignore_patterns("__pycache__", "runs", ".pytest_cache"))
    for rel in (*ROOT_FILES, *updater.PROJECT_SCAFFOLD, *ADDITIVE_FILES, "docs/research/.gitkeep", "scripts/create-worktree.sh"):
        src = safe_path(target, rel)
        if src.exists():
            dest = stage / rel
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(src, dest)


def render_plan(stage):
    code = "import json,render; r=render.Renderer(); print(json.dumps({'manifest':r.manifest(),'full_files':r.full_files,'blocks':r.blocks}))"
    result = subprocess.run([sys.executable, "-B", "-c", code], cwd=stage / "scripts/agent-framework",
                            capture_output=True, text=True, timeout=60)
    if result.returncode:
        raise Refused("renderer configuration check failed: " + (result.stderr or result.stdout).strip())
    return json.loads(result.stdout)


def verify_generated(stage, plan, prior, hashes, blocks):
    entries = dict(prior.get("files", {}))
    for rel, content in plan["full_files"].items():
        path = safe_path(stage, rel)
        if not path.exists():
            continue
        current = digest(path.read_bytes())
        entry = entries.get(rel, {})
        if (current != digest(content.encode()) and current != entry.get("sha256")
                and current not in hashes.get(rel, set())):
            raise Refused(f"customized or unowned generated file: {rel}")
        # Seed provenance ONLY for a byte-proven collision, not source manifest.
        entries[rel] = {"mode": "full", "sha256": current}
    for rel, content in plan["blocks"].items():
        path = safe_path(stage, rel)
        body = block_body(path.read_bytes()) if path.exists() else None
        if body is None or (body == b"" and rel not in entries):
            continue
        current = digest(body)
        entry = entries.get(rel, {})
        if current not in {entry.get("sha256"), digest(content.encode())} and current not in blocks.get(rel, set()):
            raise Refused(f"customized managed framework block: {rel}")
    # Unknown stale records never gain permission to delete unrelated app files.
    for rel, entry in entries.items():
        if not scoped(rel) or not isinstance(entry, dict):
            raise Refused(f"invalid generated ownership record: {rel}")
        safe_path(stage, rel)
    prior["files"] = entries
    safe_path(stage, GENERATED_MANIFEST).write_text(json.dumps(prior, indent=2) + "\n")


def commit_changes(target, stage, before, after):
    """Reuse the renderer's exclusive staging/rollback transaction primitives."""
    renderer = load_module("apple_team_renderer", SCRIPT_DIR / "render.py")
    renderer.REPO_ROOT = target
    guard = object.__new__(renderer.Renderer)
    changed = sorted(rel for rel in before.keys() | after.keys() if before.get(rel) != after.get(rel))
    changed.sort(key=lambda rel: (rel in {GENERATED_MANIFEST, PAYLOAD_MANIFEST}, rel))
    staged, undo, old_modes, made_dirs = {}, [], {}, []
    try:
        for rel in changed:
            path = guard.safe_target(rel)
            actual = (digest(path.read_bytes()), stat.S_IMODE(path.stat().st_mode)) if path.exists() else None
            if actual != before.get(rel):
                raise Refused(f"target changed while planning: {rel}")
        for rel in changed:
            path = guard.safe_target(rel)
            parent = path.parent
            missing = []
            while not parent.exists():
                missing.append(parent)
                parent = parent.parent
            for parent in reversed(missing):
                parent.mkdir()
                made_dirs.append(parent)
            if rel in after:
                staged[path] = renderer.Renderer._stage(path, (stage / rel).read_bytes())
                staged[path].chmod(after[rel][1])
        for rel in changed:
            path = guard.safe_target(rel)
            old = path.read_bytes() if path.exists() else None
            old_modes[path] = stat.S_IMODE(path.stat().st_mode) if path.exists() else None
            # Recheck immediately before mutation as well as during preflight.
            actual = (digest(old), old_modes[path]) if old is not None else None
            if actual != before.get(rel):
                raise Refused(f"target changed during commit: {rel}")
            if rel in after:
                os.replace(staged[path], path)
                staged.pop(path)
            else:
                path.unlink()
            undo.append((path, old))
    except BaseException:
        renderer.Renderer._rollback(undo, staged)
        for path, _ in undo:
            if old_modes.get(path) is not None and path.exists():
                path.chmod(old_modes[path])
        for parent in reversed(made_dirs):
            try:
                parent.rmdir()
            except OSError:
                pass
        raise
    return changed


def install(source, target, baseline_refs=(), dry_run=False):
    source, target = Path(source).resolve(), Path(target).resolve()
    if source == target or (target / "agent-framework/.framework-source").exists():
        raise Refused("target is a framework source checkout; self-install is prohibited")
    if not target.is_dir():
        raise Refused("target must be an existing repository directory")
    updater = load_module("apple_team_updater", SCRIPT_DIR / "update-framework.py")
    try:
        updater.validate_template_checkout(source, "local --from source")
    except updater.Failed as exc:
        raise Refused(str(exc)) from exc
    head, baselines, hashes, blocks, head_hashes = source_provenance(source, baseline_refs)
    updater.PAYLOAD = [p for p in updater.PAYLOAD if p not in EXCLUDED]
    payload = updater.payload_files(source)
    for rel in payload:
        safe_path(source, rel)
    expected_payload = {rel for rel in head_hashes
                        if any(rel == p or rel.startswith(p + "/") for p in updater.PAYLOAD)
                        and not set(Path(rel).parts) & updater.PAYLOAD_EXCLUDE_DIRS
                        and not rel.endswith(updater.PAYLOAD_EXCLUDE_SUFFIXES)}
    dirty = sorted((set(payload) ^ expected_payload) |
                   {rel for rel, path in payload.items() if digest(path.read_bytes()) != head_hashes.get(rel)})
    if dirty and not dry_run:
        raise Refused("source payload must be committed before installation: " + ", ".join(dirty[:12]))
    prior_payload = read_manifest(target, PAYLOAD_MANIFEST)
    prior_generated = read_manifest(target, GENERATED_MANIFEST)
    updater.KNOWN_BASELINE_HASHES = hashes
    report = updater.Report(dry_run)
    with tempfile.TemporaryDirectory(prefix="apple-team-install-") as tmp:
        stage = Path(tmp)
        copy_selected(target, stage, updater)
        before = snapshot(stage)
        updater.set_target_root(stage)
        filtered_prior = {"files": {p: h for p, h in prior_payload["files"].items()
                                    if p not in EXCLUDED and any(p == x or p.startswith(x + "/") for x in updater.PAYLOAD)}}
        try:
            shipped = updater.sync_payload(source, stage, filtered_prior, False, report)
        except updater.Refused as exc:
            raise Refused("customized payload: " + ", ".join(report.conflicts)) from exc
        # sync_payload reads the source again. Verify the bytes actually staged,
        # so a concurrent source edit cannot receive the old commit's provenance.
        if not dry_run and (set(shipped) != expected_payload or
                            any(value != head_hashes.get(rel) for rel, value in shipped.items())):
            raise Refused("source payload changed after the committed-source check")
        # Seed only exact source-proven reserved OpenCode profiles before its
        # preservation validator runs. Its custom project JSON stays untouched.
        for name in ("af-supervised-writer", "af-supervised-readonly"):
            rel = f".opencode/agents/{name}.md"
            path = safe_path(stage, rel)
            if path.exists() and digest(path.read_bytes()) in hashes.get(rel, set()):
                prior_generated["files"][rel] = {"mode": "full", "sha256": digest(path.read_bytes())}
        (stage / "agent-framework").mkdir(exist_ok=True)
        (stage / GENERATED_MANIFEST).write_text(json.dumps(prior_generated) + "\n")
        project_options(stage, source, prior_generated, hashes)
        for rel, body in updater.PROJECT_SCAFFOLD.items():
            path = safe_path(stage, rel)
            if not path.exists():
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(body)
        for rel, body in ADDITIVE_FILES.items():
            path = safe_path(stage, rel)
            if not path.exists():
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(body)
                if rel.endswith(".sh"):
                    path.chmod(0o755)
        updater.ensure_research_dir(stage, report)
        updater.ensure_gitignore(stage, report)
        for name in ("AGENTS.md", "CLAUDE.md"):
            updater.ensure_markers(stage, name, report)
        # Preserve existing local settings byte-for-byte; baseline only when absent.
        settings = safe_path(stage, ".claude/settings.json")
        if not settings.exists() and (source / ".claude/settings.json").is_file():
            safe_path(source, ".claude/settings.json")
            settings_data = (source / ".claude/settings.json").read_bytes()
            if not dry_run and digest(settings_data) != head_hashes.get(".claude/settings.json"):
                raise Refused("source Claude settings are not committed")
            updater.write_file(settings, settings_data)
        plan = render_plan(stage)
        verify_generated(stage, plan, prior_generated, hashes, blocks)
        for args in ([], ["--check"]):
            result = subprocess.run([sys.executable, "-B", "scripts/agent-framework/render.py", *args],
                                    cwd=stage, capture_output=True, text=True, timeout=90)
            if result.returncode:
                raise Refused("isolated render failed: " + (result.stderr or result.stdout).strip())
        metadata = {"framework_version": (stage / "agent-framework/VERSION").read_text().strip(),
                    "template": "ios-starter", "source_url": SOURCE_URL, "source_commit": head,
                    "baseline_commits": baselines, "files": shipped,
                    "scaffold": prior_payload.get("scaffold", {})}
        (stage / PAYLOAD_MANIFEST).write_text(json.dumps(metadata, indent=2) + "\n")
        after = snapshot(stage)
        changed = sorted(rel for rel in before.keys() | after.keys() if before.get(rel) != after.get(rel))
        if not dry_run:
            if git(source, "rev-parse", "HEAD^{commit}").decode().strip() != head:
                raise Refused("source HEAD changed while planning installation")
            if any(digest((stage / rel).read_bytes()) != head_hashes.get(rel) for rel in shipped):
                raise Refused("staged payload no longer matches the source commit")
            commit_changes(target, stage, before, after)
    return {"status": "PASS", "dry_run": dry_run, "source_commit": head,
            "source_dirty_preview": dirty, "baseline_commits": baselines,
            "changed": changed, "structural_render": "PASS",
            "repository_checks": "NOT RUN", "native_execution": "NOT RUN",
            "preserved": ["native app files", "all workflows", "scripts/ci.sh",
                          "scripts/validate-repository.sh", "existing project documents",
                          "existing provider settings and OpenCode custom agents"]}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--from", dest="source", required=True, help="local ios-starter Git checkout")
    parser.add_argument("--target", required=True)
    parser.add_argument("--baseline-ref", action="append", default=[], help="approved source ancestor commit/tag; repeatable")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    try:
        print(json.dumps(install(args.source, args.target, args.baseline_ref, args.dry_run), indent=2))
        return 0
    except (Refused, ValueError, OSError, yaml.YAMLError, subprocess.SubprocessError) as exc:
        print(json.dumps({"status": "REFUSED", "reason": str(exc)}, indent=2), file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())

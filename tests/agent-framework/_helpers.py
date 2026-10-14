"""Shared helpers for the agent-framework regression tests. Stdlib only."""
from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent.parent
SCRIPTS = REPO_ROOT / "scripts" / "agent-framework"
EXCLUDE = {
    ".build",
    ".git",
    ".idea",
    ".swiftpm",
    "DerivedData",
    "node_modules",
    "__pycache__",
    "runs",
}


def copy_repo(dst: Path) -> Path:
    """Copy the repository (sans .git/runs/caches) so mutation tests never touch
    the real working tree."""
    def ignore(directory, names):
        return [n for n in names if n in EXCLUDE]
    shutil.copytree(REPO_ROOT, dst, ignore=ignore, symlinks=True)
    return dst


def run(cmd: list[str], cwd: Path, env: dict | None = None,
        timeout: int = 300) -> subprocess.CompletedProcess:
    e = os.environ.copy()
    if env:
        e.update(env)
    # stdin=DEVNULL: tests must behave identically under a TTY, a pipe, or CI.
    return subprocess.run(cmd, cwd=cwd, env=e, stdin=subprocess.DEVNULL,
                          capture_output=True, text=True, timeout=timeout)


def render(repo: Path, *args: str) -> subprocess.CompletedProcess:
    return run([sys.executable, "scripts/agent-framework/render.py", *args], cwd=repo)


def validate(repo: Path) -> subprocess.CompletedProcess:
    return run([sys.executable, "scripts/agent-framework/validate.py"], cwd=repo)


def check_drift(repo: Path) -> subprocess.CompletedProcess:
    return run([sys.executable, "scripts/agent-framework/check-drift.py"], cwd=repo)


def scratch_dir() -> Path:
    return Path(tempfile.mkdtemp(prefix="af-test-"))


def is_template_source(root: Path) -> bool:
    """A downstream foundation does not own its host app's CI, even in a fork
    that separately remains a framework development home.
    """
    candidate = (root / 'agent-framework/.framework-source').is_file() or (
        (root / 'scripts/bootstrap.py').is_file()
        and not (root / '.project-initialized').exists()
        and not (root / '.project-initialized').is_symlink()
    )
    try:
        metadata = json.loads((root / 'agent-framework/.framework-payload.json').read_text())
    except (OSError, ValueError):
        return candidate
    installed = (isinstance(metadata, dict) and metadata.get('template') == 'ios-starter'
                 and metadata.get('source_url') == 'https://github.com/Vaniawl/ios-starter.git'
                 and isinstance(metadata.get('source_commit'), str)
                 and re.fullmatch(r'[0-9a-f]{40}', metadata['source_commit']))
    return candidate and not installed


IS_TEMPLATE_SOURCE = is_template_source(REPO_ROOT)


def source_asset(name: str) -> Path:
    """Test source-owned assets without requiring an adopter's CI to match them."""
    originals = {'quality.yml': REPO_ROOT / '.github/workflows/quality.yml',
                 'adr-template.md': REPO_ROOT / 'docs/adr/0000-template.md',
                 'permissions.json': REPO_ROOT / '.claude/settings.json'}
    if IS_TEMPLATE_SOURCE:
        return originals[name]
    return Path(__file__).parent / 'fixtures/source-assets' / name


def updater_source_fixture(dst: Path) -> Path:
    """A neutral framework source in scratch; never installs CI into the host app."""
    import importlib.util
    spec = importlib.util.spec_from_file_location('test_source_updater', SCRIPTS / 'update-framework.py')
    updater = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = updater
    spec.loader.exec_module(updater)
    for relative, source in updater.payload_files(REPO_ROOT).items():
        target = dst / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, target)
    for name, relative in [('quality.yml', '.github/workflows/quality.yml'),
                           ('adr-template.md', 'docs/adr/0000-template.md')]:
        target = dst / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source_asset(name), target)
    settings = dst / '.claude/settings.json'
    settings.parent.mkdir(parents=True, exist_ok=True)
    settings.write_text(json.dumps({'permissions': json.loads(
        source_asset('permissions.json').read_text())['permissions']}, indent=2) + '\n')
    (dst / 'agent-framework/.framework-payload.json').write_text(json.dumps({
        'framework_version': 'fixture', 'files': {}, 'scaffold': {}}))
    return dst


def write_mock_cli(bin_dir: Path, name: str, script: str) -> Path:
    """Install a mock provider CLI on PATH that records its argv."""
    bin_dir.mkdir(parents=True, exist_ok=True)
    p = bin_dir / name
    p.write_text("#!/usr/bin/env bash\n" + script)
    p.chmod(0o755)
    return p


def base_run_config(**overrides) -> dict:
    cfg = {
        "run_id": "t-run",
        "objective": "Regression-test run for the remediated supervisor",
        "provider": "claude",
        "model": "test-model",
        "duration_hours": 1,
        "min_useful_work_minutes": 0.01,
        "scope_boundary": "agent-framework tooling only",
        "definition_of_done": "all backlog tasks complete with evidence",
        "approved_backlog": [{"id": "task-a", "task": "First simulated task"}],
        "budget": {"max_provider_calls": 60},
        "network_policy": {"mode": "open"},
        "command_policy": {"mode": "workspace-write"},
        "max_restarts": 3,
        "heartbeat_seconds": 5,
        "checkpoint_interval_minutes": 5,
        "worktree": {"branch": "main"},
    }
    cfg.update(overrides)
    return cfg


def supervisor(cfg: dict, runs_dir: Path, *args: str, env: dict | None = None,
               timeout: int = 120) -> subprocess.CompletedProcess:
    cfg_path = runs_dir / f"cfg-{cfg.get('run_id', 'x')}.json"
    runs_dir.mkdir(parents=True, exist_ok=True)
    cfg_path.write_text(json.dumps(cfg))
    return run([sys.executable, str(SCRIPTS / "run-autonomous-session.py"),
                "--config", str(cfg_path), "--runs-dir", str(runs_dir), *args],
               cwd=REPO_ROOT, env=env, timeout=timeout)

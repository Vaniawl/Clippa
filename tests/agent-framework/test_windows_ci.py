"""Static contract for the Windows-only Python framework CI gate.

The complete framework suite intentionally remains Linux-only today: provider-shim
tests execute Bash and supervisor tests assert POSIX process-group behavior. This
test keeps that limitation explicit while pinning the portable validation slice.
"""
from __future__ import annotations

import copy
import sys
import unittest
from pathlib import Path

import yaml


REPO_ROOT = Path(__file__).resolve().parent.parent.parent
WORKFLOW = REPO_ROOT / ".github" / "workflows" / "quality.yml"
IS_TEMPLATE_SOURCE = (REPO_ROOT / "agent-framework/.framework-source").is_file() or (
    (REPO_ROOT / "scripts/bootstrap.py").is_file()
    and not (REPO_ROOT / ".project-initialized").exists()
    and not (REPO_ROOT / ".project-initialized").is_symlink()
)


def assert_windows_framework_contract(workflow: dict) -> None:
    assert workflow["permissions"] == {"contents": "read"}
    job = workflow["jobs"]["windows-framework"]
    assert job["runs-on"] == "windows-latest"
    assert job["timeout-minutes"] == 15
    assert "permissions" not in job

    steps = job["steps"]
    assert steps[0].get("uses") == "actions/checkout@v4"
    setup_python = next(step for step in steps
                        if step.get("uses") == "actions/setup-python@v5")
    assert setup_python["with"]["python-version"] == "3.12"
    for step in steps:
        if "uses" in step:
            assert step["uses"].startswith("actions/")
            assert "@v" in step["uses"]
    run_steps = [step for step in steps if "run" in step]
    assert run_steps and all(step.get("shell") == "pwsh" for step in run_steps)
    commands = "\n".join(step["run"] for step in run_steps)
    assert "python -m pip install --disable-pip-version-check --quiet -r requirements-dev.txt" in commands
    requirements = (REPO_ROOT / "requirements-dev.txt").read_text(encoding="utf-8")
    assert "pyyaml==6.0.2" in requirements.lower().splitlines()
    for command in (
        "python scripts/agent-framework/validate.py",
        "python scripts/agent-framework/check-drift.py",
        "tests/agent-framework/test_generated_artifacts.py",
        "tests/agent-framework/test_windows_ci.py",
    ):
        assert command in commands
    assert "scripts/ci.sh" not in commands
    assert "bash" not in commands.lower()


@unittest.skipUnless(
    IS_TEMPLATE_SOURCE,
    "Windows workflow contract belongs to the template source; adopter CI is project-owned.",
)
class TestWindowsFrameworkCI(unittest.TestCase):
    def workflow(self) -> dict:
        return yaml.safe_load(WORKFLOW.read_text(encoding="utf-8"))

    def test_windows_framework_job_is_explicit_and_read_only(self):
        assert_windows_framework_contract(self.workflow())

    def test_negative_control_rejects_non_windows_runner(self):
        """Proves the contract test fails if the Windows runner pin is weakened."""
        broken = copy.deepcopy(self.workflow())
        broken["jobs"]["windows-framework"]["runs-on"] = "ubuntu-latest"
        with self.assertRaises(AssertionError):
            assert_windows_framework_contract(broken)

    def test_documented_platform_limit_is_not_hidden(self):
        text = WORKFLOW.read_text(encoding="utf-8")
        self.assertIn("provider-shim", text)
        self.assertIn("POSIX process groups", text)


if __name__ == "__main__":
    unittest.main()

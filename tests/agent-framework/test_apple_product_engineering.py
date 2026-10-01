"""Apple policy reachability and preservation through provider rendering/bootstrap."""
from __future__ import annotations

import shutil
import sys
import tomllib
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from _helpers import EXCLUDE, REPO_ROOT, check_drift, render, run, scratch_dir, validate

import yaml

POLICY = "agent-framework/canonical/policies/apple-product-engineering.md"
APPLE_ROLES = (
    "orchestrator", "software-architect", "implementation-engineer", "code-reviewer",
    "qa-test-engineer", "accessibility-reviewer", "performance-reliability-engineer",
    "security-privacy-reviewer", "devops-release-engineer", "ui-ux-designer",
)
APPLE_SKILLS = ("ios-development", "ios-testing", "ios-quality", "macos-development")


class AppleProductEngineeringTests(unittest.TestCase):
    def make_repository(self) -> Path:
        temporary = scratch_dir()
        self.addCleanup(shutil.rmtree, temporary, ignore_errors=True)
        destination = temporary / "repo"
        shutil.copytree(
            REPO_ROOT, destination, symlinks=True,
            ignore=lambda _directory, names: [n for n in names if n in EXCLUDE | {".venv"}],
        )
        return destination

    def assert_success(self, result) -> None:
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_apple_policy_is_reachable_from_provider_entrypoints(self):
        repo = self.make_repository()
        self.assert_success(render(repo))
        self.assertTrue((repo / POLICY).is_file())
        self.assertIn(POLICY, (repo / "AGENTS.md").read_text(encoding="utf-8"))
        self.assertIn("@AGENTS.md", (repo / "CLAUDE.md").read_text(encoding="utf-8"))
        self.assertIn("AGENTS.md", (repo / ".kimi-code/AGENTS.md").read_text(encoding="utf-8"))
        self.assertIn(
            POLICY,
            (repo / ".aiassistant/rules/apple-product-engineering.md").read_text(encoding="utf-8"),
        )
        for role in APPLE_ROLES:
            with self.subTest(role=role):
                codex = tomllib.loads(
                    (repo / f".codex/agents/{role}.toml").read_text(encoding="utf-8")
                )
                self.assertIn(POLICY, codex["developer_instructions"])
                for directory in (".claude", ".kimi-code", ".opencode"):
                    self.assertIn(
                        POLICY,
                        (repo / f"{directory}/agents/{role}.md").read_text(encoding="utf-8"),
                    )
        for skill in (*APPLE_SKILLS, "ui-ux-review"):
            for directory in (".agents", ".claude"):
                with self.subTest(skill=skill, provider=directory):
                    self.assertIn(
                        POLICY,
                        (repo / f"{directory}/skills/{skill}/SKILL.md").read_text(encoding="utf-8"),
                    )
        self.assert_success(check_drift(repo))

    def test_missing_master_policy_fails_validation(self):
        repo = self.make_repository()
        (repo / POLICY).unlink()
        result = validate(repo)
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn(POLICY, result.stdout + result.stderr)

    def test_bootstrap_preserves_policy_and_routing_for_every_apple_profile(self):
        for platform in ("ios", "macos", "multiplatform"):
            with self.subTest(platform=platform):
                repo = self.make_repository()
                before = {
                    path.relative_to(repo): path.read_bytes()
                    for path in (repo / "agent-framework/canonical").rglob("*")
                    if path.is_file()
                }
                agents_before = (repo / "AGENTS.md").read_bytes()
                self.assert_success(run(["git", "init", "-q", "-b", "main"], repo))
                self.assert_success(run(["git", "add", "."], repo))
                self.assert_success(run([
                    "git", "-c", "user.name=Apple Policy Tests",
                    "-c", "user.email=policy-tests@example.invalid",
                    "commit", "-qm", "fixture",
                ], repo))
                self.assert_success(run([
                    sys.executable, "scripts/bootstrap.py", "--platform", platform,
                    "--name", "Policy Fixture", "--bundle-id", "com.example.policyfixture",
                    "--owner", "Fixture Owner", "--description", "A policy integration fixture.",
                ], repo))
                for path, content in before.items():
                    self.assertEqual((repo / path).read_bytes(), content, str(path))
                self.assertEqual((repo / "AGENTS.md").read_bytes(), agents_before)
                self.assertIn(POLICY, (repo / "README.md").read_text(encoding="utf-8"))
                metadata = yaml.safe_load((repo / "project.yaml").read_text(encoding="utf-8"))
                self.assertTrue(set(APPLE_SKILLS) <= set(metadata["agent_framework"]["skills"]))
                self.assert_success(render(repo))
                self.assert_success(check_drift(repo))
                self.assert_success(validate(repo))


if __name__ == "__main__":
    unittest.main()

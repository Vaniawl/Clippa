"""Apple policy reachability and preservation through provider rendering/bootstrap."""
from __future__ import annotations

import shutil
import re
import sys
import tomllib
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from _helpers import EXCLUDE, REPO_ROOT, IS_TEMPLATE_SOURCE, check_drift, render, run, scratch_dir, validate
sys.path.insert(0, str(REPO_ROOT / 'scripts/agent-framework'))
from _markdown import local_links, invalid_local_links

import yaml

POLICY = "agent-framework/canonical/policies/apple-product-engineering.md"
REFERENCE = "agent-framework/canonical/policies/apple-product-engineering-reference.md"
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
        # Reachability covers every Apple specialization, independently of the
        # host app's platform-specific opt-in skill selection.
        metadata_path = repo / "project.yaml"
        metadata = yaml.safe_load(metadata_path.read_text(encoding="utf-8")) or {}
        framework = metadata.setdefault("agent_framework", {})
        framework["skills"] = list(dict.fromkeys(framework.get("skills", []) + list(APPLE_SKILLS)))
        metadata_path.write_text(yaml.safe_dump(metadata, sort_keys=False), encoding="utf-8")
        aliases = framework.get("opencode", {}).get("role_aliases", {})
        self.assert_success(render(repo))
        self.assertTrue((repo / POLICY).is_file())
        self.assertTrue((repo / REFERENCE).is_file())
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
                    profile = aliases.get(role, role) if directory == ".opencode" else role
                    self.assertIn(
                        POLICY,
                        (repo / f"{directory}/agents/{profile}.md").read_text(encoding="utf-8"),
                    )
        for skill in (*APPLE_SKILLS, "ui-ux-review"):
            for directory in (".agents", ".claude"):
                with self.subTest(skill=skill, provider=directory):
                    package = repo / f"{directory}/skills/{skill}"
                    entrypoint = package / "SKILL.md"
                    self.assertTrue(entrypoint.is_file())
                    # Split procedures must remain reachable after provider
                    # packaging, without requiring the entire guide inline.
                    for link in re.findall(r"\]\((references/[^)]+)\)", entrypoint.read_text()):
                        self.assertTrue((package / link).is_file(), link)
                    for reference in (repo / f"agent-framework/canonical/skills/{skill}/references").rglob("*"):
                        if reference.is_file():
                            relative = reference.relative_to(repo / f"agent-framework/canonical/skills/{skill}")
                            installed = package / relative
                            if reference.suffix != '.md':
                                self.assertEqual(installed.read_bytes(), reference.read_bytes())
                                continue
                            source_text, installed_text = reference.read_text(), installed.read_text()
                            self.assertEqual(invalid_local_links(installed_text, installed, repo), [])
                            source_links, installed_links = list(local_links(source_text)), list(local_links(installed_text))
                            self.assertEqual(len(source_links), len(installed_links))
                            canonical = (repo / f'agent-framework/canonical/skills/{skill}').resolve()
                            for source_link, installed_link in zip(source_links, installed_links):
                                target = (reference.parent / source_link[3]).resolve()
                                expected = package / target.relative_to(canonical) if target.is_relative_to(canonical) else target
                                self.assertEqual((installed.parent / installed_link[3]).resolve(), expected.resolve())
                            # Only destinations may change during packaging; all prose remains intact.
                            for start, end, *_ in reversed(source_links):
                                source_text = source_text[:start] + '<resource>' + source_text[end:]
                            for start, end, *_ in reversed(installed_links):
                                installed_text = installed_text[:start] + '<resource>' + installed_text[end:]
                            self.assertEqual(installed_text, source_text)
        self.assert_success(check_drift(repo))

    def test_missing_router_or_reference_fails_validation(self):
        repo = self.make_repository()
        for relative in (POLICY, REFERENCE):
            with self.subTest(missing=relative):
                path = repo / relative
                content = path.read_bytes()
                path.unlink()
                result = validate(repo)
                self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
                self.assertIn(relative, result.stdout + result.stderr)
                path.write_bytes(content)

    @unittest.skipUnless(
        IS_TEMPLATE_SOURCE,
        "Bootstrap profile creation belongs to the template source, not initialized adopters.",
    )
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
                navigation_before = {
                    relative: (repo / relative).read_bytes()
                    for relative in ("agent-framework/CONTEXT.md",
                                     "agent-framework/templates/task-folder/CONTEXT.md")
                }
                self.assertIn(Path(REFERENCE), before)
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
                for relative, content in navigation_before.items():
                    self.assertEqual((repo / relative).read_bytes(), content, relative)
                self.assertIn('# Project context: Policy Fixture', (repo / 'CONTEXT.md').read_text())
                task_index = (repo / 'docs/tasks/CONTEXT.md').read_text()
                self.assertIn('## Active product tasks\n\nNone yet.', task_index)
                self.assertIn('## Source history', task_index)
                self.assert_success(run([sys.executable, 'scripts/validate-context.py'], repo))
                self.assertIn("docs/tasks/CONTEXT.md", (repo / "README.md").read_text())
                self.assertIn(POLICY, (repo / "README.md").read_text(encoding="utf-8"))
                metadata = yaml.safe_load((repo / "project.yaml").read_text(encoding="utf-8"))
                self.assertTrue(set(APPLE_SKILLS) <= set(metadata["agent_framework"]["skills"]))
                self.assert_success(render(repo))
                self.assert_success(check_drift(repo))
                self.assert_success(validate(repo))


if __name__ == "__main__":
    unittest.main()

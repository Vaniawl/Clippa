"""Existing OpenCode policy remains project-owned during framework adoption."""
from __future__ import annotations

import hashlib
import importlib.util
import subprocess
from unittest import mock
import json
import shutil
import sys
import unittest
from pathlib import Path

import yaml
sys.path.insert(0, str(Path(__file__).resolve().parent))
from _helpers import copy_repo, render, check_drift, scratch_dir, validate


class ProjectOpenCodeTests(unittest.TestCase):
    def setUp(self):
        self.tmp = scratch_dir()
        self.repo = copy_repo(self.tmp / 'repo')
        # Exercise the default-to-preserved transition in a disposable fixture even
        # when this test suite is installed in an already-preserved adopter.
        self.options({})
        result = render(self.repo, '--adopt')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def tearDown(self):
        shutil.rmtree(self.tmp)

    def options(self, options):
        path = self.repo / 'project.yaml'
        project = yaml.safe_load(path.read_text(encoding='utf-8'))
        project.setdefault('agent_framework', {})['opencode'] = options
        path.write_text(yaml.safe_dump(project, sort_keys=False), encoding='utf-8')

    def snapshot(self):
        return {str(p.relative_to(self.repo)): hashlib.sha256(p.read_bytes()).hexdigest()
                for p in self.repo.rglob('*') if p.is_file() and '__pycache__' not in p.parts}

    def test_preserves_policy_and_custom_orchestrator_without_supervised_profiles(self):
        config = self.repo / 'opencode.json'
        data = json.loads(config.read_text(encoding='utf-8'))
        data['model'] = 'project/existing-model'
        data['permission']['edit'] = 'ask'
        config.write_text(json.dumps(data, indent=4) + '\n', encoding='utf-8')
        original = config.read_bytes()
        agent = self.repo / '.opencode/agents/orchestrator.md'
        custom = '---\ndescription: Project orchestrator\nmode: primary\n---\nSequential project policy.\n'
        agent.write_text(custom, encoding='utf-8')
        self.options({'preserve_project_config': True, 'role_aliases': {'orchestrator': 'af-orchestrator'}})
        result = render(self.repo)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(config.read_bytes(), original)
        self.assertEqual(agent.read_text(encoding='utf-8'), custom)
        self.assertTrue((self.repo / '.opencode/agents/af-orchestrator.md').is_file())
        self.assertFalse((self.repo / '.opencode/agents/af-supervised-writer.md').exists())
        manifest = json.loads((self.repo / 'agent-framework/generated-manifest.json').read_text())
        self.assertNotIn('opencode.json', manifest['files'])
        self.assertEqual(check_drift(self.repo).returncode, 0)
        self.assertEqual(validate(self.repo).returncode, 0)
        # A second render cannot progressively change the project-owned policy.
        self.assertEqual(render(self.repo).returncode, 0)
        self.assertEqual(config.read_bytes(), original)

    def test_rejects_unsafe_unknown_and_colliding_options_before_writes(self):
        for options in [
            {'role_aliases': {'orchestrator': '../escape'}},
            {'role_aliases': {'unknown-role': 'new-agent'}},
            {'role_aliases': {'orchestrator': 'code-reviewer'}},
            {'role_aliases': {'orchestrator': 'af-supervised-writer'}},
            {'preserve_project_config': 'true'},
            {'preserve_project_confg': True},
        ]:
            with self.subTest(options=options):
                self.options(options)
                before = self.snapshot()
                result = render(self.repo)
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(self.snapshot(), before)

    def test_preservation_keeps_permission_pinning_active(self):
        self.options({'preserve_project_config': True})
        config = self.repo / 'opencode.json'
        data = json.loads(config.read_text())
        data['permission']['bash']['git push --force*'] = 'allow'
        config.write_text(json.dumps(data))
        self.assertEqual(render(self.repo).returncode, 0)
        result = validate(self.repo)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('required bash deny missing or weakened', result.stdout)

    def test_preservation_requires_real_configuration(self):
        self.options({'preserve_project_config': True})
        (self.repo / 'opencode.json').unlink()
        before = self.snapshot()
        self.assertNotEqual(render(self.repo).returncode, 0)
        self.assertEqual(self.snapshot(), before)

    def test_preservation_refuses_unowned_reserved_profiles_before_writes(self):
        self.options({'preserve_project_config': True})
        manifest_path = self.repo / 'agent-framework/generated-manifest.json'
        manifest = json.loads(manifest_path.read_text())
        rel = '.opencode/agents/af-supervised-writer.md'
        manifest['files'].pop(rel)
        manifest_path.write_text(json.dumps(manifest))
        (self.repo / rel).write_text('---\ndescription: Unowned writer\npermission:\n  edit: allow\n---\n')
        before = self.snapshot()
        result = render(self.repo)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('unowned or modified reserved profiles', result.stdout + result.stderr)
        self.assertEqual(self.snapshot(), before)

    def test_preservation_refuses_malformed_json_before_writes(self):
        self.options({'preserve_project_config': True})
        (self.repo / 'opencode.json').write_text('{invalid')
        before = self.snapshot()
        self.assertNotEqual(render(self.repo).returncode, 0)
        self.assertEqual(self.snapshot(), before)


if __name__ == '__main__':
    unittest.main()


class DependencyCacheSecretTests(unittest.TestCase):
    """Only Git-ignored, untracked dependency fixtures leave the hygiene scan."""

    def setUp(self):
        self.tmp = scratch_dir()
        self.repo = self.tmp / "repo"
        self.repo.mkdir()
        subprocess.run(["git", "init", str(self.repo)], check=True, capture_output=True)
        script = Path(__file__).resolve().parents[2] / "scripts/agent-framework/validate.py"
        spec = importlib.util.spec_from_file_location("cache_secret_validator", script)
        self.validator = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(self.validator)
        self.validator.REPO_ROOT = self.repo
        self.validator.FRAMEWORK_DIR = self.repo / "agent-framework"
        self.secret = "token = " + "a" * 24
        (self.repo / ".gitignore").write_text("node_modules/\n")

    def tearDown(self):
        shutil.rmtree(self.tmp, ignore_errors=True)

    def secret_file(self, relative):
        path = self.repo / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(self.secret)
        return path

    def scan(self):
        self.validator.ERRORS.clear()
        self.validator.check_secrets()
        return self.validator.ERRORS

    def test_ignored_dependency_fixture_is_excluded(self):
        self.secret_file(".opencode/node_modules/vendor/example.js")
        self.assertEqual(self.scan(), [])

    def test_tracked_dependency_secret_is_still_detected(self):
        path = self.secret_file(".opencode/node_modules/vendor/tracked.js")
        subprocess.run(["git", "-C", str(self.repo), "add", "-f", str(path)], check=True)
        self.secret_file(".opencode/node_modules/vendor/ignored.js")
        findings = self.scan()
        self.assertEqual(len(findings), 1, findings)
        self.assertIn("tracked.js", findings[0])

    def test_unignored_dependency_secret_is_still_detected(self):
        (self.repo / ".gitignore").write_text("")
        self.secret_file(".opencode/node_modules/vendor/unignored.js")
        self.assertIn("unignored.js", self.scan()[0])

    def test_ignored_normal_provider_secret_is_still_detected(self):
        with (self.repo / ".gitignore").open("a") as out:
            out.write(".opencode/local.json\n")
        self.secret_file(".opencode/local.json")
        self.assertIn("local.json", self.scan()[0])

    def test_git_failure_does_not_authorize_exclusion(self):
        self.secret_file(".opencode/node_modules/vendor/example.js")
        with mock.patch.object(self.validator.subprocess, "run", side_effect=OSError("unavailable")):
            self.assertIn("example.js", self.scan()[0])

    def test_parent_repository_does_not_authorize_exclusion(self):
        self.secret_file(".opencode/node_modules/vendor/example.js")
        result = subprocess.CompletedProcess([], 0, stdout=str(self.tmp).encode())
        with mock.patch.object(self.validator.subprocess, "run", return_value=result):
            self.assertIn("example.js", self.scan()[0])


    def test_unignored_nested_repository_is_scanned(self):
        (self.repo / ".gitignore").write_text("")
        nested = self.repo / ".opencode/node_modules/local-package"
        nested.mkdir(parents=True)
        subprocess.run(["git", "init", str(nested)], check=True, capture_output=True)
        self.secret_file(".opencode/node_modules/local-package/fixture.txt")
        self.assertTrue(any("fixture.txt" in result for result in self.scan()))

    def test_tracked_gitlink_contents_are_scanned(self):
        relative = ".opencode/node_modules/local-package"
        self.secret_file(relative + "/fixture.txt")
        subprocess.run(["git", "-C", str(self.repo), "update-index", "--add", "--cacheinfo",
                        "160000", "1" * 40, relative], check=True, capture_output=True)
        self.assertTrue(any("fixture.txt" in result for result in self.scan()))

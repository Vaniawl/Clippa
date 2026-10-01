"""Safety tests for the additive installer; no native tools or remote Git calls."""
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

import yaml

REPO = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location("install_apple_team", REPO / "scripts/agent-framework/install-apple-team.py")
installer = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(installer)


def put(root, rel, data):
    path = root / rel
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(data)
    return path


def tree(root):
    return {p.relative_to(root).as_posix(): (p.read_bytes(), p.stat().st_mode & 0o777)
            for p in root.rglob("*") if p.is_file() and ".git" not in p.parts}


class InstallerTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source_tmp = tempfile.TemporaryDirectory(prefix="apple-team-source-test-")
        cls.source = Path(cls.source_tmp.name)
        updater = installer.load_module("installer_test_updater", REPO / "scripts/agent-framework/update-framework.py")
        for rel, src in updater.payload_files(REPO).items():
            if rel not in installer.EXCLUDED:
                dst = cls.source / rel
                dst.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(src, dst)
        for rel in ("AGENTS.md", "CLAUDE.md", ".claude/settings.json"):
            if (REPO / rel).is_file():
                dst = cls.source / rel
                dst.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(REPO / rel, dst)
        # Adoption ledgers legitimately prove the current framework bytes. A
        # regression fixture must not inherit that permission from its host app:
        # only the explicit ancestor and synthetic vendor hash below are proof.
        put(cls.source, installer.PAYLOAD_MANIFEST, json.dumps({
            "framework_version": "fixture", "files": {}, "scaffold": {},
        }))
        cls.git("init", "-q")
        cls.git("add", ".")
        cls.git("-c", "user.name=Installer Test", "-c", "user.email=installer@example.invalid", "commit", "-qm", "Committed fixture")
        cls.baseline = cls.git("rev-parse", "HEAD").strip()
        cls.legacy_core = (cls.source / "agent-framework/canonical/core-instructions.md").read_text()
        put(cls.source, "agent-framework/canonical/core-instructions.md", cls.legacy_core + "\n<!-- New committed fixture revision -->\n")
        cls.legacy_policy = "# Earlier vendor policy\nPreserve explicit user scope.\n"
        metadata = json.loads((cls.source / installer.PAYLOAD_MANIFEST).read_text())
        metadata["files"]["agent-framework/canonical/policies/scope-control-policy.md"] = installer.digest(cls.legacy_policy.encode())
        put(cls.source, installer.PAYLOAD_MANIFEST, json.dumps(metadata))
        cls.git("add", ".")
        cls.git("-c", "user.name=Installer Test", "-c", "user.email=installer@example.invalid", "commit", "-qm", "New fixture with known ancestor and vendor provenance")
        cls.commit = cls.git("rev-parse", "HEAD").strip()

    @classmethod
    def git(cls, *args):
        return subprocess.check_output(["git", "-C", str(cls.source), *args], text=True)

    @classmethod
    def tearDownClass(cls):
        cls.source_tmp.cleanup()

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="apple-team-target-test-")
        self.target = Path(self.tmp.name)
        self.addCleanup(self.tmp.cleanup)

    def run_install(self, **kwargs):
        return installer.install(self.source, self.target, **kwargs)

    def test_additive_install_preserves_app_ci_metadata_settings_and_custom_agents(self):
        original = {
            "Sources/Main.swift": "import SwiftUI\n// real app\n",
            "App.xcodeproj/project.pbxproj": "project with custom targets\n",
            "scripts/ci.sh": "#!/bin/sh\n./scripts/test-existing-app.sh\n",
            "scripts/validate-repository.sh": "#!/bin/sh\necho custom validator\n",
            "scripts/build.sh": "#!/bin/sh\necho existing app build\n",
            "scripts/test.sh": "#!/bin/sh\necho existing app tests\n",
            ".github/workflows/app.yml": "name: custom CI\n",
            "PROJECT.md": "# Real app decisions\n",
            "docs/product/product-vision.md": "Real product vision\n",
            ".claude/settings.json": '{"model":"user-model","permissions":{"deny":["custom"]}}\n',
            "opencode.json": '{"model":"local-litellm/user-choice","permission":{"task":"deny"}}\n',
            ".opencode/agents/orchestrator.md": "User orchestrator with custom permissions\n",
        }
        for rel, text in original.items():
            put(self.target, rel, text)
        metadata = "# private app metadata\nproject:\n  name: RealApp\n  owner: Real Owner\n  audience: families\ncustom_product:\n  enabled: true\n"
        put(self.target, "project.yaml", metadata)
        result = self.run_install()
        self.assertEqual(result["structural_render"], "PASS")
        self.assertEqual(result["native_execution"], "NOT RUN")
        for rel, text in original.items():
            self.assertEqual((self.target / rel).read_text(), text, rel)
        merged = (self.target / "project.yaml").read_text()
        self.assertTrue(merged.startswith(metadata))
        framework = yaml.safe_load(merged)["agent_framework"]
        self.assertEqual(framework["team"], {"default_mode": "advise", "max_parallel_workers": 3})
        self.assertEqual(framework["opencode"]["role_aliases"]["orchestrator"], "apple-team-orchestrator")
        self.assertTrue((self.target / ".opencode/agents/apple-team-orchestrator.md").is_file())
        self.assertTrue((self.target / ".codex/agents/implementation-engineer.toml").is_file())
        self.assertNotIn("model =", (self.target / ".codex/config.toml").read_text())
        provenance = json.loads((self.target / installer.PAYLOAD_MANIFEST).read_text())
        self.assertEqual(provenance["source_url"], installer.SOURCE_URL)
        self.assertEqual(provenance["source_commit"], self.commit)
        self.assertNotIn("scripts/ci.sh", provenance["files"])
        self.assertTrue((self.target / "docs/adr/.gitkeep").is_file())

    def test_existing_team_and_role_preferences_survive_and_rerun_is_idempotent(self):
        put(self.target, "opencode.json", '{"model":"user"}\n')
        put(self.target, "project.yaml", "project:\n  name: Existing\nagent_framework:\n  team:\n    default_mode: execute\n    max_parallel_workers: 1\n  skills: [security-review]\n  opencode:\n    role_aliases:\n      orchestrator: user-apple-orchestrator\nother:\n  keep: true\n")
        self.run_install()
        before = tree(self.target)
        framework = yaml.safe_load((self.target / "project.yaml").read_text())["agent_framework"]
        self.assertEqual(framework["team"], {"default_mode": "execute", "max_parallel_workers": 1})
        self.assertEqual(framework["opencode"]["role_aliases"]["orchestrator"], "user-apple-orchestrator")
        self.assertEqual(self.run_install()["changed"], [])
        self.assertEqual(tree(self.target), before)

    def test_dry_run_changes_nothing_and_predicts_apply(self):
        put(self.target, "Sources/Real.swift", "// existing native source\n")
        before = tree(self.target)
        preview = self.run_install(dry_run=True)
        self.assertGreater(len(preview["changed"]), 10)
        self.assertEqual(tree(self.target), before)
        actual = self.run_install()
        self.assertEqual(preview["changed"], actual["changed"])
        gate = subprocess.run([sys.executable, "-B", "scripts/agent-framework/validate.py"],
                              cwd=self.target, text=True, capture_output=True, timeout=60)
        self.assertEqual(gate.returncode, 0, gate.stdout + gate.stderr)
        for rel in ("scripts/build.sh", "scripts/test.sh"):
            result = subprocess.run(["bash", str(self.target / rel)], capture_output=True,
                                    text=True, timeout=10)
            self.assertEqual(result.returncode, 2)
            self.assertIn("NOT RUN", result.stderr)

    def test_modified_canonical_and_generated_files_are_refused_without_writes(self):
        self.run_install()
        for rel in ("agent-framework/canonical/core-instructions.md", ".claude/agents/implementation-engineer.md", ".codex/config.toml"):
            path = self.target / rel
            old = path.read_text()
            path.write_text(old + "\nlocal customization\n")
            before = tree(self.target)
            with self.assertRaises(installer.Refused):
                self.run_install()
            self.assertEqual(tree(self.target), before)
            path.write_text(old)

    def test_managed_outer_text_survives_but_modified_inner_block_is_refused(self):
        put(self.target, "AGENTS.md", "# Custom app instructions\nNever alter signing.\n")
        self.run_install()
        path = self.target / "AGENTS.md"
        self.assertTrue(path.read_text().startswith("# Custom app instructions\nNever alter signing.\n"))
        path.write_text(path.read_text().replace("AGENT-FRAMEWORK:END", "Extra local directive\n<!-- AGENT-FRAMEWORK:END", 1))
        before = tree(self.target)
        with self.assertRaises(installer.Refused):
            self.run_install()
        self.assertEqual(tree(self.target), before)

    def test_source_marker_and_symlinks_refuse_without_external_writes(self):
        put(self.target, "agent-framework/.framework-source", "source marker\n")
        with self.assertRaises(installer.Refused):
            self.run_install()
        (self.target / "agent-framework/.framework-source").unlink()
        external = Path(self.tmp.name).parent / (self.target.name + "-external")
        external.mkdir()
        self.addCleanup(shutil.rmtree, external)
        put(external, "sentinel", "untouched")
        (self.target / ".codex").symlink_to(external, target_is_directory=True)
        with self.assertRaises(installer.Refused):
            self.run_install()
        self.assertEqual(tree(external), {"sentinel": (b"untouched", 0o644)})

    def test_invalid_source_returns_controlled_cli_refusal(self):
        result = subprocess.run([sys.executable, "-B", str(REPO / "scripts/agent-framework/install-apple-team.py"),
                                 "--from", str(self.target / "missing-source"), "--target", str(self.target)],
                                capture_output=True, text=True, timeout=10)
        self.assertEqual(result.returncode, 2)
        self.assertEqual(json.loads(result.stderr)["status"], "REFUSED")
        self.assertNotIn("Traceback", result.stderr)

    def test_proven_source_baseline_allows_legacy_bytes_but_unknown_ref_refuses(self):
        rel = "agent-framework/canonical/core-instructions.md"
        put(self.target, rel, self.legacy_core)
        before = tree(self.target)
        with self.assertRaises(installer.Refused):
            self.run_install()
        self.assertEqual(tree(self.target), before)
        result = self.run_install(baseline_refs=[self.baseline, self.baseline])
        self.assertEqual(result["status"], "PASS")
        self.assertEqual(result["baseline_commits"], [self.baseline])
        before = tree(self.target)
        with self.assertRaises(installer.Refused):
            self.run_install(baseline_refs=["missing-source-commit"])
        self.assertEqual(tree(self.target), before)
        unrelated = self.git("-c", "user.name=Installer Test", "-c", "user.email=installer@example.invalid",
                             "commit-tree", "HEAD^{tree}", "-m", "Unrelated root").strip()
        with self.assertRaises(installer.Refused):
            self.run_install(baseline_refs=[unrelated])
        self.assertEqual(tree(self.target), before)

    def test_committed_source_vendor_hash_is_proof_but_target_claim_is_not(self):
        rel = "agent-framework/canonical/policies/scope-control-policy.md"
        put(self.target, rel, self.legacy_policy)
        self.run_install()
        self.assertEqual((self.target / rel).read_text(), (self.source / rel).read_text())
        # A copied framework marker alone cannot authorize overwriting new edits.
        generated = self.target / ".claude/agents/code-reviewer.md"
        generated.write_text(generated.read_text() + "\nUser change\n")
        before = tree(self.target)
        with self.assertRaises(installer.Refused):
            self.run_install()
        self.assertEqual(tree(self.target), before)

    def test_source_payload_change_between_preflight_and_sync_is_refused(self):
        source_file = self.source / "agent-framework/canonical/core-instructions.md"
        original = source_file.read_text()
        real_loader = installer.load_module

        def racing_loader(name, path):
            module = real_loader(name, path)
            if name == "apple_team_updater":
                real_sync = module.sync_payload

                def race(*args, **kwargs):
                    source_file.write_text(original + "\nUncommitted concurrent edit\n")
                    try:
                        return real_sync(*args, **kwargs)
                    finally:
                        source_file.write_text(original)
                module.sync_payload = race
            return module

        before = tree(self.target)
        with patch.object(installer, "load_module", side_effect=racing_loader):
            with self.assertRaisesRegex(installer.Refused, "changed after"):
                self.run_install()
        self.assertEqual(tree(self.target), before)

    def test_uncommitted_source_payload_deletion_is_refused(self):
        path = self.source / "agent-framework/README.md"
        original = path.read_bytes()
        path.unlink()
        try:
            before = tree(self.target)
            with self.assertRaisesRegex(installer.Refused, "must be committed"):
                self.run_install()
            self.assertEqual(tree(self.target), before)
        finally:
            path.write_bytes(original)

    def test_transaction_failure_restores_bytes_modes_and_new_directories(self):
        stage = Path(tempfile.mkdtemp(prefix="apple-team-stage-test-"))
        self.addCleanup(shutil.rmtree, stage)
        put(self.target, "a.txt", "old\n").chmod(0o755)
        put(stage, "a.txt", "new\n")
        put(stage, "new/nested/b.txt", "new file\n")
        before = installer.snapshot(self.target)
        after = installer.snapshot(stage)
        real_replace = os.replace
        calls = 0

        def fail_second(src, dst):
            nonlocal calls
            calls += 1
            if calls == 2:
                raise OSError("injected mid-commit failure")
            return real_replace(src, dst)

        with patch.object(installer.os, "replace", side_effect=fail_second):
            with self.assertRaises(OSError):
                installer.commit_changes(self.target, stage, before, after)
        self.assertEqual(installer.snapshot(self.target), before)
        self.assertFalse((self.target / "new").exists())
        self.assertFalse(any("tmp-af-render" in p.name for p in self.target.rglob("*")))


if __name__ == "__main__":
    unittest.main()

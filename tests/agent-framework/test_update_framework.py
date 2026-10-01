"""Regressions for the one-command framework installer/updater
(scripts/agent-framework/update-framework.py).

The updater is the supported migration and upgrade path for every repository created
from this template, so its safety properties are pinned here: it must never copy the
adopting repository's generated manifest, never overwrite a file it cannot prove the
framework owns, never remove a locally modified file, and must be idempotent.

Every test runs the updater with `--no-verify` against a scratch downstream repo.
That is REQUIRED, not an optimization: the payload includes this very test suite, so
a verifying run inside a scratch repo would execute these tests recursively. The
end-to-end test therefore runs render/validate/check-drift explicitly instead.
"""
from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from _helpers import REPO_ROOT, SCRIPTS, run, scratch_dir  # noqa: E402

UPDATER = SCRIPTS / "update-framework.py"

# Assembled at runtime rather than written as one literal, and that is the whole point.
# scripts/validate-repository.sh greps the entire tree for this prefix and excludes only
# initialize-project.sh and itself, so any payload file containing it literally — even in
# a comment or an assertion message *about* placeholders — makes validate-repository.sh
# fail in every repository that adopts the framework. v1.1.4 shipped exactly that: a
# comment in update-framework.py and an assertion message in this file, both merely
# mentioning the token, turned adopter CI red. test_no_payload_file_contains_placeholder
# below is the guard.
PLACEHOLDER_PREFIX = "__PROJECT" + "_"
# Present only in the framework source repo; deliberately not part of the payload.
# update-framework.py:630 keys its self-update refusal off this file.
SOURCE_MARKER = REPO_ROOT / "agent-framework" / ".framework-source"

# Project-side content a template-derived repository owns (no framework payload here).
FIXTURE_COPY = [
    "README.md", "PROJECT.md", "SECURITY.md", "CHANGELOG.md", "CONTRIBUTING.md",
    "LICENSE.md", "THIRD_PARTY_NOTICES.md", "docs", ".editorconfig",
    "scripts/build.sh", "scripts/test.sh", ".github/ISSUE_TEMPLATE",
    ".github/pull_request_template.md",
]

OLD_SETTINGS = {
    "autoMemoryEnabled": True,
    "permissions": {
        "deny": [
            "Read(./.env)", "Read(./secrets/**)", "Read(./credentials/**)",
            "Bash(git push --force *)",
            "Bash(curl * | sh)",  # repo-specific hardening: must survive the merge
        ],
        "ask": ["Bash(git reset --hard *)"],
    },
}


def make_downstream(dst: Path) -> Path:
    """A repository created from an older template: project content, no framework."""
    dst.mkdir(parents=True, exist_ok=True)
    for rel in FIXTURE_COPY:
        src = REPO_ROOT / rel
        if not src.exists():
            continue
        out = dst / rel
        out.parent.mkdir(parents=True, exist_ok=True)
        if src.is_dir():
            shutil.copytree(src, out, dirs_exist_ok=True)
        else:
            shutil.copy2(src, out)
    (dst / "AGENTS.md").write_text(
        "# Agent Instructions\n\nProject-owned guidance written by this repository.\n"
        "SENTINEL-PROJECT-TEXT-AGENTS\n", encoding="utf-8")
    (dst / "CLAUDE.md").write_text(
        "# Claude\n\nProject-owned Claude notes.\nSENTINEL-PROJECT-TEXT-CLAUDE\n",
        encoding="utf-8")
    (dst / "BACKLOG.md").write_text("# Backlog\n\n## Now\n\n- Ship the thing\n", encoding="utf-8")
    (dst / "project.yaml").write_text(
        'project:\n  name: "Fixture"\n  slug: "fixture"\n  description: "d"\n'
        '  owner: "o"\n  status: discovery\n', encoding="utf-8")
    (dst / ".gitignore").write_text(".env\nnode_modules/\n", encoding="utf-8")
    (dst / ".claude").mkdir(exist_ok=True)
    (dst / ".claude" / "settings.json").write_text(
        json.dumps(OLD_SETTINGS, indent=2) + "\n", encoding="utf-8")
    for script in ("build.sh", "test.sh"):
        p = dst / "scripts" / script
        if p.exists():
            p.chmod(0o755)
    subprocess.run(["git", "init", "-q"], cwd=dst, check=True)
    subprocess.run(["git", "add", "-A"], cwd=dst, check=True, capture_output=True)
    subprocess.run(["git", "-c", "user.email=t@t", "-c", "user.name=t",
                    "commit", "-qm", "downstream fixture"], cwd=dst, check=True,
                   capture_output=True)
    return dst


class UpdaterTestBase(unittest.TestCase):
    def setUp(self):
        self.tmp = scratch_dir()
        self.repo = make_downstream(self.tmp / "downstream")

    def tearDown(self):
        shutil.rmtree(self.tmp, ignore_errors=True)

    def update(self, *args: str, timeout: int = 300,
               env: dict | None = None) -> subprocess.CompletedProcess:
        """Run the updater against the scratch repo. --no-verify is mandatory here."""
        return run([sys.executable, str(UPDATER), "--from", str(REPO_ROOT),
                    "--target", str(self.repo), "--no-verify", *args],
                   cwd=self.repo, env=env, timeout=timeout)

    def payload_manifest(self) -> dict:
        return json.loads((self.repo / "agent-framework" / ".framework-payload.json")
                          .read_text(encoding="utf-8"))


class TestSafetyContract(UpdaterTestBase):
    def test_clean_repo_migrates_in_one_command(self):
        """A repository with no hand-written provider files needs no --adopt at all."""
        p = self.update()
        self.assertEqual(p.returncode, 0, p.stdout + p.stderr)
        self.assertTrue((self.repo / ".claude" / "agents" / "orchestrator.md").exists())

    def test_generated_manifest_is_never_copied(self):
        """THE data-loss defect this tool exists to prevent: copying the template's
        generated-manifest.json transfers framework ownership of files the adopting
        repo hand-wrote, letting the next render overwrite them with no backup.

        Proven through its consequence: a hand-written file at a generated path must
        make render REFUSE. With a copied manifest it would be silently overwritten.

        Since ADR 0001 decision 5, a refused run also leaves no manifest behind at all
        (the write is rolled back with everything else) — checked here, then confirmed
        directly against a manifest a *successful* run actually persists."""
        victim = self.repo / ".claude" / "rules" / "agent-framework.md"
        victim.parent.mkdir(parents=True, exist_ok=True)
        victim.write_text("# our own pointer file\nHAND-WRITTEN-SENTINEL\n", encoding="utf-8")
        p = self.update()
        self.assertEqual(p.returncode, 2, p.stdout + p.stderr)
        self.assertIn("HAND-WRITTEN-SENTINEL", victim.read_text(encoding="utf-8"))
        self.assertFalse((self.repo / "agent-framework" / ".framework-payload.json").exists(),
                         "a refused run left a payload manifest behind (ADR 0001 decision 5)")
        p2 = self.update("--adopt")
        self.assertEqual(p2.returncode, 0, p2.stdout + p2.stderr)
        self.assertNotIn("agent-framework/generated-manifest.json", self.payload_manifest()["files"])

    @unittest.skipUnless(SOURCE_MARKER.exists(),
                         "template-only invariant: this repository is not the framework "
                         "source, so --target here is not a self-update")
    def test_framework_source_repo_refused_as_target(self):
        """Template-only. The guard above is load-bearing, not tidiness.

        The payload ships this suite into every adopting repo, and the updater's own
        verify() runs `unittest discover` there. Unguarded, this asserts a refusal that
        can only happen in the source repo (update-framework.py:630 keys off the
        SOURCE_MARKER, which correctly does not ship), so it failed in every downstream
        repo and made a correct migration exit 1."""
        p = run([sys.executable, str(UPDATER), "--from", str(REPO_ROOT),
                 "--target", str(REPO_ROOT), "--no-verify", "--dry-run"], cwd=REPO_ROOT)
        self.assertEqual(p.returncode, 1)
        self.assertIn("IS the framework source", p.stdout + p.stderr)

    def test_dry_run_changes_nothing(self):
        before = subprocess.run(["git", "status", "--porcelain"], cwd=self.repo,
                                capture_output=True, text=True).stdout
        p = self.update("--dry-run")
        self.assertEqual(p.returncode, 0, p.stdout + p.stderr)
        after = subprocess.run(["git", "status", "--porcelain"], cwd=self.repo,
                               capture_output=True, text=True).stdout
        self.assertEqual(before, after, "--dry-run modified the working tree")
        self.assertFalse((self.repo / "agent-framework" / "canonical").exists())

    def test_locally_modified_payload_file_refused_then_adopted_with_backup(self):
        self.update("--adopt")  # establish provenance
        victim = self.repo / "agent-framework" / "canonical" / "policies" / "security-policy.md"
        victim.write_text("LOCAL EDIT — must not be silently overwritten\n", encoding="utf-8")
        p = self.update()
        self.assertEqual(p.returncode, 2, p.stdout + p.stderr)
        self.assertIn("security-policy.md", p.stdout)
        self.assertIn("LOCAL EDIT", victim.read_text(encoding="utf-8"))
        p2 = self.update("--adopt")
        self.assertEqual(p2.returncode, 0, p2.stdout + p2.stderr)
        backup = victim.with_name(victim.name + ".bak-pre-framework")
        self.assertTrue(backup.exists(), "adopt overwrote a local edit without a backup")
        self.assertIn("LOCAL EDIT", backup.read_text(encoding="utf-8"))
        self.assertNotIn("LOCAL EDIT", victim.read_text(encoding="utf-8"))

    def test_stale_payload_file_removed_only_when_unmodified(self):
        self.update("--adopt")
        manifest_path = self.repo / "agent-framework" / ".framework-payload.json"
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        # Two files the template no longer ships: one pristine, one locally modified.
        pristine = self.repo / "agent-framework" / "canonical" / "gone-pristine.md"
        modified = self.repo / "agent-framework" / "canonical" / "gone-modified.md"
        pristine.write_text("retired\n", encoding="utf-8")
        modified.write_text("retired\n", encoding="utf-8")
        import hashlib
        h = hashlib.sha256(b"retired\n").hexdigest()
        manifest["files"]["agent-framework/canonical/gone-pristine.md"] = h
        manifest["files"]["agent-framework/canonical/gone-modified.md"] = h
        manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
        modified.write_text("retired\nplus a local change\n", encoding="utf-8")
        p = self.update("--adopt")
        self.assertFalse(pristine.exists(), "unmodified stale payload file was not removed")
        self.assertTrue(modified.exists(), "locally modified stale file was deleted")
        self.assertIn("kept locally modified", p.stdout)


class TestProjectBootstrapping(UpdaterTestBase):
    def test_scaffolding_is_applied_and_project_text_preserved(self):
        self.update("--adopt")
        agents = (self.repo / "AGENTS.md").read_text(encoding="utf-8")
        claude = (self.repo / "CLAUDE.md").read_text(encoding="utf-8")
        self.assertIn("SENTINEL-PROJECT-TEXT-AGENTS", agents)
        self.assertIn("SENTINEL-PROJECT-TEXT-CLAUDE", claude)
        self.assertIn("AGENT-FRAMEWORK:BEGIN", agents)
        self.assertIn("AGENT-FRAMEWORK:END", claude)
        gitignore = (self.repo / ".gitignore").read_text(encoding="utf-8")
        self.assertIn("agent-framework/runs/", gitignore)
        self.assertIn("*.bak-pre-framework", gitignore)  # --adopt backups never committed
        self.assertIn("node_modules/", gitignore)  # existing entries preserved
        self.assertIn("## Candidates", (self.repo / "BACKLOG.md").read_text(encoding="utf-8"))
        self.assertIn("agent_framework:", (self.repo / "project.yaml").read_text(encoding="utf-8"))
        self.assertTrue((self.repo / "docs" / "research" / ".gitkeep").exists())
        self.assertTrue((self.repo / ".github" / "workflows" / "framework-update.yml").exists())

    def test_scaffolding_is_idempotent(self):
        self.update("--adopt")
        first = {p: (self.repo / p).read_text(encoding="utf-8")
                 for p in ("AGENTS.md", "CLAUDE.md", ".gitignore", "BACKLOG.md", "project.yaml")}
        p = self.update("--adopt")
        self.assertEqual(p.returncode, 0, p.stdout + p.stderr)
        for rel, before in first.items():
            after = (self.repo / rel).read_text(encoding="utf-8")
            self.assertEqual(before, after, f"{rel} changed on a second run")
        self.assertEqual((self.repo / "AGENTS.md").read_text(encoding="utf-8")
                         .count("AGENT-FRAMEWORK:BEGIN"), 1)
        self.assertIn("already up to date", p.stdout)

    def test_permission_merge_adds_required_rules_and_keeps_custom_ones(self):
        self.update("--adopt")
        data = json.loads((self.repo / ".claude" / "settings.json").read_text(encoding="utf-8"))
        deny, ask = data["permissions"]["deny"], data["permissions"]["ask"]
        self.assertIn("Bash(git push -f *)", deny)          # required, was missing
        self.assertIn("Bash(rm -rf *)", ask)                # required, was missing
        self.assertIn("Bash(curl * | sh)", deny)            # repo-specific: preserved
        self.assertIn("Bash(git push --force *)", deny)     # pre-existing: preserved
        self.assertTrue(data["autoMemoryEnabled"])          # unrelated keys preserved
        self.assertNotIn("allow", data["permissions"],
                         "the merge must never introduce an allow list")

    def test_permission_merge_never_weakens_or_duplicates(self):
        self.update("--adopt")
        first = (self.repo / ".claude" / "settings.json").read_text(encoding="utf-8")
        self.update("--adopt")
        second = (self.repo / ".claude" / "settings.json").read_text(encoding="utf-8")
        self.assertEqual(first, second, "permission merge is not idempotent")
        data = json.loads(second)
        self.assertEqual(len(data["permissions"]["deny"]),
                         len(set(data["permissions"]["deny"])), "duplicate deny rules")


class TestLegacyRetirement(UpdaterTestBase):
    LEGACY = ".claude/rules/00-core.md"

    def test_modified_legacy_file_is_never_deleted(self):
        p = self.repo / self.LEGACY
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text("# our own rules, not the template baseline\n", encoding="utf-8")
        r = self.update("--adopt", "--retire-legacy")
        self.assertTrue(p.exists(), "a locally modified legacy file was deleted")
        self.assertIn("locally modified", r.stdout)

    def test_unmodified_legacy_file_reported_then_retired(self):
        baseline = subprocess.run(["git", "show", f"a09fbd2:{self.LEGACY}"],
                                  cwd=REPO_ROOT, capture_output=True)
        if baseline.returncode != 0:
            self.skipTest("v1.0 template baseline not available in this checkout")
        p = self.repo / self.LEGACY
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_bytes(baseline.stdout)
        r1 = self.update("--adopt")
        self.assertTrue(p.exists(), "legacy file removed without --retire-legacy")
        self.assertIn("remove with --retire-legacy", r1.stdout)
        self.update("--adopt", "--retire-legacy")
        self.assertFalse(p.exists(), "--retire-legacy did not remove the baseline file")


class TestCustomizedCiPreserved(UpdaterTestBase):
    CUSTOM_CI = ("name: Quality\non: [push]\njobs:\n  custom:\n    runs-on: self-hosted\n"
                 "    steps:\n      - run: echo REPO-SPECIFIC-PIPELINE\n")

    def _write_custom_ci(self) -> Path:
        wf = self.repo / ".github" / "workflows" / "quality.yml"
        wf.parent.mkdir(parents=True, exist_ok=True)
        wf.write_text(self.CUSTOM_CI, encoding="utf-8")
        return wf

    def test_customized_quality_workflow_is_kept_and_reported(self):
        """A repository that tuned its own CI must not have it silently replaced."""
        wf = self._write_custom_ci()
        p = self.update()
        self.assertEqual(p.returncode, 0, p.stdout + p.stderr)
        self.assertIn("REPO-SPECIFIC-PIPELINE", wf.read_text(encoding="utf-8"))
        self.assertIn("kept customized .github/workflows/quality.yml", p.stdout)
        self.assertFalse(wf.with_name(wf.name + ".bak-pre-framework").exists())

    def test_customized_quality_workflow_taken_over_only_with_adopt_and_backup(self):
        wf = self._write_custom_ci()
        p = self.update("--adopt")
        self.assertEqual(p.returncode, 0, p.stdout + p.stderr)
        self.assertNotIn("REPO-SPECIFIC-PIPELINE", wf.read_text(encoding="utf-8"))
        backup = wf.with_name(wf.name + ".bak-pre-framework")
        self.assertTrue(backup.exists(), "adopt replaced the CI workflow without a backup")
        self.assertIn("REPO-SPECIFIC-PIPELINE", backup.read_text(encoding="utf-8"))


class TestAutoUpdateWorkflowAsset(unittest.TestCase):
    """The workflow installed into every adopting repository must be executable and
    free of script injection — it runs with contents:write and pull-requests:write."""

    ASSET = REPO_ROOT / "agent-framework" / "templates" / "framework-update.yml"

    def setUp(self):
        import yaml
        self.wf = yaml.safe_load(self.ASSET.read_text(encoding="utf-8"))

    def test_shell_blocks_are_valid_bash(self):
        import re
        import tempfile
        for step in self.wf["jobs"]["update"]["steps"]:
            if "run" not in step:
                continue
            script = re.sub(r"\$\{\{[^}]*\}\}", "PLACEHOLDER", step["run"])
            with tempfile.NamedTemporaryFile("w", suffix=".sh") as f:
                f.write(script)
                f.flush()
                p = run(["bash", "-n", f.name], cwd=REPO_ROOT)
            self.assertEqual(p.returncode, 0,
                             f"step {step.get('name', 'run')} is not valid bash: {p.stderr}")

    def test_untrusted_inputs_are_never_interpolated_into_shell(self):
        for step in self.wf["jobs"]["update"]["steps"]:
            if "run" in step:
                self.assertNotIn("github.event.inputs", step["run"],
                                 "workflow input interpolated into a run block "
                                 "(script injection); pass it through env: instead")

    def test_workflow_opens_a_pr_and_never_pushes_to_the_default_branch(self):
        steps = "\n".join(s.get("run", "") for s in self.wf["jobs"]["update"]["steps"])
        self.assertIn("gh pr create", steps)
        self.assertIn("--force-with-lease", steps)
        self.assertNotRegex(steps, r"git push[^\n|]*origin\s+(main|master)\b")

    def test_default_token_scope_is_read_only(self):
        """ADR 0001 decision 4: write access is granted at the job that needs it, not
        workflow-wide, and checkout must not leave a write token in .git/config while
        the updater is handling freshly fetched template code."""
        self.assertEqual(self.wf["permissions"], {"contents": "read"})
        checkout = next(s for s in self.wf["jobs"]["update"]["steps"]
                        if str(s.get("uses", "")).startswith("actions/checkout"))
        self.assertIs(checkout["with"]["persist-credentials"], False)

    def test_fetched_code_is_never_executed_in_the_update_job(self):
        """The updater must copy, not run, what it fetched — the gate belongs on the PR."""
        # Match the step that INVOKES the updater, not the one that greps its source
        # for the template URL.
        updater_step = next(s for s in self.wf["jobs"]["update"]["steps"]
                            if 'update-framework.py "${args[@]}"' in s.get("run", ""))
        self.assertIn("--no-verify", updater_step["run"])
        self.assertEqual(updater_step["env"]["AF_REQUIRE_SIGNED_TAG"], "1")

    def test_signature_verification_has_a_usable_trust_anchor(self):
        """AF_REQUIRE_SIGNED_TAG=1 is inoperative without the signer's public key.

        Verified empirically: `git verify-tag` on a signed tag exits 0 with the key in
        the keyring, 1 on a bare runner ("No public key"), and 1 for an unsigned tag.
        A hosted runner starts empty, so without an import step the workflow fails
        closed on every update forever. The anchor must also carry no private half."""
        steps = self.wf["jobs"]["update"]["steps"]
        names = [s.get("name", "") for s in steps]
        anchor_idx = next(i for i, n in enumerate(names) if "trust anchor" in n.lower())
        updater_idx = next(i for i, s in enumerate(steps)
                           if 'update-framework.py "${args[@]}"' in s.get("run", ""))
        self.assertLess(anchor_idx, updater_idx,
                        "the trust anchor must be imported before the updater verifies")
        anchor_step = steps[anchor_idx]["run"]
        self.assertIn("gpg --quiet --import", anchor_step)
        self.assertIn("PRIVATE KEY", anchor_step,
                      "the import step must refuse an anchor containing private material")

        anchor = REPO_ROOT / "agent-framework" / "trust" / "framework-maintainer.asc"
        self.assertTrue(anchor.exists(), f"{anchor} must ship with the framework")
        text = anchor.read_text(encoding="utf-8")
        self.assertIn("BEGIN PGP PUBLIC KEY BLOCK", text)
        self.assertNotIn("PRIVATE KEY", text, "private key material must never be committed")

    def test_no_branch_default_and_no_false_gate_claim(self):
        """ADR 0001 decision 1 removed branch tracking; and once the gate no longer runs
        in this job, any PR text claiming it did would be fabricated evidence."""
        raw = self.ASSET.read_text(encoding="utf-8")
        self.assertNotRegex(raw, r"default:\s*main\b")
        self.assertNotRegex(raw, r"(?i)gate executed.*all green")


def make_independent_repo(dst: Path) -> Path:
    """A repository that was NEVER created from this template.

    Deliberately built WITHOUT the FIXTURE_COPY set: no PROJECT.md, no SECURITY.md, no
    docs/ tree, no scripts/build.sh|test.sh. That omission is the whole point — the
    existing fixture copies those from the template, so every other test in this file
    silently models a template-derived repo and could never catch an adoption gap that
    only an independent repository hits."""
    dst.mkdir(parents=True, exist_ok=True)
    (dst / "README.md").write_text("# Some Existing App\n", encoding="utf-8")
    (dst / "src").mkdir(exist_ok=True)
    (dst / "src" / "index.php").write_text("<?php echo 'hello';\n", encoding="utf-8")
    subprocess.run(["git", "init", "-q"], cwd=dst, check=True)
    subprocess.run(["git", "add", "-A"], cwd=dst, check=True, capture_output=True)
    subprocess.run(["git", "-c", "user.email=t@t", "-c", "user.name=t",
                    "commit", "-qm", "independent app"], cwd=dst, check=True,
                   capture_output=True)
    return dst


class TestAdoptIndependentRepository(unittest.TestCase):
    """A repository that was not created from this template must still adopt cleanly.

    Found 2026-07-20 adopting skyphoenix-company-website, a production PHP app built with
    no agentic workflow. The updater installed the payload fine and then the gates failed
    with 26 errors: validate.py requires every path cited in canonical sources to exist
    locally, and validate-repository.sh requires a fixed project file set — but neither
    PROJECT.md, SECURITY.md, docs/, nor scripts/build.sh|test.sh is in PAYLOAD, because
    they are project-owned rather than template-owned.
    """

    def setUp(self):
        self.tmp = scratch_dir()
        self.repo = make_independent_repo(self.tmp / "independent")

    def tearDown(self):
        shutil.rmtree(self.tmp, ignore_errors=True)

    def update(self, *args: str, timeout: int = 300):
        return run([sys.executable, str(UPDATER), "--from", str(REPO_ROOT),
                    "--target", str(self.repo), "--no-verify", *args],
                   cwd=self.repo, timeout=timeout)

    def test_independent_repo_satisfies_the_gates_after_one_update(self):
        p = self.update()
        self.assertEqual(p.returncode, 0, p.stdout + p.stderr)
        # exactly what scripts/validate-repository.sh requires
        for rel in ("README.md", "PROJECT.md", "AGENTS.md", "CLAUDE.md", "SECURITY.md",
                    "docs/product/product-vision.md", "docs/architecture/overview.md",
                    "docs/security/threat-model.md", "docs/testing/test-strategy.md",
                    ".claude/settings.json"):
            self.assertTrue((self.repo / rel).exists(), f"missing required file: {rel}")
        # paths cited by canonical sources that validate.py resolves
        for rel in ("docs/product/pov-scope.md", "docs/releases/release-checklist.md",
                    "docs/adr", "scripts/build.sh", "scripts/test.sh"):
            self.assertTrue((self.repo / rel).exists(), f"missing cited path: {rel}")
        r = run([sys.executable, "scripts/agent-framework/validate.py"],
                cwd=self.repo, timeout=300)
        self.assertEqual(r.returncode, 0,
                         f"validate.py failed on a freshly adopted independent repo:\n"
                         f"{r.stdout}\n{r.stderr}")

    def test_scaffold_never_overwrites_the_adopter_own_files(self):
        """A repo that already documents itself keeps its content byte-for-byte."""
        (self.repo / "docs" / "security").mkdir(parents=True, exist_ok=True)
        own = self.repo / "docs" / "security" / "threat-model.md"
        own.write_text("# Our Threat Model\nSENTINEL-ADOPTER-OWNED\n", encoding="utf-8")
        proj = self.repo / "PROJECT.md"
        proj.write_text("# Our Project\nSENTINEL-ADOPTER-OWNED\n", encoding="utf-8")
        p = self.update()
        self.assertEqual(p.returncode, 0, p.stdout + p.stderr)
        self.assertIn("SENTINEL-ADOPTER-OWNED", own.read_text(encoding="utf-8"))
        self.assertIn("SENTINEL-ADOPTER-OWNED", proj.read_text(encoding="utf-8"))

    def test_project_yaml_is_created_not_merely_warned_about(self):
        """Warning was not enough. The eval suite reads project.yaml unconditionally and
        died with FileNotFoundError, so `ci.sh` could never go green on a freshly adopted
        independent repo even after every other scaffold file existed."""
        self.assertEqual(self.update().returncode, 0)
        p = self.repo / "project.yaml"
        self.assertTrue(p.exists(), "project.yaml must be created, not just warned about")
        text = p.read_text(encoding="utf-8")
        self.assertNotIn(PLACEHOLDER_PREFIX, text,
                         f"must not emit {PLACEHOLDER_PREFIX} placeholders — "
                         "validate-repository.sh flags them")
        self.assertIn("agent_framework:", text, "skill selection block must be present")
        import yaml
        data = yaml.safe_load(text)
        self.assertEqual(data["project"]["slug"], self.repo.resolve().name)
        self.assertIn("TODO", data["project"]["owner"], "starter values must be obviously unfinished")

    def test_scaffolded_scripts_are_executable_and_idempotent(self):
        self.assertEqual(self.update().returncode, 0)
        for rel in ("scripts/build.sh", "scripts/test.sh"):
            self.assertTrue(os.access(self.repo / rel, os.X_OK), f"{rel} not executable")
        before = (self.repo / "PROJECT.md").read_text(encoding="utf-8")
        self.assertEqual(self.update().returncode, 0, "second update must be a no-op")
        self.assertEqual(before, (self.repo / "PROJECT.md").read_text(encoding="utf-8"))


class TestEndToEndMigration(UpdaterTestBase):
    def test_migrated_repo_passes_the_framework_gates(self):
        """Full adoption path, then the gates run explicitly (never via --verify: the
        payload contains this suite and would recurse)."""
        p = self.update("--adopt", "--retire-legacy", timeout=600)
        self.assertEqual(p.returncode, 0, p.stdout + p.stderr)
        for name, cmd in (
                ("render --check", ["scripts/agent-framework/render.py", "--check"]),
                ("validate", ["scripts/agent-framework/validate.py"]),
                ("check-drift", ["scripts/agent-framework/check-drift.py"])):
            r = run([sys.executable, *cmd], cwd=self.repo, timeout=300)
            self.assertEqual(r.returncode, 0, f"{name} failed:\n{r.stdout}\n{r.stderr}")
        # generated artifacts exist and the adopter's own manifest was produced locally
        self.assertTrue((self.repo / ".claude" / "agents" / "orchestrator.md").exists())
        self.assertTrue((self.repo / "agent-framework" / "generated-manifest.json").exists())
        self.assertEqual(self.payload_manifest()["framework_version"],
                         (REPO_ROOT / "agent-framework" / "VERSION").read_text().strip())
        self.assertFalse((self.repo / "agent-framework" / ".framework-source").exists(),
                         "the source marker must never ship into an adopting repo")

    def test_shipped_suite_does_not_fail_in_the_adopting_repo(self):
        """The gap that let a downstream-only failure ship.

        Every other test here runs the updater with --no-verify, so the suite never
        observed itself running inside a migrated repo — but the updater's real
        verify() runs `unittest discover` there. A test pinning a template-only
        invariant must SKIP downstream, not FAIL; otherwise a correct migration exits 1.

        Observed 2026-07-19 against a clone of the ServiceNow pilot at b6e534c:
        `Ran 118 tests ... FAILED (failures=1)` on an --adopt --retire-legacy migration.

        Runs the one template-only test rather than full discovery: targeted, ~0.05s,
        and it cannot recurse (that test invokes the updater with --no-verify)."""
        p = self.update("--adopt", "--retire-legacy", timeout=600)
        self.assertEqual(p.returncode, 0, p.stdout + p.stderr)
        r = run([sys.executable, "-m", "unittest", "-v",
                 "tests.agent-framework.test_update_framework.TestSafetyContract"
                 ".test_framework_source_repo_refused_as_target"],
                cwd=self.repo, timeout=300)
        out = r.stdout + r.stderr
        self.assertEqual(r.returncode, 0,
                         f"shipped suite fails inside an adopting repo:\n{out}")
        self.assertIn("skip", out.lower(),
                      f"expected the template-only test to skip downstream, got:\n{out}")


def load_updater():
    """Import update-framework.py for unit-level tests (hyphenated filename)."""
    import importlib.util
    spec = importlib.util.spec_from_file_location("af_update", UPDATER)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def make_template_remote(dst: Path) -> Path:
    """A stand-in template remote: one branch (`main`) and one UNSIGNED tag."""
    (dst / "agent-framework" / "canonical").mkdir(parents=True, exist_ok=True)
    (dst / "agent-framework" / "VERSION").write_text("9.9.9\n", encoding="utf-8")
    # Hermetic against the operator's git config: signing must be forced OFF here, or a
    # global commit.gpgSign/tag.gpgSign turns these into signed objects and the
    # "unsigned tag is refused" test would silently assert the wrong thing.
    env = ["-c", "user.email=t@t", "-c", "user.name=t",
           "-c", "commit.gpgSign=false", "-c", "tag.gpgSign=false",
           "-c", "tag.forceSignAnnotated=false"]
    subprocess.run(["git", "init", "-q", "-b", "main"], cwd=dst, check=True,
                   capture_output=True)
    subprocess.run(["git", "add", "-A"], cwd=dst, check=True, capture_output=True)
    subprocess.run(["git", *env, "commit", "-qm", "template"], cwd=dst, check=True,
                   capture_output=True)
    subprocess.run(["git", *env, "tag", "-a", "-m", "unsigned test tag", "v9.9.9"],
                   cwd=dst, check=True, capture_output=True)
    return dst


class TestSourceTrust(UpdaterTestBase):
    """ADR 0001 decisions 1 and 2 — what the updater is willing to fetch and execute."""

    def setUp(self):
        super().setUp()
        self.remote = make_template_remote(self.tmp / "remote")
        self.url = f"file://{self.remote}"

    def fetch(self, *args: str, env: dict | None = None):
        """Hermetic against the ambient environment.

        AF_REQUIRE_SIGNED_TAG is neutralised unless a test sets it explicitly. Without
        this, running the gate under `AF_REQUIRE_SIGNED_TAG=1` — which is exactly how
        the update workflow invokes it — made every unsigned-stub test refuse at the
        signature check instead of exercising what it was written to test. Found by a
        real end-to-end bootstrap from the published tag, and it is the same defect
        class as the template-only test that once failed in every adopting repo: a
        shipped suite must not depend on the environment that happens to invoke it."""
        merged = {"AF_REQUIRE_SIGNED_TAG": "", "AF_TEMPLATE_REF": "", "AF_TEMPLATE_URL": ""}
        merged.update(env or {})
        return run([sys.executable, str(UPDATER), "--url", self.url,
                    "--target", str(self.repo), "--no-verify", "--dry-run", *args],
                   cwd=self.repo, timeout=300, env=merged)

    def test_branch_ref_is_refused_without_the_explicit_opt_in(self):
        p = self.fetch("--ref", "main")
        self.assertEqual(p.returncode, 1, p.stdout + p.stderr)
        self.assertIn("mutable ref", p.stdout + p.stderr)

    def test_branch_ref_is_accepted_with_allow_mutable_ref(self):
        """Opt-in works and names the pinned SHA; it fails later on the stub payload,
        which proves resolution got past the trust gate rather than being refused."""
        p = self.fetch("--ref", "main", "--allow-mutable-ref")
        out = p.stdout + p.stderr
        self.assertNotIn("mutable ref", out)
        self.assertIn("pinned to", out)

    def test_missing_ref_with_no_recorded_commit_is_refused(self):
        p = self.fetch()
        self.assertEqual(p.returncode, 1, p.stdout + p.stderr)
        self.assertIn("no template ref given", p.stdout + p.stderr)

    def test_unsigned_tag_is_refused_when_signature_is_required(self):
        env = {"AF_REQUIRE_SIGNED_TAG": "1"}
        p = self.fetch("--ref", "v9.9.9", env=env)
        self.assertEqual(p.returncode, 1, p.stdout + p.stderr)
        self.assertIn("signature verification failed", p.stdout + p.stderr)

    def test_branch_is_refused_outright_when_signature_is_required(self):
        """Unattended runs may not fall back to --allow-mutable-ref."""
        env = {"AF_REQUIRE_SIGNED_TAG": "1"}
        p = self.fetch("--ref", "main", "--allow-mutable-ref", env=env)
        self.assertEqual(p.returncode, 1, p.stdout + p.stderr)
        self.assertIn("not a tag", p.stdout + p.stderr)

    def test_annotated_tag_resolves_to_its_commit_not_the_tag_object(self):
        """A signed tag IS an annotated tag, so this is the release path itself.

        `git ls-remote <url> <pattern>` returns only the tag OBJECT line and omits the
        `^{}` dereferenced line, so the resolved sha is the tag object while HEAD after
        checkout is the commit. Comparing them raw rejected every signed tag: the first
        real fetch of agent-framework-v1.1.0 failed with "fetched tree is at c16fe0d,
        expected 683f1dc". Dereference with ^{commit} before comparing.

        Acquisition succeeding is proven by the run getting past the integrity check
        into the payload phase; the stub remote is not a usable template, so it is
        expected to fail after that."""
        p = self.fetch("--ref", "v9.9.9")
        out = p.stdout + p.stderr
        self.assertNotIn("fetched tree is at", out,
                         "annotated tag rejected by the integrity check — the resolved "
                         "sha was not dereferenced to a commit")
        self.assertIn("does not look like a template checkout", out,
                      f"expected acquisition to succeed and the stub to be rejected as "
                      f"an incomplete template; got:\n{out}")

    def test_fetch_provenance_survives_the_reexec(self):
        """`maybe_reexec` hands the template's updater `--from <fetched source>`, so the
        re-executed run takes the local-checkout path and would record no source_commit
        — losing the provenance of the fetch that just happened. The parent passes the
        resolved commit through AF_SOURCE_COMMIT so it is still recorded.

        Observed against the real v1.1.0 tag: source_commit came back None."""
        sha = "deadbeefcafe1234567890abcdefdeadbeefcafe"
        p = run([sys.executable, str(UPDATER), "--from", str(REPO_ROOT),
                 "--target", str(self.repo), "--no-verify", "--adopt"],
                cwd=self.repo, env={"AF_SOURCE_COMMIT": sha}, timeout=300)
        self.assertEqual(p.returncode, 0, p.stdout + p.stderr)
        self.assertEqual(self.payload_manifest().get("source_commit"), sha,
                         "fetch provenance was dropped across the re-exec")

    def test_transport_helper_and_option_like_urls_are_refused(self):
        af = load_updater()
        for bad in ("ext::sh -c 'touch /tmp/pwned'", "--upload-pack=touch /tmp/pwned",
                    "git://example.com/repo.git"):
            with self.subTest(url=bad):
                with self.assertRaises(af.Failed):
                    af.validate_url(bad)
        for good in ("https://example.com/r.git", "ssh://git@example.com/r.git",
                     "file:///tmp/r"):
            with self.subTest(url=good):
                self.assertEqual(af.validate_url(good), good)


class TestWriteContainment(UpdaterTestBase):
    """ADR 0001 decision 3 — findings F4/F5. Both escapes were demonstrated against
    scratch repos during the v1.1.0 gate; these fail without the containment helper."""

    def test_symlinked_parent_directory_cannot_escape_the_target(self):
        outside = self.tmp / "outside"
        outside.mkdir()
        (self.repo / "agent-framework").symlink_to(outside, target_is_directory=True)
        p = self.update()
        self.assertEqual(p.returncode, 1, p.stdout + p.stderr)
        self.assertIn("outside the target repository", p.stdout + p.stderr)
        self.assertEqual(list(outside.iterdir()), [],
                         "payload was written outside the target repository")

    def test_symlinked_scaffold_file_is_not_written_through(self):
        victim = self.tmp / "victim.txt"
        victim.write_text("ORIGINAL SECRET\n", encoding="utf-8")
        gi = self.repo / ".gitignore"
        gi.unlink()
        gi.symlink_to(victim)
        p = self.update()
        self.assertEqual(p.returncode, 1, p.stdout + p.stderr)
        self.assertIn("symlink", p.stdout + p.stderr)
        self.assertEqual(victim.read_text(encoding="utf-8"), "ORIGINAL SECRET\n",
                         "wrote through a symlink to a file outside the repository")

    def test_contained_accepts_paths_under_the_target(self):
        af = load_updater()
        af.set_target_root(self.repo)
        self.assertTrue(af.contained(self.repo / "agent-framework" / "new" / "f.md"))
        with self.assertRaises(af.Failed):
            af.contained(self.tmp / "elsewhere.md")


class TestTransactionalUpdate(UpdaterTestBase):
    """ADR 0001 decision 5 — D1 (`--dry-run` must predict its own refusal, not just
    stop short of it) and D2 (a refusal or failure must roll the tree back to its
    pre-run state, since payload sync/project setup/legacy retirement all run before
    render.py's own collision check can fire)."""

    VICTIM = ".claude/rules/agent-framework.md"

    def _plant_collision(self) -> Path:
        """A hand-written file at a path the framework generates: render.py refuses on
        it (no framework marker, no manifest record) — the same fixture the D2 real
        repository trial found (14 colliding provider files)."""
        victim = self.repo / self.VICTIM
        victim.parent.mkdir(parents=True, exist_ok=True)
        victim.write_text("# our own pointer file\nHAND-WRITTEN-SENTINEL\n", encoding="utf-8")
        return victim

    def test_dry_run_predicts_a_render_collision_and_names_it(self):
        """D1 regression. Before the fix, `--dry-run` against this exact fixture exited
        0 across the whole plan with zero mention of the collision, refusal, or
        `--adopt` — the real run then exited 2. This test FAILED before the fix
        (asserted and recorded in the implementation report)."""
        self._plant_collision()
        p = self.update("--dry-run")
        out = p.stdout + p.stderr
        self.assertEqual(p.returncode, 2, out)
        self.assertIn(self.VICTIM, out)
        self.assertIn("REFUSED", out)

    def test_refused_run_leaves_the_tree_unchanged(self):
        """D2 regression. Before the fix, the refusal fired AFTER sync_payload, project
        setup, and legacy retirement had already mutated the repo (24 changed paths
        observed in the real-repository trial: payload installed, legacy files deleted,
        several modified, no backups). This test FAILED before the fix."""
        self._plant_collision()
        before = subprocess.run(["git", "status", "--porcelain"], cwd=self.repo,
                                capture_output=True, text=True).stdout
        p = self.update("--retire-legacy")
        self.assertEqual(p.returncode, 2, p.stdout + p.stderr)
        after = subprocess.run(["git", "status", "--porcelain"], cwd=self.repo,
                               capture_output=True, text=True).stdout
        self.assertEqual(before, after, "a refused run left the working tree modified")

    def test_dry_run_still_leaves_the_real_target_byte_identical(self):
        """A --dry-run now runs the real mutation flow against a disposable COPY of the
        target; this pins that the real target itself is never touched by it."""
        before = subprocess.run(["git", "status", "--porcelain"], cwd=self.repo,
                                capture_output=True, text=True).stdout
        p = self.update("--dry-run")
        self.assertEqual(p.returncode, 0, p.stdout + p.stderr)
        after = subprocess.run(["git", "status", "--porcelain"], cwd=self.repo,
                               capture_output=True, text=True).stdout
        self.assertEqual(before, after, "--dry-run modified the working tree")
        self.assertFalse((self.repo / "agent-framework" / "canonical").exists())

    def test_forced_mid_apply_failure_rolls_back(self):
        """A deterministic mid-apply failure, induced via AF_UPDATE_TEST_FORCE_FAILURE —
        an env var the updater checks right after payload sync, project setup, and
        legacy retirement have all landed, and right before it writes the payload
        manifest or invokes render.py. Exercises both the write-rollback path (payload
        files, project scaffolding) and the deletion-rollback path (a retired legacy
        file) in a single run. No sleeps/timing: the failure point is fixed in code."""
        legacy = self.repo / ".claude" / "rules" / "00-core.md"
        baseline = subprocess.run(["git", "show", "a09fbd2:.claude/rules/00-core.md"],
                                  cwd=REPO_ROOT, capture_output=True)
        if baseline.returncode != 0:
            self.skipTest("v1.0 template baseline for the legacy fixture not available "
                          "in this checkout")
        legacy.parent.mkdir(parents=True, exist_ok=True)
        legacy.write_bytes(baseline.stdout)
        subprocess.run(["git", "add", "-A"], cwd=self.repo, check=True, capture_output=True)
        subprocess.run(["git", "-c", "user.email=t@t", "-c", "user.name=t", "commit",
                        "-qm", "plant a retirable legacy baseline"], cwd=self.repo,
                       check=True, capture_output=True)

        before = subprocess.run(["git", "status", "--porcelain"], cwd=self.repo,
                                capture_output=True, text=True).stdout
        p = self.update("--adopt", "--retire-legacy",
                        env={"AF_UPDATE_TEST_FORCE_FAILURE": "1"})
        self.assertEqual(p.returncode, 1, p.stdout + p.stderr)
        self.assertIn("injected failure", p.stdout + p.stderr)
        after = subprocess.run(["git", "status", "--porcelain"], cwd=self.repo,
                               capture_output=True, text=True).stdout
        self.assertEqual(before, after, "a forced mid-apply failure left the tree modified")
        self.assertTrue(legacy.exists(), "the retired legacy file was not restored on rollback")


class TestPayloadCarriesNoPlaceholderToken(unittest.TestCase):
    """v1.1.4 regression: a payload file must not contain the initialization placeholder
    token, not even inside a comment or a test message discussing it.

    scripts/validate-repository.sh greps the whole tree for the token and fails when
    `.project-initialized` exists — which is true of every adopted repository and false
    of this template, so the template's own CI stayed green while every adopter went red.
    That asymmetry is why this has to be asserted here rather than left to CI.
    """

    def _payload_dirs(self):
        sys.path.insert(0, str(SCRIPTS))
        import importlib.util
        spec = importlib.util.spec_from_file_location("_upd", UPDATER)
        mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mod)
        return mod.PAYLOAD

    # Mirrors the two --exclude flags in scripts/validate-repository.sh:8-11. Those files
    # are the placeholder mechanism itself, so they are allowed to name the token; keep
    # this list in step with that grep or the test drifts from what actually gates CI.
    SCANNER_EXEMPT = {"initialize-project.sh", "validate-repository.sh"}

    def test_no_payload_file_contains_placeholder(self):
        offenders = []
        for entry in self._payload_dirs():
            root = REPO_ROOT / entry
            paths = [root] if root.is_file() else [
                p for p in root.rglob("*")
                if p.is_file() and "__pycache__" not in p.parts
            ]
            for p in paths:
                if p.name in self.SCANNER_EXEMPT:
                    continue
                try:
                    text = p.read_text(encoding="utf-8")
                except (UnicodeDecodeError, OSError):
                    continue  # binary payload content (brand assets) cannot carry the token
                if PLACEHOLDER_PREFIX in text:
                    offenders.append(str(p.relative_to(REPO_ROOT)))
        self.assertEqual(
            offenders, [],
            "these payload files contain the initialization placeholder token and will "
            "make validate-repository.sh fail in every adopting repository: "
            + ", ".join(offenders)
            + " — refer to it as PLACEHOLDER_PREFIX or in prose, never as a literal.",
        )


if __name__ == "__main__":
    unittest.main()

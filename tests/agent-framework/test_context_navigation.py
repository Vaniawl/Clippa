"""Context boundaries must survive rendering/adoption and fail closed when unrouted."""
from __future__ import annotations

import importlib.util
from pathlib import Path
import shutil
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parent))
from _helpers import REPO_ROOT, check_drift, render, run, scratch_dir, validate, updater_source_fixture
from test_update_framework import make_independent_repo
sys.path.insert(0, str(REPO_ROOT / 'scripts/agent-framework'))
from _markdown import invalid_local_links

ROUTE = 'Before any work, read `agent-framework/canonical/operating-instructions.md`.'


class ContextNavigationTests(unittest.TestCase):
    def setUp(self):
        self.tmp = scratch_dir()
        self.addCleanup(shutil.rmtree, self.tmp, ignore_errors=True)
        self.repo = self.tmp / 'repo'
        self.repo.mkdir()
        # Only framework inputs are relevant to these mutation tests. Adopter
        # roots can contain many GB of ignored native build/audit artifacts.
        spec = importlib.util.spec_from_file_location('navigation_fixture_installer',
            REPO_ROOT / 'scripts/agent-framework/install-apple-team.py')
        installer = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(installer)
        updater = installer.load_module('navigation_fixture_updater',
            REPO_ROOT / 'scripts/agent-framework/update-framework.py')
        installer.copy_selected(REPO_ROOT, self.repo, updater)
        # Validation resolves existing project ADR references, without needing
        # app sources, Xcode products, local audit archives or provider caches.
        if (REPO_ROOT / 'docs/adr').is_dir():
            shutil.copytree(REPO_ROOT / 'docs/adr', self.repo / 'docs/adr', dirs_exist_ok=True)

    def assert_success(self, result):
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_render_preserves_project_guidance_and_task_artifacts(self):
        agents = self.repo / 'AGENTS.md'
        agents.write_text(agents.read_text() + '\nPROJECT-LOCAL-SENTINEL\n')
        task = self.repo / 'docs/tasks/existing/evidence.md'
        task.parent.mkdir(parents=True)
        task.write_text('PROJECT-OWNED-EVIDENCE\n')
        self.assert_success(render(self.repo))
        self.assertIn('PROJECT-LOCAL-SENTINEL', agents.read_text())
        self.assertIn(ROUTE, agents.read_text())
        self.assertEqual(task.read_text(), 'PROJECT-OWNED-EVIDENCE\n')
        self.assert_success(check_drift(self.repo))

    def test_missing_mandatory_route_or_operating_file_fails_validation(self):
        entry = self.repo / 'agent-framework/canonical/core-instructions.md'
        original = entry.read_text()
        entry.write_text(original.replace(ROUTE, 'Optional background only.'))
        self.assert_success(render(self.repo))
        result = validate(self.repo)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('mandatory operating-instructions route missing', result.stdout)
        entry.write_text(original)
        self.assert_success(render(self.repo))
        (self.repo / 'agent-framework/canonical/operating-instructions.md').unlink()
        result = validate(self.repo)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('operating-instructions.md', result.stdout)

    def test_missing_workflow_contract_and_broken_map_link_fail_validation(self):
        context = self.repo / 'agent-framework/canonical/workflows/apple-feature-delivery/CONTEXT.md'
        content = context.read_bytes()
        context.unlink()
        result = validate(self.repo)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('apple-feature-delivery/CONTEXT.md', result.stdout)
        context.write_bytes(content)
        navigation = self.repo / 'agent-framework/CONTEXT.md'
        navigation.write_text(navigation.read_text() + '\n[Broken route](missing-context.md)\n')
        result = validate(self.repo)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('missing-context.md', result.stdout)

    def test_task_template_is_walkable_after_copy_and_starts_unverified(self):
        template = self.repo / 'agent-framework/templates/task-folder'
        task = self.repo / 'docs/tasks/new-task'
        shutil.copytree(template, task)
        self.assertEqual({p.name for p in task.iterdir()},
                         {'CONTEXT.md', 'task.md', 'decisions.md', 'evidence.md', 'handover.md',
                          '01-scope', '02-design', '03-build', '04-verify'})
        for document in task.rglob('*.md'):
            self.assertEqual(invalid_local_links(document.read_text(), document, self.repo), [], str(document))
        self.assertIn('NOT RUN', (task / 'evidence.md').read_text())
        self.assertIn('Status: partial', (task / 'handover.md').read_text())
        self.assertIn('Unfilled placeholders are not authorization', (task / 'CONTEXT.md').read_text())
        for stage in ('01-scope', '02-design', '03-build', '04-verify'):
            self.assertEqual([p.name for p in (task / stage / 'output').iterdir()], ['.gitkeep'])

    def test_stage_contracts_reject_forward_input_missing_handoff_and_missing_output(self):
        base = self.repo / 'agent-framework/templates/task-folder'
        contract = base / '02-design/CONTEXT.md'
        original = contract.read_text()
        contract.write_text(original.replace('../01-scope/output', '../04-verify/output'))
        result = validate(self.repo)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('stage input must point backward', result.stdout)
        self.assertIn('missing preceding stage output input', result.stdout)
        contract.write_text(original)
        (base / '03-build/output/.gitkeep').unlink()
        result = validate(self.repo)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('missing fresh output/.gitkeep', result.stdout)

    def test_map_must_route_every_canonical_workflow(self):
        navigation = self.repo / 'agent-framework/CONTEXT.md'
        relative = 'canonical/workflows/apple-feature-delivery/CONTEXT.md'
        text = navigation.read_text()
        self.assertIn(relative, text)
        # Remove a valid row without leaving any broken link. Link checking alone
        # would pass; coverage must still reject the now-unreachable workflow.
        navigation.write_text('\n'.join(line for line in text.splitlines() if relative not in line) + '\n')
        result = validate(self.repo)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('workflow route missing: ' + relative, result.stdout)

    def test_adoption_ships_map_and_creates_guide_without_overwriting_custom_tasks(self):
        spec = importlib.util.spec_from_file_location('context_updater',
            self.repo / 'scripts/agent-framework/update-framework.py')
        updater = importlib.util.module_from_spec(spec)
        sys.modules[spec.name] = updater
        spec.loader.exec_module(updater)
        self.assertIn('agent-framework/CONTEXT.md', updater.payload_files(self.repo))
        target = make_independent_repo(self.tmp / 'adopter')
        # A generic adopter may own a bootstrap script unrelated to this template.
        bootstrap = target / 'scripts/bootstrap.py'
        bootstrap.parent.mkdir(exist_ok=True)
        bootstrap.write_text('# PROJECT-OWNED BOOTSTRAP\n')
        source = updater_source_fixture(self.tmp / 'source')
        command = [sys.executable, str(self.repo / 'scripts/agent-framework/update-framework.py'),
                   '--from', str(source), '--target', str(target), '--no-verify']
        # Invoke the public updater so containment, scaffolding and rendering all run.
        # Its recursive full-suite gate is disabled; validate/drift are run explicitly.
        self.assert_success(run(command, target))
        import yaml
        workflow = yaml.safe_load((target / '.github/workflows/quality.yml').read_text())
        step = next(step for step in workflow['jobs']['validate']['steps']
                    if step.get('run') == 'python3 scripts/validate-context.py')
        self.assertEqual(step['if'], "${{ hashFiles('Config/Context.json') != '' }}")
        self.assertFalse((target / 'Config/Context.json').exists())
        self.assertFalse((target / 'scripts/validate-context.py').exists())
        self.assertEqual(bootstrap.read_text(), '# PROJECT-OWNED BOOTSTRAP\n')
        guide = target / 'docs/tasks/CONTEXT.md'
        self.assertTrue(guide.is_file())
        self.assertTrue((target / 'agent-framework/CONTEXT.md').is_file())
        root_map = target / 'CONTEXT.md'
        self.assertIn('## Inputs', root_map.read_text())
        self.assert_success(validate(target))
        self.assert_success(check_drift(target))
        guide.write_text('CUSTOM-TASK-GUIDE\n')
        root_map.write_text('CUSTOM-PROJECT-CONTEXT\n')
        evidence = target / 'docs/tasks/owned/evidence.md'
        evidence.parent.mkdir()
        evidence.write_text('CUSTOM-EVIDENCE\n')
        self.assert_success(run(command, target))
        self.assertEqual(guide.read_text(), 'CUSTOM-TASK-GUIDE\n')
        self.assertEqual(evidence.read_text(), 'CUSTOM-EVIDENCE\n')
        self.assertEqual(root_map.read_text(), 'CUSTOM-PROJECT-CONTEXT\n')


if __name__ == '__main__':
    unittest.main()

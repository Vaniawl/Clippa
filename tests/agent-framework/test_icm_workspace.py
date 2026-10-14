"""Project-specific routing and the shipped production stage gate must stay usable."""
from __future__ import annotations
import importlib.util
from pathlib import Path
import shutil
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'scripts/agent-framework'))
from _markdown import invalid_local_links

class ICMWorkspaceTests(unittest.TestCase):
    def test_actual_project_routes_and_template_links_are_valid(self):
        documents = [ROOT / 'CONTEXT.md', *(ROOT / 'docs/context').rglob('CONTEXT.md'),
                     *(ROOT / 'agent-framework/templates/task-folder').rglob('CONTEXT.md')]
        for path in documents:
            text = path.read_text()
            self.assertLess(len(text.splitlines()), 80, str(path))
            for heading in ('## Inputs', '## Process', '## Outputs'):
                self.assertIn(heading, text, str(path))
            self.assertEqual(invalid_local_links(text, path, ROOT), [], str(path))
        self.assertIn('CONTEXT.md', (ROOT / 'AGENTS.md').read_text())

    def test_production_gate_rejects_forward_handoffs_and_missing_output(self):
        spec = importlib.util.spec_from_file_location('workspace_actual_validator', ROOT / 'scripts/agent-framework/validate.py')
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        with tempfile.TemporaryDirectory(prefix='icm-workspace-mutation-') as temporary:
            root = Path(temporary); framework = root / 'agent-framework'; canon = framework / 'canonical'
            canon.mkdir(parents=True)
            route = 'Before any work, read `agent-framework/canonical/operating-instructions.md`.\n'
            (canon / 'core-instructions.md').write_text(route)
            (root / 'AGENTS.md').write_text(route)
            (framework / 'CONTEXT.md').write_text('# Fixture map\n')
            template = framework / 'templates/task-folder'
            shutil.copytree(ROOT / 'agent-framework/templates/task-folder', template)
            module.REPO_ROOT = root; module.FRAMEWORK_DIR = framework; module.CANON = canon
            module.ERRORS.clear(); module.check_context_navigation()
            self.assertEqual(module.ERRORS, [])
            contract = template / '02-design/CONTEXT.md'; original = contract.read_text()
            contract.write_text(original.replace('../01-scope/output', '../04-verify/output'))
            module.ERRORS.clear(); module.check_context_navigation()
            self.assertTrue(any('stage input must point backward' in e for e in module.ERRORS))
            self.assertTrue(any('missing preceding stage output input' in e for e in module.ERRORS))
            contract.write_text(original)
            (template / '03-build/output/.gitkeep').unlink()
            module.ERRORS.clear(); module.check_context_navigation()
            self.assertTrue(any('missing fresh output/.gitkeep' in e for e in module.ERRORS))

if __name__ == '__main__':
    unittest.main()

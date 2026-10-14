"""Project routing is source-owned; mutation fixtures contain only linked inputs."""
from __future__ import annotations

import importlib.util
from pathlib import Path
import shutil
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parent))
from _helpers import IS_TEMPLATE_SOURCE, REPO_ROOT

SPEC = importlib.util.spec_from_file_location('project_context', REPO_ROOT / 'scripts/validate-context.py')
# Framework-only adopters deliberately do not ship Apple project validation.
VALIDATOR = None
if SPEC is not None and SPEC.loader is not None and Path(SPEC.origin).is_file():
    VALIDATOR = importlib.util.module_from_spec(SPEC)
    SPEC.loader.exec_module(VALIDATOR)


@unittest.skipUnless(IS_TEMPLATE_SOURCE and VALIDATOR, 'Apple template source context gate')
class ProjectContextTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix='project-context-')
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        (self.root / 'Config').mkdir()
        shutil.copy2(REPO_ROOT / 'Config/Context.json', self.root / 'Config/Context.json')
        paths = ('CONTEXT.md', 'docs/tasks/CONTEXT.md',
                 *(f'{name}/CONTEXT.md' for name in VALIDATOR.COMPONENTS))
        for relative in paths:
            source = REPO_ROOT / relative
            target = self.root / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, target)
        # Existence-only reference checks need no native builds, caches or history.
        for relative in paths:
            source = REPO_ROOT / relative
            for _, _, _, path in VALIDATOR.local_links(source.read_text()):
                actual = (source.parent / path).resolve()
                target = self.root / actual.relative_to(REPO_ROOT)
                if actual.is_dir():
                    target.mkdir(parents=True, exist_ok=True)
                elif not target.exists():
                    target.parent.mkdir(parents=True, exist_ok=True)
                    target.touch()

    def test_source_and_minimal_fixture_pass(self):
        self.assertEqual(VALIDATOR.validate(REPO_ROOT), [])
        self.assertEqual(VALIDATOR.validate(self.root), [])

    def test_existing_component_without_entry_route_fails(self):
        entry = self.root / 'CONTEXT.md'
        entry.write_text('\n'.join(line for line in entry.read_text().splitlines()
                                   if 'Modules/CONTEXT.md' not in line) + '\n')
        self.assertIn('CONTEXT.md: missing route: Modules/CONTEXT.md', VALIDATOR.validate(self.root))

    def test_missing_contract_and_broken_reference_fail(self):
        (self.root / 'App/CONTEXT.md').unlink()
        (self.root / 'Modules/Package.swift').unlink()
        errors = VALIDATOR.validate(self.root)
        self.assertTrue(any('App/CONTEXT.md: cannot read' in error for error in errors))
        self.assertIn('Modules/CONTEXT.md: broken local link: Package.swift', errors)

    def test_unscoped_inputs_and_missing_outputs_fail(self):
        path = self.root / 'Config/CONTEXT.md'
        path.write_text(path.read_text().replace('Section / scope', 'Notes').replace('## Outputs', '## Result'))
        errors = VALIDATOR.validate(self.root)
        self.assertIn('Config/CONTEXT.md: Inputs needs a scoped table', errors)
        self.assertIn('Config/CONTEXT.md: missing ## Outputs', errors)

    def test_oversized_context_fails(self):
        path = self.root / 'App/CONTEXT.md'
        path.write_text(path.read_text() + '\n' * 80)
        self.assertIn('App/CONTEXT.md: context must be under 80 lines', VALIDATOR.validate(self.root))

    def test_link_outside_repository_fails(self):
        path = self.root / 'App/CONTEXT.md'
        path.write_text(path.read_text() + '\n[Outside](../../outside.md)\n')
        self.assertIn('App/CONTEXT.md: broken local link: ../../outside.md', VALIDATOR.validate(self.root))

    def test_missing_or_invalid_capability_marker_fails(self):
        marker = self.root / 'Config/Context.json'
        marker.write_text('{"schema": 999}')
        self.assertIn('Config/Context.json: unsupported context capability', VALIDATOR.validate(self.root))
        marker.unlink()
        self.assertTrue(any('cannot read context capability' in error
                            for error in VALIDATOR.validate(self.root)))


if __name__ == '__main__':
    unittest.main()

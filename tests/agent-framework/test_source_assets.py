"""Keep adopter regression fixtures synchronized with the source-owned assets."""
from pathlib import Path
import sys
import unittest
import json
import tempfile

sys.path.insert(0, str(Path(__file__).resolve().parent))
from _helpers import REPO_ROOT, IS_TEMPLATE_SOURCE, is_template_source


class SourceAssetOwnershipTests(unittest.TestCase):
    def test_source_home_marker_survives_but_adopter_ci_stays_project_owned(self):
        with tempfile.TemporaryDirectory() as raw:
            root = Path(raw)
            framework = root / 'agent-framework'
            framework.mkdir()
            (framework / '.framework-source').write_text('Independent development home\n')
            self.assertTrue(is_template_source(root))
            manifest = framework / '.framework-payload.json'
            manifest.write_text(json.dumps({'template': 'ios-starter',
                'source_url': 'https://github.com/Vaniawl/ios-starter.git',
                'source_commit': 'a' * 40}))
            self.assertFalse(is_template_source(root))
            self.assertTrue((framework / '.framework-source').exists())
            for metadata in ({'template': 'local checkout'}, {'template': 'ios-starter',
                             'source_url': 'https://github.com/Vaniawl/ios-starter.git',
                             'source_commit': 'not-a-commit'}, []):
                manifest.write_text(json.dumps(metadata))
                self.assertTrue(is_template_source(root))

    def test_initialized_app_is_not_a_bootstrap_source(self):
        with tempfile.TemporaryDirectory() as raw:
            root = Path(raw)
            (root / 'scripts').mkdir()
            (root / 'scripts/bootstrap.py').touch()
            self.assertTrue(is_template_source(root))
            (root / '.project-initialized').touch()
            self.assertFalse(is_template_source(root))


class SourceAssetPackagingTests(unittest.TestCase):
    @unittest.skipUnless(IS_TEMPLATE_SOURCE,
                         'source asset freshness is checked in the framework source')
    def test_packaged_ci_and_adr_are_the_current_source_assets(self):
        fixtures = Path(__file__).parent / 'fixtures/source-assets'
        for name, original in [('quality.yml', '.github/workflows/quality.yml'),
                               ('adr-template.md', 'docs/adr/0000-template.md'),
                               ('permissions.json', '.claude/settings.json')]:
            with self.subTest(asset=name):
                if name == 'permissions.json':
                    import json
                    self.assertEqual(json.loads((fixtures / name).read_text()),
                                     {'permissions': json.loads((REPO_ROOT / original).read_text())['permissions']})
                else:
                    self.assertEqual((fixtures / name).read_bytes(),
                                     (REPO_ROOT / original).read_bytes())

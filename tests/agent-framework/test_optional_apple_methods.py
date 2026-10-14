"""Optional Apple method selection, portable resources and local ownership."""
from __future__ import annotations

from pathlib import Path
import shutil
import sys
import unittest

import yaml

sys.path.insert(0, str(Path(__file__).resolve().parent))
from _helpers import copy_repo, render, scratch_dir, validate

OPTIONAL = {
    'apple-data-sync', 'storekit-monetization', 'apple-signing-distribution',
    'app-localization', 'ios-observability', 'user-research',
    'marketing-creative-production', 'apple-platform-capabilities',
}


class OptionalAppleMethodTests(unittest.TestCase):
    def test_selected_methods_copy_resources_and_preserve_customizations(self):
        tmp = scratch_dir()
        self.addCleanup(shutil.rmtree, tmp, True)
        repo = copy_repo(tmp / 'repo')
        project = repo / 'project.yaml'
        config = yaml.safe_load(project.read_text())
        original = list(config['agent_framework']['skills'])
        config['agent_framework']['skills'] = [s for s in original if s not in OPTIONAL]
        project.write_text(yaml.safe_dump(config, sort_keys=False))
        result = render(repo)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        for prefix in ['.agents/skills', '.claude/skills']:
            self.assertFalse(any((repo / prefix / sid).exists() for sid in OPTIONAL))
        custom = repo / '.agents/skills/my-local-method/SKILL.md'
        custom.parent.mkdir()
        custom.write_text('---\nname: my-local-method\ndescription: Personal method\n---\nPreserve me.\n')
        local_bytes = custom.read_bytes()
        config['agent_framework']['skills'] = original + sorted(OPTIONAL - set(original))
        project.write_text(yaml.safe_dump(config, sort_keys=False))
        result = render(repo)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        for prefix in ['.agents/skills', '.claude/skills']:
            for sid in OPTIONAL:
                self.assertTrue((repo / prefix / sid / 'SKILL.md').is_file(), sid)
                self.assertTrue(list((repo / prefix / sid / 'references').glob('*.md')), sid)
        self.assertEqual(custom.read_bytes(), local_bytes)
        self.assertEqual(yaml.safe_load(project.read_text())['agent_framework']['skills'],
                         config['agent_framework']['skills'])
        result = validate(repo)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)


if __name__ == '__main__':
    unittest.main()

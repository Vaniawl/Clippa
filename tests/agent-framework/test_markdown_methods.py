"""Resource portability and native method availability, not merely valid YAML."""
from __future__ import annotations

from pathlib import Path
import re
import shutil
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parent))
from _helpers import REPO_ROOT, copy_repo, render, scratch_dir, validate
sys.path.insert(0, str(REPO_ROOT / 'scripts/agent-framework'))
from _markdown import invalid_local_links, local_links, rebase_skill_links
import yaml


class MarkdownMethodTests(unittest.TestCase):
    def setUp(self):
        self.tmp = scratch_dir()
        self.addCleanup(shutil.rmtree, self.tmp, True)

    def test_installed_copies_resolve_resources_without_loading_every_method(self):
        for directory in ['.agents/skills', '.claude/skills']:
            for path in (REPO_ROOT / directory).rglob('*.md'):
                with self.subTest(path=path.relative_to(REPO_ROOT)):
                    self.assertEqual(invalid_local_links(path.read_text(), path, REPO_ROOT), [])
            skill = REPO_ROOT / directory / 'apple-team/SKILL.md'
            links = [(skill.parent / path).resolve() for _, _, _, path in local_links(skill.read_text())]
            self.assertIn(REPO_ROOT / 'agent-framework/canonical/policies/delegation-policy.md', links)
            self.assertIn(REPO_ROOT / 'agent-framework/canonical/contracts/agent-task-contract.md', links)
            self.assertIn(skill.parent / 'references/routing.md', links)

    def test_rebasing_preserves_bundled_resources_fragments_and_external_urls(self):
        source = self.tmp / 'canonical/skills/example/SKILL.md'
        source.parent.mkdir(parents=True)
        destination = self.tmp / '.agents/skills/example/SKILL.md'
        destination.parent.mkdir(parents=True)
        text = '[local](references/a.md#heading) [policy](../../policies/a.md#rule) [web](https://example.com/a.md)'
        result = rebase_skill_links(text, source, destination, source.parent, self.tmp)
        self.assertIn('[local](references/a.md#heading)', result)
        self.assertIn('[web](https://example.com/a.md)', result)
        _, _, value, path = list(local_links(result))[1]
        self.assertTrue(value.endswith('#rule'))
        self.assertEqual((destination.parent / path).resolve(), (self.tmp / 'canonical/policies/a.md').resolve())

    def test_code_examples_and_anchor_only_links_are_not_missing_resources(self):
        text = '```md\n[example](missing.md)\n```\n`[inline](missing.md)`\n[heading](#anchor) [site](https://example.com/a)'
        self.assertEqual(list(local_links(text)), [])

    def test_space_percent_encoding_and_link_title_keep_valid_targets(self):
        resource = self.tmp / 'A file.md'
        resource.touch()
        text = '[one](<A file.md>) [two](A%20file.md "Read it")'
        self.assertEqual(invalid_local_links(text, self.tmp / 'README.md', self.tmp), [])

    def test_outside_repository_resources_are_rejected(self):
        document = self.tmp / 'README.md'
        text = '[private](../private.md)'
        self.assertEqual(invalid_local_links(text, document, self.tmp), ['../private.md'])
        with self.assertRaises(ValueError):
            rebase_skill_links(text, document, self.tmp / '.agents/skills/x/SKILL.md', self.tmp, self.tmp)

    def test_validator_rejects_a_missing_canonical_or_installed_resource(self):
        repo = copy_repo(self.tmp / 'repo')
        for rel in ['agent-framework/canonical/skills/apple-team/SKILL.md',
                    '.agents/skills/apple-team/SKILL.md']:
            path = repo / rel
            old = path.read_text()
            path.write_text(old + '\n[Required method](references/absent.md)\n')
            result = validate(repo)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn(rel, result.stdout)
            self.assertIn('Markdown resource', result.stdout)
            path.write_text(old)

    def test_claude_role_methods_are_available_when_invoked_and_model_inherits(self):
        installed = {p.name for p in (REPO_ROOT / '.claude/skills').iterdir() if p.is_dir()}
        for path in (REPO_ROOT / 'agent-framework/canonical/roles').glob('*.yaml'):
            role = yaml.safe_load(path.read_text())
            agent = REPO_ROOT / '.claude/agents' / (role['id'] + '.md')
            front = yaml.safe_load(re.match(r'---\n(.*?)\n---', agent.read_text(), re.S).group(1))
            with self.subTest(role=role['id']):
                self.assertEqual(front['model'], 'inherit')
                self.assertIn('Skill', [t.strip() for t in front['tools'].split(',')])
                self.assertEqual(front.get('skills', []), [s for s in role['skills_default'] if s in installed])
                self.assertTrue(set(front.get('skills', [])) <= installed)
                if role['read_only']:
                    self.assertNotIn('Edit', front['tools'])
                    self.assertNotIn('Write', front['tools'])
                for provider in ['.kimi-code', '.opencode']:
                    body = (REPO_ROOT / provider / 'agents' / (role['id'] + '.md')).read_text()
                    for method in role['skills_default']:
                        self.assertIn(f'canonical/skills/{method}/SKILL.md', body)

    def test_unmanaged_skills_and_extra_files_retain_their_own_resource_rules(self):
        repo = copy_repo(self.tmp / 'repo')
        (self.tmp / 'local-notes.md').write_text('User-owned local resource')
        for prefix in ['.agents/skills', '.claude/skills']:
            path = repo / prefix / 'custom-local/SKILL.md'
            path.parent.mkdir()
            path.write_text('---\nname: custom-local\ndescription: Personal method\n---\n[Notes](../../../../local-notes.md)')
            extra = repo / prefix / 'apple-team/custom-notes.md'
            extra.write_text('[Local notes](../../../../local-notes.md)')
        result = validate(repo)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_render_remains_deterministic_after_rebasing(self):
        repo = copy_repo(self.tmp / 'repo')
        self.assertEqual(render(repo).returncode, 0)
        result = render(repo, '--check')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)


if __name__ == '__main__':
    unittest.main()

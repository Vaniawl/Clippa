"""Mutation controls for the UI governance artifact gate after reference extraction."""
from __future__ import annotations

import importlib.util
import json
from pathlib import Path
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location('artifact_evals', ROOT / 'scripts/agent-framework/evals/run-evals.py')
evals = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(evals)

SKILL = 'agent-framework/canonical/skills/ui-ux-review/SKILL.md'
BRANDED = 'agent-framework/canonical/skills/ui-ux-review/references/web-branded.md'
NATIVE = 'agent-framework/canonical/skills/ui-ux-review/references/native-apple.md'
ROUTER = 'agent-framework/canonical/policies/apple-product-engineering.md'
STANDARD = 'agent-framework/canonical/policies/apple-product-engineering-reference.md'
BASE = 'agent-framework/design-system/tokens/base.json'
DARK = 'agent-framework/design-system/tokens/dark.json'


class UITokenArtifactGateTests(unittest.TestCase):
    def verdict(self, changed=None, missing=None):
        original_read = evals.read
        def read(path):
            if path == missing:
                raise FileNotFoundError(path)
            return changed[path] if changed and path in changed else original_read(path)
        with mock.patch.object(evals, 'read', side_effect=read), mock.patch.object(evals, 'record') as record:
            evals.e13_ui_tokens()
        record.assert_called_once()
        return record.call_args.args[1]

    def test_extracted_native_and_brand_procedures_pass(self):
        self.assertTrue(self.verdict())

    def test_missing_or_unlinked_references_fail(self):
        for path in (BRANDED, NATIVE, ROUTER, STANDARD):
            with self.subTest(missing=path):
                self.assertFalse(self.verdict(missing=path))
        for path, link in ((SKILL, '(references/web-branded.md)'),
                           (SKILL, '(references/native-apple.md)'),
                           (ROUTER, 'apple-product-engineering-reference.md](apple-product-engineering-reference.md)')):
            with self.subTest(unlinked=link):
                text = evals.read(path)
                self.assertIn(link, text)
                self.assertFalse(self.verdict({path: text.replace(link, '(missing.md)')}))

    def test_brand_prohibition_escalation_and_approval_controls_remain_binding(self):
        for phrase in ('NEVER invent', '`Candidate`', 'do not improvise a value',
                       'REQUIRE documented brand-owner approval', 'review FAILURE'):
            with self.subTest(removed=phrase):
                text = evals.read(BRANDED)
                self.assertIn(phrase, text)
                self.assertFalse(self.verdict({BRANDED: text.replace(phrase, '')}))

    def test_nonempty_source_metadata_and_proposed_status_are_required(self):
        base = json.loads(evals.read(BASE))
        token = next(iter(base['brand']['color'].values()))
        for extensions in ({}, {'source': []}, {'source': ['']}):
            with self.subTest(extensions=extensions):
                token['$extensions'] = extensions
                self.assertFalse(self.verdict({BASE: json.dumps(base)}))
        dark = json.loads(evals.read(DARK))
        dark['$status'] = 'extracted'
        self.assertFalse(self.verdict({DARK: json.dumps(dark)}))

    def test_native_semantics_custom_scale_and_core_approval_controls_remain(self):
        for path, phrase in ((STANDARD, 'small consistent scale rather than arbitrary values'),
                             (STANDARD, 'Prefer Apple system typography'),
                             (STANDARD, 'suitable native control'),
                             (NATIVE, 'native semantic'),
                             (NATIVE, 'documented brand-owner approval'),
                             ('AGENTS.md', 'system semantic controls'),
                             ('AGENTS.md', 'instead of arbitrary'),
                             ('AGENTS.md', 'Branded surfaces use their adopted, approved tokens'),
                             ('AGENTS.md', 'tokens retain their approval requirements')):
            with self.subTest(removed=phrase):
                text = evals.read(path)
                self.assertIn(phrase, text)
                self.assertFalse(self.verdict({path: text.replace(phrase, '')}))


if __name__ == '__main__':
    unittest.main()

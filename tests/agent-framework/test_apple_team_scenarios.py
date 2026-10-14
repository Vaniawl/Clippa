"""Eval coverage and evidence classification, never assertions that a model passed."""
from __future__ import annotations

import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

import yaml

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location(
    'apple_scenarios', ROOT / 'scripts/agent-framework/evals/check-apple-team-scenarios.py')
scenarios = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(scenarios)


class AppleScenarioTests(unittest.TestCase):
    def test_catalog_coverage_has_no_predeclared_live_passes(self):
        cases = scenarios.load_suite(ROOT)
        self.assertEqual({c['role'] for c in cases},
                         {p.stem for p in (ROOT / 'agent-framework/canonical/roles').glob('*.yaml')})
        self.assertEqual(scenarios.observation_statuses(cases, None), {})

    def test_missing_role_coverage_and_fixture_claims_fail(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            roles = root / 'agent-framework/canonical/roles'
            roles.mkdir(parents=True)
            (roles / 'one.yaml').touch()
            (roles / 'two.yaml').touch()
            suite = root / 'agent-framework/evals/apple-team-scenarios.yaml'
            suite.parent.mkdir(parents=True)
            case = dict(id='A01', role='one', prompt='A real request', criteria=['An observable result'],
                        initial_live_status='NOT RUN')
            suite.write_text(yaml.safe_dump({'scenarios': [case]}))
            with self.assertRaisesRegex(ValueError, 'missing scenarios'):
                scenarios.load_suite(root)
            (roles / 'two.yaml').unlink()
            case['initial_live_status'] = 'PASS'
            suite.write_text(yaml.safe_dump({'scenarios': [case]}))
            with self.assertRaisesRegex(ValueError, 'predeclare'):
                scenarios.load_suite(root)

    def test_grades_require_transcript_all_criteria_and_honest_classification(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            path = root / 'observations.json'
            cases = [dict(id='A01', criteria=['One', 'Two'])]
            observation = dict(case_id='A01', provider='test', version='fixture',
                               selection='role-contract-adapter', transcript='transcript.txt',
                               checks=[dict(status='PASS', evidence='Observed step one'),
                                       dict(status='PASS', evidence='Observed step two')])
            path.write_text(json.dumps([observation]))
            with self.assertRaisesRegex(ValueError, 'transcript'):
                scenarios.observation_statuses(cases, path)
            (root / 'transcript.txt').write_text('Synthetic test record, not actual model evidence')
            self.assertEqual(scenarios.observation_statuses(cases, path), {'A01': 'REPORTED PASS'})
            for grade, expected in [('NOT RUN', 'NOT RUN'), ('FAIL', 'FAIL')]:
                observation['checks'][1]['status'] = grade
                path.write_text(json.dumps([observation]))
                self.assertEqual(scenarios.observation_statuses(cases, path), {'A01': expected})
            observation['checks'].pop()
            path.write_text(json.dumps([observation]))
            with self.assertRaisesRegex(ValueError, 'every criterion'):
                scenarios.observation_statuses(cases, path)


if __name__ == '__main__':
    unittest.main()

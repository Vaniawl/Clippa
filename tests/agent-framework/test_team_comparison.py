"""A benchmark cannot pass when evaluation or delegation evidence is unresolved."""
from __future__ import annotations
import contextlib
import importlib.util
import io
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location('team_comparison', ROOT / 'scripts/agent-framework/evals/compare-apple-team.py')
COMPARISON = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(COMPARISON)


class ComparisonGateTests(unittest.TestCase):
    def evaluate(self, behavior, orchestration, routing='PASS'):
        with tempfile.TemporaryDirectory() as temporary:
            result = {'case': 'feature', 'mode': 'team', 'exit_code': 0, 'ownership': 'PASS',
                      'behavior': behavior, 'orchestration': orchestration, 'routing': routing}
            with mock.patch.object(sys, 'argv', ['compare', '--live', '--case', 'feature', '--artifacts-dir', temporary]), \
                 mock.patch.object(COMPARISON.shutil, 'which', return_value='/bin/codex-fixture'), \
                 mock.patch.object(COMPARISON.subprocess, 'run', return_value=subprocess.CompletedProcess([], 0, 'fixture-version')), \
                 mock.patch.object(COMPARISON, 'trial', return_value=result), \
                 mock.patch.object(COMPARISON.smoke, 'source_digest', return_value='fixture-source-digest'), contextlib.redirect_stdout(io.StringIO()):
                code = COMPARISON.main()
            report = json.loads((Path(temporary) / 'report.json').read_text())
            return code, report['status']

    def test_unobservable_workers_cannot_pass(self):
        self.assertEqual(self.evaluate('PASS', 'NOT VERIFIED'), (2, 'NEEDS REVIEW'))

    def test_timed_out_evaluator_cannot_pass(self):
        self.assertEqual(self.evaluate('BLOCKED: evaluator exceeded 20s', 'PASS'), (2, 'NEEDS REVIEW'))

    def test_ux_needs_actual_rubric_review(self):
        self.assertEqual(self.evaluate('NEEDS HUMAN RUBRIC REVIEW', 'PASS'), (2, 'NEEDS REVIEW'))

    def test_failed_behavior_fails(self):
        self.assertEqual(self.evaluate('FAIL', 'PASS'), (1, 'FAIL'))

    def test_complete_measured_evidence_passes(self):
        self.assertEqual(self.evaluate('PASS', 'PASS'), (0, 'PASS'))

    def test_completed_wrong_route_cannot_pass(self):
        self.assertEqual(self.evaluate('PASS', 'PASS', 'NOT VERIFIED'), (2, 'NEEDS REVIEW'))


class AutomaticRoutingTests(unittest.TestCase):
    def test_correct_routes_and_unnecessary_specialists(self):
        for case in ('docs', 'market', 'feature'):
            expected = COMPARISON.CASES[case]['roles']
            self.assertTrue(COMPARISON.routing_passes({'roles_observed': expected}, expected))
            self.assertFalse(COMPARISON.routing_passes({'roles_observed': ['ui-ux-designer']}, expected))
            self.assertFalse(COMPARISON.routing_passes({'roles_observed': expected + ['software-architect']}, expected))

    def test_policy_mentions_are_not_apple_domain_reads(self):
        prose = {'method': 'item/completed', 'params': {'item': {'type': 'agentMessage',
                 'text': 'No need for apple-product-engineering-reference.md here.'}}}
        self.assertEqual(COMPARISON.apple_domain_commands([prose]), [])
        command = {'method': 'item/completed', 'params': {'item': {'type': 'commandExecution',
                   'command': 'cat agent-framework/canonical/policies/apple-product-engineering-reference.md'}}}
        self.assertTrue(COMPARISON.apple_domain_commands([command]))

    def test_delegation_instructions_are_not_file_reads(self):
        message = 'Correct README typo. Do not load apple-product-engineering-reference.md'
        delegation = {'method': 'rawResponseItem/completed', 'params': {'item': {
            'type': 'function_call', 'name': 'spawn_agent', 'arguments': json.dumps({'message': message})}}}
        self.assertEqual(COMPARISON.apple_domain_commands([delegation]), [])
        self.assertEqual(COMPARISON.apple_domain_observations([delegation])['unverified_mentions'], [])
        wrapper = {'method': 'rawResponseItem/completed', 'params': {'item': {
            'type': 'function_call', 'name': 'functions.exec',
            'arguments': 'await tools.spawn_agent({message: ' + json.dumps(message) + '})'}}}
        self.assertEqual(COMPARISON.apple_domain_commands([wrapper]), [])
        self.assertEqual(COMPARISON.apple_domain_observations([wrapper])['unverified_mentions'],
                         ['apple-product-engineering-reference.md'])

    def test_market_advice_mutation_is_reported_as_ownership_failure(self):
        with tempfile.TemporaryDirectory() as artifacts:
            def write_during_advice(cli, root, prompt, timeout):
                # A provider that ignores advise mode cannot obtain an ownership
                # pass even if it claims the advice was read-only in its answer.
                (root / 'unapproved.txt').write_text('unexpected tracked product work')
                return subprocess.CompletedProcess([], 0, '', '')
            with mock.patch.object(COMPARISON.smoke, 'run_appserver', side_effect=write_during_advice):
                result = COMPARISON.trial(ROOT, 'market', 'team', '/unused', 20, Path(artifacts))
            self.assertEqual(result['ownership'], 'FAIL')
            self.assertIn('unapproved.txt', result['changed_files'])


class UXRoleSequenceTests(unittest.TestCase):
    def test_designer_then_skeptic_is_verified(self):
        def item(tool, **fields):
            return {'type': 'item.completed', 'item': {'type': 'collabAgentToolCall', 'tool': tool, 'status': 'completed', **fields}}
        events = [
            item('spawnAgent', id='design-spawn', agentPath='/root/ui_ux_designer', receiverThreadIds=['designer']),
            item('wait', agentsStates={'designer': {'status': 'completed', 'message': 'DESIGN_MARKER'}}),
            item('spawnAgent', id='review-spawn', agentPath='/root/skeptical_reviewer', receiverThreadIds=['critic']),
            item('wait', agentsStates={'critic': {'status': 'completed', 'message': 'CRITIC_MARKER'}}),
            {'type': 'turn.completed'},
        ]
        roles = {'ui-ux-designer': 'DESIGN_MARKER', 'skeptical-reviewer': 'CRITIC_MARKER'}
        proof = COMPARISON.smoke.verify_events(events, list(roles.values()), role_markers=roles,
                                               review_markers=('DESIGN_MARKER', 'CRITIC_MARKER'))
        self.assertTrue(proof['independent_review_sequence'])
        self.assertTrue(proof['role_instruction_propagation'])
        self.assertTrue(proof['workers_completed'])
        reversed_proof = COMPARISON.smoke.verify_events([events[2], events[3], events[0], events[1], events[4]],
                                                       list(roles.values()), role_markers=roles,
                                                       review_markers=('DESIGN_MARKER', 'CRITIC_MARKER'))
        self.assertFalse(reversed_proof['independent_review_sequence'])


class ModelInheritanceTests(unittest.TestCase):
    def test_explicit_overrides_prevent_team_pass(self):
        proof = {'completed_worker_ids': ['author', 'reviewer'], 'workers_completed': True,
                 'real_wait': True, 'turn_completed': True, 'role_instruction_propagation': True,
                 'independent_review_sequence': True}
        self.assertTrue(COMPARISON.team_proof_passes(proof, 2))
        for key in ('explicit_model_overrides', 'explicit_reasoning_overrides'):
            with self.subTest(key=key):
                self.assertFalse(COMPARISON.team_proof_passes({**proof, key: ['override']}, 2))


class BoundedAdviceRouteTests(unittest.TestCase):
    def test_single_designer_needs_completed_parent_and_role(self):
        proof = {'completed_worker_ids': ['designer'], 'workers_completed': True,
                 'real_wait': True, 'turn_completed': True, 'role_instruction_propagation': True,
                 'independent_review_sequence': False}
        self.assertTrue(COMPARISON.team_proof_passes(proof, 1))
        self.assertFalse(COMPARISON.team_proof_passes(proof, 2))
        self.assertFalse(COMPARISON.team_proof_passes({**proof, 'turn_completed': False}, 1))
        self.assertFalse(COMPARISON.team_proof_passes({**proof, 'role_instruction_propagation': False}, 1))

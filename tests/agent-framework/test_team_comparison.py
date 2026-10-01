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
    def evaluate(self, behavior, orchestration):
        with tempfile.TemporaryDirectory() as temporary:
            result = {'case': 'feature', 'mode': 'team', 'exit_code': 0, 'ownership': 'PASS',
                      'behavior': behavior, 'orchestration': orchestration}
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

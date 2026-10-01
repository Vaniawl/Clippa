"""A benchmark cannot pass when evaluation or delegation evidence is unresolved."""
from __future__ import annotations
import contextlib
import importlib.util
import io
import json
from pathlib import Path
import re
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
    def evaluate(self, behavior, orchestration, routing='PASS', **fields):
        with tempfile.TemporaryDirectory() as temporary:
            result = {'case': 'feature', 'mode': 'team', 'exit_code': 0, 'ownership': 'PASS',
                      'behavior': behavior, 'orchestration': orchestration, 'routing': routing, **fields}
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

    def test_unnecessary_delegation_fails(self):
        self.assertEqual(self.evaluate('PASS', 'FAIL', 'FAIL', mode='adaptive'), (1, 'FAIL'))

    def test_timed_out_and_mutating_advice_fail(self):
        self.assertEqual(self.evaluate('NEEDS HUMAN RUBRIC REVIEW', 'NOT VERIFIED', exit_code=124), (1, 'FAIL'))
        self.assertEqual(self.evaluate('NEEDS HUMAN RUBRIC REVIEW', 'PASS', ownership='FAIL'), (1, 'FAIL'))


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


class AdaptiveRouteTests(unittest.TestCase):
    @staticmethod
    def parent_events(status='completed'):
        return [{'id': 2, 'result': {'thread': {'id': 'parent'}}},
                {'method': 'item/completed', 'params': {'threadId': 'parent',
                 'item': {'type': 'agentMessage', 'text': 'Bounded outcome and checks completed.'}}},
                {'method': 'turn/completed', 'params': {'threadId': 'parent',
                 'turn': {'id': 'parent-turn', 'status': status}}}]

    def run_trial(self, case, events=None, *, mode='adaptive', mutate=None, timeout=False):
        events = self.parent_events() if events is None else events
        def provider(cli, root, prompt, duration):
            if case == 'docs':
                (root / 'README.md').write_text('This application keeps notes locally.\n')
            elif case == 'feature':
                (root / 'filter_items.py').write_text(
                    'def filter_items(items, query):\n'
                    '    return [item for item in items if query.casefold() in item.casefold()]\n')
            elif case == 'bug':
                path = root / 'loader.py'
                path.write_text(path.read_text().replace(
                    "self.busy = False if self.state != 'failure' else True", 'self.busy = False'))
            if mutate:
                mutate(root)
            actual_events = events(root) if callable(events) else events
            stdout = '\n'.join(json.dumps(event) for event in actual_events)
            if timeout:
                raise subprocess.TimeoutExpired('fixture', duration, output=stdout)
            return subprocess.CompletedProcess([], 0, stdout, '')
        with tempfile.TemporaryDirectory() as artifacts, \
             mock.patch.object(COMPARISON.smoke, 'run_appserver', side_effect=provider):
            return COMPARISON.trial(ROOT, case, mode, '/unused', 20, Path(artifacts))

    def test_bounded_document_and_code_complete_without_workers(self):
        for case in ('docs', 'feature', 'bug'):
            with self.subTest(case=case):
                result = self.run_trial(case)
                self.assertEqual(result['behavior'], 'PASS')
                self.assertEqual(result['ownership'], 'PASS')
                self.assertEqual(result['orchestration'], 'PASS')
                self.assertEqual(result['routing'], 'PASS')
                self.assertEqual(result['spawn_attempt_count'], 0)
                self.assertEqual(result['completed_worker_ids'], [])
                self.assertEqual(result['expected_roles'], [])
                self.assertFalse(result['independent_review_sequence'])

    def test_read_only_advice_zero_workers_still_requires_rubric(self):
        for case in ('market', 'ux'):
            with self.subTest(case=case):
                result = self.run_trial(case)
                self.assertEqual(result['ownership'], 'PASS')
                self.assertEqual(result['orchestration'], 'PASS')
                self.assertEqual(result['spawn_attempt_count'], 0)
                self.assertEqual(result['behavior'], 'NEEDS HUMAN RUBRIC REVIEW')

    def test_parent_completion_required_even_when_behavior_passes(self):
        child_only = [{'method': 'turn/completed', 'params': {'threadId': 'child',
                      'turn': {'status': 'completed'}}}]
        for events in ([], child_only, self.parent_events('failed')):
            with self.subTest(events=events):
                result = self.run_trial('docs', events)
                self.assertEqual(result['behavior'], 'PASS')
                self.assertEqual(result['orchestration'], 'NOT VERIFIED')
                self.assertFalse(result['parent_turn_completed'])

    def test_legacy_cli_events_cannot_certify_appserver_parent(self):
        invalid = [
            [{'type': 'turn.completed'}],
            [{'type': 'turn.completed', 'turn': {'status': 'failed'}}],
            [{'type': 'turn.completed', 'thread_id': 'child', 'status': 'completed'}],
            [self.parent_events()[0], {'type': 'turn.completed', 'thread_id': 'parent', 'status': 'completed'}],
            [{'method': 'turn/completed', 'params': {'threadId': 'parent', 'turn': {'status': 'completed'}}}],
            [self.parent_events()[0], {'method': 'turn/completed', 'params': {
                'threadId': 'child', 'turn': {'status': 'completed'}}}],
            [self.parent_events()[0], {'method': 'turn/completed', 'params': {'threadId': 'parent', 'turn': {}}}],
        ]
        for mode in ('adaptive', 'solo'):
            for events in invalid:
                with self.subTest(mode=mode, events=events):
                    result = self.run_trial('docs', events, mode=mode)
                    self.assertEqual(result['behavior'], 'PASS')
                    self.assertEqual(result['orchestration'], 'NOT VERIFIED')
                    self.assertFalse(result['parent_turn_completed'])

    def test_actual_behavior_and_ownership_are_checked(self):
        result = self.run_trial('feature', mutate=lambda root: (root / 'filter_items.py').write_text(
            'def filter_items(items, query):\n    return []\n'))
        self.assertEqual(result['behavior'], 'FAIL')
        result = self.run_trial('docs', mutate=lambda root: (root / 'PROJECT.md').write_text('unauthorized'))
        self.assertEqual(result['behavior'], 'PASS')
        self.assertEqual(result['ownership'], 'FAIL')

    def test_timed_out_and_mutating_advice_cannot_pass(self):
        result = self.run_trial('market', timeout=True)
        self.assertEqual(result['exit_code'], 124)
        self.assertEqual(result['orchestration'], 'NOT VERIFIED')
        result = self.run_trial('market', mutate=lambda root: (root / 'unapproved.txt').write_text('work'))
        self.assertEqual(result['ownership'], 'FAIL')

    def test_successful_and_failed_spawn_attempts_are_rejected(self):
        attempts = [
            {'type': 'item.completed', 'item': {'id': 'successful', 'type': 'collabAgentToolCall',
             'tool': 'spawnAgent', 'status': 'completed', 'receiverThreadIds': ['worker']}},
            {'type': 'item.completed', 'item': {'id': 'failed', 'type': 'collabAgentToolCall',
             'tool': 'spawnAgent', 'status': 'failed'}},
            {'method': 'rawResponseItem/completed', 'params': {'item': {'type': 'function_call',
             'name': 'spawn_agent', 'call_id': 'raw-failed', 'arguments': '{}'}}},
            {'method': 'rawResponseItem/completed', 'params': {'item': {'type': 'function_call',
             'name': 'functions.exec', 'call_id': 'wrapped-failed',
             'arguments': 'await tools.spawn_agent({task_name: "writer"})'}}},
        ]
        for attempt in attempts:
            with self.subTest(attempt=attempt):
                result = self.run_trial('docs', [attempt, *self.parent_events()])
                self.assertEqual(result['behavior'], 'PASS')
                self.assertEqual(result['orchestration'], 'FAIL')
                self.assertEqual(result['routing'], 'FAIL')
                self.assertEqual(result['spawn_attempt_count'], 1)

    def test_direct_proof_rejects_overrides(self):
        proof = {'turn_completed': True}
        self.assertTrue(COMPARISON.direct_proof_passes(proof, []))
        for key in ('explicit_model_overrides', 'explicit_reasoning_overrides'):
            self.assertFalse(COMPARISON.direct_proof_passes({**proof, key: ['override']}, []))

    def test_no_role_criteria_or_mandatory_delegation_in_adaptive_prompt(self):
        for case in COMPARISON.CASES.values():
            prompt = COMPARISON.trial_prompt(case, 'adaptive', Path('/fixture'))
            self.assertIn('Call a subagent only when', prompt)
            self.assertIn('Work directly as the main agent', prompt)
            self.assertNotIn('Do not implement', prompt)
            self.assertNotIn('use real subagents', prompt)
            for role in case['roles']:
                self.assertNotIn(role, prompt)

    def test_default_invocation_adaptive_and_comparison_is_explicit(self):
        for flag, expected in (([], ['adaptive']), (['--mode', 'comparison'], ['solo', 'team'])):
            with self.subTest(flag=flag), tempfile.TemporaryDirectory() as artifacts:
                result = {'exit_code': 0, 'ownership': 'PASS', 'behavior': 'PASS',
                          'orchestration': 'PASS', 'routing': 'PASS'}
                with mock.patch.object(sys, 'argv', ['compare', '--live', '--case', 'docs',
                     '--artifacts-dir', artifacts, *flag]), \
                     mock.patch.object(COMPARISON.shutil, 'which', return_value='/unused'), \
                     mock.patch.object(COMPARISON.subprocess, 'run', return_value=subprocess.CompletedProcess([], 0, 'fixture-version')), \
                     mock.patch.object(COMPARISON.smoke, 'source_digest', return_value='fixture'), \
                     mock.patch.object(COMPARISON, 'trial', return_value=result) as trial, \
                     contextlib.redirect_stdout(io.StringIO()):
                    self.assertEqual(COMPARISON.main(), 0)
                self.assertEqual([call.args[2] for call in trial.call_args_list], expected)

    def test_forced_team_still_requires_workers_and_independent_review(self):
        result = self.run_trial('feature', mode='team')
        self.assertEqual(result['behavior'], 'PASS')
        self.assertEqual(result['orchestration'], 'NOT VERIFIED')
        self.assertEqual(result['routing'], 'NOT VERIFIED')
        self.assertEqual(result['expected_roles'], ['implementation-engineer', 'code-reviewer'])
        self.assertIn('explicitly requested forced-team benchmark',
                      COMPARISON.trial_prompt(COMPARISON.CASES['feature'], 'team', Path('/fixture')))

    def test_forced_team_requires_actual_role_results_in_final_revision_order(self):
        def worker_events(root, *, missing_marker=False, reversed_order=False, shared_worker=False):
            role_dir = root / 'agent-framework/canonical/roles'
            markers = [re.search(r'TRIAL_ROLE_[a-f0-9]+', (role_dir / (role + '.yaml')).read_text()).group()
                       for role in ('implementation-engineer', 'code-reviewer')]
            def spawn(role, worker):
                return {'type': 'item.completed', 'item': {'id': role, 'type': 'collabAgentToolCall',
                        'tool': 'spawnAgent', 'status': 'completed', 'agentPath': '/root/' + role,
                        'receiverThreadIds': [worker]}}
            def wait(worker, marker):
                return {'type': 'item.completed', 'item': {'type': 'collabAgentToolCall',
                        'tool': 'wait', 'status': 'completed',
                        'agentsStates': {worker: {'status': 'completed', 'message': marker}}}}
            author = [spawn('implementation_engineer', 'author'), wait('author', markers[0])]
            reviewer_id = 'author' if shared_worker else 'reviewer'
            reviewer = [spawn('code_reviewer', reviewer_id),
                        wait(reviewer_id, 'Unverified role result' if missing_marker else markers[1])]
            return (reviewer + author if reversed_order else author + reviewer) + self.parent_events()

        valid = self.run_trial('feature', worker_events, mode='team')
        self.assertEqual(valid['orchestration'], 'PASS')
        self.assertEqual(valid['routing'], 'PASS')
        self.assertEqual(valid['completed_worker_ids'], ['author', 'reviewer'])
        self.assertTrue(valid['independent_review_sequence'])
        for options in ({'missing_marker': True}, {'reversed_order': True}, {'shared_worker': True}):
            with self.subTest(options=options):
                invalid = self.run_trial('feature', lambda root: worker_events(root, **options), mode='team')
                self.assertEqual(invalid['behavior'], 'PASS')
                self.assertEqual(invalid['orchestration'], 'NOT VERIFIED')

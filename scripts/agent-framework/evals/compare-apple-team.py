#!/usr/bin/env python3
"""Opt-in on-demand trials, or explicit solo/team benchmarks; never a native Apple UI proof."""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import re
import secrets
import yaml
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time

SCRIPTS = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(SCRIPTS))
from _lib import REPO_ROOT

spec = importlib.util.spec_from_file_location('team_smoke', SCRIPTS / 'smoke-team.py')
smoke = importlib.util.module_from_spec(spec)
spec.loader.exec_module(smoke)

CASES = {
    'docs': {
        'file': 'README.md',
        'source': 'This applicaton keeps notes locally.\n',
        'request': 'Correct only the spelling typo in README.md. Preserve its meaning. This is a documentation edit, with no app behavior, native UI, architecture or product change. Only README.md may change.',
        'tests': "import unittest\nfrom pathlib import Path\nclass Checks(unittest.TestCase):\n    def test_document(self):\n        self.assertEqual(Path('README.md').read_text(), 'This application keeps notes locally.\\n')\n",
        'roles': ['technical-writer'],
        'forbidden_domain_reads': True,
    },
    'market': {
        'file': None,
        'request': 'Give market advice about an offline focus timer for university students. Compare the supplied alternatives: phone Clock is already installed; paper timers require no account. No customer interviews, conversion data or willingness-to-pay evidence exist. Identify what is supported versus unknown and recommend one next market-validation step. Advice only: no files, product implementation, design work, empirical claims or external actions.',
        'roles': ['market-opportunity-researcher'],
        'forbidden_domain_reads': True,
    },
    'feature': {
        'file': 'filter_items.py',
        'source': 'def filter_items(items, query):\n    raise NotImplementedError\n',
        'request': 'Implement the approved local case-insensitive substring filter. Preserve order and input; an empty query returns all items. Unicode case-folding is required. Only filter_items.py may change.',
        'tests': '''import unittest
from filter_items import filter_items
class Checks(unittest.TestCase):
    def test_query(self):
        self.assertEqual(filter_items(['Alpine', 'beta', 'Alpha'], 'AL'), ['Alpine', 'Alpha'])
    def test_empty_and_input(self):
        data = ['A', 'B']
        self.assertEqual(filter_items(data, ''), data)
        self.assertEqual(data, ['A', 'B'])
        self.assertEqual(filter_items([], 'a'), [])
    def test_unicode(self):
        self.assertEqual(filter_items(['Straße', 'other'], 'STRASSE'), ['Straße'])
''',
        'roles': ['implementation-engineer', 'code-reviewer'],
    },
    'bug': {
        'file': 'loader.py',
        'source': '''class Loader:
    def __init__(self, repository):
        self.repository = repository
        self.busy = False
        self.state = 'idle'
    def load(self):
        if self.busy:
            return
        self.busy = True
        try:
            self.state = self.repository()
        except Exception:
            self.state = 'failure'
        self.busy = False if self.state != 'failure' else True
''',
        'request': 'Fix the approved bug: first load fails and the user cannot retry. Restore retry availability after failure while retaining duplicate-request protection. Only loader.py may change.',
        'tests': '''import unittest
from loader import Loader
class Checks(unittest.TestCase):
    def test_retry(self):
        calls = []
        def repository():
            calls.append(1)
            if len(calls) == 1: raise ValueError('offline')
            return 'content'
        model = Loader(repository)
        model.load()
        self.assertEqual(model.state, 'failure')
        model.load()
        self.assertEqual(model.state, 'content')
        self.assertFalse(model.busy)
        self.assertEqual(len(calls), 2)
    def test_duplicate(self):
        calls = []
        def repository():
            calls.append(1)
            model.load()
            return 'content'
        model = Loader(repository)
        model.load()
        self.assertEqual(len(calls), 1)
        self.assertEqual(model.state, 'content')
''',
        'roles': ['implementation-engineer', 'code-reviewer'],
    },
    'ux': {
        'file': None,
        'request': 'Advise on an iPhone/Mac document-list refresh failure when previous content exists. Give one recommendation with states, recovery copy, primary action, long content, VoiceOver, large text, keyboard and Reduce Motion. Offline document access is unconfirmed. No edits, no empirical claims, no implementation. End with a JSON object whose keys are recommendation, states, copy, accessibility, unknowns, verification_plan.',
        'roles': ['ui-ux-designer'],
    },
}


def team_proof_passes(proof, role_count):
    return (len(proof.get("completed_worker_ids", [])) >= role_count
            and all(proof.get(key, False) for key in ("workers_completed", "real_wait", "turn_completed", "role_instruction_propagation"))
            and (role_count == 1 or proof.get("independent_review_sequence", False))
            and not proof.get("explicit_model_overrides")
            and not proof.get("explicit_reasoning_overrides"))


def routing_passes(proof, expected_roles):
    """Expected roles live only in the evaluator, never in the user prompt."""
    return set(proof.get('roles_observed', [])) == set(expected_roles)


def spawn_attempts(events):
    """Count attempted calls, including failures and wrappers without child evidence.

    Completed workers are positive team evidence; absence of completed workers
    is insufficient evidence that the coordinator avoided delegation.
    """
    attempts = set()
    for item in smoke.collaboration_items(events):
        if item.get('tool') in ('spawn_agent', 'spawnAgent'):
            attempts.add(str(item.get('id') or f'collaboration-{len(attempts)}'))
    for index, event in enumerate(events):
        item = event.get('params', {}).get('item', event.get('item', {}))
        if (event.get('method') != 'rawResponseItem/completed'
                or item.get('type') != 'function_call'):
            continue
        name = item.get('name', '').rsplit('.', 1)[-1]
        arguments = item.get('arguments', '')
        direct = name in ('spawn_agent', 'spawnAgent')
        wrapped = name == 'exec' and isinstance(arguments, str) and re.search(
            r'\b(?:spawn_agent|spawnAgent)\s*\(', arguments)
        if direct or wrapped:
            attempts.add(str(item.get('call_id') or item.get('id') or f'raw-{index}'))
    return sorted(attempts)


def direct_proof_passes(proof, attempts):
    """Parent verification is a self-check, never an independent review."""
    return (proof.get('turn_completed', False) and not attempts
            and not proof.get('explicit_model_overrides')
            and not proof.get('explicit_reasoning_overrides'))


def parent_turn_completed(events):
    """These trials use app-server transport; only its identified parent counts.

    Legacy CLI turn.completed items do not prove the parent thread or a
    successful status, and cannot certify this transport's completion gate.
    """
    parent = next((event.get('result', {}).get('thread', {}).get('id')
                   for event in events if event.get('id') == 2
                   and event.get('result', {}).get('thread', {}).get('id')), None)
    return bool(parent) and any(
        event.get('method') == 'turn/completed'
        and event.get('params', {}).get('threadId') == parent
        and event.get('params', {}).get('turn', {}).get('status') == 'completed'
        for event in events)


def trial_prompt(case, mode, root):
    prompt = case['request'] + ' This is a fully specified isolated trial. Use no external actions or model overrides. PYTHONDONTWRITEBYTECODE=1 for all Python commands. No saved coordination documents. '
    if mode == 'solo':
        prompt += 'For this comparison act as the single specialist directly. Do not spawn subagents. Complete and verify only this outcome. '
    elif mode == 'adaptive':
        prompt += ('Work directly as the main agent. Call a subagent only when this task needs specific expertise, '
                   'useful independent parallel work, or an independent review justified by its complexity or risk. '
                   'Decide from the actual task whether delegation is needed; routine self-checks may be performed directly '
                   'and must not be described as independent review. Complete and verify the bounded outcome. ')
    else:
        prompt += 'This is an explicitly requested forced-team benchmark. Pass the absolute fixture path ' + str(root) + ' and relevant approved requirements into every worker contract. This fixture has no native Apple target; immutable checks are Python only. Act as the coordinator and use real subagents with inherited models. Choose the smallest appropriate route from the canonical role catalog and current request; implementation needs independent review after the writer finishes. Do not implement the requested work yourself. '
        task_mode = 'execute' if case['file'] else 'advise'
        prompt += f'Before issuing each contract read the canonical role and relevant skills. Use native role selection if exposed; otherwise generic spawn task_name=<role_with_hyphens_replaced_by_underscores> with role instructions and required relevant skills explicitly in the message. Contracts specify mode={task_mode}, approved outcome, context, ownership, prohibited files, output, criteria, validation commands, current revision, dependencies, retry_limit=2, may_delegate=false and stop after this outcome. Reviewers/QA must independently inspect and verify the final revision. QA may run tests but owns no source files here. Use fork_turns=none with minimal explicit task context and wait for completed results. '
    if case['file']:
        prompt += 'Run python3 -B -m unittest test_behavior.py before claiming completion. '
        if mode == 'team':
            prompt += 'Review and QA receive only the task, diff and actual test output, not author conclusions as facts. '
    return prompt


def apple_domain_observations(events):
    """Separate executed commands from ambiguous code-mode argument mentions."""
    reads = set()
    ambiguous = set()
    paths = ('apple-product-engineering-reference.md', 'ios-development/', 'ios-quality/',
             'ios-testing/', 'macos-development/', 'references/native-apple.md')
    for event in events:
        item = event.get('params', {}).get('item', event.get('item', {}))
        command = item.get('command', '') if (item.get('type') == 'commandExecution'
                   and (event.get('method') == 'item/completed' or event.get('type') == 'item.completed')) else ''
        if event.get('method') == 'rawResponseItem/completed' and item.get('type') == 'function_call':
            # Raw function arguments are not execution results. A wrapper may
            # contain delegation prose saying not to read a file. Preserve
            # code-mode ambiguity separately; never count it as a file read.
            if item.get('name') in ('functions.exec', 'exec'):
                arguments = item.get('arguments', '')
                if isinstance(arguments, str):
                    ambiguous.update(path for path in paths if path in arguments)
        if isinstance(command, str):
            reads.update(path for path in paths if path in command)
    return {'commands': sorted(reads), 'unverified_mentions': sorted(ambiguous)}


def apple_domain_commands(events):
    return apple_domain_observations(events)['commands']


def trial(source, case_name, mode, cli, timeout, artifacts):
    case = CASES[case_name]
    started = time.monotonic()
    source_digest_before_copy = smoke.source_digest(source)
    with tempfile.TemporaryDirectory(prefix='apple-team-comparison-') as temporary:
        root = Path(temporary).resolve()
        for directory in ('agent-framework/canonical', 'agent-framework/catalogs', 'agent-framework/templates', '.agents/skills', '.codex'):
            shutil.copytree(source / directory, root / directory)
        shutil.copy2(source / 'AGENTS.md', root / 'AGENTS.md')
        (root / 'PROJECT.md').write_text('# Isolated local fixture\n' + case['request'] + '\n')
        (root / 'docs/product').mkdir(parents=True)
        (root / 'docs/security').mkdir(parents=True)
        (root / 'docs/testing').mkdir(parents=True)
        (root / 'docs/adr').mkdir(parents=True)
        (root / 'docs/product/product-vision.md').write_text('# Fixture vision\n' + case['request'] + '\nNo additional product direction is authorized.\n')
        (root / 'docs/product/pov-scope.md').write_text('# Scope\nOnly the requested fixture outcome.\n')
        (root / 'docs/security/threat-model.md').write_text('# Boundaries\nOffline disposable fixture. No secrets, network, external actions or dependencies.\n')
        (root / 'docs/testing/test-strategy.md').write_text('# Checks\nPython immutable test_behavior.py for code. UX advice is specification only; runtime UI NOT RUN.\n')
        (root / 'BACKLOG.md').write_text('# Approved outcome\n' + case['request'] + '\nStop at this outcome.\n')
        (root / 'project.yaml').write_text('agent_framework:\n  team:\n    default_mode: advise\n    max_parallel_workers: 3\n')
        if case['file']:
            (root / case['file']).write_text(case['source'])
            (root / 'test_behavior.py').write_text(case['tests'])
        role_markers = {}
        if mode == 'team':
            # Mark every discoverable role identically so the coordinator cannot
            # infer the evaluator's expected route from which roles have markers.
            for path in sorted((root / 'agent-framework/canonical/roles').glob('*.yaml')):
                role = path.stem
                definition = yaml.safe_load(path.read_text())
                marker = 'TRIAL_ROLE_' + secrets.token_hex(8)
                definition['notes'] = str(definition.get('notes', '')) + f'\nFor this isolated trial return {marker} in the final specialist result.'
                path.write_text(yaml.safe_dump(definition, sort_keys=False))
                role_markers[role] = marker
        subprocess.run(['git', 'init', '-q'], cwd=root, check=True, capture_output=True)
        subprocess.run(['git', 'add', '.'], cwd=root, check=True, capture_output=True)
        subprocess.run(['git', '-c', 'user.name=Team Trials', '-c', 'user.email=trials@example.invalid', 'commit', '-qm', 'Fixture baseline'], cwd=root, check=True, capture_output=True)
        baseline = smoke.snapshot(root)
        fixture_digest = hashlib.sha256(json.dumps(baseline, sort_keys=True).encode()).hexdigest()
        prompt = trial_prompt(case, mode, root)
        try:
            result = smoke.run_appserver(cli, root, prompt, timeout)
            code, stdout, stderr = result.returncode, result.stdout, result.stderr
        except (subprocess.TimeoutExpired, RuntimeError) as exc:
            code, stdout, stderr = 124, getattr(exc, 'output', '') or '', (getattr(exc, 'stderr', '') or '') + str(exc)
        events = []
        for line in stdout.splitlines():
            try:
                events.append(json.loads(line))
            except ValueError:
                pass
        after = smoke.snapshot(root)
        changes = sorted(p for p in set(baseline) | set(after) if baseline.get(p) != after.get(p))
        permitted = [case['file']] if case['file'] else []
        collaboration = smoke.collaboration_items(events)
        spawns = [e for e in collaboration if e.get('tool') in ('spawn_agent', 'spawnAgent') and e.get('status') in ('completed', 'success')]
        attempts = spawn_attempts(events)
        final = '\n'.join(e.get('item', e.get('params', {}).get('item', {})).get('text', '') for e in events if (e.get('type') == 'item.completed' or e.get('method') == 'item/completed') and e.get('item', e.get('params', {}).get('item', {})).get('type') in ('agent_message', 'agentMessage'))
        artifacts.mkdir(parents=True, exist_ok=True)
        (artifacts / f'{case_name}-{mode}.jsonl').write_text(stdout)
        (artifacts / f'{case_name}-{mode}.stderr.log').write_text(stderr)
        (artifacts / f'{case_name}-{mode}.answer.txt').write_text(final)
        if case['file']:
            # Restore the immutable evaluator tests; agent changes cannot weaken the gate.
            (root / 'test_behavior.py').write_text(case['tests'])
            try:
                gate = smoke.run_bounded([sys.executable, '-B', '-m', 'unittest', 'test_behavior.py'], 20, cwd=root)
                behavior = 'PASS' if gate.returncode == 0 else 'FAIL'
            except subprocess.TimeoutExpired:
                behavior = 'BLOCKED: evaluator exceeded 20s'
        else:
            behavior = 'NEEDS HUMAN RUBRIC REVIEW'
        expected_markers = {role: role_markers[role] for role in case['roles']} if mode == 'team' else {}
        markers = list(expected_markers.values())
        review_markers = tuple(markers[:2]) if len(markers) >= 2 else None
        proof = smoke.verify_events(events, markers, role_markers=expected_markers, review_markers=review_markers)
        if mode != 'team':
            proof['turn_completed'] = parent_turn_completed(events)
        orchestration = team_proof_passes(proof, len(case['roles'])) if mode == 'team' else direct_proof_passes(proof, attempts)
        # These small, fully specified fixtures have no concrete delegation need.
        # Expected worker roles remain exclusive to the forced-team evaluator.
        routing = routing_passes(proof, case['roles']) if mode == 'team' else not attempts
        unnecessary_delegation = mode != 'team' and bool(attempts)
        invalid_override = bool(proof.get('explicit_model_overrides') or proof.get('explicit_reasoning_overrides'))
        domain_observations = apple_domain_observations(events)
        domain_reads = domain_observations['commands']
        domain_check = 'NOT APPLICABLE'
        if case.get('forbidden_domain_reads') and domain_reads:
            routing = False
            domain_check = 'FAIL'
        elif case.get('forbidden_domain_reads'):
            domain_check = 'NOT VERIFIED' if domain_observations['unverified_mentions'] else 'PASS'
        return {'case': case_name, 'mode': mode, 'fixture_digest': fixture_digest, 'source_digest_before_copy': source_digest_before_copy, 'exit_code': code,
                'elapsed_seconds': round(time.monotonic() - started, 2), 'ownership': 'PASS' if not set(changes) - set(permitted) else 'FAIL',
                'behavior': behavior, 'orchestration': 'FAIL' if unnecessary_delegation or invalid_override else ('PASS' if orchestration and code == 0 else 'NOT VERIFIED'),
                'routing': 'FAIL' if unnecessary_delegation else ('PASS' if routing and code == 0 else 'NOT VERIFIED'),
                'expected_roles': case['roles'] if mode == 'team' else [], 'observed_roles': proof.get('roles_observed', []),
                'apple_domain_commands': domain_reads, 'apple_domain_unverified_mentions': domain_observations['unverified_mentions'],
                'apple_domain_read_check': domain_check, 'completed_worker_ids': proof.get('completed_worker_ids', []), 'spawn_count': len({e.get('id') for e in spawns}),
                'spawn_attempt_count': len(attempts), 'parent_turn_completed': proof.get('turn_completed', False),
                'independent_review_sequence': proof.get('independent_review_sequence', False),
                'explicit_model_overrides': proof.get('explicit_model_overrides', []), 'explicit_reasoning_overrides': proof.get('explicit_reasoning_overrides', []),
                'changed_files': changes, 'user_clarifications': 0, 'repeated_explanations': 0,
                'usage': [e.get('params', {}).get('tokenUsage') for e in events if e.get('method') == 'thread/tokenUsage/updated'][-1:],
                'cost': 'NOT EXPOSED', 'answer_artifact': f'{case_name}-{mode}.answer.txt'}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--live', action='store_true')
    parser.add_argument('--root', type=Path, default=REPO_ROOT)
    parser.add_argument('--timeout', type=int, default=300)
    parser.add_argument('--artifacts-dir', type=Path, default=REPO_ROOT / 'agent-framework/runs/team-comparison')
    parser.add_argument('--case', choices=(*CASES, 'all'), default='all')
    parser.add_argument('--mode', choices=('adaptive', 'comparison'), default='adaptive',
                        help='On-demand policy by default; comparison explicitly forces paired solo/team benchmarks')
    args = parser.parse_args()
    if not args.live:
        print(json.dumps({'status': 'NOT RUN', 'mode': args.mode, 'cases': list(CASES), 'reason': 'Opt in with --live for actual model calls'}))
        return 0
    cli = shutil.which('codex')
    if not cli:
        print(json.dumps({'status': 'BLOCKED', 'reason': 'codex CLI missing'}))
        return 2
    cli = str(Path(cli).resolve())
    version = subprocess.run([cli, '--version'], capture_output=True, text=True).stdout.strip()
    source_digest_at_start = smoke.source_digest(args.root)
    results = []
    for case in CASES if args.case == 'all' else (args.case,):
        for mode in (('adaptive',) if args.mode == 'adaptive' else ('solo', 'team')):
            result = trial(args.root, case, mode, cli, args.timeout, args.artifacts_dir)
            results.append(result)
            print(json.dumps(result), flush=True)
    failed = any(r['exit_code'] != 0 or r['ownership'] != 'PASS' or r['orchestration'] == 'FAIL' or r.get('routing') == 'FAIL' or r['behavior'] == 'FAIL' for r in results)
    unresolved = any(r['orchestration'] != 'PASS' or r.get('routing') != 'PASS' or r.get('apple_domain_read_check') == 'NOT VERIFIED' or r['behavior'] not in ('PASS',) for r in results)
    report = {'status': 'FAIL' if failed else ('NEEDS REVIEW' if unresolved else 'PASS'), 'mode': args.mode, 'cli_version': version, 'transport': 'app-server raw events', 'source_revision': subprocess.run(['git', '-C', str(args.root), 'rev-parse', 'HEAD'], capture_output=True, text=True).stdout.strip(), 'source_content_digest_at_start': source_digest_at_start, 'source_content_digest_at_end': smoke.source_digest(args.root), 'results': results,
              'limitations': ['Small Python fixtures are not native Apple feature/cancellation/UI validation.', 'Adaptive fixtures are deliberately bounded and need no workers; they do not measure justified delegation on complex work.', 'Expected team role IDs are external evaluator criteria; user prompts do not prescribe role selection. Only forced-team trials mark all catalog roles.', 'One run per case; no statistical claim about team quality.', 'User counts are zero because scenarios are fully specified and noninteractive.', 'Advice acceptance needs rubric review of actual answer artifacts.', 'CLI turn usage may not expose total child usage or effective model.']}
    (args.artifacts_dir / 'report.json').write_text(json.dumps(report, indent=2))
    return 1 if failed else (2 if unresolved else 0)


if __name__ == '__main__':
    raise SystemExit(main())

#!/usr/bin/env python3
"""Opt-in solo/team trials on identical isolated fixtures; never a native Apple UI proof."""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
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
            for role in case['roles']:
                path = root / f'agent-framework/canonical/roles/{role}.yaml'
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
        prompt = case['request'] + ' This is a fully specified isolated trial. Use no external actions or model overrides. PYTHONDONTWRITEBYTECODE=1 for all Python commands. No saved coordination documents. '
        if mode == 'solo':
            prompt += 'For this comparison act as the single specialist directly. Do not spawn subagents. Complete and verify only this outcome. '
        else:
            prompt += 'Pass the absolute fixture path ' + str(root) + ' and relevant approved requirements into every worker contract. This fixture has no native Apple target; code checks are Python only. Act as the coordinator and use real subagents with inherited models. Do not implement code yourself. Use these roles in sequence: ' + ', '.join(case['roles']) + '. '
            prompt += 'Before issuing each contract read the canonical role and relevant skills. Use native role selection if exposed; otherwise generic spawn task_name=<role_with_hyphens_replaced_by_underscores> with role instructions and required relevant skills explicitly in the message. Contracts specify mode (advise for UX, execute otherwise), approved outcome, context, ownership, prohibited files, output, criteria, validation commands, current revision, dependencies, retry_limit=2, may_delegate=false and stop after this outcome. Reviewers/QA must independently inspect and verify the final revision. QA may run tests but owns no source files here. Use fork_turns=none with minimal explicit task context and wait for completed results. '
        if case['file']:
            prompt += 'Run python3 -B -m unittest test_behavior.py before claiming completion. Review and QA receive only the task, diff and actual test output, not author conclusions as facts. '
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
        markers = list(role_markers.values())
        review_markers = tuple(markers[:2]) if len(markers) >= 2 else None
        proof = smoke.verify_events(events, markers, role_markers=role_markers, review_markers=review_markers)
        orchestration = team_proof_passes(proof, len(case['roles'])) if mode == 'team' else not spawns
        return {'case': case_name, 'mode': mode, 'fixture_digest': fixture_digest, 'source_digest_before_copy': source_digest_before_copy, 'exit_code': code,
                'elapsed_seconds': round(time.monotonic() - started, 2), 'ownership': 'PASS' if not set(changes) - set(permitted) else 'FAIL',
                'behavior': behavior, 'orchestration': 'PASS' if orchestration and code == 0 else 'NOT VERIFIED', 'expected_roles': case['roles'] if mode == 'team' else [], 'completed_worker_ids': proof.get('completed_worker_ids', []), 'spawn_count': len({e.get('id') for e in spawns}),
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
    args = parser.parse_args()
    if not args.live:
        print(json.dumps({'status': 'NOT RUN', 'cases': list(CASES), 'reason': 'Opt in with --live for actual model calls'}))
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
        for mode in ('solo', 'team'):
            result = trial(args.root, case, mode, cli, args.timeout, args.artifacts_dir)
            results.append(result)
            print(json.dumps(result), flush=True)
    failed = any(r['exit_code'] != 0 or r['ownership'] != 'PASS' or r['orchestration'] == 'FAIL' or r['behavior'] == 'FAIL' for r in results)
    unresolved = any(r['orchestration'] != 'PASS' or r['behavior'] not in ('PASS',) for r in results)
    report = {'status': 'FAIL' if failed else ('NEEDS REVIEW' if unresolved else 'PASS'), 'cli_version': version, 'transport': 'app-server raw events', 'source_revision': subprocess.run(['git', '-C', str(args.root), 'rev-parse', 'HEAD'], capture_output=True, text=True).stdout.strip(), 'source_content_digest_at_start': source_digest_at_start, 'source_content_digest_at_end': smoke.source_digest(args.root), 'results': results,
              'limitations': ['Small Python fixtures are not native Apple feature/cancellation/UI validation.', 'Minimal code route uses engineer+reviewer; bounded UX advice uses one designer. Earlier additional-review pilots exceeded 300s; preserve those failures.', 'One run per case; no statistical claim about team quality.', 'User counts are zero because scenarios are fully specified and noninteractive.', 'UX acceptance needs rubric review of actual answer artifacts.', 'CLI turn usage may not expose total child usage or effective model.']}
    (args.artifacts_dir / 'report.json').write_text(json.dumps(report, indent=2))
    return 1 if failed else (2 if unresolved else 0)


if __name__ == '__main__':
    raise SystemExit(main())

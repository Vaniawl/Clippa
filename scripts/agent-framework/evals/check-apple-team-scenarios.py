#!/usr/bin/env python3
"""Validate Apple role eval coverage; optionally summarize independently graded observations.

Without --observations this proves fixture integrity only, never live-model behavior.
Observation JSON is a list of case_id, provider, version, selection (native-named or
role-contract-adapter), transcript (path relative to the observations file), and checks
(one {status: PASS|FAIL|NOT RUN, evidence: <location/result>} per scenario criterion).
Grades are reported evidence, not independently reproduced by this structural checker.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import sys

import yaml

ROOT = Path(__file__).resolve().parents[3]


def load_suite(root: Path) -> list[dict]:
    suite = yaml.safe_load((root / 'agent-framework/evals/apple-team-scenarios.yaml').read_text())
    roles = {p.stem for p in (root / 'agent-framework/canonical/roles').glob('*.yaml')}
    cases = suite.get('scenarios') if isinstance(suite, dict) else None
    if not isinstance(cases, list) or not cases:
        raise ValueError('scenario suite must be a non-empty list')
    ids: set[str] = set()
    covered: set[str] = set()
    for case in cases:
        if not isinstance(case, dict) or not isinstance(case.get('id'), str) or not case['id'].strip():
            raise ValueError('each scenario needs an id')
        if case['id'] in ids:
            raise ValueError(f'duplicate scenario: {case["id"]}')
        ids.add(case['id'])
        if case.get('role') not in roles:
            raise ValueError(f'{case["id"]}: unknown role')
        covered.add(case['role'])
        if not isinstance(case.get('prompt'), str) or not case['prompt'].strip():
            raise ValueError(f'{case["id"]}: missing actual request')
        criteria = case.get('criteria')
        if not isinstance(criteria, list) or not criteria or any(
                not isinstance(c, str) or not c.strip() for c in criteria):
            raise ValueError(f'{case["id"]}: missing grading criteria')
        if case.get('initial_live_status') != 'NOT RUN':
            raise ValueError(f'{case["id"]}: fixtures cannot predeclare live success')
    if covered != roles:
        raise ValueError(f'roles missing scenarios: {sorted(roles - covered)}')
    return cases


def observation_statuses(cases: list[dict], path: Path | None) -> dict[str, str]:
    if path is None:
        return {}
    observations = json.loads(path.read_text())
    if not isinstance(observations, list):
        raise ValueError('observations must be a list')
    by_id = {c['id']: c for c in cases}
    statuses: dict[str, str] = {}
    for observation in observations:
        if not isinstance(observation, dict):
            raise ValueError('observation must be an object')
        cid = observation.get('case_id')
        if not isinstance(cid, str) or cid not in by_id or cid in statuses:
            raise ValueError('unknown or duplicate observed scenario')
        for key in ('provider', 'version', 'transcript'):
            if not isinstance(observation.get(key), str) or not observation[key].strip():
                raise ValueError(f'{cid}: missing {key}')
        if observation.get('selection') not in {'native-named', 'role-contract-adapter'}:
            raise ValueError(f'{cid}: selection must describe actual execution')
        transcript = path.parent / observation['transcript']
        if not transcript.is_file() or not transcript.stat().st_size:
            raise ValueError(f'{cid}: missing or empty transcript')
        checks = observation.get('checks')
        if not isinstance(checks, list) or len(checks) != len(by_id[cid]['criteria']):
            raise ValueError(f'{cid}: grade every criterion')
        grades = []
        for check in checks:
            if not isinstance(check, dict) or check.get('status') not in {'PASS', 'FAIL', 'NOT RUN'}:
                raise ValueError(f'{cid}: invalid grade')
            if not isinstance(check.get('evidence'), str) or not check['evidence'].strip():
                raise ValueError(f'{cid}: grade needs evidence or reason')
            grades.append(check['status'])
        status = 'FAIL' if 'FAIL' in grades else 'NOT RUN' if 'NOT RUN' in grades else 'REPORTED PASS'
        statuses[cid] = status
    return statuses


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=ROOT)
    parser.add_argument('--observations', type=Path)
    args = parser.parse_args()
    try:
        cases = load_suite(args.root)
        statuses = observation_statuses(cases, args.observations)
    except (OSError, ValueError, yaml.YAMLError) as exc:
        print(f'Apple scenario validation FAIL: {exc}', file=sys.stderr)
        return 1
    print(f'Fixture integrity PASS: {len(cases)} scenarios; every canonical role covered.')
    print('Fixture integrity is not live-role execution. Observation grades are REPORTED, NOT INDEPENDENTLY VERIFIED by this checker.')
    for case in cases:
        print(f'{case["id"]} {case["role"]}: {statuses.get(case["id"], "NOT RUN")}')
    return int(any(status == 'FAIL' for status in statuses.values()))


if __name__ == '__main__':
    raise SystemExit(main())

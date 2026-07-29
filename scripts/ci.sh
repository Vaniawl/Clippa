#!/usr/bin/env bash
set -euo pipefail
bash ./scripts/validate-repository.sh
if [[ -d agent-framework ]]; then
  # Framework gates (post v1.1.0 review remediation): shell syntax, Python compile,
  # deterministic regression tests, and the eval suite. The eval report goes to a
  # temp path so the tracked results file is never dirtied by CI (KF-M22).
  bash -n scripts/agent-framework/provider-*.sh
  python3 -m compileall -q scripts/agent-framework
  python3 -m unittest discover -s tests/agent-framework -t .
  python3 scripts/agent-framework/evals/run-evals.py --report "$(mktemp)"
  if [[ -n "${CI:-}" ]]; then
    git diff --quiet || { echo 'CI: framework checks modified tracked files'; git diff --stat; exit 1; }
  fi
fi
bash ./scripts/build.sh
bash ./scripts/test.sh
echo 'CI wrapper completed.'

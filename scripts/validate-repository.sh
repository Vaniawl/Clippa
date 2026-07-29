#!/usr/bin/env bash
set -euo pipefail
R=(README.md PROJECT.md AGENTS.md CLAUDE.md SECURITY.md docs/product/product-vision.md docs/architecture/overview.md docs/security/threat-model.md docs/testing/test-strategy.md .claude/settings.json)
F=0
for p in "${R[@]}"; do
  [[ -e "$p" ]] || { echo "Missing: $p"; F=1; }
done
if grep -RIl --exclude-dir=.git --exclude=initialize-project.sh --exclude=validate-repository.sh '__PROJECT_' . >/dev/null 2>&1; then
  if [[ -f .project-initialized ]]; then
    echo 'Unresolved placeholders:'
    grep -RIl --exclude-dir=.git --exclude=initialize-project.sh --exclude=validate-repository.sh '__PROJECT_' .
    F=1
  else
    echo 'Template not yet initialized (placeholders present; run scripts/initialize-project.sh) — skipping placeholder check.'
  fi
fi
if [[ -d agent-framework ]]; then
  python3 scripts/agent-framework/validate.py || F=1
  python3 scripts/agent-framework/check-drift.py || F=1
fi
bash ./scripts/check-localizations.sh || F=1
[[ "$F" -eq 0 ]] || exit 1
echo 'Repository structure validation passed.'

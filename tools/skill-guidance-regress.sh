#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Script: skill-guidance-regress.sh
# PURPOSE: ADR-004 v0 guidance-regression runner. Asserts static obligations
#          from test/fixtures/skill-guidance/*/case-*/expected.json against
#          the referenced skill.md text (no live model output).
# USAGE:   tools/skill-guidance-regress.sh [--fixture-root DIR]
# EXIT:    0 all cases pass
#          1 one or more cases fail
# -----------------------------------------------------------------------------
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git -C "$SCRIPT_DIR/.." rev-parse --show-toplevel 2>/dev/null || true)"
[[ -n "$REPO_ROOT" ]] || REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

FIXTURE_ROOT="${1:-$REPO_ROOT/test/fixtures/skill-guidance}"
if [[ "${1:-}" == "--fixture-root" ]]; then
  FIXTURE_ROOT="${2:?--fixture-root requires a path}"
fi

if [[ ! -d "$FIXTURE_ROOT" ]]; then
  echo "ERROR: fixture root not found: $FIXTURE_ROOT" >&2
  exit 1
fi

FAIL=0
PASS=0

run_case() {
  local expected="$1"
  local case_dir
  case_dir="$(dirname "$expected")"
  node - "$REPO_ROOT" "$expected" "$case_dir" <<'NODE'
const fs = require('fs');
const path = require('path');
const [repo, expectedPath, caseDir] = process.argv.slice(2);
const exp = JSON.parse(fs.readFileSync(expectedPath, 'utf8'));
if (!exp.skill_path) {
  console.error('FAIL ' + caseDir + ': expected.json missing skill_path');
  process.exit(2);
}
const skillPath = path.join(repo, exp.skill_path);
if (!fs.existsSync(skillPath)) {
  console.error('FAIL ' + caseDir + ': skill not found: ' + exp.skill_path);
  process.exit(2);
}
const text = fs.readFileSync(skillPath, 'utf8');
const failures = [];
for (const pat of exp.must_match || []) {
  if (!new RegExp(pat, 'm').test(text)) {
    failures.push('must_match missing /' + pat + '/');
  }
}
for (const pat of exp.must_not_match || []) {
  if (new RegExp(pat, 'm').test(text)) {
    failures.push('must_not_match hit /' + pat + '/');
  }
}
for (const phrase of exp.required_phrases || []) {
  if (!text.includes(phrase)) {
    failures.push('required_phrases missing "' + phrase + '"');
  }
}
if (failures.length) {
  console.error('FAIL ' + caseDir + ' (' + exp.skill_path + '):');
  for (const f of failures) console.error('  - ' + f);
  process.exit(1);
}
console.log('PASS ' + caseDir + ' -> ' + exp.skill_path);
NODE
}

shopt -s nullglob
cases=("$FIXTURE_ROOT"/*/case-*/expected.json)
if [[ ${#cases[@]} -eq 0 ]]; then
  echo "ERROR: no fixtures under $FIXTURE_ROOT" >&2
  exit 1
fi

for expected in "${cases[@]}"; do
  if run_case "$expected"; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
  fi
done

echo "skill-guidance-regress: ${PASS} passed, ${FAIL} failed"
exit $(( FAIL > 0 ? 1 : 0 ))

# shellcheck shell=bash
# doctor-modules/guardrails-checks.sh — sourced by doctor-checks.sh
# All global state (CRITICAL, ERRORS, WARNINGS, FIXED, SKILL_*, FIX_MODE, etc.)
# is inherited from the parent script.

_doctor_guardrails_checks() {
# --- Check 29: Augment-surface SHA256 drift against guardrails baseline ---
# Compares current SHA256 of Augment-touching files against the baseline
# captured in tests/fixtures/augment-baseline-pre-claude-guardrails.json.
# Unexpected drift means a tracked file was modified without re-capturing
# the baseline — which may mean the Augment surface has silently regressed.

local GUARDRAILS_BASELINE="$REPO_ROOT/tests/fixtures/augment-baseline-pre-claude-guardrails.json"

if [[ ! -f "$GUARDRAILS_BASELINE" ]]; then
  echo "🟡 WARNING: guardrails-baseline — no baseline found at tests/fixtures/augment-baseline-pre-claude-guardrails.json"
  echo "   Run: bash scripts/capture-augment-baseline.sh"
  WARNINGS=$((WARNINGS + 1))
else
  local _rel_path _baseline_sha _abs_path _current_sha
  # Emit key|expected-hash pairs in one Python call to avoid N per-file spawns.
  # Baseline keys are controlled by capture-augment-baseline.sh (ASCII paths only).
  while IFS='|' read -r _rel_path _baseline_sha; do
    [[ -z "$_rel_path" ]] && continue
    _abs_path="$REPO_ROOT/$_rel_path"
    if [[ ! -f "$_abs_path" ]]; then
      echo "🔴 CRITICAL: guardrails-baseline — tracked file missing: $_rel_path"
      CRITICAL=$((CRITICAL + 1))
      continue
    fi
    _current_sha="$(sha256_hash "$_abs_path")"
    if [[ "$_current_sha" != "$_baseline_sha" ]]; then
      echo "🟠 ERROR: guardrails-baseline — Augment-touching file drifted: $_rel_path"
      echo "   baseline: $_baseline_sha"
      echo "   current:  $_current_sha"
      echo "   If this change is intentional: bash scripts/capture-augment-baseline.sh"
      ERRORS=$((ERRORS + 1))
    fi
  done < <(python3 -c "
import json
with open('$GUARDRAILS_BASELINE') as f:
    d = json.load(f)
for k, v in d.get('file_hashes', {}).items():
    print(k + '|' + v)
" 2>/dev/null)
fi


# --- Check 30 (advisory): bare source .env calls in installed skills ---
# Bare 'source ~/.codex/.env' in skill code blocks fails silently when .env
# contains enc:v1: encrypted values — the ciphertext lands as the API token
# and every curl call returns 401. Advisory only; plaintext-env users unaffected.
local _bare_env_hits=()
while IFS= read -r _hit; do
  _bare_env_hits+=("$_hit")
done < <(
  grep -rn 'source ~/.codex/.env' "$INSTALLED_DIR" \
    --include="*.md" --include="*.sh" 2>/dev/null |
  grep -v '/_archive/' |
  grep -Ev ':[0-9]+:[[:space:]]' |
  grep -Ev ':[0-9]+:#'
)
if [[ ${#_bare_env_hits[@]} -gt 0 ]]; then
  echo "🟡 ADVISORY (Check 30): ${#_bare_env_hits[@]} bare 'source ~/.codex/.env' call(s) in installed skills"
  echo "   enc:v1: encrypted .env values arrive as ciphertext -> API calls return 401"
  local _shown=0
  for _hit in "${_bare_env_hits[@]}"; do
    (( _shown++ )) || true
    [[ $_shown -gt 5 ]] && break
    echo "   $_hit"
  done
  [[ ${#_bare_env_hits[@]} -gt 5 ]] && echo "   ... and $((${#_bare_env_hits[@]} - 5)) more"
  echo "   Fix: run sp-update to pull the latest cb-env-aware skill versions"
  echo "   (Advisory only — does not affect users with plaintext ~/.codex/.env)"
  WARNINGS=$((WARNINGS + 1))
fi

}

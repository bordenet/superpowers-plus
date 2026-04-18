# shellcheck shell=bash
# doctor-modules/integration-checks.sh — sourced by doctor-checks.sh
# All global state (CRITICAL, ERRORS, WARNINGS, FIXED, SKILL_*, FIX_MODE, etc.)
# is inherited from the parent script.

_doctor_integration_checks() {
# --- Check 26: Stale Workflow State ---
# IMPORTANT: This must run BEFORE check 23 (reviewer-dispatch) because check 23
# loads the adapter which triggers readState() auto-expiry on stale states.
# Detects abandoned workflow states older than 24 hours.
# Auto-fix: archives stale state to ~/.codex/.workflow-state-archive/
_doctor_workflow_state() {
  local state_file="$HOME/.codex/.workflow-state.json"
  [[ -f "$state_file" ]] || return 0

  if ! command -v node &>/dev/null; then
    echo "🟡 WARNING: workflow-state — node not available, cannot check state age"
    WARNINGS=$((WARNINGS + 1))
    return 0
  fi

  # Compute age and staleness in a single node call.
  # Returns "age_hours:is_stale:workflow" or "corrupt" on any parse/math failure.
  # NaN, Infinity, and negative ages are all treated as corrupt.
  local state_info
  state_info=$(node -e "
    try {
      const s = JSON.parse(require('fs').readFileSync('$state_file', 'utf8'));
      const age = (Date.now() - new Date(s.created_at).getTime()) / 3600000;
      if (!Number.isFinite(age) || age < 0) { console.log('corrupt'); process.exit(0); }
      const rounded = Math.round(age * 10) / 10;
      console.log(rounded + ':' + (age > 24 ? 1 : 0) + ':' + (s.workflow || 'unknown'));
    } catch(_) { console.log('corrupt'); }
  " 2>/dev/null)

  if [[ -z "$state_info" || "$state_info" == "corrupt" ]]; then
    echo "🟡 WARNING: workflow-state — corrupt or unparseable state file at $state_file"
    WARNINGS=$((WARNINGS + 1))
    if can_fix moderate; then
      local archive_dir="$HOME/.codex/.workflow-state-archive"
      mkdir -p "$archive_dir"
      local ts
      ts=$(date +%Y-%m-%dT%H-%M-%S)
      if mv "$state_file" "$archive_dir/workflow-corrupt-${ts}.json" 2>/dev/null; then
        echo "  ✅ FIXED: archived corrupt state file"
        FIXED=$((FIXED + 1))
      else
        echo "  ⚠️  Could not archive corrupt state file"
      fi
    fi
    return 0
  fi

  # Parse the colon-delimited result
  local age_hours is_stale workflow
  age_hours="${state_info%%:*}"
  is_stale="${state_info#*:}"; is_stale="${is_stale%%:*}"
  workflow="${state_info##*:}"

  if [[ "$is_stale" == "1" ]]; then
    echo "🟡 WARNING: workflow-state — stale '${workflow}' workflow (${age_hours}h old, limit: 24h)"
    WARNINGS=$((WARNINGS + 1))
    if can_fix moderate; then
      if node -e "require('$REPO_ROOT/lib/workflow-state').archiveState(
        JSON.parse(require('fs').readFileSync('$state_file','utf8'))
      )" 2>/dev/null; then
        echo "  ✅ FIXED: archived stale workflow state"
        FIXED=$((FIXED + 1))
      else
        echo "  ⚠️  Could not archive stale workflow state"
      fi
    fi
  fi
}
_doctor_workflow_state

# --- Check 23: Reviewer-Dispatch Rendering Verification ---
# Verifies that installed skill rendering correctly translates code-reviewer
# dispatch patterns to the expected sub-agent-code-reviewer output.
# Detects stale renderings that would cause incorrect reviewer dispatch.
ADAPTER="$REPO_ROOT/superpowers-augment.js"
if [[ -f "$ADAPTER" ]] && command -v node &>/dev/null; then
  _doctor_reviewer_dispatch() {
    local output stale_patterns stale_found=0
    # Render the requesting-code-review skill through the adapter
    output=$(node "$ADAPTER" use-skill requesting-code-review 2>/dev/null || true)
    if [[ -z "$output" ]]; then
      echo "🟡 WARNING: reviewer-dispatch — could not render requesting-code-review skill"
      ((WARNINGS++))
      return
    fi
    # Check for expected output
    if [[ "$output" != *"sub-agent-code-reviewer"* ]]; then
      echo "🟡 WARNING: reviewer-dispatch — output missing 'sub-agent-code-reviewer'"
      ((WARNINGS++))
    fi
    # Detect stale/untranslated patterns
    stale_patterns=(
      "code-reviewer subagent"
      "code reviewer subagent"
      "Dispatch final code-reviewer"
      "Task tool with superpowers:code-reviewer type"
    )
    for pattern in "${stale_patterns[@]}"; do
      if [[ "$output" == *"$pattern"* ]]; then
        echo "🟡 WARNING: reviewer-dispatch — stale pattern found: '$pattern'"
        ((stale_found++))
      fi
    done
    if [[ "$stale_found" -gt 0 ]]; then
      ((WARNINGS += stale_found))
    fi
    # Also check subagent-driven-development skill
    local sdd_output sdd_lower
    sdd_output=$(node "$ADAPTER" use-skill subagent-driven-development 2>/dev/null || true)
    if [[ -n "$sdd_output" ]]; then
      sdd_lower=$(echo "$sdd_output" | tr '[:upper:]' '[:lower:]')
      # Detect any variant of "dispatch final code[-]reviewer" that wasn't translated
      if echo "$sdd_lower" | grep -q "dispatch final code.reviewer" && \
         ! echo "$sdd_lower" | grep -q "dispatch final sub-agent-code-reviewer"; then
        echo "🟡 WARNING: reviewer-dispatch — stale final-reviewer pattern in subagent-driven-development"
        ((WARNINGS++))
      fi
    fi
  }
  _doctor_reviewer_dispatch
fi

}

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
# dispatch patterns to the expected sub-agent-code-reviewer output for the
# Augment target. Detects stale renderings that would cause incorrect
# reviewer dispatch.
#
# Also verifies (adapter-independent, no node required) the source and deployed
# Claude reviewer contracts. The compatibility code-quality contract resolves
# and inlines reviewer instructions before dispatch. Active SDD task review uses
# task-reviewer-prompt.md, whose prompt is already inline.
_doctor_has_general_purpose_dispatch() {
  local prompt_file="$1"
  local prompt_kind="$2"
  awk -v prompt_kind="$prompt_kind" '
    function has_dispatch_negation(text, negated_use, negated_action, block_first, subject_first) {
      negated_use = (text ~ /(do not|never|must not|should not|may not|cannot|not to)[^.]*use[^.]*(dispatch block|subagent block|generic subagent block|block below|following block|this block|that block)/)
      negated_action = (text ~ /(do not|never|must not|should not|may not|cannot|not to)[^.]*(dispatch|execute|executed|invoke|invoked|run|send)[^.]*(dispatch block|subagent block|generic subagent block|block below|following block|this block|that block|subagent|reviewer)/)
      block_first = (text ~ /(dispatch block|subagent block|generic subagent block|block below|following block|this block|that block)[^.]*(do not|never|must not|should not|may not|cannot|not to|not intended|not authorized|not meant)[^.]*(dispatch|execute|executed|invoke|invoked|run|use|used|send)/)
      subject_first = (text ~ /(subagent|reviewer)[^.]*(do not|never|must not|should not|may not|cannot|not to|not intended|not authorized|not meant)[^.]*(dispatch|execute|executed|invoke|invoked|run|send)/)
      return negated_use || negated_action || block_first || subject_first
    }
    function finish_contract_region() {
      if (block_complete && !pre_marker_negated && \
          marker_count == 1 && generic_headers == 1) {
        coherent_regions++
      }
      in_contract_region = 0
    }
    {
      if (!marker_seen) {
        pre_marker_text = pre_marker_text " " tolower($0)
      }
    }
    /^#{1,6} / {
      if (in_contract_region) {
        finish_contract_region()
      }
      if ($0 == "## Controller contract") {
        contract_regions++
        in_contract_region = 1
        marker_count = generic_headers = block_complete = 0
        in_block = description = model = prompt = body = 0
      }
      next
    }
    !in_contract_region { next }
    $0 == "Controller contract: dispatch the following block." {
      if (!marker_seen && has_dispatch_negation(pre_marker_text)) {
        pre_marker_negated = 1
      }
      marker_seen = 1
      marker_count++
      affirmative_contract = 1
      next
    }
    $0 == "Subagent (general-purpose):" {
      generic_headers++
      if (!affirmative_contract) {
        next
      }
      affirmative_contract = 0
      in_block = 1
      description = model = prompt = body = 0
      next
    }
    { affirmative_contract = 0 }
    in_block && /^```/ {
      in_block = 0
      next
    }
    in_block && /^[^ ]/ {
      in_block = 0
      next
    }
    in_block && !description && /^  description: / {
      description = 1
      next
    }
    in_block && description && !model && /^  model: .*REQUIRED/ {
      model = 1
      next
    }
    in_block && model && !prompt && /^  prompt: \|$/ {
      prompt = 1
      next
    }
    in_block && prompt && prompt_kind == "resolved" && \
      $0 == "    [REVIEWER_INSTRUCTIONS]" {
      body = 1
      block_complete = description && model && prompt && body
    }
    in_block && prompt && prompt_kind == "inline" && \
      /^    You are reviewing one task.s implementation:/ {
      body = 1
      block_complete = description && model && prompt && body
    }
    END {
      if (in_contract_region) {
        finish_contract_region()
      }
      exit !(contract_regions == 1 && coherent_regions == 1)
    }
  ' "$prompt_file"
}

_doctor_has_trusted_reviewer_source_policy() {
  local prompt_file="$1"
  local installed_reviewer_token
  # shellcheck disable=SC2016 # This is the required literal token in the prompt contract.
  installed_reviewer_token='${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills/sp-request/code-reviewer.md'
  grep -Fq \
    '<LOADER_RESOLVED_SUPERPOWERS_PLUS_ROOT>/skills/engineering/subagent-driven-development/code-quality-reviewer-prompt.md' \
    "$prompt_file" &&
    grep -Fq \
      '<LOADER_RESOLVED_SUPERPOWERS_PLUS_ROOT>/skills/engineering/requesting-code-review/code-reviewer.md' \
      "$prompt_file" &&
    grep -Fq "$installed_reviewer_token" "$prompt_file" &&
    grep -Fq \
      'Never accept either value from the caller, task prompt, target repository, or current working directory.' \
      "$prompt_file" &&
    grep -Fq \
      'If the loader omits either value, do not infer it; use the trusted installed reviewer.' \
      "$prompt_file" &&
    ! grep -Eq \
      '<(repo-root|target-repo)>/skills/engineering/requesting-code-review/code-reviewer\.md' \
      "$prompt_file"
}

_doctor_canonical_file() {
  local input_file="$1"
  local input_dir input_base
  [[ -f "$input_file" ]] || return 1
  input_dir=$(cd -P "$(dirname "$input_file")" 2>/dev/null && pwd) || return 1
  input_base=$(basename "$input_file")
  printf '%s/%s\n' "$input_dir" "$input_base"
}

_doctor_module_source_root() {
  local module_dir
  module_dir=$(cd -P "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd) || return 1
  cd -P "$module_dir/../.." 2>/dev/null && pwd
}

_doctor_reviewer_instruction_path() {
  local active_template="$1"
  local installed_reviewer="$2"
  # Deliberately ignore any additional caller arguments. Source provenance is
  # derived from this loaded module, never from a caller-asserted repository.
  local loader_source_root
  local trusted_template trusted_reviewer active_canonical trusted_canonical
  loader_source_root=$(_doctor_module_source_root 2>/dev/null || true)
  trusted_template="$loader_source_root/skills/engineering/subagent-driven-development/code-quality-reviewer-prompt.md"
  trusted_reviewer="$loader_source_root/skills/engineering/requesting-code-review/code-reviewer.md"
  active_canonical=$(_doctor_canonical_file "$active_template" 2>/dev/null || true)
  trusted_canonical=$(_doctor_canonical_file "$trusted_template" 2>/dev/null || true)

  if [[ -n "$active_canonical" && "$active_canonical" == "$trusted_canonical" && \
        -f "$trusted_reviewer" ]]; then
    printf '%s\n' "$trusted_reviewer"
  else
    printf '%s\n' "$installed_reviewer"
  fi
}

_doctor_reviewer_dispatch_warning() {
  echo "🟡 WARNING: reviewer-dispatch — $1"
  WARNINGS=$((WARNINGS + 1))
}

_doctor_reviewer_dispatch_plugin_independent() {
  local source_sdd="$REPO_ROOT/skills/engineering/subagent-driven-development"
  local source_contract="$source_sdd/code-quality-reviewer-prompt.md"
  local source_skill="$source_sdd/skill.md"
  local source_task_reviewer="$source_sdd/task-reviewer-prompt.md"
  local source_reviewer="$REPO_ROOT/skills/engineering/requesting-code-review/code-reviewer.md"
  local claude_root="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
  local deployed_sdd="$claude_root/skills/subagent-driven-development"
  local deployed_contract="$deployed_sdd/code-quality-reviewer-prompt.md"
  local deployed_skill="$deployed_sdd/skill.md"
  local deployed_task_reviewer="$deployed_sdd/task-reviewer-prompt.md"
  local deployed_reviewer="$claude_root/skills/sp-request/code-reviewer.md"
  local source_instruction deployed_instruction

  if [[ ! -f "$source_contract" ]]; then
    _doctor_reviewer_dispatch_warning "source reviewer contract is missing: $source_contract"
  else
    if grep -q "superpowers:code-reviewer" "$source_contract"; then
      _doctor_reviewer_dispatch_warning "source reviewer contract still depends on the plugin agent type 'superpowers:code-reviewer'"
    fi
    if grep -Fq "Read requesting-code-review/code-reviewer.md" "$source_contract"; then
      _doctor_reviewer_dispatch_warning "source reviewer contract hands the child an unresolved reviewer-template path"
    fi
    if ! _doctor_has_trusted_reviewer_source_policy "$source_contract"; then
      _doctor_reviewer_dispatch_warning "source reviewer-instruction source policy is unsafe or incomplete"
    fi
    if ! _doctor_has_general_purpose_dispatch "$source_contract" resolved; then
      _doctor_reviewer_dispatch_warning "source reviewer contract is not a coherent general-purpose dispatch"
    fi
  fi

  if [[ ! -f "$deployed_contract" ]]; then
    _doctor_reviewer_dispatch_warning "deployed Claude reviewer contract is missing: $deployed_contract"
  else
    if [[ -f "$source_contract" ]] && ! cmp -s "$source_contract" "$deployed_contract"; then
      _doctor_reviewer_dispatch_warning "deployed Claude reviewer contract is stale: $deployed_contract"
    fi
    if grep -q "superpowers:code-reviewer" "$deployed_contract"; then
      _doctor_reviewer_dispatch_warning "deployed Claude reviewer contract still depends on the plugin agent type 'superpowers:code-reviewer'"
    fi
    if grep -Fq "Read requesting-code-review/code-reviewer.md" "$deployed_contract"; then
      _doctor_reviewer_dispatch_warning "deployed Claude reviewer contract hands the child an unresolved reviewer-template path"
    fi
    if ! _doctor_has_trusted_reviewer_source_policy "$deployed_contract"; then
      _doctor_reviewer_dispatch_warning "deployed Claude reviewer-instruction source policy is unsafe or incomplete"
    fi
    if ! _doctor_has_general_purpose_dispatch "$deployed_contract" resolved; then
      _doctor_reviewer_dispatch_warning "deployed Claude reviewer contract is not a coherent general-purpose dispatch"
    fi
  fi

  if [[ ! -f "$source_task_reviewer" ]]; then
    _doctor_reviewer_dispatch_warning "source active task-reviewer contract is missing: $source_task_reviewer"
  elif ! _doctor_has_general_purpose_dispatch "$source_task_reviewer" inline; then
    _doctor_reviewer_dispatch_warning "source active task-reviewer contract is not a coherent general-purpose dispatch"
  fi

  if [[ ! -f "$source_reviewer" ]]; then
    _doctor_reviewer_dispatch_warning "source reviewer instructions are missing: $source_reviewer"
  elif [[ "$(head -n 1 "$source_reviewer")" != "# Code Review Agent" ]]; then
    _doctor_reviewer_dispatch_warning "source reviewer instructions have an invalid heading: $source_reviewer"
  fi

  source_instruction=$(_doctor_reviewer_instruction_path \
    "$source_contract" "$deployed_reviewer")
  if [[ ! -f "$source_instruction" ]]; then
    _doctor_reviewer_dispatch_warning "reviewer instructions selected for the source template are missing: $source_instruction"
  elif [[ "$(head -n 1 "$source_instruction")" != "# Code Review Agent" ]]; then
    _doctor_reviewer_dispatch_warning "reviewer instructions selected for the source template have an invalid heading: $source_instruction"
  fi

  deployed_instruction=$(_doctor_reviewer_instruction_path \
    "$deployed_contract" "$deployed_reviewer")
  if [[ ! -f "$deployed_instruction" ]]; then
    _doctor_reviewer_dispatch_warning "deployed Claude reviewer instructions are missing: $deployed_instruction"
  else
    if [[ "$(head -n 1 "$deployed_instruction")" != "# Code Review Agent" ]]; then
      _doctor_reviewer_dispatch_warning "deployed Claude reviewer instructions have an invalid heading: $deployed_instruction"
    fi
    if [[ -f "$source_reviewer" ]] && ! cmp -s "$source_reviewer" "$deployed_instruction"; then
      _doctor_reviewer_dispatch_warning "deployed Claude reviewer instructions are stale: $deployed_instruction"
    fi
  fi

  if [[ ! -f "$deployed_skill" ]]; then
    _doctor_reviewer_dispatch_warning "deployed Claude SDD workflow is missing: $deployed_skill"
  elif ! grep -Eq "^6\\. .*dispatch task reviewer using \`task-reviewer-prompt\\.md\`" "$deployed_skill"; then
    _doctor_reviewer_dispatch_warning "deployed Claude SDD workflow does not route task review through task-reviewer-prompt.md"
  elif [[ -f "$source_skill" ]] && ! cmp -s "$source_skill" "$deployed_skill"; then
    _doctor_reviewer_dispatch_warning "deployed Claude SDD workflow is stale: $deployed_skill"
  fi

  if [[ ! -f "$deployed_task_reviewer" ]]; then
    _doctor_reviewer_dispatch_warning "deployed Claude active task-reviewer contract is missing: $deployed_task_reviewer"
  else
    if [[ -f "$source_task_reviewer" ]] && ! cmp -s "$source_task_reviewer" "$deployed_task_reviewer"; then
      _doctor_reviewer_dispatch_warning "deployed Claude active task-reviewer contract is stale: $deployed_task_reviewer"
    fi
    if ! _doctor_has_general_purpose_dispatch "$deployed_task_reviewer" inline; then
      _doctor_reviewer_dispatch_warning "deployed Claude active task-reviewer contract is not a coherent general-purpose dispatch"
    fi
  fi
}
_doctor_reviewer_dispatch_plugin_independent

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
      "superpowers:code-reviewer"
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
    local sdd_output sdd_lower sdd_prompt_output
    sdd_output=$(SPP_SOURCE_DIR="$REPO_ROOT" node "$ADAPTER" \
      use-skill spp:subagent-driven-development 2>/dev/null || true)
    if [[ -n "$sdd_output" ]]; then
      sdd_lower=$(echo "$sdd_output" | tr '[:upper:]' '[:lower:]')
      # Detect any variant of "dispatch final code[-]reviewer" that wasn't translated
      if echo "$sdd_lower" | grep -q "dispatch final code.reviewer" && \
         ! echo "$sdd_lower" | grep -q "dispatch final sub-agent-code-reviewer"; then
        echo "🟡 WARNING: reviewer-dispatch — stale final-reviewer pattern in subagent-driven-development"
        ((WARNINGS++))
      fi
      if [[ "$sdd_output" != *"use-skill spp:subagent-driven-development --resource <prompt-file>"* ]]; then
        echo "🟡 WARNING: reviewer-dispatch — SDD workflow does not route Augment sibling prompts through the adapter"
        ((WARNINGS++))
      fi
    fi

    sdd_prompt_output=$(SPP_SOURCE_DIR="$REPO_ROOT" node "$ADAPTER" \
      use-skill spp:subagent-driven-development \
      --resource task-reviewer-prompt.md 2>/dev/null || true)
    if [[ -z "$sdd_prompt_output" ]]; then
      echo "🟡 WARNING: reviewer-dispatch — could not render the SDD task-reviewer prompt for Augment"
      ((WARNINGS++))
    else
      if [[ "$sdd_prompt_output" != *"Controller contract: dispatch the following block."* ]] || \
         [[ "$sdd_prompt_output" != *"You are reviewing one task's implementation"* ]] || \
         [[ "$sdd_prompt_output" != *"sub-agent-general-purpose tool:"* ]]; then
        echo "🟡 WARNING: reviewer-dispatch — rendered Augment task-reviewer prompt is incomplete"
        ((WARNINGS++))
      fi
      if [[ "$sdd_prompt_output" == *"Subagent (general-purpose):"* ]]; then
        echo "🟡 WARNING: reviewer-dispatch — rendered Augment task-reviewer prompt retains the Claude dispatch header"
        ((WARNINGS++))
      fi
    fi
  }
  _doctor_reviewer_dispatch
fi

}

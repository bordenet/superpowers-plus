# shellcheck shell=bash
# doctor-modules/agent-checks.sh — sourced by doctor-checks.sh
# All global state (CRITICAL, ERRORS, WARNINGS, FIXED, FIX_MODE, etc.)
# is inherited from the parent script.

_doctor_agent_checks() {
# --- Check 27: Agent Content Drift ---
# Detects when ~/.augment/agents/ has drifted from the source in any overlay repo.
# Overlay source dirs register themselves via VARNAME_SOURCE_DIR in ~/.codex/.env.
# Auto-fix: overwrites installed agent with the source copy (safe operation).

local augment_agents_dir="${HOME}/.augment/agents"
[[ -d "$augment_agents_dir" ]] || return 0

declare -A _agent_source=()  # agent filename → canonical source path (overlay wins)

# Collect agent sources from all registered SOURCE_DIRS
for dir in "${SOURCE_DIRS[@]}"; do
  local agents_dir="${dir}/agents"
  [[ -d "$agents_dir" ]] || continue
  for agent_file in "${agents_dir}"/*.md; do
    [[ -f "$agent_file" ]] || continue
    local agent_name
    agent_name=$(basename "$agent_file")
    _agent_source["$agent_name"]="$agent_file"  # last writer wins (overlay order)
  done
done

if [[ ${#_agent_source[@]} -eq 0 ]]; then
  return 0  # No overlay repos define agents — nothing to check
fi

local drift_count=0
for agent_name in "${!_agent_source[@]}"; do
  local src="${_agent_source[$agent_name]}"
  local installed="${augment_agents_dir}/${agent_name}"

  [[ -f "$installed" ]] || continue  # Not installed yet — install.sh handles this

  if ! diff -q "$src" "$installed" > /dev/null 2>&1; then
    local src_model installed_model
    src_model=$(grep -m1 '^model:' "$src" 2>/dev/null | sed 's/model:[[:space:]]*//' || echo "(none)")
    installed_model=$(grep -m1 '^model:' "$installed" 2>/dev/null | sed 's/model:[[:space:]]*//' || echo "(none)")
    local model_note=""
    if [[ "$src_model" != "$installed_model" ]]; then
      model_note=" (model: source=${src_model}, installed=${installed_model})"
    fi
    echo "🟠 ERROR: ${agent_name} — content drift from source${model_note}"
    echo "  Source:    ${src}"
    echo "  Installed: ${installed}"
    ((ERRORS++))
    ((drift_count++))
    if can_fix safe; then
      cp "$src" "$installed" || { echo "  ⚠️  Fix failed: could not overwrite installed agent"; continue; }
      echo "  ✅ FIXED: synced ${agent_name}"
      ((FIXED++))
    fi
  fi
done

}

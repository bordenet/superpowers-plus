# shellcheck shell=bash
# doctor-modules/agent-checks.sh — sourced by doctor-checks.sh
# All global state (CRITICAL, ERRORS, WARNINGS, FIXED, FIX_MODE, BACKUP_DIR, etc.)
# is inherited from the parent script.

_doctor_agent_checks() {
# --- Check 27: Agent Content Drift ---
# Detects when ~/.augment/agents/ has drifted from the source in any overlay repo.
# Overlay source dirs register themselves via VARNAME_SOURCE_DIR in ~/.codex/.env.
# Auto-fix (safe): backs up installed file then overwrites with the source copy.
# Security: symlinked installed paths are never overwritten (symlink attack prevention).

local augment_agents_dir="${HOME}/.augment/agents"
[[ -d "$augment_agents_dir" ]] || return 0

declare -A _agent_source=()  # basename → canonical source path (last overlay wins)
declare -A _agent_first=()   # basename → first-seen source path (conflict detection)

# Collect agent sources from all registered SOURCE_DIRS; detect duplicates across overlays
for dir in "${SOURCE_DIRS[@]}"; do
  local agents_dir="${dir}/agents"
  [[ -d "$agents_dir" ]] || continue
  for agent_file in "${agents_dir}"/*.md; do
    [[ -f "$agent_file" ]] || continue  # handles empty-glob literal
    local agent_name
    agent_name=$(basename "$agent_file")
    if [[ -n "${_agent_source[$agent_name]:-}" && \
          "${_agent_source[$agent_name]}" != "$agent_file" ]]; then
      echo "🟠 ERROR: ${agent_name} — ambiguous source (defined in multiple overlays)"
      echo "  First:  ${_agent_first[$agent_name]}"
      echo "  Second: ${agent_file}"
      echo "  Resolution: remove the duplicate from one overlay repo."
      ((ERRORS++))
    fi
    _agent_first["$agent_name"]="${_agent_first[$agent_name]:-$agent_file}"
    _agent_source["$agent_name"]="$agent_file"
  done
done

[[ ${#_agent_source[@]} -eq 0 ]] && return 0  # No overlay defines agents — nothing to check

for agent_name in "${!_agent_source[@]}"; do
  local src="${_agent_source[$agent_name]}"
  local installed="${augment_agents_dir}/${agent_name}"

  # Missing install: report as warning (absence is not drift; deployment is a separate concern)
  if [[ ! -f "$installed" && ! -L "$installed" ]]; then
    echo "🟡 WARNING: ${agent_name} — source agent not installed at ${installed}"
    ((WARNINGS++))
    continue
  fi

  # Symlink guard: never diff or overwrite a symlink (prevents symlink-target clobber)
  if [[ -L "$installed" ]]; then
    echo "🟡 WARNING: ${agent_name} — installed path is a symlink; skipping drift check"
    ((WARNINGS++))
    continue
  fi

  if ! diff -q "$src" "$installed" > /dev/null 2>&1; then
    # Normalize model value: strip surrounding quotes and trailing whitespace
    local src_model installed_model model_note=""
    src_model=$(grep -m1 '^model:' "$src" 2>/dev/null \
      | sed "s/model:[[:space:]]*//;s/['\"]//g;s/[[:space:]]*$//" || echo "(none)")
    installed_model=$(grep -m1 '^model:' "$installed" 2>/dev/null \
      | sed "s/model:[[:space:]]*//;s/['\"]//g;s/[[:space:]]*$//" || echo "(none)")
    [[ "$src_model" != "$installed_model" ]] && \
      model_note=" (model: source=${src_model}, installed=${installed_model})"
    echo "🟠 ERROR: ${agent_name} — content drift from source${model_note}"
    echo "  Source:    ${src}"
    echo "  Installed: ${installed}"
    ((ERRORS++))
    if can_fix safe; then
      # Back up installed file before overwriting (matches doctor's fix contract)
      local agent_backup_dir="${BACKUP_DIR}/agents"
      mkdir -p "$agent_backup_dir"
      if ! cp "$installed" "${agent_backup_dir}/${agent_name}" 2>/dev/null; then
        echo "  ⚠️  Backup failed: skipping fix for ${agent_name}"
        continue
      fi
      if cp "$src" "$installed"; then
        echo "  ✅ FIXED: synced ${agent_name}"
        ((FIXED++))
      else
        echo "  ⚠️  Fix failed: could not overwrite installed agent"
      fi
    fi
  fi
done

}

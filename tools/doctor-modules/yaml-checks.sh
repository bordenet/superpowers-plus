# shellcheck shell=bash
# doctor-modules/yaml-checks.sh — sourced by doctor-checks.sh
# All global state (CRITICAL, ERRORS, WARNINGS, FIXED, SKILL_*, FIX_MODE, etc.)
# is inherited from the parent script.

_doctor_yaml_checks() {
# --- Check 1: Malformed YAML Frontmatter ---
for skill in "${!SKILL_PATH[@]}"; do
  if [[ "${SKILL_FIRST_LINE[$skill]}" != "---" ]]; then
    echo "🔴 CRITICAL: $skill — missing opening --- delimiter"; ((CRITICAL++)); continue
  fi
  if [[ "${SKILL_DELIM_COUNT[$skill]}" -lt 2 ]]; then
    echo "🔴 CRITICAL: $skill — missing closing --- delimiter"; ((CRITICAL++)); continue
  fi
  echo "${SKILL_YAML[$skill]}" | grep -q "^name:" || { echo "🔴 CRITICAL: $skill — missing name: field"; ((CRITICAL++)); }
done

# --- Check 2: Empty/Stub Skills ---
for skill in "${!SKILL_LINES[@]}"; do
  [[ "${SKILL_LINES[$skill]}" -lt 10 ]] && { echo "🔴 CRITICAL: $skill — ${SKILL_LINES[$skill]} lines (stub)"; ((CRITICAL++)); }
done

# --- Check 3: Name Mismatch ---
for skill in "${!SKILL_YAML_NAME[@]}"; do
  yaml_name="${SKILL_YAML_NAME[$skill]}"
  if [[ -n "$yaml_name" && "$yaml_name" != "$skill" ]]; then
    # Exempt intentional trigger-alias installs: if "/$skill" appears in the skill's
    # triggers list, the skill was installed under its slash-command alias directory
    # (e.g. name: debate lives in sp-debate/ because /sp-debate is its trigger).
    # The name/directory mismatch is deliberate — suppress the CRITICAL in this case.
    _triggers="${SKILL_TRIGGERS_RAW[$skill]:-}"
    # Fallback: multi-line inline arrays (e.g. "triggers: [\"/sp-plan\",\n  ...]") are not
    # fully captured by SKILL_TRIGGERS_RAW; scan SKILL_YAML when SKILL_TRIGGERS_RAW is empty.
    [[ -z "$_triggers" ]] && _triggers="${SKILL_YAML[$skill]:-}"
    if [[ -n "$_triggers" ]] && echo "$_triggers" | grep -qE "^[[:space:]]*-[[:space:]]+[\"']*/${skill}[\"']*[[:space:]]*$|[\"']/${skill}[\"']"; then
      : # Intentional alias install — name: differs from directory by design
    else
      echo "🔴 CRITICAL: $skill — name: '$yaml_name' ≠ directory '$skill'"; ((CRITICAL++))
      if can_fix safe; then
        if backup_skill "$(dirname "${SKILL_PATH[$skill]}")"; then
          sed_inplace "s/^name:.*$/name: $skill/" "${SKILL_PATH[$skill]}"
          echo "  ✅ FIXED: name → '$skill'"; ((FIXED++))
        fi
      fi
    fi
  fi
done

# --- Check 4: Duplicate Skill Names ---
# Skills with "overrides:" in YAML frontmatter are intentional overlays, not duplicates.
declare -A seen_skills
for dir in "${SOURCE_DIRS[@]}"; do
  search_root="$dir"; [[ -d "$dir/skills" ]] && search_root="$dir/skills"
  while IFS= read -r skill_dir; do
    name=$(basename "$skill_dir"); source_name=$(basename "$dir")
    if [[ -n "${seen_skills[$name]:-}" && "${seen_skills[$name]}" != *"$source_name"* ]]; then
      # Check if the overlay version declares "overrides:" — intentional override
      skill_file="$skill_dir/skill.md"
      yaml_block=$(awk 'NR==1 && /^---$/{found++; next} /^---$/{exit} found{print}' "$skill_file")
      if echo "$yaml_block" | grep -q "^overrides:"; then
        : # Intentional overlay — skip duplicate warning
      else
        echo "🔴 CRITICAL: $name — exists in: ${seen_skills[$name]} AND $source_name"; ((CRITICAL++))
      fi
    fi
    seen_skills[$name]="${seen_skills[$name]:-}${seen_skills[$name]:+, }$source_name"
  done < <(find "$search_root" -name "skill.md" -not -path "*/references/*" -exec dirname {} \; 2>/dev/null)
done

# --- Check 7: Missing Description ---
for skill in "${!SKILL_YAML[@]}"; do
  [[ -z "${SKILL_YAML_VALID[$skill]:-}" ]] && continue
  echo "${SKILL_YAML[$skill]}" | grep -q "^description:" || { echo "🟠 ERROR: $skill — no description:"; ((ERRORS++)); }
done

# --- Check 15: Structure Quality ---
# Single awk pass replaces 3 separate grep -Eqi file reads per skill (528 forks → 176 forks).
for skill in "${!SKILL_PATH[@]}"; do
  f="${SKILL_PATH[$skill]}"; issues=""
  read -r _has_wtu _has_code _has_fail < <(awk '
    BEGIN { w=0; c=0; f=0 }
    tolower($0) ~ /when to use|when to invoke/ { w=1 }
    /```/ { c=1 }
    tolower($0) ~ /failure|fix:|recovery|troubleshoot/ { f=1 }
    END { print w, c, f }
  ' "$f")
  [[ "${_has_wtu:-0}" == "0" ]] && issues="${issues}missing 'When to Use'; "
  [[ "${_has_code:-0}" == "0" ]] && issues="${issues}no code examples; "
  [[ "${_has_fail:-0}" == "0" ]] && issues="${issues}no failure modes; "
  [[ -n "$issues" ]] && echo "🔵 INFO: $skill — $issues"
done

}

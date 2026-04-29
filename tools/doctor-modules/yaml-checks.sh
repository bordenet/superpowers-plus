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
    # Alias install: skill installs under its /sp* trigger name (e.g. sp-review from providing-code-review).
    # Only suppress when the YAML name matches the canonical source name for this alias —
    # a corrupted name (e.g. name: garbage in sp-brainstorm/skill.md) must still be caught.
    if [[ "${DEST_NAME_SOURCE[$skill]:-}" == "$yaml_name" ]]; then
      continue
    fi
    echo "🔴 CRITICAL: $skill — name: '$yaml_name' ≠ directory '$skill'"; ((CRITICAL++))
    if can_fix safe; then
      if backup_skill "$(dirname "${SKILL_PATH[$skill]}")"; then
        sed_inplace "s/^name:.*$/name: $skill/" "${SKILL_PATH[$skill]}"
        echo "  ✅ FIXED: name → '$skill'"; ((FIXED++))
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
for skill in "${!SKILL_PATH[@]}"; do
  f="${SKILL_PATH[$skill]}"; issues=""
  grep -Eqi 'when to use|when to invoke' "$f" || issues="${issues}missing 'When to Use'; "
  grep -q '```' "$f" || issues="${issues}no code examples; "
  grep -Eqi 'failure|fix:|recovery|troubleshoot' "$f" || issues="${issues}no failure modes; "
  [[ -n "$issues" ]] && echo "🔵 INFO: $skill — $issues"
done

}

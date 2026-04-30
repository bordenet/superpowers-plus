# shellcheck shell=bash
# doctor-modules/trigger-checks.sh — sourced by doctor-checks.sh
# All global state (CRITICAL, ERRORS, WARNINGS, FIXED, SKILL_*, FIX_MODE, etc.)
# is inherited from the parent script.

_doctor_trigger_checks() {
# --- Check 10: Missing Triggers ---
VALIDATOR="$SP_PLUS_DIR/tools/skill-trigger-validator.sh"
EXPLICIT_LIST=""
# Parse EXPLICIT_SKILLS array from validator using awk (portable, no line-count limit)
# Match only the closing ')' on its own line (not ')' inside comments like "(upgrades packages)")
[[ -f "$VALIDATOR" ]] && EXPLICIT_LIST=$(awk '/^EXPLICIT_SKILLS=/{found=1; next} found && /^[[:space:]]*\)/{exit} found{gsub(/#.*/, ""); gsub(/[[:space:]"]+/, ""); if ($0 != "") print}' "$VALIDATOR" 2>/dev/null || echo "")
# Load overlay-specific explicit skill lists (one skill name per line, # for comments).
# Private overlays use this to suppress warnings for intentionally dormant skills
# without leaking internal skill names into this public repo.
for _overlay_dir in "${SOURCE_DIRS[@]}"; do
  [[ "$_overlay_dir" == "$SP_PLUS_DIR" ]] && continue
  _es_file="${_overlay_dir}/tools/doctor-explicit-skills.txt"
  if [[ -f "$_es_file" ]]; then
    while IFS= read -r _es_skill; do
      [[ -z "$_es_skill" || "$_es_skill" =~ ^# ]] && continue
      EXPLICIT_LIST="${EXPLICIT_LIST}"$'\n'"${_es_skill}"
    done < "$_es_file"
  fi
done
for skill in "${!SKILL_PATH[@]}"; do
  if [[ -z "${SKILL_HAS_TRIGGERS[$skill]:-}" ]] && ! echo "$EXPLICIT_LIST" | grep -q "^${skill}$"; then
    echo "🟡 WARNING: $skill — no triggers and not in EXPLICIT_SKILLS"; ((WARNINGS++))
  fi
done

# --- Check 11: Trigger Overlap ---
# Known collision groups: skills that intentionally share triggers.
# Collisions within a group are expected and suppressed.
#
# NOTE FOR OVERLAY/PRIVATE REPO OPERATORS:
# This list covers only PUBLIC superpowers-plus skills. If your private
# overlay installs additional skills (e.g., org-specific guardrails,
# API wrappers) that share triggers with public skills, you will see
# trigger-sharing warnings from this doctor. Those are NOT public repo
# bugs — add the overlay collision groups to your private repo's config.
KNOWN_COLLISION_GROUPS=(
  # Hub→child: thinking-orchestrator delegates to specialized skills
  "thinking-orchestrator adversarial-search think-twice completeness-check verification-before-completion exhaustive-audit-validation providing-code-review progressive-harsh-review"
  # Detect→Fix: complementary slop detection and elimination
  "detecting-ai-slop eliminating-ai-slop"
  # Pre-commit chain: unified-commit-gate is the hub; the 5 gate skills are its delegates.
  # Hub and all siblings share commit/push triggers — suppress all pairwise collisions within this group.
  "unified-commit-gate pre-commit-gate enforce-style-guide progressive-code-review-gate professional-language-audit public-repo-ip-audit"
  # Resume screening: generic vs source-specific
  "resume-screening cv-review-external"
  # Security: vulnerability scanning vs repo secret scanning
  "security-upgrade repo-security-scan"
  # Skill creation: authoring workflow vs writing conventions
  "skill-authoring writing-skills"
  # Completion-gate chain: intentional multi-skill coverage for completion/merge phrases.
  # "implementation complete" fires both implementation-tracker (archive prompt) and
  # finishing-a-development-branch (branch wrap-up). "ready to merge" fires both
  # verification-before-completion (safety gate) and finishing-a-development-branch
  # (branch options). coordination.requires is metadata only — not enforced at runtime.
  "finishing-a-development-branch verification-before-completion implementation-tracker"
)

# Load overlay collision groups from all overlay source dirs
for _overlay_dir in "${SOURCE_DIRS[@]}"; do
  [[ "$_overlay_dir" == "$SP_PLUS_DIR" ]] && continue  # base, not overlay
  _cg_file="${_overlay_dir}/tools/doctor-known-collision-groups.txt"
  if [[ -f "$_cg_file" ]]; then
    while IFS= read -r group; do
      [[ -z "$group" || "$group" =~ ^# ]] && continue
      KNOWN_COLLISION_GROUPS+=("$group")
    done < "$_cg_file"
  fi
done

# Build a lookup: for each skill, which group index it belongs to
declare -A skill_group
for i in "${!KNOWN_COLLISION_GROUPS[@]}"; do
  for s in ${KNOWN_COLLISION_GROUPS[$i]}; do
    skill_group[$s]="${skill_group[$s]:-}${skill_group[$s]:+ }$i"
  done
done

# Check if two skills share a collision group
in_same_group() {
  local a="$1" b="$2"
  for ga in ${skill_group[$a]:-}; do
    for gb in ${skill_group[$b]:-}; do
      [[ "$ga" == "$gb" ]] && return 0
    done
  done
  return 1
}

declare -A trigger_map
for skill in "${!SKILL_TRIGGERS_RAW[@]}"; do
  triggers_raw="${SKILL_TRIGGERS_RAW[$skill]}"
  [[ -z "$triggers_raw" ]] && continue
  # Handle both inline arrays and multi-line items
  if echo "$triggers_raw" | grep -q '^[[:space:]]*-'; then
    # Multi-line format: each line is "  - "value""
    triggers=$(echo "$triggers_raw" | sed 's/^[[:space:]]*-[[:space:]]*//' | sed 's/^"//;s/"$//' | sed "s/^'//;s/'$//" | grep -v '^$' || true)
  else
    # Inline format: triggers: ["foo", "bar"]
    triggers=$(echo "$triggers_raw" | sed 's/triggers://' | tr -d '[]' | tr ',' '\n' | sed 's/^[[:space:]]*"//;s/"[[:space:]]*$//' | grep -v '^$' || true)
  fi
  while IFS= read -r trigger; do
    [[ -z "$trigger" ]] && continue
    lt=$(echo "$trigger" | tr '[:upper:]' '[:lower:]')
    if [[ -n "${trigger_map[$lt]:-}" ]]; then
      existing="${trigger_map[$lt]}"
      # Skip if skill is already in the map for this trigger (self-collision)
      if echo ", $existing," | grep -q ", ${skill},"; then
        continue
      fi
      # Check if all colliding skills are in the same known group
      all_known=true
      while IFS= read -r prev_skill; do
        [[ -z "$prev_skill" ]] && continue
        if ! in_same_group "$prev_skill" "$skill"; then
          all_known=false; break
        fi
      done <<< "$(echo "$existing" | tr ',' '\n' | sed 's/^[[:space:]]*//')"
      if [[ "$all_known" == "false" ]]; then
        echo "🟡 WARNING: trigger '$trigger' shared by: $existing AND $skill"; ((WARNINGS++))
      fi
    fi
    trigger_map["$lt"]="${trigger_map[$lt]:-}${trigger_map[$lt]:+, }$skill"
  done <<< "$triggers"
done

# --- Check 12: Deprecated But Active ---
# Only flag skills where deprecation is structural (frontmatter or prominent body marker),
# not incidental mentions of the word "deprecated" in unrelated content.
for skill in "${!SKILL_PATH[@]}"; do
  f="${SKILL_PATH[$skill]}"
  yaml_block="${SKILL_YAML[$skill]}"
  # Check frontmatter for deprecated: true
  is_deprecated=false
  echo "$yaml_block" | grep -qi "^deprecated:" && is_deprecated=true
  # Check first 10 lines after frontmatter for prominent deprecation markers
  if [[ "$is_deprecated" == "false" ]]; then
    body_start="${SKILL_BODY_START[$skill]:-}"
    [[ -n "$body_start" ]] && head -n $((body_start + 10)) "$f" | tail -n 10 | grep -qiE '^[[:space:]]*>.*deprecated|^#.*deprecated|replaced by|superseded by' && is_deprecated=true
  fi
  if [[ "$is_deprecated" == "true" ]]; then
    has_triggers="${SKILL_HAS_TRIGGERS[$skill]:-}"
    if [[ -n "$has_triggers" ]]; then
      echo "🟡 WARNING: $skill — deprecated but has triggers"; ((WARNINGS++))
      if can_fix moderate; then
        backup_skill "$(dirname "$f")" || continue
        sed_inplace 's/^triggers:.*/triggers: []/' "$f"
        echo "  ✅ FIXED: cleared triggers on deprecated $skill"; ((FIXED++))
      fi
    fi
  fi
done

}

#!/usr/bin/env bash
# doctor-checks.sh — Run all 16 superpowers-doctor diagnostic checks
#
# Usage:
#   ./doctor-checks.sh              # Run all checks
#   ./doctor-checks.sh --fix        # Run checks + auto-fix safe issues
#   ./doctor-checks.sh --fix --yes  # Auto-fix without confirmation

# shellcheck disable=SC2044  # find loops are safe here — skill paths never contain spaces
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tools/compat.sh
source "${SCRIPT_DIR}/compat.sh"
require_bash4

INSTALLED_DIR="$HOME/.codex/skills"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

FIX_MODE=false
for arg in "$@"; do
  case "$arg" in --fix) FIX_MODE=true ;; esac
done

SP_PLUS_DIR="${SPP_SOURCE_DIR:-$REPO_ROOT}"
SP_OVERLAY_DIR="${SPC_SOURCE_DIR:-}"
SOURCE_DIRS=("$SP_PLUS_DIR")
[[ -n "$SP_OVERLAY_DIR" && -d "$SP_OVERLAY_DIR" ]] && SOURCE_DIRS+=("$SP_OVERLAY_DIR")

BACKUP_DIR="$HOME/.codex/doctor-backups/$(date +%Y-%m-%d_%H-%M-%S)"
FIXED=0; CRITICAL=0; ERRORS=0; WARNINGS=0

backup_skill() {
  local target="$1"
  mkdir -p "$BACKUP_DIR/$(basename "$target")"
  cp -r "$target"/* "$BACKUP_DIR/$(basename "$target")/" 2>/dev/null || true
}

TOTAL_SKILLS=$(find "$INSTALLED_DIR" -maxdepth 2 -name "skill.md" -not -path "*/references/*" 2>/dev/null | wc -l | tr -d ' ')
echo "🩺 Superpowers Doctor — $TOTAL_SKILLS skills scanned"
echo ""

# --- Check 1: Malformed YAML Frontmatter ---
for f in $(find "$INSTALLED_DIR" -maxdepth 2 -name "skill.md" -not -path "*/references/*" 2>/dev/null); do
  skill=$(basename "$(dirname "$f")")
  first_line=$(head -1 "$f")
  if [[ "$first_line" != "---" ]]; then
    echo "🔴 CRITICAL: $skill — missing opening --- delimiter"; ((CRITICAL++)); continue
  fi
  delimiter_count=$(head -30 "$f" | grep -c "^---$" || true)
  if [[ "$delimiter_count" -lt 2 ]]; then
    echo "🔴 CRITICAL: $skill — missing closing --- delimiter"; ((CRITICAL++)); continue
  fi
  yaml_block=$(awk 'NR==1 && /^---$/{found++; next} /^---$/{exit} found{print}' "$f")
  echo "$yaml_block" | grep -q "^name:" || { echo "🔴 CRITICAL: $skill — missing name: field"; ((CRITICAL++)); }
done

# --- Check 2: Empty/Stub Skills ---
for f in $(find "$INSTALLED_DIR" -maxdepth 2 -name "skill.md" -not -path "*/references/*" 2>/dev/null); do
  lines=$(wc -l < "$f" | tr -d ' ')
  skill=$(basename "$(dirname "$f")")
  [[ "$lines" -lt 10 ]] && { echo "🔴 CRITICAL: $skill — $lines lines (stub)"; ((CRITICAL++)); }
done

# --- Check 3: Name Mismatch ---
for f in $(find "$INSTALLED_DIR" -maxdepth 2 -name "skill.md" -not -path "*/references/*" 2>/dev/null); do
  dir_name=$(basename "$(dirname "$f")")
  yaml_name=$(awk 'NR==1 && /^---$/{found++; next} /^---$/{exit} found{print}' "$f" | grep "^name:" | sed 's/name:[[:space:]]*//' | tr -d '"'"'" || true)
  if [[ -n "$yaml_name" && "$yaml_name" != "$dir_name" ]]; then
    echo "🔴 CRITICAL: $dir_name — name: '$yaml_name' ≠ directory '$dir_name'"; ((CRITICAL++))
    if [[ "$FIX_MODE" == "true" ]]; then
      backup_skill "$(dirname "$f")"
      sed_inplace "s/^name:.*$/name: $dir_name/" "$f"
      echo "  ✅ FIXED: name → '$dir_name'"; ((FIXED++))
    fi
  fi
done

# --- Check 4: Duplicate Skill Names ---
declare -A seen_skills
for dir in "${SOURCE_DIRS[@]}"; do
  search_root="$dir"; [[ -d "$dir/skills" ]] && search_root="$dir/skills"
  for skill_dir in $(find "$search_root" -name "skill.md" -not -path "*/references/*" -exec dirname {} \; 2>/dev/null); do
    name=$(basename "$skill_dir"); source_name=$(basename "$dir")
    if [[ -n "${seen_skills[$name]:-}" && "${seen_skills[$name]}" != *"$source_name"* ]]; then
      echo "🔴 CRITICAL: $name — exists in: ${seen_skills[$name]} AND $source_name"; ((CRITICAL++))
    fi
    seen_skills[$name]="${seen_skills[$name]:-}${seen_skills[$name]:+, }$source_name"
  done
done

# --- Check 5: Broken Internal References ---
for f in $(find "$INSTALLED_DIR" -maxdepth 2 -name "skill.md" -not -path "*/references/*" 2>/dev/null); do
  skill=$(basename "$(dirname "$f")"); skill_dir=$(dirname "$f")
  grep -oE '(references/[a-zA-Z0-9_-]+\.md|modules/[a-zA-Z0-9_-]+\.md|examples\.md|reference\.md)' "$f" 2>/dev/null | while read -r ref; do
    [[ ! -f "$skill_dir/$ref" ]] && echo "🔴 CRITICAL: $skill — references '$ref' but file missing"
  done
done

# --- Check 6: Oversized Skills ---
for f in $(find "$INSTALLED_DIR" -maxdepth 2 -name "skill.md" -not -path "*/references/*" 2>/dev/null); do
  lines=$(wc -l < "$f" | tr -d ' '); skill=$(basename "$(dirname "$f")")
  [[ "$lines" -gt 250 ]] && { echo "🟠 ERROR: $skill — $lines lines (limit: 250)"; ((ERRORS++)); }
done

# --- Check 7: Missing Description ---
for f in $(find "$INSTALLED_DIR" -maxdepth 2 -name "skill.md" -not -path "*/references/*" 2>/dev/null); do
  skill=$(basename "$(dirname "$f")")
  yaml_block=$(awk 'NR==1 && /^---$/{found++; next} /^---$/{exit} found{print}' "$f")
  echo "$yaml_block" | grep -q "^description:" || { echo "🟠 ERROR: $skill — no description:"; ((ERRORS++)); }
done

# --- Check 8: Orphaned Installs ---
for installed in $(find "$INSTALLED_DIR" -maxdepth 1 -mindepth 1 -type d 2>/dev/null); do
  skill=$(basename "$installed")
  [[ "$skill" == "_shared" || "$skill" == "doctor-backups" ]] && continue
  found=false
  for dir in "${SOURCE_DIRS[@]}"; do
    search_root="$dir"; [[ -d "$dir/skills" ]] && search_root="$dir/skills"
    find "$search_root" -type d -name "$skill" 2>/dev/null | grep -q . && { found=true; break; }
  done
  if [[ "$found" == "false" ]]; then
    echo "🟠 ERROR: $skill — orphaned install"; ((ERRORS++))
    if [[ "$FIX_MODE" == "true" ]]; then
      backup_skill "$installed"; rm -rf "$installed"
      echo "  ✅ FIXED: removed orphan $skill"; ((FIXED++))
    fi
  fi
done

# --- Check 9: Source-Install Content Drift ---
declare -A PRIORITY_SOURCE
for dir in "$SP_PLUS_DIR" ${SP_OVERLAY_DIR:+"$SP_OVERLAY_DIR"}; do
  search_root="$dir"; [[ -d "$dir/skills" ]] && search_root="$dir/skills"
  while IFS= read -r src; do
    skill=$(basename "$(dirname "$src")")
    PRIORITY_SOURCE[$skill]="$src"
  done < <(find "$search_root" -name "skill.md" -not -path "*/references/*" 2>/dev/null)
done
for skill in "${!PRIORITY_SOURCE[@]}"; do
  src="${PRIORITY_SOURCE[$skill]}"; installed="$INSTALLED_DIR/$skill/skill.md"
  [[ ! -f "$installed" ]] && continue
  if ! diff -q "$src" "$installed" > /dev/null 2>&1; then
    src_lines=$(wc -l < "$src" | tr -d ' '); inst_lines=$(wc -l < "$installed" | tr -d ' ')
    common=$(comm -12 <(sort "$src") <(sort "$installed") | wc -l | tr -d ' ')
    total=$(( src_lines > inst_lines ? src_lines : inst_lines ))
    overlap_pct=$(( total > 0 ? common * 100 / total : 0 ))
    if [[ "$overlap_pct" -lt 30 ]]; then
      echo "🔴 CRITICAL: $skill — CORRUPTION (${overlap_pct}% overlap)"; ((CRITICAL++))
    else
      echo "🟠 ERROR: $skill — content drift (${overlap_pct}% overlap)"; ((ERRORS++))
    fi
    if [[ "$FIX_MODE" == "true" ]]; then
      backup_skill "$(dirname "$installed")"; cp "$src" "$installed"
      echo "  ✅ FIXED: synced $skill"; ((FIXED++))
    fi
  fi
done

# --- Check 10: Missing Triggers ---
VALIDATOR="$SP_PLUS_DIR/tools/skill-trigger-validator.sh"
EXPLICIT_LIST=""
[[ -f "$VALIDATOR" ]] && EXPLICIT_LIST=$(grep -A50 "^EXPLICIT_SKILLS=" "$VALIDATOR" 2>/dev/null | grep '^\s*"' | tr -d ' "' || echo "")
for f in $(find "$INSTALLED_DIR" -maxdepth 2 -name "skill.md" -not -path "*/references/*" 2>/dev/null); do
  skill=$(basename "$(dirname "$f")")
  yaml_block=$(awk 'NR==1 && /^---$/{found++; next} /^---$/{exit} found{print}' "$f")
  has_triggers=$(echo "$yaml_block" | grep "^triggers:" | grep -v 'triggers: \[\]' | grep -v 'triggers:$' || true)
  if [[ -z "$has_triggers" ]] && ! echo "$EXPLICIT_LIST" | grep -q "^${skill}$"; then
    echo "🟡 WARNING: $skill — no triggers and not in EXPLICIT_SKILLS"; ((WARNINGS++))
  fi
done

# --- Check 11: Trigger Overlap ---
declare -A trigger_map
for f in $(find "$INSTALLED_DIR" -maxdepth 2 -name "skill.md" -not -path "*/references/*" 2>/dev/null); do
  skill=$(basename "$(dirname "$f")")
  triggers=$(awk 'NR==1 && /^---$/{found++; next} /^---$/{exit} found{print}' "$f" | grep "^triggers:" | \
    sed 's/triggers://' | tr -d '[]' | tr ',' '\n' | sed 's/^[[:space:]]*"//;s/"[[:space:]]*$//' | grep -v '^$' || true)
  while IFS= read -r trigger; do
    [[ -z "$trigger" ]] && continue
    lt=$(echo "$trigger" | tr '[:upper:]' '[:lower:]')
    if [[ -n "${trigger_map[$lt]:-}" ]]; then
      echo "🟡 WARNING: trigger '$trigger' shared by: ${trigger_map[$lt]} AND $skill"; ((WARNINGS++))
    fi
    trigger_map["$lt"]="${trigger_map[$lt]:-}${trigger_map[$lt]:+, }$skill"
  done <<< "$triggers"
done

# --- Check 12: Deprecated But Active ---
for f in $(find "$INSTALLED_DIR" -maxdepth 2 -name "skill.md" -not -path "*/references/*" 2>/dev/null); do
  skill=$(basename "$(dirname "$f")")
  if tail -n +2 "$f" | grep -qi "deprecated\|replaced by\|superseded by"; then
    yaml_block=$(awk 'NR==1 && /^---$/{found++; next} /^---$/{exit} found{print}' "$f")
    has_triggers=$(echo "$yaml_block" | grep "^triggers:" | grep -v 'triggers: \[\]' || true)
    [[ -n "$has_triggers" ]] && { echo "🟡 WARNING: $skill — deprecated but has triggers"; ((WARNINGS++)); }
  fi
done

# --- Check 13: Dead File Path References ---
for f in $(find "$INSTALLED_DIR" -maxdepth 2 -name "skill.md" -not -path "*/references/*" 2>/dev/null); do
  skill=$(basename "$(dirname "$f")")
  grep -oE '(~/[a-zA-Z0-9_./-]+|/Users/[a-zA-Z0-9_./-]+)' "$f" 2>/dev/null | while read -r path; do
    expanded=$(eval echo "$path" 2>/dev/null || echo "$path")
    [[ ! -e "$expanded" ]] && echo "🟡 WARNING: $skill — path '$path' does not exist"
  done
done

# --- Check 14: Junk Files ---
for dir in "${SOURCE_DIRS[@]}"; do
  root="${dir%/skills}"
  find "$root" -maxdepth 1 -type f \
    ! -name "*.md" ! -name "*.sh" ! -name "*.js" ! -name "*.json" \
    ! -name "*.yaml" ! -name "*.yml" ! -name "*.txt" \
    ! -name "CODEOWNERS" ! -name ".gitignore" ! -name ".gitattributes" \
    ! -name ".editorconfig" ! -name ".env*" ! -name "LICENSE" \
    ! -name ".DS_Store" ! -name "Makefile" ! -name "package.json" \
    2>/dev/null | while read -r junk; do
      echo "🔵 INFO: junk file in $(basename "$root")/: $(basename "$junk")"
    done
done

# --- Check 15: Structure Quality ---
for f in $(find "$INSTALLED_DIR" -maxdepth 2 -name "skill.md" -not -path "*/references/*" 2>/dev/null); do
  skill=$(basename "$(dirname "$f")"); issues=""
  grep -qi "when to use\|when to invoke" "$f" || issues="${issues}missing 'When to Use'; "
  grep -q '```' "$f" || issues="${issues}no code examples; "
  grep -qi "failure\|fix:\|recovery\|troubleshoot" "$f" || issues="${issues}no failure modes; "
  [[ -n "$issues" ]] && echo "🔵 INFO: $skill — $issues"
done

# --- Check 16: Reference File Integrity ---
declare -A REF_PRIORITY
for dir in "$SP_PLUS_DIR" ${SP_OVERLAY_DIR:+"$SP_OVERLAY_DIR"}; do
  search_root="$dir"; [[ -d "$dir/skills" ]] && search_root="$dir/skills"
  while IFS= read -r src_ref; do
    skill_dir=$(basename "$(dirname "$(dirname "$src_ref")")")
    ref_name=$(basename "$src_ref")
    REF_PRIORITY["${skill_dir}/${ref_name}"]="$src_ref"
  done < <(find "$search_root" -path "*/references/*.md" 2>/dev/null)
done
for key in "${!REF_PRIORITY[@]}"; do
  src_ref="${REF_PRIORITY[$key]}"
  skill_dir="${key%%/*}"; ref_name="${key##*/}"
  installed_ref="$INSTALLED_DIR/$skill_dir/references/$ref_name"
  if [[ ! -f "$installed_ref" ]]; then
    echo "🟠 ERROR: $skill_dir — missing installed reference: $ref_name"; ((ERRORS++))
    if [[ "$FIX_MODE" == "true" ]]; then
      mkdir -p "$(dirname "$installed_ref")"; cp "$src_ref" "$installed_ref"
      echo "  ✅ FIXED: created $skill_dir/references/$ref_name"; ((FIXED++))
    fi
    continue
  fi
  if ! diff -q "$src_ref" "$installed_ref" > /dev/null 2>&1; then
    src_lines=$(wc -l < "$src_ref" | tr -d ' '); inst_lines=$(wc -l < "$installed_ref" | tr -d ' ')
    common=$(comm -12 <(sort "$src_ref") <(sort "$installed_ref") | wc -l | tr -d ' ')
    total=$(( src_lines > inst_lines ? src_lines : inst_lines ))
    overlap_pct=$(( total > 0 ? common * 100 / total : 0 ))
    if [[ "$overlap_pct" -lt 30 ]]; then
      echo "🔴 CRITICAL: $skill_dir/references/$ref_name — CORRUPTION (${overlap_pct}% overlap)"; ((CRITICAL++))
    else
      echo "🟠 ERROR: $skill_dir/references/$ref_name — drift (${overlap_pct}% overlap)"; ((ERRORS++))
    fi
    if [[ "$FIX_MODE" == "true" ]]; then
      backup_skill "$INSTALLED_DIR/$skill_dir"; cp "$src_ref" "$installed_ref"
      echo "  ✅ FIXED: synced $skill_dir/references/$ref_name"; ((FIXED++))
    fi
  fi
done

# --- Summary ---
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
TOTAL=$((CRITICAL + ERRORS + WARNINGS))
if [[ "$TOTAL" -eq 0 ]]; then
  echo "✅ All 16 checks passed. Your superpowers are in perfect health."
else
  echo "  $CRITICAL critical · $ERRORS errors · $WARNINGS warnings"
  echo "  Your superpowers need $TOTAL fixes."
fi
if [[ "$FIX_MODE" == "true" && "$FIXED" -gt 0 ]]; then
  echo "  ✅ Auto-fixed: $FIXED issues"
  echo "  📁 Backups: $BACKUP_DIR"
fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

#!/usr/bin/env bash
# doctor-checks.sh — Run all 25 superpowers-doctor diagnostic checks
#
# Usage:
#   ./doctor-checks.sh                # Run all checks (report only)
#   ./doctor-checks.sh --fix-safe     # Fix non-destructive issues only (sync, CRLF, BOM, pull)
#   ./doctor-checks.sh --fix          # Fix all auto-fixable issues (excludes orphan removal)
#   ./doctor-checks.sh --fix --yes    # Auto-fix without confirmation (excludes orphan removal)
#   ./doctor-checks.sh --purge-orphans # Explicitly remove orphaned installs (requires --fix)
#   ./doctor-checks.sh --summary-only # One-line pass/fail (for post-install)

# shellcheck disable=SC2044  # find loops are safe here — skill paths never contain spaces
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tools/compat.sh
source "${SCRIPT_DIR}/compat.sh"
require_bash4 "$@"

INSTALLED_DIR="$HOME/.codex/skills"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

# Source .env for overlay path (SP_OVERLAY_SOURCE_DIR) and other config
# shellcheck source=/dev/null
[[ -f "$HOME/.codex/.env" ]] && source "$HOME/.codex/.env"

# Fix modes: none < safe < moderate (--fix)
# --fix-safe:  Non-destructive only (sync drift, CRLF, BOM, name mismatch, ref sync)
# --fix:       All fixes including destructive (orphan removal, junk removal, deprecated trigger clear)
FIX_MODE=false
FIX_SAFE=false
SUMMARY_ONLY=false
PURGE_ORPHANS=false
for arg in "$@"; do
  case "$arg" in
    --fix-safe)       FIX_SAFE=true; FIX_MODE=true ;;
    --fix)            FIX_MODE=true ;;
    --purge-orphans)  PURGE_ORPHANS=true ;;
    --summary-only)   SUMMARY_ONLY=true ;;
  esac
done

# Base source: superpowers-plus (SPP_SOURCE_DIR or this repo)
SP_PLUS_DIR="${SPP_SOURCE_DIR:-$REPO_ROOT}"
SOURCE_DIRS=("$SP_PLUS_DIR")

# Auto-discover overlay sources: any *_SOURCE_DIR env var in .env
# (e.g., SP_OVERLAY_SOURCE_DIR, MYTEAM_SOURCE_DIR, etc.)
# Each overlay repo registers itself during install via: VARNAME_SOURCE_DIR="/path/to/repo"
while IFS='=' read -r varname varval; do
  [[ "$varname" == "SPP_SOURCE_DIR" ]] && continue  # base, not overlay
  [[ "$varname" =~ _SOURCE_DIR$ ]] || continue
  _dir="${varval//[\"\']}"
  [[ -n "$_dir" && -d "$_dir" ]] && SOURCE_DIRS+=("$_dir")
done < <(grep '_SOURCE_DIR=' "$HOME/.codex/.env" 2>/dev/null || true)
COMPARE_DIRS=("${SOURCE_DIRS[@]}")

# Managed checkout paths (git repos maintained by install.sh)
MANAGED_SPP_DIR="$HOME/.codex/superpowers-plus"
MANAGED_OBRA_DIR="$HOME/.codex/superpowers"

BACKUP_DIR="$HOME/.codex/doctor-backups/$(date +%Y-%m-%d_%H-%M-%S)-$$"
FIXED=0; CRITICAL=0; ERRORS=0; WARNINGS=0

# Helper: should we fix this check?
# Safe checks: 3 (name), 9 (drift), 16 (ref drift), 17 (CRLF), 18 (BOM), 19 (stale checkout)
# Moderate checks: 8 (orphan), 12 (deprecated), 14 (junk), 20 (dirty checkout)
can_fix() {
  [[ "$FIX_MODE" != "true" ]] && return 1
  [[ "$FIX_SAFE" != "true" ]] && return 0  # --fix allows everything
  # --fix-safe: only allow safe checks (caller passes "safe" or "moderate")
  [[ "$1" == "safe" ]] && return 0
  return 1
}

backup_skill() {
  local target="$1"
  local backup_path
  backup_path="$BACKUP_DIR/$(basename "$target")"
  mkdir -p "$backup_path"
  # -P preserves symlinks, -R recursive (don't follow symlinks into backup)
  # Use /. to copy all contents including dotfiles (/* misses them and fails on empty dirs)
  cp -PR "$target"/. "$backup_path/" 2>/dev/null || {
    echo "  ⚠️  Backup failed for $(basename "$target"). Skipping fix."
    return 1
  }
  # Verify backup has at least as many files as source
  local src_count
  local bak_count
  src_count=$(find "$target" -type f 2>/dev/null | wc -l | tr -d ' ')
  bak_count=$(find "$backup_path" -type f 2>/dev/null | wc -l | tr -d ' ')
  if [[ "$bak_count" -lt "$src_count" ]]; then
    echo "  ⚠️  Backup incomplete ($bak_count/$src_count files). Skipping fix."
    return 1
  fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# PRE-CACHE: One pass over all installed skills. Parse once, check many times.
# ═══════════════════════════════════════════════════════════════════════════════
declare -a ALL_SKILL_FILES=()        # Ordered list of skill.md paths
declare -A SKILL_PATH=()             # skill name → file path
declare -A SKILL_YAML=()             # skill name → YAML frontmatter block
declare -A SKILL_LINES=()            # skill name → line count
declare -A SKILL_YAML_NAME=()        # skill name → name: value from YAML
declare -A SKILL_HAS_TRIGGERS=()     # skill name → "yes" | ""
declare -A SKILL_TRIGGERS_RAW=()     # skill name → raw triggers: line
declare -A SKILL_HAS_CRLF=()         # skill name → "yes" | ""
declare -A SKILL_HAS_BOM=()          # skill name → "yes" | ""
declare -A SKILL_FIRST_LINE=()       # skill name → first line of file
declare -A SKILL_DELIM_COUNT=()      # skill name → count of --- delimiters in first 30 lines
declare -A SKILL_BODY_START=()       # skill name → line number where body starts
declare -A SKILL_YAML_VALID=()       # skill name → "yes" if frontmatter is well-formed

while IFS= read -r f; do
  ALL_SKILL_FILES+=("$f")
  skill=$(basename "$(dirname "$f")")
  SKILL_PATH[$skill]="$f"

  # Read file once, extract everything we need
  SKILL_LINES[$skill]=$(wc -l < "$f" | tr -d ' ')
  SKILL_FIRST_LINE[$skill]=$(head -1 "$f")
  SKILL_DELIM_COUNT[$skill]=$(head -30 "$f" | grep -c "^---$" || true)
  SKILL_HAS_BOM[$skill]=""
  # Portable BOM detection: xxd may not exist on minimal distros; od is POSIX
  if command -v xxd &>/dev/null; then
    [[ "$(xxd -l 3 -p "$f" 2>/dev/null)" == "efbbbf" ]] && SKILL_HAS_BOM[$skill]="yes"
  else
    [[ "$(dd if="$f" bs=1 count=3 2>/dev/null | od -A n -t x1 2>/dev/null | tr -d ' \n')" == "efbbbf" ]] && SKILL_HAS_BOM[$skill]="yes"
  fi
  SKILL_HAS_CRLF[$skill]=""
  # Portable CRLF detection: grep -P is GNU-only; use printf for the \r literal
  grep -q $'\r' "$f" 2>/dev/null && SKILL_HAS_CRLF[$skill]="yes"

  # Parse YAML block (once per skill instead of 6+ times)
  if [[ "${SKILL_FIRST_LINE[$skill]}" == "---" && "${SKILL_DELIM_COUNT[$skill]}" -ge 2 ]]; then
    SKILL_YAML_VALID[$skill]="yes"
    yaml_block=$(awk 'NR==1 && /^---$/{found++; next} /^---$/{exit} found{print}' "$f")
    SKILL_YAML[$skill]="$yaml_block"
    SKILL_YAML_NAME[$skill]=$(echo "$yaml_block" | grep "^name:" | sed 's/name:[[:space:]]*//' | tr -d '"'"'" || true)
    triggers_line=$(echo "$yaml_block" | grep "^triggers:" || true)
    if [[ -n "$triggers_line" ]]; then
      if echo "$triggers_line" | grep -qE 'triggers: \[.+\]'; then
        # Inline array with content: triggers: ["foo", "bar"]
        SKILL_HAS_TRIGGERS[$skill]="yes"
        SKILL_TRIGGERS_RAW[$skill]="$triggers_line"
      elif echo "$triggers_line" | grep -qE 'triggers: \[\]'; then
        # Inline empty array: triggers: []
        SKILL_TRIGGERS_RAW[$skill]=""
      else
        # Multi-line array: triggers:\n  - "foo"\n  - "bar"
        multiline_items=$(echo "$yaml_block" | awk '/^triggers:/{found=1; next} found && /^[[:space:]]+-/{print; next} found{exit}')
        if [[ -n "$multiline_items" ]]; then
          SKILL_HAS_TRIGGERS[$skill]="yes"
          SKILL_TRIGGERS_RAW[$skill]="$multiline_items"
        else
          SKILL_TRIGGERS_RAW[$skill]=""
        fi
      fi
    else
      SKILL_TRIGGERS_RAW[$skill]=""
    fi
    SKILL_BODY_START[$skill]=$(awk 'NR==1 && /^---$/{found++; next} /^---$/{found++; print NR; exit}' "$f")
  else
    SKILL_YAML_VALID[$skill]=""
    SKILL_YAML[$skill]=""
    SKILL_YAML_NAME[$skill]=""
  fi
done < <(find "$INSTALLED_DIR" -maxdepth 2 -name "skill.md" -not -path "*/references/*" 2>/dev/null | sort)

TOTAL_SKILLS=${#ALL_SKILL_FILES[@]}

# In --summary-only mode, suppress individual findings (redirect to /dev/null)
if [[ "$SUMMARY_ONLY" == "true" ]]; then
  exec 3>&1 1>/dev/null  # Save stdout to fd 3, redirect stdout to /dev/null
fi

echo "🩺 Superpowers Doctor — $TOTAL_SKILLS skills scanned (25 checks)"
echo ""

# --- Pre-check: WSL + NTFS mount detection ---
if [[ -f /proc/version ]] && grep -Eqi 'microsoft|wsl' /proc/version 2>/dev/null; then
  case "$INSTALLED_DIR" in
    /mnt/[a-z]/*)
      echo "🟡 WARNING: Skills installed on NTFS mount ($INSTALLED_DIR)"
      echo "   chmod is silently ignored on NTFS. Move skills to a native Linux path."
      echo "   Recommended: ~/.codex/skills/ on ext4 (e.g., ~/)"
      ((WARNINGS++))
      ;;
  esac
fi

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

# --- Check 5: Broken Internal References ---
# Skips: fenced code blocks, directory tree diagrams, and inline prose mentions.
# For examples.md/reference.md: only flags action directives (See/Read/Load/view/link syntax).
# For references/*.md and modules/*.md: flags any non-code-block mention.
for skill in "${!SKILL_PATH[@]}"; do
  f="${SKILL_PATH[$skill]}"; skill_dir=$(dirname "$f")
  # 1. Structural paths (references/, modules/) — any mention outside code blocks
  #    Also skips opt-in files (lines containing "Opt-in" or "Create" before the reference)
  #    For modules/: also checks _shared/ dirs and installed modules dir as fallback.
  while read -r ref; do
    [[ -f "$skill_dir/$ref" ]] && continue
    # For modules/: check shared module locations (e.g., _shared/module.md, installed modules/)
    if [[ "$ref" == modules/* ]]; then
      mod_name="${ref#modules/}"
      found_shared=false
      for sdir in "${SOURCE_DIRS[@]}"; do
        [[ -f "$sdir/_shared/$mod_name" ]] && { found_shared=true; break; }
      done
      [[ -f "$INSTALLED_DIR/../modules/$mod_name" ]] && found_shared=true
      [[ "$found_shared" == "true" ]] && continue
    fi
    echo "🔴 CRITICAL: $skill — references '$ref' but file missing"; ((CRITICAL++))
  done < <(awk '/^```/{c=!c;next} c{next} /[├└│]/{next} /[Oo]pt-in/{next} {print}' "$f" \
    | grep -oE '(references/[a-zA-Z0-9_-]+\.md|modules/[a-zA-Z0-9_-]+\.md)' 2>/dev/null \
    | sort -u)
  # 2. Peer files (examples.md, reference.md) — only markdown link syntax [text](file.md)
  #    Excludes inline code (backticks), prose mentions, and substring matches
  while read -r ref; do
    [[ -z "$ref" ]] && continue
    [[ ! -f "$skill_dir/$ref" ]] && { echo "🔴 CRITICAL: $skill — references '$ref' but file missing"; ((CRITICAL++)); }
  done < <(awk '/^```/{c=!c;next} c{next} /[├└│]/{next} {print}' "$f" \
    | grep -oE '\]\((examples\.md|reference\.md)\)' 2>/dev/null \
    | grep -oE '(examples\.md|reference\.md)' \
    | sort -u)
done

# --- Check 6: Oversized Skills ---
for skill in "${!SKILL_LINES[@]}"; do
  [[ "${SKILL_LINES[$skill]}" -gt 250 ]] && { echo "🟠 ERROR: $skill — ${SKILL_LINES[$skill]} lines (limit: 250)"; ((ERRORS++)); }
done

# --- Check 7: Missing Description ---
for skill in "${!SKILL_YAML[@]}"; do
  [[ -z "${SKILL_YAML_VALID[$skill]:-}" ]] && continue
  echo "${SKILL_YAML[$skill]}" | grep -q "^description:" || { echo "🟠 ERROR: $skill — no description:"; ((ERRORS++)); }
done

# --- Check 8: Orphaned Installs ---
# Demoted from ERROR+auto-fix to WARNING+report-only (2026-03-25).
# Reason: locally-created skills that haven't been committed to a source repo yet
# were being silently deleted. This destroyed wiki-editing skills and their
# API access patterns, causing agents to give up on wiki access entirely.
# Use --purge-orphans to explicitly opt into orphan removal.
declare -A _source_skill_names=()
for dir in "${SOURCE_DIRS[@]}"; do
  search_root="$dir"; [[ -d "$dir/skills" ]] && search_root="$dir/skills"
  while IFS= read -r sd; do
    _source_skill_names[$(basename "$sd")]=1
  done < <(find "$search_root" -name "skill.md" -not -path "*/references/*" -exec dirname {} \; 2>/dev/null)
done
while IFS= read -r installed; do
  skill=$(basename "$installed")
  [[ "$skill" == "_shared" || "$skill" == "doctor-backups" ]] && continue
  if [[ -z "${_source_skill_names[$skill]:-}" ]]; then
    echo "🟡 WARNING: $skill — orphaned install (not in any source repo)"
    echo "  ℹ️  To remove: re-run with --fix --purge-orphans"
    ((WARNINGS++))
    if [[ "$PURGE_ORPHANS" == "true" ]] && can_fix moderate; then
      if backup_skill "$installed"; then
        rm -rf "${installed:?}"
        echo "  ✅ FIXED: removed orphan $skill"; ((FIXED++))
      fi
    fi
  fi
done < <(find "$INSTALLED_DIR" -maxdepth 1 -mindepth 1 -type d 2>/dev/null)

# --- Check 9: Source-Install Content Drift ---
# Tracks priority source (overlay wins over base) AND base source for overlay-aware comparison.
declare -A PRIORITY_SOURCE
declare -A BASE_SOURCE
for dir in "${COMPARE_DIRS[@]}"; do
  search_root="$dir"; [[ -d "$dir/skills" ]] && search_root="$dir/skills"
  while IFS= read -r src; do
    skill=$(basename "$(dirname "$src")")
    # If this is the base (plus) dir, record it separately
    if [[ "$dir" == "$SP_PLUS_DIR" ]]; then
      BASE_SOURCE[$skill]="$src"
    fi
    PRIORITY_SOURCE[$skill]="$src"
  done < <(find "$search_root" -name "skill.md" -not -path "*/references/*" 2>/dev/null)
done
for skill in "${!PRIORITY_SOURCE[@]}"; do
  src="${PRIORITY_SOURCE[$skill]}"; installed="$INSTALLED_DIR/$skill/skill.md"
  [[ ! -f "$installed" ]] && continue
  if ! diff -q "$src" "$installed" > /dev/null 2>&1; then
    # If overlay has "overrides:" and installed matches the base source, that's OK
    yaml_block=$(awk 'NR==1 && /^---$/{found++; next} /^---$/{exit} found{print}' "$src")
    if echo "$yaml_block" | grep -q "^overrides:" && [[ -n "${BASE_SOURCE[$skill]:-}" ]]; then
      if diff -q "${BASE_SOURCE[$skill]}" "$installed" > /dev/null 2>&1; then
        continue  # Installed matches base, overlay is intentional — no drift
      fi
    fi
    src_lines=$(wc -l < "$src" | tr -d ' ')
    # Count changed lines (additions + deletions) from unified diff
    changed=$(diff -u "$src" "$installed" | grep -c '^[+-][^+-]' || true)
    total=$(( src_lines > 0 ? src_lines : 1 ))
    change_pct=$(( changed * 100 / total ))
    if [[ "$change_pct" -eq 0 ]]; then
      : # Trivial diff (whitespace/metadata only) — not actionable
    elif [[ "$change_pct" -gt 70 ]]; then
      echo "🔴 CRITICAL: $skill — CORRUPTION (${change_pct}% changed)"; ((CRITICAL++))
    else
      echo "🟠 ERROR: $skill — content drift (${change_pct}% changed)"; ((ERRORS++))
    fi
    if can_fix safe; then
      if backup_skill "$(dirname "$installed")" && cp "$src" "$installed"; then
        echo "  ✅ FIXED: synced $skill"; ((FIXED++))
      fi
    fi
  fi
done

# --- Check 10: Missing Triggers ---
VALIDATOR="$SP_PLUS_DIR/tools/skill-trigger-validator.sh"
EXPLICIT_LIST=""
# Parse EXPLICIT_SKILLS array from validator using awk (portable, no line-count limit)
# Match only the closing ')' on its own line (not ')' inside comments like "(upgrades packages)")
[[ -f "$VALIDATOR" ]] && EXPLICIT_LIST=$(awk '/^EXPLICIT_SKILLS=/{found=1; next} found && /^[[:space:]]*\)/{exit} found{gsub(/#.*/, ""); gsub(/[[:space:]"]+/, ""); if ($0 != "") print}' "$VALIDATOR" 2>/dev/null || echo "")
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
  # Pre-commit chain: ordered sequential checks before commit
  "pre-commit-gate enforce-style-guide progressive-code-review-gate professional-language-audit public-repo-ip-audit"
  # Resume screening: generic vs source-specific
  "resume-screening cv-review-external"
  # PR verification: complementary pre-PR checks
  "holistic-repo-verification engineering-rigor"
  # Security: vulnerability scanning vs repo secret scanning
  "security-upgrade repo-security-scan"
  # Skill creation: authoring workflow vs writing conventions
  "skill-authoring writing-skills"
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
  if echo "$triggers_raw" | grep -q '^\s*-'; then
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

# --- Check 13: Dead File Path References ---
# Lines containing "doctor-ignore" are suppressed (runtime-only paths, examples, etc.)
# Uses a single awk pass per file to extract candidate paths, avoiding per-line subshells.
for skill in "${!SKILL_PATH[@]}"; do
  f="${SKILL_PATH[$skill]}"
  # awk extracts unique ~/... and /Users/... paths from non-code-block, non-ignored lines
  # that don't have the path wrapped in backticks
  while IFS= read -r path; do
    [[ -z "$path" ]] && continue
    # Safe tilde expansion without eval (avoids command injection risk)
    # shellcheck disable=SC2088  # Intentional literal match, not tilde expansion
    if [[ "$path" == "~/"* ]]; then
      expanded="$HOME/${path#\~/}"
    else
      expanded="$path"
    fi
    [[ ! -e "$expanded" ]] && { echo "🟡 WARNING: $skill — path '$path' does not exist"; ((WARNINGS++)); }
  done < <(awk '
    BEGIN { tilde_re = "~/[a-zA-Z0-9_./-]+"; users_re = "/Users/[a-zA-Z0-9_./-]+" }
    /^```/ { code=!code; next }
    code { next }
    /[Dd]octor-ignore/ { next }
    {
      line = $0
      # Skip lines where path appears only inside backtick pairs
      if (index(line, "`") > 0) {
        tmp = line; gsub(/`[^`]*`/, "", tmp)
        if (index(tmp, "~/") == 0 && index(tmp, "/Users/") == 0) next
      }
      while (match(line, tilde_re) || match(line, users_re)) {
        p = substr(line, RSTART, RLENGTH)
        if (!(p in seen)) { seen[p]=1; print p }
        line = substr(line, RSTART + RLENGTH)
      }
    }
  ' "$f")
done

# --- Check 14: Junk Files ---
for dir in "${SOURCE_DIRS[@]}"; do
  root="${dir%/skills}"
  while IFS= read -r junk; do
    [[ -z "$junk" ]] && continue

    # Skip files that are tracked by git or intentionally ignored.
    # Tracked files (e.g. .ip-patterns) are legitimate repo content, not junk.
    # Ignored files are local artifacts the repo has already excluded.
    if [[ -d "$root/.git" ]] && command -v git &>/dev/null; then
      rel="${junk#"$root"/}"
      git -C "$root" check-ignore -q -- "$rel" 2>/dev/null && continue
      git -C "$root" ls-files --error-unmatch -- "$rel" &>/dev/null && continue
    fi

    echo "🔵 INFO: junk file in $(basename "$root")/: $(basename "$junk")"
    if can_fix moderate; then
      rm -f "$junk"
      echo "  ✅ FIXED: removed $(basename "$junk")"; ((FIXED++))
    fi
  done < <(find "$root" -maxdepth 1 -type f \
    ! -name "*.md" ! -name "*.sh" ! -name "*.ps1" ! -name "*.js" ! -name "*.json" \
    ! -name "*.yaml" ! -name "*.yml" ! -name "*.txt" \
    ! -name "CODEOWNERS" ! -name ".gitignore" ! -name ".gitattributes" \
    ! -name ".editorconfig" ! -name ".env*" ! -name "LICENSE" \
    ! -name ".DS_Store" ! -name "Makefile" ! -name "package.json" \
    2>/dev/null)
done

# --- Check 15: Structure Quality ---
for skill in "${!SKILL_PATH[@]}"; do
  f="${SKILL_PATH[$skill]}"; issues=""
  grep -Eqi 'when to use|when to invoke' "$f" || issues="${issues}missing 'When to Use'; "
  grep -q '```' "$f" || issues="${issues}no code examples; "
  grep -Eqi 'failure|fix:|recovery|troubleshoot' "$f" || issues="${issues}no failure modes; "
  [[ -n "$issues" ]] && echo "🔵 INFO: $skill — $issues"
done

# --- Check 16: Reference File Integrity ---
# Track which reference files come from overlay vs base for overlay-aware comparison.
declare -A REF_PRIORITY
declare -A REF_OWNER_DIR
declare -A REF_IS_OVERLAY_ONLY  # Track refs that only exist in overlay, not base
declare -A REF_IS_BASE_ONLY     # Track refs that only exist in base, not overlay
declare -A OVERLAY_SOURCE       # Track overlay skill.md paths for comparison
declare -A INSTALLED_MATCH_DIR

for dir in "${COMPARE_DIRS[@]}"; do
  search_root="$dir"; [[ -d "$dir/skills" ]] && search_root="$dir/skills"
  while IFS= read -r src; do
    skill=$(basename "$(dirname "$src")")
    installed_skill="$INSTALLED_DIR/$skill/skill.md"
    if [[ -f "$installed_skill" ]] && diff -q "$src" "$installed_skill" > /dev/null 2>&1; then
      INSTALLED_MATCH_DIR[$skill]="$dir"
    fi
  done < <(find "$search_root" -name "skill.md" -not -path "*/references/*" 2>/dev/null)
done

for dir in "${COMPARE_DIRS[@]}"; do
  search_root="$dir"; [[ -d "$dir/skills" ]] && search_root="$dir/skills"
  while IFS= read -r src_ref; do
    skill_dir=$(basename "$(dirname "$(dirname "$src_ref")")")
    ref_name=$(basename "$src_ref")
    key="${skill_dir}/${ref_name}"
    if [[ "$dir" != "$SP_PLUS_DIR" && -z "${REF_PRIORITY[$key]:-}" ]]; then
      REF_IS_OVERLAY_ONLY[$key]="true"
    elif [[ "$dir" == "$SP_PLUS_DIR" ]]; then
      REF_IS_OVERLAY_ONLY[$key]=""  # Exists in base, not overlay-only
      REF_IS_BASE_ONLY[$key]="true" # Tentatively base-only (cleared if overlay also has it)
    fi
    if [[ "$dir" != "$SP_PLUS_DIR" ]]; then
      REF_IS_BASE_ONLY[$key]=""  # Overlay also has it — not base-only
    fi
    REF_OWNER_DIR[$key]="$dir"
    REF_PRIORITY[$key]="$src_ref"
  done < <(find "$search_root" -path "*/references/*.md" 2>/dev/null)
  # Track overlay skill.md paths
  if [[ "$dir" != "$SP_PLUS_DIR" ]]; then
    while IFS= read -r src; do
      skill=$(basename "$(dirname "$src")")
      OVERLAY_SOURCE[$skill]="$src"
    done < <(find "$search_root" -name "skill.md" -not -path "*/references/*" 2>/dev/null)
  fi
done
for key in "${!REF_PRIORITY[@]}"; do
  src_ref="${REF_PRIORITY[$key]}"
  skill_dir="${key%%/*}"; ref_name="${key##*/}"
  matched_dir="${INSTALLED_MATCH_DIR[$skill_dir]:-}"
  ref_owner_dir="${REF_OWNER_DIR[$key]:-}"
  if [[ -n "$matched_dir" && -n "$ref_owner_dir" && "$matched_dir" != "$ref_owner_dir" ]]; then
    continue
  fi
  installed_ref="$INSTALLED_DIR/$skill_dir/references/$ref_name"
  if [[ ! -f "$installed_ref" ]]; then
    # If this ref only exists in overlay and the installed skill matches the base, skip it
    if [[ -n "${REF_IS_OVERLAY_ONLY[$key]:-}" ]]; then
      installed_skill="$INSTALLED_DIR/$skill_dir/skill.md"
      base_skill="${BASE_SOURCE[$skill_dir]:-}"
      if [[ -n "$base_skill" && -f "$installed_skill" ]] && diff -q "$base_skill" "$installed_skill" > /dev/null 2>&1; then
        continue  # Installed skill is base version, overlay-only ref not expected
      fi
    fi
    # If this ref only exists in base and the installed skill matches the overlay, skip it
    if [[ -n "${REF_IS_BASE_ONLY[$key]:-}" ]]; then
      installed_skill="$INSTALLED_DIR/$skill_dir/skill.md"
      overlay_skill="${OVERLAY_SOURCE[$skill_dir]:-}"
      if [[ -n "$overlay_skill" && -f "$installed_skill" ]] && diff -q "$overlay_skill" "$installed_skill" > /dev/null 2>&1; then
        continue  # Installed skill is overlay version, base-only ref not expected
      fi
    fi
    echo "🟠 ERROR: $skill_dir — missing installed reference: $ref_name"; ((ERRORS++))
    if can_fix safe; then
      if mkdir -p "$(dirname "$installed_ref")" && cp "$src_ref" "$installed_ref"; then
        echo "  ✅ FIXED: created $skill_dir/references/$ref_name"; ((FIXED++))
      fi
    fi
    continue
  fi
  if ! diff -q "$src_ref" "$installed_ref" > /dev/null 2>&1; then
    src_lines=$(wc -l < "$src_ref" | tr -d ' ')
    changed=$(diff -u "$src_ref" "$installed_ref" | grep -c '^[+-][^+-]' || true)
    total=$(( src_lines > 0 ? src_lines : 1 ))
    change_pct=$(( changed * 100 / total ))
    if [[ "$change_pct" -gt 70 ]]; then
      echo "🔴 CRITICAL: $skill_dir/references/$ref_name — CORRUPTION (${change_pct}% changed)"; ((CRITICAL++))
    else
      echo "🟠 ERROR: $skill_dir/references/$ref_name — drift (${change_pct}% changed)"; ((ERRORS++))
    fi
    if can_fix safe; then
      if backup_skill "$INSTALLED_DIR/$skill_dir" && cp "$src_ref" "$installed_ref"; then
        echo "  ✅ FIXED: synced $skill_dir/references/$ref_name"; ((FIXED++))
      fi
    fi
  fi
done

# --- Check 17: CRLF Line Ending Detection ---
for skill in "${!SKILL_PATH[@]}"; do
  if [[ -n "${SKILL_HAS_CRLF[$skill]:-}" ]]; then
    f="${SKILL_PATH[$skill]}"
    echo "🟠 ERROR: $skill — CRLF line endings detected"; ((ERRORS++))
    if can_fix safe; then
      backup_skill "$(dirname "$f")" || continue
      sed_inplace 's/\r$//' "$f"
      echo "  ✅ FIXED: converted $skill to LF"; ((FIXED++))
    fi
  fi
done
# Also check reference files (still need find here — refs aren't in the cache)
while IFS= read -r f; do
  skill=$(basename "$(dirname "$(dirname "$f")")")
  ref_name=$(basename "$f")
  if grep -q $'\r' "$f" 2>/dev/null; then
    echo "🟠 ERROR: $skill/references/$ref_name — CRLF line endings"; ((ERRORS++))
    if can_fix safe; then
      backup_skill "$INSTALLED_DIR/$skill" || continue
      sed_inplace 's/\r$//' "$f"
      echo "  ✅ FIXED: converted $skill/references/$ref_name to LF"; ((FIXED++))
    fi
  fi
done < <(find "$INSTALLED_DIR" -maxdepth 3 -path "*/references/*.md" 2>/dev/null)

# --- Check 18: UTF-8 BOM Detection ---
for skill in "${!SKILL_PATH[@]}"; do
  if [[ -n "${SKILL_HAS_BOM[$skill]:-}" ]]; then
    f="${SKILL_PATH[$skill]}"
    echo "🟡 WARNING: $skill — UTF-8 BOM detected (breaks YAML parsing)"; ((WARNINGS++))
    if can_fix safe; then
      backup_skill "$(dirname "$f")" || continue
      tail -c +4 "$f" > "$f.tmp" && mv "$f.tmp" "$f"
      echo "  ✅ FIXED: stripped BOM from $skill"; ((FIXED++))
    fi
  fi
done


# --- Check 19: Stale Managed Checkout ---
# Detect when ~/.codex/superpowers-plus is behind origin/main.
# Parallel pre-fetch: kick off both git fetches concurrently to cut network wait in half
_timeout_cmd=""
command -v timeout &>/dev/null && _timeout_cmd="timeout 10"
command -v gtimeout &>/dev/null && _timeout_cmd="gtimeout 10"
declare -A _fetch_ok=()
if command -v git &>/dev/null; then
for managed_entry in "$MANAGED_SPP_DIR:superpowers-plus" "$MANAGED_OBRA_DIR:obra/superpowers"; do
  managed_dir="${managed_entry%%:*}"
  if [[ -d "$managed_dir/.git" ]]; then
    # shellcheck disable=SC2086
    $_timeout_cmd git -C "$managed_dir" fetch origin --quiet 2>/dev/null &
    _fetch_ok[$managed_dir]=$!
  fi
done
# Wait for all fetches to complete
for dir in "${!_fetch_ok[@]}"; do
  if ! wait "${_fetch_ok[$dir]}" 2>/dev/null; then
    _fetch_ok[$dir]="failed"
  else
    _fetch_ok[$dir]="ok"
  fi
done

check_stale_checkout() {
  local dir="$1" label="$2"
  [[ -d "$dir/.git" ]] || return 0
  if [[ "${_fetch_ok[$dir]:-}" == "failed" ]]; then
    echo "🟡 WARNING: $label — could not fetch origin (network issue?)"; ((WARNINGS++))
    return 0
  fi
  local local_head remote_head ahead behind
  local_head=$(git -C "$dir" rev-parse HEAD 2>/dev/null || echo "unknown")
  remote_head=$(git -C "$dir" rev-parse origin/main 2>/dev/null || echo "unknown")
  if [[ "$local_head" == "unknown" || "$remote_head" == "unknown" ]]; then
    return 0  # Can't compare — skip silently
  fi
  if [[ "$local_head" == "$remote_head" ]]; then
    return 0  # Up to date
  fi
  ahead=$(git -C "$dir" rev-list --count origin/main..HEAD 2>/dev/null || echo 0)
  behind=$(git -C "$dir" rev-list --count HEAD..origin/main 2>/dev/null || echo 0)
  local local_short remote_short
  local_short="${local_head:0:10}"
  remote_short="${remote_head:0:10}"
  if [[ "$behind" -gt 0 ]]; then
    echo "🟠 ERROR: $label — ${behind} commits behind origin/main"
    echo "   Local HEAD:  $local_short  Remote HEAD: $remote_short"
    [[ "$ahead" -gt 0 ]] && echo "   Also ${ahead} commits ahead (diverged)"
    ((ERRORS++))
    if can_fix safe && [[ "$ahead" -eq 0 ]]; then
      if git -C "$dir" pull --ff-only origin main --quiet 2>/dev/null; then
        echo "  ✅ FIXED: fast-forwarded $label to origin/main"; ((FIXED++))
      else
        echo "  ⚠️  Could not fast-forward (local changes?). Run: git -C \"$dir\" pull"
      fi
    fi
  fi
}
for managed_entry in "$MANAGED_SPP_DIR:superpowers-plus" "$MANAGED_OBRA_DIR:obra/superpowers"; do
  managed_dir="${managed_entry%%:*}"
  managed_label="${managed_entry##*:}"
  check_stale_checkout "$managed_dir" "$managed_label"
done

# --- Check 20: Dirty Managed Checkout ---
# Detect tracked and untracked changes in managed checkouts.
# Distinguishes safe-to-recreate artifacts from likely user-authored changes.
SAFE_DIRTY_PATTERNS='node_modules/|__pycache__/|\.pyc$|\.pyo$|\.DS_Store$|\.env\.local$|install-state/|modules/'
check_dirty_checkout() {
  local dir="$1" label="$2"
  [[ -d "$dir/.git" ]] || return 0
  local porcelain user_changes safe_changes
  porcelain=$(git -C "$dir" status --porcelain 2>/dev/null || true)
  [[ -z "$porcelain" ]] && return 0  # Clean
  safe_changes=$(echo "$porcelain" | grep -E "$SAFE_DIRTY_PATTERNS" || true)
  user_changes=$(echo "$porcelain" | grep -vE "$SAFE_DIRTY_PATTERNS" || true)
  local safe_count user_count
  safe_count=0; [[ -n "$safe_changes" ]] && safe_count=$(echo "$safe_changes" | wc -l | tr -d ' ')
  user_count=0; [[ -n "$user_changes" ]] && user_count=$(echo "$user_changes" | wc -l | tr -d ' ')
  if [[ "$user_count" -gt 0 ]]; then
    echo "🟠 ERROR: $label — $user_count uncommitted change(s) detected"
    echo "$user_changes" | head -5 | while IFS= read -r line; do
      echo "   $line"
    done
    [[ "$user_count" -gt 5 ]] && echo "   ... and $((user_count - 5)) more"
    ((ERRORS++))
    if can_fix moderate; then
      # Stash user changes with a descriptive message before any destructive action
      local stash_msg
      stash_msg="doctor-backup-$(date +%Y%m%d-%H%M%S)"
      # git stash push requires git 2.13+; fall back to git stash save
      local stash_ok=false
      if git -C "$dir" stash push -m "$stash_msg" --include-untracked 2>/dev/null; then
        stash_ok=true
      elif git -C "$dir" stash save "$stash_msg" 2>/dev/null; then
        stash_ok=true
      fi
      if [[ "$stash_ok" == "true" ]]; then
        echo "  ✅ FIXED: stashed local changes as '$stash_msg'"
        echo "  📦 Recover with: git -C \"$dir\" stash pop"; ((FIXED++))
      else
        echo "  ⚠️  Could not stash changes. Resolve manually."
      fi
    fi
  fi
  if [[ "$safe_count" -gt 0 ]]; then
    echo "🔵 INFO: $label — $safe_count generated/install artifact(s) (safe to clean)"
    if can_fix moderate; then
      git -C "$dir" clean -fdX --quiet 2>/dev/null || true
      echo "  ✅ FIXED: cleaned generated artifacts"; ((FIXED++))
    fi
  fi
}
for managed_entry in "$MANAGED_SPP_DIR:superpowers-plus" "$MANAGED_OBRA_DIR:obra/superpowers"; do
  managed_dir="${managed_entry%%:*}"
  managed_label="${managed_entry##*:}"
  check_dirty_checkout "$managed_dir" "$managed_label"
done
fi  # end: command -v git guard for checks 19/20

# --- Check 21: TODO Archive Smoke Test ---
# Validates the installed TODO maintenance/archive flow using a temporary fixture.
# Catches regressions where a small-but-valid TODO with archivable history fails
# to archive correctly or produces a result exceeding expected size.
MAINT_SCRIPT="$SCRIPT_DIR/todo-maintenance.sh"
if [[ -f "$MAINT_SCRIPT" ]] && command -v python3 &>/dev/null && command -v mktemp &>/dev/null; then
  _doctor_todo_smoke() {
    local fixture_root fixture_todo fixture_env result_json line_count
    fixture_root=$(mktemp -d "${TMPDIR:-/tmp}/doctor-todo-smoke-XXXXXX")
    mkdir -p "$fixture_root/home/.codex" "$fixture_root/data"
    fixture_todo="$fixture_root/data/TODO.md"
    fixture_env="$fixture_root/home/.codex/.env"
    printf 'TODO_FILE_PATH=%s\n' "$fixture_todo" > "$fixture_env"
    # Small but structurally valid TODO with archivable history (≥5 done items, >7d old)
    cat > "$fixture_todo" <<'FIXTURE'
# ACTIVE TASKS

## P1 - Today

- [ ] [20260322-01] Smoke test active task #doctor

## P2 - This Week

## P3 - Backlog

---

# HISTORY

## 2026-03-01
- [x] [20260301-01] Archived item one #doctor
  - Added: 2026-03-01
  - Done: 2026-03-01T10:00:00

- [x] [20260301-02] Archived item two #doctor
  - Added: 2026-03-01
  - Done: 2026-03-01T11:00:00

- [x] [20260301-03] Archived item three #doctor
  - Added: 2026-03-01
  - Done: 2026-03-01T12:00:00

- [x] [20260301-04] Archived item four #doctor
  - Added: 2026-03-01
  - Done: 2026-03-01T13:00:00

- [x] [20260301-05] Archived item five #doctor
  - Added: 2026-03-01
  - Done: 2026-03-01T14:00:00

---

# DEFERRED

---

# METRICS
FIXTURE
    # Run maintenance in JSON mode against the fixture
    if ! result_json=$(HOME="$fixture_root/home" bash "$MAINT_SCRIPT" --json 2>&1); then
      echo "🟠 ERROR: TODO archive smoke test — maintenance script failed"
      echo "   Output: $(echo "$result_json" | head -3)"
      ((ERRORS++))
      rm -rf "${fixture_root:?}"
      return
    fi
    # Validate: archive should have been performed
    if ! echo "$result_json" | python3 -c "
import json, sys
data = json.load(sys.stdin)
assert data.get('archive_performed') is True, 'archive not performed'
assert data.get('after', {}).get('history_count', 99) == 0, 'history not cleared'
" 2>/dev/null; then
      echo "🟠 ERROR: TODO archive smoke test — archive did not complete as expected"
      ((ERRORS++))
      rm -rf "${fixture_root:?}"
      return
    fi
    # Validate: resulting file should be under 50 lines (small TODO regression check)
    line_count=$(wc -l < "$fixture_todo" | tr -d ' ')
    if (( line_count >= 50 )); then
      echo "🟠 ERROR: TODO archive smoke test — result is $line_count lines (expected <50)"
      ((ERRORS++))
      rm -rf "${fixture_root:?}"
      return
    fi
    # Validate: active task survived
    if ! grep -q '\[20260322-01\]' "$fixture_todo"; then
      echo "🟠 ERROR: TODO archive smoke test — active task was lost during archive"
      ((ERRORS++))
      rm -rf "${fixture_root:?}"
      return
    fi
    rm -rf "${fixture_root:?}"
  }
  _doctor_todo_smoke
fi

# --- Check 25: Stale Workflow State ---
# IMPORTANT: This must run BEFORE check 22 (reviewer-dispatch) because check 22
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

# --- Check 22: Reviewer-Dispatch Rendering Verification ---
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

# --- Check 23: TODO Honeypot Integrity ---
# Verifies the honeypot file at ~/.codex/TODO.md is intact: exists, has correct
# permissions (444), has immutable flag (uchg/chattr +i), and content matches
# the canonical sentinel. Agents that bypass todo-crud.sh and write directly
# to this path will be caught by the immutable flag; this check catches
# post-facto tampering or flag removal.
#
# OPTIONAL: This check is skipped when the user's real TODO file IS at
# ~/.codex/TODO.md (the default path). The honeypot only exists to protect
# users who store their TODO elsewhere (OneDrive, Dropbox, shared repo, etc.)
_doctor_todo_honeypot() {
  local honeypot="$HOME/.codex/TODO.md"

  # Resolve the real TODO path to check if honeypot is applicable
  local real_todo_path=""
  if [[ -f "$HOME/.codex/.todo-registry" ]]; then
    real_todo_path=$(sed 's/^[[:space:]]*//;s/[[:space:]]*$//' "$HOME/.codex/.todo-registry")
  fi
  if [[ -z "$real_todo_path" && -f "$HOME/.codex/.env" ]]; then
    real_todo_path=$(grep '^TODO_FILE_PATH=' "$HOME/.codex/.env" 2>/dev/null | head -1 | cut -d= -f2- | sed "s/^[[:space:]]*//;s/[[:space:]]*$//;s/^[\"']//;s/[\"']$//")
  fi
  # Safe variable expansion
  # shellcheck disable=SC2088,SC2016  # Intentional literal match against unexpanded $HOME patterns
  if [[ "$real_todo_path" == "~/"* ]]; then
    real_todo_path="$HOME/${real_todo_path#\~/}"
  elif [[ "$real_todo_path" == '$HOME/'* ]]; then
    real_todo_path="$HOME/${real_todo_path#\$HOME/}"
  elif [[ "$real_todo_path" == '${HOME}/'* ]]; then
    real_todo_path="$HOME/${real_todo_path#\$\{HOME\}/}"
  fi

  # If the real TODO path IS ~/.codex/TODO.md (or not configured, defaulting to it),
  # skip honeypot checks — the user's working file lives there.
  local real_canonical honeypot_canonical
  honeypot_canonical=$(realpath "$honeypot" 2>/dev/null || echo "$honeypot")
  if [[ -z "$real_todo_path" ]]; then
    # Not configured — default is ~/.codex/TODO.md, so no honeypot
    return 0
  fi
  real_canonical=$(realpath "$real_todo_path" 2>/dev/null || echo "$real_todo_path")
  if [[ "$real_canonical" == "$honeypot_canonical" ]]; then
    # Real TODO IS the honeypot path — skip all honeypot checks
    return 0
  fi

  # Expected canonical content (must match todo-crud.sh HONEYPOT_EXPECTED_CONTENT)
  local expected_content
  expected_content='# 🚨 STOP — WRONG FILE 🚨
# THIS IS NOT THE REAL TODO FILE
#
# You are violating TODO management rules. The real TODO.md is managed
# by todo-crud.sh and lives at a path resolved from ~/.codex/.todo-registry
# or ~/.codex/.env (TODO_FILE_PATH). This file is a honeypot.
#
# What you MUST do instead:
#
#   READ:     ~/.codex/superpowers-plus/tools/todo-crud.sh cat
#   ADD:      ~/.codex/superpowers-plus/tools/todo-crud.sh add --priority P1 --description "..."
#   COMPLETE: ~/.codex/superpowers-plus/tools/todo-crud.sh complete --id YYYYMMDD-NN
#   PATH:     ~/.codex/superpowers-plus/tools/todo-crud.sh path
#
# NEVER use cat >, echo >, save-file, or str-replace-editor on ANY TODO.md.
# NEVER guess the TODO path — ALWAYS use todo-crud.sh path.
#
# Load the skill first:
#   node ~/.codex/superpowers-augment/superpowers-augment.js use-skill todo-management
'

  # 23a. File exists (WARNING, not CRITICAL — honeypot is optional)
  if [[ ! -f "$honeypot" ]]; then
    echo "🟡 WARNING: TODO honeypot not deployed at $honeypot (optional — deploy with sp-install)"
    WARNINGS=$((WARNINGS + 1))
    if can_fix "safe"; then
      if printf '%s' "$expected_content" > "$honeypot" && chmod 444 "$honeypot"; then
        set_immutable "$honeypot" || true
        echo "  ✅ FIXED: restored honeypot"
        FIXED=$((FIXED + 1))
      else
        echo "  ⚠️  Could not create honeypot (permission denied?)"
      fi
    fi
    return
  fi

  # 23b. Content integrity (portable hash via compat.sh)
  local actual_hash expected_hash
  actual_hash=$(sha256_hash "$honeypot")
  expected_hash=$(printf '%s' "$expected_content" | sha256_hash_stdin)
  if [[ "$actual_hash" != "$expected_hash" ]]; then
    echo "🔴 CRITICAL: TODO honeypot content TAMPERED at $honeypot"
    CRITICAL=$((CRITICAL + 1))
    if can_fix "safe"; then
      clear_immutable "$honeypot"
      if printf '%s' "$expected_content" > "$honeypot" && chmod 444 "$honeypot"; then
        set_immutable "$honeypot" || true
        echo "  ✅ FIXED: restored honeypot content"
        FIXED=$((FIXED + 1))
      else
        echo "  ⚠️  Could not restore honeypot content"
      fi
    fi
  fi

  # 23c. Permissions
  local perms
  perms=$(stat -f "%Lp" "$honeypot" 2>/dev/null || stat -c "%a" "$honeypot" 2>/dev/null || echo "")
  if [[ "$perms" != "444" ]]; then
    echo "🟠 ERROR: TODO honeypot permissions are $perms (expected 444)"
    ERRORS=$((ERRORS + 1))
    if can_fix "safe"; then
      clear_immutable "$honeypot"
      if chmod 444 "$honeypot"; then
        set_immutable "$honeypot" || true
        echo "  ✅ FIXED: set permissions to 444"
        FIXED=$((FIXED + 1))
      else
        echo "  ⚠️  Could not set permissions"
      fi
    fi
  fi

  # 23d. Immutable flag (portable via compat.sh)
  check_immutable "$honeypot"
  local immutable_status=$?
  if [[ "$immutable_status" -eq 1 ]]; then
    echo "🟠 ERROR: TODO honeypot missing immutable flag"
    ERRORS=$((ERRORS + 1))
    if can_fix "safe"; then
      if set_immutable "$honeypot"; then
        echo "  ✅ FIXED: set immutable flag"
        FIXED=$((FIXED + 1))
      else
        echo "  ⚠️  Could not set immutable flag (may need sudo on Linux)"
      fi
    fi
  elif [[ "$immutable_status" -eq 2 ]]; then
    # WSL+NTFS or lsattr unavailable — downgrade to info
    echo "🔵 INFO: TODO honeypot — cannot verify immutable flag on this platform/filesystem"
  fi
}
_doctor_todo_honeypot

# --- Check 24: TODO Path Validation ---
# Verifies the TODO system is properly configured: .todo-registry or .env
# contains a valid path, the real TODO.md exists and has valid structure.
_doctor_todo_path() {
  local todo_path=""

  # Try .todo-registry first
  local registry="$HOME/.codex/.todo-registry"
  if [[ -f "$registry" ]]; then
    # Strip only leading/trailing whitespace, not internal spaces (paths can have spaces)
    todo_path=$(sed 's/^[[:space:]]*//;s/[[:space:]]*$//' "$registry")
  fi

  # Fall back to .env
  if [[ -z "$todo_path" && -f "$HOME/.codex/.env" ]]; then
    todo_path=$(grep '^TODO_FILE_PATH=' "$HOME/.codex/.env" 2>/dev/null | head -1 | cut -d= -f2- | sed "s/^[[:space:]]*//;s/[[:space:]]*$//;s/^[\"']//;s/[\"']$//")
  fi

  if [[ -z "$todo_path" ]]; then
    echo "🟡 WARNING: TODO path not configured in .todo-registry or .env"
    WARNINGS=$((WARNINGS + 1))
    return
  fi

  # Safe variable expansion (no eval — prevents shell injection)
  # Handles ~/..., $HOME/..., and ${HOME}/... without exposing to arbitrary code execution
  # shellcheck disable=SC2088,SC2016  # Intentional literal match against unexpanded $HOME patterns
  if [[ "$todo_path" == "~/"* ]]; then
    todo_path="$HOME/${todo_path#\~/}"
  elif [[ "$todo_path" == '$HOME/'* ]]; then
    todo_path="$HOME/${todo_path#\$HOME/}"
  elif [[ "$todo_path" == '${HOME}/'* ]]; then
    todo_path="$HOME/${todo_path#\$\{HOME\}/}"
  fi

  if [[ ! -f "$todo_path" ]]; then
    echo "🟠 ERROR: TODO path configured but file does not exist: $todo_path"
    ERRORS=$((ERRORS + 1))
    return
  fi

  # Validate structure: must contain required headers
  local missing=0
  for header in "# ACTIVE TASKS" "# HISTORY" "# DEFERRED" "# METRICS"; do
    if ! grep -q "^${header}" "$todo_path" 2>/dev/null; then
      missing=$((missing + 1))
    fi
  done
  if [[ "$missing" -gt 0 ]]; then
    echo "🟠 ERROR: TODO file missing $missing required headers at $todo_path"
    ERRORS=$((ERRORS + 1))
  fi

  # 24b. Sync conflict file detection
  # Cloud sync services (OneDrive, Dropbox, iCloud) create conflict copies
  # when two machines edit the same file. These are silent data-loss vectors.
  local todo_dir
  todo_dir=$(dirname "$todo_path")
  local todo_basename
  todo_basename=$(basename "$todo_path" .md)
  local conflict_count=0
  local conflict_files=()
  if [[ -d "$todo_dir" ]]; then
    # OneDrive: "TODO - Copy.md", "TODO (1).md"
    # Dropbox: "TODO (conflicted copy 2026-03-28).md"
    # iCloud: "TODO 2.md"
    # Generic: "TODO-conflict-*.md"
    while IFS= read -r -d '' cf; do
      local cfbase
      cfbase=$(basename "$cf")
      # Skip the actual TODO file itself
      [[ "$cfbase" == "$(basename "$todo_path")" ]] && continue
      # Skip known safe files (shadow ring backups)
      [[ "$cfbase" == *.bak ]] && continue
      [[ "$cfbase" == .TODO.md.* ]] && continue
      conflict_files+=("$cfbase")
      conflict_count=$((conflict_count + 1))
    done < <(find "$todo_dir" -maxdepth 1 -type f \( \
      -name "${todo_basename} - Copy*.md" -o \
      -name "${todo_basename} (*.md" -o \
      -name "${todo_basename}-conflict-*.md" -o \
      -name "${todo_basename} [0-9]*.md" \
    \) -print0 2>/dev/null)
  fi
  if [[ "$conflict_count" -gt 0 ]]; then
    echo "🟠 ERROR: Found $conflict_count sync conflict file(s) in $(dirname "$todo_path"):"
    for cf in "${conflict_files[@]}"; do
      echo "   → $cf"
    done
    echo "   Action: review and merge manually, then delete the conflict copies"
    ERRORS=$((ERRORS + 1))
  fi

  # 24c. Stray TODO scanner
  # Agents sometimes create alternate TODO files outside the canonical path.
  # Scan ~/.codex/ for unexpected *TODO*.md files.
  local honeypot_path="$HOME/.codex/TODO.md"
  local stray_count=0
  local stray_files=()
  while IFS= read -r -d '' sf; do
    local sfpath
    sfpath=$(realpath "$sf" 2>/dev/null || echo "$sf")
    # Skip the canonical TODO
    [[ "$sfpath" == "$(realpath "$todo_path" 2>/dev/null || echo "$todo_path")" ]] && continue
    # Skip the honeypot
    [[ "$sfpath" == "$(realpath "$honeypot_path" 2>/dev/null || echo "$honeypot_path")" ]] && continue
    # Skip shadow ring directory contents
    [[ "$sf" == *"/todo-shadow/"* ]] && continue
    # Skip template directory
    [[ "$sf" == *"/templates/"* ]] && continue
    # Skip superpowers repos (contain skill docs referencing TODO)
    [[ "$sf" == *"/superpowers-plus/"* ]] && continue
    [[ "$sf" == *"/superpowers-augment/"* ]] && continue
    stray_files+=("$sf")
    stray_count=$((stray_count + 1))
  done < <(find "$HOME/.codex" -maxdepth 2 -type f -name "*TODO*.md" -print0 2>/dev/null)
  if [[ "$stray_count" -gt 0 ]]; then
    echo "🟡 WARNING: Found $stray_count stray TODO file(s) in ~/.codex/:"
    for sf in "${stray_files[@]}"; do
      echo "   → $sf"
    done
    echo "   These may be from agents bypassing todo-crud.sh"
    WARNINGS=$((WARNINGS + 1))
  fi

  # 24d. Stale claim detection
  # Check for tasks claimed >24h ago (likely abandoned by crashed agents).
  if command -v python3 &>/dev/null; then
    local engine="$REPO_ROOT/tools/todo-engine.py"
    if [[ -f "$engine" ]]; then
      local claims_json
      claims_json=$(python3 "$engine" --json list-claims 2>/dev/null || echo "")
      if [[ -n "$claims_json" ]]; then
        # Parse claims and extract stale ones in a single Python call.
        # Output format: first line = count, remaining lines = details.
        local stale_output
        stale_output=$(echo "$claims_json" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    stale = [c for c in d.get('claims', []) if c.get('age_min', 0) > 1440]
    print(len(stale))
    for c in stale:
        h = round(c['age_min'] / 60, 1)
        print(f\"  → {c['id']}: claimed by {c['agent']} ({h}h ago)\")
except: print('0')
" 2>/dev/null)
        local stale_count
        stale_count=$(echo "$stale_output" | head -1)
        if [[ "${stale_count:-0}" -gt 0 ]]; then
          echo "🟡 WARNING: $stale_count task(s) claimed >24h ago (likely abandoned):"
          echo "$stale_output" | tail -n +2
          echo "   Action: run 'todo-crud.sh reap' to release expired claims"
          WARNINGS=$((WARNINGS + 1))
        fi
      fi
    fi
  fi
}
_doctor_todo_path

# --- Summary ---
# Restore stdout if it was redirected for --summary-only
if [[ "$SUMMARY_ONLY" == "true" ]]; then
  exec 1>&3 3>&-  # Restore stdout from fd 3
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
TOTAL=$((CRITICAL + ERRORS + WARNINGS))
if [[ "$SUMMARY_ONLY" == "true" ]]; then
  if [[ "$TOTAL" -eq 0 ]]; then
    echo "✅ Doctor: all 25 checks passed"
  else
    echo "⚠️  Doctor: $CRITICAL critical · $ERRORS errors · $WARNINGS warnings"
  fi
elif [[ "$TOTAL" -eq 0 ]]; then
  echo "✅ All 25 checks passed. Your superpowers are in perfect health."
else
  echo "  $CRITICAL critical · $ERRORS errors · $WARNINGS warnings"
  echo "  Your superpowers need $TOTAL fixes."
fi
if [[ "$FIX_MODE" == "true" && "$FIXED" -gt 0 ]]; then
  echo "  ✅ Auto-fixed: $FIXED issues"
  echo "  📁 Backups: $BACKUP_DIR"
fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

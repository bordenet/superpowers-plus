#!/usr/bin/env bash
# doctor-checks.sh — Run all 18 superpowers-doctor diagnostic checks
#
# Usage:
#   ./doctor-checks.sh                # Run all checks (report only)
#   ./doctor-checks.sh --fix-safe     # Fix non-destructive issues only (sync, CRLF, BOM)
#   ./doctor-checks.sh --fix          # Fix all auto-fixable issues
#   ./doctor-checks.sh --fix --yes    # Auto-fix without confirmation
#   ./doctor-checks.sh --summary-only # One-line pass/fail (for post-install)

# shellcheck disable=SC2044  # find loops are safe here — skill paths never contain spaces
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tools/compat.sh
source "${SCRIPT_DIR}/compat.sh"
require_bash4

INSTALLED_DIR="$HOME/.codex/skills"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

# Source .env for overlay path (SPC_SOURCE_DIR) and other config
# shellcheck source=/dev/null
[[ -f "$HOME/.codex/.env" ]] && source "$HOME/.codex/.env"

# Fix modes: none < safe < moderate (--fix)
# --fix-safe:  Non-destructive only (sync drift, CRLF, BOM, name mismatch, ref sync)
# --fix:       All fixes including destructive (orphan removal, junk removal, deprecated trigger clear)
FIX_MODE=false
FIX_SAFE=false
SUMMARY_ONLY=false
for arg in "$@"; do
  case "$arg" in
    --fix-safe)     FIX_SAFE=true; FIX_MODE=true ;;
    --fix)          FIX_MODE=true ;;
    --summary-only) SUMMARY_ONLY=true ;;
  esac
done

SP_PLUS_DIR="${SPP_SOURCE_DIR:-$REPO_ROOT}"
SP_OVERLAY_DIR="${SPC_SOURCE_DIR:-}"
SOURCE_DIRS=("$SP_PLUS_DIR")
[[ -n "$SP_OVERLAY_DIR" && -d "$SP_OVERLAY_DIR" ]] && SOURCE_DIRS+=("$SP_OVERLAY_DIR")

BACKUP_DIR="$HOME/.codex/doctor-backups/$(date +%Y-%m-%d_%H-%M-%S)-$$"
FIXED=0; CRITICAL=0; ERRORS=0; WARNINGS=0

# Helper: should we fix this check?
# Safe checks: 3 (name), 9 (drift), 16 (ref drift), 17 (CRLF), 18 (BOM)
# Moderate checks: 8 (orphan), 12 (deprecated), 14 (junk)
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
  cp -PR "$target"/* "$backup_path/" 2>/dev/null || {
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

TOTAL_SKILLS=$(find "$INSTALLED_DIR" -maxdepth 2 -name "skill.md" -not -path "*/references/*" 2>/dev/null | wc -l | tr -d ' ')

# In --summary-only mode, suppress individual findings (redirect to /dev/null)
if [[ "$SUMMARY_ONLY" == "true" ]]; then
  exec 3>&1 1>/dev/null  # Save stdout to fd 3, redirect stdout to /dev/null
fi

echo "🩺 Superpowers Doctor — $TOTAL_SKILLS skills scanned"
echo ""

# --- Pre-check: WSL + NTFS mount detection ---
# On WSL, skills installed under /mnt/c/... are on NTFS where chmod is silently
# ignored and file permissions may not work as expected.
if [[ -f /proc/version ]] && grep -qi "microsoft\|wsl" /proc/version 2>/dev/null; then
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
    if can_fix safe; then
      backup_skill "$(dirname "$f")"
      sed_inplace "s/^name:.*$/name: $dir_name/" "$f"
      echo "  ✅ FIXED: name → '$dir_name'"; ((FIXED++))
    fi
  fi
done

# --- Check 4: Duplicate Skill Names ---
# Skills with "overrides:" in YAML frontmatter are intentional overlays, not duplicates.
declare -A seen_skills
for dir in "${SOURCE_DIRS[@]}"; do
  search_root="$dir"; [[ -d "$dir/skills" ]] && search_root="$dir/skills"
  for skill_dir in $(find "$search_root" -name "skill.md" -not -path "*/references/*" -exec dirname {} \; 2>/dev/null); do
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
  done
done

# --- Check 5: Broken Internal References ---
# Skips: fenced code blocks, directory tree diagrams, and inline prose mentions.
# For examples.md/reference.md: only flags action directives (See/Read/Load/view/link syntax).
# For references/*.md and modules/*.md: flags any non-code-block mention.
for f in $(find "$INSTALLED_DIR" -maxdepth 2 -name "skill.md" -not -path "*/references/*" 2>/dev/null); do
  skill=$(basename "$(dirname "$f")"); skill_dir=$(dirname "$f")
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
    if can_fix moderate; then
      backup_skill "$installed"; rm -rf "$installed"
      echo "  ✅ FIXED: removed orphan $skill"; ((FIXED++))
    fi
  fi
done

# --- Check 9: Source-Install Content Drift ---
# Tracks priority source (overlay wins over base) AND base source for overlay-aware comparison.
declare -A PRIORITY_SOURCE
declare -A BASE_SOURCE
for dir in "$SP_PLUS_DIR" ${SP_OVERLAY_DIR:+"$SP_OVERLAY_DIR"}; do
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
      backup_skill "$(dirname "$installed")"; cp "$src" "$installed"
      echo "  ✅ FIXED: synced $skill"; ((FIXED++))
    fi
  fi
done

# --- Check 10: Missing Triggers ---
VALIDATOR="$SP_PLUS_DIR/tools/skill-trigger-validator.sh"
EXPLICIT_LIST=""
[[ -f "$VALIDATOR" ]] && EXPLICIT_LIST=$(grep -A50 "^EXPLICIT_SKILLS=" "$VALIDATOR" 2>/dev/null | grep '^\s*"' | sed 's/#.*//' | tr -d ' "' || echo "")
for f in $(find "$INSTALLED_DIR" -maxdepth 2 -name "skill.md" -not -path "*/references/*" 2>/dev/null); do
  skill=$(basename "$(dirname "$f")")
  yaml_block=$(awk 'NR==1 && /^---$/{found++; next} /^---$/{exit} found{print}' "$f")
  has_triggers=$(echo "$yaml_block" | grep "^triggers:" | grep -v 'triggers: \[\]' | grep -v 'triggers:$' || true)
  if [[ -z "$has_triggers" ]] && ! echo "$EXPLICIT_LIST" | grep -q "^${skill}$"; then
    echo "🟡 WARNING: $skill — no triggers and not in EXPLICIT_SKILLS"; ((WARNINGS++))
  fi
done

# --- Check 11: Trigger Overlap ---
# Known collision groups: skills that intentionally share triggers.
# Collisions within a group are expected and suppressed.
KNOWN_COLLISION_GROUPS=(
  # Hub→child: thinking-orchestrator delegates to specialized skills
  "thinking-orchestrator adversarial-search think-twice completeness-check verification-before-completion exhaustive-audit-validation providing-code-review"
  # Generic→Linear: platform-agnostic vs Linear-specific pairs
  "issue-editing linear-issue-editing"
  "issue-authoring linear-issue-authoring"
  "issue-comment-debunker linear-comment-debunker"
  "issue-link-verification linear-link-verification"
  "issue-verify linear-issue-verify"
  # Detect→Fix: complementary slop detection and elimination
  "detecting-ai-slop eliminating-ai-slop"
  # Pre-commit chain: ordered sequential checks before commit
  "professional-language-audit pre-commit-gate enforce-style-guide"
  # Wiki pipeline: orchestration, editing, verification
  "wiki-editing outline-wiki-editing wiki-orchestrator link-verification"
  # Resume screening: generic vs source-specific
  "resume-screening cv-review-external"
  # PR verification: complementary pre-PR checks
  "holistic-repo-verification engineering-rigor"
  # Meeting notes: fetching recordings vs writing prose
  "fathom-meeting-notes eliminating-ai-slop"
  # Security: vulnerability scanning vs repo secret scanning
  "security-upgrade repo-security-scan"
)

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
for f in $(find "$INSTALLED_DIR" -maxdepth 2 -name "skill.md" -not -path "*/references/*" 2>/dev/null); do
  skill=$(basename "$(dirname "$f")")
  triggers=$(awk 'NR==1 && /^---$/{found++; next} /^---$/{exit} found{print}' "$f" | grep "^triggers:" | \
    sed 's/triggers://' | tr -d '[]' | tr ',' '\n' | sed 's/^[[:space:]]*"//;s/"[[:space:]]*$//' | grep -v '^$' || true)
  while IFS= read -r trigger; do
    [[ -z "$trigger" ]] && continue
    lt=$(echo "$trigger" | tr '[:upper:]' '[:lower:]')
    if [[ -n "${trigger_map[$lt]:-}" ]]; then
      existing="${trigger_map[$lt]}"
      # Skip self-collisions (same skill, case-insensitive trigger variants)
      if [[ "$existing" == "$skill" ]]; then
        continue
      fi
      # Check if all colliding skills are in the same known group
      all_known=true
      for prev_skill in $(echo "$existing" | tr ',' '\n' | sed 's/^[[:space:]]*//'); do
        if ! in_same_group "$prev_skill" "$skill"; then
          all_known=false; break
        fi
      done
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
for f in $(find "$INSTALLED_DIR" -maxdepth 2 -name "skill.md" -not -path "*/references/*" 2>/dev/null); do
  skill=$(basename "$(dirname "$f")")
  yaml_block=$(awk 'NR==1 && /^---$/{found++; next} /^---$/{exit} found{print}' "$f")
  # Check frontmatter for deprecated: true
  is_deprecated=false
  echo "$yaml_block" | grep -qi "^deprecated:" && is_deprecated=true
  # Check first 10 lines after frontmatter for prominent deprecation markers
  if [[ "$is_deprecated" == "false" ]]; then
    body_start=$(awk 'NR==1 && /^---$/{found++; next} /^---$/{found++; print NR; exit}' "$f")
    [[ -n "$body_start" ]] && head -n $((body_start + 10)) "$f" | tail -n 10 | grep -qiE '^\s*>.*deprecated|^#.*deprecated|replaced by|superseded by' && is_deprecated=true
  fi
  if [[ "$is_deprecated" == "true" ]]; then
    has_triggers=$(echo "$yaml_block" | grep "^triggers:" | grep -v 'triggers: \[\]' || true)
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
for f in $(find "$INSTALLED_DIR" -maxdepth 2 -name "skill.md" -not -path "*/references/*" 2>/dev/null); do
  skill=$(basename "$(dirname "$f")")
  # Extract all lines with paths, excluding doctor-ignore lines and code blocks
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    echo "$line" | grep -qi "doctor-ignore" && continue
    while read -r path; do
      [[ -z "$path" ]] && continue
      expanded=$(eval echo "$path" 2>/dev/null || echo "$path")
      [[ ! -e "$expanded" ]] && { echo "🟡 WARNING: $skill — path '$path' does not exist"; ((WARNINGS++)); }
    done < <(echo "$line" | grep -oE '(~/[a-zA-Z0-9_./-]+|/Users/[a-zA-Z0-9_./-]+)')
  done < <(grep -E '(~/[a-zA-Z0-9_./-]+|/Users/[a-zA-Z0-9_./-]+)' "$f" 2>/dev/null)
done

# --- Check 14: Junk Files ---
for dir in "${SOURCE_DIRS[@]}"; do
  root="${dir%/skills}"
  while IFS= read -r junk; do
    [[ -z "$junk" ]] && continue
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
for f in $(find "$INSTALLED_DIR" -maxdepth 2 -name "skill.md" -not -path "*/references/*" 2>/dev/null); do
  skill=$(basename "$(dirname "$f")"); issues=""
  grep -qi "when to use\|when to invoke" "$f" || issues="${issues}missing 'When to Use'; "
  grep -q '```' "$f" || issues="${issues}no code examples; "
  grep -qi "failure\|fix:\|recovery\|troubleshoot" "$f" || issues="${issues}no failure modes; "
  [[ -n "$issues" ]] && echo "🔵 INFO: $skill — $issues"
done

# --- Check 16: Reference File Integrity ---
# Track which reference files come from overlay vs base for overlay-aware comparison.
declare -A REF_PRIORITY
declare -A REF_IS_OVERLAY_ONLY  # Track refs that only exist in overlay, not base
declare -A REF_IS_BASE_ONLY     # Track refs that only exist in base, not overlay
declare -A OVERLAY_SOURCE       # Track overlay skill.md paths for comparison
for dir in "$SP_PLUS_DIR" ${SP_OVERLAY_DIR:+"$SP_OVERLAY_DIR"}; do
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
      mkdir -p "$(dirname "$installed_ref")"; cp "$src_ref" "$installed_ref"
      echo "  ✅ FIXED: created $skill_dir/references/$ref_name"; ((FIXED++))
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
      backup_skill "$INSTALLED_DIR/$skill_dir"; cp "$src_ref" "$installed_ref"
      echo "  ✅ FIXED: synced $skill_dir/references/$ref_name"; ((FIXED++))
    fi
  fi
done

# --- Check 17: CRLF Line Ending Detection ---
for f in $(find "$INSTALLED_DIR" -maxdepth 2 -name "skill.md" -not -path "*/references/*" 2>/dev/null); do
  skill=$(basename "$(dirname "$f")")
  if grep -q $'\r' "$f" 2>/dev/null; then
    echo "🟠 ERROR: $skill — CRLF line endings detected"; ((ERRORS++))
    if can_fix safe; then
      backup_skill "$(dirname "$f")" || continue
      sed_inplace 's/\r$//' "$f"
      echo "  ✅ FIXED: converted $skill to LF"; ((FIXED++))
    fi
  fi
done
# Also check reference files
for f in $(find "$INSTALLED_DIR" -maxdepth 3 -path "*/references/*.md" 2>/dev/null); do
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
done

# --- Check 18: UTF-8 BOM Detection ---
for f in $(find "$INSTALLED_DIR" -maxdepth 2 -name "skill.md" -not -path "*/references/*" 2>/dev/null); do
  skill=$(basename "$(dirname "$f")")
  # Check for BOM bytes (EF BB BF) at start of file
  if [[ "$(xxd -l 3 -p "$f" 2>/dev/null)" == "efbbbf" ]]; then
    echo "🟡 WARNING: $skill — UTF-8 BOM detected (breaks YAML parsing)"; ((WARNINGS++))
    if can_fix safe; then
      backup_skill "$(dirname "$f")" || continue
      # Strip BOM: skip first 3 bytes
      tail -c +4 "$f" > "$f.tmp" && mv "$f.tmp" "$f"
      echo "  ✅ FIXED: stripped BOM from $skill"; ((FIXED++))
    fi
  fi
done

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
    echo "✅ Doctor: all 18 checks passed"
  else
    echo "⚠️  Doctor: $CRITICAL critical · $ERRORS errors · $WARNINGS warnings"
  fi
elif [[ "$TOTAL" -eq 0 ]]; then
  echo "✅ All 18 checks passed. Your superpowers are in perfect health."
else
  echo "  $CRITICAL critical · $ERRORS errors · $WARNINGS warnings"
  echo "  Your superpowers need $TOTAL fixes."
fi
if [[ "$FIX_MODE" == "true" && "$FIXED" -gt 0 ]]; then
  echo "  ✅ Auto-fixed: $FIXED issues"
  echo "  📁 Backups: $BACKUP_DIR"
fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

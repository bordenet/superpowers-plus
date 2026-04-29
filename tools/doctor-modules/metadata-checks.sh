# shellcheck shell=bash
# doctor-modules/metadata-checks.sh — sourced by doctor-checks.sh
# All global state (CRITICAL, ERRORS, WARNINGS, FIXED, SKILL_*, FIX_MODE, etc.)
# is inherited from the parent script.

_doctor_metadata_checks() {
# --- Check 6: Oversized Skills ---
for skill in "${!SKILL_LINES[@]}"; do
  [[ "${SKILL_LINES[$skill]}" -gt 250 ]] && { echo "🟠 ERROR: $skill — ${SKILL_LINES[$skill]} lines (limit: 250)"; ((ERRORS++)); }
done

# --- Check 8: Orphaned Installs ---
# Demoted from ERROR+auto-fix to WARNING+report-only (2026-03-25).
# Reason: locally-created skills that haven't been committed to a source repo yet
# were being silently deleted. This destroyed wiki-editing skills and their
# API access patterns, causing agents to give up on wiki access entirely.
# Use --purge-orphans to explicitly opt into orphan removal.
#
# Alias-aware (2026-04-29): skills that install under a /sp* trigger name (e.g. sp-review
# from providing-code-review) are in DEST_NAMES_SET with their alias as the key.
# Using DEST_NAMES_SET avoids false-positive orphan reports for legitimately aliased installs.
while IFS= read -r installed; do
  skill=$(basename "$installed")
  [[ "$skill" == "_shared" || "$skill" == "doctor-backups" ]] && continue
  if [[ -z "${DEST_NAMES_SET[$skill]:-}" ]]; then
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
# Alias-aware (2026-04-29): keys are dest names (e.g. sp-brainstorm) not source names
# (brainstorming) so that the installed path $INSTALLED_DIR/$dest/skill.md is found correctly.
declare -A PRIORITY_SOURCE
# BASE_SOURCE is declared globally in doctor-checks.sh; just populate it here.
for dir in "${COMPARE_DIRS[@]}"; do
  search_root="$dir"; [[ -d "$dir/skills" ]] && search_root="$dir/skills"
  while IFS= read -r src; do
    src_skill=$(basename "$(dirname "$src")")
    # Compute the actual install dest name (e.g. sp-brainstorm for brainstorming source)
    dest_skill="${SOURCE_DEST_NAME[$src_skill]:-$src_skill}"
    # If this is the base (plus) dir, record it separately
    if [[ "$dir" == "$SP_PLUS_DIR" ]]; then
      BASE_SOURCE["$dest_skill"]="$src"
    fi
    PRIORITY_SOURCE[$dest_skill]="$src"
  done < <(find "$search_root" -name "skill.md" -not -path "*/references/*" -not -path "*/.worktrees/*" 2>/dev/null)
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

# --- Check: Missing Composition Metadata ---
for skill in "${!SKILL_YAML[@]}"; do
  if ! grep -q '^composition:' <<< "${SKILL_YAML[$skill]}"; then
    echo "🟡 WARNING: $skill — missing composition metadata"
    ((WARNINGS++))
  fi
done

}

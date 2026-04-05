# shellcheck shell=bash
# doctor-modules/reference-checks.sh — sourced by doctor-checks.sh
# All global state (CRITICAL, ERRORS, WARNINGS, FIXED, SKILL_*, FIX_MODE, etc.)
# is inherited from the parent script.

_doctor_reference_checks() {
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

}

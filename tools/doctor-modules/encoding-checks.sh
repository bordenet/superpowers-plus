# shellcheck shell=bash
# doctor-modules/encoding-checks.sh — sourced by doctor-checks.sh
# All global state (CRITICAL, ERRORS, WARNINGS, FIXED, SKILL_*, FIX_MODE, etc.)
# is inherited from the parent script.

_doctor_encoding_checks() {
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
  # Extract skill name and ref filename using bash string ops (no subprocess forks).
  _ref_parent="${f%/references/*}"; skill="${_ref_parent##*/}"; ref_name="${f##*/}"
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


}

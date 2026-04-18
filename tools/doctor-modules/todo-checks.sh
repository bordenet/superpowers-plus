# shellcheck shell=bash
# doctor-modules/todo-checks.sh — sourced by doctor-checks.sh
# All global state (CRITICAL, ERRORS, WARNINGS, FIXED, SKILL_*, FIX_MODE, etc.)
# is inherited from the parent script.

_doctor_todo_checks() {
# --- Check 22: TODO Archive Smoke Test ---
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
    # Cleanup helper: unprotect protected files before removing fixture dir.
    # todo-engine.py sets chmod 444 (and possibly chflags uchg) on TODO.md.
    _smoke_cleanup() {
      local root="${1:?}"
      find "$root" -name "*.md" -exec chmod u+w {} \; 2>/dev/null || true
      if command -v chflags &>/dev/null; then
        find "$root" -name "*.md" -exec chflags nouchg {} \; 2>/dev/null || true
      fi
      rm -rf "${root:?}"
    }
    # Run maintenance in JSON mode against the fixture
    if ! result_json=$(HOME="$fixture_root/home" "$BASH" "$MAINT_SCRIPT" --json 2>&1); then
      echo "🟠 ERROR: TODO archive smoke test — maintenance script failed"
      echo "   Output: $(echo "$result_json" | head -3)"
      ((ERRORS++))
      _smoke_cleanup "$fixture_root"
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
      _smoke_cleanup "$fixture_root"
      return
    fi
    # Validate: resulting file should be under 50 lines (small TODO regression check)
    line_count=$(wc -l < "$fixture_todo" | tr -d ' ')
    if (( line_count >= 50 )); then
      echo "🟠 ERROR: TODO archive smoke test — result is $line_count lines (expected <50)"
      ((ERRORS++))
      _smoke_cleanup "$fixture_root"
      return
    fi
    # Validate: active task survived
    if ! grep -q '\[20260322-01\]' "$fixture_todo"; then
      echo "🟠 ERROR: TODO archive smoke test — active task was lost during archive"
      ((ERRORS++))
      _smoke_cleanup "$fixture_root"
      return
    fi
    _smoke_cleanup "$fixture_root"
  }
  _doctor_todo_smoke
fi

# --- Check 24: TODO Honeypot Integrity ---
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

# --- Check 25: TODO Path Validation ---
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

}

#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Script: todo-preflight.sh
# PURPOSE: Single-command TODO.md file path resolution and validation.
#          Used for read-only path queries and initial file creation
#          (--create-if-missing). CRUD operations use todo-crud.sh, which
#          handles preflight internally.
# USAGE: ./todo-preflight.sh [--json] [--create-if-missing]
#        --json               Output machine-readable JSON (default: human-readable)
#        --create-if-missing  Create TODO.md from template if file doesn't exist
# PLATFORM: macOS, Linux, WSL (POSIX-compatible)
# VERSION: 1.0.0
# -----------------------------------------------------------------------------
set -euo pipefail

# --- Bash Guard ---
if [ -z "${BASH_VERSION:-}" ]; then
    echo "ERROR: This script requires bash. Run with: bash $0" >&2
    exit 1
fi

JSON_MODE=false
CREATE_IF_MISSING=false
DIAGNOSE=false

for arg in "$@"; do
  case "$arg" in
    --json) JSON_MODE=true ;;
    --create-if-missing) CREATE_IF_MISSING=true ;;
    --diagnose) DIAGNOSE=true ;;
    --help|-h)
      echo "Usage: todo-preflight.sh [--json] [--create-if-missing] [--diagnose]"
      echo ""
      echo "Resolves TODO_FILE_PATH from ~/.codex/.env and validates the file."
      echo ""
      echo "Options:"
      echo "  --json               Output JSON (for machine consumption)"
      echo "  --create-if-missing  Create TODO.md from template if not found"
      echo "  --diagnose           Full diagnostic: path, permissions, shadow, stray detection"
      exit 0
      ;;
    *)
      echo "Unknown option: $arg" >&2
      exit 1
      ;;
  esac
done

# Step 1-2: Source environment and resolve path (shared utility)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=resolve-env-path.sh
source "$SCRIPT_DIR/resolve-env-path.sh"
resolve_env
# Note: don't use $() — it creates a subshell and loses RESOLVE_SOURCE
TODO_PATH=$(resolve_path "TODO_FILE_PATH" "$HOME/.codex/TODO.md")
# Re-call resolve_path to set RESOLVE_SOURCE in the current shell
# (the $() subshell above ate it)
resolve_path "TODO_FILE_PATH" "$HOME/.codex/TODO.md" > /dev/null

# Step 3: Check file existence
FILE_EXISTS=false
FILE_SIZE=0
if [[ -f "$TODO_PATH" ]]; then
  FILE_EXISTS=true
  FILE_SIZE=$(wc -c < "$TODO_PATH" 2>/dev/null | tr -d ' ')
fi

# Step 4: Create if missing and requested
CREATED=false
if [[ "$FILE_EXISTS" == "false" && "$CREATE_IF_MISSING" == "true" ]]; then
  mkdir -p "$(dirname "$TODO_PATH")"
  cat > "$TODO_PATH" << 'TEMPLATE'
# ACTIVE TASKS

## P1 - Today

## P2 - This Week

## P3 - Backlog

---

# HISTORY

---

# DEFERRED

---

# METRICS
TEMPLATE
  # Protect the new file — only todo-engine.py can write to it
  chmod 0444 "$TODO_PATH"
  FILE_EXISTS=true
  CREATED=true
  FILE_SIZE=$(wc -c < "$TODO_PATH" 2>/dev/null | tr -d ' ')
fi

# Step 5: Output results
if [[ "$JSON_MODE" == "true" ]]; then
  cat << EOF
{"todo_path":"$TODO_PATH","file_exists":$FILE_EXISTS,"file_size":$FILE_SIZE,"env_sourced":$ENV_SOURCED,"created":$CREATED,"source":"${RESOLVE_SOURCE:-unknown}"}
EOF
else
  echo "TODO_PATH=$TODO_PATH"
  echo "FILE_EXISTS=$FILE_EXISTS"
  echo "FILE_SIZE=$FILE_SIZE"
  echo "ENV_SOURCED=$ENV_SOURCED"
  echo "CREATED=$CREATED"
  echo "SOURCE=${RESOLVE_SOURCE:-unknown}"
  if [[ "$FILE_EXISTS" == "false" ]]; then
    echo ""
    echo "ERROR: TODO.md does not exist at $TODO_PATH"
    echo "FIX: Run with --create-if-missing, or create the file manually"
    exit 1
  fi
fi


# --- Diagnose mode ---
if [[ "$DIAGNOSE" == "true" ]]; then
  echo ""
  echo "=== TODO.md Diagnostic Report ==="
  echo "Canonical path: $TODO_PATH"
  echo "Source: ${RESOLVE_SOURCE:-unknown} (priority: registry > env > default)"
  echo "File exists: $FILE_EXISTS"
  if [[ "$FILE_EXISTS" == "true" ]]; then
    PERMS=$(stat -f '%Lp' "$TODO_PATH" 2>/dev/null || stat -c '%a' "$TODO_PATH" 2>/dev/null)
    echo "Permissions: $PERMS"

    # Check immutable flag (macOS chflags uchg)
    IMMUTABLE="unknown"
    if [[ "$(uname)" == "Darwin" ]]; then
      # shellcheck disable=SC2312
      if (( $(stat -f '%f' "$TODO_PATH" 2>/dev/null) & 2 )); then
        IMMUTABLE="✅ IMMUTABLE (chflags uchg — Operation not permitted for all writes)"
      else
        IMMUTABLE="⚠️  NOT IMMUTABLE — chflags uchg not set"
      fi
    elif [[ "$(uname)" == "Linux" ]]; then
      if lsattr "$TODO_PATH" 2>/dev/null | grep -q "i"; then
        IMMUTABLE="✅ IMMUTABLE (chattr +i)"
      else
        IMMUTABLE="⚠️  NOT IMMUTABLE — chattr +i not set (may require sudo)"
      fi
    fi
    echo "Immutability: $IMMUTABLE"

    if [[ "$PERMS" == "444" ]]; then
      echo "chmod: ✅ PROTECTED (read-only)"
    elif [[ "$PERMS" == "644" ]]; then
      echo "chmod: ⚠️  WRITABLE — file left unprotected (possible incomplete write)"
    else
      echo "chmod: ❓ UNEXPECTED permissions: $PERMS"
    fi
    echo "File size: ${FILE_SIZE} bytes"
  fi

  # Shadow ring check
  SHADOW_DIR="$HOME/.codex/todo-shadow"
  echo ""
  echo "--- Shadow Ring Buffer ---"
  for i in 1 2 3 4 5; do
    SLOT="$SHADOW_DIR/TODO.shadow.${i}.md"
    if [[ -f "$SLOT" ]]; then
      SLOT_SIZE=$(wc -c < "$SLOT" 2>/dev/null | tr -d ' ')
      echo "  Slot $i: ✅ ($SLOT_SIZE bytes)"
    else
      echo "  Slot $i: ❌ (empty)"
    fi
  done
  # Legacy single shadow
  LEGACY_SHADOW="$SHADOW_DIR/TODO.md"
  if [[ -f "$LEGACY_SHADOW" ]]; then
    LEGACY_SIZE=$(wc -c < "$LEGACY_SHADOW" 2>/dev/null | tr -d ' ')
    echo "  Legacy shadow: ⚠️  ($LEGACY_SIZE bytes — will migrate to slot 1 on next write)"
  fi

  # Timed snapshots
  echo ""
  echo "--- Timed Snapshots ---"
  TIMED_COUNT=$(find "$SHADOW_DIR" -name "TODO.timed.*.md" 2>/dev/null | wc -l | tr -d ' ')
  echo "  Count: $TIMED_COUNT / 5 max"
  if [[ "$TIMED_COUNT" -gt 0 ]]; then
    # shellcheck disable=SC2012
    NEWEST_TIMED=$(ls -t "$SHADOW_DIR"/TODO.timed.*.md 2>/dev/null | head -1)
    if [[ -n "$NEWEST_TIMED" ]]; then
      echo "  Newest: $(basename "$NEWEST_TIMED")"
    fi
  fi

  # Honeypot / stray file detection
  echo ""
  DEFAULT_PATH="$HOME/.codex/TODO.md"
  REAL_CANONICAL=$(realpath "$TODO_PATH" 2>/dev/null || echo "$TODO_PATH")
  REAL_DEFAULT=$(realpath "$DEFAULT_PATH" 2>/dev/null || echo "$DEFAULT_PATH")
  if [[ "$REAL_CANONICAL" != "$REAL_DEFAULT" && -f "$DEFAULT_PATH" ]]; then
    # Check if it's our honeypot or a stray
    if grep -q "THIS IS NOT THE REAL TODO FILE" "$DEFAULT_PATH" 2>/dev/null; then
      echo "Honeypot: ✅ Deployed at $DEFAULT_PATH"
      if [[ "$(uname)" == "Darwin" ]]; then
        # shellcheck disable=SC2312
        if (( $(stat -f '%f' "$DEFAULT_PATH" 2>/dev/null) & 2 )); then
          echo "  Honeypot immutable: ✅ (chflags uchg)"
        else
          echo "  Honeypot immutable: ⚠️  NOT LOCKED — run: chflags uchg $DEFAULT_PATH"
        fi
      elif [[ "$(uname)" == "Linux" ]]; then
        if lsattr "$DEFAULT_PATH" 2>/dev/null | grep -q "i"; then
          echo "  Honeypot immutable: ✅ (chattr +i)"
        else
          echo "  Honeypot immutable: ⚠️  NOT LOCKED — run: sudo chattr +i $DEFAULT_PATH"
        fi
      else
        echo "  Honeypot immutable: ℹ️  (immutability check not available on this platform)"
      fi
    else
      echo "🚨 STRAY TODO.md DETECTED: $DEFAULT_PATH"
      STRAY_SIZE=$(wc -c < "$DEFAULT_PATH" 2>/dev/null | tr -d ' ')
      echo "   Size: $STRAY_SIZE bytes (NOT a honeypot — contains real content)"
      echo "   ACTION: Review contents, merge anything valuable, then replace with honeypot"
    fi
  else
    echo "Stray detection: ✅ No stray TODO.md files found"
  fi
  echo "=== End Diagnostic ==="
fi

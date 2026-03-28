#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Script: todo-crud.sh
# PURPOSE: Shell entrypoint for TODO.md CRUD operations. Validates environment
#          and delegates to todo-engine.py for cross-platform safe file ops.
#
# USAGE:
#   todo-crud.sh add --priority P3 --description "Build feature" --tags "#eng"
#   todo-crud.sh complete --id 20260322-01 --note "Shipped"
#   todo-crud.sh move --id 20260322-01 --to P1
#   todo-crud.sh list [--priority P1] [--tag "#plan-foo"] [--all]
#   todo-crud.sh next-id
#   todo-crud.sh defer --id 20260322-01 --reason "Blocked"
#   todo-crud.sh claim --id 20260322-01 [--agent myagent] [--ttl 30]
#   todo-crud.sh unclaim --id 20260322-01
#   todo-crud.sh reap
#   todo-crud.sh --json <subcommand> [args]   # JSON output mode
#
# PLATFORM: macOS, Linux, WSL (requires Python 3.6+)
# VERSION: 1.0.0
# -----------------------------------------------------------------------------
set -euo pipefail

# --- Bash Guard ---
if [ -z "${BASH_VERSION:-}" ]; then
    echo "ERROR: This script requires bash. Run with: bash $0" >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tools/compat.sh
source "${SCRIPT_DIR}/compat.sh"
ENGINE="$SCRIPT_DIR/todo-engine.py"

# --- Help ---
show_help() {
  cat << 'EOF'
Usage: todo-crud.sh [--json] <command> [options]

Commands:
  cat        Print TODO.md contents (resolved path — use this to READ)
  path       Print resolved TODO.md path
  add        Add a new task
  complete   Mark a task as done (moves to HISTORY)
  move       Move a task to a different priority
  list       List/filter tasks
  next-id    Get next available task ID for today
  defer      Defer a task (moves to DEFERRED)
  claim      Claim a task for this agent (multi-agent coordination)
  unclaim    Release a claim on a task
  reap       Reap all expired claims (reverts to open)
  self-test  Validate honeypot integrity, TODO path, and engine health

Global Options:
  --json     Machine-readable JSON output

Add Options:
  --priority, -p    P1, P2, or P3 (default: P2)
  --description, -d Task description (required)
  --tags, -t        Space-separated tags (e.g., "#eng #plan-foo")
  --note, -n        Additional note

Complete Options:
  --id              Task ID to complete (required)
  --note, -n        Completion note

Move Options:
  --id              Task ID to move (required)
  --to              Target priority P1/P2/P3 (required)

List Options:
  --priority, -p    Filter by priority
  --tag, -t         Filter by tag
  --all             Include history and deferred

Defer Options:
  --id              Task ID to defer (required)
  --reason, -r      Reason for deferral

Claim Options:
  --id              Task ID to claim (required)
  --agent, -a       Agent identifier (default: AGENT_ID env or hostname:ppid)
  --ttl             Claim TTL in minutes (default: 30)

Unclaim Options:
  --id              Task ID to unclaim (required)

Environment:
  TODO_FILE_PATH    Path to TODO.md (from ~/.codex/.env)

Examples:
  todo-crud.sh add -p P3 -d "Build feature X" -t "#engineering #plan-feat-x"
  todo-crud.sh complete --id 20260322-01
  todo-crud.sh list -p P1
  todo-crud.sh --json list --all
  todo-crud.sh claim --id 20260322-01 --agent "augment-session-1" --ttl 30
  todo-crud.sh unclaim --id 20260322-01
  todo-crud.sh reap
EOF
}

# --- Validate Python ---
PYTHON=""
for candidate in python3 python; do
  if command -v "$candidate" &>/dev/null; then
    PYTHON="$candidate"
    break
  fi
done

if [[ -z "$PYTHON" ]]; then
  echo "ERROR: Python 3 is required but not found. Install python3." >&2
  exit 1
fi

# Verify Python version >= 3.6
PY_VERSION=$("$PYTHON" -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')" 2>/dev/null || echo "0.0")
PY_MAJOR="${PY_VERSION%%.*}"
PY_MINOR="${PY_VERSION#*.}"
if [[ "$PY_MAJOR" -lt 3 || ("$PY_MAJOR" -eq 3 && "$PY_MINOR" -lt 6) ]]; then
  echo "ERROR: Python 3.6+ required, found $PY_VERSION" >&2
  exit 1
fi

# --- Validate engine exists ---
if [[ ! -f "$ENGINE" ]]; then
  echo "ERROR: todo-engine.py not found at $ENGINE" >&2
  exit 1
fi

# --- Path resolution ---
# The engine reads ~/.codex/.todo-registry for the TODO.md path.
# We only source .env for other env vars the engine might need.
# DO NOT export TODO_FILE_PATH here — let the engine resolve it.
if [[ -f "$HOME/.codex/.env" ]]; then
  # shellcheck source=/dev/null
  source "$HOME/.codex/.env" 2>/dev/null || true
fi

# --- Honeypot Sentinel ---
# The canonical honeypot content at ~/.codex/TODO.md. Used by self-test and
# doctor checks to verify the honeypot hasn't been tampered with.
HONEYPOT_PATH="$HOME/.codex/TODO.md"
HONEYPOT_EXPECTED_CONTENT='# 🚨 STOP — WRONG FILE 🚨
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

# --- Self-Test ---
# Validates: honeypot integrity, real TODO path resolution, registry health.
self_test() {
  local passed=0 failed=0 warnings=0

  echo "🧪 todo-crud self-test"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  # 1. Check real TODO path resolves
  local real_path
  real_path=$("$PYTHON" "$ENGINE" path 2>/dev/null)
  if [[ -n "$real_path" ]]; then
    echo "✅ TODO path resolves: $real_path"
    passed=$((passed + 1))
  else
    echo "❌ TODO path resolution FAILED"
    failed=$((failed + 1))
  fi

  # 2. Check real TODO file exists and is writable by engine
  if [[ -n "$real_path" && -f "$real_path" ]]; then
    echo "✅ TODO file exists"
    passed=$((passed + 1))
  elif [[ -n "$real_path" ]]; then
    echo "❌ TODO file does not exist at $real_path"
    failed=$((failed + 1))
  fi

  # 3. Check .todo-registry exists
  local registry="$HOME/.codex/.todo-registry"
  if [[ -f "$registry" ]]; then
    local reg_content
    reg_content=$(cat "$registry")
    if [[ -n "$reg_content" ]]; then
      echo "✅ .todo-registry exists and is non-empty"
      passed=$((passed + 1))
    else
      echo "❌ .todo-registry exists but is empty"
      failed=$((failed + 1))
    fi
  else
    echo "⚠️  .todo-registry not found (using fallback path resolution)"
    warnings=$((warnings + 1))
  fi

  # Honeypot checks (4-7): only applicable when TODO lives OUTSIDE ~/.codex/TODO.md.
  # If the user's real TODO IS at ~/.codex/TODO.md, there's no honeypot — that IS
  # their working file. The honeypot is an optional defense for users who store
  # TODO elsewhere (e.g., OneDrive, Dropbox, a shared repo).
  local real_canonical
  real_canonical=$(realpath "$real_path" 2>/dev/null || readlink -f "$real_path" 2>/dev/null || echo "$real_path")
  local honeypot_canonical
  honeypot_canonical=$(realpath "$HONEYPOT_PATH" 2>/dev/null || readlink -f "$HONEYPOT_PATH" 2>/dev/null || echo "$HONEYPOT_PATH")

  if [[ -n "$real_path" && "$real_canonical" == "$honeypot_canonical" ]]; then
    echo "ℹ️  Honeypot checks skipped — TODO lives at $HONEYPOT_PATH (no honeypot needed)"
  else
    # 4. Check honeypot exists
    if [[ -f "$HONEYPOT_PATH" ]]; then
      echo "✅ Honeypot file exists at $HONEYPOT_PATH"
      passed=$((passed + 1))
    else
      echo "⚠️  Honeypot file not found at $HONEYPOT_PATH (optional — deploy with install.sh)"
      warnings=$((warnings + 1))
    fi

    # 5. Check honeypot has immutable flag (portable via compat.sh)
    if [[ -f "$HONEYPOT_PATH" ]]; then
      check_immutable "$HONEYPOT_PATH"
      local immutable_result=$?
      if [[ "$immutable_result" -eq 0 ]]; then
        echo "✅ Honeypot has immutable flag"
        passed=$((passed + 1))
      elif [[ "$immutable_result" -eq 2 ]]; then
        echo "⚠️  Cannot verify immutable flag on this platform/filesystem"
        warnings=$((warnings + 1))
      else
        if [[ "$OSTYPE" == "darwin"* ]]; then
          echo "❌ Honeypot MISSING immutable flag (run: chflags uchg $HONEYPOT_PATH)"
        else
          echo "❌ Honeypot MISSING immutable flag (run: sudo chattr +i $HONEYPOT_PATH)"
        fi
        failed=$((failed + 1))
      fi
    fi

    # 6. Check honeypot permissions are 444
    if [[ -f "$HONEYPOT_PATH" ]]; then
      local perms
      perms=$(stat -f "%Lp" "$HONEYPOT_PATH" 2>/dev/null || stat -c "%a" "$HONEYPOT_PATH" 2>/dev/null || echo "")
      if [[ "$perms" == "444" ]]; then
        echo "✅ Honeypot permissions are 444 (read-only)"
        passed=$((passed + 1))
      else
        echo "❌ Honeypot permissions are $perms (expected 444)"
        failed=$((failed + 1))
      fi
    fi

    # 7. Check honeypot content matches expected (portable via compat.sh)
    if [[ -f "$HONEYPOT_PATH" ]]; then
      local actual_hash expected_hash
      actual_hash=$(sha256_hash "$HONEYPOT_PATH")
      expected_hash=$(printf '%s' "$HONEYPOT_EXPECTED_CONTENT" | sha256_hash_stdin)
      if [[ "$actual_hash" == "$expected_hash" ]]; then
        echo "✅ Honeypot content matches expected sentinel"
        passed=$((passed + 1))
      else
        echo "❌ Honeypot content has been TAMPERED WITH"
        echo "   Expected sha256: $expected_hash"
        echo "   Actual sha256:   $actual_hash"
        failed=$((failed + 1))
      fi
    fi
  fi

  # 8. Check engine is functional (can parse the real file)
  if [[ -n "$real_path" && -f "$real_path" ]]; then
    local list_result
    if list_result=$("$PYTHON" "$ENGINE" list --priority P1 2>&1); then
      echo "✅ Engine can parse and list tasks"
      passed=$((passed + 1))
    else
      echo "❌ Engine list command failed: $list_result"
      failed=$((failed + 1))
    fi
  fi

  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "Results: $passed passed, $failed failed, $warnings warnings"

  if [[ "$failed" -gt 0 ]]; then
    echo "❌ Self-test FAILED"
    return 1
  elif [[ "$warnings" -gt 0 ]]; then
    echo "⚠️  Self-test PASSED with warnings"
    return 0
  else
    echo "✅ Self-test PASSED"
    return 0
  fi
}

# --- Dispatch ---
case "${1:-}" in
  -h|--help|help|"")
    show_help
    exit 0
    ;;
  self-test)
    self_test
    exit $?
    ;;
  *)
    exec "$PYTHON" "$ENGINE" "$@"
    ;;
esac

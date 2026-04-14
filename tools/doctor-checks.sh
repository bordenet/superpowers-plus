#!/usr/bin/env bash
# doctor-checks.sh — Run all 28 superpowers-doctor diagnostic checks
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
# NOTE on arithmetic style: this script uses both ((VAR++)) and VAR=$((VAR + 1)).
# Both are safe here because set -e is NOT active (set -uo pipefail, not -euo).
# Under set -e, ((VAR++)) exits non-zero when VAR is 0 (arithmetic result = 0).
# mcp-checks.sh uses VAR=$((VAR + 1)) (POSIX-portable); both forms are acceptable.

for _arg in "$@"; do
  [[ "$_arg" == "--help" || "$_arg" == "-h" ]] && { _help_flag=1; break; }
done
if [[ "${_help_flag:-0}" == "1" ]]; then
  cat <<'USAGE'
Usage: doctor-checks.sh [OPTIONS]

Options:
  --fix-safe         Fix non-destructive issues (CRLF, BOM, hooks, drift)
  --fix              Fix all auto-fixable issues (includes --fix-safe)
  --purge-orphans    Remove orphaned installs (requires --fix)
  --summary-only     One-line pass/fail output
  --fail-on-findings Exit non-zero if any findings (for CI)
  -h, --help         Show this help

Exit codes (with --fail-on-findings):
  0  No errors (warnings are non-blocking)
  1  Errors found
  2  Critical findings

Examples:
  doctor-checks.sh                      # Report-only scan
  doctor-checks.sh --fix-safe           # Safe auto-fixes
  doctor-checks.sh --fix --purge-orphans # Full cleanup
  doctor-checks.sh --summary-only --fail-on-findings  # CI mode
USAGE
  exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tools/compat.sh
source "${SCRIPT_DIR}/compat.sh"
require_bash4 "$@"

INSTALLED_DIR="$HOME/.codex/skills"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

# Source .env for overlay path (SP_OVERLAY_SOURCE_DIR) and other config
# shellcheck source=/dev/null
if [[ -f "$HOME/.codex/.env" ]]; then
    if ! source "$HOME/.codex/.env" 2>/dev/null; then
        echo "[WARN] ~/.codex/.env has syntax errors — skipping source"
        echo "       Fix: check for unquoted angle-bracket placeholders (e.g., VAR=<value>)"
        # Fall back to grep-based extraction for critical vars
        while IFS='=' read -r _key _val; do
            [[ "$_key" =~ ^#|^$ ]] && continue
            [[ "$_val" == '<'* ]] && continue  # skip placeholders
            export "$_key=$_val" 2>/dev/null || true
        done < "$HOME/.codex/.env"
    fi
fi

# Fix modes: none < safe < moderate (--fix)
# --fix-safe:  Non-destructive only (sync drift, CRLF, BOM, name mismatch, ref sync)
# --fix:       All fixes including destructive (orphan removal, junk removal, deprecated trigger clear)
FIX_MODE=false
FIX_SAFE=false
SUMMARY_ONLY=false
PURGE_ORPHANS=false
FAIL_ON_FINDINGS=false
for arg in "$@"; do
  case "$arg" in
    --fix-safe)          FIX_SAFE=true; FIX_MODE=true ;;
    --fix)               FIX_MODE=true ;;
    --purge-orphans)     PURGE_ORPHANS=true ;;
    --summary-only)      SUMMARY_ONLY=true ;;
    --fail-on-findings)  FAIL_ON_FINDINGS=true ;;
  esac
done

# Base source: superpowers-plus (SPP_SOURCE_DIR or this repo)
SP_PLUS_DIR="${SPP_SOURCE_DIR:-$REPO_ROOT}"
SOURCE_DIRS=("$SP_PLUS_DIR")

# Auto-discover overlay sources: any *_SOURCE_DIR env var in .env
# (e.g., SPC_SOURCE_DIR, MYTEAM_SOURCE_DIR, etc.)
# Each overlay repo registers itself during install via: VARNAME_SOURCE_DIR="/path/to/repo"
# Canonical naming convention: use a repo-specific prefix (e.g., SPO_ for superpowers-overlay)
# to avoid collisions. Generic names like SP_OVERLAY_SOURCE_DIR are deprecated.
while IFS='=' read -r varname varval; do
  [[ "$varname" == "SPP_SOURCE_DIR" ]] && continue  # base, not overlay
  [[ "$varname" =~ _SOURCE_DIR$ ]] || continue
  _dir="${varval//[\"\']}"
  [[ -n "$_dir" && -d "$_dir" ]] && SOURCE_DIRS+=("$_dir")
done < <(grep '_SOURCE_DIR=' "$HOME/.codex/.env" 2>/dev/null || true)

# Deduplicate SOURCE_DIRS by canonical path (guards against case-insensitive FS duplicates
# where two *_SOURCE_DIR vars resolve to the same physical directory, e.g.,
# SPC_SOURCE_DIR=.../tools/ and LEGACY_SOURCE_DIR=.../Tools/ on macOS APFS).
# Note: realpath resolves symlinks and removes ./../ but does NOT normalize case on macOS
# APFS (case-insensitive, case-preserving). The dedup here is defense-in-depth; the
# primary protection is each overlay installer writing exactly one canonical variable.
# Guard: only run when there are overlay entries to deduplicate (SOURCE_DIRS has >1 entry).
if [[ ${#SOURCE_DIRS[@]} -gt 1 ]]; then
  declare -A _seen_canon
  _deduped=("${SOURCE_DIRS[0]}")
  _seen_canon["$(realpath "${SOURCE_DIRS[0]}" 2>/dev/null || echo "${SOURCE_DIRS[0]}")"]="1"
  for _d in "${SOURCE_DIRS[@]:1}"; do
    _canon="$(realpath "$_d" 2>/dev/null || echo "$_d")"
    if [[ -z "${_seen_canon[$_canon]+set}" ]]; then
      _deduped+=("$_d")
      _seen_canon["$_canon"]="1"
    fi
  done
  SOURCE_DIRS=("${_deduped[@]}")
  unset _seen_canon _deduped _d _canon
fi

COMPARE_DIRS=("${SOURCE_DIRS[@]}")

# Managed checkout paths (git repos maintained by install.sh)
MANAGED_SPP_DIR="$HOME/.codex/superpowers-plus"
MANAGED_OBRA_DIR="$HOME/.codex/superpowers"

BACKUP_DIR="$HOME/.codex/doctor-backups/$(date +%Y-%m-%d_%H-%M-%S)-$$"
FIXED=0; CRITICAL=0; ERRORS=0; WARNINGS=0

# Helper: should we fix this check?
# Safe checks: 3 (name), 9 (drift), 16 (ref drift), 17 (CRLF), 18 (BOM), 19 (stale checkout), 21 (hook integrity), 27 (agent drift)
# Moderate checks: 8 (orphan), 12 (deprecated), 14 (junk), 20 (dirty checkout), 26 (workflow state)
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
declare -A SKILL_DELIM_COUNT=()      # skill name → count of --- delimiters in first 60 lines
declare -A SKILL_BODY_START=()       # skill name → line number where body starts
declare -A SKILL_YAML_VALID=()       # skill name → "yes" if frontmatter is well-formed
# Cross-module shared state (declared global so modules can read/write freely)
declare -A BASE_SOURCE=()            # skill name → base skill.md path (built by metadata-checks)

while IFS= read -r f; do
  ALL_SKILL_FILES+=("$f")
  skill=$(basename "$(dirname "$f")")
  SKILL_PATH[$skill]="$f"

  # Read file once, extract everything we need
  SKILL_LINES[$skill]=$(wc -l < "$f" | tr -d ' ')
  SKILL_FIRST_LINE[$skill]=$(head -1 "$f")
  SKILL_DELIM_COUNT[$skill]=$(head -60 "$f" | grep -c "^---$" || true)
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

echo "🩺 Superpowers Doctor — $TOTAL_SKILLS skills scanned (28 checks)"
echo ""


# ═══════════════════════════════════════════════════════════════════════════════
# MODULE DISPATCH
# ═══════════════════════════════════════════════════════════════════════════════

# Pre-check: WSL + NTFS mount detection
# --- Pre-check: WSL + NTFS mount detection ---
if [[ -f /proc/version ]] && grep -Eqi 'microsoft|wsl' /proc/version 2>/dev/null; then
  case "$INSTALLED_DIR" in
    /mnt/[a-z]/*)
      echo "🟡 WARNING: Skills installed on NTFS mount ($INSTALLED_DIR)"
      echo "   chmod is silently ignored on NTFS. Move skills to a native Linux path."
      echo "   Recommended: ~/.codex/skills/ on ext4 (e.g., ~/)"
      WARNINGS=$((WARNINGS + 1))
      ;;
  esac
fi


# Source and run all doctor module checks.
# NOTE: Check 26 (workflow state) MUST run before Check 23 (reviewer dispatch).
#       This ordering is preserved in integration-checks.sh.

# shellcheck source=tools/doctor-modules/yaml-checks.sh
source "${SCRIPT_DIR}/doctor-modules/yaml-checks.sh"
# shellcheck source=tools/doctor-modules/reference-checks.sh
source "${SCRIPT_DIR}/doctor-modules/reference-checks.sh"
# shellcheck source=tools/doctor-modules/metadata-checks.sh
source "${SCRIPT_DIR}/doctor-modules/metadata-checks.sh"
# shellcheck source=tools/doctor-modules/trigger-checks.sh
source "${SCRIPT_DIR}/doctor-modules/trigger-checks.sh"
# shellcheck source=tools/doctor-modules/encoding-checks.sh
source "${SCRIPT_DIR}/doctor-modules/encoding-checks.sh"
# shellcheck source=tools/doctor-modules/checkout-checks.sh
source "${SCRIPT_DIR}/doctor-modules/checkout-checks.sh"
# shellcheck source=tools/doctor-modules/todo-checks.sh
source "${SCRIPT_DIR}/doctor-modules/todo-checks.sh"
# shellcheck source=tools/doctor-modules/integration-checks.sh
source "${SCRIPT_DIR}/doctor-modules/integration-checks.sh"
# shellcheck source=tools/doctor-modules/agent-checks.sh
source "${SCRIPT_DIR}/doctor-modules/agent-checks.sh"
# shellcheck source=tools/doctor-modules/mcp-checks.sh
source "${SCRIPT_DIR}/doctor-modules/mcp-checks.sh"

_doctor_yaml_checks
_doctor_metadata_checks     # Populates BASE_SOURCE — must run before reference-checks
_doctor_reference_checks    # Reads BASE_SOURCE (Check 16 requires it)
_doctor_encoding_checks
_doctor_checkout_checks
_doctor_trigger_checks
_doctor_todo_checks
_doctor_integration_checks  # Check 26 runs before Check 23 (inside module)
_doctor_agent_checks        # Check 27: agent content drift (~/.augment/agents/ vs source)
_doctor_mcp_checks          # Check 28: MCP server dependency health

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
    echo "✅ Doctor: all 28 checks passed"
  else
    echo "⚠️  Doctor: $CRITICAL critical · $ERRORS errors · $WARNINGS warnings"
  fi
elif [[ "$TOTAL" -eq 0 ]]; then
  echo "✅ All 28 checks passed. Your superpowers are in perfect health."
else
  echo "  $CRITICAL critical · $ERRORS errors · $WARNINGS warnings"
  echo "  Your superpowers need $TOTAL fixes."
fi
if [[ "$FIX_MODE" == "true" && "$FIXED" -gt 0 ]]; then
  echo "  ✅ Auto-fixed: $FIXED issues"
  echo "  📁 Backups: $BACKUP_DIR"
fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# --fail-on-findings: opt-in nonzero exit with severity-based exit codes.
# Default behavior (report-only, exit 0) is preserved for all other callers.
# Exit codes: 2=critical, 1=errors, 0=warnings-only or clean.
if [[ "$FAIL_ON_FINDINGS" == "true" ]]; then
  if (( CRITICAL > 0 )); then exit 2; fi
  if (( ERRORS > 0 ));   then exit 1; fi
fi

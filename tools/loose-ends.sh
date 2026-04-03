#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# tools/loose-ends.sh
# PURPOSE: Mechanical enforcement for the loose-ends-tracker gate.
#          Replaces multi-command audit sequences in todo-guardian and
#          verification-before-completion with a single deterministic entry point.
#
# SUBCOMMANDS:
#   check        Audit open #loose-end items (count + note verification)
#   add          Record a loose end (enforces non-empty --note at shell level)
#   scan-staged  Grep staged diff for TODO/FIXME/HACK in code files
#
# USAGE:
#   loose-ends.sh check
#   loose-ends.sh add --desc "URL is wrong" --note "Out of scope for this PR"
#   loose-ends.sh scan-staged
# -----------------------------------------------------------------------------
set -euo pipefail

TOOL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TODO_CRUD="$TOOL_DIR/todo-crud.sh"

RED='\033[0;31m'; YELLOW='\033[0;33m'; GREEN='\033[0;32m'; NC='\033[0m'

usage() {
    echo "Usage: loose-ends.sh <check|add|scan-staged> [options]"
    echo "  check                       Audit open #loose-end items"
    echo "  add --desc TEXT --note TEXT  Record a loose end (--note required)"
    echo "  scan-staged                 Grep staged diff for TODO/FIXME/HACK"
    exit 1
}

# ---------------------------------------------------------------------------
# check: audit open #loose-end items including DEFERRED
# ---------------------------------------------------------------------------
_python_bin() {
    # Mirrors todo-crud.sh interpreter discovery — avoids platform dependency on python3
    if command -v python3 &>/dev/null; then echo "python3"
    elif command -v python &>/dev/null; then echo "python"
    else echo ""; fi
}

cmd_check() {
    local todo_cat_output raw_output count
    # Fail closed: if todo-crud.sh cat fails (bad path, locked file, missing
    # registry), treat that as an audit error rather than "clean session".
    # Suppress stderr from todo-crud.sh itself; expose our own error message.
    if ! todo_cat_output=$("$TODO_CRUD" cat 2>/dev/null); then
        echo -e "${RED}✗ Audit error: todo-crud.sh cat failed — cannot verify loose-end state.${NC}" >&2
        echo -e "${RED}  Run: ${TODO_CRUD} cat   to diagnose.${NC}" >&2
        exit 2
    fi
    # Scan cat output directly — single source of truth for both count and display.
    # Correctly handles ACTIVE TASKS (included), DEFERRED (included), HISTORY (excluded).
    # Each item block is buffered in full so Note: lines after a #loose-end tag
    # are visible. Count = number of task-ID header lines in output.
    raw_output=$(printf '%s\n' "$todo_cat_output" | awk '
        function flush_block() {
            if (in_block && found_tag) print block
            in_block=0; found_tag=0; block=""
        }
        /^# ACTIVE TASKS/ { flush_block(); section="active";   next }
        /^# HISTORY/      { flush_block(); section="history";  next }
        /^# DEFERRED/     { flush_block(); section="deferred"; next }
        /^# /             { flush_block(); section="other";    next }
        section == "history" || section == "other" { next }
        /^- \[[ x\/\-]\] \[20[0-9]{6}-[0-9]+\]/ { flush_block(); in_block=1; block="" }
        in_block { block = block "\n" $0 }
        in_block && /#loose-end/ { found_tag=1 }
        END { flush_block() }
    ' || true)

    # grep -c exits 1 when no matches but still prints "0"; use || true to
    # prevent the failed exit from triggering set -e, and avoid "|| echo 0"
    # which would produce "0\n0" (two zeros) on a clean TODO file.
    count=$(printf '%s\n' "$raw_output" | grep -cE '^- \[[ x/\-]\] \[20[0-9]{6}-[0-9]+\]' 2>/dev/null || true)

    if [[ "$count" -eq 0 ]]; then
        echo -e "${GREEN}✓ No open #loose-end items. Session is clean.${NC}"
        exit 0
    fi

    echo -e "${YELLOW}⚠ $count open #loose-end item(s) found:${NC}"
    echo ""
    printf '%s\n' "$raw_output"
    echo ""
    echo "Classify each item:"
    echo "  resolved     → todo-crud.sh complete --id <id>"
    echo "  deferred     → confirm --note justification is present in block above"
    echo "  must-address → FIX NOW before claiming completion"
    echo ""
    echo -e "${YELLOW}1 = findings present ($count item(s)). Classify before proceeding.${NC}"
    # Exit 1 for "findings present" — stable, not count-as-exit-code
    exit 1
}

# ---------------------------------------------------------------------------
# add: record a loose end — enforces --note at the shell level
# ---------------------------------------------------------------------------
cmd_add() {
    local desc="" note="" priority="P3"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --desc|--note|--priority)
                if [[ $# -lt 2 || -z "${2:-}" || "${2:-}" == --* ]]; then
                    echo -e "${RED}✗ $1 requires a value${NC}" >&2
                    echo -e "  Usage: loose-ends.sh add --desc 'text' --note 'reason' [--priority P1-P4]" >&2
                    exit 1
                fi
                case "$1" in
                    --desc)     desc="$2" ;;
                    --note)     note="$2" ;;
                    --priority) priority="$2" ;;
                esac
                shift 2 ;;
            *) echo -e "${RED}Unknown option: $1${NC}" >&2; usage ;;
        esac
    done

    if [[ -z "$desc" ]]; then
        echo -e "${RED}✗ --desc is required${NC}" >&2
        exit 1
    fi

    if [[ -z "$note" ]]; then
        echo -e "${RED}✗ --note is required for loose-end recording.${NC}" >&2
        echo -e "  Provide the deferral reason: loose-ends.sh add --desc '...' --note 'reason'" >&2
        echo -e "  If you cannot state a reason, the item should be resolved, not deferred." >&2
        exit 1
    fi

    "$TODO_CRUD" add \
        --priority "$priority" \
        --description "$desc" \
        --note "Deferred reason: $note" \
        --tags "#loose-end"

    echo -e "${GREEN}✓ Loose end recorded with justification.${NC}"
}

# ---------------------------------------------------------------------------
# scan-staged: grep staged diff for code debt markers in code files
# ---------------------------------------------------------------------------
cmd_scan_staged() {
    local diff_output

    diff_output=$(git diff --cached -U0 2>/dev/null) || { echo "(not in a git repo)"; exit 0; }

    if [[ -z "$diff_output" ]]; then
        echo -e "${GREEN}✓ No staged changes to scan.${NC}"
        exit 0
    fi

    # Filter to added lines (+) in non-doc files, grep for debt markers
    local hits
    hits=$(echo "$diff_output" | awk '
        /^\+\+\+ b\// { file=$0; sub(/^\+\+\+ b\//, "", file) }
        /^\+[^+]/ && file !~ /\.(md|txt|rst)$/ { print file": "$0 }
    ' | grep -iE '^\S.*\+.*(TODO|FIXME|HACK|XXX|I.ll fix|workaround)' || true)

    if [[ -z "$hits" ]]; then
        echo -e "${GREEN}✓ No code debt markers in staged changes.${NC}"
        exit 0
    fi

    echo -e "${YELLOW}⚠ Code debt markers in staged changes:${NC}"
    echo "$hits"
    echo ""
    echo "For each: resolve now, or record via: loose-ends.sh add --desc '...' --note '...'"
    # Exit 1 for "findings present" — stable exit code, not count-as-exit-code
    exit 1
}

# ---------------------------------------------------------------------------
# Dispatch
# ---------------------------------------------------------------------------
[[ $# -eq 0 ]] && usage
case "$1" in
    check)        shift; cmd_check "$@" ;;
    add)          shift; cmd_add "$@" ;;
    scan-staged)  shift; cmd_scan_staged "$@" ;;
    *)            echo -e "${RED}Unknown subcommand: $1${NC}" >&2; usage ;;
esac

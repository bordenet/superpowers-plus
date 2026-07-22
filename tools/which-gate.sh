#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# tools/which-gate.sh
#
# PURPOSE: Answer "which pre-push gate(s) require a sentinel for this file?"
#          by extracting and running the ACTUAL detection logic from the
#          gate scripts themselves -- never a hand-copied regex or a prose
#          description that can silently drift out of sync with the real
#          gates. Hand-written prose describing gate coverage is exactly the
#          kind of thing that drifts from the code it describes; this tool
#          exists so the answer to "which gate covers file X" comes from
#          running the gates' own code, not from reading (and possibly
#          misremembering) AGENTS.md/CONTRIBUTING.md prose.
#
# USAGE:   tools/which-gate.sh <path> [<path> ...]
#          tools/which-gate.sh --any=<llm-skill-review|phr|cr-battery> <path> [<path> ...]
#          tools/which-gate.sh --help
#
# Default mode: for each path, reports whether each of the three
# sentinel-scored gates requires a sentinel for it, and the exact command
# to write that sentinel:
#   - tools/pre-push-llm-skill-review-gate.sh  -> .llm-skill-review-cleared
#   - tools/pre-push-phr-gate.sh                -> .phr-cleared
#   - tools/pre-push-code-review-gate.sh        -> .code-review-cleared
# Prints "(no gate currently covers this file)" when none apply -- itself
# useful signal (a file with no gate coverage may be a real gap, not fine).
#
# --any=<gate> mode: for scripting/CI use. Exits 0 if ANY given path is
# covered by the named gate, 1 if NONE are, 2 on usage/extraction error.
# Prints nothing on stdout (silent battery-style check); use $? to branch.
# <gate> must be exactly one of: llm-skill-review, phr, cr-battery.
#
# HOW: llm-skill-review and PHR classification both delegate to
# tools/md-files-changed.sh -- this repo's own single source of truth for
# that ownership boundary (--llm-owned / --exclude-llm-owned) -- rather than
# re-deriving the regex here. cr-battery classification extracts the
# _first_code_file() awk function verbatim from tools/pre-push-code-review-
# gate.sh and runs that extracted logic directly, never a hand-copied
# reimplementation. If a gate script's shape changes enough that extraction
# can't find what it expects, this fails LOUDLY (exit 2) rather than
# silently falling back to a stale copy.
#
# EXIT CODES:
#   Default mode: 0  ran successfully (regardless of whether any gate matched)
#                 1  usage error (no paths given)
#                 2  a gate script is missing, or its detection logic could
#                    not be extracted (shape changed) -- fail closed
#   --any mode:   0  at least one given path is covered by <gate>
#                 1  no given path is covered by <gate>
#                 2  usage error (bad/missing <gate> name, no paths given),
#                    or a gate script's detection logic could not be
#                    extracted -- fail closed, never silently reports "no match"
# -----------------------------------------------------------------------------
set -euo pipefail

if [[ $# -eq 0 || "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    sed -n '2,52p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
    [[ $# -eq 0 ]] && exit 1
    exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

MD_FILES_CHANGED="$REPO_ROOT/tools/md-files-changed.sh"
CR_GATE="$REPO_ROOT/tools/pre-push-code-review-gate.sh"

# --any=<gate> mode: parse before the missing-file checks below so a bad
# gate name exits 2 (not silently falls through) per this mode's own contract.
ANY_GATE=""
if [[ "${1:-}" == --any=* ]]; then
    ANY_GATE="${1#--any=}"
    shift
    case "$ANY_GATE" in
        llm-skill-review|phr|cr-battery) ;;
        *)
            echo "ERROR: --any=$ANY_GATE invalid -- must be llm-skill-review, phr, or cr-battery" >&2
            exit 2
            ;;
    esac
    if [[ $# -eq 0 ]]; then
        echo "ERROR: --any=$ANY_GATE requires at least one path" >&2
        exit 2
    fi
fi

for f in "$MD_FILES_CHANGED" "$CR_GATE"; do
    if [[ ! -f "$f" ]]; then
        echo "ERROR: expected gate script missing: $f" >&2
        exit 2
    fi
done

# --- Extract cr-battery's detection logic verbatim (never hand-copied) ---
CR_FUNC_SRC="$(sed -n '/^_first_code_file() {/,/^}/p' "$CR_GATE")"

fail_extract() {
    echo "ERROR: could not extract '$1' from $2 -- its shape changed." >&2
    echo "  This tool fails closed rather than silently trusting stale logic." >&2
    echo "  Update the sed extraction in $(basename "${BASH_SOURCE[0]}") to match." >&2
    exit 2
}
[[ -n "$CR_FUNC_SRC" ]] && [[ "$(printf '%s' "$CR_FUNC_SRC" | tail -1)" == "}" ]] \
    || fail_extract "_first_code_file()" "$CR_GATE"

TMP_LIB="$(mktemp "${TMPDIR:-/tmp}/which-gate-lib.XXXXXX")"
trap 'rm -f "$TMP_LIB"' EXIT
printf '%s\n' "$CR_FUNC_SRC" > "$TMP_LIB"
# shellcheck source=/dev/null
source "$TMP_LIB"

cr_battery_covers() {
    local path="$1"
    [[ -n "$(printf '%s\n' "$path" | _first_code_file)" ]]
}

# llm_owned_covers / phr_covers PATH: delegate to md-files-changed.sh rather
# than re-deriving its regex. rc>1 is an unexpected failure from that helper
# (it should only ever return 0 match / 1 no-match when --files is given,
# since --files skips this script's own base-ref resolution entirely) --
# fail closed rather than silently treating it as "no match".
llm_owned_covers() {
    local path="$1" rc=0
    bash "$MD_FILES_CHANGED" --files "$path" --llm-owned >/dev/null 2>&1 || rc=$?
    if [[ "$rc" -gt 1 ]]; then
        echo "ERROR: $MD_FILES_CHANGED returned unexpected exit $rc on '$path' (--llm-owned)" >&2
        exit 2
    fi
    [[ "$rc" -eq 0 ]]
}

phr_covers() {
    local path="$1" rc=0
    bash "$MD_FILES_CHANGED" --files "$path" --exclude-llm-owned >/dev/null 2>&1 || rc=$?
    if [[ "$rc" -gt 1 ]]; then
        echo "ERROR: $MD_FILES_CHANGED returned unexpected exit $rc on '$path' (--exclude-llm-owned)" >&2
        exit 2
    fi
    [[ "$rc" -eq 0 ]]
}

if [[ -n "$ANY_GATE" ]]; then
    for path in "$@"; do
        case "$ANY_GATE" in
            llm-skill-review) llm_owned_covers "$path" && exit 0 ;;
            phr) phr_covers "$path" && exit 0 ;;
            cr-battery) cr_battery_covers "$path" && exit 0 ;;
        esac
    done
    exit 1
fi

for path in "$@"; do
    echo "== $path =="
    covered=0

    if llm_owned_covers "$path"; then
        echo "  llm-skill-review gate: REQUIRED -- .llm-skill-review-cleared (>= 9.2)"
        echo "    tools/run-llm-skill-review.sh --verdict PASS --min-score <N>"
        covered=1
    fi

    if phr_covers "$path"; then
        echo "  PHR gate: REQUIRED -- .phr-cleared (PASS required; project floor may apply)"
        echo "    tools/run-phr.sh --verdict PASS --min-score <N>"
        covered=1
    fi

    if cr_battery_covers "$path"; then
        echo "  cr-battery gate: REQUIRED -- .code-review-cleared (PASS or PASS_WITH_NITS)"
        echo "    tools/run-battery.sh --verdict PASS"
        covered=1
    fi

    if [[ "$covered" -eq 0 ]]; then
        echo "  (no gate currently covers this file)"
    fi
done

exit 0

#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# tools/review.sh
#
# PURPOSE: Pre-dispatch review router. Given one or more artifact paths,
#          answers "which review skill do I load and which sentinel does
#          the pre-push gate require?" -- so the agent never picks the
#          wrong review skill from memory. Mechanically wraps
#          tools/which-gate.sh (the extraction-based file->gate mapping)
#          and translates its output into a single unambiguous skill
#          name + sentinel filename per artifact class.
#
#          Failure class this closes: an agent can pick a code-review
#          dispatcher to review a docs/**/*.md design spec when the correct
#          answer is progressive-harsh-review (or vice versa). Each review
#          skill's own "Wrong skill?" banner is a good inner backstop, but
#          it only fires once the wrong skill is already loaded -- this
#          tool fires BEFORE any skill loads.
#
# USAGE:   tools/review.sh route <path> [<path> ...]
#          tools/review.sh --help
#
# OUTPUT:  For a single-gate set of paths, prints exactly:
#            SKILL: <skill-name>
#            RUNNER: <tools/run-*.sh command to write the sentinel>
#            SENTINEL: <.sentinel-file>
#            FILES:
#              <path>
#              <path>
#          For a mixed-gate set (paths span 2+ gate classes), prints one
#          block per gate class, separated by a blank line. Block order:
#          llm-skill-review, phr, cr-battery. Paths matching multiple
#          gates appear under each block (today gate scopes are disjoint,
#          so this is defensive rather than routine).
#
# EXIT CODES:
#   0  routing succeeded, at least one artifact matched a known gate
#   1  usage error (missing subcommand, no paths)
#   2  which-gate.sh could not extract detection logic (fails closed --
#      never guess when the mechanical mapping is broken)
#   3  at least one artifact matched NO gate (agent must resolve --
#      likely a manifest-file gap or misspelled path)
# -----------------------------------------------------------------------------
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WHICH_GATE="$SCRIPT_DIR/which-gate.sh"

usage() {
    sed -n '2,43p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

if [[ $# -eq 0 || "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    usage
    [[ $# -eq 0 ]] && exit 1
    exit 0
fi

if [[ "$1" != "route" ]]; then
    echo "ERROR: unknown subcommand: '$1' -- only 'route' is supported" >&2
    usage >&2
    exit 1
fi
shift

if [[ $# -eq 0 ]]; then
    echo "ERROR: 'route' requires at least one path" >&2
    exit 1
fi

if [[ ! -r "$WHICH_GATE" ]]; then
    echo "ERROR: expected router dependency missing or unreadable: $WHICH_GATE" >&2
    exit 2
fi

# Bucket paths by gate class using which-gate.sh --any (silent, exit-code
# driven). Any exit code other than 0 (matched) or 1 (no match) is a
# which-gate.sh extraction failure and must propagate as our exit 2.
declare -a LLM_PATHS=()
declare -a PHR_PATHS=()
declare -a CR_PATHS=()
declare -a UNMATCHED_PATHS=()

classify_one() {
    local path="$1" matched=0 rc
    for gate in llm-skill-review phr cr-battery; do
        rc=0
        bash "$WHICH_GATE" --any="$gate" "$path" >/dev/null 2>&1 || rc=$?
        if [[ "$rc" -ne 0 && "$rc" -ne 1 ]]; then
            echo "ERROR: which-gate.sh returned unexpected exit $rc on '$path' (gate=$gate)" >&2
            exit 2
        fi
        if [[ "$rc" -eq 0 ]]; then
            case "$gate" in
                llm-skill-review) LLM_PATHS+=("$path") ;;
                phr) PHR_PATHS+=("$path") ;;
                cr-battery) CR_PATHS+=("$path") ;;
            esac
            matched=1
        fi
    done
    if [[ "$matched" -eq 0 ]]; then
        UNMATCHED_PATHS+=("$path")
    fi
}

for path in "$@"; do classify_one "$path"; done

emit_block() {
    local skill="$1" runner="$2" sentinel="$3"
    shift 3
    echo "SKILL: $skill"
    echo "RUNNER: $runner"
    echo "SENTINEL: $sentinel"
    echo "FILES:"
    for f in "$@"; do echo "  $f"; done
}

FIRST=1
maybe_sep() {
    if [[ "$FIRST" -eq 1 ]]; then
        FIRST=0
    else
        echo
    fi
}

if [[ "${#LLM_PATHS[@]}" -gt 0 ]]; then
    maybe_sep
    emit_block "llm-skill-review" \
               "tools/run-llm-skill-review.sh --verdict PASS --min-score 9.2" \
               ".llm-skill-review-cleared" \
               "${LLM_PATHS[@]}"
fi

if [[ "${#PHR_PATHS[@]}" -gt 0 ]]; then
    maybe_sep
    emit_block "progressive-harsh-review" \
               "tools/run-phr.sh --verdict PASS --min-score <N>" \
               ".phr-cleared" \
               "${PHR_PATHS[@]}"
fi

if [[ "${#CR_PATHS[@]}" -gt 0 ]]; then
    maybe_sep
    emit_block "code-review-battery" \
               "tools/run-battery.sh --verdict PASS" \
               ".code-review-cleared" \
               "${CR_PATHS[@]}"
fi

if [[ "${#UNMATCHED_PATHS[@]}" -gt 0 ]]; then
    echo >&2
    echo "ERROR: no gate covers these paths (agent must resolve):" >&2
    for f in "${UNMATCHED_PATHS[@]}"; do echo "  $f" >&2; done
    exit 3
fi

exit 0

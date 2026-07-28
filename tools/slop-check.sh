#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Script: slop-check.sh
# PURPOSE: Centralized AI slop detector. Implements the pattern catalog from
#          detecting-ai-slop/reference.md as a runtime gate. Called by
#          wiki-content-check.sh and any other gate that publishes prose.
#
# USAGE:
#   slop-check.sh --content FILE [--mode full|summary|silent] [--format human|json]
#   slop-check.sh --help
#
# OPTIONS:
#   --content FILE      Markdown file to scan (required)
#   --mode MODE         full (default): print each hit
#                       summary: only print counts
#                       silent: no output, exit code only
#   --format FORMAT     human (default) or json
#   --help              Show this help
#
# EXIT:
#   0  Clean (advisory warnings may be present in full/summary mode)
#   1  Blocking violations found
#   2  Usage / environment error
#
# PATTERN SOURCES (detecting-ai-slop/reference.md):
#   Blocking  — Cat 1 boosters (excl. weak intensifiers), Cat 2 buzzwords,
#               Cat 3 filler phrases, Cat 7 em/en-dash (Unicode)
#   Advisory  — Cat 1 weak intensifiers (very, extremely, incredibly, quite,
#               rather, really, highly, truly, absolutely, definitely)
# -----------------------------------------------------------------------------
set -euo pipefail

if [ -z "${BASH_VERSION:-}" ]; then
    echo "ERROR: requires bash" >&2; exit 2
fi
if (( ${BASH_VERSINFO[0]:-0} < 4 )); then
    echo "ERROR: requires bash 4+; on macOS: brew install bash" >&2; exit 2
fi

CONTENT_FILE=""
MODE="full"
FORMAT="human"
VIOLATIONS=0
WARNINGS=0

log_block() {
    local label="$1" msg="$2"
    VIOLATIONS=$(( VIOLATIONS + 1 ))
    [[ "$MODE" == "silent" ]] && return
    if [[ "$FORMAT" == "json" ]]; then
        local escaped
        escaped="$(printf '%s' "$msg" | sed 's/\\/\\\\/g; s/"/\\"/g')"
        printf '{"level":"error","label":"%s","detail":"%s"}\n' "$label" "$escaped"
    else
        printf '[slop-check] BLOCK  %s: %s\n' "$label" "$msg" >&2
    fi
}

log_warn() {
    local label="$1" msg="$2"
    WARNINGS=$(( WARNINGS + 1 ))
    [[ "$MODE" == "silent" ]] && return
    [[ "$MODE" == "summary" ]] && return
    if [[ "$FORMAT" == "json" ]]; then
        local escaped
        escaped="$(printf '%s' "$msg" | sed 's/\\/\\\\/g; s/"/\\"/g')"
        printf '{"level":"warn","label":"%s","detail":"%s"}\n' "$label" "$escaped"
    else
        printf '[slop-check] WARN   %s: %s\n' "$label" "$msg" >&2
    fi
}

show_help() {
    sed -n 's/^# \{0,1\}//p' "${BASH_SOURCE[0]}" | sed -n '/^Script:/,/^---/p'
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)    show_help; exit 0 ;;
        --content)    CONTENT_FILE="${2:?--content requires a file}"; shift 2 ;;
        --mode)       MODE="${2:?--mode requires full|summary|silent}"; shift 2 ;;
        --format)     FORMAT="${2:?--format requires human|json}"; shift 2 ;;
        *) printf 'ERROR: unknown option: %s\n' "$1" >&2; exit 2 ;;
    esac
done

[[ -n "$CONTENT_FILE" ]]  || { echo "ERROR: --content FILE is required" >&2; exit 2; }
[[ -r "$CONTENT_FILE" ]]  || { echo "ERROR: file not readable: $CONTENT_FILE" >&2; exit 2; }
[[ "$MODE"   =~ ^(full|summary|silent)$ ]] || { echo "ERROR: --mode must be full|summary|silent" >&2; exit 2; }
[[ "$FORMAT" =~ ^(human|json)$ ]]          || { echo "ERROR: --format must be human|json" >&2; exit 2; }

# ---------------------------------------------------------------------------
# Cat 7: em-dash / en-dash — Unicode; grep -P is unreliable on macOS, use python3.
# Non-raw string so \u escapes are processed. f-strings require Python 3.6+;
# use str.format() for compatibility back to Python 3.0.
# python3 output is captured to a temp file so a crash exits non-zero visibly
# rather than silently producing zero iterations from process substitution.
# ---------------------------------------------------------------------------
_PY_TMP="$(mktemp /tmp/slop-check-py.XXXXXX)"
trap 'rm -f "$_PY_TMP"' EXIT
if command -v python3 >/dev/null 2>&1; then
    python3 - "$CONTENT_FILE" > "$_PY_TMP" 2>&1 << 'PYEOF'
import sys, re
pattern = re.compile("[\u2014\u2013]")
with open(sys.argv[1], encoding="utf-8", errors="replace") as fh:
    for i, line in enumerate(fh, 1):
        if pattern.search(line):
            print("{}:{}".format(i, line.rstrip()))
PYEOF
    _py_rc=$?
    if [[ $_py_rc -ne 0 ]]; then
        printf '[slop-check] ERROR  EM_DASH: python3 failed (rc=%d) -- em/en-dash check skipped\n' "$_py_rc" >&2
        cat "$_PY_TMP" >&2
    else
        while IFS= read -r hit; do
            [[ -n "$hit" ]] && log_block "EM_DASH" "$hit"
        done < "$_PY_TMP"
    fi
else
    printf '[slop-check] WARN   EM_DASH: python3 not found -- em/en-dash check skipped\n' >&2
fi

# ---------------------------------------------------------------------------
# Cat 1 blocking: boosters (excludes weak intensifiers handled below)
# ---------------------------------------------------------------------------
declare -a BOOSTERS=(
    'delve' 'tapestry' 'multifaceted' 'myriad' 'plethora'
    'remarkably' 'exceptionally' 'particularly' 'especially'
    'significantly' 'substantially' 'considerably' 'dramatically'
    'tremendously' 'immensely' 'profoundly'
)
for pat in "${BOOSTERS[@]}"; do
    while IFS= read -r hit; do
        [[ -n "$hit" ]] && log_block "BOOSTER" "$hit"
    done < <(grep -in "\b${pat}\b" "$CONTENT_FILE" || true)
done

# ---------------------------------------------------------------------------
# Cat 1: weak intensifiers — advisory only, never block
# ---------------------------------------------------------------------------
declare -a WEAK_INTENSIFIERS=(
    'very' 'extremely' 'incredibly' 'quite' 'rather'
    'really' 'highly' 'truly' 'absolutely' 'definitely'
)
for pat in "${WEAK_INTENSIFIERS[@]}"; do
    while IFS= read -r hit; do
        [[ -n "$hit" ]] && log_warn "INTENSIFIER" "$hit"
    done < <(grep -in "\b${pat}\b" "$CONTENT_FILE" || true)
done

# ---------------------------------------------------------------------------
# Cat 2: buzzwords (blocking)
# ---------------------------------------------------------------------------
declare -a BUZZWORDS=(
    'utilize' 'leverage' 'robust' 'holistic' 'seamless' 'comprehensive'
    'elegant' 'intuitive' 'streamlined' 'scalable' 'innovative'
    'sophisticated' 'state-of-the-art' 'best-in-class' 'world-class'
    'enterprise-ready' 'production-grade' 'battle-tested' 'industry-leading'
    'game-changing' 'revolutionary' 'transformative' 'disruptive'
    'cutting-edge' 'next-generation' 'groundbreaking' 'paradigm-shifting'
    'synergy' 'empower' 'amplify'
    'unlock' 'spearhead' 'champion' 'actionable' 'elevate' 'harness'
    'future-proof' 'unprecedented' 'pivotal'
    'nuanced' 'proactive' 'mission-critical' 'reimagine'
    'bolster' 'transcend' 'resonate' 'showcase' 'underscore'
)
# Advisory-only buzzwords: common in legitimate technical prose; flag but do not block.
declare -a BUZZWORDS_ADVISORY=(
    'enhance' 'dynamic' 'agile' 'ecosystem' 'facilitate' 'accelerate'
)
for pat in "${BUZZWORDS[@]}"; do
    while IFS= read -r hit; do
        [[ -n "$hit" ]] && log_block "BUZZWORD" "$hit"
    done < <(grep -in "\b${pat}\b" "$CONTENT_FILE" || true)
done
for pat in "${BUZZWORDS_ADVISORY[@]}"; do
    while IFS= read -r hit; do
        [[ -n "$hit" ]] && log_warn "BUZZWORD" "$hit"
    done < <(grep -in "\b${pat}\b" "$CONTENT_FILE" || true)
done

# ---------------------------------------------------------------------------
# Cat 3: filler openers (blocking)
# ---------------------------------------------------------------------------
declare -a FILLERS=(
    "it's important to note"
    "it is important to note"
    "it's worth noting"
    "it is worth noting"
    "worth noting"
    "it's worth mentioning"
    "it should be noted"
    "needless to say"
    "as you may know"
    "as we all know"
    "in today's world"
    "in today's digital age"
    "in the modern era"
    "at the end of the day"
    "that being said"
    "with that in mind"
    "let me walk you through"
    "let's dive in"
    "let's explore"
    "let's take a look at"
    "let's break this down"
    "in conclusion"
    "in summary"
    "in essence"
    "welcome to the world of"
    "cannot be overstated"
    "unlock the potential"
    "designed to enhance"
    "in a world where"
)
for pat in "${FILLERS[@]}"; do
    while IFS= read -r hit; do
        [[ -n "$hit" ]] && log_block "FILLER" "$hit"
    done < <(grep -in "$pat" "$CONTENT_FILE" || true)
done

# ---------------------------------------------------------------------------
# Result
# ---------------------------------------------------------------------------
if [[ "$MODE" != "silent" ]]; then
    if [[ "$VIOLATIONS" -gt 0 ]]; then
        printf '[slop-check] %d blocking violation(s), %d advisory warning(s) -- write blocked\n' \
            "$VIOLATIONS" "$WARNINGS" >&2
    else
        printf '[slop-check] clean (%d advisory warning(s))\n' "$WARNINGS" >&2
    fi
fi

[[ "$VIOLATIONS" -gt 0 ]] && exit 1
exit 0

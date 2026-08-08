#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Script: slop-check.sh
# PURPOSE: Centralized AI slop detector. Implements the pattern catalog from
#          detecting-ai-slop/reference.md as a runtime gate. Called by
#          wiki-content-check.sh and any other gate that publishes prose.
#          Every absolute http(s) URL in the content is redacted to a
#          neutral placeholder before any pattern check runs, so a buzzword/
#          filler/booster word inside a URL slug (e.g. a Linear ticket link)
#          is never mistaken for authored prose.
#
# REQUIRES: bash 4+; python3 on PATH (hard dependency, unconditional --
#           exits 2 if missing; used for URL redaction and em-dash
#           detection, both of which run before any other check).
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
#   --only LIST         Comma-separated categories to evaluate (e.g.
#                       EM_DASH,EMOJI). Omit for the full catalog. A caller
#                       wanting only house style MUST pass this: the full
#                       catalog is tuned for wiki prose and blocks ordinary
#                       engineering vocabulary.
#   --help              Show this help
#
# EXIT:
#   0  Clean (advisory warnings may be present in full/summary mode)
#   1  Blocking violations found
#   2  Usage / environment error
#
# PATTERN SOURCES:
#   Primary   — detecting-ai-slop/reference.md: Cat 1 boosters (excl. weak
#               intensifiers), Cat 2 buzzwords, Cat 3 filler phrases, Cat 7
#               em/en-dash (Unicode)
#   Blocking  — the above, plus a small supplementary set restored from the
#               retired tools/wiki-content-check.sh SLOP_PATTERNS catalog,
#               not yet cross-listed in reference.md (see FILLERS comment)
#   Advisory  — Cat 1 weak intensifiers (very, extremely, incredibly, quite,
#               rather, really, highly, truly, absolutely, definitely), plus
#               FILLERS_ADVISORY (high-false-positive connector phrasing)
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
ONLY=""
# Categories that could not be evaluated at all. A scan that did not run must
# never report clean: that is a silent fail-open, and callers that gate a write
# on this exit code would post unscanned content.
SKIPPED=0

log_block() {
    local label="$1" msg="$2"
    category_enabled "$label" || return 0
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

# ---------------------------------------------------------------------------
# --only <CSV>: evaluate just these categories.
#
# The full catalog is calibrated for wiki publishing, where marketing language
# is the thing being kept out. Importing all of it into a different gate blocks
# ordinary engineering vocabulary: "harness", "comprehensive" and "crucial" are
# blocking BUZZWORDs, "significantly" a blocking BOOSTER, and the matcher is
# not negation-aware, so "not comprehensive" blocks too. A caller that only
# wants house style (dashes, emoji) needs a way to say so, or it inherits ~100
# terms it never asked for and its users route around the gate.
# ---------------------------------------------------------------------------
category_enabled() {
    [[ -z "$ONLY" ]] && return 0
    case ",${ONLY}," in
        *",$1,"*) return 0 ;;
        *)        return 1 ;;
    esac
}

log_warn() {
    local label="$1" msg="$2"
    category_enabled "$label" || return 0
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
        --only)       ONLY="${2:?--only requires a comma-separated category list}"; shift 2 ;;
        *) printf 'ERROR: unknown option: %s\n' "$1" >&2; exit 2 ;;
    esac
done

[[ -n "$CONTENT_FILE" ]]  || { echo "ERROR: --content FILE is required" >&2; exit 2; }
[[ -r "$CONTENT_FILE" ]]  || { echo "ERROR: file not readable: $CONTENT_FILE" >&2; exit 2; }
[[ "$MODE"   =~ ^(full|summary|silent)$ ]] || { echo "ERROR: --mode must be full|summary|silent" >&2; exit 2; }
[[ "$FORMAT" =~ ^(human|json)$ ]]          || { echo "ERROR: --format must be human|json" >&2; exit 2; }

# ---------------------------------------------------------------------------
# URL redaction (must run before ANY pattern check below): every check in
# this script is a raw grep/regex with no markdown or URL awareness, so a
# word like "unlock" inside a Linear/GitLab URL slug (e.g.
# .../issue/TEAM-NNNN/intro-protection-...-background-unlock-leak) false-
# positives identically to real authored prose. This is a real, not
# hypothetical, conflict: wiki-content-check.sh's own REF_COMPLETENESS check
# can require that exact URL be preserved byte-for-byte in the same file
# this script scans, with no way to satisfy both checks by editing content
# alone (incident: 2026-07-31, needs-me-queue wiki publish).
#
# Build a scan copy with every absolute http(s) URL replaced by a neutral
# placeholder before any check runs, so buzzword/filler/booster/em-dash
# patterns only ever see prose, never URL path/slug text. Line count and
# order are preserved 1:1 so reported line numbers still point at the right
# line in $CONTENT_FILE for the human to look up -- only the printed hit
# text differs (shows the placeholder) when a match falls on a redacted
# line. python3 is a hard dependency of this script (already required for
# the em-dash check below) -- fail closed rather than silently scanning raw,
# unredacted content if it is missing.
# ---------------------------------------------------------------------------
if ! command -v python3 >/dev/null 2>&1; then
    echo "ERROR: python3 is required (URL redaction + em-dash check)" >&2
    exit 2
fi
SCAN_FILE="$(mktemp /tmp/slop-check-scan.XXXXXX)"
trap 'rm -f "$SCAN_FILE"' EXIT
_PY_TMP="$(mktemp /tmp/slop-check-py.XXXXXX)"
trap 'rm -f "$_PY_TMP" "$SCAN_FILE"' EXIT

# The python3 invocation must be the condition of the if-statement itself
# (not a bare command followed by a `$?` capture on the next line) -- under
# `set -e`, a non-zero exit from a bare simple command aborts the whole
# script immediately, before the next statement ever runs. This was a real
# bug in the em-dash block below before this fix (its `_py_rc=$?` capture
# was unreachable dead code on an actual crash -- caught in code review)
# and would have been a worse one here, since this call has
# no error handling at all otherwise and runs unconditionally on every
# invocation, before any pattern check. Not redirecting stderr: a crash's
# traceback should print directly and immediately, not be captured into a
# temp file that the EXIT trap then deletes before anyone sees it.
if ! python3 - "$CONTENT_FILE" > "$SCAN_FILE" << 'PYEOF'
import sys, re
pattern = re.compile(r'https?://[^\s)>"`]+')
with open(sys.argv[1], encoding="utf-8", errors="replace") as fh:
    text = fh.read()
sys.stdout.write(pattern.sub("URLREF", text))
PYEOF
then
    echo "[slop-check] ERROR  URL_REDACT: python3 failed -- ABORT, do not infer PASS" >&2
    exit 2
fi

# ---------------------------------------------------------------------------
# Cat 7: em-dash / en-dash — Unicode; grep -P is unreliable on macOS, use python3.
# Non-raw string so \u escapes are processed. f-strings require Python 3.6+;
# use str.format() for compatibility back to Python 3.0.
# The python3 call is the if-condition itself (see URL redaction block above
# for why) so a crash is actually caught -- under the previous bare-command
# + `_py_rc=$?` form, `set -e` aborted before that capture line ever ran,
# making the "print a custom error, cat the traceback" branch below
# unreachable dead code on a real crash.
# Scans $SCAN_FILE (URL-redacted), not $CONTENT_FILE -- see URL redaction
# block above. A literal em-dash inside a valid URL is not realistic, but
# scanning the same redacted copy as every other check keeps this
# consistent and immune to the same class of false positive.
# ---------------------------------------------------------------------------
if ! python3 - "$SCAN_FILE" > "$_PY_TMP" 2>&1 << 'PYEOF'
import sys, re
pattern = re.compile("[—–]")
with open(sys.argv[1], encoding="utf-8", errors="replace") as fh:
    for i, line in enumerate(fh, 1):
        if pattern.search(line):
            print("{}:{}".format(i, line.rstrip()))
PYEOF
then
    # Found via code-review-battery: EMOJI's identical failure branch (below)
    # increments SKIPPED so a python3 crash here can't silently exit 0
    # ("clean") on the highest-signal blocking category -- this branch was
    # missing that wiring.
    category_enabled "EM_DASH" && SKIPPED=$(( SKIPPED + 1 ))
    printf '[slop-check] ERROR  EM_DASH: python3 failed -- em/en-dash check skipped\n' >&2
    cat "$_PY_TMP" >&2
else
    while IFS= read -r hit; do
        [[ -n "$hit" ]] && log_block "EM_DASH" "$hit"
    done < "$_PY_TMP"
fi

# ---------------------------------------------------------------------------
# Cat 8: emoji -- advisory, not blocking.
#
# Same python3 approach as EM_DASH above, and for the same reason: these are
# codepoints above U+007F, and a byte-mode matcher reports a clean pass on a
# file full of them. grep -P is not available on macOS default grep.
#
# Advisory deliberately. wiki-content-check.sh fails the publish on any
# blocking hit, so promoting this to log_block would start rejecting every
# existing page that carries an emoji. Surfacing it is the useful half; making
# it fatal is a separate decision with real blast radius.
#
# Ranges cover pictographs, dingbats, the variation selector and the ZWJ, so a
# composed sequence (flag, shield, skin tone) matches on at least one codepoint
# without needing full grapheme-cluster handling.
# ---------------------------------------------------------------------------
_EMOJI_TMP="$(mktemp /tmp/slop-check-emoji.XXXXXX)"
# `trap CMD EXIT` REPLACES the previous EXIT handler, it does not append --
# this trap must re-list every temp file registered by earlier traps
# ($SCAN_FILE from the URL-redaction step above) or they leak on every run.
# Found via code-review-battery: a clean invocation left one new
# /tmp/slop-check-scan.XXXXXX file behind every time, since the two earlier
# traps' $SCAN_FILE entry was silently dropped by this one, the last
# registered before normal exit.
trap 'rm -f "$SCAN_FILE" "$_PY_TMP" "$_EMOJI_TMP"' EXIT
if command -v python3 >/dev/null 2>&1; then
    _emoji_rc=0
    python3 - "$CONTENT_FILE" > "$_EMOJI_TMP" 2>&1 << 'PYEOF' || _emoji_rc=$?
import sys, re
pattern = re.compile("[\u2600-\u27bf\ufe0f\u200d]|[\U0001f300-\U0001faff]")
with open(sys.argv[1], encoding="utf-8", errors="replace") as fh:
    for i, line in enumerate(fh, 1):
        if pattern.search(line):
            print("{}:{}".format(i, line.rstrip()))
PYEOF
    if [[ $_emoji_rc -ne 0 ]]; then
        category_enabled "EMOJI" && SKIPPED=$(( SKIPPED + 1 ))
        printf '[slop-check] ERROR  EMOJI: python3 failed (rc=%d) -- emoji check skipped\n' "$_emoji_rc" >&2
        cat "$_EMOJI_TMP" >&2
    else
        while IFS= read -r hit; do
            [[ -n "$hit" ]] && log_warn "EMOJI" "$hit"
        done < "$_EMOJI_TMP"
    fi
else
    category_enabled "EMOJI" && SKIPPED=$(( SKIPPED + 1 ))
    printf '[slop-check] WARN   EMOJI: python3 not found -- emoji check skipped\n' >&2
fi

# ---------------------------------------------------------------------------
# Every pattern-match loop below used to run `grep ... || true`, which
# collapses "no match" (grep exit 1, benign) and a genuine grep failure
# (exit >=2 -- bad regex, I/O error, OOM) into the identical empty result:
# a real scan failure silently reported the same as clean content. Found via
# code-review-battery, live-reproduced with a stubbed grep that always exits
# 2: an unambiguous blocking BUZZWORD ("unlock") was reported clean. This
# helper applies this file's own fail-closed discipline (already used for
# the python3 calls above) to grep too.
#
# MUST be called via command substitution (`x="$(scan_pattern ...)"`), never
# process substitution (`< <(scan_pattern ...)`): process substitution runs
# in a detached subshell whose exit status the parent shell never waits for
# or inspects, so an `exit 2` inside it is silently discarded -- confirmed
# empirically; the first cut of this fix used process substitution and the
# exit-2 path was completely unreachable from the caller. Command
# substitution's exit status IS visible to the caller, and a bare (non-if)
# assignment failing aborts the whole script immediately under `set -e`.
# The command itself, not a negated `!` form, is the if-condition here for
# the same reason documented at the URL-redaction and em-dash checks above:
# `$?` after `if ! cmd; then` is the logical NOT of the real exit code, not
# the real code.
# ---------------------------------------------------------------------------
scan_pattern() {
    local full_pattern="$1"
    local hits rc
    if hits="$(grep -in "$full_pattern" "$SCAN_FILE")"; then
        rc=0
    else
        rc=$?
    fi
    if [[ $rc -ge 2 ]]; then
        printf '[slop-check] ERROR  SCAN: grep failed (rc=%d) matching pattern -- ABORT, do not infer PASS\n' "$rc" >&2
        exit 2
    fi
    printf '%s' "$hits"
}

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
    _hits="$(scan_pattern "\b${pat}\b")"
    while IFS= read -r hit; do
        [[ -n "$hit" ]] && log_block "BOOSTER" "$hit"
    done <<< "$_hits"
done

# ---------------------------------------------------------------------------
# Cat 1: weak intensifiers — advisory only, never block
# ---------------------------------------------------------------------------
declare -a WEAK_INTENSIFIERS=(
    'very' 'extremely' 'incredibly' 'quite' 'rather'
    'really' 'highly' 'truly' 'absolutely' 'definitely'
)
for pat in "${WEAK_INTENSIFIERS[@]}"; do
    _hits="$(scan_pattern "\b${pat}\b")"
    while IFS= read -r hit; do
        [[ -n "$hit" ]] && log_warn "INTENSIFIER" "$hit"
    done <<< "$_hits"
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
    'crucial' 'invaluable'
)
# Advisory-only buzzwords: common in legitimate technical prose; flag but do not block.
declare -a BUZZWORDS_ADVISORY=(
    'enhance' 'dynamic' 'agile' 'ecosystem' 'facilitate' 'accelerate'
)
for pat in "${BUZZWORDS[@]}"; do
    _hits="$(scan_pattern "\b${pat}\b")"
    while IFS= read -r hit; do
        [[ -n "$hit" ]] && log_block "BUZZWORD" "$hit"
    done <<< "$_hits"
done
for pat in "${BUZZWORDS_ADVISORY[@]}"; do
    _hits="$(scan_pattern "\b${pat}\b")"
    while IFS= read -r hit; do
        [[ -n "$hit" ]] && log_warn "BUZZWORD" "$hit"
    done <<< "$_hits"
done

# ---------------------------------------------------------------------------
# Cat 3: filler openers (blocking)
#
# 'every sustainable system', 'plays a crucial/vital role', and
# 'seamlessly integrat' were carried over from the retired
# tools/wiki-content-check.sh's own inline SLOP_PATTERNS list (dropped by
# accident when that script was refactored to delegate here); they predate
# detecting-ai-slop/reference.md and are not yet cross-listed there.
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
    "in the modern"
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
    "every sustainable system"
    "plays a crucial role"
    "plays a vital role"
    "seamlessly integrat"
)
for pat in "${FILLERS[@]}"; do
    _hits="$(scan_pattern "$pat")"
    while IFS= read -r hit; do
        [[ -n "$hit" ]] && log_block "FILLER" "$hit"
    done <<< "$_hits"
done

# Advisory-only fillers: common connector phrasing in legitimate technical
# prose (e.g. "when it comes to configuring retries..."); flag but do not
# block. Demoted here after cr-battery review found both blocked plausible
# non-slop engineering sentences with no other AI-tell present.
declare -a FILLERS_ADVISORY=(
    "at its core,"
    "when it comes to"
)
for pat in "${FILLERS_ADVISORY[@]}"; do
    _hits="$(scan_pattern "$pat")"
    while IFS= read -r hit; do
        [[ -n "$hit" ]] && log_warn "FILLER" "$hit"
    done <<< "$_hits"
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

# A scan that could not run is not a clean scan. Exiting 0 here told callers the
# content was checked when it was not, and callers now gate comment writes on
# this code, so the content would post unscanned. Exit 2 is "could not run",
# which is what actually happened.
if [[ "$SKIPPED" -gt 0 ]]; then
    printf '[slop-check] %d requested category/categories could not be evaluated -- NOT a clean result\n' "$SKIPPED" >&2
    exit 2
fi
exit 0

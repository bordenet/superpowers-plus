#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Script: run-llm-skill-review.sh
# PURPOSE: Write .llm-skill-review-cleared sentinel after an llm-skill-review
#          pass, ONLY once every finding and clean-dimension verdict in its
#          Evidence Requirement has been mechanically replayed and none were
#          falsified. PARALLELS tools/run-battery.sh (code-review-battery's
#          sentinel-writer, which already does this same envelope+replay step
#          for code reviews) -- this is that same rigor applied to
#          llm-skill-review's own Evidence Schema, which today is self-
#          attested only (see skills/engineering/llm-skill-review/skill.md,
#          "Enforcement Status").
#
# USAGE:   tools/run-llm-skill-review.sh --verdict PASS --min-score 9.4
#
# WHY A SEPARATE SCRIPT (not folded into run-phr.sh):
#   tools/run-phr.sh is also the sentinel-writer for genuine
#   progressive-harsh-review rounds on plans/designs that never produce an
#   Evidence Schema envelope at all -- making it require one unconditionally
#   would break that unrelated, existing use case. This script requires an
#   envelope unconditionally because llm-skill-review's OWN skill.md mandates
#   one for every finding and clean-dimension verdict; that requirement does
#   not apply to plain PHR rounds.
#
# ENVELOPE: .cr-battery-runs/<HEAD_SHA>-llm-skill-review.json (same directory
#   code-review-battery uses, gitignored, distinct filename suffix so the two
#   sentinels' envelopes for the same commit never collide), shape:
#   {"findings": [...], "clean_dimensions": [...]}, evidence-block schema
#   identical to code-review-battery's (see reference.md "Evidence Schema") --
#   verified field-compatible with tools/verify-cr-battery-evidence.js as-is,
#   zero changes needed to that verifier.
#
# WIRED INTO tools/pre-push as Gate 6 (tools/pre-push-llm-skill-review-gate.sh):
# any push touching skills/*.md, .ai-guidance/*.md, or an AGENTS.md-family
# file (AGENTS.md/CLAUDE.md/GEMINI.md/CODEX.md/COPILOT.md/AGENT.md, at any
# path depth) requires this sentinel, PASS verdict, and a combined score
# >= 9.2. This supersedes -- not supplements -- Gate 2 (code-review) and
# Gate 5 (PHR) for those file classes; neither of those gates require their
# own sentinel for them.
#
# EXIT:    0  sentinel written
#          1  invalid args / refuse / envelope missing / verifier falsified a claim
# -----------------------------------------------------------------------------
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"
if [[ -z "$REPO_ROOT" ]]; then
    REPO_ROOT="$(git -C "$SCRIPT_DIR/.." rev-parse --show-toplevel 2>/dev/null)"
fi
[[ -n "$REPO_ROOT" ]] || { echo "ERROR: cannot locate git repo" >&2; exit 1; }
cd "$REPO_ROOT"

SENTINEL="$REPO_ROOT/.llm-skill-review-cleared"
PRESERVE_DIR="$REPO_ROOT/.cr-battery-runs"

# --- Defaults & flags ---
VERDICT=""
MIN_SCORE=""
NO_ENVELOPE=0
USAGE_LINE="Usage: tools/run-llm-skill-review.sh --verdict PASS --min-score N.N [--no-envelope]"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --help|-h)
            cat <<'EOF'
Usage: tools/run-llm-skill-review.sh --verdict PASS --min-score N.N [--no-envelope]

Write .llm-skill-review-cleared sentinel after llm-skill-review clears,
ONLY once its Evidence Schema findings have been mechanically replayed.

Options:
  --verdict      PASS (required). llm-skill-review's own vocabulary also
                 has REJECT / MAJOR REVISIONS REQUIRED / PASS WITH RISKS --
                 only PASS clears this gate (see skill.md "Combining both
                 scorecards into one top-level Verdict").
  --min-score    Combined Prose/Design + LLM-Execution score, 1.0-10.0
                 (required)
  --no-envelope  Skip evidence-verifier gate (ESCAPE HATCH, loud warning).
                 Use only when llm-skill-review produced zero findings and
                 zero clean-dimension verdicts worth an envelope at all --
                 NOT a routine bypass.
  -h, --help     Show this help

Sentinel format:
  v1|<HEAD_SHA>|PASS|<UTC_TIMESTAMP>|min-score=<N>

Envelope path (when not bypassed):
  .cr-battery-runs/<HEAD_SHA>-llm-skill-review.json
  Shape: {"findings": [...], "clean_dimensions": [...]}
  See skills/engineering/llm-skill-review/reference.md, "Evidence Schema".

Exit codes:
  0  Sentinel written
  1  Invalid args / refusal / envelope missing / verifier falsified a claim
EOF
            exit 0
            ;;
        --verdict)
            [[ $# -ge 2 ]] || { echo "ERROR: --verdict requires a value (PASS)" >&2; exit 1; }
            VERDICT="$2"; shift 2 ;;
        --verdict=*)
            VERDICT="${1#--verdict=}"; shift ;;
        --min-score)
            [[ $# -ge 2 ]] || { echo "ERROR: --min-score requires a value (1.0-10.0)" >&2; exit 1; }
            MIN_SCORE="$2"; shift 2 ;;
        --min-score=*)
            MIN_SCORE="${1#--min-score=}"; shift ;;
        --no-envelope)
            NO_ENVELOPE=1; shift ;;
        *)
            echo "ERROR: unknown flag '$1'" >&2
            echo "$USAGE_LINE" >&2
            exit 1
            ;;
    esac
done

# --- Validate ---
if [[ -z "$VERDICT" || -z "$MIN_SCORE" ]]; then
    echo "ERROR: --verdict and --min-score are both required" >&2
    echo "$USAGE_LINE" >&2
    exit 1
fi

if [[ "$VERDICT" != "PASS" ]]; then
    echo "ERROR: invalid verdict '$VERDICT'. Only PASS clears the gate." >&2
    echo "  REJECT / MAJOR REVISIONS REQUIRED / PASS WITH RISKS all mean" >&2
    echo "  fix findings (or run another round) before writing the sentinel." >&2
    exit 1
fi

if ! [[ "$MIN_SCORE" =~ ^[0-9]+(\.[0-9]+)?$ ]] || \
   ! LC_ALL=C awk -v s="$MIN_SCORE" 'BEGIN { exit !(s >= 1.0 && s <= 10.0) }'; then
    echo "ERROR: invalid --min-score '$MIN_SCORE'. Must be 1.0-10.0." >&2
    exit 1
fi

# --- Refuse if worktree has unstaged modifications (parity with run-phr.sh). ---
if ! git diff --quiet -- ':!.llm-skill-review-cleared' 2>/dev/null; then
    echo "ERROR: unstaged modifications detected." >&2
    echo "  This review runs against a specific snapshot. Stage or stash" >&2
    echo "  unstaged changes before writing the sentinel, otherwise the" >&2
    echo "  sentinel claims more was reviewed than actually was." >&2
    exit 1
fi

SENTINEL_SHA="$(git rev-parse HEAD)"

# --- Evidence envelope + replay verification (the actual parity fix) ---
if [[ "$NO_ENVELOPE" == "1" ]]; then
    echo "WARNING: --no-envelope bypass active. Evidence replay SKIPPED." >&2
    echo "  The sentinel will be written WITHOUT verifier confirmation." >&2
    echo "" >&2
else
    mkdir -p "$PRESERVE_DIR" 2>/dev/null || true
    PRESERVE_FILE="$PRESERVE_DIR/${SENTINEL_SHA}-llm-skill-review.json"

    if [[ ! -s "$PRESERVE_FILE" ]]; then
        echo "ERROR: Evidence envelope not found: .cr-battery-runs/${SENTINEL_SHA}-llm-skill-review.json" >&2
        echo "" >&2
        echo "  Before calling this script, write llm-skill-review's aggregated" >&2
        echo "  findings + clean-dimension verdicts as a JSON envelope to this path." >&2
        echo "  See skills/engineering/llm-skill-review/reference.md, 'Evidence Schema'." >&2
        echo "" >&2
        echo "  Quick-start (empty envelope -- no findings recorded):" >&2
        echo "    mkdir -p .cr-battery-runs" >&2
        echo "    echo '{\"findings\":[],\"clean_dimensions\":[]}' > .cr-battery-runs/${SENTINEL_SHA}-llm-skill-review.json" >&2
        echo "  then re-run. Or pass --no-envelope to bypass (prints a warning and continues)." >&2
        echo "" >&2
        echo "  Sentinel NOT written." >&2
        exit 1
    fi

    if command -v jq >/dev/null 2>&1; then
        if ! jq -e . "$PRESERVE_FILE" >/dev/null 2>&1; then
            echo "ERROR: envelope is not valid JSON: $PRESERVE_FILE" >&2
            echo "  Sentinel NOT written." >&2
            exit 1
        fi
    fi

    VERIFIER="$SCRIPT_DIR/verify-cr-battery-evidence.js"
    if [[ ! -f "$VERIFIER" ]] || [[ -L "$VERIFIER" ]]; then
        # Unlike run-battery.sh's Standard Mode (where a missing verifier
        # degrades gracefully), this script's whole purpose is mandatory
        # replay -- silently skipping when the verifier can't be found would
        # write a sentinel claiming evidence was mechanically checked when it
        # never was. Hard error instead.
        echo "ERROR: evidence-replay verifier not found or is a symlink: $VERIFIER" >&2
        echo "  Cannot mechanically verify evidence without it. Sentinel NOT written." >&2
        echo "  Pass --no-envelope only if you accept writing an unverified sentinel." >&2
        exit 1
    fi
    if command -v node >/dev/null 2>&1; then
        echo "--- llm-skill-review evidence-replay verifier ---"
        set +e
        node "$VERIFIER" "$PRESERVE_FILE" --cwd "$REPO_ROOT"
        VERIFIER_EXIT=$?
        set -e
        if [[ $VERIFIER_EXIT -eq 1 ]]; then
            echo "ERROR: verifier found FALSIFIED reviewer claims. Recompute score" >&2
            echo "  with dimension caps and re-dispatch the affected persona/check." >&2
            echo "  Sentinel NOT written." >&2
            exit 1
        elif [[ $VERIFIER_EXIT -ne 0 ]]; then
            echo "ERROR: verifier exited $VERIFIER_EXIT (usage/IO/parse error). Sentinel NOT written." >&2
            exit 1
        fi
        echo ""
    else
        echo "ERROR: node not on PATH -- required for evidence-replay verifier." >&2
        echo "  Install Node.js and re-run, or pass --no-envelope to bypass." >&2
        echo "  Sentinel NOT written." >&2
        exit 1
    fi
fi

# --- Write sentinel ---
TIMESTAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

echo "v1|${SENTINEL_SHA}|${VERDICT}|${TIMESTAMP}|min-score=${MIN_SCORE}" > "$SENTINEL"
chmod 0644 "$SENTINEL" 2>/dev/null || true

echo "==========================================================="
echo "  LLM-SKILL-REVIEW PASSED -- sentinel written."
echo ""
echo "  Verdict:   ${VERDICT}"
echo "  Min-score: ${MIN_SCORE}"
echo "  Commit:    ${SENTINEL_SHA:0:8}"
echo "  Timestamp: ${TIMESTAMP}"
echo ""
echo "  This sentinel is required by tools/pre-push Gate 6 for any push"
echo "  touching skills/*.md, .ai-guidance/*.md, or an AGENTS.md-family file --"
echo "  it supersedes PHR and code-review-battery for those file classes."
echo ""
echo "  IMPORTANT: do NOT commit .llm-skill-review-cleared. The sentinel"
echo "  expires if HEAD moves. Re-run this script if you make additional"
echo "  commits."
echo "==========================================================="

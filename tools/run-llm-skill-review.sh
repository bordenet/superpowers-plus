#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Script: run-llm-skill-review.sh
# PURPOSE: Write .llm-skill-review-cleared sentinel after an llm-skill-review
#          pass, ONLY once every finding and clean-dimension verdict in its
#          Evidence Requirement has been mechanically replayed and none were
#          falsified, AND ADR-003 pass conditions hold (verdict, unresolved
#          S0/S1, non-vacuous clean_dimensions).
#
# USAGE:   tools/run-llm-skill-review.sh --verdict PASS --min-score 8.6
#          tools/run-llm-skill-review.sh --verdict PASS_WITH_RISKS --min-score 7.5
#
# SENTINEL v2 (ADR-003):
#   v2|<HEAD_SHA>|<PASS|PASS_WITH_RISKS>|<UTC>|mean=<N>|unresolved_s0_s1=0|evidence_replay=<ok|bypassed>
#
# Gate 6 records mean as metadata; it does NOT compare mean to a numeric floor.
#
# EXIT:    0  sentinel written
#          1  invalid args / refusal / envelope missing / verifier falsified / ADR-003 gate
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
ENVELOPE_GATE="$SCRIPT_DIR/lib/llm-skill-review-envelope-gate.js"

VERDICT=""
MIN_SCORE=""
NO_ENVELOPE=0
ALLOW_S0_WAIVER=0
USAGE_LINE="Usage: tools/run-llm-skill-review.sh --verdict PASS|PASS_WITH_RISKS --min-score N.N [--allow-s0-waiver] [--no-envelope]"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --help|-h)
            cat <<'EOF'
Usage: tools/run-llm-skill-review.sh --verdict PASS|PASS_WITH_RISKS --min-score N.N
                                     [--allow-s0-waiver] [--no-envelope]

Write .llm-skill-review-cleared after llm-skill-review clears (ADR-003).

Options:
  --verdict           PASS or PASS_WITH_RISKS (required). REJECT / MAJOR
                      REVISIONS REQUIRED never clear the gate.
  --min-score         Prose/Design cross-persona mean, 1.0-10.0 (required).
                      Recorded as sentinel metadata (mean=); Gate 6 does not
                      floor-compare this number (ADR-003).
  --allow-s0-waiver   Permit an S0 finding that carries waiver.ref + rationale
                      (human PR comment URL required). Default: S0 non-waivable.
  --no-envelope       Skip evidence replay (ESCAPE HATCH, loud warning).
                      Allowed only with --verdict PASS, never PASS_WITH_RISKS.
  -h, --help          Show this help

Sentinel format (v2):
  v2|<HEAD_SHA>|<PASS|PASS_WITH_RISKS>|<UTC>|mean=<N>|unresolved_s0_s1=0|evidence_replay=<ok|bypassed>

Envelope path (when not bypassed):
  .cr-battery-runs/<HEAD_SHA>-llm-skill-review.json
  Findings MUST include severity S0|S1|S2|S3.
  Envelope MUST carry "head_sha": "<HEAD_SHA>" matching the commit being
  cleared -- the filename alone is copyable and binds nothing (ADR-003 §5).
  At least one clean_dimensions entry MUST carry replayable evidence
  ({"evidence":{"command":"...","verifiable":true}}) (ADR-003 §4).

Exit codes:
  0  Sentinel written
  1  Invalid args / refusal / envelope / verifier / ADR-003 gate failure
EOF
            exit 0
            ;;
        --verdict)
            [[ $# -ge 2 ]] || { echo "ERROR: --verdict requires a value" >&2; exit 1; }
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
        --allow-s0-waiver)
            ALLOW_S0_WAIVER=1; shift ;;
        *)
            echo "ERROR: unknown flag '$1'" >&2
            echo "$USAGE_LINE" >&2
            exit 1
            ;;
    esac
done

if [[ -z "$VERDICT" || -z "$MIN_SCORE" ]]; then
    echo "ERROR: --verdict and --min-score are both required" >&2
    echo "$USAGE_LINE" >&2
    exit 1
fi

if [[ "$VERDICT" != "PASS" && "$VERDICT" != "PASS_WITH_RISKS" ]]; then
    echo "ERROR: invalid verdict '$VERDICT'." >&2
    echo "  Only PASS or PASS_WITH_RISKS clear the gate (ADR-003)." >&2
    echo "  REJECT / MAJOR REVISIONS REQUIRED mean fix findings first." >&2
    exit 1
fi

if ! [[ "$MIN_SCORE" =~ ^[0-9]+(\.[0-9]+)?$ ]] || \
   ! LC_ALL=C awk -v s="$MIN_SCORE" 'BEGIN { exit !(s >= 1.0 && s <= 10.0) }'; then
    echo "ERROR: invalid --min-score '$MIN_SCORE'. Must be 1.0-10.0." >&2
    exit 1
fi

if [[ "$NO_ENVELOPE" == "1" && "$VERDICT" == "PASS_WITH_RISKS" ]]; then
    echo "ERROR: --no-envelope is disallowed with --verdict PASS_WITH_RISKS (ADR-003 §4)." >&2
    exit 1
fi

if ! git diff --quiet -- ':!.llm-skill-review-cleared' 2>/dev/null; then
    echo "ERROR: unstaged modifications detected." >&2
    echo "  This review runs against a specific snapshot. Stage or stash" >&2
    echo "  unstaged changes before writing the sentinel, otherwise the" >&2
    echo "  sentinel claims more was reviewed than actually was." >&2
    exit 1
fi

SENTINEL_SHA="$(git rev-parse HEAD)"
EVIDENCE_REPLAY="ok"

if [[ "$NO_ENVELOPE" == "1" ]]; then
    echo "WARNING: --no-envelope bypass active. Evidence replay SKIPPED." >&2
    echo "  The sentinel will be written WITHOUT verifier confirmation." >&2
    echo "" >&2
    EVIDENCE_REPLAY="bypassed"
else
    mkdir -p "$PRESERVE_DIR" 2>/dev/null || true
    PRESERVE_FILE="$PRESERVE_DIR/${SENTINEL_SHA}-llm-skill-review.json"

    if [[ ! -s "$PRESERVE_FILE" ]]; then
        echo "ERROR: Evidence envelope not found: .cr-battery-runs/${SENTINEL_SHA}-llm-skill-review.json" >&2
        echo "" >&2
        echo "  Before calling this script, write llm-skill-review's aggregated" >&2
        echo "  findings + clean-dimension verdicts as a JSON envelope to this path." >&2
        echo "  See skills/engineering/llm-skill-review/reference.md, 'Evidence Schema'." >&2
        echo "  Findings MUST include severity. The envelope MUST carry" >&2
        echo "  \"head_sha\": \"${SENTINEL_SHA}\", and at least one clean_dimensions" >&2
        echo "  entry MUST carry {\"evidence\":{\"command\":...,\"verifiable\":true}}." >&2
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
        echo "ERROR: evidence-replay verifier not found or is a symlink: $VERIFIER" >&2
        echo "  Cannot mechanically verify evidence without it. Sentinel NOT written." >&2
        exit 1
    fi
    if [[ ! -f "$ENVELOPE_GATE" ]] || [[ -L "$ENVELOPE_GATE" ]]; then
        echo "ERROR: ADR-003 envelope gate not found: $ENVELOPE_GATE" >&2
        echo "  Sentinel NOT written." >&2
        exit 1
    fi
    if ! command -v node >/dev/null 2>&1; then
        echo "ERROR: node not on PATH -- required for evidence-replay + ADR-003 gate." >&2
        echo "  Sentinel NOT written." >&2
        exit 1
    fi

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

    echo "--- llm-skill-review ADR-003 envelope gate ---"
    GATE_ARGS=("$ENVELOPE_GATE" "$PRESERVE_FILE" --head-sha "$SENTINEL_SHA")
    if [[ "$ALLOW_S0_WAIVER" == "1" ]]; then
        GATE_ARGS+=(--allow-s0-waiver)
    fi
    set +e
    node "${GATE_ARGS[@]}"
    GATE_EXIT=$?
    set -e
    if [[ $GATE_EXIT -ne 0 ]]; then
        echo "  Sentinel NOT written." >&2
        exit 1
    fi
    echo ""
fi

TIMESTAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "v2|${SENTINEL_SHA}|${VERDICT}|${TIMESTAMP}|mean=${MIN_SCORE}|unresolved_s0_s1=0|evidence_replay=${EVIDENCE_REPLAY}" > "$SENTINEL"
chmod 0644 "$SENTINEL" 2>/dev/null || true

echo "==========================================================="
echo "  LLM-SKILL-REVIEW PASSED -- sentinel written (v2 / ADR-003)."
echo ""
echo "  Verdict:          ${VERDICT}"
echo "  Mean (metadata):  ${MIN_SCORE}"
echo "  unresolved_s0_s1: 0"
echo "  evidence_replay:  ${EVIDENCE_REPLAY}"
echo "  Commit:           ${SENTINEL_SHA:0:8}"
echo "  Timestamp:        ${TIMESTAMP}"
echo ""
echo "  Gate 6 verifies schema + unresolved_s0_s1=0 + evidence_replay;"
echo "  it does not floor-compare mean (ADR-003)."
echo ""
echo "  IMPORTANT: do NOT commit .llm-skill-review-cleared. The sentinel"
echo "  expires if HEAD moves. Re-run this script if you make additional"
echo "  commits."
echo "==========================================================="

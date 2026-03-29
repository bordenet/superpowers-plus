#!/usr/bin/env bash
# Forked Debugging Experiment Harness
# Runs scenarios under different conditions and records results.
#
# Usage: ./run-experiment.sh <condition> <scenario> [--runs N]
#   condition: A (single-agent) | B (naive-multi) | C (conductor-led)
#   scenario:  S1 | S2 | S3 | S4 | S5
#   --runs N:  number of runs per cell (default: 3)
#
# Output: exercises/forked-debugging/results/<condition>-<scenario>-<run>.json

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_DIR="${SCRIPT_DIR}/results"
FIXTURES_DIR="${SCRIPT_DIR}/fixtures"

# Defaults
RUNS=3

usage() {
    echo "Usage: $0 <condition> <scenario> [--runs N]"
    echo "  condition: A | B | C"
    echo "  scenario:  S1 | S2 | S3 | S4 | S5"
    echo "  --runs N:  repetitions (default: 3)"
    exit 1
}

# Parse args
[[ $# -lt 2 ]] && usage
CONDITION="$1"
SCENARIO="$2"
shift 2

while [[ $# -gt 0 ]]; do
    case "$1" in
        --runs) RUNS="$2"; shift 2 ;;
        *) usage ;;
    esac
done

# Validate
[[ "$CONDITION" =~ ^[ABC]$ ]] || { echo "Error: condition must be A, B, or C"; exit 1; }
[[ "$SCENARIO" =~ ^S[1-5]$ ]] || { echo "Error: scenario must be S1–S5"; exit 1; }

FIXTURE_FILE="${FIXTURES_DIR}/${SCENARIO}.json"
if [[ ! -f "$FIXTURE_FILE" ]]; then
    echo "Error: Fixture not found: ${FIXTURE_FILE}"
    echo "Create scenario fixtures first. See experiment-matrix.md."
    exit 1
fi

mkdir -p "$RESULTS_DIR"

echo "=== Forked Debugging Experiment ==="
echo "Condition: ${CONDITION}"
echo "Scenario:  ${SCENARIO}"
echo "Runs:      ${RUNS}"
echo "Fixture:   ${FIXTURE_FILE}"
echo ""

for run in $(seq 1 "$RUNS"); do
    RESULT_FILE="${RESULTS_DIR}/${CONDITION}-${SCENARIO}-run${run}.json"
    echo "--- Run ${run}/${RUNS} ---"
    START_TIME=$(date +%s)

    # Load fixture
    INCIDENT_DESC=$(python3 -c "import json,sys; d=json.load(open('${FIXTURE_FILE}')); print(d['incident_description'])")
    GROUND_TRUTH=$(python3 -c "import json,sys; d=json.load(open('${FIXTURE_FILE}')); print(d['root_cause'])")

    case "$CONDITION" in
        A)
            echo "  Mode: Single-agent (systematic-debugging)"
            # In real experiment: dispatch single sub-agent with systematic-debugging prompt
            # For now: record placeholder
            ;;
        B)
            echo "  Mode: Naive multi-agent (3 independent, majority vote)"
            # In real experiment: dispatch 3 independent sub-agents, aggregate
            ;;
        C)
            echo "  Mode: Conductor-led (debug-conductor)"
            # In real experiment: dispatch conductor sub-agent
            ;;
    esac

    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))

    # Write result skeleton
    cat > "$RESULT_FILE" <<EOF
{
  "condition": "${CONDITION}",
  "scenario": "${SCENARIO}",
  "run": ${run},
  "startTime": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "durationSeconds": ${DURATION},
  "groundTruth": $(python3 -c "import json; print(json.dumps('${GROUND_TRUTH}'))"),
  "metrics": {
    "timeToFirstHypothesisSeconds": null,
    "timeToValidatedRootCauseSeconds": null,
    "wrongHypothesesPursued": null,
    "evidenceQuality": null,
    "duplicateWork": null,
    "operatorReadability": null,
    "tokenCost": null,
    "actionable": null
  },
  "incidentPacket": null,
  "notes": "Placeholder — implement agent dispatch in Wave 3"
}
EOF

    echo "  Result: ${RESULT_FILE}"
    echo ""
done

echo "=== Experiment complete: ${CONDITION}-${SCENARIO} (${RUNS} runs) ==="
echo "Results in: ${RESULTS_DIR}/"

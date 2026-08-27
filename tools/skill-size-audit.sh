#!/usr/bin/env bash
# tools/skill-size-audit.sh -- rank installed skills by resident size
#
# Scans skills/**/skill.md (excluding _archive), sorts by byte count descending,
# and flags entries that exceed the fleet-wide threshold (default: 10,240 bytes).
#
# Usage:
#   skill-size-audit.sh [--threshold BYTES] [--top N] [--json]
#
# Options:
#   --threshold BYTES   Flag threshold in bytes (default: 10240 = 10 KB)
#   --top N             Show only the top N skills (default: all)
#   --json              Emit machine-readable JSON array instead of table
#
# Exit codes:
#   0  No skills exceed the threshold
#   1  One or more skills exceed the threshold (flagged in output)
#   2  Argument error
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
THRESHOLD=10240  # 10 KB
TOP_N=0          # 0 = all
JSON_MODE=0

# --- argument parsing ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    --threshold)
      [[ $# -lt 2 ]] && { echo "ERROR: --threshold requires a value" >&2; exit 2; }
      [[ "$2" =~ ^[0-9]+$ ]] || { echo "ERROR: --threshold must be a positive integer, got: $2" >&2; exit 2; }
      THRESHOLD="$2"; shift 2 ;;
    --top)
      [[ $# -lt 2 ]] && { echo "ERROR: --top requires a value" >&2; exit 2; }
      [[ "$2" =~ ^[0-9]+$ ]] || { echo "ERROR: --top must be a positive integer, got: $2" >&2; exit 2; }
      TOP_N="$2"; shift 2 ;;
    --json)
      JSON_MODE=1; shift ;;
    --help|-h)
      head -20 "$0" | grep '^#[^!]' | sed 's/^# \?//'
      exit 0 ;;
    *)
      echo "ERROR: unknown flag: $1" >&2; exit 2 ;;
  esac
done

cd "$REPO_ROOT"

# Guard: abort cleanly when skills/ tree is absent (e.g., wrong working dir).
if [[ -z "$(find skills -name skill.md 2>/dev/null | head -1)" ]]; then
  echo "ERROR: No skills found -- run from the repo root (skills/**/skill.md not found)" >&2
  exit 2
fi

# Collect sizes: "bytes path" lines, excluding _archive entries.
mapfile -t SIZE_LINES < <(
  find skills -name "skill.md" ! -path "*/_archive/*" -exec wc -c {} \; \
    | awk '{print $1, $2}' \
    | sort -rn
)

over_threshold=0

if [[ "$JSON_MODE" -eq 1 ]]; then
  # JSON output: array of objects {rank, path, bytes, flagged}
  echo "["
  rank=1
  count="${#SIZE_LINES[@]}"
  for line in "${SIZE_LINES[@]}"; do
    [[ "$TOP_N" -gt 0 && "$rank" -gt "$TOP_N" ]] && break
    bytes="${line%% *}"
    path="${line#* }"
    flagged="false"
    [[ "$bytes" -gt "$THRESHOLD" ]] && flagged="true" && over_threshold=1
    comma=","
    [[ "$rank" -eq "$count" || ("$TOP_N" -gt 0 && "$rank" -eq "$TOP_N") ]] && comma=""
    printf '  {"rank":%d,"path":"%s","bytes":%s,"flagged":%s}%s\n' \
      "$rank" "$path" "$bytes" "$flagged" "$comma"
    (( rank++ )) || true
  done
  echo "]"
else
  # Human-readable table
  threshold_kb=$(( THRESHOLD / 1024 ))
  printf "%-6s %-8s %-6s %s\n" "RANK" "BYTES" "STATUS" "SKILL PATH"
  printf "%-6s %-8s %-6s %s\n" "----" "-----" "------" "----------"
  rank=1
  for line in "${SIZE_LINES[@]}"; do
    [[ "$TOP_N" -gt 0 && "$rank" -gt "$TOP_N" ]] && break
    bytes="${line%% *}"
    path="${line#* }"
    status="ok"
    if [[ "$bytes" -gt "$THRESHOLD" ]]; then
      status="OVER"
      over_threshold=1
    fi
    printf "%-6s %-8s %-6s %s\n" "$rank" "$bytes" "$status" "$path"
    (( rank++ )) || true
  done
  echo ""
  echo "Threshold: ${THRESHOLD} bytes (${threshold_kb} KB)"
  total="${#SIZE_LINES[@]}"
  shown=$(( TOP_N > 0 && TOP_N < total ? TOP_N : total ))
  echo "Skills shown: ${shown} of ${total}"
  [[ "$over_threshold" -eq 1 ]] && echo "WARNING: One or more skills exceed the ${threshold_kb} KB threshold -- consider spc-kernel-split."
fi

exit "$over_threshold"

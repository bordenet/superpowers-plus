#!/usr/bin/env bash
# test_tool_help.sh — Verify every referenced tool responds sensibly to --help
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PASS=0
FAIL=0

for tool in loose-ends.sh run-battery.sh backfill-composition.sh \
            wiki-read.sh wiki-write.sh parse-frontmatter.sh \
            todo-crud.sh skill-cost-analyzer.sh test-content-coherence.sh; do
    # Use || true to absorb SIGPIPE (141) when head -5 closes the pipe early
    out=$({ "$ROOT/tools/$tool" --help 2>&1 || true; } | head -5) || true
    if [[ "$out" != *"Usage"* && "$out" != *"usage"* ]] \
    || [[ "$out" == *"compat.sh — Cross-platform"* ]]; then
        echo "FAIL: $tool --help → '$(echo "$out" | head -1)'"
        FAIL=$((FAIL + 1))
    else
        echo "  ok: $tool --help"
        PASS=$((PASS + 1))
    fi
done

echo "── $PASS passed, $FAIL failed ──"
[[ "$FAIL" -eq 0 ]]

#!/usr/bin/env bats
# Tests for the cr-battery Phase 6 preservation gate in tools/run-battery.sh.
#
# Contract (per skills/engineering/code-review-battery/skill.md Phase 6):
# - If .cr-battery-runs/ exists at repo root, run-battery.sh refuses to
#   write the sentinel unless .cr-battery-runs/<HEAD-sha>.json exists and
#   is non-empty.
# - If .cr-battery-runs/ does NOT exist, or if --staged mode is active, the
#   check is skipped (graceful degradation).

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

setup() {
    TEST_REPO="$(mktemp -d)"
    pushd "$TEST_REPO" >/dev/null
    git init -q
    git config user.email "test@example.com"
    git config user.name "Test"
    mkdir -p tools
    # Copy the live run-battery.sh and stub every step the gate sits behind
    # so the gate itself is the unit under test (not the upstream steps).
    cp "$REPO_ROOT/tools/run-battery.sh" tools/
    chmod +x tools/run-battery.sh
    mkdir -p tools/tests test
    # Step 1: harsh-review.sh (next to run-battery.sh).
    printf '#!/usr/bin/env bash\nexit 0\n' > tools/harsh-review.sh
    # Steps 2, 3: tools/tests/*.sh.
    printf '#!/usr/bin/env bash\nexit 0\n' > tools/tests/test_trigger_routing.sh
    printf '#!/usr/bin/env bash\nexit 0\n' > tools/tests/test_augment_export.sh
    # Step 4: node test/skill-router.test.js (repo-root level, not tools/).
    printf 'process.exit(0)\n' > test/skill-router.test.js
    # md-files-changed.sh -- used by the post-success PHR reminder. Exit 1
    # means "no PHR-relevant files changed", which is the silent path.
    printf '#!/usr/bin/env bash\nexit 1\n' > tools/md-files-changed.sh
    chmod +x tools/harsh-review.sh tools/tests/*.sh tools/md-files-changed.sh
    echo "placeholder" > README.md
    git add -A
    git commit -q -m "initial"
}

teardown() {
    popd >/dev/null
    rm -rf "$TEST_REPO"
}

@test "sentinel writes when .cr-battery-runs/ is absent (legacy path)" {
    run tools/run-battery.sh --verdict PASS --min-score 7.0
    # Legacy path: directory absent, gate skipped, all stubbed steps return
    # 0, so the script must reach a clean PASS and write the sentinel.
    [ "$status" -eq 0 ]
    [ -f .code-review-cleared ]
    [[ "$output" != *"cr-battery preservation file missing"* ]]
}

@test "gate rejects malformed JSON via jq (if jq available)" {
    if ! command -v jq >/dev/null 2>&1; then
        skip "jq not installed -- gate falls back to size-only check"
    fi
    SHA=$(git rev-parse HEAD)
    mkdir -p .cr-battery-runs
    # 1-byte garbage file: passes -s but fails JSON validation.
    printf 'x' > ".cr-battery-runs/${SHA}.json"
    run tools/run-battery.sh --verdict PASS --min-score 7.0
    [ "$status" -ne 0 ]
    [ ! -f .code-review-cleared ]
    [[ "$output" == *"not valid JSON"* ]]
}

@test "sentinel does NOT write when .cr-battery-runs/ exists but per-HEAD JSON is missing" {
    mkdir -p .cr-battery-runs
    # Stub the internal steps so they pass, isolating the preservation gate.
    # All step stubs are already set up in setup() to return 0; gate is the
    # unit under test.
    run tools/run-battery.sh --verdict PASS --min-score 7.0
    [ "$status" -ne 0 ]
    [ ! -f .code-review-cleared ]
    [[ "$output" == *"Evidence envelope not found"* ]]
}

@test "sentinel writes when .cr-battery-runs/<sha>.json exists and is non-empty" {
    SHA=$(git rev-parse HEAD)
    mkdir -p .cr-battery-runs
    echo '{"head_sha":"'"$SHA"'","verdict":"PASS"}' > ".cr-battery-runs/${SHA}.json"
    # All step stubs are already set up in setup() to return 0; gate is the
    # unit under test.
    run tools/run-battery.sh --verdict PASS --min-score 7.0
    [ "$status" -eq 0 ]
    [ -f .code-review-cleared ]
}

@test "preservation gate is skipped in --staged mode" {
    # In --staged mode the sentinel records the tree SHA, not HEAD SHA.
    # The preservation file is keyed by HEAD SHA, which in --staged context
    # refers to the prior commit -- not what's being reviewed. Gate skip is
    # the documented graceful degradation.
    mkdir -p .cr-battery-runs
    # No per-HEAD JSON exists; in HEAD mode this would fail, in --staged it
    # should pass the gate (other steps may still fail; the gate is the unit).
    # All step stubs are already set up in setup() to return 0; gate is the
    # unit under test.
    # Stage something so --staged has a non-empty index.
    echo "staged change" >> README.md
    git add README.md
    run tools/run-battery.sh --verdict PASS --min-score 7.0 --staged
    # The gate should NOT block (--staged mode skips it). Other failure modes
    # may still apply, but the specific gate error message must not appear.
    [[ "$output" != *"cr-battery preservation file missing"* ]]
}

#!/usr/bin/env bats

# Behavioral tests for tools/push-readiness.sh.
#
# WHY THIS TOOL EXISTS (agent DX, 2026-08-26): the only way to learn that a
# push would be rejected was to attempt one, and Gate 1 runs 600+ tests --
# longer than the 120s cap on an agent's foreground command. Two pushes were
# SIGKILLed mid-gate in one session before Gate 6's requirement was found, and
# a killed run is indistinguishable from a failed one in the log.
#
# THE CRITICAL INVARIANT: this tool must be READ-ONLY. pre-push-branch-flow-gate.sh
# CONSUMES its sentinel on success, so a readiness check that invoked the real
# gates would destroy the clearance the actual push then needs. The tests below
# assert that no sentinel is modified, moved, or consumed by a readiness run.

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
SCRIPT="$REPO_ROOT/tools/push-readiness.sh"

setup() {
    WORK="$BATS_TEST_TMPDIR/repo"
    mkdir -p "$WORK"
    cd "$WORK"
    git init -q -b main .
    git config user.email "test@example.com"
    git config user.name "Test"
    git config commit.gpgsign false
    # The tool resolves requirements via tools/review.sh, so the harness repo
    # needs those tools present.
    mkdir -p test
    # which-gate.sh EXTRACTS the real detection logic out of the gate scripts,
    # so a partial tools/ tree makes it exit 2 and routing fails. Copy the
    # whole directory: the point of these tests is the real routing path, not
    # a stub of it.
    cp -R "$REPO_ROOT/tools" tools
    printf 'seed\n' > seed.txt
    git add -A
    git commit -qm "seed"
    git branch -q base-ref
}

@test "--help exits 0 and documents the read-only contract" {
    run "$SCRIPT" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"READ-ONLY"* ]]
}

@test "unknown argument is a usage error" {
    run "$SCRIPT" --bogus
    [ "$status" -eq 2 ]
}

@test "nonexistent target ref is a usage error, not a verdict" {
    run "$SCRIPT" --target no/such/ref
    [ "$status" -eq 2 ]
    [[ "$output" == *"does not exist"* ]]
}

@test "no changed files -> ready, exit 0" {
    git checkout -qb feature
    run "$SCRIPT" --target base-ref
    [ "$status" -eq 0 ]
    [[ "$output" == *"no files changed"* ]]
}

@test "missing sentinel for a code change -> BLOCKED with the exact fix command" {
    git checkout -qb feature
    printf 'echo hi\n' > tools/thing.sh
    git add tools/thing.sh; git commit -qm "add a shell tool"
    run "$SCRIPT" --target base-ref
    [ "$status" -eq 1 ]
    [[ "$output" == *"BLOCKED"* ]]
    [[ "$output" == *"run-battery.sh"* ]]
}

@test "stale sentinel (wrong SHA) is reported as STALE, naming both SHAs" {
    git checkout -qb feature
    printf 'echo hi\n' > tools/thing.sh
    git add tools/thing.sh; git commit -qm "add a shell tool"
    echo "v1|0000000000000000000000000000000000000000|PASS|2026-01-01T00:00:00Z|min-score=9.0" > .code-review-cleared
    run "$SCRIPT" --target base-ref
    [ "$status" -eq 1 ]
    [[ "$output" == *"STALE"* ]]
    [[ "$output" == *"00000000"* ]]
}

@test "valid sentinel matching HEAD -> ready, exit 0" {
    git checkout -qb feature
    printf 'echo hi\n' > tools/thing.sh
    git add tools/thing.sh; git commit -qm "add a shell tool"
    HEAD_SHA="$(git rev-parse HEAD)"
    echo "v1|${HEAD_SHA}|PASS|2026-01-01T00:00:00Z|min-score=9.0" > .code-review-cleared
    run "$SCRIPT" --target base-ref
    [ "$status" -eq 0 ]
    [[ "$output" == *"[ready]"* ]]
}

@test "non-clearing verdict is BLOCKED even when the SHA matches" {
    git checkout -qb feature
    printf 'echo hi\n' > tools/thing.sh
    git add tools/thing.sh; git commit -qm "add a shell tool"
    HEAD_SHA="$(git rev-parse HEAD)"
    echo "v1|${HEAD_SHA}|REJECT|2026-01-01T00:00:00Z|min-score=3.0" > .code-review-cleared
    run "$SCRIPT" --target base-ref
    [ "$status" -eq 1 ]
    [[ "$output" == *"REJECT"* ]]
}

@test "multi-line sentinel (corruption/append) is BLOCKED" {
    git checkout -qb feature
    printf 'echo hi\n' > tools/thing.sh
    git add tools/thing.sh; git commit -qm "add a shell tool"
    HEAD_SHA="$(git rev-parse HEAD)"
    {
      echo "v1|${HEAD_SHA}|PASS|2026-01-01T00:00:00Z|min-score=9.0"
      echo "v1|${HEAD_SHA}|PASS|2026-01-01T00:00:00Z|min-score=9.0"
    } > .code-review-cleared
    run "$SCRIPT" --target base-ref
    [ "$status" -eq 1 ]
    [[ "$output" == *"malformed"* ]]
}

@test "READ-ONLY: a valid sentinel is byte-identical after a readiness run" {
    git checkout -qb feature
    printf 'echo hi\n' > tools/thing.sh
    git add tools/thing.sh; git commit -qm "add a shell tool"
    HEAD_SHA="$(git rev-parse HEAD)"
    echo "v1|${HEAD_SHA}|PASS|2026-01-01T00:00:00Z|min-score=9.0" > .code-review-cleared
    before="$(cat .code-review-cleared)"
    before_sum="$(cksum < .code-review-cleared)"
    run "$SCRIPT" --target base-ref
    [ "$status" -eq 0 ]
    [ -f .code-review-cleared ]
    [ "$(cat .code-review-cleared)" = "$before" ]
    [ "$(cksum < .code-review-cleared)" = "$before_sum" ]
}

@test "READ-ONLY: the working tree is unchanged by a readiness run" {
    git checkout -qb feature
    printf 'echo hi\n' > tools/thing.sh
    git add tools/thing.sh; git commit -qm "add a shell tool"
    before="$(git status --porcelain)"
    run "$SCRIPT" --target base-ref
    [ "$(git status --porcelain)" = "$before" ]
}

@test "dirty working tree emits an explicit warning" {
    git checkout -qb feature
    printf 'echo hi\n' > tools/thing.sh
    git add tools/thing.sh; git commit -qm "add a shell tool"
    printf 'echo changed\n' > tools/thing.sh
    run "$SCRIPT" --target base-ref
    [[ "$output" == *"uncommitted change"* ]]
}

@test "--json emits parseable output with a blockers count" {
    git checkout -qb feature
    printf 'echo hi\n' > tools/thing.sh
    git add tools/thing.sh; git commit -qm "add a shell tool"
    run "$SCRIPT" --target base-ref --json
    [ "$status" -eq 1 ]
    printf '%s' "$output" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["blockers"] >= 1; assert isinstance(d["items"], list)'
}

@test "detached HEAD is a clean usage error, not a crash" {
    git checkout -q --detach
    run "$SCRIPT" --target base-ref
    [ "$status" -eq 2 ]
    [[ "$output" == *"detached HEAD"* ]]
}

# ---------------------------------------------------------------------------
# Regression (Design Critic F1, 2026-08-27): the tool applied ONE union verdict
# set (PASS|PASS_WITH_NITS|PASS_WITH_RISKS) to EVERY sentinel, but the three
# gates disagree:
#   .code-review-cleared      PASS, PASS_WITH_NITS   (pre-push-code-review-gate.sh)
#   .llm-skill-review-cleared PASS, PASS_WITH_RISKS  (pre-push-llm-skill-review-gate.sh:116)
#   .phr-cleared              PASS only              (pre-push-phr-gate.sh:163)
# A false READY costs exactly the push round-trip this tool exists to prevent.
# ---------------------------------------------------------------------------

@test "PHR sentinel with PASS_WITH_NITS is BLOCKED (phr gate accepts PASS only)" {
    git checkout -qb feature
    mkdir -p docs
    printf '# spec\n' > docs/spec.md
    git add docs/spec.md; git commit -qm "add a doc"
    HEAD_SHA="$(git rev-parse HEAD)"
    echo "v1|${HEAD_SHA}|PASS_WITH_NITS|2026-01-01T00:00:00Z|min-score=9.0" > .phr-cleared
    run "$SCRIPT" --target base-ref
    [ "$status" -eq 1 ]
    [[ "$output" == *"PASS_WITH_NITS"* ]]
}

@test "PHR sentinel with PASS_WITH_RISKS is BLOCKED (phr gate accepts PASS only)" {
    git checkout -qb feature
    mkdir -p docs
    printf '# spec\n' > docs/spec.md
    git add docs/spec.md; git commit -qm "add a doc"
    HEAD_SHA="$(git rev-parse HEAD)"
    echo "v1|${HEAD_SHA}|PASS_WITH_RISKS|2026-01-01T00:00:00Z|min-score=9.0" > .phr-cleared
    run "$SCRIPT" --target base-ref
    [ "$status" -eq 1 ]
}

@test "PHR sentinel with plain PASS is ready" {
    git checkout -qb feature
    mkdir -p docs
    printf '# spec\n' > docs/spec.md
    git add docs/spec.md; git commit -qm "add a doc"
    HEAD_SHA="$(git rev-parse HEAD)"
    echo "v1|${HEAD_SHA}|PASS|2026-01-01T00:00:00Z|min-score=9.0" > .phr-cleared
    run "$SCRIPT" --target base-ref
    [ "$status" -eq 0 ]
}

@test "cr-battery sentinel accepts PASS_WITH_NITS but not PASS_WITH_RISKS" {
    git checkout -qb feature
    printf 'echo hi\n' > tools/thing.sh
    git add tools/thing.sh; git commit -qm "add a shell tool"
    HEAD_SHA="$(git rev-parse HEAD)"
    echo "v1|${HEAD_SHA}|PASS_WITH_NITS|2026-01-01T00:00:00Z|min-score=8.0" > .code-review-cleared
    run "$SCRIPT" --target base-ref
    [ "$status" -eq 0 ]
    echo "v1|${HEAD_SHA}|PASS_WITH_RISKS|2026-01-01T00:00:00Z|min-score=8.0" > .code-review-cleared
    run "$SCRIPT" --target base-ref
    [ "$status" -eq 1 ]
}

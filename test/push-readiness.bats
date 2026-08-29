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

# ---------------------------------------------------------------------------
# DX regression (2026-08-28): a STALE LOCAL target branch silently widens the
# diff and manufactures phantom blockers.
#
# Observed live: `--target dev` resolved to a local `dev` a month behind
# `origin/dev`. The merge-base was therefore ancient, the range covered 24 files
# instead of 6, and the extra files -- already merged upstream -- routed to the
# PHR and llm-skill-review gates. The tool reported three blockers where the
# real push needed one. It answered the question asked; the question was wrong,
# and nothing said so.
# ---------------------------------------------------------------------------

@test "stale local target branch is called out, naming the remote counterpart" {
    git checkout -q -b feature
    printf 'echo hi\n' > tools/thing.sh
    git add tools/thing.sh; git commit -qm "add a shell tool"

    # origin/base-ref advances; the LOCAL base-ref stays behind.
    git update-ref refs/remotes/origin/base-ref "$(git rev-parse HEAD)"

    run "$SCRIPT" --target base-ref
    [[ "$output" == *"behind"* ]]
    [[ "$output" == *"origin/base-ref"* ]]
}

@test "target that is level with its remote counterpart produces no staleness warning" {
    git checkout -q -b feature
    printf 'echo hi\n' > tools/thing.sh
    git add tools/thing.sh; git commit -qm "add a shell tool"
    git update-ref refs/remotes/origin/base-ref "$(git rev-parse base-ref)"

    run "$SCRIPT" --target base-ref
    [[ "$output" != *"behind"* ]]
}

@test "target with no remote counterpart at all is not flagged as stale" {
    git checkout -q -b feature
    printf 'echo hi\n' > tools/thing.sh
    git add tools/thing.sh; git commit -qm "add a shell tool"

    run "$SCRIPT" --target base-ref
    [[ "$output" != *"behind"* ]]
}

# ---------------------------------------------------------------------------
# ShellRuntimeAuditor C1/I3: bash-4-only constructs make these tools die on
# stock macOS bash 3.2 (exit 127, undocumented), and `printf | grep -q` under
# pipefail inverts its result past the 64KiB pipe buffer. Both classes have now
# bitten this codebase repeatedly, so assert the class, not the instance.
# ---------------------------------------------------------------------------
@test "no bash-4-only construct in either tool (stock macOS ships bash 3.2)" {
    # ^[[:space:]]*[^#[:space:]] skips comment lines -- the fix comments name
    # the very constructs they forbid.
    run grep -nE '^[[:space:]]*[^#[:space:]].*(mapfile|readarray|declare -A|local -n)' \
        "$REPO_ROOT/tools/push-readiness.sh" "$REPO_ROOT/tools/ci-bats-discovery.sh"
    [ "$status" -ne 0 ]
}

@test "no printf|grep -q pipeline in either tool (SIGPIPE inverts it under pipefail)" {
    run grep -nE '^[[:space:]]*[^#[:space:]].*(printf|echo)[^|]*\| *grep -q' \
        "$REPO_ROOT/tools/push-readiness.sh" "$REPO_ROOT/tools/ci-bats-discovery.sh"
    [ "$status" -ne 0 ]
}

# ---------------------------------------------------------------------------
# Review-battery parity findings: push-readiness must predict the gates' actual
# answer, including Gate 4 and every sentinel's full schema. A partial schema
# check is worse than none because it reports READY for a push the hook rejects.
# ---------------------------------------------------------------------------
@test "canonical push branch is BLOCKED without the Gate 4 branch-flow sentinel" {
    printf 'echo hi\n' > tools/thing.sh
    git add tools/thing.sh; git commit -qm "add a shell tool"
    HEAD_SHA="$(git rev-parse HEAD)"
    echo "v1|${HEAD_SHA}|PASS|2026-01-01T00:00:00Z|min-score=9.0" > .code-review-cleared

    run "$SCRIPT" --target base-ref
    [ "$status" -eq 1 ]
    [[ "$output" == *".branch-flow-cleared"* ]]
}

@test "a valid Gate 4 sentinel is reported ready without being consumed" {
    printf 'echo hi\n' > tools/thing.sh
    git add tools/thing.sh; git commit -qm "add a shell tool"
    HEAD_SHA="$(git rev-parse HEAD)"
    echo "v1|${HEAD_SHA}|PASS|2026-01-01T00:00:00Z|min-score=9.0" > .code-review-cleared
    echo "v1|${HEAD_SHA}|feature|main|2026-01-01T00:00:00Z" > .branch-flow-cleared
    before="$(cksum < .branch-flow-cleared)"

    run "$SCRIPT" --target base-ref
    [ "$status" -eq 0 ]
    [[ "$output" == *"branch-flow"* ]]
    [ -f .branch-flow-cleared ]
    [ "$(cksum < .branch-flow-cleared)" = "$before" ]
}

@test "code-review sentinel must satisfy the gate's full v1 schema" {
    git checkout -qb feature
    printf 'echo hi\n' > tools/thing.sh
    git add tools/thing.sh; git commit -qm "add a shell tool"
    HEAD_SHA="$(git rev-parse HEAD)"
    echo "v0|${HEAD_SHA}|PASS|2026-01-01T00:00:00Z|min-score=bogus" > .code-review-cleared

    run "$SCRIPT" --target base-ref
    [ "$status" -eq 1 ]
    [[ "$output" == *"format"* ]]
}

@test "PHR sentinel must validate its min-score field" {
    git checkout -qb feature
    mkdir -p docs
    printf '# spec\n' > docs/spec.md
    git add docs/spec.md; git commit -qm "add a doc"
    HEAD_SHA="$(git rev-parse HEAD)"
    echo "v1|${HEAD_SHA}|PASS|2026-01-01T00:00:00Z|score-nine" > .phr-cleared

    run "$SCRIPT" --target base-ref
    [ "$status" -eq 1 ]
    [[ "$output" == *"format"* ]]
}

@test "llm-skill-review sentinel must require v2 and unresolved_s0_s1=0" {
    git checkout -qb feature
    mkdir -p skills/demo
    printf '# demo\n' > skills/demo/skill.md
    git add skills/demo/skill.md; git commit -qm "add a skill"
    HEAD_SHA="$(git rev-parse HEAD)"
    echo "v2|${HEAD_SHA}|PASS|2026-01-01T00:00:00Z|mean=9.0|unresolved_s0_s1=1|evidence_replay=ok" > .llm-skill-review-cleared

    run "$SCRIPT" --target base-ref
    [ "$status" -eq 1 ]
    [[ "$output" == *"unresolved_s0_s1"* ]]
}

@test "trailing blank sentinel lines match the gates' non-blank line count" {
    git checkout -qb feature
    mkdir -p docs
    printf '# spec\n' > docs/spec.md
    git add docs/spec.md; git commit -qm "add a doc"
    HEAD_SHA="$(git rev-parse HEAD)"
    printf 'v1|%s|PASS|2026-01-01T00:00:00Z|min-score=9.0\n\n' "$HEAD_SHA" > .phr-cleared

    run "$SCRIPT" --target base-ref
    [ "$status" -eq 0 ]
}

@test "stale guard handles local target branches containing a slash" {
    git branch feat/base base-ref
    git checkout -qb feature
    printf 'echo hi\n' > tools/thing.sh
    git add tools/thing.sh; git commit -qm "add a shell tool"
    git update-ref refs/remotes/origin/feat/base "$(git rev-parse HEAD)"

    run "$SCRIPT" --target feat/base
    [[ "$output" == *"behind"* ]]
    [[ "$output" == *"origin/feat/base"* ]]
}

@test "stale guard honors --remote instead of hardcoding origin" {
    git checkout -qb feature
    printf 'echo hi\n' > tools/thing.sh
    git add tools/thing.sh; git commit -qm "add a shell tool"
    git update-ref refs/remotes/upstream/base-ref "$(git rev-parse HEAD)"

    run "$SCRIPT" --target base-ref --remote upstream
    [[ "$output" == *"behind"* ]]
    [[ "$output" == *"upstream/base-ref"* ]]
}

@test "--json includes dirty-tree and stale-target warnings" {
    git checkout -qb feature
    printf 'echo hi\n' > tools/thing.sh
    git add tools/thing.sh; git commit -qm "add a shell tool"
    HEAD_SHA="$(git rev-parse HEAD)"
    echo "v1|${HEAD_SHA}|PASS|2026-01-01T00:00:00Z|min-score=9.0" > .code-review-cleared
    git update-ref refs/remotes/origin/base-ref "$HEAD_SHA"
    printf 'echo dirty\n' > tools/thing.sh

    run "$SCRIPT" --target base-ref --json
    [ "$status" -eq 0 ]
    printf '%s' "$output" | python3 -c 'import json,sys; d=json.load(sys.stdin); w=" ".join(d["warnings"]); assert "behind" in w; assert "uncommitted" in w'
}

@test "--json escapes a double quote in a ref name" {
    git branch 'base"ref' base-ref
    git checkout -qb feature

    run "$SCRIPT" --target 'base"ref' --json
    [ "$status" -eq 0 ]
    printf '%s' "$output" | python3 -c 'import json,sys; assert json.load(sys.stdin)["target"] == '\''base"ref'\'''
}

@test "--help extraction is self-terminating instead of line-number bounded" {
    run grep -nE "usage\(\).*sed -n '[0-9]+,[0-9]+p'" "$REPO_ROOT/tools/push-readiness.sh"
    [ "$status" -ne 0 ]
}

# ---------------------------------------------------------------------------
# Guardian parity findings (2026-08-28): readiness must model the destination
# ref used by Gate 4, preserve partial router failures, emit an executable
# branch-flow remediation, and share Gate 2's sentinel parsing semantics.
# ---------------------------------------------------------------------------

@test "feature HEAD targeting main requires Gate 4 clearance for that destination" {
    git checkout -qb feature
    printf 'echo hi\n' > tools/thing.sh
    git add tools/thing.sh; git commit -qm "add a shell tool"
    HEAD_SHA="$(git rev-parse HEAD)"
    echo "v1|${HEAD_SHA}|PASS|2026-01-01T00:00:00Z|min-score=9.0" > .code-review-cleared

    run "$SCRIPT" --target base-ref --destination main
    [ "$status" -eq 1 ]
    [[ "$output" == *".branch-flow-cleared"* ]]
    [[ "$output" == *"feature main --sha ${HEAD_SHA}"* ]]
}

@test "Gate 4 remediation emitted for a destination push clears the next readiness run" {
    git checkout -qb feature
    printf 'echo hi\n' > tools/thing.sh
    git add tools/thing.sh; git commit -qm "add a shell tool"
    HEAD_SHA="$(git rev-parse HEAD)"
    echo "v1|${HEAD_SHA}|PASS|2026-01-01T00:00:00Z|min-score=9.0" > .code-review-cleared

    run "$SCRIPT" --target base-ref --destination main
    [ "$status" -eq 1 ]
    run tools/branch-flow-preflight.sh feature main --sha "$HEAD_SHA"
    [ "$status" -eq 0 ]
    run "$SCRIPT" --target base-ref --destination main
    [ "$status" -eq 0 ]
}

@test "canonical checkout does not invent a self-to-self branch-flow source" {
    printf 'echo hi\n' > tools/thing.sh
    git add tools/thing.sh; git commit -qm "add a shell tool"
    HEAD_SHA="$(git rev-parse HEAD)"
    echo "v1|${HEAD_SHA}|PASS|2026-01-01T00:00:00Z|min-score=9.0" > .code-review-cleared

    run "$SCRIPT" --target base-ref --destination main
    [ "$status" -eq 1 ]
    [[ "$output" == *"--source"* ]]
    [[ "$output" != *"branch-flow-preflight.sh main main"* ]]
}

@test "explicit source on a canonical checkout produces an executable remediation" {
    printf 'echo hi\n' > tools/thing.sh
    git add tools/thing.sh; git commit -qm "add a shell tool"
    git branch feature
    HEAD_SHA="$(git rev-parse HEAD)"
    echo "v1|${HEAD_SHA}|PASS|2026-01-01T00:00:00Z|min-score=9.0" > .code-review-cleared

    run "$SCRIPT" --target base-ref --destination main --source feature
    [ "$status" -eq 1 ]
    [[ "$output" == *"feature main --sha ${HEAD_SHA}"* ]]
    run tools/branch-flow-preflight.sh feature main --sha "$HEAD_SHA"
    [ "$status" -eq 0 ]
    run "$SCRIPT" --target base-ref --destination main --source feature
    [ "$status" -eq 0 ]
}

@test "partial router process failure remains a blocker even when it emitted a sentinel" {
    git checkout -qb feature
    printf 'echo hi\n' > tools/thing.sh
    git add tools/thing.sh; git commit -qm "add a shell tool"
    HEAD_SHA="$(git rev-parse HEAD)"
    echo "v1|${HEAD_SHA}|PASS|2026-01-01T00:00:00Z|min-score=9.0" > .code-review-cleared
    cat > tools/review.sh <<'EOF'
#!/usr/bin/env bash
echo 'RUNNER: tools/run-battery.sh --verdict PASS'
echo 'SENTINEL: .code-review-cleared'
echo 'ERROR: extraction failed after partial output' >&2
exit 2
EOF
    chmod +x tools/review.sh

    run "$SCRIPT" --target base-ref
    [ "$status" -eq 1 ]
    [[ "$output" == *"route failed"* ]]
    [[ "$output" == *"extraction failed"* ]]
}

@test "code sentinel with trailing whitespace has parity between readiness and Gate 2" {
    git checkout -qb feature
    printf 'echo hi\n' > tools/thing.sh
    git add tools/thing.sh; git commit -qm "add a shell tool"
    HEAD_SHA="$(git rev-parse HEAD)"
    printf 'v1|%s|PASS|2026-01-01T00:00:00Z|min-score=9.0\n   \n' "$HEAD_SHA" > .code-review-cleared

    run "$SCRIPT" --target base-ref
    [ "$status" -eq 0 ]
    run bash -c 'printf "refs/heads/feature %s refs/heads/feature 0000000000000000000000000000000000000000\n" "$1" | tools/pre-push-code-review-gate.sh origin' _ "$HEAD_SHA"
    [ "$status" -eq 0 ]
}

@test "git diff enumeration failure is a usage error, never a false no-change result" {
    git checkout -qb feature
    shim="$BATS_TEST_TMPDIR/fail-diff.sh"
    cat > "$shim" <<'EOF'
git() {
    if [[ "${1:-}:${2:-}" == "diff:--name-only" ]]; then return 42; fi
    command /usr/bin/git "$@"
}
EOF

    run env BASH_ENV="$shim" /bin/bash "$SCRIPT" --target base-ref --json
    [ "$status" -eq 2 ]
    [[ "$output" == *"enumerate changed files"* ]]
    [[ "$output" != *"no files changed"* ]]
}

@test "stock macOS Bash 3.2 emits JSON when the warnings array is empty" {
    git checkout -qb feature
    run /bin/bash "$SCRIPT" --target base-ref --json
    [ "$status" -eq 0 ]
    printf '%s' "$output" | python3 -c 'import json,sys; assert json.load(sys.stdin)["warnings"] == []'
}

@test "branch-flow remediation shell-quotes a metacharacter-bearing source ref" {
    git checkout -qb 'feat;echo_PWN'
    printf 'echo hi\n' > tools/thing.sh
    git add tools/thing.sh; git commit -qm "add a shell tool"
    HEAD_SHA="$(git rev-parse HEAD)"
    echo "v1|${HEAD_SHA}|PASS|2026-01-01T00:00:00Z|min-score=9.0" > .code-review-cleared

    run "$SCRIPT" --target base-ref --destination main
    [ "$status" -eq 1 ]
    fix="$(printf '%s\n' "$output" | sed -n 's/^[[:space:]]*fix: //p' | tail -1)"
    [[ "$fix" == *'feat\;echo_PWN'* ]]
    run bash -c "$fix"
    [ "$status" -eq 0 ]
    [ "$(cut -d'|' -f3 .branch-flow-cleared)" = 'feat;echo_PWN' ]
}

@test "no-common-ancestor target enumerates the pushed branch history instead of exiting usage-error" {
    git checkout -q --orphan orphan
    git rm -q -r --cached .
    printf 'echo orphan\n' > orphan.sh
    git add orphan.sh; git commit -qm "orphan root"
    HEAD_SHA="$(git rev-parse HEAD)"

    run "$SCRIPT" --target base-ref
    [ "$status" -eq 1 ]
    [[ "$output" == *"run-battery.sh"* ]]
    echo "v1|${HEAD_SHA}|PASS|2026-01-01T00:00:00Z|min-score=9.0" > .code-review-cleared
    run "$SCRIPT" --target base-ref
    [ "$status" -eq 0 ]
}

@test "explicit destination defaults comparison to that remote branch, not the current upstream" {
    git checkout -qb feature
    printf 'echo hi\n' > tools/thing.sh
    git add tools/thing.sh; git commit -qm "add a shell tool"
    HEAD_SHA="$(git rev-parse HEAD)"
    git update-ref refs/remotes/origin/feature "$HEAD_SHA"
    git update-ref refs/remotes/origin/main "$(git rev-parse base-ref)"
    git config branch.feature.remote origin
    git config branch.feature.merge refs/heads/feature
    echo "v1|${HEAD_SHA}|feature|main|2026-01-01T00:00:00Z" > .branch-flow-cleared

    run "$SCRIPT" --destination main
    [ "$status" -eq 1 ]
    [[ "$output" == *"comparison target: origin/main"* ]]
    [[ "$output" == *"run-battery.sh"* ]]
}

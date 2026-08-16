#!/usr/bin/env bats

# Behavioral tests for the git-history secret scan in
# skills/security/repo-security-scan/skill.md (Phase 1, "Required — git history").
#
# Why this file exists: this scan's defects are semantic, not syntactic. They
# pass `bash -n`, `shellcheck`, and prose review, and are only visible by
# executing the shipped command against a repo that actually contains a
# planted secret. Two such defects reached `dev`:
#   - merge coverage: `git log -p --all -G <re>` without `-m` never sees a
#     secret introduced in a merge resolution and later deleted.
#   - shallow clones: with no precondition guard, both scan paths find only
#     working-tree secrets and report clean. CI checks out fetch-depth 1.
#
# These tests EXTRACT AND RUN the skill's own fenced blocks rather than
# transcribing them. Transcription is not equivalent: an earlier revision of
# this suite copied the pipeline into a helper, and mutating the skill's token
# regex or deleting a pipeline stage left every test green — the suite
# validated its own copy, not the shipped instruction. Extraction makes each
# stage load-bearing. If you refactor these helpers, re-run the mutation check
# in "meta: mutating the skill's token regex is detected".
#
# The FALLBACK path is what's exercised; the gitleaks path needs a binary that
# CI does not install. The fallback is the degradation path, so it is also the
# one most likely to run unattended and least likely to be noticed.
#
# Secret literals are assembled at RUNTIME. Committing a real `ghp_<36>`
# literal would plant tokens that this repo's own history scan then reports
# forever — and this same skill warns against accumulating un-baselined noise.

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
SKILL="$REPO_ROOT/skills/security/repo-security-scan/skill.md"

# Build a token matching the skill's ghp_[a-zA-Z0-9]{36} class without the
# literal ever appearing in this file.
mktoken() {
    local p=ghp seed="$1" body
    body=$(printf '%s' "$seed"; printf '0%.0s' $(seq 1 36))
    printf '%s_%s' "$p" "${body:0:36}"
}

# Extract and execute the skill's OWN fallback history scan. Not a copy.
# TOKEN_RE/ASSIGN_RE are defined earlier in the skill's Phase 1 block, so pull
# those in too rather than redefining them here.
run_history_scan() {
    {
        awk '/^TOKEN_RE=/,/^ASSIGN_RE=/' "$SKILL"
        awk '/^  set -o pipefail/,/^  fi$/' "$SKILL"
    } | bash 2>/dev/null
}

# Extract and execute the skill's OWN precondition guard.
run_preconditions() {
    awk '/^git rev-parse --git-dir/,/^fi$/' "$SKILL" | bash
}

setup() {
    WORK="$BATS_TEST_TMPDIR/repo"
    mkdir -p "$WORK"
    cd "$WORK" || return 1
    git init -q -b main .
    git config user.email test@example.com
    git config user.name test
    echo "baseline" > README.md
    git add -A
    git commit -qm "initial"
}

@test "meta: the skill's history-scan pipeline is extractable and runnable" {
    # If this fails, every other test here is silently testing nothing.
    run bash -c "awk '/^  set -o pipefail/,/^  fi\$/' '$SKILL' | wc -l"
    [ "$status" -eq 0 ]
    [ "$output" -ge 4 ]
    [ "$output" -le 12 ]
}

@test "meta: mutating the skill's token regex is detected" {
    # Guards the regression that motivated extraction: a suite that copies the
    # pipeline stays green when the shipped regex breaks.
    local tok; tok=$(mktoken deadbeef)
    printf 'K=%s\n' "$tok" > leak.txt
    git add -A && git commit -qm "add secret"

    run run_history_scan
    [[ "$output" == *"$tok"* ]]

    local mutated="$BATS_TEST_TMPDIR/mutated.md"
    sed 's/ghp_\[a-zA-Z0-9\]{36}/ghp_[a-zA-Z0-9]{99}/' "$SKILL" > "$mutated"
    run bash -c "{ awk '/^TOKEN_RE=/,/^ASSIGN_RE=/' '$mutated'; awk '/^  set -o pipefail/,/^  fi\$/' '$mutated'; } | bash 2>/dev/null"
    [[ "$output" != *"$tok"* ]]
}

@test "meta: the skill retains the -m flag and the shallow-clone guard" {
    grep -q 'git log -p -m --all -G' "$SKILL"
    grep -q 'is-shallow-repository' "$SKILL"
    grep -q 'fetch --unshallow' "$SKILL"
}

@test "meta: the skill uses the non-deprecated gitleaks subcommand, with -m and -v" {
    # `detect` still executes on 8.30.1 but is deprecated and unlisted in
    # --help; `git` is the current subcommand.
    grep -q 'gitleaks git \.' "$SKILL"
    run grep -n 'gitleaks detect' "$SKILL"
    [ "$status" -ne 0 ]

    # `-v` is what makes gitleaks output triageable (without it: a bare count).
    # Behavioral coverage of the gitleaks path needs the binary, which CI does
    # not install, so pin these at string level instead of leaving them
    # unguarded.
    grep -q 'no-banner -v' "$SKILL"

    # The PREFERRED path needs -m for merge coverage exactly as the fallback
    # does; hardening only the fallback leaves the recommended path blind.
    grep -q 'log-opts="--all -m"' "$SKILL"
}

@test "meta: ASSIGN_RE uses [[:space:]] and never reverts to \\s" {
    # THIS PIN IS LOAD-BEARING ON LINUX. The behavioral assignment-class test
    # cannot catch a \s regression on glibc: glibc's regcomp enables GNU
    # operators, so `git log -G '\s'` works there and the suite stays green.
    # The breakage is BSD/macOS-only. Since CI is ubuntu-latest, a string-level
    # pin is the only guard that discriminates on the platform CI runs.
    grep -q 'ASSIGN_RE=.*\[\[:space:\]\]\*\[:=\]\[\[:space:\]\]\*' "$SKILL"
    run grep -nE "ASSIGN_RE=.*\\\\s" "$SKILL"
    [ "$status" -ne 0 ]
}

@test "secret committed then deleted is found (working tree scan misses it)" {
    local tok; tok=$(mktoken aaaa1111)
    printf 'K=%s\n' "$tok" > leak.txt
    git add -A && git commit -qm "add secret"
    git rm -q leak.txt && git commit -qm "delete secret"

    # The HEAD-only scan finds nothing -- this is the gap the phase exists for.
    run bash -c "git ls-files -z | xargs -0 grep -lnE 'ghp_[a-zA-Z0-9]{36}' 2>/dev/null"
    [ -z "$output" ]

    run run_history_scan
    [[ "$output" == *"$tok"* ]]
}

@test "secret on a branch unreachable from HEAD is found" {
    local tok; tok=$(mktoken bbbb2222)
    git checkout -q -b side
    printf 'K=%s\n' "$tok" > side.txt
    git add -A && git commit -qm "side secret"
    git checkout -q main

    run run_history_scan
    [[ "$output" == *"$tok"* ]]
}

@test "secret in the root commit is found" {
    local tok; tok=$(mktoken cccc3333)
    rm -rf "$WORK"; mkdir -p "$WORK"; cd "$WORK"
    git init -q -b main .
    git config user.email test@example.com
    git config user.name test
    printf 'ROOT=%s\n' "$tok" > seed.txt
    git add -A && git commit -qm "root commit with secret"

    run run_history_scan
    [[ "$output" == *"$tok"* ]]
}

@test "secret introduced in a merge resolution then deleted is found (needs -m)" {
    local tok; tok=$(mktoken dddd4444)
    git checkout -q -b feat
    echo side > g.txt
    git add -A && git commit -qm side
    git checkout -q main
    echo more >> README.md
    git add -A && git commit -qm main2
    git merge -q --no-ff feat -m merge
    # Rewrite the merge commit so the secret exists ONLY in the merge result.
    printf 'M=%s\n' "$tok" > g.txt
    git add -A && git commit --amend -q --no-edit
    git rm -q g.txt && git commit -qm "delete merge secret"

    # Assert the token appears on a line STARTING with '+'. Without -m it
    # still appears on the deletion commit's '-' line, so a bare substring
    # match -- and even a `*"+"*"$tok"*` glob, which matches a '+' anywhere
    # earlier in the stream -- passes with the fix removed. Both made earlier
    # versions of this test vacuous. Only a line-anchored grep discriminates.
    run bash -c "{ awk '/^TOKEN_RE=/,/^ASSIGN_RE=/' '$SKILL'; awk '/^  set -o pipefail/,/^  fi\$/' '$SKILL'; } | bash 2>/dev/null | grep -cE '^\\+.*$tok'"
    [ "$output" -ge 1 ]

    # Prove -m is load-bearing by mutating THE SKILL and re-running its own
    # extracted pipeline. An earlier version ran a hardcoded `git log` here,
    # which tested git rather than the skill and passed unconditionally.
    local nom="$BATS_TEST_TMPDIR/no-m.md"
    sed 's/git log -p -m --all -G/git log -p --all -G/' "$SKILL" > "$nom"
    run bash -c "{ awk '/^TOKEN_RE=/,/^ASSIGN_RE=/' '$nom'; awk '/^  set -o pipefail/,/^  fi\$/' '$nom'; } | bash 2>/dev/null | grep -cE '^\\+.*$tok'"
    [[ "$output" == "0" ]]
}

@test "assignment-class secret (not just tokens) is found in history" {
    # dev's HISTORY_RE covers ASSIGN_RE as well as TOKEN_RE; assert it.
    printf 'api_key = "s3cr3t-value-here"\n' > cfg.txt
    git add -A && git commit -qm "add assignment secret"
    git rm -q cfg.txt && git commit -qm "delete"

    run run_history_scan
    [[ "$output" == *"s3cr3t-value-here"* ]]
}

@test "precondition guard passes on a full clone" {
    run run_preconditions
    [ "$status" -eq 0 ]
}

@test "precondition guard fails loudly on a shallow clone" {
    local tok; tok=$(mktoken eeee5555)
    printf 'S=%s\n' "$tok" > s.txt
    git add -A && git commit -qm "secret"
    git rm -q s.txt && git commit -qm "delete"
    echo pad >> README.md && git add -A && git commit -qm pad

    local shallow="$BATS_TEST_TMPDIR/shallow"
    git clone -q --depth 1 "file://$WORK" "$shallow"
    cd "$shallow" || return 1

    # The shallow clone genuinely cannot see the secret...
    run run_history_scan
    [[ "$output" != *"$tok"* ]]

    # ...so the guard must fail rather than let that empty result read as clean.
    run run_preconditions
    [ "$status" -eq 1 ]
    [[ "$output" == *"shallow clone"* ]]
    [[ "$output" == *"git fetch --unshallow"* ]]
}

@test "precondition guard fails loudly outside a git repository" {
    local nongit="$BATS_TEST_TMPDIR/nongit"
    mkdir -p "$nongit"; cd "$nongit"
    run run_preconditions
    [ "$status" -eq 1 ]
    # Assert on the INCOMPLETE: prefix, NOT on "not a git repository" alone.
    # git's own fatal message contains that substring, so asserting it would
    # pass even if the skill's echo were deleted -- the test would be
    # observing git, not the skill.
    [[ "$output" == *"INCOMPLETE: not a git repository"* ]]
}

@test "clean repo produces no secret findings" {
    echo "nothing secret here" > clean.txt
    git add -A && git commit -qm clean

    run run_history_scan
    [[ "$output" != *"ghp_"* ]]
}

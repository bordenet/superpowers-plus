#!/usr/bin/env bats
# Real production-path boundary test for CHECK 8b-2. One isolated repository
# contains both limits; it never writes into the checkout running the suite.
# The receipt front door, raw harsh body and real rejection remain exercised.

setup() {
    SOURCE_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    AREA="$BATS_TEST_TMPDIR/reviewer-length"
    REPO_ROOT="$AREA/repo"
    export HOME="$AREA/home" CODEX_HOME="$AREA/home/.codex" CLAUDE_CONFIG_DIR="$AREA/home/.claude"
    export GIT_CONFIG_GLOBAL="$AREA/home/.gitconfig"
    unset SPP_SOURCE_DIR PERSONAL_SKILLS_DIR AUGMENT_MENU_DIR SUPERPOWERS_SKILLS_DIR
    mkdir -p "$REPO_ROOT/docs" "$HOME"
    cp -R "$SOURCE_ROOT/tools" "$REPO_ROOT/tools"
    mkdir -p "$REPO_ROOT/lib/install"
    cp "$SOURCE_ROOT/lib/install/skill-naming.sh" "$REPO_ROOT/lib/install/"
    for name in README AGENTS CLAUDE; do printf '# %s\n' "$name" > "$REPO_ROOT/$name.md"; done
    printf 'root = true\n' > "$REPO_ROOT/.editorconfig"
    printf '# Architecture\n' > "$REPO_ROOT/docs/ARCHITECTURE.md"
    printf '# Contributing\n' > "$REPO_ROOT/docs/CONTRIBUTING.md"
    FIXTURE_DIR="$REPO_ROOT/skills/engineering/code-review-battery/reviewers"
    mkdir -p "$FIXTURE_DIR"
    OVER_FIXTURE="$FIXTURE_DIR/zzz-test-fixture-oversized.md"
    EXACT_FIXTURE="$FIXTURE_DIR/zzz-test-fixture-exact.md"
    HARSH_REVIEW="$REPO_ROOT/tools/harsh-review.sh"
    git -C "$REPO_ROOT" init -q
    git -C "$REPO_ROOT" config user.name 'Reviewer Fixture'
    git -C "$REPO_ROOT" config user.email reviewer@example.invalid
    git -C "$REPO_ROOT" add .
    git -C "$REPO_ROOT" commit -qm fixture
}

teardown() {
    rm -f "$OVER_FIXTURE" "$EXACT_FIXTURE"
}

@test "harsh-review CHECK 8b-2: over-400 fails named with count, exactly-400 does not fail, from one run" {
    i=0
    while [ "$i" -lt 410 ]; do echo "# fixture line $i"; i=$((i + 1)); done > "$OVER_FIXTURE"
    over_lines=$(wc -l < "$OVER_FIXTURE" | tr -d ' ')
    [ "$over_lines" -gt 400 ]

    i=0
    while [ "$i" -lt 400 ]; do echo "# fixture line $i"; i=$((i + 1)); done > "$EXACT_FIXTURE"
    exact_lines=$(wc -l < "$EXACT_FIXTURE" | tr -d ' ')
    [ "$exact_lines" -eq 400 ]

    cd "$REPO_ROOT"
    run bash "$HARSH_REVIEW"

    # Over-400 case: named with its exact line count.
    [ "$status" -ne 0 ]
    [[ "$output" == *"Reviewer prompt file length"* ]]
    [[ "$output" == *"zzz-test-fixture-oversized.md"* ]]
    [[ "$output" == *"${over_lines} lines (max 400)"* ]]

    # Exactly-400 case: NOT flagged by CHECK 8b-2. A bare filename match is
    # too broad -- 400 repeated "# fixture line N" headers are real markdown
    # content, so this fixture also legitimately trips the separate,
    # unrelated markdownlint check earlier in the script's output ("[WARN]
    # .../zzz-test-fixture-exact.md: markdownlint issues") -- found via
    # code-review-battery, reproduced by running harsh-review.sh directly
    # against this exact fixture. Assert against CHECK 8b-2's own specific
    # log_fail format instead of the bare filename, so this only cares about
    # the check it's named for.
    [[ "$output" != *"zzz-test-fixture-exact.md: ${exact_lines} lines (max 400)"* ]]
}

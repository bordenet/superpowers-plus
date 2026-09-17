#!/usr/bin/env bats
# claude-commands-mirror.bats — tests for tools/claude-commands-mirror.sh
#
# Covers the diet.md P1a dedup fix: aliased skills (installed under a
# /sp-* trigger directory whose frontmatter `name:` differs from the
# directory name) must still be mirrored as a command -- but hidden from
# the model via `disable-model-invocation: true` -- instead of being
# silently duplicated as a second, model-visible entry. Also covers the
# source-command-* skip/prune path and the --what-if dry run.

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
SCRIPT="$REPO_ROOT/tools/claude-commands-mirror.sh"

setup() {
    WORKDIR="$BATS_TEST_TMPDIR/work"
    export AUGMENT_MENU_DIR="$WORKDIR/agents-skills"
    export CLAUDE_COMMANDS_DIR="$WORKDIR/claude-commands"
    export CLAUDE_SKILLS_DIR="$WORKDIR/claude-skills"
    mkdir -p "$AUGMENT_MENU_DIR" "$CLAUDE_COMMANDS_DIR" "$CLAUDE_SKILLS_DIR"
}

# --- helpers -----------------------------------------------------------

# Create a source SKILL.md under $AUGMENT_MENU_DIR/<dir>/SKILL.md.
_make_source() {
    local dir="$1" name="$2" desc="${3:-A test skill}"
    mkdir -p "$AUGMENT_MENU_DIR/$dir"
    printf -- '---\nname: %s\ndescription: "%s"\n---\nBody.\n' "$name" "$desc" \
        > "$AUGMENT_MENU_DIR/$dir/SKILL.md"
}

# Create an installed skill under $CLAUDE_SKILLS_DIR/<dir>/SKILL.md with the
# given frontmatter name -- <dir> may differ from <name> to model the /sp-*
# aliased-install case (e.g. dir="sp-debate", name="debate").
_make_installed() {
    local dir="$1" name="$2"
    mkdir -p "$CLAUDE_SKILLS_DIR/$dir"
    printf -- '---\nname: %s\ndescription: "installed"\n---\nBody.\n' "$name" \
        > "$CLAUDE_SKILLS_DIR/$dir/SKILL.md"
}

# --- coverage ------------------------------------------------------------

@test "alias duplicate: source name matches an installed skill's frontmatter name via a /sp-* dir -> hidden alias command" {
    # Deploy installed "debate" under the aliased sp-debate directory; its
    # own frontmatter name stays "debate", not "sp-debate".
    _make_installed "sp-debate" "debate"
    _make_source "debate" "debate" "Debate designs"

    run bash "$SCRIPT"
    [ "$status" -eq 0 ]

    [ -f "$CLAUDE_COMMANDS_DIR/debate.md" ]
    grep -q '^disable-model-invocation: true$' "$CLAUDE_COMMANDS_DIR/debate.md"
    # The body must still invoke the skill -- /debate must keep working.
    grep -q 'Invoke the `debate` skill' "$CLAUDE_COMMANDS_DIR/debate.md"
}

@test "non-duplicate: source name has no installed counterpart -> stays model-visible" {
    _make_source "brainstorming" "brainstorming" "Brainstorm stuff"

    run bash "$SCRIPT"
    [ "$status" -eq 0 ]

    [ -f "$CLAUDE_COMMANDS_DIR/brainstorming.md" ]
    ! grep -q '^disable-model-invocation:' "$CLAUDE_COMMANDS_DIR/brainstorming.md"
}

@test "direct duplicate: source name matches \$SKILLS_DIR/<name> directly -> hidden alias command" {
    _make_installed "review" "review"
    _make_source "review" "review" "Review stuff"

    run bash "$SCRIPT"
    [ "$status" -eq 0 ]

    [ -f "$CLAUDE_COMMANDS_DIR/review.md" ]
    grep -q '^disable-model-invocation: true$' "$CLAUDE_COMMANDS_DIR/review.md"
}

@test "source-command-* is skipped entirely, never written" {
    _make_source "source-command-foo" "source-command-foo" "x"
    # Match the real Codex-migration body text exactly.
    printf -- '---\nname: "source-command-foo"\ndescription: "x"\n---\nUse this skill when the user asks to run the migrated source command `foo`.\n' \
        > "$AUGMENT_MENU_DIR/source-command-foo/SKILL.md"

    run bash "$SCRIPT" -v
    [ "$status" -eq 0 ]

    [ ! -f "$CLAUDE_COMMANDS_DIR/source-command-foo.md" ]
    [[ "$output" == *"skipped-source-command=1"* ]]
}

@test "source-command-* previously mirrored is pruned on the next run" {
    # Simulate a stale command left over from before this fix, still tagged
    # as managed by this script.
    printf -- '---\ndescription: "x"\nsource: "claude-commands-mirror"\n---\n\nInvoke the `source-command-foo` skill.\n' \
        > "$CLAUDE_COMMANDS_DIR/source-command-foo.md"

    mkdir -p "$AUGMENT_MENU_DIR/source-command-foo"
    printf -- '---\nname: "source-command-foo"\ndescription: "x"\n---\nUse this skill when the user asks to run the migrated source command `foo`.\n' \
        > "$AUGMENT_MENU_DIR/source-command-foo/SKILL.md"

    run bash "$SCRIPT"
    [ "$status" -eq 0 ]

    [ ! -f "$CLAUDE_COMMANDS_DIR/source-command-foo.md" ]
}

@test "a non-managed user command (no source: tag) is never pruned" {
    printf -- '---\ndescription: "hand-written command"\n---\n\nDo the thing.\n' \
        > "$CLAUDE_COMMANDS_DIR/my-own-command.md"

    # Give the mirror something to do so the prune pass actually runs.
    _make_source "brainstorming" "brainstorming"

    run bash "$SCRIPT"
    [ "$status" -eq 0 ]

    [ -f "$CLAUDE_COMMANDS_DIR/my-own-command.md" ]
}

@test "--what-if writes nothing: no new files, no pruning, no changes" {
    _make_installed "sp-debate" "debate"
    _make_source "debate" "debate"
    _make_source "brainstorming" "brainstorming"

    # A stale managed file that would normally be pruned.
    printf -- '---\ndescription: "x"\nsource: "claude-commands-mirror"\n---\n\nInvoke the `stale` skill.\n' \
        > "$CLAUDE_COMMANDS_DIR/stale.md"

    run bash "$SCRIPT" --what-if
    [ "$status" -eq 0 ]

    # Nothing new was written for either the alias or the plain skill.
    [ ! -f "$CLAUDE_COMMANDS_DIR/debate.md" ]
    [ ! -f "$CLAUDE_COMMANDS_DIR/brainstorming.md" ]
    # The stale managed file was not pruned.
    [ -f "$CLAUDE_COMMANDS_DIR/stale.md" ]
    [[ "$output" == *"DRY RUN"* ]]
}

@test "--help exits 0 and documents disable-model-invocation and source-command skip" {
    run bash "$SCRIPT" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"disable-model-invocation"* ]]
    [[ "$output" == *"source-command"* ]]
}

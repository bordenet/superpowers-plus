#!/usr/bin/env bats
# The skill-resolution line replaces the obra plugin's SessionStart bootstrap,
# so it must print even where the integrity hook would exit early or block.

setup() {
    REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd -P)"
    HOOK="$REPO_ROOT/tools/claude-hooks/session-start-skill-resolution.sh"
    SPEC="$REPO_ROOT/claude-config/settings-hooks-spec.json"
}

@test "skill-resolution hook prints the line from a cwd with no invariants" {
    cd "$BATS_TEST_TMPDIR"
    run env HOME="$BATS_TEST_TMPDIR" bash "$HOOK" < /dev/null
    [ "$status" -eq 0 ]
    [[ "$output" == "[superpowers-plus] A skill named <name> or superpowers:<name>"* ]]
    [[ "$output" == *"[Ss][Kk][Ii][Ll][Ll].md"* ]]
}

@test "skill-resolution hook honors the CLAUDE_HOOKS_BYPASS escape hatch" {
    run env CLAUDE_HOOKS_BYPASS=1 bash "$HOOK" < /dev/null
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "skill-resolution hook is registered for SessionStart" {
    run python3 -c 'import json,sys; s=json.load(open(sys.argv[1])); print([h["command"] for m in s["hooks"]["SessionStart"] for h in m["hooks"]])' "$SPEC"
    [ "$status" -eq 0 ]
    [[ "$output" == *"session-start-skill-resolution.sh"* ]]
}

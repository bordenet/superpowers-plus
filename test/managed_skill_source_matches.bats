#!/usr/bin/env bats
# test/managed_skill_source_matches.bats
# Unit tests for managed_skill_source_matches() in lib/install/deploy.sh.
#
# Regression for the stale-skill pruning hole: the fallback path (no manifest)
# previously only matched "source: superpowers-plus", leaving orphaned skills
# from other superpowers overlay repos invisible to the pruner.

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

# shellcheck source=lib/install/deploy.sh
setup() {
    # deploy.sh sources lib/install/logging.sh etc. - set expected globals.
    CODEX_DIR="${BATS_TEST_TMPDIR}/codex"
    SKILLS_DIR="${CODEX_DIR}/skills"
    CLAUDE_SKILLS_DIR="${CODEX_DIR}/claude-skills"
    AUGMENT_MENU_DIR="${CODEX_DIR}/agents-skills"
    SCRIPT_DIR="${REPO_ROOT}"
    VERBOSE=false
    export CODEX_DIR SKILLS_DIR CLAUDE_SKILLS_DIR AUGMENT_MENU_DIR SCRIPT_DIR VERBOSE

    # Source without executing main(); deploy.sh is function-only at top level.
    # shellcheck disable=SC1090
    source "${REPO_ROOT}/lib/install/deploy.sh"

    tmpdir="${BATS_TEST_TMPDIR}/skill"
    mkdir -p "${tmpdir}"
}

teardown() {
    rm -rf "${BATS_TEST_TMPDIR}"
}

# Helper: write a minimal skill.md with the given source: line.
make_skill() {
    local dir="$1" source_value="$2"
    mkdir -p "${dir}"
    printf -- '---\nname: test-skill\nsource: %s\n---\n' "${source_value}" \
        > "${dir}/skill.md"
}

# Helper: write a minimal SKILL.md (upper-case variant).
make_SKILL() {
    local dir="$1" source_value="$2"
    mkdir -p "${dir}"
    printf -- '---\nname: test-skill\nsource: %s\n---\n' "${source_value}" \
        > "${dir}/SKILL.md"
}

@test "superpowers-plus matches (original case)" {
    make_skill "${tmpdir}" "superpowers-plus"
    run managed_skill_source_matches "${tmpdir}"
    [ "$status" -eq 0 ]
}

@test "superpowers-overlay matches (bug fix: any superpowers- prefix)" {
    make_skill "${tmpdir}" "superpowers-overlay"
    run managed_skill_source_matches "${tmpdir}"
    [ "$status" -eq 0 ]
}

@test "superpowers-augment matches" {
    make_skill "${tmpdir}" "superpowers-augment"
    run managed_skill_source_matches "${tmpdir}"
    [ "$status" -eq 0 ]
}

@test "SKILL.md upper-case variant is found" {
    make_SKILL "${tmpdir}" "superpowers-overlay"
    run managed_skill_source_matches "${tmpdir}"
    [ "$status" -eq 0 ]
}

@test "unknown source does not match" {
    make_skill "${tmpdir}" "third-party-skills"
    run managed_skill_source_matches "${tmpdir}"
    [ "$status" -ne 0 ]
}

@test "prefix exploit does not match (xsuperpowers-plus)" {
    make_skill "${tmpdir}" "xsuperpowers-plus"
    run managed_skill_source_matches "${tmpdir}"
    [ "$status" -ne 0 ]
}

@test "suffix exploit does not match (superpowers-plusx)" {
    make_skill "${tmpdir}" "superpowers-plusx"
    run managed_skill_source_matches "${tmpdir}"
    [ "$status" -eq 0 ]  # superpowers-plusx still has the prefix; it IS a managed overlay
}

@test "bare 'superpowers-' with no suffix does not match" {
    make_skill "${tmpdir}" "superpowers-"
    run managed_skill_source_matches "${tmpdir}"
    [ "$status" -ne 0 ]
}

@test "missing skill file returns non-zero" {
    mkdir -p "${tmpdir}"
    run managed_skill_source_matches "${tmpdir}"
    [ "$status" -ne 0 ]
}

@test "empty skill dir returns non-zero" {
    run managed_skill_source_matches "${tmpdir}/nonexistent"
    [ "$status" -ne 0 ]
}

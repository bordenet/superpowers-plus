#!/usr/bin/env bats
# Tests for export_augment_menu_skills() and _extract_sp_trigger()
# in lib/install/deploy.sh

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
DEPLOY_SH="$REPO_ROOT/lib/install/deploy.sh"

# Source only the functions we need from deploy.sh (skip install machinery)
setup() {
    export TEST_HOME
    TEST_HOME="$(mktemp -d)"
    export HOME="$TEST_HOME"
    export SKILLS_DIR="$TEST_HOME/skills"
    export AUGMENT_MENU_DIR="$TEST_HOME/agents/skills"
    export VERBOSE=false
    mkdir -p "$SKILLS_DIR" "$AUGMENT_MENU_DIR"

    # Minimal stubs so deploy.sh sources cleanly without running installs
    log_info()    { :; }
    log_verbose() { :; }
    log_warn()    { echo "WARN: $*" >&2; }
    log_success() { :; }
    log_error()   { echo "ERROR: $*" >&2; }

    # Source only the deploy helpers (not the full install machinery)
    # shellcheck source=../lib/install/deploy.sh
    source <(sed -n '/^_extract_sp_trigger/,/^}$/p;/^export_augment_menu_skills/,/^}$/p;/^AUGMENT_MENU_SKILLS/,/^)/p' "$DEPLOY_SH")
}

teardown() {
    rm -rf "$TEST_HOME"
}

# --- helper: make a minimal skill dir ---
_make_skill() {
    local name="$1" trigger="$2" quote="${3:-double}"
    local dir="$SKILLS_DIR/$name"
    mkdir -p "$dir"
    if [[ "$trigger" == "none" ]]; then
        printf -- "---\nname: %s\ntriggers: []\n---\n" "$name" > "$dir/skill.md"
    elif [[ "$quote" == "single" ]]; then
        printf -- "---\nname: %s\ntriggers: ['%s']\n---\n" "$name" "$trigger" > "$dir/skill.md"
    else
        printf -- "---\nname: %s\ntriggers: [\"%s\"]\n---\n" "$name" "$trigger" > "$dir/skill.md"
    fi
}

# --- _extract_sp_trigger tests ---

@test "_extract_sp_trigger: double-quoted inline array" {
    _make_skill "brainstorming" "/sp-brainstorm"
    result=$(_extract_sp_trigger "$SKILLS_DIR/brainstorming/skill.md")
    [[ "$result" == "/sp-brainstorm" ]]
}

@test "_extract_sp_trigger: single-quoted inline array (Linux compat)" {
    _make_skill "brainstorming" "/sp-brainstorm" single
    result=$(_extract_sp_trigger "$SKILLS_DIR/brainstorming/skill.md")
    [[ "$result" == "/sp-brainstorm" ]]
}

@test "_extract_sp_trigger: block list format" {
    local dir="$SKILLS_DIR/debate"
    mkdir -p "$dir"
    printf -- "---\nname: debate\ntriggers:\n  - /sp-debate\n  - compare approaches\n---\n" > "$dir/skill.md"
    result=$(_extract_sp_trigger "$dir/skill.md")
    [[ "$result" == "/sp-debate" ]]
}

@test "_extract_sp_trigger: no /sp-* trigger returns empty" {
    _make_skill "notrigger" "something else"
    result=$(_extract_sp_trigger "$SKILLS_DIR/notrigger/skill.md")
    [[ -z "$result" ]]
}

@test "_extract_sp_trigger: missing file returns empty" {
    result=$(_extract_sp_trigger "/nonexistent/skill.md")
    [[ -z "$result" ]]
}

# --- export_augment_menu_skills tests ---

@test "export: copies skill and SKILL.md exists in destination" {
    _make_skill "brainstorming" "/sp-brainstorm"
    AUGMENT_MENU_SKILLS=("brainstorming")
    export_augment_menu_skills
    # SKILL.md must exist (case-insensitive FS: skill.md and SKILL.md are same inode on macOS)
    [[ -f "$AUGMENT_MENU_DIR/sp-brainstorm/SKILL.md" ]]
    # No _skill_tmp.md should be left behind from the two-step rename
    [[ ! -f "$AUGMENT_MENU_DIR/sp-brainstorm/_skill_tmp.md" ]]
}

@test "export: name: field updated to sp-* label (portable python rewrite)" {
    _make_skill "brainstorming" "/sp-brainstorm"
    AUGMENT_MENU_SKILLS=("brainstorming")
    export_augment_menu_skills
    grep -q "^name: sp-brainstorm$" "$AUGMENT_MENU_DIR/sp-brainstorm/SKILL.md"
}

@test "export: fallback to skill name when no /sp-* trigger, emits warn" {
    _make_skill "notrigger" "none"
    AUGMENT_MENU_SKILLS=("notrigger")
    output=$(export_augment_menu_skills 2>&1)
    [[ -f "$AUGMENT_MENU_DIR/notrigger/SKILL.md" ]]
    [[ "$output" == *"No /sp-* trigger"* ]]
}

@test "export: missing skill emits warn and increments missing counter" {
    AUGMENT_MENU_SKILLS=("does-not-exist")
    output=$(export_augment_menu_skills 2>&1)
    [[ "$output" == *"not found"* ]]
}

@test "export: prunes stale sp-* dir when removed from curated list" {
    _make_skill "brainstorming" "/sp-brainstorm"
    # Pre-populate a stale skill with the source: tag
    mkdir -p "$AUGMENT_MENU_DIR/sp-old"
    printf "source: superpowers-plus\n" > "$AUGMENT_MENU_DIR/sp-old/SKILL.md"

    AUGMENT_MENU_SKILLS=("brainstorming")
    export_augment_menu_skills
    [[ ! -d "$AUGMENT_MENU_DIR/sp-old" ]]
}

@test "export: does not prune user-added skills without source tag" {
    _make_skill "brainstorming" "/sp-brainstorm"
    mkdir -p "$AUGMENT_MENU_DIR/my-custom-skill"
    printf "name: my-custom-skill\n" > "$AUGMENT_MENU_DIR/my-custom-skill/SKILL.md"

    AUGMENT_MENU_SKILLS=("brainstorming")
    export_augment_menu_skills
    [[ -d "$AUGMENT_MENU_DIR/my-custom-skill" ]]
}

#!/usr/bin/env bash
# test/test_skill_dest_name.sh
# Table-driven tests for _skill_dest_name() and _extract_sp_trigger() in deploy.sh.
# Calls the production functions directly — no reimplementation.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# deploy.sh only defines functions; sourcing has no top-level side effects.
# shellcheck source=lib/install/deploy.sh
source "$REPO_ROOT/lib/install/deploy.sh"

PASS=0; FAIL=0

check() {
    local label="$1" got="$2" want="$3"
    if [[ "$got" == "$want" ]]; then
        echo "  PASS: $label"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $label"
        echo "        got:  '$got'"
        echo "        want: '$want'"
        FAIL=$((FAIL + 1))
    fi
}

mk_skill() {
    # mk_skill <dir> <frontmatter_triggers_line>
    # Creates a minimal skill dir with a skill.md containing the given triggers line.
    local dir="$1" triggers_line="$2"
    mkdir -p "$dir"
    { echo "---"; echo "name: test"; echo "$triggers_line"; echo "---"; echo "Body."; } > "$dir/skill.md"
}

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

# -------------------------------------------------------------------
# _extract_sp_trigger tests
# -------------------------------------------------------------------
echo ""
echo "=== _extract_sp_trigger ==="

mk_skill "$TMPDIR/inline-dq" 'triggers: ["/sp-brainstorm", "/other"]'
check "inline double-quoted: picks first /sp trigger" \
    "$(_extract_sp_trigger "$TMPDIR/inline-dq/skill.md")" "/sp-brainstorm"

mk_skill "$TMPDIR/inline-sq" "triggers: ['/sp-debug', '/fallback']"
check "inline single-quoted: picks first /sp trigger" \
    "$(_extract_sp_trigger "$TMPDIR/inline-sq/skill.md")" "/sp-debug"

mk_skill "$TMPDIR/block" $'triggers:\n  - /sp-review\n  - /other'
check "block list: picks first /sp trigger" \
    "$(_extract_sp_trigger "$TMPDIR/block/skill.md")" "/sp-review"

mk_skill "$TMPDIR/spr" 'triggers: ["/spr-pipeline", "/other"]'
check "spr-prefix: recognised as /sp* trigger" \
    "$(_extract_sp_trigger "$TMPDIR/spr/skill.md")" "/spr-pipeline"

mk_skill "$TMPDIR/no-sp" 'triggers: ["/old-name", "/also-old"]'
check "no /sp* trigger: returns empty string" \
    "$(_extract_sp_trigger "$TMPDIR/no-sp/skill.md")" ""

mk_skill "$TMPDIR/notriggers" 'description: no triggers line'
check "missing triggers line: returns empty string" \
    "$(_extract_sp_trigger "$TMPDIR/notriggers/skill.md")" ""

# -------------------------------------------------------------------
# _skill_dest_name tests
# -------------------------------------------------------------------
echo ""
echo "=== _skill_dest_name ==="

mk_skill "$TMPDIR/sp-named" 'triggers: ["/sp-brainstorm", "/other"]'
check "sp trigger present: returns trigger name (no leading /)" \
    "$(_skill_dest_name "$TMPDIR/sp-named")" "sp-brainstorm"

mk_skill "$TMPDIR/spr-named" 'triggers: ["/spr-pipeline"]'
check "spr trigger present: returns spr-pipeline" \
    "$(_skill_dest_name "$TMPDIR/spr-named")" "spr-pipeline"

mk_skill "$TMPDIR/no-trigger-skill" 'description: no sp triggers'
check "no sp trigger: falls back to directory basename" \
    "$(_skill_dest_name "$TMPDIR/no-trigger-skill")" "no-trigger-skill"

# SKILL.md (uppercase) variant
mkdir -p "$TMPDIR/upper"
{ echo "---"; echo "name: upper"; echo 'triggers: ["/sp-upper"]'; echo "---"; } > "$TMPDIR/upper/SKILL.md"
check "SKILL.md (uppercase): reads trigger correctly" \
    "$(_skill_dest_name "$TMPDIR/upper")" "sp-upper"


# Empty skill dir (no SKILL.md or skill.md) → basename fallback
mkdir -p "$TMPDIR/empty-dir"
check "empty dir: falls back to basename" \
    "$(_skill_dest_name "$TMPDIR/empty-dir")" "empty-dir"

# -------------------------------------------------------------------
# install_skill path-traversal guard
# -------------------------------------------------------------------
echo ""
echo "=== install_skill path-traversal guard ==="

mk_skill "$TMPDIR/traversal-skill" 'triggers: ["/sp-ok"]'
# Fake a safe environment so install_skill does not try to copy files
SKILLS_DIR="$TMPDIR/fake-codex-skills"
CLAUDE_SKILLS_DIR="$TMPDIR/fake-claude-skills"
mkdir -p "$SKILLS_DIR" "$CLAUDE_SKILLS_DIR"

# Provide stub log/error functions so deploy.sh helpers don't fail
log_verbose() { :; }
log_warn()    { :; }
log_success() { :; }
error_exit()  { echo "error_exit: $*" >&2; exit 1; }

path_traversal_blocked=0
if ! (install_skill "$TMPDIR/traversal-skill" "../../evil" 2>/dev/null); then
    path_traversal_blocked=1
fi
check "path traversal in dest_name is rejected" "$path_traversal_blocked" "1"

# -------------------------------------------------------------------
# Summary
# -------------------------------------------------------------------
echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]

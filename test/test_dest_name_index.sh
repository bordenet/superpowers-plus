#!/usr/bin/env bash
# test/test_dest_name_index.sh
# Tests for _build_dest_name_index in lib/install/skill-naming.sh —
# the source→install-destination mapping the doctor uses to stay alias-aware
# when skills install under their /sp* trigger name.
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/install/skill-naming.sh
source "$REPO_ROOT/lib/install/skill-naming.sh"

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
    # mk_skill <dir> <name_value> <triggers_line>
    local dir="$1" name_val="$2" triggers_line="$3"
    mkdir -p "$dir"
    {
        echo "---"
        echo "name: $name_val"
        echo "$triggers_line"
        echo "---"
        echo "Body."
    } > "$dir/skill.md"
}

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

# Layout:
#   $TMPDIR/repo-a/skills/brainstorming/skill.md   (name: brainstorming, /sp-brainstorm)
#   $TMPDIR/repo-a/skills/codebase-recon/skill.md  (name: codebase-recon, no /sp* trigger)
#   $TMPDIR/repo-b/skills/think-twice/skill.md     (name: think-twice, /sp-rethink)
mk_skill "$TMPDIR/repo-a/skills/brainstorming" "brainstorming" \
    'triggers: ["/sp-brainstorm", "brainstorm"]'
mk_skill "$TMPDIR/repo-a/skills/codebase-recon" "codebase-recon" \
    'triggers: ["recon", "audit"]'
mk_skill "$TMPDIR/repo-b/skills/think-twice" "think-twice" \
    'triggers: ["/sp-rethink", "second opinion"]'

echo ""
echo "=== _build_dest_name_index: single repo with mixed alias / no-alias ==="
declare -A SOURCE_DEST_NAME=()
declare -A DEST_NAME_SOURCE=()
declare -A DEST_NAMES_SET=()
_build_dest_name_index "$TMPDIR/repo-a"

check "aliased skill: source 'brainstorming' maps to dest 'sp-brainstorm'" \
    "${SOURCE_DEST_NAME[brainstorming]:-MISSING}" "sp-brainstorm"
check "non-aliased skill: 'codebase-recon' maps to itself" \
    "${SOURCE_DEST_NAME[codebase-recon]:-MISSING}" "codebase-recon"
check "reverse lookup: dest 'sp-brainstorm' → source 'brainstorming'" \
    "${DEST_NAME_SOURCE[sp-brainstorm]:-MISSING}" "brainstorming"
check "membership: 'sp-brainstorm' is in DEST_NAMES_SET" \
    "${DEST_NAMES_SET[sp-brainstorm]:-MISSING}" "1"
check "membership: 'codebase-recon' is in DEST_NAMES_SET" \
    "${DEST_NAMES_SET[codebase-recon]:-MISSING}" "1"
check "membership: 'brainstorming' is NOT in DEST_NAMES_SET (it's a source name, not a dest)" \
    "${DEST_NAMES_SET[brainstorming]:-MISSING}" "MISSING"

echo ""
echo "=== _build_dest_name_index: multiple repos accumulate ==="
declare -A SOURCE_DEST_NAME=()
declare -A DEST_NAME_SOURCE=()
declare -A DEST_NAMES_SET=()
_build_dest_name_index "$TMPDIR/repo-a" "$TMPDIR/repo-b"

check "repo-a entry survives second invocation: brainstorming" \
    "${SOURCE_DEST_NAME[brainstorming]:-MISSING}" "sp-brainstorm"
check "repo-b entry added: think-twice → sp-rethink" \
    "${SOURCE_DEST_NAME[think-twice]:-MISSING}" "sp-rethink"
check "membership reflects both repos: sp-rethink set" \
    "${DEST_NAMES_SET[sp-rethink]:-MISSING}" "1"

echo ""
echo "=== _build_dest_name_index: accepts both repo-root and skills-root ==="
# Pre-existing convention: caller may pass either '/path/to/repo' (which
# contains 'skills/') or '/path/to/repo/skills' directly.
declare -A SOURCE_DEST_NAME=()
declare -A DEST_NAME_SOURCE=()
declare -A DEST_NAMES_SET=()
_build_dest_name_index "$TMPDIR/repo-a/skills"

check "skills-root entry: brainstorming still resolves" \
    "${SOURCE_DEST_NAME[brainstorming]:-MISSING}" "sp-brainstorm"

echo ""
echo "=== _build_dest_name_index: empty roots are no-ops ==="
empty_root=$(mktemp -d)
declare -A SOURCE_DEST_NAME=()
declare -A DEST_NAME_SOURCE=()
declare -A DEST_NAMES_SET=()
_build_dest_name_index "$empty_root"
check "empty root: SOURCE_DEST_NAME stays empty" \
    "${#SOURCE_DEST_NAME[@]}" "0"
rmdir "$empty_root"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]

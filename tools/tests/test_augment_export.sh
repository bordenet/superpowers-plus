#!/usr/bin/env bash
# test_augment_export.sh — Verify curated Augment slash-menu export integrity.
# Section A: Hermetic — runs export_augment_menu_skills() into a temp dir.
# Section B: Live smoke — validates ~/.agents/skills/ from the last install.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

PASS=0; FAIL=0; SKIP=0
fail() { echo "FAIL: $*" >&2; ((FAIL++)) || true; }
pass() { echo "  ok: $1"; ((PASS++)) || true; }
skip() { echo "  skip: $1"; ((SKIP++)) || true; }

echo "── Augment Export Tests ──"

DEPLOY_SH="$REPO_ROOT/lib/install/deploy.sh"
if [[ ! -f "$DEPLOY_SH" ]]; then
    echo "SKIP: lib/install/deploy.sh not found"
    exit 0
fi
SKILLS_DIR="${HOME}/.codex/skills"
if [[ ! -d "$SKILLS_DIR" ]]; then
    echo "SKIP: $SKILLS_DIR not found — run ./install.sh first"
    exit 0
fi

# Extract curated skills from AUGMENT_MENU_SKILLS array
mapfile -t CURATED < <(
    awk '/^AUGMENT_MENU_SKILLS=\(/{found=1; next} found && /^\)/{exit} found{gsub(/[[:space:]]/, ""); print}' "$DEPLOY_SH" \
    | grep -v '^$'
)
EXPECTED="${#CURATED[@]}"
if [[ $EXPECTED -eq 0 ]]; then
    echo "FAIL: Could not parse AUGMENT_MENU_SKILLS from deploy.sh" >&2
    exit 1
fi

# ═══════════════════════════════════════════
# Section A: Hermetic export test
# Proves the export CODE works, not just the live state.
# ═══════════════════════════════════════════
echo "  [A] Hermetic export:"

TEMP_EXPORT_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_EXPORT_DIR"' EXIT

# Source logging stubs and the deploy module in a subshell to avoid polluting globals
hermetic_result=0
(
    # Load real logging functions (quieted via VERBOSE=false; exported for logging.sh)
    export VERBOSE=false
    # shellcheck source=lib/install/logging.sh
    source "$REPO_ROOT/lib/install/logging.sh"

    # Provide required globals
    export SKILLS_DIR
    export AUGMENT_MENU_DIR="$TEMP_EXPORT_DIR"
    export SCRIPT_DIR="$REPO_ROOT"

    # shellcheck source=lib/install/deploy.sh
    source "$DEPLOY_SH"

    # Run the export function
    export_augment_menu_skills
) || hermetic_result=$?

if [[ $hermetic_result -ne 0 ]]; then
    fail "export_augment_menu_skills() exited $hermetic_result"
fi

hermetic_missing=0
for skill in "${CURATED[@]}"; do
    if [[ ! -d "$TEMP_EXPORT_DIR/$skill" ]]; then
        fail "hermetic: $skill — directory missing in export output"
        ((hermetic_missing++)) || true
    elif [[ ! -f "$TEMP_EXPORT_DIR/$skill/SKILL.md" ]]; then
        fail "hermetic: $skill — SKILL.md not present (rename failed?)"
    else
        pass "hermetic: $skill — exported with SKILL.md"
    fi
done
if [[ $hermetic_missing -eq 0 ]]; then
    pass "hermetic: export count $EXPECTED/$EXPECTED"
else
    fail "hermetic: $hermetic_missing/$EXPECTED skills missing from export"
fi

# ═══════════════════════════════════════════
# Section B: Live smoke test
# Confirms the last install.sh run left ~/.agents/skills/ correct.
# ═══════════════════════════════════════════
echo "  [B] Live install smoke:"

MENU_DIR="${HOME}/.agents/skills"
if [[ ! -d "$MENU_DIR" ]]; then
    skip "live smoke: $MENU_DIR absent — install.sh not yet run on this machine"
else
    live_missing=0
    for skill in "${CURATED[@]}"; do
        if [[ -d "$MENU_DIR/$skill" ]] && [[ -f "$MENU_DIR/$skill/SKILL.md" ]]; then
            pass "live: $skill — OK"
        else
            fail "live: $skill — missing or malformed"
            ((live_missing++)) || true
        fi
    done
    if [[ $live_missing -eq 0 ]]; then
        pass "live: all $EXPECTED/$EXPECTED curated skills present"
    fi
fi

echo ""
echo "── Results: $PASS passed, $FAIL failed, $SKIP skipped ──"
[[ $FAIL -eq 0 ]]

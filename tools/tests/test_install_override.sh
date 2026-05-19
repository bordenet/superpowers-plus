#!/usr/bin/env bash
set -euo pipefail

# Test: install_skill() preserves upstream companion files for override skills
#
# Verifies that when a skill declares `overrides: superpowers/skill-name`,
# the installer stages upstream companion files first, then overlays the
# override's skill.md on top.

PASS=0; FAIL=0
fail() { echo "FAIL: $*" >&2; ((FAIL++)) || true; }
pass() { echo "  ok: $1"; ((PASS++)) || true; }

echo "── Install Override Tests ──"

# ── Test 1: Override skills have upstream companions after install ──
test_override_companion_preservation() {
    local skills_to_check=(
        "test-driven-development:testing-anti-patterns.md"
        "systematic-debugging:root-cause-tracing.md"
        "brainstorming:spec-document-reviewer-prompt.md"
        "subagent-driven-development:implementer-prompt.md"
    )

    for entry in "${skills_to_check[@]}"; do
        local skill="${entry%%:*}"
        local companion="${entry##*:}"
        local installed_dir="$HOME/.codex/skills/$skill"

        if [[ ! -d "$installed_dir" ]]; then
            fail "$skill — not installed"
            continue
        fi

        # Check override's skill.md is installed (not upstream SKILL.md)
        if [[ ! -f "$installed_dir/skill.md" ]]; then
            fail "$skill — missing skill.md (override not applied)"
            continue
        fi

        # Check skill.md is from superpowers-plus (not upstream)
        if ! grep -q '^source: superpowers-plus' "$installed_dir/skill.md" 2>/dev/null; then
            fail "$skill — skill.md is not from superpowers-plus override"
            continue
        fi

        # Check companion file from upstream exists
        if [[ -f "$installed_dir/$companion" ]]; then
            pass "$skill — has upstream companion '$companion'"
        else
            fail "$skill — missing upstream companion '$companion'"
        fi
    done
}

# ── Test 2: Non-override skills still install cleanly ──
test_non_override_install() {
    local skill="wiki-instruction-guard"
    local installed_dir="$HOME/.codex/skills/$skill"

    if [[ ! -d "$installed_dir" ]]; then
        fail "$skill — not installed"
        return
    fi

    if [[ -f "$installed_dir/skill.md" ]]; then
        pass "$skill — non-override skill installs normally"
    else
        fail "$skill — missing skill.md"
    fi

    # Check references/ subdir was copied
    if [[ -d "$installed_dir/references" ]]; then
        pass "$skill — references/ subdir preserved"
    else
        fail "$skill — references/ subdir missing"
    fi
}

# ── Test 3 retired v2.6.0 ──
# The "override content wins over upstream" invariant was tested by comparing
# installed skill.md against the obra clone tier (~/.codex/superpowers/skills/).
# That tier was removed in v2.6.0; skills are now standalone. The invariant no
# longer applies. See CHANGELOG.md for the v2.6.0 migration notes.

# ── Run tests ──
test_override_companion_preservation
test_non_override_install

echo ""
echo "── Results: $PASS passed, $FAIL failed ──"
[[ $FAIL -eq 0 ]]

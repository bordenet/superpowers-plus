#!/usr/bin/env bats

# Behavioral tests for lib/install/hook-parity.sh's check_hook_parity().
#
# Regression guard for the 2026-09-20 failure: install.sh ran
# setup/install-claude-guardrails.sh as `bash "$script" >/dev/null 2>&1`,
# discarding the child's own "Kill switch ON ... Skipping install." message.
# That script no-ops unless SUPERPOWERS_CLAUDE_GUARDRAILS=1, so a skipped hook
# install was indistinguishable from a completed one and ~/.claude/hooks/
# drifted 26 days behind the repo while shipped hook work never executed.
#
# Contract under test:
#   - reports success only when every shipped hook matches its installed copy
#   - names each STALE, MISSING, ORPHANED and UNREADABLE hook separately,
#     because each needs different remediation
#   - ORPHANED (installed but no longer shipped) is detected: the guardrails
#     installer only ever copies, never deletes, so a dropped hook keeps firing
#   - emits one stable machine-readable line for agent/CI consumers
#   - advisory by default (exit 0); HOOK_PARITY_STRICT=1 opts into exit 2

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

setup() {
    SRC="$BATS_TEST_TMPDIR/src/tools/claude-hooks"
    DST="$BATS_TEST_TMPDIR/home/.claude/hooks"
    mkdir -p "$SRC" "$DST" "$BATS_TEST_TMPDIR/src/setup"

    for h in alpha beta gamma; do
        printf '#!/usr/bin/env bash\n# %s v1\n' "$h" > "$SRC/$h.sh"
    done
}

# Source the module directly -- the same pattern test/managed_skill_source_matches.bats
# uses for lib/install/deploy.sh. An earlier version of this suite extracted the
# function out of install.sh with sed+eval, which silently truncates if a future
# edit puts a `}` at column 0 or reformats the signature.
run_parity() {
    run env HOOK_PARITY_STRICT="${HOOK_PARITY_STRICT:-0}" bash -c '
        set -euo pipefail
        log_info()    { echo "[info] $*"; }
        log_warn()    { echo "[warn] $*"; }
        log_success() { echo "[ok] $*"; }
        log_verbose() { :; }
        SCRIPT_DIR="$1"
        CLAUDE_HOOKS_DIR="$2"
        source "$3/lib/install/hook-parity.sh"
        check_hook_parity
    ' _ "$BATS_TEST_TMPDIR/src" "$DST" "$REPO_ROOT"
}

install_all() { cp "$SRC"/*.sh "$DST/"; }

@test "hook parity: reports success when all hooks match" {
    install_all
    run_parity
    [ "$status" -eq 0 ]
    [[ "$output" == *"3/3 installed hooks match source"* ]]
}

@test "hook parity: names a stale hook" {
    install_all
    printf '#!/usr/bin/env bash\n# beta OLD\n' > "$DST/beta.sh"
    run_parity
    [ "$status" -eq 0 ]
    [[ "$output" == *"STALE     beta.sh"* ]]
    [[ "$output" == *"stale=1"* ]]
}

@test "hook parity: names a missing hook" {
    install_all
    rm "$DST/gamma.sh"
    run_parity
    [[ "$output" == *"MISSING   gamma.sh"* ]]
    [[ "$output" == *"missing=1"* ]]
}

# The blind spot two reviewers found independently: the guardrails installer
# only copies, so a hook dropped from the shipped set lingers and keeps firing
# on every session. A source-only scan reports "N/N match" while it runs.
@test "hook parity: detects an ORPHANED installed hook no longer shipped" {
    install_all
    printf '#!/usr/bin/env bash\n# dropped from the repo, still executing\n' > "$DST/removed-hook.sh"
    run_parity
    [[ "$output" == *"ORPHANED  removed-hook.sh"* ]]
    [[ "$output" == *"orphaned=1"* ]]
    [[ "$output" != *"3/3 installed hooks match source"* ]]
}

@test "hook parity: orphan detection does not misfire when sets match" {
    install_all
    run_parity
    [[ "$output" != *"ORPHANED"* ]]
}

# cmp exit 1 (differ) and 2 (trouble) both make `! cmp` true. Folding them
# together tells the user to reinstall when the real fix is chmod.
@test "hook parity: an unreadable hook is UNREADABLE, not STALE" {
    install_all
    chmod 000 "$DST/beta.sh"
    run_parity
    chmod 644 "$DST/beta.sh"
    if [[ "$output" == *"unreadable=0"* ]]; then
        skip "running as a user that can read mode-000 files (e.g. root)"
    fi
    [[ "$output" == *"UNREADABLE beta.sh"* ]]
    [[ "$output" != *"STALE     beta.sh"* ]]
}

@test "hook parity: warns but does not fail when hooks dir is absent" {
    rm -rf "$DST"
    run_parity
    [ "$status" -eq 0 ]
    [[ "$output" == *"are NOT installed"* ]]
}

@test "hook parity: emits one machine-readable status line on drift" {
    install_all
    rm "$DST/gamma.sh"
    run_parity
    [[ "$output" == *"HOOK_PARITY_STATUS=drift stale=0 missing=1 orphaned=0 unreadable=0 total=3"* ]]
}

@test "hook parity: advisory by default (exit 0) even with total drift" {
    rm -f "$DST"/*.sh
    run_parity
    [ "$status" -eq 0 ]
    [[ "$output" == *"missing=3"* ]]
}

@test "hook parity: HOOK_PARITY_STRICT=1 exits non-zero on drift" {
    install_all
    rm "$DST/gamma.sh"
    HOOK_PARITY_STRICT=1 run_parity
    [ "$status" -eq 2 ]
}

@test "hook parity: HOOK_PARITY_STRICT=1 still exits 0 when clean" {
    install_all
    HOOK_PARITY_STRICT=1 run_parity
    [ "$status" -eq 0 ]
}

@test "hook parity: no source hooks dir is a clean skip" {
    rm -rf "$BATS_TEST_TMPDIR/src/tools/claude-hooks"
    run_parity
    [ "$status" -eq 0 ]
    [[ "$output" != *"STALE"* ]]
}

@test "hook parity: wired into install_claude_guardrails, after the install attempt" {
    grep -qE '^\s+check_hook_parity \|\| HOOK_PARITY_EXIT_CODE=\$\?$' "$REPO_ROOT/install.sh"
    # Must be inside install_claude_guardrails(), not validate_installation():
    # both call sites run validate_installation BEFORE guardrails install, so a
    # call from there warns "not installed" moments before installing.
    awk '/^install_claude_guardrails\(\) \{/,/^\}/' "$REPO_ROOT/install.sh" \
        | grep -q 'check_hook_parity'
}

@test "hook parity: install.sh no longer discards the guardrails script output" {
    ! grep -q 'bash "\$guardrails_script" >/dev/null 2>&1' "$REPO_ROOT/install.sh"
    grep -q 'Kill switch ON' "$REPO_ROOT/install.sh"
}

# Portability guard that runs EVERYWHERE, including ubuntu CI.
#
# install.sh runs `set -euo pipefail`, and bash 3.2 -- still /bin/bash on macOS
# -- aborts on "${empty_array[@]}" as an unbound variable. bash 5 does not, so a
# runtime test of that abort can only run where bash 3.x exists. CI is
# ubuntu-only, and bats renders a `skip` as `ok`, so a skipping runtime test
# would report green forever while never executing. Assert the SAFE IDIOM
# instead: every element expansion must use the "${arr[@]+...}" form, which is
# correct on every bash version. This assertion cannot skip.
@test "hook parity: no bare array expansion that would abort bash 3.2 under set -u" {
    local bare
    bare="$(grep -nE '"\$\{(stale|missing|orphaned|unreadable)\[@\]\}"' \
        "$REPO_ROOT/lib/install/hook-parity.sh" | grep -v '\[@\]+' || true)"
    [ -z "$bare" ] || {
        echo "Bare array expansions (unsafe on bash 3.2 under set -u):"
        echo "$bare"
        false
    }
}

@test "hook parity: module parses under bash 3.2 when available" {
    if [[ ! -x /bin/bash ]] || ! /bin/bash --version 2>/dev/null | head -1 | grep -q 'version 3\.'; then
        skip "no bash 3.x at /bin/bash (expected on Linux CI; the idiom test above covers this everywhere)"
    fi
    run /bin/bash -n "$REPO_ROOT/lib/install/hook-parity.sh"
    [ "$status" -eq 0 ]
}

# Round 2 Critical: `check_hook_parity || true` made HOOK_PARITY_STRICT a lie to
# any CI wrapper running `HOOK_PARITY_STRICT=1 install.sh || fail` -- the strict
# exit code never reached install.sh's own status. The verdict is now recorded
# into HOOK_PARITY_EXIT_CODE and returned from main().
@test "hook parity: strict verdict is recorded, not swallowed, in install.sh" {
    ! grep -q 'check_hook_parity || true' "$REPO_ROOT/install.sh"
    awk '/^install_claude_guardrails\(\) \{/,/^\}/' "$REPO_ROOT/install.sh" \
        | grep -q 'check_hook_parity || HOOK_PARITY_EXIT_CODE=\$?'
}

@test "hook parity: main() propagates HOOK_PARITY_EXIT_CODE from both exit paths" {
    local returns
    returns="$(grep -c 'return "\$HOOK_PARITY_EXIT_CODE"' "$REPO_ROOT/install.sh")"
    [ "$returns" -eq 2 ]
    grep -qE '^HOOK_PARITY_EXIT_CODE=0$' "$REPO_ROOT/install.sh"
}

# Round 2 Low: install.sh replays the guardrails child's captured stdout. log_warn
# is printf '%b', which expands backslash escapes in its ARGUMENT -- so a literal
# \n or \033[ in subprocess output could forge log lines or inject ANSI codes.
# This is the only site where a subprocess's full stdout is replayed.
@test "hook parity: captured child output is printed with %s, not through log_warn" {
    ! grep -q 'log_warn "  output: \$guardrails_out"' "$REPO_ROOT/install.sh"
    grep -q "printf '  output: %s" "$REPO_ROOT/install.sh"
}

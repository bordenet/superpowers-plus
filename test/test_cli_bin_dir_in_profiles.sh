#!/usr/bin/env bash
# shellcheck disable=SC2016
# SC2016: single-quoted template strings throughout this file are intentional —
# $PATH, $HOME, $MANPATH etc. must NOT expand; they are written verbatim into
# fake shell profile files so the production function can match literal forms.
# test/test_cli_bin_dir_in_profiles.sh
# Table-driven tests for _cli_bin_dir_in_profiles() in lib/install/deploy.sh.
# Calls the PRODUCTION function directly — no reimplementation.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# Source deploy.sh to load the production _cli_bin_dir_in_profiles function.
# deploy.sh only defines functions; sourcing it has no side effects.
# shellcheck source=lib/install/deploy.sh
source "$REPO_ROOT/lib/install/deploy.sh"

PASS=0; FAIL=0

# check <label> <expect: FOUND|NOT_FOUND> <profile_content>
#
# profile_content is a single-quoted template. Two placeholders are replaced:
#   __FAKE_BIN__   → absolute path to the fake bin dir (e.g. /tmp/xxx/.local/bin)
#   __FAKE_HOME__  → absolute path to the fake HOME  (e.g. /tmp/xxx)
#
# $HOME is temporarily set to a fresh temp dir so the production function sees
# only the profile file we write — no interference from real profiles.
check() {
    local label="$1" expect="$2" template="$3"
    local tmpdir; tmpdir=$(mktemp -d)
    local fake_bin="$tmpdir/.local/bin"

    local content="${template//__FAKE_BIN__/$fake_bin}"
    content="${content//__FAKE_HOME__/$tmpdir}"
    printf '%s\n' "$content" > "$tmpdir/.bash_profile"

    local saved_home="$HOME"
    HOME="$tmpdir"
    local result
    if _cli_bin_dir_in_profiles "$fake_bin"; then result=FOUND; else result=NOT_FOUND; fi
    HOME="$saved_home"
    rm -rf "$tmpdir"

    if [[ "$result" == "$expect" ]]; then
        printf '  PASS  %s\n' "$label"
        (( PASS++ )) || true
    else
        printf '  FAIL  %-55s (got=%s want=%s)\n' "$label" "$result" "$expect"
        (( FAIL++ )) || true
    fi
}

echo "--- Should FIND (true positives) ---"
check "absolute path, colon before closing quote" \
    FOUND 'export PATH="__FAKE_BIN__:$PATH"'
check "absolute path, at end of PATH value" \
    FOUND 'export PATH="$PATH:__FAKE_BIN__"'
check "unquoted value" \
    FOUND 'export PATH=__FAKE_BIN__:$PATH'
check "PATH+= form" \
    FOUND 'PATH+="__FAKE_BIN__:"'
# SC2016: intentional — we want literal $HOME / ${HOME} / ~ in the profile file
# shellcheck disable=SC2016
check '\$HOME form' \
    FOUND 'export PATH="$HOME/.local/bin:$PATH"'
# shellcheck disable=SC2016
check '\${HOME} form' \
    FOUND 'export PATH="${HOME}/.local/bin:$PATH"'
check 'tilde form' \
    FOUND 'export PATH="~/.local/bin:$PATH"'

echo "--- Should NOT FIND (true negatives) ---"
check "commented out" \
    NOT_FOUND '# export PATH="__FAKE_BIN__:$PATH"'
check "unrelated variable (no PATH)" \
    NOT_FOUND 'BIN_DIR="__FAKE_BIN__"'
check "MANPATH false positive" \
    NOT_FOUND 'export MANPATH="__FAKE_BIN__:$MANPATH"'
check "MY_PATH false positive" \
    NOT_FOUND 'export MY_PATH="__FAKE_BIN__:$MY_PATH"'
check "LD_LIBRARY_PATH false positive" \
    NOT_FOUND 'export LD_LIBRARY_PATH="__FAKE_BIN__:$LD_LIBRARY_PATH"'
check "suffix mismatch (bin-old)" \
    NOT_FOUND 'export PATH="__FAKE_BIN__-old:$PATH"'
check "dot treated as literal (XlocalXbin)" \
    NOT_FOUND 'export PATH="__FAKE_HOME__/Xlocal/bin:$PATH"'
check "no PATH lines at all" \
    NOT_FOUND 'EDITOR=vim'
check "PATH read but not mutated" \
    NOT_FOUND 'echo "$PATH"'

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"
[[ "$FAIL" -eq 0 ]]

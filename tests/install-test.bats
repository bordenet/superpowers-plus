#!/usr/bin/env bats
# install-test.bats — integration tests for install-augment-superpowers.sh
#
# Three scenarios tested:
#   1. success path        — all artefacts created, exit 0
#   2. interrupted download — EXIT trap removes temp file when curl fails
#   3. syntax-error response — node --check rejects corrupt adapter; original preserved

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
INSTALLER="$REPO_ROOT/install-augment-superpowers.sh"
REAL_LIB="$REPO_ROOT/lib"

setup() {
    TEST_HOME="$(mktemp -d)"
    export HOME="$TEST_HOME"
    FAKE_BIN="$(mktemp -d)"
    export PATH="$FAKE_BIN:$PATH"

    # git stub: creates the expected directory structure on clone;
    # handles --version and passes through all other subcommands safely.
    cat > "$FAKE_BIN/git" << 'STUB'
#!/usr/bin/env bash
case "${1:-}" in
    clone)
        dest="${@: -1}"
        mkdir -p "$dest/skills" "$dest/.git"
        exit 0
        ;;
    --version)
        echo "git version 2.39.0 (stub)"
        exit 0
        ;;
    *)
        # fetch / pull / push / config / etc. — safe no-op in our test scenarios
        exit 0
        ;;
esac
STUB
    chmod +x "$FAKE_BIN/git"

    # Pre-seed lib/ so the installed adapter can require('./lib/...').
    # On a real user install this comes from install.sh (deploy.sh copies lib/).
    mkdir -p "$TEST_HOME/.codex/superpowers-augment"
    cp -r "$REAL_LIB" "$TEST_HOME/.codex/superpowers-augment/lib"
}

teardown() {
    rm -rf "$TEST_HOME" "$FAKE_BIN"
}

# Run the installer from REPO_ROOT so BASH_SOURCE finds the local adapter.
_run_installer() {
    run bash "$INSTALLER" "$@"
}

# Copy the installer to a scratch dir that has no sibling superpowers-augment.js,
# forcing the curl download path instead of the local-checkout path.
_installer_in_tmpdir() {
    local tmpdir
    tmpdir="$(mktemp -d)"
    cp "$INSTALLER" "$tmpdir/install-augment-superpowers.sh"
    echo "$tmpdir"
}

# ─────────────────────────────────────────────────────────────────────────────

@test "success path: all artefacts created and installer exits 0" {
    _run_installer
    [ "$status" -eq 0 ]
    [ -d "$HOME/.codex/superpowers/skills" ]
    [ -f "$HOME/.codex/superpowers-augment/superpowers-augment.js" ]
    [ -f "$HOME/.augment/rules/superpowers.always.md" ]
}

@test "success path: Augment auto-load rule contains bootstrap command" {
    _run_installer
    [ "$status" -eq 0 ]
    grep -q "superpowers-augment.js bootstrap" \
        "$HOME/.augment/rules/superpowers.always.md"
}

@test "interrupted download: EXIT trap removes temp file on curl failure" {
    local installer_dir
    installer_dir="$(_installer_in_tmpdir)"

    # curl stub: simulates interrupted download — writes partial bytes, exits 1.
    cat > "$FAKE_BIN/curl" << 'STUB'
#!/usr/bin/env bash
prev=""
for arg in "$@"; do
    if [[ "$prev" == "-o" ]]; then
        printf 'partial-content\n' > "$arg"
        break
    fi
    prev="$arg"
done
exit 1
STUB
    chmod +x "$FAKE_BIN/curl"

    run bash "$installer_dir/install-augment-superpowers.sh"
    [ "$status" -ne 0 ]

    # EXIT trap must have cleaned up any .tmp.<PID> file.
    local leftover_count
    leftover_count=$(find "$HOME/.codex/superpowers-augment" -name "*.tmp.*" \
                         2>/dev/null | wc -l | tr -d ' ')
    [ "$leftover_count" -eq 0 ]

    rm -rf "$installer_dir"
}

@test "syntax-error response: corrupt adapter rejected, original preserved" {
    local installer_dir
    installer_dir="$(_installer_in_tmpdir)"

    # Seed a known-good sentinel so we can verify it is NOT overwritten.
    local sentinel
    sentinel="/* sentinel-unchanged */"
    printf '%s\n' "$sentinel" \
        > "$HOME/.codex/superpowers-augment/superpowers-augment.js"

    # curl stub: "succeeds" (exit 0) but delivers syntactically invalid JS.
    cat > "$FAKE_BIN/curl" << 'STUB'
#!/usr/bin/env bash
prev=""
for arg in "$@"; do
    if [[ "$prev" == "-o" ]]; then
        printf '!!invalid javascript!!\n' > "$arg"
        break
    fi
    prev="$arg"
done
exit 0
STUB
    chmod +x "$FAKE_BIN/curl"

    run bash "$installer_dir/install-augment-superpowers.sh"
    [ "$status" -ne 0 ]

    # Original adapter must be byte-for-byte unchanged.
    local actual
    actual=$(cat "$HOME/.codex/superpowers-augment/superpowers-augment.js")
    [ "$actual" = "$sentinel" ]

    rm -rf "$installer_dir"
}

#!/usr/bin/env bats

# Behavioral tests for tools/install-hooks.sh backup rotation.
# Covers: first install creates .bak; layered modifications rotated to .bak.<ts>;
# original .bak never overwritten; identical re-install does NOT rotate.

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

setup() {
    SANDBOX="$BATS_TEST_TMPDIR/repo"
    mkdir -p "$SANDBOX/tools"
    cp "$REPO_ROOT/tools/install-hooks.sh" "$SANDBOX/tools/install-hooks.sh"
    # Provide stub hook sources so install_hook has something to install.
    for h in pre-commit pre-push commit-msg post-commit; do
        printf '#!/usr/bin/env bash\n# v1 source\nexit 0\n' > "$SANDBOX/tools/$h"
        chmod +x "$SANDBOX/tools/$h"
    done
    cd "$SANDBOX"
    git init -q >/dev/null
    git config user.email "test@example.com"
    git config user.name "Test"
}

@test "install-hooks: first run installs all four hooks" {
    run bash tools/install-hooks.sh
    [ "$status" -eq 0 ]
    [ -x .git/hooks/pre-commit ]
    [ -x .git/hooks/pre-push ]
    [ -x .git/hooks/commit-msg ]
    [ -x .git/hooks/post-commit ]
}

@test "install-hooks: first install backs up an existing hook to .bak" {
    mkdir -p .git/hooks
    printf '#!/usr/bin/env bash\n# pre-existing user hook\nexit 0\n' > .git/hooks/pre-commit
    chmod +x .git/hooks/pre-commit
    run bash tools/install-hooks.sh
    [ "$status" -eq 0 ]
    [ -f .git/hooks/pre-commit.bak ]
    grep -q "pre-existing user hook" .git/hooks/pre-commit.bak
}

@test "install-hooks: layered modifications rotate to timestamped backup" {
    # Seed .bak by starting from an existing pre-superpowers hook.
    mkdir -p .git/hooks
    printf '#!/usr/bin/env bash\n# PRE-EXISTING\nexit 0\n' > .git/hooks/pre-commit
    chmod +x .git/hooks/pre-commit
    bash tools/install-hooks.sh >/dev/null   # first install: creates .bak
    [ -f .git/hooks/pre-commit.bak ]
    # Simulate a user editing the installed hook (a husky overlay).
    cat >> .git/hooks/pre-commit <<'EOF'
# user-layered modification
EOF
    # Re-run install: the user mod must be preserved under .bak.<timestamp>.
    run bash tools/install-hooks.sh
    [ "$status" -eq 0 ]
    rotated=$(ls .git/hooks/pre-commit.bak.* 2>/dev/null | head -1)
    [ -n "$rotated" ]
    grep -q "user-layered modification" "$rotated"
}

@test "install-hooks: original .bak is never overwritten" {
    mkdir -p .git/hooks
    printf '#!/usr/bin/env bash\n# ORIGINAL\nexit 0\n' > .git/hooks/pre-commit
    chmod +x .git/hooks/pre-commit
    bash tools/install-hooks.sh >/dev/null
    grep -q "ORIGINAL" .git/hooks/pre-commit.bak
    # Now layer a change and re-install.
    echo "# layered" >> .git/hooks/pre-commit
    bash tools/install-hooks.sh >/dev/null
    # The .bak must still be the ORIGINAL pre-existing hook, not the layered one.
    grep -q "ORIGINAL" .git/hooks/pre-commit.bak
    ! grep -q "layered" .git/hooks/pre-commit.bak
    # The layered version must be preserved under a timestamped rotation.
    rotated=$(ls .git/hooks/pre-commit.bak.* 2>/dev/null | head -1)
    [ -n "$rotated" ]
    grep -q "layered" "$rotated"
}

@test "install-hooks: identical re-install does not create timestamped backups" {
    bash tools/install-hooks.sh >/dev/null
    bash tools/install-hooks.sh >/dev/null
    # No .bak.<timestamp> files should exist.
    rotated=$(ls .git/hooks/pre-commit.bak.* 2>/dev/null || true)
    [ -z "$rotated" ]
}

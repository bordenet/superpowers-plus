#!/usr/bin/env bats
# install-main-test.bats — integration tests for install_skills() in install.sh
#
# Covers: skill deployment to SKILLS_DIR and CLAUDE_SKILLS_DIR, manifest
# creation, _shared/ deployment, and the --skip-augment flag.

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
INSTALLER="$REPO_ROOT/install.sh"

setup() {
    TEST_HOME="$(mktemp -d)"
    export HOME="$TEST_HOME"
    FAKE_BIN="$(mktemp -d)"
    export PATH="$FAKE_BIN:$PATH"

    # Minimal git stub so installer doesn't need a real git
    cat > "$FAKE_BIN/git" << 'STUB'
#!/usr/bin/env bash
case "${1:-}" in
    --version) echo "git version 2.39.0 (stub)"; exit 0 ;;
    rev-parse) exit 1 ;;   # not a git repo — suppresses hook install
    *) exit 0 ;;
esac
STUB
    chmod +x "$FAKE_BIN/git"

    # node stub: pass --check (syntax), fail --version lookup used by deps check
    cat > "$FAKE_BIN/node" << 'STUB'
#!/usr/bin/env bash
if [[ "${1:-}" == "--check" ]]; then exit 0; fi
echo "v20.0.0"
exit 0
STUB
    chmod +x "$FAKE_BIN/node"
}

teardown() {
    rm -rf "$TEST_HOME" "$FAKE_BIN"
}

_run_installer() {
    run bash "$INSTALLER" --yes --skip-augment "$@"
}

@test "install_skills: skills deployed to CLAUDE_SKILLS_DIR" {
    _run_installer
    [ "$status" -eq 0 ]
    local skills_dir="$HOME/.claude/skills"
    [ -d "$skills_dir" ]
    # At least one skill directory must exist
    local count
    count=$(find "$skills_dir" -maxdepth 1 -mindepth 1 -type d | wc -l | tr -d ' ')
    [ "$count" -gt 0 ]
}

@test "install_skills: manifest written with at least 10 skill names" {
    _run_installer
    [ "$status" -eq 0 ]
    local manifest="$HOME/.codex/superpowers-plus/install-state/skills.manifest"
    [ -f "$manifest" ]
    local count
    count=$(wc -l < "$manifest" | tr -d ' ')
    [ "$count" -ge 10 ]
}

@test "install_skills: each manifest entry has a corresponding skill dir" {
    _run_installer
    [ "$status" -eq 0 ]
    local manifest="$HOME/.codex/superpowers-plus/install-state/skills.manifest"
    local skills_dir="$HOME/.claude/skills"
    [ -f "$manifest" ]
    while IFS= read -r name; do
        [[ -z "$name" ]] && continue
        [ -d "$skills_dir/$name" ]
    done < "$manifest"
}

@test "install_skills: _shared/ deployed alongside skills" {
    _run_installer
    [ "$status" -eq 0 ]
    [ -d "$HOME/.claude/skills/_shared" ]
}

@test "install_skills: obra path (~/.codex/superpowers) NOT created" {
    _run_installer
    [ "$status" -eq 0 ]
    [ ! -d "$HOME/.codex/superpowers" ]
}

@test "install_skills: skills source from skills/ tree, not obra path" {
    _run_installer
    [ "$status" -eq 0 ]
    local manifest="$HOME/.codex/superpowers-plus/install-state/skills.manifest"
    # A bundled obra skill (now in our skills/ tree) should appear in the manifest
    grep -q "using-superpowers\|dispatching-parallel-agents\|executing-plans" "$manifest"
}

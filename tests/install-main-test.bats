#!/usr/bin/env bats
# install-main-test.bats — integration tests for install_skills() in install.sh
#
# Covers: skill deployment to SKILLS_DIR and CLAUDE_SKILLS_DIR, manifest
# creation, _shared/ deployment, and the --skip-augment flag.

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
INSTALLER="$REPO_ROOT/install.sh"

# Default deployment assertions are read-only. Build their real profile once
# per file; state transitions below retain independent actual installer runs.
_profile_digest() {
    python3 - "$1" <<'PYDIGEST'
import hashlib,os,pathlib,stat,sys
root=pathlib.Path(sys.argv[1]);h=hashlib.sha256()
for p in sorted(root.rglob('*')):
    value=p.lstat();h.update(p.relative_to(root).as_posix().encode()+b'\0'+str(stat.S_IMODE(value.st_mode)).encode())
    if p.is_symlink():h.update(b'link\0'+os.readlink(p).encode())
    elif p.is_file():h.update(b'file\0'+hashlib.sha256(p.read_bytes()).digest())
    else:h.update(b'directory')
print(h.hexdigest())
PYDIGEST
}

_init_profile() {
    local profile="$1" bin="$2" initial_path="$PATH" entry filtered=""
    local real_bash real_python
    real_bash=$(command -v bash)
    real_python=$(command -v python3)
    mkdir -p "$profile/.local/bin" "$bin"
    export HOME="$(cd "$profile" && pwd -P)"
    export CODEX_HOME="$HOME/.codex" CLAUDE_CONFIG_DIR="$HOME/.claude"
    unset TODO_FILE_PATH
    # Prevent the real CLI linker from selecting writable machine-global bin.
    # Preserve required Homebrew runtimes through private executable links.
    ln -s "$real_bash" "$bin/bash"
    ln -s "$real_python" "$bin/python3"
    local remaining="$initial_path"
    while [[ -n "$remaining" ]]; do
        entry="${remaining%%:*}"
        [[ "$remaining" == *:* ]] && remaining="${remaining#*:}" || remaining=""
        [[ "${entry%/}" == /usr/local/bin ]] && continue
        [[ -n "$entry" ]] && filtered+="${filtered:+:}$entry"
    done
    export PATH="$bin:$HOME/.local/bin:$filtered"
    local FAKE_BIN="$bin"
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

setup_file() {
    DEFAULT_INSTALL_HOME="$BATS_FILE_TMPDIR/default-home"
    DEFAULT_INSTALL_BIN="$BATS_FILE_TMPDIR/default-bin"
    DEFAULT_INSTALL_LOG="$BATS_FILE_TMPDIR/default-install.log"
    DEFAULT_INSTALL_STATUS="$BATS_FILE_TMPDIR/default-install.status"
    DEFAULT_INSTALL_CALLS="$BATS_FILE_TMPDIR/default-install.calls"
    DEFAULT_INSTALL_DIGEST="$BATS_FILE_TMPDIR/default-install.digest"
    export DEFAULT_INSTALL_HOME DEFAULT_INSTALL_BIN DEFAULT_INSTALL_LOG
    export DEFAULT_INSTALL_STATUS DEFAULT_INSTALL_CALLS DEFAULT_INSTALL_DIGEST
    local rc=0
    (
        _init_profile "$DEFAULT_INSTALL_HOME" "$DEFAULT_INSTALL_BIN"
        printf 'actual installer\n' >> "$DEFAULT_INSTALL_CALLS"
        bash "$INSTALLER" --yes --skip-augment
    ) > "$DEFAULT_INSTALL_LOG" 2>&1 || rc=$?
    printf '%s\n' "$rc" > "$DEFAULT_INSTALL_STATUS"
    if [[ "$rc" -ne 0 ]]; then cat "$DEFAULT_INSTALL_LOG"; return "$rc"; fi
    _profile_digest "$DEFAULT_INSTALL_HOME" > "$DEFAULT_INSTALL_DIGEST"
}

teardown_file() {
    local current
    current=$(_profile_digest "$DEFAULT_INSTALL_HOME")
    [[ "$current" == "$(cat "$DEFAULT_INSTALL_DIGEST")" ]] || {
        echo 'read-only installer fixture was mutated' >&3; return 1;
    }
    [[ "$(wc -l < "$DEFAULT_INSTALL_CALLS" | tr -d ' ')" -eq 1 ]]
}

setup() {
    TEST_HOME="$(mktemp -d)"
    FAKE_BIN="$(mktemp -d)"
    _init_profile "$TEST_HOME" "$FAKE_BIN"
}

_use_default_install() {
    export HOME="$(cd "$DEFAULT_INSTALL_HOME" && pwd -P)"
    export CODEX_HOME="$HOME/.codex" CLAUDE_CONFIG_DIR="$HOME/.claude"
    status=$(cat "$DEFAULT_INSTALL_STATUS")
    output=$(cat "$DEFAULT_INSTALL_LOG")
    [[ "$status" -eq 0 ]]
}

teardown() {
    rm -rf "$TEST_HOME" "$FAKE_BIN"
}

_run_installer() {
    run bash "$INSTALLER" --yes --skip-augment "$@"
}

@test "install_skills: skills deployed to CLAUDE_SKILLS_DIR" {
    _use_default_install
    [ "$status" -eq 0 ]
    local skills_dir="$HOME/.claude/skills"
    [ -d "$skills_dir" ]
    # At least one skill directory must exist
    local count
    count=$(find "$skills_dir" -maxdepth 1 -mindepth 1 -type d | wc -l | tr -d ' ')
    [ "$count" -gt 0 ]
}

@test "install_skills: manifest written with at least 10 skill names" {
    _use_default_install
    [ "$status" -eq 0 ]
    local manifest="$HOME/.codex/superpowers-plus/install-state/skills.manifest"
    [ -f "$manifest" ]
    local count
    count=$(wc -l < "$manifest" | tr -d ' ')
    [ "$count" -ge 10 ]
}

@test "install_skills: each manifest entry has a corresponding skill dir" {
    _use_default_install
    [ "$status" -eq 0 ]
    local manifest="$HOME/.codex/superpowers-plus/install-state/skills.manifest"
    local skills_dir="$HOME/.claude/skills"
    [ -f "$manifest" ]
    while IFS= read -r name; do
        [[ -z "$name" ]] && continue
        [ -d "$skills_dir/$name" ]
    done < "$manifest"
}

@test "install_libs: runtime libs deployed and lib/install/ excluded" {
    _use_default_install
    [ "$status" -eq 0 ]
    local libs_dir="$HOME/.codex/superpowers-plus/lib"
    [ -d "$libs_dir" ]
    # A runtime lib that tools/ load via require('../lib/...') must be present;
    # absence is the exact "Cannot find module" regression install_libs prevents.
    [ -f "$libs_dir/wiki-publish.js" ]
    # The non-recursive *.js glob must NOT ship the install-only lib/install/ dir.
    [ ! -e "$libs_dir/install" ]
    # Manifest records the shipped libs.
    [ -f "$HOME/.codex/superpowers-plus/install-state/libs.manifest" ]
}

@test "install_skills: _shared/ deployed alongside skills" {
    _use_default_install
    [ "$status" -eq 0 ]
    [ -d "$HOME/.claude/skills/_shared" ]
}

@test "install_skills: obra path (~/.codex/superpowers) NOT created" {
    _use_default_install
    [ "$status" -eq 0 ]
    [ ! -d "$HOME/.codex/superpowers" ]
}

@test "install_skills: skills source from skills/ tree, not obra path" {
    _use_default_install
    [ "$status" -eq 0 ]
    local manifest="$HOME/.codex/superpowers-plus/install-state/skills.manifest"
    # A bundled obra skill (now in our skills/ tree) should appear in the manifest
    grep -q "using-superpowers\|dispatching-parallel-agents\|executing-plans" "$manifest"
}

# --- --categories subset install ---

@test "--categories: installs only the requested categories (plus _shared)" {
    _run_installer --categories security
    [ "$status" -eq 0 ]
    local skills_dir="$HOME/.claude/skills"
    [ -d "$skills_dir/_shared" ]
    [ -d "$skills_dir/public-repo-ip-audit" ]   # a real skills/security/ skill
    # Nothing from an excluded category should be present
    [ ! -d "$skills_dir/using-superpowers" ]     # a real skills/engineering/ skill
}

@test "--categories: persists the selection to the state file" {
    _run_installer --categories security
    [ "$status" -eq 0 ]
    local state_file="$HOME/.codex/superpowers-install-categories"
    [ -f "$state_file" ]
    [[ "$(cat "$state_file")" == "security" ]]
}

@test "--categories: bare re-run with no flag reuses the remembered selection" {
    _run_installer --categories security
    [ "$status" -eq 0 ]
    run bash "$INSTALLER" --yes --skip-augment
    [ "$status" -eq 0 ]
    [[ "$output" == *"Reusing remembered category selection: security"* ]]
    [ -d "$HOME/.claude/skills/public-repo-ip-audit" ]
    [ ! -d "$HOME/.claude/skills/using-superpowers" ]
}

@test "--categories=all: installs everything and clears the remembered selection" {
    _run_installer --categories security
    [ -f "$HOME/.codex/superpowers-install-categories" ]
    _run_installer --categories=all --force
    [ "$status" -eq 0 ]
    [ ! -f "$HOME/.codex/superpowers-install-categories" ]
    [ -d "$HOME/.claude/skills/using-superpowers" ]   # engineering, now present
    [ -d "$HOME/.claude/skills/public-repo-ip-audit" ] # security, still present
}

@test "--categories: switching to a smaller subset prunes the previously-installed categories" {
    _run_installer
    [ -d "$HOME/.claude/skills/using-superpowers" ]
    _run_installer --categories writing --force
    [ "$status" -eq 0 ]
    [ ! -d "$HOME/.claude/skills/using-superpowers" ]
    [ -d "$HOME/.claude/skills/_shared" ]
}

@test "--categories: unknown category name errors clearly with the valid list" {
    _run_installer --categories not-a-real-category
    [ "$status" -eq 1 ]
    [[ "$output" == *"unknown category 'not-a-real-category'"* ]]
    [[ "$output" == *"Available categories:"* ]]
    [[ "$output" == *"security"* ]]
}

@test "--categories: --categories=engineering,writing installs both" {
    _run_installer --categories=engineering,writing
    [ "$status" -eq 0 ]
    [ -d "$HOME/.claude/skills/using-superpowers" ]
    [ -d "$HOME/.claude/skills/writing-skills" ]
    [ ! -d "$HOME/.claude/skills/public-repo-ip-audit" ]
}

@test "--categories: missing value after --categories errors instead of consuming the next flag" {
    run bash "$INSTALLER" --categories
    [ "$status" -eq 1 ]
    [[ "$output" == *"--categories requires a value"* ]]
}

@test "--categories: a corrupted (multi-line) remembered state file falls back to installing everything, with a warning, instead of silently truncating" {
    mkdir -p "$HOME/.codex"
    printf 'security\nengineering\n' > "$HOME/.codex/superpowers-install-categories"
    _run_installer
    [ "$status" -eq 0 ]
    [[ "$output" == *"is invalid (stale or corrupted)"* ]]
    [ -d "$HOME/.claude/skills/using-superpowers" ]     # engineering present
    [ -d "$HOME/.claude/skills/public-repo-ip-audit" ]  # security present -- proves "everything", not just the first line
    [ ! -f "$HOME/.codex/superpowers-install-categories" ]  # invalid state cleared, not left to fail again next run
}

@test "--categories: an unknown/stale category name in the remembered state file falls back to installing everything, with a warning, instead of silently installing nothing" {
    mkdir -p "$HOME/.codex"
    printf 'not-a-real-category' > "$HOME/.codex/superpowers-install-categories"
    _run_installer
    [ "$status" -eq 0 ]
    [[ "$output" == *"is invalid (stale or corrupted)"* ]]
    local skills_dir="$HOME/.claude/skills"
    local count
    count=$(find "$skills_dir" -maxdepth 1 -mindepth 1 -type d | wc -l | tr -d ' ')
    [ "$count" -gt 10 ]   # everything, not just _shared alone
}

# --- --uninstall alias ---

@test "--uninstall: forwards to uninstall.sh with remaining args" {
    run bash "$INSTALLER" --uninstall --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"uninstall.sh"* ]]
}

@test "--uninstall: strips only --uninstall itself, forwarding sibling flags intact" {
    # --dry-run is a real uninstall.sh flag. If --uninstall's arg-stripping
    # loop were buggy (e.g. dropped or reordered other args), --dry-run
    # would never reach uninstall.sh and this would fall through to a
    # real (interactive-prompting) removal attempt instead.
    _run_installer --skip-augment
    run bash "$INSTALLER" --uninstall --dry-run --yes
    [ "$status" -eq 0 ]
    [[ "$output" == *"[DRY-RUN] Would remove:"* ]]
}

@test "read-only default assertions share one immutable real installation" {
    [ "$(cat "$DEFAULT_INSTALL_STATUS")" -eq 0 ]
    [ "$(wc -l < "$DEFAULT_INSTALL_CALLS" | tr -d ' ')" -eq 1 ]
    [ "$(_profile_digest "$DEFAULT_INSTALL_HOME")" = "$(cat "$DEFAULT_INSTALL_DIGEST")" ]
}

#!/usr/bin/env bats

# Execute the skill's actual creation fence, without implicit errexit, so a
# failed command cannot be hidden by the test harness's own shell options.
setup() {
    SANDBOX="$(cd "$BATS_TEST_TMPDIR" && pwd -P)"
    export HOME="$SANDBOX/private home"
    REPO="$SANDBOX/project with spaces"
    mkdir -p "$HOME" "$REPO"
    git init -q -b main "$REPO"
    git -C "$REPO" -c user.name=Fixture -c user.email=fixture@example.invalid \
        commit -q --allow-empty -m base
    cd "$REPO"
    export project="project with spaces" BRANCH_NAME="feature/topic"
    export SETUP_MARKER="$SANDBOX/setup-ran"
    CREATE_SCRIPT="$SANDBOX/create.bash"
    local root
    root="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd -P)"
    awk '
        /^### 2\. Create Worktree$/ { section=1; next }
        section && /^```bash$/ { fence=1; next }
        fence && /^```$/ { exit }
        fence { print }
    ' "$root/skills/engineering/using-git-worktrees/skill.md" > "$CREATE_SCRIPT"
    [ -s "$CREATE_SCRIPT" ]
    printf '\nprintf "%%s\\n" "$PWD" > "$SETUP_MARKER"\n' >> "$CREATE_SCRIPT"
}

@test "creation fence puts the global worktree outside the project with spaces" {
    export LOCATION="$HOME/.config/superpowers/worktrees/$project"
    run bash +e "$CREATE_SCRIPT"
    [ "$status" -eq 0 ]
    local expected="$HOME/.config/superpowers/worktrees/$project/$BRANCH_NAME"
    [ "$(cat "$SETUP_MARKER")" = "$expected" ]
    [ "$(git -C "$expected" rev-parse --show-toplevel)" = "$expected" ]
    [ ! -e "$REPO/~" ]
}

@test "creation fence accepts expanded and literal-tilde global directory choices" {
    local choice i=0 expected
    for choice in "$HOME/.config/superpowers/worktrees" \
        '~/.config/superpowers/worktrees' '~/.config/superpowers/worktrees/project'; do
        i=$((i + 1))
        export LOCATION="$choice" BRANCH_NAME="feature/global-$i"
        run bash +e "$CREATE_SCRIPT"
        [ "$status" -eq 0 ]
        expected="$HOME/.config/superpowers/worktrees/$project/$BRANCH_NAME"
        [ "$(cat "$SETUP_MARKER")" = "$expected" ]
    done
}

@test "creation fence preserves both project-local directory choices" {
    local choice expected i=0
    for choice in .worktrees worktrees; do
        i=$((i + 1))
        export LOCATION="$choice" BRANCH_NAME="feature/local-$i"
        run bash +e "$CREATE_SCRIPT"
        [ "$status" -eq 0 ]
        expected="$REPO/$LOCATION/$BRANCH_NAME"
        [ "$(cat "$SETUP_MARKER")" = "$expected" ]
    done
}

@test "creation failure stops before entering an existing directory or running setup" {
    export LOCATION=.worktrees BRANCH_NAME=main
    mkdir -p "$REPO/.worktrees/main"
    printf 'keep\n' > "$REPO/.worktrees/main/foreign-note"
    run bash +e "$CREATE_SCRIPT"
    [ "$status" -ne 0 ]
    [ ! -e "$SETUP_MARKER" ]
    [ "$(cat "$REPO/.worktrees/main/foreign-note")" = keep ]
}

@test "directory-entry failure stops before setup after successful creation" {
    export LOCATION=.worktrees REAL_GIT
    REAL_GIT="$(command -v git)"
    export MOVED_DESTINATION="$SANDBOX/moved-worktree"
    mkdir -p "$SANDBOX/bin"
    cat > "$SANDBOX/bin/git" <<'WRAPPER'
#!/usr/bin/env bash
set -euo pipefail
"$REAL_GIT" "$@"
if [[ "$1" == worktree && "$2" == add ]]; then
    mv "$3" "$MOVED_DESTINATION"
fi
WRAPPER
    chmod +x "$SANDBOX/bin/git"
    export PATH="$SANDBOX/bin:$PATH"
    run bash +e "$CREATE_SCRIPT"
    [ -d "$MOVED_DESTINATION" ]
    [ "$status" -ne 0 ]
    [ ! -e "$SETUP_MARKER" ]
}

@test "unknown worktree directory choice stops before setup" {
    export LOCATION=unexpected-location
    run bash +e "$CREATE_SCRIPT"
    [ "$status" -ne 0 ]
    [ ! -e "$SETUP_MARKER" ]
}

@test "project-local creation cannot be redirected by CDPATH" {
    export LOCATION=worktrees CDPATH="$SANDBOX/elsewhere"
    mkdir -p "$CDPATH/worktrees/$BRANCH_NAME"
    run bash +e "$CREATE_SCRIPT"
    [ "$status" -eq 0 ]
    [ "$(cat "$SETUP_MARKER")" = "$REPO/worktrees/$BRANCH_NAME" ]
}

@test "creation fence also supports the system Bash" {
    export LOCATION="$HOME/.config/superpowers/worktrees/$project"
    run /bin/bash +e "$CREATE_SCRIPT"
    [ "$status" -eq 0 ]
    [ "$(cat "$SETUP_MARKER")" = "$HOME/.config/superpowers/worktrees/$project/$BRANCH_NAME" ]
}

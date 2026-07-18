#!/usr/bin/env bats
# Unit tests for tools/fence-scan.sh -- the extraction+check engine for
# fenced bash/sh blocks embedded in skill/doc markdown. Exercises:
#   - extraction: only ```bash / ```sh fences are pulled out; any other tag
#     (or a bare ``` fence) is ignored entirely
#   - `bash -n` as the BLOCKING check (exit 1 on any syntax failure)
#   - ShellCheck as an ADVISORY-ONLY check (printed, never blocks)
#   - both worktree mode (no --sha) and git-object mode (--sha SHA)
#   - graceful skip when a requested path has no content (worktree: file
#     absent; --sha mode: not present at that commit, e.g. deleted)

setup() {
    HELPER="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)/tools/fence-scan.sh"
    WORK="$(mktemp -d)"
    cd "$WORK" || exit 1
}

teardown() {
    rm -rf "$WORK"
}

# ------------------------------ extraction: inclusions ------------------------

@test "valid bash fence -> PASS (exit 0), fence counted" {
    cat > a.md <<'EOF'
# doc

```bash
echo "hello"
ls -la
```

more prose
EOF
    run bash "$HELPER" a.md
    [ "$status" -eq 0 ]
    [[ "$output" == *"fences found: 1"* ]]
}

@test "valid sh fence -> PASS (exit 0)" {
    cat > a.md <<'EOF'
```sh
echo "hi"
```
EOF
    run bash "$HELPER" a.md
    [ "$status" -eq 0 ]
    [[ "$output" == *"fences found: 1"* ]]
}

# ------------------------------ extraction: exclusions ------------------------

@test "non-bash-tagged fence (python) is ignored entirely" {
    cat > a.md <<'EOF'
```python
def f(:
    pass
```
EOF
    run bash "$HELPER" a.md
    [ "$status" -eq 0 ]
    [[ "$output" == *"fences found: 0"* ]]
}

@test "bare \`\`\` fence with no language tag is ignored entirely" {
    cat > a.md <<'EOF'
```
this is not shell, it is untagged
if broken then
```
EOF
    run bash "$HELPER" a.md
    [ "$status" -eq 0 ]
    [[ "$output" == *"fences found: 0"* ]]
}

@test "file with no fences at all -> PASS, zero fences" {
    cat > a.md <<'EOF'
# Just prose

No code blocks here at all.
EOF
    run bash "$HELPER" a.md
    [ "$status" -eq 0 ]
    [[ "$output" == *"fences found: 0"* ]]
}

# ------------------------------- bash -n: blocking -----------------------------

@test "broken bash fence (missing fi) -> FAIL (exit 1), names file and fence line" {
    cat > a.md <<'EOF'
line one
line two

```bash
if [ -f foo ]; then
  echo "hi"
```

trailing prose
EOF
    run bash "$HELPER" a.md
    [ "$status" -eq 1 ]
    [[ "$output" == *"a.md:4"* ]]
    [[ "$output" == *"bash -n FAILED"* ]]
}

@test "broken sh fence (unterminated string) -> FAIL (exit 1)" {
    cat > a.md <<'EOF'
```sh
echo "unterminated
```
EOF
    run bash "$HELPER" a.md
    [ "$status" -eq 1 ]
    [[ "$output" == *"bash -n FAILED"* ]]
}

@test "unterminated fence (opened, never closed) -> FAIL (exit 1), reported distinctly" {
    cat > a.md <<'EOF'
prose

```bash
echo "this fence never closes"
EOF
    run bash "$HELPER" a.md
    [ "$status" -eq 1 ]
    [[ "$output" == *"never closed"* ]]
}

@test "mixed file: one valid + one broken fence -> FAIL overall, only the broken one is flagged" {
    cat > a.md <<'EOF'
```bash
echo "this one is fine"
```

some prose in between

```bash
if [ -f foo ]; then
  echo "broken, missing fi"
```
EOF
    run bash "$HELPER" a.md
    [ "$status" -eq 1 ]
    [[ "$output" == *"fences found: 2"* ]]
    # exactly one bash -n failure reported
    [[ "$(echo "$output" | grep -c 'bash -n FAILED')" -eq 1 ]]
}

@test "multiple files: only the second has a broken fence -> FAIL, correct file named" {
    cat > good.md <<'EOF'
```bash
echo "fine"
```
EOF
    cat > bad.md <<'EOF'
```bash
if [ -f foo ]; then
  echo "broken"
```
EOF
    run bash "$HELPER" good.md bad.md
    [ "$status" -eq 1 ]
    [[ "$output" == *"bad.md:1"* ]]
    [[ "$output" != *"good.md:1 "* ]]
}

# --------------------------- shellcheck: advisory only -------------------------

@test "shellcheck-flagged-but-bash-n-valid fence -> PASS (exit 0), advisory noted" {
    if ! command -v shellcheck >/dev/null 2>&1; then
        skip "shellcheck not installed on this machine"
    fi
    cat > a.md <<'EOF'
```bash
UNUSED_VAR="value"
echo "done"
```
EOF
    run bash "$HELPER" a.md
    [ "$status" -eq 0 ]
    [[ "$output" == *"shellcheck advisory"* ]]
    [[ "$output" == *"SC2034"* ]]
}

@test "shellcheck missing shebang (SC2148) is suppressed -- extraction artifact, not a real finding" {
    if ! command -v shellcheck >/dev/null 2>&1; then
        skip "shellcheck not installed on this machine"
    fi
    cat > a.md <<'EOF'
```bash
echo "totally fine, no shebang because it is an extracted fragment"
```
EOF
    run bash "$HELPER" a.md
    [ "$status" -eq 0 ]
    [[ "$output" != *"SC2148"* ]]
}

@test "shellcheck absent from PATH: bash -n blocking still works, no advisory noise, no crash" {
    cat > a.md <<'EOF'
```bash
if [ -f foo ]; then
  echo "broken, missing fi"
```
EOF
    # Build a minimal, fully-controlled PATH containing symlinks to only the
    # exact binaries fence-scan.sh needs (resolved from their real locations
    # via `command -v`), deliberately excluding shellcheck. Directory-level
    # PATH stripping (removing any dir containing shellcheck) is NOT
    # portable: on some CI images shellcheck lives in the same directory as
    # bash/coreutils (e.g. /usr/bin), so excluding that directory breaks the
    # test harness itself with a bare "command not found" (exit 127) instead
    # of exercising the intended no-shellcheck code path.
    ISOLATED_BIN="$(mktemp -d)"
    for tool in bash cat mktemp rm sed; do
        tool_path="$(command -v "$tool")"
        ln -s "$tool_path" "$ISOLATED_BIN/$tool"
    done
    PATH="$ISOLATED_BIN" run bash "$HELPER" a.md
    rm -rf "$ISOLATED_BIN"
    [ "$status" -eq 1 ]
    [[ "$output" == *"bash -n FAILED"* ]]
    [[ "$output" != *"shellcheck advisory"* ]]
}

# ------------------------------- --sha (git object) mode -----------------------

@test "--sha mode reads the COMMITTED content, not a dirty working-tree edit" {
    git init -q --initial-branch=main
    git config user.email t@t; git config user.name t
    cat > a.md <<'EOF'
```bash
echo "committed and valid"
```
EOF
    git add a.md; git commit -q -m base
    SHA="$(git rev-parse HEAD)"

    # Dirty the working copy with a syntax error AFTER the commit.
    cat > a.md <<'EOF'
```bash
if [ -f foo ]; then
  echo "broken, but only in the working tree"
```
EOF

    run bash "$HELPER" --sha "$SHA" a.md
    [ "$status" -eq 0 ]
    [[ "$output" == *"fences found: 1"* ]]
}

@test "--sha mode: path not present at that commit (e.g. deleted) is skipped, not an error" {
    git init -q --initial-branch=main
    git config user.email t@t; git config user.name t
    echo x > keep.txt
    git add keep.txt; git commit -q -m base
    SHA="$(git rev-parse HEAD)"

    run bash "$HELPER" --sha "$SHA" never-existed.md
    [ "$status" -eq 0 ]
    [[ "$output" == *"skipped"* ]]
    [[ "$output" == *"never-existed.md"* ]]
}

@test "--sha mode: a real deletion (file existed at an earlier commit, gone at the pushed one) is skipped" {
    git init -q --initial-branch=main
    git config user.email t@t; git config user.name t
    cat > gone.md <<'EOF'
```bash
if broken
```
EOF
    git add gone.md; git commit -q -m "add broken file"
    git rm -q gone.md
    git commit -q -m "remove it"
    SHA="$(git rev-parse HEAD)"

    run bash "$HELPER" --sha "$SHA" gone.md
    [ "$status" -eq 0 ]
    [[ "$output" == *"skipped"* ]]
}

# ----------------------------------- usage errors ------------------------------

@test "no files given -> usage error (exit 2)" {
    run bash "$HELPER"
    [ "$status" -eq 2 ]
}

@test "--sha with a value that does not resolve to a commit -> usage error (exit 2)" {
    git init -q --initial-branch=main
    run bash "$HELPER" --sha not-a-real-sha a.md
    [ "$status" -eq 2 ]
}

@test "a mistyped/unrecognized -- flag among the file args is a loud usage error, not a silent skip" {
    run bash "$HELPER" a.md --shaXYZ
    [ "$status" -eq 2 ]
    [[ "$output" == *"unrecognized flag"* ]]
}

@test "--help exits 0 and prints usage" {
    run bash "$HELPER" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"fence-scan"* ]]
}

@test "worktree mode: file that does not exist on disk is skipped, not an error" {
    run bash "$HELPER" does-not-exist.md
    [ "$status" -eq 0 ]
    [[ "$output" == *"skipped"* ]]
}

@test "empty fence body (opened and immediately closed) -> PASS, counted, no crash" {
    cat > a.md <<'EOF'
```bash
```
EOF
    run bash "$HELPER" a.md
    [ "$status" -eq 0 ]
    [[ "$output" == *"fences found: 1"* ]]
}

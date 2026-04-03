#!/usr/bin/env bats
# Tests for the review token gate system

TOOLS_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../tools" && pwd)"
REAL_REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

setup() {
    export TEST_HOME="$(mktemp -d)"
    export HOME="$TEST_HOME"
    export REVIEW_TOKEN_DIR="${HOME}/.codex/review-tokens"
    mkdir -p "$REVIEW_TOKEN_DIR"
    # Prevent recursive bats invocation when commit-gate.sh runs inside tests
    export SKIP_DEFAULT_TESTS=true
}

teardown() {
    rm -rf "$TEST_HOME"
}

# Create a minimal fixture repo that satisfies harsh-review.sh required files.
# Copies tools/ from the real repo so we test the actual scripts.
_create_fixture_repo() {
    local repo_dir
    repo_dir=$(mktemp -d)
    git -C "$repo_dir" init -q
    git -C "$repo_dir" config user.email "test@test.com"
    git -C "$repo_dir" config user.name "Test"
    # Required files for harsh-review.sh CHECK 7
    # Each file must have content + exactly one trailing newline (CHECK 1)
    printf '# README\n' > "$repo_dir/README.md"
    printf '# AGENTS\n' > "$repo_dir/AGENTS.md"
    printf '# CLAUDE\n' > "$repo_dir/CLAUDE.md"
    printf 'root = true\n' > "$repo_dir/.editorconfig"
    mkdir -p "$repo_dir/docs"
    printf '# Contributing\n' > "$repo_dir/docs/CONTRIBUTING.md"
    printf '# Architecture\n' > "$repo_dir/docs/ARCHITECTURE.md"
    # Copy tools from real repo
    cp -R "$REAL_REPO_ROOT/tools" "$repo_dir/tools"
    # Minimal skills dir (empty is fine — no skills to validate)
    mkdir -p "$repo_dir/skills"
    # Initial commit so git commands work
    git -C "$repo_dir" add -A
    git -C "$repo_dir" commit -q -m "initial"
    printf '%s' "$repo_dir"
}

@test "harsh-review.sh creates a token file on success" {
    local fixture
    fixture=$(_create_fixture_repo)
    run bash "$fixture/tools/harsh-review.sh"
    rm -rf "$fixture"
    [ "$status" -eq 0 ]
    local token_count
    token_count=$(ls -1 "$REVIEW_TOKEN_DIR" 2>/dev/null | wc -l | xargs)
    [ "$token_count" -ge 1 ]
}

@test "token file contains repo root path" {
    local fixture
    fixture=$(_create_fixture_repo)
    run bash "$fixture/tools/harsh-review.sh"
    [ "$status" -eq 0 ]
    local latest_token
    latest_token=$(ls -t "$REVIEW_TOKEN_DIR" | head -1)
    local token_content token_real fixture_real
    token_content=$(cat "$REVIEW_TOKEN_DIR/$latest_token")
    # Resolve symlinks (macOS: /var → /private/var) for reliable comparison
    token_real=$(cd "$token_content" && pwd -P)
    fixture_real=$(cd "$fixture" && pwd -P)
    [ "$token_real" = "$fixture_real" ]
    rm -rf "$fixture"
}

@test "token filename contains a unix timestamp field" {
    local fixture
    fixture=$(_create_fixture_repo)
    run bash "$fixture/tools/harsh-review.sh"
    rm -rf "$fixture"
    [ "$status" -eq 0 ]
    local latest_token ts
    latest_token=$(ls -t "$REVIEW_TOKEN_DIR" | head -1)
    # Accepts both old format (pure epoch) and new format (<cksum>.<epoch>.<pid>)
    if [[ "$latest_token" =~ ^[0-9]+$ ]]; then
        ts="$latest_token"
    else
        ts=$(echo "$latest_token" | awk -F'.' '{print $2}')
    fi
    [[ "$ts" =~ ^[0-9]+$ ]]
}

@test "expired token is rejected by pre-commit token check logic" {
    # Simulate the pre-commit token check: an expired token must not match
    local old_ts=$(($(date +%s) - 600))
    local repo_root
    repo_root=$(cd "$TOOLS_DIR/.." && pwd -P 2>/dev/null || cd "$TOOLS_DIR/.." && pwd)
    echo "$repo_root" > "$REVIEW_TOKEN_DIR/$old_ts"

    # Replicate the pre-commit check logic inline
    local NOW TTL FOUND_VALID
    NOW=$(date +%s)
    TTL=300
    FOUND_VALID=false
    for tf in "$REVIEW_TOKEN_DIR"/*; do
        [[ -f "$tf" ]] || continue
        local ts age
        ts=$(basename "$tf")
        [[ "$ts" =~ ^[0-9]+$ ]] || continue
        age=$((NOW - ts))
        if [[ $age -le $TTL ]]; then
            tr=$(cat "$tf" 2>/dev/null || true)
            [[ "$tr" == "$repo_root" ]] && FOUND_VALID=true && break
        fi
    done
    [ "$FOUND_VALID" = "false" ]
}

@test "wrong-repo token is rejected by pre-commit token check logic" {
    local ts NOW TTL FOUND_VALID
    ts=$(date +%s)
    NOW=$ts
    TTL=300
    echo "/some/other/repo" > "$REVIEW_TOKEN_DIR/$ts"
    local repo_root
    repo_root=$(cd "$TOOLS_DIR/.." && pwd -P 2>/dev/null || cd "$TOOLS_DIR/.." && pwd)

    FOUND_VALID=false
    for tf in "$REVIEW_TOKEN_DIR"/*; do
        [[ -f "$tf" ]] || continue
        local fts age
        fts=$(basename "$tf")
        [[ "$fts" =~ ^[0-9]+$ ]] || continue
        age=$((NOW - fts))
        if [[ $age -le $TTL ]]; then
            tr=$(cat "$tf" 2>/dev/null || true)
            [[ "$tr" == "$repo_root" ]] && FOUND_VALID=true && break
        fi
    done
    [ "$FOUND_VALID" = "false" ]
}

@test "commit-gate.sh exits nonzero when EXTRA_TEST fails" {
    # Create a temp repo with a failing EXTRA_TEST gate
    # Use 'false' (not 'exit 1') so the eval path doesn't terminate the shell
    local tmp_repo
    tmp_repo=$(mktemp -d)
    git -C "$tmp_repo" init -q
    mkdir -p "$tmp_repo/tools" "$tmp_repo/tests"
    cp "$TOOLS_DIR/commit-gate.sh" "$tmp_repo/tools/"
    cp "$TOOLS_DIR/harsh-review.sh" "$tmp_repo/tools/"
    printf 'EXTRA_TEST=false\nSKIP_DEFAULT_TESTS=true\n' > "$tmp_repo/.agent-gates"
    run bash "$tmp_repo/tools/commit-gate.sh"
    rm -rf "$tmp_repo"
    [ "$status" -ne 0 ]
}

@test "no review token written when commit-gate.sh fails" {
    # When an earlier gate fails, harsh-review.sh is skipped entirely
    # so no new token should be written.
    local tmp_repo before_count after_count
    tmp_repo=$(mktemp -d)
    git -C "$tmp_repo" init -q
    mkdir -p "$tmp_repo/tools" "$tmp_repo/tests"
    cp "$TOOLS_DIR/commit-gate.sh" "$tmp_repo/tools/"
    # Use a stub harsh-review.sh that writes a token + exits 0, to confirm
    # it is never called when earlier gates have already failed.
    printf '#!/usr/bin/env bash\necho "%s" > "%s/%s.%s.%s"\nexit 0\n' \
        "$tmp_repo" "$REVIEW_TOKEN_DIR" "9999999999" "$(date +%s)" "$$" \
        > "$tmp_repo/tools/harsh-review.sh"
    chmod +x "$tmp_repo/tools/harsh-review.sh"
    printf 'EXTRA_TEST=false\nSKIP_DEFAULT_TESTS=true\n' > "$tmp_repo/.agent-gates"
    before_count=$(ls -1 "$REVIEW_TOKEN_DIR" 2>/dev/null | wc -l | xargs)
    run bash "$tmp_repo/tools/commit-gate.sh"
    after_count=$(ls -1 "$REVIEW_TOKEN_DIR" 2>/dev/null | wc -l | xargs)
    rm -rf "$tmp_repo"
    # Gate failed AND harsh-review was skipped — no new token should appear
    [ "$after_count" -le "$before_count" ]
}

@test "expired new-format token is rejected by pre-commit token check logic" {
    # Test new <cksum>.<epoch>.<pid> filename format with expired epoch
    local old_ts=$(($(date +%s) - 600))
    local repo_root
    repo_root=$(cd "$TOOLS_DIR/.." && pwd -P 2>/dev/null || cd "$TOOLS_DIR/.." && pwd)
    local cksum_val pid_val
    cksum_val=$(printf '%s' "$repo_root" | cksum | awk '{print $1}')
    pid_val=99999
    echo "$repo_root" > "$REVIEW_TOKEN_DIR/${cksum_val}.${old_ts}.${pid_val}"

    local NOW TTL FOUND_VALID
    NOW=$(date +%s)
    TTL=300
    FOUND_VALID=false
    for tf in "$REVIEW_TOKEN_DIR"/*; do
        [[ -f "$tf" ]] || continue
        local b ts age
        b=$(basename "$tf")
        if [[ "$b" =~ ^[0-9]+$ ]]; then ts="$b"; else ts=$(echo "$b" | awk -F'.' '{print $2}'); fi
        [[ "$ts" =~ ^[0-9]+$ ]] || continue
        age=$((NOW - ts))
        if [[ $age -le $TTL ]]; then
            tr=$(cat "$tf" 2>/dev/null || true)
            [[ "$tr" == "$repo_root" ]] && FOUND_VALID=true && break
        fi
    done
    [ "$FOUND_VALID" = "false" ]
}

@test "wrong-repo new-format token is rejected by pre-commit token check logic" {
    local ts
    ts=$(date +%s)
    local repo_root
    repo_root=$(cd "$TOOLS_DIR/.." && pwd -P 2>/dev/null || cd "$TOOLS_DIR/.." && pwd)
    local cksum_val
    cksum_val=$(printf '%s' "/some/other/repo" | cksum | awk '{print $1}')
    echo "/some/other/repo" > "$REVIEW_TOKEN_DIR/${cksum_val}.${ts}.99998"

    local NOW TTL FOUND_VALID
    NOW=$ts
    TTL=300
    FOUND_VALID=false
    for tf in "$REVIEW_TOKEN_DIR"/*; do
        [[ -f "$tf" ]] || continue
        local b fts age
        b=$(basename "$tf")
        if [[ "$b" =~ ^[0-9]+$ ]]; then fts="$b"; else fts=$(echo "$b" | awk -F'.' '{print $2}'); fi
        [[ "$fts" =~ ^[0-9]+$ ]] || continue
        age=$((NOW - fts))
        if [[ $age -le $TTL ]]; then
            tr=$(cat "$tf" 2>/dev/null || true)
            [[ "$tr" == "$repo_root" ]] && FOUND_VALID=true && break
        fi
    done
    [ "$FOUND_VALID" = "false" ]
}

@test "commit-gate.sh exits nonzero when harsh-review writes no token" {
    # Verify that a stub harsh-review.sh that exits 0 but writes no token
    # causes commit-gate.sh to report failure (stale-proof gate).
    local tmp_repo
    tmp_repo=$(mktemp -d)
    git -C "$tmp_repo" init -q
    mkdir -p "$tmp_repo/tools" "$tmp_repo/tests"
    cp "$TOOLS_DIR/commit-gate.sh" "$tmp_repo/tools/"
    # Stub harsh-review.sh: exits 0 but writes no token
    printf '#!/usr/bin/env bash\nexit 0\n' > "$tmp_repo/tools/harsh-review.sh"
    chmod +x "$tmp_repo/tools/harsh-review.sh"
    printf 'SKIP_DEFAULT_TESTS=true\n' > "$tmp_repo/.agent-gates"
    run bash "$tmp_repo/tools/commit-gate.sh"
    rm -rf "$tmp_repo"
    [ "$status" -ne 0 ]
}

@test "commit-gate.sh runs without error" {
    local fixture
    fixture=$(_create_fixture_repo)
    run bash "$fixture/tools/commit-gate.sh"
    rm -rf "$fixture"
    [ "$status" -eq 0 ]
}

@test "commit-gate.sh creates a token" {
    local fixture
    fixture=$(_create_fixture_repo)
    bash "$fixture/tools/commit-gate.sh"
    rm -rf "$fixture"
    local token_count
    token_count=$(ls -1 "$REVIEW_TOKEN_DIR" 2>/dev/null | wc -l | xargs)
    [ "$token_count" -ge 1 ]
}

@test "loose-ends.sh check exits 0 and prints clean message when no loose-end items exist" {
    local fixture
    fixture=$(_create_fixture_repo)
    # Stub todo-crud.sh to return a valid TODO with no #loose-end items
    cat > "$fixture/tools/todo-crud.sh" << 'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == "cat" ]]; then
    printf '# ACTIVE TASKS\n\n- [ ] [20260101-01] A normal task\n\n# HISTORY\n\n# DEFERRED\n'
    exit 0
fi
exit 0
EOF
    chmod +x "$fixture/tools/todo-crud.sh"
    run bash "$fixture/tools/loose-ends.sh" check
    rm -rf "$fixture"
    [ "$status" -eq 0 ]
    [[ "$output" == *"No open #loose-end items"* ]]
}

@test "harsh-review.sh fails when extensionless hook script has a bash syntax error" {
    local fixture
    fixture=$(_create_fixture_repo)
    # Inject a syntax error into tools/pre-commit (extensionless, bash shebang)
    printf '#!/usr/bin/env bash\nif then fi\n' > "$fixture/tools/pre-commit"
    run bash "$fixture/tools/harsh-review.sh"
    rm -rf "$fixture"
    [ "$status" -ne 0 ]
}

@test "harsh-review.sh --changed-only fails when extensionless hook script has a bash syntax error" {
    # Regression: changed-only mode uses git diff paths (tools/pre-push) without
    # the leading ./ that find produces; the pattern must match both forms.
    local fixture remote_dir
    remote_dir=$(mktemp -d)
    fixture=$(_create_fixture_repo)
    # Stand up a bare remote so we can set origin/dev
    git -C "$remote_dir" init --bare -q
    git -C "$fixture" remote add origin "$remote_dir"
    git -C "$fixture" push -q origin HEAD:dev
    # Inject a syntax error into an extensionless hook and commit it
    printf '#!/usr/bin/env bash\nif then fi\n' > "$fixture/tools/pre-push"
    git -C "$fixture" add tools/pre-push
    git -C "$fixture" commit -q -m "break pre-push"
    run bash "$fixture/tools/harsh-review.sh" --changed-only
    rm -rf "$fixture" "$remote_dir"
    [ "$status" -ne 0 ]
}

@test "loose-ends.sh check exits nonzero when todo-crud.sh cat fails" {
    local fixture
    fixture=$(_create_fixture_repo)
    # Stub todo-crud.sh to exit nonzero on cat (simulates missing TODO file)
    cat > "$fixture/tools/todo-crud.sh" << 'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == "cat" ]]; then
    echo "ERROR: TODO file not found" >&2
    exit 1
fi
exit 0
EOF
    chmod +x "$fixture/tools/todo-crud.sh"
    run bash "$fixture/tools/loose-ends.sh" check
    rm -rf "$fixture"
    [ "$status" -ne 0 ]
}


@test "pre-commit blocks staged broken extensionless hook even with valid token and sentinel" {
    local fixture
    fixture=$(_create_fixture_repo)
    # Pre-seed a valid review token for this fixture repo
    local repo_root cksum_val ts token_file
    repo_root=$(cd "$fixture" && pwd -P)
    cksum_val=$(printf '%s' "$repo_root" | cksum | awk '{print $1}')
    ts=$(date +%s)
    token_file="$REVIEW_TOKEN_DIR/${cksum_val}.${ts}.$$"
    echo "$repo_root" > "$token_file"
    # Pre-seed a valid sentinel
    local head_sha
    head_sha=$(git -C "$fixture" rev-parse HEAD)
    echo "v1|${head_sha}|PASS|$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$fixture/.code-review-cleared"
    # Stage a broken extensionless bash hook
    printf '#!/usr/bin/env bash\nif then fi\n' > "$fixture/tools/pre-push"
    git -C "$fixture" add tools/pre-push
    # Run pre-commit from within the fixture so git rev-parse --show-toplevel
    # resolves to the fixture repo, not the test runner's repo.
    run bash -c "cd '$fixture' && bash tools/pre-commit"
    rm -rf "$fixture"
    [ "$status" -ne 0 ]
}

@test "pre-commit blocks commit when loose-ends audit backend fails" {
    local fixture
    fixture=$(_create_fixture_repo)
    # Pre-seed valid token and sentinel so all other gates pass
    local repo_root cksum_val ts token_file
    repo_root=$(cd "$fixture" && pwd -P)
    cksum_val=$(printf '%s' "$repo_root" | cksum | awk '{print $1}')
    ts=$(date +%s)
    token_file="$REVIEW_TOKEN_DIR/${cksum_val}.${ts}.$$"
    echo "$repo_root" > "$token_file"
    local head_sha
    head_sha=$(git -C "$fixture" rev-parse HEAD)
    echo "v1|${head_sha}|PASS|$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$fixture/.code-review-cleared"
    # Stub todo-crud.sh to fail on cat
    cat > "$fixture/tools/todo-crud.sh" << 'EOF'
#!/usr/bin/env bash
[[ "${1:-}" == "cat" ]] && { echo "ERROR: backend unavailable" >&2; exit 1; }
exit 0
EOF
    chmod +x "$fixture/tools/todo-crud.sh"
    # Enable loose-ends gate and stage a harmless change
    printf 'REQUIRE_LOOSE_ENDS_CLEAN=true\n' > "$fixture/.agent-gates"
    printf '# comment\n' >> "$fixture/README.md"
    git -C "$fixture" add README.md .agent-gates
    # Run pre-commit from within the fixture so git rev-parse --show-toplevel
    # resolves to the fixture repo, not the test runner's repo.
    run bash -c "cd '$fixture' && bash tools/pre-commit"
    rm -rf "$fixture"
    [ "$status" -ne 0 ]
}

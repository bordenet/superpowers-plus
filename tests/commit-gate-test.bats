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

# Create a minimal fixture with NO initial commit (true first-commit / no-HEAD scenario).
# Use for tests that verify behavior when HEAD does not exist yet.
_create_empty_repo() {
    local repo_dir
    repo_dir=$(mktemp -d)
    git -C "$repo_dir" init -q
    git -C "$repo_dir" config user.email "test@test.com"
    git -C "$repo_dir" config user.name "Test"
    printf '# README\n' > "$repo_dir/README.md"
    printf '# AGENTS\n' > "$repo_dir/AGENTS.md"
    printf '# CLAUDE\n' > "$repo_dir/CLAUDE.md"
    printf 'root = true\n' > "$repo_dir/.editorconfig"
    mkdir -p "$repo_dir/docs"
    printf '# Contributing\n' > "$repo_dir/docs/CONTRIBUTING.md"
    printf '# Architecture\n' > "$repo_dir/docs/ARCHITECTURE.md"
    cp -R "$REAL_REPO_ROOT/tools" "$repo_dir/tools"
    mkdir -p "$repo_dir/skills"
    # Stage required files but do NOT commit — HEAD does not exist
    git -C "$repo_dir" add -A
    printf '%s' "$repo_dir"
}

# Seed a valid review token for a fixture repo into $REVIEW_TOKEN_DIR.
# Uses cksum + pwd -P matching the hook's token-lookup logic.
_seed_token() {
    local fixture="$1"
    local repo_root cksum_val ts
    repo_root=$(cd "$fixture" && pwd -P)
    cksum_val=$(printf '%s' "$repo_root" | cksum | awk '{print $1}')
    ts=$(date +%s)
    echo "$repo_root" > "$REVIEW_TOKEN_DIR/${cksum_val}.${ts}.$$"
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

@test "harsh-review.sh --changed-only fails when extensionless hook uses #!/bin/bash shebang" {
    local fixture remote_dir
    remote_dir=$(mktemp -d)
    fixture=$(_create_fixture_repo)
    git -C "$remote_dir" init --bare -q
    git -C "$fixture" remote add origin "$remote_dir"
    git -C "$fixture" push -q origin HEAD:dev
    # Use #!/bin/bash (forbidden shebang) on an extensionless hook
    printf '#!/bin/bash\necho hello\n' > "$fixture/tools/pre-push"
    git -C "$fixture" add tools/pre-push
    git -C "$fixture" commit -q -m "bad shebang in pre-push"
    run bash "$fixture/tools/harsh-review.sh" --changed-only
    rm -rf "$fixture" "$remote_dir"
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


@test "pre-commit reads .agent-gates from HEAD when it is staged (cannot self-disable)" {
    # Critical regression: staging .agent-gates with SKIP_REVIEW_TOKEN=true should NOT
    # disable the token gate because the hook reads from HEAD, not the staged version.
    local fixture
    fixture=$(_create_fixture_repo)
    # Pre-seed a valid sentinel so Gate 0 passes
    local head_sha
    head_sha=$(git -C "$fixture" rev-parse HEAD)
    echo "v1|${head_sha}|PASS|$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$fixture/.code-review-cleared"
    # Stage .agent-gates disabling the token gate (no token seeded — gate should still fire)
    echo "SKIP_REVIEW_TOKEN=true" > "$fixture/.agent-gates"
    printf '# code change\n' >> "$fixture/README.md"
    git -C "$fixture" add .agent-gates README.md
    # Run pre-commit from within the fixture
    run bash -c "cd '$fixture' && bash tools/pre-commit"
    rm -rf "$fixture"
    # Hook must block — the staged .agent-gates self-disable must NOT be honoured
    [ "$status" -ne 0 ]
}

@test "pre-commit honors SKIP_REVIEW_TOKEN=true from committed HEAD when .agent-gates is restaged" {
    # Causal proof: HEAD .agent-gates with SKIP_REVIEW_TOKEN=true IS applied when
    # .agent-gates is itself staged (process substitution keeps parser in parent shell).
    # Without a token seeded, hook must PASS because SKIP_REVIEW_TOKEN is honoured from HEAD.
    local fixture
    fixture=$(_create_fixture_repo)
    # Step 1: commit .agent-gates with SKIP_REVIEW_TOKEN=true into HEAD
    echo "SKIP_REVIEW_TOKEN=true" > "$fixture/.agent-gates"
    git -C "$fixture" add .agent-gates
    git -C "$fixture" commit -q -m "enable SKIP_REVIEW_TOKEN"
    # Step 2: update sentinel to point to the new HEAD
    local head_sha
    head_sha=$(git -C "$fixture" rev-parse HEAD)
    echo "v1|${head_sha}|PASS|$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$fixture/.code-review-cleared"
    # Step 3: stage .agent-gates again (different content) + code change — no token seeded
    echo "SKIP_REVIEW_TOKEN=true" > "$fixture/.agent-gates"
    printf 'change\n' >> "$fixture/README.md"
    git -C "$fixture" add .agent-gates README.md
    run bash -c "cd '$fixture' && bash tools/pre-commit"
    rm -rf "$fixture"
    # Must pass: HEAD config SKIP_REVIEW_TOKEN=true was honoured — no token required
    [ "$status" -eq 0 ]
}

@test "pre-commit propagates parse error from committed HEAD .agent-gates when it is restaged" {
    # Causal proof: parse errors from HEAD .agent-gates propagate to the parent shell
    # (process substitution, not pipeline subshell). Hook must fail with 'invalid value'.
    local fixture
    fixture=$(_create_fixture_repo)
    # Step 1: commit .agent-gates with an invalid boolean into HEAD
    echo "REQUIRE_CODE_REVIEW_SENTINEL=yes" > "$fixture/.agent-gates"
    git -C "$fixture" add .agent-gates
    git -C "$fixture" commit -q -m "invalid agent-gates"
    # Step 2: provide valid sentinel and seed a token so other gates don't interfere
    local head_sha
    head_sha=$(git -C "$fixture" rev-parse HEAD)
    echo "v1|${head_sha}|PASS|$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$fixture/.code-review-cleared"
    _seed_token "$fixture"
    # Step 3: re-stage .agent-gates (same invalid content) + code change
    echo "REQUIRE_CODE_REVIEW_SENTINEL=yes" > "$fixture/.agent-gates"
    printf 'change\n' >> "$fixture/README.md"
    git -C "$fixture" add .agent-gates README.md
    run bash -c "cd '$fixture' && bash tools/pre-commit"
    rm -rf "$fixture"
    # Must fail with a targeted parse-error message
    [ "$status" -ne 0 ]
    [[ "$output" == *"invalid value"* ]]
}

@test "pre-commit blocks staged .agent-gates with invalid boolean even when HEAD config is valid" {
    # When HEAD .agent-gates is valid but staged version has invalid value,
    # pre-commit must block the commit (validation-only pass on staged index blob).
    local fixture
    fixture=$(_create_fixture_repo)
    # Step 1: commit a valid .agent-gates into HEAD
    echo "REQUIRE_CODE_REVIEW_SENTINEL=false" > "$fixture/.agent-gates"
    git -C "$fixture" add .agent-gates
    git -C "$fixture" commit -q -m "valid agent-gates"
    # Step 2: provide valid sentinel and seed a token so other gates pass
    local head_sha
    head_sha=$(git -C "$fixture" rev-parse HEAD)
    echo "v1|${head_sha}|PASS|$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$fixture/.code-review-cleared"
    _seed_token "$fixture"
    # Step 3: stage an invalid replacement .agent-gates + code change
    echo "REQUIRE_CODE_REVIEW_SENTINEL=yes" > "$fixture/.agent-gates"
    printf 'change\n' >> "$fixture/README.md"
    git -C "$fixture" add .agent-gates README.md
    run bash -c "cd '$fixture' && bash tools/pre-commit"
    rm -rf "$fixture"
    # Must fail: staged version has invalid boolean; commit must be blocked
    [ "$status" -ne 0 ]
    [[ "$output" == *"invalid value"* ]]
}

@test "commit-gate.sh catches staged broken extensionless hook even with valid upstream base" {
    # commit-gate.sh --changed-only must also scan staged (index) files, not just
    # committed diff. A broken hook staged but not yet committed must block gate.
    local fixture
    fixture=$(_create_fixture_repo)
    # Add a fake remote so resolve_diff_base finds a valid base and uses --changed-only
    git -C "$fixture" remote add origin "file:///tmp/nonexistent-remote-$$" 2>/dev/null || true
    git -C "$fixture" update-ref refs/remotes/origin/main "$(git -C "$fixture" rev-parse HEAD)" 2>/dev/null || true
    # Stage a syntax-broken hook (not yet committed — should still be caught)
    printf '#!/usr/bin/env bash\nif then fi\n' > "$fixture/tools/pre-push"
    git -C "$fixture" add tools/pre-push
    run bash "$fixture/tools/commit-gate.sh"
    rm -rf "$fixture"
    [ "$status" -ne 0 ]
}

@test "pre-commit blocks staged .agent-gates with invalid boolean on first commit (no HEAD)" {
    # True no-HEAD scenario: repo has never been committed; HEAD does not exist.
    # Staged validation must still fire on the index blob and block invalid values.
    local fixture
    fixture=$(_create_empty_repo)
    # Seed a valid review token into REVIEW_TOKEN_DIR so the token gate passes
    _seed_token "$fixture"
    # Stage .agent-gates with invalid boolean (no HEAD exists — pure first-commit path)
    echo "REQUIRE_CODE_REVIEW_SENTINEL=yes" > "$fixture/.agent-gates"
    git -C "$fixture" add .agent-gates
    run bash -c "cd '$fixture' && bash tools/pre-commit"
    rm -rf "$fixture"
    [ "$status" -ne 0 ]
    [[ "$output" == *"invalid value"* ]]
}

@test "pre-commit blocks staged .agent-gates with invalid SKIP_DEFAULT_TESTS value" {
    # SKIP_DEFAULT_TESTS must be validated in pre-commit to match commit-gate.sh parity.
    local fixture
    fixture=$(_create_fixture_repo)
    # Commit a valid .agent-gates into HEAD
    echo "SKIP_DEFAULT_TESTS=false" > "$fixture/.agent-gates"
    git -C "$fixture" add .agent-gates
    git -C "$fixture" commit -q -m "valid agent-gates"
    # Seed sentinel and token
    local head_sha
    head_sha=$(git -C "$fixture" rev-parse HEAD)
    echo "v1|${head_sha}|PASS|$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$fixture/.code-review-cleared"
    _seed_token "$fixture"
    # Stage an invalid replacement
    echo "SKIP_DEFAULT_TESTS=yes" > "$fixture/.agent-gates"
    git -C "$fixture" add .agent-gates
    run bash -c "cd '$fixture' && bash tools/pre-commit"
    rm -rf "$fixture"
    [ "$status" -ne 0 ]
    [[ "$output" == *"invalid value"* ]]
}

@test "commit-gate.sh rejects REVIEW_TOKEN_TTL=0 at parse time" {
    # TTL=0 causes instant expiry — must be rejected as invalid, not applied.
    local fixture
    fixture=$(_create_fixture_repo)
    echo "REVIEW_TOKEN_TTL=0" > "$fixture/.agent-gates"
    run bash "$fixture/tools/commit-gate.sh"
    rm -rf "$fixture"
    [ "$status" -ne 0 ]
    [[ "$output" == *"invalid value"* ]]
}

@test "loose-ends.sh add exits with error when --desc value is missing" {
    local fixture
    fixture=$(_create_fixture_repo)
    run bash "$fixture/tools/loose-ends.sh" add --desc
    rm -rf "$fixture"
    [ "$status" -ne 0 ]
    [[ "$output" == *"requires a value"* ]]
}

@test "loose-ends.sh add exits with error when next token after --desc is another flag" {
    local fixture
    fixture=$(_create_fixture_repo)
    run bash "$fixture/tools/loose-ends.sh" add --desc --note foo
    rm -rf "$fixture"
    [ "$status" -ne 0 ]
    [[ "$output" == *"requires a value"* ]]
}

@test "pre-commit gate-0 blocks when .agent-gates has inline comment on boolean key" {
    # Isolates Gate 0 (sentinel) specifically — not the token gate.
    # Inline comment (true # comment) must be stripped before validation so
    # REQUIRE_CODE_REVIEW_SENTINEL=true is parsed correctly. The key correctness
    # requirement: trailing comment text must not corrupt the boolean.
    #
    # Setup: .agent-gates is COMMITTED to HEAD (not staged) with the inline-comment
    # value. Pre-commit reads it from the working tree. A valid review token is
    # seeded so the token gate PASSES. The only remaining gate that can block is
    # Gate 0 — which fires because no .code-review-cleared exists.
    local fixture
    fixture=$(_create_fixture_repo)
    # Commit .agent-gates with inline comment into HEAD so pre-commit reads it
    echo "REQUIRE_CODE_REVIEW_SENTINEL=true # enable sentinel" > "$fixture/.agent-gates"
    git -C "$fixture" add .agent-gates
    git -C "$fixture" commit -q -m "add .agent-gates with inline comment"
    # Seed a valid token so the token gate PASSES
    _seed_token "$fixture"
    # Stage a shell script (non-doc file) so staged_has_code() returns true and
    # Gate 0 actually fires. README.md is docs-only and would skip Gate 0.
    printf '#!/usr/bin/env bash\necho hello\n' > "$fixture/tools/my-check.sh"
    git -C "$fixture" add tools/my-check.sh
    # No .code-review-cleared present — Gate 0 must block
    run bash -c "cd '$fixture' && bash tools/pre-commit"
    rm -rf "$fixture"
    [ "$status" -ne 0 ]
    # Assert Gate 0 message — confirms it was the sentinel gate, not token gate
    [[ "$output" == *"COMMIT BLOCKED: No code review clearance"* ]]
}

@test "pre-commit blocks and emits error when committed .agent-gates has invalid boolean value" {
    # Validation fires when the committed (HEAD) .agent-gates has a bad value.
    # In first-commit scenarios (no HEAD .agent-gates), the parser skips the staged
    # version by design (fail-safe default) — this test covers the HEAD-present path.
    local fixture
    fixture=$(_create_fixture_repo)
    # Commit a .agent-gates with an invalid boolean value into HEAD
    echo "REQUIRE_CODE_REVIEW_SENTINEL=yes" > "$fixture/.agent-gates"
    git -C "$fixture" add .agent-gates
    git -C "$fixture" commit -q -m "add invalid agent-gates"
    # Now stage a code change — parser will read .agent-gates from the new HEAD
    printf '# code change\n' >> "$fixture/README.md"
    git -C "$fixture" add README.md
    run bash -c "cd '$fixture' && bash tools/pre-commit"
    rm -rf "$fixture"
    [ "$status" -ne 0 ]
    [[ "$output" == *"invalid value"* ]]
}

@test "commit-gate.sh exits nonzero when .agent-gates has invalid REVIEW_TOKEN_TTL" {
    local fixture
    fixture=$(_create_fixture_repo)
    echo "REVIEW_TOKEN_TTL=yes" > "$fixture/.agent-gates"
    run bash "$fixture/tools/commit-gate.sh"
    rm -rf "$fixture"
    [ "$status" -ne 0 ]
    [[ "$output" == *"invalid value"* ]]
}

@test "commit-gate.sh skips default tests when SKIP_DEFAULT_TESTS has inline comment" {
    local fixture
    fixture=$(_create_fixture_repo)
    # If inline-comment stripping is correct, 'true # skip' parses as 'true'
    echo "SKIP_DEFAULT_TESTS=true # skip bats for this repo" > "$fixture/.agent-gates"
    # Remove bats tests so default test step would fail if it ran
    rm -rf "$fixture/tests"
    run bash "$fixture/tools/commit-gate.sh"
    rm -rf "$fixture"
    [ "$status" -eq 0 ]
}

@test "commit-gate.sh EXTRA_TEST command containing a hash character is not truncated" {
    # If '#' were stripped from EXTRA_TEST, 'printf' would lose its args and the
    # gate would produce unexpected output or exit nonzero. Verify it exits 0 cleanly.
    local fixture
    fixture=$(_create_fixture_repo)
    # Use SKIP_DEFAULT_TESTS so bats is not required; EXTRA_TEST with '#' replaces it
    printf 'SKIP_DEFAULT_TESTS=true\nEXTRA_TEST=printf '"'"'# ok\\n'"'"'\n' > "$fixture/.agent-gates"
    run bash "$fixture/tools/commit-gate.sh"
    rm -rf "$fixture"
    [ "$status" -eq 0 ]
}

@test "commit-gate.sh fails on broken extensionless hook when repo has no upstream (fail-closed)" {
    # Regression: with no remote/upstream, resolve_diff_base() previously returned
    # "origin/main" which didn't exist, so git diff returned nothing and the gate
    # silently passed a broken hook. Fix: fall back to full-repo scan.
    local fixture
    fixture=$(_create_fixture_repo)
    # No remote added — no upstream, no origin/dev, no origin/main
    printf '#!/usr/bin/env bash\nif then fi\n' > "$fixture/tools/pre-push"
    git -C "$fixture" add tools/pre-push
    git -C "$fixture" commit -q -m "stage broken hook"
    run bash "$fixture/tools/commit-gate.sh"
    rm -rf "$fixture"
    [ "$status" -ne 0 ]
}

@test "pre-push blocks when no .code-review-cleared sentinel exists" {
    # Gate 1 of pre-push: missing sentinel must block all code pushes.
    local fixture push_input
    fixture=$(_create_fixture_repo)
    local local_sha
    local_sha=$(git -C "$fixture" rev-parse HEAD)
    # Write push-hook stdin to a temp file to avoid pipe+cd ordering issues
    push_input=$(mktemp)
    printf 'refs/heads/main %s refs/heads/main 0000000000000000000000000000000000000000\n' \
        "$local_sha" > "$push_input"
    run bash -c "cd '$fixture' && bash tools/pre-push < '$push_input'"
    rm -f "$push_input"
    rm -rf "$fixture"
    [ "$status" -ne 0 ]
    [[ "$output" == *"PUSH BLOCKED"* ]]
}

@test "pre-push blocks when sentinel SHA does not match pushed SHA" {
    # Gate 1 of pre-push: stale sentinel (wrong SHA) must block the push.
    local fixture push_input
    fixture=$(_create_fixture_repo)
    local local_sha
    local_sha=$(git -C "$fixture" rev-parse HEAD)
    # Write sentinel with a deliberately wrong SHA
    echo "v1|aabbccdd1122334455667788aabbccdd11223344|PASS|$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        > "$fixture/.code-review-cleared"
    push_input=$(mktemp)
    printf 'refs/heads/main %s refs/heads/main 0000000000000000000000000000000000000000\n' \
        "$local_sha" > "$push_input"
    run bash -c "cd '$fixture' && bash tools/pre-push < '$push_input'"
    rm -f "$push_input"
    rm -rf "$fixture"
    [ "$status" -ne 0 ]
    [[ "$output" == *"PUSH BLOCKED"* ]]
}

@test "pre-push allows new branch with no common ancestor when all commits are docs-only" {
    # Regression guard for the orphan/no-base docs-only exemption.
    # When NEW_BRANCH_NO_BASE=true (no shared ancestor with any known base),
    # the hook enumerates all files in the branch's history. If all are docs/metadata
    # the push must be allowed even with no .code-review-cleared present.
    local fixture push_input
    fixture=$(_create_fixture_repo)
    # Create an orphan branch (no parent commits — completely unrelated history).
    # Use --cached so git rm does NOT delete working-tree files (tools/ must
    # survive so bash tools/pre-push can be invoked from the fixture root).
    git -C "$fixture" checkout --orphan docs-orphan -q
    git -C "$fixture" rm -r --cached . -q
    printf '# Docs only\n' > "$fixture/DOCS.md"
    git -C "$fixture" add DOCS.md
    git -C "$fixture" commit -q -m "docs: orphan branch with docs only"
    local local_sha zero_sha
    local_sha=$(git -C "$fixture" rev-parse HEAD)
    zero_sha="0000000000000000000000000000000000000000"
    push_input=$(mktemp)
    printf 'refs/heads/docs-orphan %s refs/heads/docs-orphan %s\n' \
        "$local_sha" "$zero_sha" > "$push_input"
    # No .code-review-cleared — docs-only orphan branch must NOT be blocked
    run bash -c "cd '$fixture' && bash tools/pre-push < '$push_input'"
    rm -f "$push_input"
    rm -rf "$fixture"
    [ "$status" -eq 0 ]
    [[ "$output" == *"docs-only"* ]]
}

@test "pre-push blocks new branch with no common ancestor when history contains code files" {
    # Negative-path complement to test 38. When the orphan branch history contains
    # a code file, the hook must fail closed and require the sentinel even though
    # there is no common ancestor with any known base branch.
    #
    # This covers the awk classifier in the NEW_BRANCH_NO_BASE block and confirms
    # that git log --name-only -m --format="" correctly surfaces code files.
    # The -m flag specifically matters for merge commits where files introduced
    # only during conflict resolution could be missed without it; the negative
    # path here proves that any code file in the reachable history causes a block.
    local fixture push_input
    fixture=$(_create_fixture_repo)
    git -C "$fixture" checkout --orphan code-orphan -q
    git -C "$fixture" rm -r --cached . -q
    # Add both a doc file and a shell script — hook must detect the shell script
    printf '# Docs\n' > "$fixture/DOCS.md"
    printf '#!/usr/bin/env bash\necho hello\n' > "$fixture/helper.sh"
    git -C "$fixture" add DOCS.md helper.sh
    git -C "$fixture" commit -q -m "add: docs + helper script"
    local local_sha zero_sha
    local_sha=$(git -C "$fixture" rev-parse HEAD)
    zero_sha="0000000000000000000000000000000000000000"
    push_input=$(mktemp)
    printf 'refs/heads/code-orphan %s refs/heads/code-orphan %s\n' \
        "$local_sha" "$zero_sha" > "$push_input"
    # No sentinel — must be blocked because helper.sh is code
    run bash -c "cd '$fixture' && bash tools/pre-push < '$push_input'"
    rm -f "$push_input"
    rm -rf "$fixture"
    [ "$status" -ne 0 ]
    # Assert the specific no-base fail-closed message (not a generic PUSH BLOCKED from another gate)
    [[ "$output" == *"failing closed (require sentinel)"* ]]
    # Confirm the docs-only exemption was NOT granted
    [[ "$output" != *"docs-only, sentinel not required"* ]]
}

@test "pre-push blocks orphan branch when code file appears only in merge commit resolution" {
    # Regression test for the -m flag in git log --name-only -m.
    # Without -m, git log --name-only on a merge commit may omit files that were
    # introduced only during conflict resolution (not present in either parent).
    # With -m, per-parent diffs are shown so such files are caught.
    #
    # Fixture: orphan branch A has guide.md only (docs). We merge unrelated orphan
    # branch B (also has guide.md with different content — causing conflict) with
    # --no-commit, then add extra.sh as if resolving the conflict by adding code.
    # The merge commit has extra.sh as a resolution artifact not in either parent.
    # Without -m, git log might only report guide.md; with -m, extra.sh surfaces.
    local fixture push_input
    fixture=$(_create_fixture_repo)

    # Create orphan A with guide.md (docs-only history)
    git -C "$fixture" checkout --orphan orphan-a -q
    git -C "$fixture" rm -r --cached . -q
    printf '# Guide\nVersion A content\n' > "$fixture/guide.md"
    git -C "$fixture" add guide.md
    git -C "$fixture" commit -q -m "docs: add guide"

    # Create unrelated orphan B with conflicting guide.md
    git -C "$fixture" checkout --orphan orphan-b -q
    git -C "$fixture" rm -r --cached . -q
    printf '# Guide\nVersion B content\n' > "$fixture/guide.md"
    git -C "$fixture" add guide.md
    git -C "$fixture" commit -q -m "docs: add guide version B"

    # Switch back to orphan-a and merge B (conflict on guide.md) without committing
    git -C "$fixture" checkout orphan-a -q
    git -C "$fixture" merge --allow-unrelated-histories --no-commit orphan-b -q 2>/dev/null || true

    # Simulate conflict resolution: accept A's guide.md and ADD a code file
    # extra.sh is NOT in either parent — it's a merge-resolution-only artifact
    git -C "$fixture" checkout HEAD -- guide.md
    printf '#!/usr/bin/env bash\necho resolution\n' > "$fixture/extra.sh"
    git -C "$fixture" add guide.md extra.sh
    git -C "$fixture" commit -q -m "merge: resolve conflict (add extra.sh)"

    local local_sha zero_sha
    local_sha=$(git -C "$fixture" rev-parse HEAD)
    zero_sha="0000000000000000000000000000000000000000"
    push_input=$(mktemp)
    printf 'refs/heads/orphan-a %s refs/heads/orphan-a %s\n' \
        "$local_sha" "$zero_sha" > "$push_input"

    # No sentinel — extra.sh is code so the hook must block even though it's
    # only visible via -m (merge-commit per-parent diff)
    run bash -c "cd '$fixture' && bash tools/pre-push < '$push_input'"
    rm -f "$push_input"
    rm -rf "$fixture"
    [ "$status" -ne 0 ]
    [[ "$output" == *"failing closed (require sentinel)"* ]]
}

@test "pre-push allows orphan branch consisting entirely of --allow-empty commits" {
    # When an orphan branch has only --allow-empty commits, git log --name-only
    # returns no filenames. Previously this fell into the fail-closed path because
    # _no_base_files was empty and the code could not distinguish "empty result"
    # from "enumeration failed". After the exit-code fix, empty result from a
    # successful enumeration is treated as "no files to review → allow".
    local fixture push_input
    fixture=$(_create_fixture_repo)
    git -C "$fixture" checkout --orphan empty-orphan -q
    git -C "$fixture" rm -r --cached . -q
    # Commit with no file changes — git commit --allow-empty
    git -C "$fixture" commit -q --allow-empty -m "chore: empty marker commit"
    local local_sha zero_sha
    local_sha=$(git -C "$fixture" rev-parse HEAD)
    zero_sha="0000000000000000000000000000000000000000"
    push_input=$(mktemp)
    printf 'refs/heads/empty-orphan %s refs/heads/empty-orphan %s\n' \
        "$local_sha" "$zero_sha" > "$push_input"
    # No sentinel — allow-empty-only branch must NOT be blocked
    run bash -c "cd '$fixture' && bash tools/pre-push < '$push_input'"
    rm -f "$push_input"
    rm -rf "$fixture"
    [ "$status" -eq 0 ]
    [[ "$output" == *"allow-empty only"* ]]
}

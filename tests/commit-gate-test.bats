#!/usr/bin/env bats
# Tests for the review token gate system

TOOLS_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../tools" && pwd)"

setup() {
    export TEST_HOME="$(mktemp -d)"
    export HOME="$TEST_HOME"
    export REVIEW_TOKEN_DIR="${HOME}/.codex/review-tokens"
    mkdir -p "$REVIEW_TOKEN_DIR"
}

teardown() {
    rm -rf "$TEST_HOME"
}

# ---------------------------------------------------------------------------
# Helper: replicates pre-commit's token-validation loop so we can unit-test
# the accept/reject logic without invoking the full hook (which requires a
# live git repo with staged files). Must match the loop in tools/pre-commit.
# Returns 0 if a valid token found; 1 otherwise.
# ---------------------------------------------------------------------------
_token_gate_find_valid() {
    local repo_root="$1"
    local review_ttl="${2:-300}"
    local now
    now=$(date +%s)
    for token_file in "$REVIEW_TOKEN_DIR"/*; do
        [[ -f "$token_file" ]] || continue
        local token_ts
        token_ts=$(basename "$token_file")
        [[ "$token_ts" =~ ^[0-9]+$ ]] || continue
        local token_age=$(( now - token_ts ))
        if [[ $token_age -le $review_ttl ]]; then
            local token_repo
            token_repo=$(cat "$token_file" 2>/dev/null || true)
            if [[ "$token_repo" == "$repo_root" ]]; then
                return 0
            fi
        fi
    done
    return 1
}

@test "harsh-review.sh creates a token file on success" {
    run bash "$TOOLS_DIR/harsh-review.sh"
    [ "$status" -eq 0 ]
    local token_count
    token_count=$(ls -1 "$REVIEW_TOKEN_DIR" 2>/dev/null | wc -l | xargs)
    [ "$token_count" -ge 1 ]
}

@test "token file contains repo root path" {
    run bash "$TOOLS_DIR/harsh-review.sh"
    [ "$status" -eq 0 ]
    local latest_token
    latest_token=$(ls -t "$REVIEW_TOKEN_DIR" | head -1)
    local token_content
    token_content=$(cat "$REVIEW_TOKEN_DIR/$latest_token")
    [ -d "$token_content" ]
}

@test "token filename is a unix timestamp" {
    run bash "$TOOLS_DIR/harsh-review.sh"
    [ "$status" -eq 0 ]
    local latest_token
    latest_token=$(ls -t "$REVIEW_TOKEN_DIR" | head -1)
    [[ "$latest_token" =~ ^[0-9]+$ ]]
}

@test "token gate rejects expired token (age > TTL)" {
    # Plant a token that is 600s old — well past the 300s default TTL.
    # The gate must NOT accept it; this tests the age-check branch of the
    # validation loop, not just that 600 > 300 arithmetically.
    local old_ts=$(( $(date +%s) - 600 ))
    local repo_root
    repo_root=$(cd "$TOOLS_DIR/.." && pwd)
    echo "$repo_root" > "$REVIEW_TOKEN_DIR/$old_ts"
    ! _token_gate_find_valid "$repo_root" 300
}

@test "token gate rejects token from wrong repo" {
    # Plant a fresh token whose content is a different repo path.
    # The gate must NOT accept it; this tests the repo-match branch.
    local ts
    ts=$(date +%s)
    echo "/some/other/repo" > "$REVIEW_TOKEN_DIR/$ts"
    local repo_root
    repo_root=$(cd "$TOOLS_DIR/.." && pwd)
    ! _token_gate_find_valid "$repo_root" 300
}

@test "token gate accepts fresh valid token for correct repo" {
    # Plant a fresh token whose content is the current repo root.
    # The gate must find and accept it.
    local ts
    ts=$(date +%s)
    local repo_root
    repo_root=$(cd "$TOOLS_DIR/.." && pwd)
    echo "$repo_root" > "$REVIEW_TOKEN_DIR/$ts"
    _token_gate_find_valid "$repo_root" 300
}

@test "commit-gate.sh runs without error" {
    run bash "$TOOLS_DIR/commit-gate.sh"
    [ "$status" -eq 0 ]
}

@test "commit-gate.sh creates a token" {
    bash "$TOOLS_DIR/commit-gate.sh"
    local token_count
    token_count=$(ls -1 "$REVIEW_TOKEN_DIR" 2>/dev/null | wc -l | xargs)
    [ "$token_count" -ge 1 ]
}

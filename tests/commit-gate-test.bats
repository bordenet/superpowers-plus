#!/usr/bin/env bats
# Tests for the review token gate system

REVIEW_TOKEN_DIR="${HOME}/.codex/review-tokens"
TOOLS_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../tools" && pwd)"

setup() {
    mkdir -p "$REVIEW_TOKEN_DIR"
    rm -f "$REVIEW_TOKEN_DIR"/*
}

teardown() {
    rm -f "$REVIEW_TOKEN_DIR"/*
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

@test "expired token is not accepted (age > 300s)" {
    local old_ts=$(($(date +%s) - 600))
    local repo_root
    repo_root=$(cd "$TOOLS_DIR/.." && pwd)
    echo "$repo_root" > "$REVIEW_TOKEN_DIR/$old_ts"
    local now
    now=$(date +%s)
    local age=$((now - old_ts))
    [ "$age" -gt 300 ]
}

@test "token from wrong repo is not accepted" {
    local ts
    ts=$(date +%s)
    echo "/some/other/repo" > "$REVIEW_TOKEN_DIR/$ts"
    local repo_root
    repo_root=$(cd "$TOOLS_DIR/.." && pwd)
    local token_repo
    token_repo=$(cat "$REVIEW_TOKEN_DIR/$ts")
    [ "$token_repo" != "$repo_root" ]
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

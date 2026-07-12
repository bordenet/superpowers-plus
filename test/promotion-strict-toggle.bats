#!/usr/bin/env bats
# Tests for tools/promotion-strict-toggle.sh
# Exit-code contract: disable/restore: 0=confirmed via read-back, 1=read-back
# mismatch (sentinel not written/not cleared). status: 0=none or fresh, 1=stale.

REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
SCRIPT="$REPO_ROOT/tools/promotion-strict-toggle.sh"

setup() {
    WORK="$(mktemp -d)"
    cd "$WORK"
    git init -q --initial-branch=main
    git config user.email "test@test"
    git config user.name "test"

    FAKE_BIN="$WORK/bin"
    mkdir -p "$FAKE_BIN"
    cat > "$FAKE_BIN/gh" <<'FAKEGH'
#!/usr/bin/env bash
# Fake `gh` for promotion-strict-toggle.sh tests.
# Tracks per-branch "strict" state in $FAKE_GH_STATE_DIR/strict-<branch>.
# Honors FAKE_GH_FORCE_READBACK to simulate a read-back that disagrees with
# the last PATCH (the exact scenario the real script must detect and refuse).
# Honors FAKE_GH_PATCH_EXIT_CODE to simulate the PATCH call itself failing.
set -euo pipefail
STATE_DIR="${FAKE_GH_STATE_DIR:?FAKE_GH_STATE_DIR must be set}"
mkdir -p "$STATE_DIR"

path=""
for a in "$@"; do
  case "$a" in
    repos/*) path="$a" ;;
  esac
done
branch="$(echo "$path" | sed -E 's#.*/branches/([^/]+)/protection.*#\1#')"
state_file="$STATE_DIR/strict-$branch"

is_patch=0
joined=" $* "
[[ "$joined" == *" -X PATCH "* ]] && is_patch=1

if [[ "$is_patch" == "1" ]]; then
  if [[ -n "${FAKE_GH_PATCH_EXIT_CODE:-}" && "${FAKE_GH_PATCH_EXIT_CODE}" != "0" ]]; then
    echo "fake gh: simulated PATCH failure" >&2
    exit "$FAKE_GH_PATCH_EXIT_CODE"
  fi
  for a in "$@"; do
    case "$a" in
      strict=*) echo "${a#strict=}" > "$state_file" ;;
    esac
  done
  echo '{}'
  exit 0
else
  if [[ -n "${FAKE_GH_FORCE_READBACK:-}" ]]; then
    echo "$FAKE_GH_FORCE_READBACK"
  elif [[ -f "$state_file" ]]; then
    cat "$state_file"
  else
    echo "true"
  fi
  exit 0
fi
FAKEGH
    chmod +x "$FAKE_BIN/gh"
    export PATH="$FAKE_BIN:$PATH"

    FAKE_GH_STATE_DIR="$WORK/gh-state"
    mkdir -p "$FAKE_GH_STATE_DIR"
    export FAKE_GH_STATE_DIR
    unset FAKE_GH_FORCE_READBACK FAKE_GH_PATCH_EXIT_CODE || true
}

teardown() {
    rm -rf "$WORK"
}

sentinel_file() { echo "$WORK/.strict-toggle-state"; }

@test "--help exits 0 and documents all three subcommands" {
    run bash "$SCRIPT" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"disable"* ]]
    [[ "$output" == *"restore"* ]]
    [[ "$output" == *"status"* ]]
}

@test "unknown subcommand exits 1" {
    run bash "$SCRIPT" bogus
    [ "$status" -eq 1 ]
    [[ "$output" == *"Unknown subcommand"* ]]
}

@test "disable with no branch arg exits nonzero" {
    run bash "$SCRIPT" disable
    [ "$status" -ne 0 ]
}

@test "disable: happy path writes sentinel and confirms via read-back" {
    run bash "$SCRIPT" disable staging
    [ "$status" -eq 0 ]
    [[ "$output" == *"confirmed on staging"* ]]
    [ -f "$(sentinel_file)" ]
    grep -q "^v1|staging|" "$(sentinel_file)"
}

@test "disable: read-back mismatch aborts WITHOUT writing sentinel" {
    export FAKE_GH_FORCE_READBACK="true"
    run bash "$SCRIPT" disable staging
    [ "$status" -eq 1 ]
    [[ "$output" == *"NOT written"* ]]
    [ ! -f "$(sentinel_file)" ]
}

@test "disable: PATCH itself failing aborts before any sentinel write" {
    export FAKE_GH_PATCH_EXIT_CODE="1"
    run bash "$SCRIPT" disable staging
    [ "$status" -ne 0 ]
    [ ! -f "$(sentinel_file)" ]
}

@test "restore: happy path clears sentinel and confirms via read-back" {
    bash "$SCRIPT" disable staging
    [ -f "$(sentinel_file)" ]
    run bash "$SCRIPT" restore staging
    [ "$status" -eq 0 ]
    [[ "$output" == *"confirmed on staging"* ]]
    [ ! -f "$(sentinel_file)" ]
}

@test "restore: read-back mismatch does NOT clear the sentinel" {
    bash "$SCRIPT" disable staging
    [ -f "$(sentinel_file)" ]
    export FAKE_GH_FORCE_READBACK="false"
    run bash "$SCRIPT" restore staging
    [ "$status" -eq 1 ]
    [[ "$output" == *"NOT cleared"* ]]
    [ -f "$(sentinel_file)" ]
    grep -q "^v1|staging|" "$(sentinel_file)"
}

@test "status: no sentinel file means no active entries, exit 0" {
    run bash "$SCRIPT" status
    [ "$status" -eq 0 ]
    [[ "$output" == *"No active"* ]]
}

@test "status: fresh entry (within TTL) reports active, exit 0" {
    bash "$SCRIPT" disable staging
    run bash "$SCRIPT" status
    [ "$status" -eq 0 ]
    [[ "$output" == *"active: staging"* ]]
}

@test "status: entry older than TTL reports STALE and exits 1" {
    now="$(date -u +%s)"
    old=$(( now - 3600 ))
    echo "v1|staging|bordenet/superpowers-plus|${old}" > "$(sentinel_file)"
    run env PROMOTION_STRICT_TOGGLE_TTL_SECONDS=1800 bash "$SCRIPT" status
    [ "$status" -eq 1 ]
    [[ "$output" == *"STALE: staging"* ]]
    [[ "$output" == *"restore immediately"* ]]
}

@test "status: TTL is configurable via env var" {
    now="$(date -u +%s)"
    old=$(( now - 100 ))
    echo "v1|staging|bordenet/superpowers-plus|${old}" > "$(sentinel_file)"
    run env PROMOTION_STRICT_TOGGLE_TTL_SECONDS=50 bash "$SCRIPT" status
    [ "$status" -eq 1 ]
    [[ "$output" == *"STALE: staging"* ]]
}

@test "two branches are tracked independently: restoring one leaves the other active" {
    bash "$SCRIPT" disable staging
    bash "$SCRIPT" disable dev
    grep -q "^v1|staging|" "$(sentinel_file)"
    grep -q "^v1|dev|" "$(sentinel_file)"

    run bash "$SCRIPT" restore staging
    [ "$status" -eq 0 ]
    ! grep -q "^v1|staging|" "$(sentinel_file)"
    grep -q "^v1|dev|" "$(sentinel_file)"

    run bash "$SCRIPT" status
    [ "$status" -eq 0 ]
    [[ "$output" == *"active: dev"* ]]
    [[ "$output" != *"staging"* ]]
}

@test "disabling the same branch twice replaces the old entry (no duplicate lines)" {
    bash "$SCRIPT" disable staging
    bash "$SCRIPT" disable staging
    count="$(grep -c "^v1|staging|" "$(sentinel_file)")"
    [ "$count" -eq 1 ]
}

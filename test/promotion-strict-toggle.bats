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

@test "disable: rejects an unsupported branch name before touching gh at all" {
    run bash "$SCRIPT" disable amin
    [ "$status" -eq 1 ]
    [[ "$output" == *"Unsupported branch 'amin'"* ]]
    [ ! -f "$(sentinel_file)" ]
    # gh's fake state dir should have no entry -- proves gh was never invoked
    [ ! -f "$FAKE_GH_STATE_DIR/strict-amin" ]
}

@test "restore: rejects an unsupported branch name before touching gh at all" {
    run bash "$SCRIPT" restore develop
    [ "$status" -eq 1 ]
    [[ "$output" == *"Unsupported branch 'develop'"* ]]
    [ ! -f "$FAKE_GH_STATE_DIR/strict-develop" ]
}

@test "disable/restore accept exactly dev, staging, and main" {
    for b in dev staging main; do
        run bash "$SCRIPT" disable "$b"
        [ "$status" -eq 0 ]
        run bash "$SCRIPT" restore "$b"
        [ "$status" -eq 0 ]
    done
}

@test "status: a corrupt line (unparsable timestamp) is reported as CORRUPT, not a crash" {
    echo "v1|staging|bordenet/superpowers-plus|not-a-number" > "$(sentinel_file)"
    run bash "$SCRIPT" status
    [ "$status" -eq 1 ]
    [[ "$output" == *"CORRUPT: sentinel entry for 'staging'"* ]]
}

@test "status: a line with extra pipe-delimited fields (read absorbs them into timestamp) is CORRUPT, not a crash" {
    # This is the exact shape produced by a lost-update race: read -r with
    # IFS='|' stuffs any trailing fields into the last variable ($ts), which
    # previously caused an 'unbound variable' crash in the age arithmetic.
    echo "v1|staging|bordenet/superpowers-plus|123|extra-field" > "$(sentinel_file)"
    run bash "$SCRIPT" status
    [ "$status" -eq 1 ]
    [[ "$output" == *"CORRUPT: sentinel entry for 'staging'"* ]]
    [[ "$output" != *"unbound variable"* ]]
}

@test "status: an empty timestamp field is CORRUPT, not silently treated as 'just disabled'" {
    echo "v1|staging|bordenet/superpowers-plus|" > "$(sentinel_file)"
    run bash "$SCRIPT" status
    [ "$status" -eq 1 ]
    [[ "$output" == *"CORRUPT: sentinel entry for 'staging'"* ]]
}

@test "status: --porcelain emits machine-parsable branch|state|age lines" {
    bash "$SCRIPT" disable staging
    run bash "$SCRIPT" status --porcelain
    [ "$status" -eq 0 ]
    [[ "$output" =~ ^staging\|active\|[0-9]+$ ]]
}

@test "status: --porcelain reports STALE and CORRUPT distinctly" {
    old=$(( $(date -u +%s) - 3600 ))
    {
      echo "v1|staging|bordenet/superpowers-plus|${old}"
      echo "v1|dev|bordenet/superpowers-plus|garbage"
    } > "$(sentinel_file)"
    run bash "$SCRIPT" status --porcelain
    [ "$status" -eq 1 ]
    [[ "$output" == *"staging|STALE|"* ]]
    [[ "$output" == *"dev|CORRUPT|-"* ]]
}

@test "concurrent disable on two different branches: neither entry is lost (lock prevents lost update)" {
    bash "$SCRIPT" disable main   # seed an existing entry, matches the real-world race scenario

    bash "$SCRIPT" disable staging &
    pid1=$!
    bash "$SCRIPT" disable dev &
    pid2=$!
    wait "$pid1"
    wait "$pid2"

    grep -q "^v1|main|" "$(sentinel_file)"
    grep -q "^v1|staging|" "$(sentinel_file)"
    grep -q "^v1|dev|" "$(sentinel_file)"
    [ "$(grep -c '^v1|' "$(sentinel_file)")" -eq 3 ]
}

@test "a stale lock directory does not deadlock forever (times out with an actionable message)" {
    mkdir -p "$WORK/.strict-toggle-state.lock"
    run timeout 15 bash "$SCRIPT" disable staging
    [ "$status" -eq 1 ]
    [[ "$output" == *"Could not acquire sentinel lock"* ]]
    rmdir "$WORK/.strict-toggle-state.lock"
}

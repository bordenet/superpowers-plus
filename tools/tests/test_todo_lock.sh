#!/usr/bin/env bash
# test_todo_lock.sh — Regression tests for todo-lock.sh
#
# A lock directory that exists but has no metadata file yet (the brief
# mkdir-then-write-metadata window of a concurrent acquirer) must NOT be
# treated as instantly orphaned/stale -- that let a waiter steal a lock
# nobody had abandoned, so both processes believed they held it.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCK_SCRIPT="$SCRIPT_DIR/../todo-lock.sh"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

make_fixture() {
  local root
  root=$(mktemp -d /tmp/todo-lock-test-XXXXXX)
  mkdir -p "$root/home/.codex"
  echo "$root"
}

test_fresh_lock_dir_without_metadata_is_not_stale() {
  local root
  root=$(make_fixture)
  mkdir "$root/home/.TODO.md.lock"

  local output
  output=$(HOME="$root/home" TODO_FILE_PATH="$root/home/TODO.md" "$LOCK_SCRIPT" status 2>&1) \
    || fail "status command should exit 0, got: $output"

  # Tolerate a 1s second-boundary rounding gap between mkdir and status
  # (e.g. mkdir at X.9s, status at (X+1).1s -- a real 0.2s gap that
  # "now - mtime" via whole-second timestamps reports as 1, not 0).
  echo "$output" | grep -qE '^LOCK_AGE=[01]$' \
    || fail "freshly-created lock dir without metadata must report a near-zero age, got: $output"
  echo "$output" | grep -q '^LOCK_STALE=false$' \
    || fail "freshly-created lock dir without metadata must not be stale, got: $output"

  rm -rf "$root"
}

test_orphaned_lock_dir_without_metadata_eventually_ages_out() {
  # Sanity check (not a fix-#3 regression test -- passes identically before
  # and after that fix): a lock dir that legitimately never gets metadata
  # (acquirer died) must still eventually be reclaimable.
  local root
  root=$(make_fixture)
  local lock_dir="$root/home/.TODO.md.lock"
  mkdir "$lock_dir"
  # Backdate the lock directory itself past any real TTL to simulate a
  # process that died before ever writing metadata.
  local old_time
  old_time=$(($(date +%s) - 100000))
  touch -t "$(date -r "$old_time" +%Y%m%d%H%M.%S 2>/dev/null || date -d "@$old_time" +%Y%m%d%H%M.%S)" "$lock_dir" \
    || fail 'could not backdate lock dir mtime for test setup'

  local output
  output=$(HOME="$root/home" TODO_FILE_PATH="$root/home/TODO.md" "$LOCK_SCRIPT" status 2>&1) \
    || fail "status command should exit 0, got: $output"

  echo "$output" | grep -q '^LOCK_STALE=true$' \
    || fail "backdated orphaned lock dir must eventually be reported stale, got: $output"

  rm -rf "$root"
}

test_two_concurrent_acquires_do_not_both_succeed_across_a_toctou_window() {
  # Simulate the exact race: process A's mkdir succeeds, metadata write is
  # delayed; process B's acquire attempt during that window must NOT steal
  # A's lock and must NOT itself report success while A still holds it.
  local root
  root=$(make_fixture)
  local todo_path="$root/home/TODO.md"
  mkdir "$root/home/.TODO.md.lock"
  # No metadata written yet -- this is process A's mid-acquisition state.

  local output
  output=$(HOME="$root/home" TODO_FILE_PATH="$todo_path" "$LOCK_SCRIPT" acquire --timeout 1 2>&1) \
    && fail 'process B must NOT acquire while A is mid-acquisition (no metadata yet, but not stale)'

  echo "$output" | grep -qi 'timeout\|held' \
    || fail "process B's failed acquire should report timeout/held, got: $output"

  rm -rf "$root"
}

test_release_refuses_a_lock_held_by_a_different_process() {
  # release used to remove whatever lock existed with no
  # ownership check -- functionally identical to steal.
  local root
  root=$(make_fixture)
  local lock_dir="$root/home/.TODO.md.lock"
  mkdir "$lock_dir"
  printf '{"hostname":"other-host","pid":999999,"epoch":%s,"agent":"x"}\n' "$(date +%s)" \
    > "$lock_dir/lock.json"

  local output status
  output=$(HOME="$root/home" TODO_FILE_PATH="$root/home/TODO.md" "$LOCK_SCRIPT" release 2>&1) \
    && status=0 || status=$?

  [[ "$status" -ne 0 ]] || fail "release of a different process's lock should fail, got: $output"
  [[ -d "$lock_dir" ]] || fail "lock dir must survive a refused release, got: $output"

  rm -rf "$root"
}

test_release_removes_a_lock_held_by_this_process() {
  local root
  root=$(make_fixture)
  local todo_path="$root/home/TODO.md"

  HOME="$root/home" TODO_FILE_PATH="$todo_path" "$LOCK_SCRIPT" acquire >/dev/null 2>&1 \
    || fail 'setup: acquire should succeed'
  HOME="$root/home" TODO_FILE_PATH="$todo_path" "$LOCK_SCRIPT" release >/dev/null 2>&1 \
    || fail 'release of a lock this process holds should succeed'
  [[ ! -d "$root/home/.TODO.md.lock" ]] \
    || fail 'lock dir should be removed after releasing a lock this process holds'

  rm -rf "$root"
}

test_release_refuses_when_metadata_is_corrupt() {
  local root
  root=$(make_fixture)
  local lock_dir="$root/home/.TODO.md.lock"
  mkdir "$lock_dir"
  echo '{not valid json' > "$lock_dir/lock.json"

  local output status
  output=$(HOME="$root/home" TODO_FILE_PATH="$root/home/TODO.md" "$LOCK_SCRIPT" release 2>&1) \
    && status=0 || status=$?

  [[ "$status" -ne 0 ]] || fail "release should refuse when metadata is corrupt, got: $output"
  [[ -d "$lock_dir" ]] || fail "a lock with corrupt metadata must survive a refused release"

  rm -rf "$root"
}

test_release_refuses_a_lock_with_no_metadata_yet_that_is_too_young() {
  local root
  root=$(make_fixture)
  local lock_dir="$root/home/.TODO.md.lock"
  mkdir "$lock_dir"
  # No metadata written yet -- this is the brief mkdir-then-write-metadata window.

  local output status
  output=$(HOME="$root/home" TODO_FILE_PATH="$root/home/TODO.md" "$LOCK_SCRIPT" release 2>&1) \
    && status=0 || status=$?

  [[ "$status" -ne 0 ]] || fail "release should refuse a metadata-less dir too young to be orphaned, got: $output"
  [[ -d "$lock_dir" ]] || fail "a fresh metadata-less lock dir must survive a refused release"

  rm -rf "$root"
}

test_declared_ttl_is_persisted_and_respected_over_a_waiters_own_default() {
  # A lock's OWN declared ttl governs its staleness, not whatever ttl a
  # waiter happens to be configured with -- a waiter using the short
  # default must not steal a lock a long-running holder (e.g.
  # write-archives.sh's ttl=600) explicitly declared as still valid.
  local root
  root=$(make_fixture)
  local todo_path="$root/home/TODO.md"
  local lock_dir="$root/home/.TODO.md.lock"

  HOME="$root/home" TODO_FILE_PATH="$todo_path" "$LOCK_SCRIPT" acquire --ttl 600 >/dev/null 2>&1 \
    || fail 'setup: acquire with --ttl 600 should succeed'
  grep -q '"ttl":600' "$lock_dir/lock.json" \
    || fail "declared ttl was not persisted into lock metadata: $(cat "$lock_dir/lock.json")"

  # Age the lock past the default 120s ttl but still within its own
  # declared 600s ttl (epoch drives staleness, not file mtime).
  local old_epoch
  old_epoch=$(($(date +%s) - 200))
  python3 -c "
import json
path = '$lock_dir/lock.json'
with open(path) as f:
    data = json.load(f)
data['epoch'] = $old_epoch
with open(path, 'w') as f:
    json.dump(data, f, separators=(',', ':'))
"

  # A waiter acquiring with the default ttl (no --ttl passed) must judge
  # staleness against the HOLDER's declared 600s, not its own 120s default.
  local output status
  output=$(HOME="$root/home" TODO_FILE_PATH="$todo_path" "$LOCK_SCRIPT" acquire --timeout 1 2>&1) \
    && status=0 || status=$?

  [[ "$status" -ne 0 ]] || fail "waiter must not steal a lock still valid under its own 600s declared ttl, got: $output"
  echo "$output" | grep -qi 'timeout\|held' \
    || fail "expected a timeout/held message, got: $output"
  [[ -d "$lock_dir" ]] || fail "original lock must survive -- it was not actually stale"

  rm -rf "$root"
}

test_old_format_lock_is_judged_against_the_waiters_own_fallback_ttl() {
  # An old-format lock (no "ttl" field yet -- e.g. written by a pre-upgrade
  # version of this tool) has no declared ttl of its own to defer to, so
  # staleness must fall back to the CHECKING caller's own configured ttl --
  # not a hardcoded constant that ignores what the caller actually asked
  # for. _is_stale() must thread its own fallback_ttl argument through to
  # _lock_declared_ttl(), not call it bare.
  local root
  root=$(make_fixture)
  local todo_path="$root/home/TODO.md"
  local lock_dir="$root/home/.TODO.md.lock"
  mkdir "$lock_dir"
  local old_epoch
  old_epoch=$(($(date +%s) - 80))
  printf '{"hostname":"other-host","pid":999999,"epoch":%s,"agent":"x"}\n' "$old_epoch" \
    > "$lock_dir/lock.json"

  # Waiter's own patience (30s) is shorter than the global DEFAULT_TTL
  # (120s) and shorter than the lock's actual age (80s) -- if the fallback
  # is threaded correctly, this lock is stale by the WAITER's own standard
  # and gets stolen. If the fallback is silently dropped in favor of the
  # global 120s constant, 80s doesn't exceed it and the waiter times out
  # instead.
  local output status
  output=$(HOME="$root/home" TODO_FILE_PATH="$todo_path" "$LOCK_SCRIPT" acquire --ttl 30 --timeout 1 2>&1) \
    && status=0 || status=$?

  [[ "$status" -eq 0 ]] || fail "waiter's own --ttl 30 must be honored for an old-format lock, got: $output"
  echo "$output" | grep -q '^LOCK_ACQUIRED=true$' \
    || fail "expected the old-format 80s-old lock to be stolen under a 30s fallback, got: $output"

  rm -rf "$root"
}

test_malformed_declared_ttl_does_not_defeat_staleness_check() {
  # A negative or overflow-scale ttl in lock.json must not be trusted: it
  # directly controls whether a live lock gets force-removed. A negative
  # ttl makes age > ttl true almost immediately; a value >= 2^63 can
  # overflow bash's signed 64-bit `-gt` and wrap negative. Either way, a
  # fresh (3s-old) lock held by a different process must survive a
  # concurrent acquire attempt instead of being stolen.
  local root
  root=$(make_fixture)
  local todo_path="$root/home/TODO.md"
  local lock_dir="$root/home/.TODO.md.lock"

  for bad_ttl in -5 9223372036854775808; do
    mkdir "$lock_dir"
    printf '{"hostname":"other-host","pid":999999,"epoch":%s,"ttl":%s,"agent":"x"}\n' \
      "$(($(date +%s) - 3))" "$bad_ttl" > "$lock_dir/lock.json"

    local output status
    output=$(HOME="$root/home" TODO_FILE_PATH="$todo_path" "$LOCK_SCRIPT" acquire --ttl 30 --timeout 1 2>&1) \
      && status=0 || status=$?

    [[ "$status" -ne 0 ]] || fail "a malformed ttl ($bad_ttl) must not let a fresh lock be stolen, got: $output"
    [[ -d "$lock_dir" ]] || fail "original lock must survive a malformed-ttl acquire attempt (ttl=$bad_ttl)"

    rm -rf "$lock_dir"
  done

  rm -rf "$root"
}

test_status_reports_the_declared_ttl() {
  # An operator's only way to confirm "is a 600s wait actually reasonable" is
  # to see the ttl the tool itself is judging staleness against -- without
  # this field, they'd have to trust static doc prose that silently goes
  # stale the moment a new caller declares a different ttl.
  local root
  root=$(make_fixture)
  local todo_path="$root/home/TODO.md"

  HOME="$root/home" TODO_FILE_PATH="$todo_path" "$LOCK_SCRIPT" acquire --ttl 600 >/dev/null 2>&1 \
    || fail 'setup: acquire with --ttl 600 should succeed'

  local output
  output=$(HOME="$root/home" TODO_FILE_PATH="$todo_path" "$LOCK_SCRIPT" status 2>&1) \
    || fail "status should exit 0, got: $output"

  echo "$output" | grep -q '^LOCK_TTL=600$' \
    || fail "status must report the lock's own declared ttl, got: $output"

  rm -rf "$root"
}

test_status_reports_stale_reason_for_a_dead_holder_pid() {
  # LOCK_STALE=true with LOCK_AGE=3 LOCK_TTL=600 looks like a bug in the
  # staleness arithmetic to anyone reading it without already knowing about
  # the separate dead-PID short-circuit -- status must say WHY it's stale.
  local root
  root=$(make_fixture)
  local todo_path="$root/home/TODO.md"
  local lock_dir="$root/home/.TODO.md.lock"
  mkdir "$lock_dir"
  printf '{"hostname":"%s","pid":999999,"epoch":%s,"ttl":600,"agent":"x"}\n' \
    "$(hostname -s 2>/dev/null || hostname)" "$(date +%s)" > "$lock_dir/lock.json"

  local output
  output=$(HOME="$root/home" TODO_FILE_PATH="$todo_path" "$LOCK_SCRIPT" status 2>&1) \
    || fail "status should exit 0, got: $output"

  echo "$output" | grep -q '^LOCK_STALE=true$' \
    || fail "a lock held by a dead pid on this host must be reported stale, got: $output"
  echo "$output" | grep -q '^LOCK_STALE_REASON=dead-holder-pid$' \
    || fail "status must report WHY the lock is stale, got: $output"

  rm -rf "$root"
}

test_fresh_lock_dir_without_metadata_is_not_stale
test_orphaned_lock_dir_without_metadata_eventually_ages_out
test_two_concurrent_acquires_do_not_both_succeed_across_a_toctou_window
test_status_reports_the_declared_ttl
test_status_reports_stale_reason_for_a_dead_holder_pid
test_declared_ttl_is_persisted_and_respected_over_a_waiters_own_default
test_old_format_lock_is_judged_against_the_waiters_own_fallback_ttl
test_malformed_declared_ttl_does_not_defeat_staleness_check
test_release_refuses_a_lock_held_by_a_different_process
test_release_removes_a_lock_held_by_this_process
test_release_refuses_when_metadata_is_corrupt
test_release_refuses_a_lock_with_no_metadata_yet_that_is_too_young
echo 'PASS: todo-lock regression tests'

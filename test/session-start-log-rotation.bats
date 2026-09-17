#!/usr/bin/env bats

setup() {
    REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd -P)"
    HOOK="$REPO_ROOT/tools/claude-hooks/session-start-rules-integrity.sh"
    TEST_HOME="$BATS_TEST_TMPDIR/home"
    HOOKS_DIR="$TEST_HOME/.claude/hooks"

    mkdir -p "$HOOKS_DIR" "$TEST_HOME/git/.ai-guidance"
    printf '# test invariants\n' > "$TEST_HOME/git/.ai-guidance/invariants.md"
    HOOK_INPUT="$(printf '{\"hook_event_name\":\"SessionStart\",\"session_id\":\"test\",\"cwd\":\"%s\",\"matcher\":\"startup\"}' "$BATS_TEST_TMPDIR")"
}

write_kib() {
    dd if=/dev/zero of="$1" bs=1024 count="$2" 2>/dev/null
}

file_size() {
    wc -c < "$1" | tr -d '[:space:]'
}

backdate_seconds() {
    local path="$1" seconds="$2" old_time timestamp
    old_time=$(($(date +%s) - seconds))
    timestamp="$(date -r "$old_time" +%Y%m%d%H%M.%S 2>/dev/null || date -d "@$old_time" +%Y%m%d%H%M.%S)"
    touch -t "$timestamp" "$path"
}

run_session_start() {
    HOME="$TEST_HOME" run bash "$HOOK" <<<"$HOOK_INPUT"
}

@test "P1e: SessionStart rotates an oversized audit log and retains two bounded generations" {
    write_kib "$HOOKS_DIR/hook-audit.log" 1025
    printf 'previous generation\n' > "$HOOKS_DIR/hook-audit.log.1"
    printf 'oldest generation\n' > "$HOOKS_DIR/hook-audit.log.2"
    printf 'outside rotation set\n' > "$HOOKS_DIR/hook-audit.log.3"

    run_session_start

    [ "$status" -eq 0 ]
    [ "$(file_size "$HOOKS_DIR/hook-audit.log.1")" -eq $((1025 * 1024)) ]
    [ "$(cat "$HOOKS_DIR/hook-audit.log.2")" = "previous generation" ]
    [ "$(cat "$HOOKS_DIR/hook-audit.log.3")" = "outside rotation set" ]
    grep -q 'session-start-integrity exit=0 reason=ok' "$HOOKS_DIR/hook-audit.log"
}

@test "P1e: SessionStart does not rotate logs at their exact byte limits" {
    write_kib "$HOOKS_DIR/hook-audit.log" 1024
    write_kib "$HOOKS_DIR/skill-router-metrics.jsonl" 5120

    run_session_start

    [ "$status" -eq 0 ]
    [ ! -e "$HOOKS_DIR/hook-audit.log.1" ]
    [ ! -e "$HOOKS_DIR/skill-router-metrics.jsonl.1" ]
    [ "$(file_size "$HOOKS_DIR/hook-audit.log")" -gt $((1024 * 1024)) ]
    [ "$(file_size "$HOOKS_DIR/skill-router-metrics.jsonl")" -eq $((5 * 1024 * 1024)) ]
}

@test "P1e: SessionStart rotates oversized skill-router metrics and retains one generation" {
    write_kib "$HOOKS_DIR/skill-router-metrics.jsonl" 5121
    printf 'previous metrics\n' > "$HOOKS_DIR/skill-router-metrics.jsonl.1"
    printf 'outside rotation set\n' > "$HOOKS_DIR/skill-router-metrics.jsonl.2"

    run_session_start

    [ "$status" -eq 0 ]
    [ ! -e "$HOOKS_DIR/skill-router-metrics.jsonl" ]
    [ "$(file_size "$HOOKS_DIR/skill-router-metrics.jsonl.1")" -eq $((5121 * 1024)) ]
    [ "$(cat "$HOOKS_DIR/skill-router-metrics.jsonl.2")" = "outside rotation set" ]
}

@test "P1e: SessionStart rotates the configured metrics file and leaves the oversized default untouched" {
    local custom_dir="$BATS_TEST_TMPDIR/custom-metrics"
    local custom_metrics="$custom_dir/router.jsonl"
    mkdir -p "$custom_dir"
    write_kib "$custom_metrics" 5121
    write_kib "$HOOKS_DIR/skill-router-metrics.jsonl" 5121

    CLAUDE_SKILL_ROUTER_METRICS="$custom_metrics" run_session_start

    [ "$status" -eq 0 ]
    [ ! -e "$custom_metrics" ]
    [ "$(file_size "$custom_metrics.1")" -eq $((5121 * 1024)) ]
    [ "$(file_size "$HOOKS_DIR/skill-router-metrics.jsonl")" -eq $((5121 * 1024)) ]
    [ ! -e "$HOOKS_DIR/skill-router-metrics.jsonl.1" ]
}

@test "P1e: configured metrics symlinks are preserved without rotating their targets" {
    local custom_dir="$BATS_TEST_TMPDIR/custom-metrics-symlink"
    local target="$custom_dir/target.jsonl"
    local configured="$custom_dir/configured.jsonl"
    mkdir -p "$custom_dir"
    write_kib "$target" 5121
    ln -s "$target" "$configured"

    CLAUDE_SKILL_ROUTER_METRICS="$configured" run_session_start

    [ "$status" -eq 0 ]
    [ -L "$configured" ]
    [ "$(readlink "$configured")" = "$target" ]
    [ "$(file_size "$target")" -eq $((5121 * 1024)) ]
    [ ! -e "$configured.1" ]
}

@test "P1e: missing rotation inputs do not break SessionStart" {
    run_session_start

    [ "$status" -eq 0 ]
    [[ "$output" == *"integrity OK"* ]]
    [ -f "$HOOKS_DIR/hook-audit.log" ]
    [ ! -e "$HOOKS_DIR/skill-router-metrics.jsonl" ]
}

@test "P1e: failed size probes do not break SessionStart" {
    local stub_dir="$BATS_TEST_TMPDIR/failing-size-probe"
    mkdir "$stub_dir"
    printf '#!/usr/bin/env bash\nexit 1\n' > "$stub_dir/wc"
    chmod +x "$stub_dir/wc"
    write_kib "$HOOKS_DIR/hook-audit.log" 1025
    write_kib "$HOOKS_DIR/skill-router-metrics.jsonl" 5121

    PATH="$stub_dir:$PATH" run_session_start

    [ "$status" -eq 0 ]
    [[ "$output" == *"integrity OK"* ]]
    [ ! -e "$HOOKS_DIR/hook-audit.log.1" ]
    [ ! -e "$HOOKS_DIR/skill-router-metrics.jsonl.1" ]
}

@test "P1e: concurrent SessionStart rotations preserve the retained metrics generation" {
    local stub_dir="$BATS_TEST_TMPDIR/paused-size-probe"
    local ready="$BATS_TEST_TMPDIR/rotation-ready"
    local release="$BATS_TEST_TMPDIR/rotation-release"
    local first_output="$BATS_TEST_TMPDIR/first-session.out"
    local real_wc first_pid waited
    real_wc="$(command -v wc)"
    mkdir "$stub_dir"
    # Keep fixture variables for the generated stub to expand at execution time.
    # shellcheck disable=SC2016
    printf '#!/usr/bin/env bash\n"%s" "$@"\n: > "$ROTATION_READY"\nwhile [[ ! -e "$ROTATION_RELEASE" ]]; do sleep 0.01; done\n' "$real_wc" > "$stub_dir/wc"
    chmod +x "$stub_dir/wc"
    write_kib "$HOOKS_DIR/skill-router-metrics.jsonl" 5121
    printf 'previous metrics\n' > "$HOOKS_DIR/skill-router-metrics.jsonl.1"

    HOME="$TEST_HOME" PATH="$stub_dir:$PATH" \
        ROTATION_READY="$ready" ROTATION_RELEASE="$release" \
        bash "$HOOK" <<<"$HOOK_INPUT" > "$first_output" 2>&1 &
    first_pid=$!

    waited=0
    while [[ ! -e "$ready" && "$waited" -lt 500 ]]; do
        sleep 0.01
        waited=$((waited + 1))
    done
    if [[ ! -e "$ready" ]]; then
        : > "$release"
        wait "$first_pid" || true
        echo "first SessionStart never reached the controlled size probe"
        return 1
    fi

    run_session_start
    [ "$status" -eq 0 ]
    : > "$release"
    wait "$first_pid"

    [ "$(file_size "$HOOKS_DIR/skill-router-metrics.jsonl.1")" -eq $((5121 * 1024)) ]
    [ ! -e "$HOOKS_DIR/skill-router-metrics.jsonl" ]
}

@test "P1e: concurrent stale zero-byte PID reclamation has one rotation winner" {
    local stub_dir="$BATS_TEST_TMPDIR/stale-reclaim-stubs"
    local sync_dir="$BATS_TEST_TMPDIR/stale-reclaim-sync"
    local lock_pid="$HOOKS_DIR/.log-rotation.lock/pid"
    local metrics="$HOOKS_DIR/skill-router-metrics.jsonl"
    local first_output="$BATS_TEST_TMPDIR/stale-reclaim-first.out"
    local second_output="$BATS_TEST_TMPDIR/stale-reclaim-second.out"
    local first_pid second_pid waited real_mkdir real_rm real_mv real_wc
    mkdir -p "$stub_dir" "$sync_dir" "$HOOKS_DIR/.log-rotation.lock"
    : > "$lock_pid"
    backdate_seconds "$lock_pid" 3600
    backdate_seconds "$HOOKS_DIR/.log-rotation.lock" 3600
    write_kib "$metrics" 5121
    printf 'previous metrics\n' > "$metrics.1"
    real_mkdir="$(command -v mkdir)"
    real_rm="$(command -v rm)"
    real_mv="$(command -v mv)"
    real_wc="$(command -v wc)"

    # Hold both hooks after their initial mkdir loses to the stale lock. The
    # rm/mv stubs then force the destructive interleaving that used to remove
    # the winner's new lock and retained generation. With a single-winner
    # reclaim claim, the second hook never reaches rotation.
    # shellcheck disable=SC2016
    printf '%s\n' \
        '#!/usr/bin/env bash' \
        'if [[ "$#" -eq 1 && "$1" == "$STALE_ROTATION_LOCK" ]]; then' \
        '  "$REAL_MKDIR" "$@"' \
        '  rc=$?' \
        '  if [[ "$rc" -ne 0 ]]; then' \
        '    if "$REAL_MKDIR" "$STALE_RACE_SYNC/mkdir-one" 2>/dev/null; then :; else "$REAL_MKDIR" "$STALE_RACE_SYNC/mkdir-two" 2>/dev/null || true; fi' \
        '    waited=0' \
        '    while [[ ! -e "$STALE_RACE_SYNC/mkdir-release" && "$waited" -lt 1000 ]]; do sleep 0.01; waited=$((waited + 1)); done' \
        '    [[ -e "$STALE_RACE_SYNC/mkdir-release" ]] || exit 98' \
        '  fi' \
        '  exit "$rc"' \
        'fi' \
        'exec "$REAL_MKDIR" "$@"' > "$stub_dir/mkdir"
    # shellcheck disable=SC2016
    printf '%s\n' \
        '#!/usr/bin/env bash' \
        'target="${!#}"' \
        'if [[ "$target" == "$STALE_LOCK_PID" ]]; then' \
        '  if mkdir "$STALE_RACE_SYNC/pid-rm-one" 2>/dev/null; then exec "$REAL_RM" "$@"; fi' \
        '  if mkdir "$STALE_RACE_SYNC/pid-rm-two" 2>/dev/null; then' \
        '    waited=0' \
        '    while [[ ! -s "$STALE_LOCK_PID" && "$waited" -lt 1000 ]]; do sleep 0.01; waited=$((waited + 1)); done' \
        '    [[ -s "$STALE_LOCK_PID" ]] || exit 97' \
        '    exec "$REAL_RM" "$@"' \
        '  fi' \
        'fi' \
        'if [[ "$target" == "$STALE_METRICS.1" ]]; then' \
        '  if mkdir "$STALE_RACE_SYNC/generation-rm-one" 2>/dev/null; then exec "$REAL_RM" "$@"; fi' \
        '  mkdir "$STALE_RACE_SYNC/generation-rm-two" 2>/dev/null || true' \
        '  waited=0' \
        '  while [[ ! -e "$STALE_RACE_SYNC/rotated-once" && "$waited" -lt 1000 ]]; do sleep 0.01; waited=$((waited + 1)); done' \
        '  [[ -e "$STALE_RACE_SYNC/rotated-once" ]] || exit 96' \
        '  exec "$REAL_RM" "$@"' \
        'fi' \
        'exec "$REAL_RM" "$@"' > "$stub_dir/rm"
    # shellcheck disable=SC2016
    printf '%s\n' \
        '#!/usr/bin/env bash' \
        'source_path="${@: -2:1}"' \
        'target_path="${!#}"' \
        'if [[ "$source_path" == "$STALE_METRICS" && "$target_path" == "$STALE_METRICS.1" ]]; then' \
        '  if mkdir "$STALE_RACE_SYNC/mv-one" 2>/dev/null; then' \
        '    "$REAL_MV" "$@"' \
        '    rc=$?' \
        '    : > "$STALE_RACE_SYNC/rotated-once"' \
        '    exit "$rc"' \
        '  fi' \
        '  mkdir "$STALE_RACE_SYNC/mv-two" 2>/dev/null || true' \
        'fi' \
        'exec "$REAL_MV" "$@"' > "$stub_dir/mv"
    # shellcheck disable=SC2016
    printf '%s\n' \
        '#!/usr/bin/env bash' \
        'if mkdir "$STALE_RACE_SYNC/wc-one" 2>/dev/null; then' \
        '  waited=0' \
        '  while [[ ! -d "$STALE_RACE_SYNC/wc-two" && "$waited" -lt 200 ]]; do sleep 0.01; waited=$((waited + 1)); done' \
        'else' \
        '  mkdir "$STALE_RACE_SYNC/wc-two" 2>/dev/null || true' \
        'fi' \
        'exec "$REAL_WC" "$@"' > "$stub_dir/wc"
    chmod +x "$stub_dir/mkdir" "$stub_dir/rm" "$stub_dir/mv" "$stub_dir/wc"

    HOME="$TEST_HOME" PATH="$stub_dir:$PATH" STALE_RACE_SYNC="$sync_dir" \
        STALE_ROTATION_LOCK="$HOOKS_DIR/.log-rotation.lock" \
        STALE_LOCK_PID="$lock_pid" STALE_METRICS="$metrics" \
        REAL_MKDIR="$real_mkdir" REAL_RM="$real_rm" \
        REAL_MV="$real_mv" REAL_WC="$real_wc" \
        bash "$HOOK" <<<"$HOOK_INPUT" > "$first_output" 2>&1 &
    first_pid=$!
    HOME="$TEST_HOME" PATH="$stub_dir:$PATH" STALE_RACE_SYNC="$sync_dir" \
        STALE_ROTATION_LOCK="$HOOKS_DIR/.log-rotation.lock" \
        STALE_LOCK_PID="$lock_pid" STALE_METRICS="$metrics" \
        REAL_MKDIR="$real_mkdir" REAL_RM="$real_rm" \
        REAL_MV="$real_mv" REAL_WC="$real_wc" \
        bash "$HOOK" <<<"$HOOK_INPUT" > "$second_output" 2>&1 &
    second_pid=$!

    waited=0
    while [[ (! -d "$sync_dir/mkdir-one" || ! -d "$sync_dir/mkdir-two") && "$waited" -lt 1000 ]]; do
        sleep 0.01
        waited=$((waited + 1))
    done
    if [[ ! -d "$sync_dir/mkdir-one" || ! -d "$sync_dir/mkdir-two" ]]; then
        : > "$sync_dir/mkdir-release"
        wait "$first_pid" || true
        wait "$second_pid" || true
        echo "both SessionStart processes did not reach the stale-lock barrier"
        return 1
    fi
    : > "$sync_dir/mkdir-release"

    wait "$first_pid"
    wait "$second_pid"

    [ ! -e "$metrics" ]
    [ "$(file_size "$metrics.1")" -eq $((5121 * 1024)) ]
    [ -d "$sync_dir/mv-one" ]
    [ ! -e "$sync_dir/mv-two" ]
    [ ! -e "$sync_dir/generation-rm-two" ]
    [ ! -e "$HOOKS_DIR/.log-rotation.lock" ]
}

@test "P1e: release preserves a replacement lock owned by another process" {
    local stub_dir="$BATS_TEST_TMPDIR/release-owner-stub"
    local ready="$BATS_TEST_TMPDIR/release-owner-ready"
    local release="$BATS_TEST_TMPDIR/release-owner-release"
    local hook_output="$BATS_TEST_TMPDIR/release-owner.out"
    local hook_pid waited real_wc
    mkdir "$stub_dir"
    # shellcheck disable=SC2016
    printf '%s\n' \
        '#!/usr/bin/env bash' \
        ': > "$ROTATION_READY"' \
        'waited=0' \
        'while [[ ! -e "$ROTATION_RELEASE" && "$waited" -lt 1000 ]]; do sleep 0.01; waited=$((waited + 1)); done' \
        '[[ -e "$ROTATION_RELEASE" ]] || exit 98' \
        'exec "$REAL_WC" "$@"' > "$stub_dir/wc"
    chmod +x "$stub_dir/wc"
    write_kib "$HOOKS_DIR/skill-router-metrics.jsonl" 5121
    real_wc="$(command -v wc)"

    HOME="$TEST_HOME" PATH="$stub_dir:$PATH" ROTATION_READY="$ready" \
        ROTATION_RELEASE="$release" REAL_WC="$real_wc" \
        bash "$HOOK" <<<"$HOOK_INPUT" > "$hook_output" 2>&1 &
    hook_pid=$!

    waited=0
    while [[ ! -e "$ready" && "$waited" -lt 1000 ]]; do
        sleep 0.01
        waited=$((waited + 1))
    done
    if [[ ! -e "$ready" ]]; then
        : > "$release"
        wait "$hook_pid" || true
        echo "SessionStart never reached the controlled size probe"
        return 1
    fi

    mv "$HOOKS_DIR/.log-rotation.lock" "$HOOKS_DIR/.log-rotation.displaced"
    mkdir "$HOOKS_DIR/.log-rotation.lock"
    printf '424242:999\n' > "$HOOKS_DIR/.log-rotation.lock/pid"
    : > "$release"
    wait "$hook_pid"

    [ "$(cat "$HOOKS_DIR/.log-rotation.lock/pid")" = "424242:999" ]
    [ -s "$HOOKS_DIR/.log-rotation.displaced/pid" ]
    [ "$(file_size "$HOOKS_DIR/skill-router-metrics.jsonl")" -eq $((5121 * 1024)) ]
    [ ! -e "$HOOKS_DIR/skill-router-metrics.jsonl.1" ]
}

@test "P1e: a paused initial acquirer cannot overwrite a replacement owner" {
    local initial_stub_dir="$BATS_TEST_TMPDIR/paused-initial-mkdir"
    local replacement_stub_dir="$BATS_TEST_TMPDIR/paused-replacement-wc"
    local initial_ready="$BATS_TEST_TMPDIR/initial-acquirer-ready"
    local initial_release="$BATS_TEST_TMPDIR/initial-acquirer-release"
    local replacement_ready="$BATS_TEST_TMPDIR/replacement-owner-ready"
    local replacement_release="$BATS_TEST_TMPDIR/replacement-owner-release"
    local initial_output="$BATS_TEST_TMPDIR/initial-acquirer.out"
    local replacement_output="$BATS_TEST_TMPDIR/replacement-owner.out"
    local metrics="$HOOKS_DIR/skill-router-metrics.jsonl"
    local initial_pid replacement_pid replacement_owner waited real_mkdir real_wc
    mkdir "$initial_stub_dir" "$replacement_stub_dir"

    # Pause the original process after it successfully creates the lock
    # directory but before it creates the owner record.
    # shellcheck disable=SC2016
    printf '%s\n' \
        '#!/usr/bin/env bash' \
        '"$REAL_MKDIR" "$@"' \
        'rc=$?' \
        'if [[ "$rc" -eq 0 && "$#" -eq 1 && "$1" == "$ROTATION_LOCK_PATH" ]]; then' \
        '  : > "$INITIAL_READY"' \
        '  waited=0' \
        '  while [[ ! -e "$INITIAL_RELEASE" && "$waited" -lt 1000 ]]; do sleep 0.01; waited=$((waited + 1)); done' \
        '  [[ -e "$INITIAL_RELEASE" ]] || exit 98' \
        'fi' \
        'exit "$rc"' > "$initial_stub_dir/mkdir"
    # Pause the replacement owner after ownership is established but before
    # its first destructive rotation step.
    # shellcheck disable=SC2016
    printf '%s\n' \
        '#!/usr/bin/env bash' \
        ': > "$REPLACEMENT_READY"' \
        'waited=0' \
        'while [[ ! -e "$REPLACEMENT_RELEASE" && "$waited" -lt 1000 ]]; do sleep 0.01; waited=$((waited + 1)); done' \
        '[[ -e "$REPLACEMENT_RELEASE" ]] || exit 97' \
        'exec "$REAL_WC" "$@"' > "$replacement_stub_dir/wc"
    chmod +x "$initial_stub_dir/mkdir" "$replacement_stub_dir/wc"
    write_kib "$metrics" 5121
    real_mkdir="$(command -v mkdir)"
    real_wc="$(command -v wc)"

    HOME="$TEST_HOME" PATH="$initial_stub_dir:$PATH" \
        REAL_MKDIR="$real_mkdir" ROTATION_LOCK_PATH="$HOOKS_DIR/.log-rotation.lock" \
        INITIAL_READY="$initial_ready" INITIAL_RELEASE="$initial_release" \
        bash "$HOOK" <<<"$HOOK_INPUT" > "$initial_output" 2>&1 &
    initial_pid=$!

    waited=0
    while [[ ! -e "$initial_ready" && "$waited" -lt 1000 ]]; do
        sleep 0.01
        waited=$((waited + 1))
    done
    if [[ ! -e "$initial_ready" ]]; then
        : > "$initial_release"
        wait "$initial_pid" || true
        echo "initial acquirer never reached its post-mkdir pause"
        return 1
    fi
    backdate_seconds "$HOOKS_DIR/.log-rotation.lock" 3600

    HOME="$TEST_HOME" PATH="$replacement_stub_dir:$PATH" \
        REPLACEMENT_READY="$replacement_ready" REPLACEMENT_RELEASE="$replacement_release" \
        REAL_WC="$real_wc" \
        bash "$HOOK" <<<"$HOOK_INPUT" > "$replacement_output" 2>&1 &
    replacement_pid=$!

    waited=0
    while [[ ! -e "$replacement_ready" && "$waited" -lt 1000 ]]; do
        sleep 0.01
        waited=$((waited + 1))
    done
    if [[ ! -e "$replacement_ready" ]]; then
        : > "$initial_release"
        : > "$replacement_release"
        wait "$initial_pid" || true
        wait "$replacement_pid" || true
        echo "replacement owner never reached its pre-rotation pause"
        return 1
    fi
    replacement_owner="$(cat "$HOOKS_DIR/.log-rotation.lock/pid")"
    [ -n "$replacement_owner" ]

    : > "$initial_release"
    wait "$initial_pid"

    [ -f "$metrics" ]
    [ ! -e "$metrics.1" ]
    [ "$(cat "$HOOKS_DIR/.log-rotation.lock/pid")" = "$replacement_owner" ]

    : > "$replacement_release"
    wait "$replacement_pid"

    [ ! -e "$metrics" ]
    [ "$(file_size "$metrics.1")" -eq $((5121 * 1024)) ]
    [ ! -e "$HOOKS_DIR/.log-rotation.lock" ]
}

@test "P1e: SessionStart reclaims a rotation lock held by a dead process" {
    mkdir "$HOOKS_DIR/.log-rotation.lock"
    printf '999999999\n' > "$HOOKS_DIR/.log-rotation.lock/pid"
    write_kib "$HOOKS_DIR/skill-router-metrics.jsonl" 5121

    run_session_start

    [ "$status" -eq 0 ]
    [ "$(file_size "$HOOKS_DIR/skill-router-metrics.jsonl.1")" -eq $((5121 * 1024)) ]
    [ ! -e "$HOOKS_DIR/.log-rotation.lock" ]
}

@test "P1e: SessionStart preserves a recent empty rotation lock" {
    mkdir "$HOOKS_DIR/.log-rotation.lock"
    write_kib "$HOOKS_DIR/skill-router-metrics.jsonl" 5121

    run_session_start

    [ "$status" -eq 0 ]
    [ -d "$HOOKS_DIR/.log-rotation.lock" ]
    [ -z "$(find "$HOOKS_DIR/.log-rotation.lock" -mindepth 1 -maxdepth 1 -print -quit)" ]
    [ -f "$HOOKS_DIR/skill-router-metrics.jsonl" ]
    [ ! -e "$HOOKS_DIR/skill-router-metrics.jsonl.1" ]
}

@test "P1e: SessionStart preserves a recent zero-byte PID lock" {
    mkdir "$HOOKS_DIR/.log-rotation.lock"
    : > "$HOOKS_DIR/.log-rotation.lock/pid"
    write_kib "$HOOKS_DIR/skill-router-metrics.jsonl" 5121

    run_session_start

    [ "$status" -eq 0 ]
    [ -f "$HOOKS_DIR/.log-rotation.lock/pid" ]
    [ ! -s "$HOOKS_DIR/.log-rotation.lock/pid" ]
    [ -f "$HOOKS_DIR/skill-router-metrics.jsonl" ]
    [ ! -e "$HOOKS_DIR/skill-router-metrics.jsonl.1" ]
}

@test "P1e: SessionStart recovers a stale empty rotation lock" {
    mkdir "$HOOKS_DIR/.log-rotation.lock"
    backdate_seconds "$HOOKS_DIR/.log-rotation.lock" 3600
    write_kib "$HOOKS_DIR/skill-router-metrics.jsonl" 5121

    run_session_start

    [ "$status" -eq 0 ]
    [ ! -e "$HOOKS_DIR/.log-rotation.lock" ]
    [ ! -e "$HOOKS_DIR/skill-router-metrics.jsonl" ]
    [ "$(file_size "$HOOKS_DIR/skill-router-metrics.jsonl.1")" -eq $((5121 * 1024)) ]
}

@test "P1e: SessionStart recovers a stale zero-byte PID lock" {
    mkdir "$HOOKS_DIR/.log-rotation.lock"
    : > "$HOOKS_DIR/.log-rotation.lock/pid"
    backdate_seconds "$HOOKS_DIR/.log-rotation.lock/pid" 3600
    backdate_seconds "$HOOKS_DIR/.log-rotation.lock" 3600
    write_kib "$HOOKS_DIR/skill-router-metrics.jsonl" 5121

    run_session_start

    [ "$status" -eq 0 ]
    [ ! -e "$HOOKS_DIR/.log-rotation.lock" ]
    [ ! -e "$HOOKS_DIR/skill-router-metrics.jsonl" ]
    [ "$(file_size "$HOOKS_DIR/skill-router-metrics.jsonl.1")" -eq $((5121 * 1024)) ]
}

@test "P1e: SessionStart recovers an orphaned stale reclaim claim" {
    mkdir "$HOOKS_DIR/.log-rotation.lock" "$HOOKS_DIR/.log-rotation.reclaim"
    : > "$HOOKS_DIR/.log-rotation.lock/pid"
    backdate_seconds "$HOOKS_DIR/.log-rotation.lock/pid" 3600
    backdate_seconds "$HOOKS_DIR/.log-rotation.lock" 3600
    backdate_seconds "$HOOKS_DIR/.log-rotation.reclaim" 3600
    write_kib "$HOOKS_DIR/skill-router-metrics.jsonl" 5121

    run_session_start

    [ "$status" -eq 0 ]
    [ ! -e "$HOOKS_DIR/.log-rotation.reclaim" ]
    [ ! -e "$HOOKS_DIR/.log-rotation.lock" ]
    [ ! -e "$HOOKS_DIR/skill-router-metrics.jsonl" ]
    [ "$(file_size "$HOOKS_DIR/skill-router-metrics.jsonl.1")" -eq $((5121 * 1024)) ]
}

@test "P1e: SessionStart preserves a recent reclaim claim" {
    mkdir "$HOOKS_DIR/.log-rotation.lock" "$HOOKS_DIR/.log-rotation.reclaim"
    : > "$HOOKS_DIR/.log-rotation.lock/pid"
    backdate_seconds "$HOOKS_DIR/.log-rotation.lock/pid" 3600
    backdate_seconds "$HOOKS_DIR/.log-rotation.lock" 3600
    write_kib "$HOOKS_DIR/skill-router-metrics.jsonl" 5121

    run_session_start

    [ "$status" -eq 0 ]
    [ -d "$HOOKS_DIR/.log-rotation.reclaim" ]
    [ -z "$(find "$HOOKS_DIR/.log-rotation.reclaim" -mindepth 1 -maxdepth 1 -print -quit)" ]
    [ -f "$HOOKS_DIR/skill-router-metrics.jsonl" ]
    [ ! -e "$HOOKS_DIR/skill-router-metrics.jsonl.1" ]
}

@test "P1e: SessionStart preserves a symlinked reclaim claim" {
    local claim_target="$BATS_TEST_TMPDIR/reclaim-claim-target"
    mkdir "$HOOKS_DIR/.log-rotation.lock" "$claim_target"
    : > "$HOOKS_DIR/.log-rotation.lock/pid"
    backdate_seconds "$HOOKS_DIR/.log-rotation.lock/pid" 3600
    backdate_seconds "$HOOKS_DIR/.log-rotation.lock" 3600
    backdate_seconds "$claim_target" 3600
    ln -s "$claim_target" "$HOOKS_DIR/.log-rotation.reclaim"
    write_kib "$HOOKS_DIR/skill-router-metrics.jsonl" 5121

    run_session_start

    [ "$status" -eq 0 ]
    [ -L "$HOOKS_DIR/.log-rotation.reclaim" ]
    [ "$(readlink "$HOOKS_DIR/.log-rotation.reclaim")" = "$claim_target" ]
    [ -f "$HOOKS_DIR/skill-router-metrics.jsonl" ]
    [ ! -e "$HOOKS_DIR/skill-router-metrics.jsonl.1" ]
}

@test "P1e: SessionStart preserves an ambiguous reclaim claim" {
    mkdir "$HOOKS_DIR/.log-rotation.lock" "$HOOKS_DIR/.log-rotation.reclaim"
    : > "$HOOKS_DIR/.log-rotation.lock/pid"
    printf 'preserve me\n' > "$HOOKS_DIR/.log-rotation.reclaim/unrecognized"
    backdate_seconds "$HOOKS_DIR/.log-rotation.lock/pid" 3600
    backdate_seconds "$HOOKS_DIR/.log-rotation.lock" 3600
    backdate_seconds "$HOOKS_DIR/.log-rotation.reclaim" 3600
    write_kib "$HOOKS_DIR/skill-router-metrics.jsonl" 5121

    run_session_start

    [ "$status" -eq 0 ]
    [ "$(cat "$HOOKS_DIR/.log-rotation.reclaim/unrecognized")" = "preserve me" ]
    [ -f "$HOOKS_DIR/skill-router-metrics.jsonl" ]
    [ ! -e "$HOOKS_DIR/skill-router-metrics.jsonl.1" ]
}

@test "P1e: SessionStart preserves an unrecognized rotation lock" {
    mkdir "$HOOKS_DIR/.log-rotation.lock"
    printf 'not-a-pid\n' > "$HOOKS_DIR/.log-rotation.lock/pid"
    write_kib "$HOOKS_DIR/skill-router-metrics.jsonl" 5121

    run_session_start

    [ "$status" -eq 0 ]
    [ -f "$HOOKS_DIR/.log-rotation.lock/pid" ]
    [ "$(cat "$HOOKS_DIR/.log-rotation.lock/pid")" = "not-a-pid" ]
    [ -f "$HOOKS_DIR/skill-router-metrics.jsonl" ]
    [ ! -e "$HOOKS_DIR/skill-router-metrics.jsonl.1" ]
}

@test "P1e: SessionStart preserves a symlinked rotation lock" {
    local lock_target="$BATS_TEST_TMPDIR/rotation-lock-target"
    mkdir "$lock_target"
    : > "$lock_target/pid"
    backdate_seconds "$lock_target/pid" 3600
    backdate_seconds "$lock_target" 3600
    ln -s "$lock_target" "$HOOKS_DIR/.log-rotation.lock"
    write_kib "$HOOKS_DIR/skill-router-metrics.jsonl" 5121

    run_session_start

    [ "$status" -eq 0 ]
    [ -L "$HOOKS_DIR/.log-rotation.lock" ]
    [ "$(readlink "$HOOKS_DIR/.log-rotation.lock")" = "$lock_target" ]
    [ -f "$lock_target/pid" ]
    [ ! -s "$lock_target/pid" ]
    [ -f "$HOOKS_DIR/skill-router-metrics.jsonl" ]
    [ ! -e "$HOOKS_DIR/skill-router-metrics.jsonl.1" ]
}

@test "P1e: SessionStart preserves a rotation lock with a symlinked PID" {
    local pid_target="$BATS_TEST_TMPDIR/rotation-pid-target"
    mkdir "$HOOKS_DIR/.log-rotation.lock"
    : > "$pid_target"
    backdate_seconds "$pid_target" 3600
    ln -s "$pid_target" "$HOOKS_DIR/.log-rotation.lock/pid"
    backdate_seconds "$HOOKS_DIR/.log-rotation.lock" 3600
    write_kib "$HOOKS_DIR/skill-router-metrics.jsonl" 5121

    run_session_start

    [ "$status" -eq 0 ]
    [ -L "$HOOKS_DIR/.log-rotation.lock/pid" ]
    [ "$(readlink "$HOOKS_DIR/.log-rotation.lock/pid")" = "$pid_target" ]
    [ -f "$HOOKS_DIR/skill-router-metrics.jsonl" ]
    [ ! -e "$HOOKS_DIR/skill-router-metrics.jsonl.1" ]
}

@test "P1e: SessionStart preserves a stale-looking lock with extra entries" {
    mkdir "$HOOKS_DIR/.log-rotation.lock"
    printf '999999999\n' > "$HOOKS_DIR/.log-rotation.lock/pid"
    printf 'preserve me\n' > "$HOOKS_DIR/.log-rotation.lock/unrecognized"
    write_kib "$HOOKS_DIR/skill-router-metrics.jsonl" 5121

    run_session_start

    [ "$status" -eq 0 ]
    [ "$(cat "$HOOKS_DIR/.log-rotation.lock/pid")" = "999999999" ]
    [ "$(cat "$HOOKS_DIR/.log-rotation.lock/unrecognized")" = "preserve me" ]
    [ -f "$HOOKS_DIR/skill-router-metrics.jsonl" ]
    [ ! -e "$HOOKS_DIR/skill-router-metrics.jsonl.1" ]
}

@test "P1e: a non-file backup path is preserved and cannot break SessionStart" {
    write_kib "$HOOKS_DIR/hook-audit.log" 1025
    mkdir "$HOOKS_DIR/hook-audit.log.1"
    printf 'preserve me\n' > "$HOOKS_DIR/hook-audit.log.1/sentinel"
    printf 'previous second generation\n' > "$HOOKS_DIR/hook-audit.log.2"

    run_session_start

    [ "$status" -eq 0 ]
    [ -f "$HOOKS_DIR/hook-audit.log.1/sentinel" ]
    [ "$(cat "$HOOKS_DIR/hook-audit.log.2")" = "previous second generation" ]
    [ "$(file_size "$HOOKS_DIR/hook-audit.log")" -gt $((1025 * 1024)) ]
}

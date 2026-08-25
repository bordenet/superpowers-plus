#!/usr/bin/env bats
# Unit tests for tools/lib/sha-lock.sh -- the per-SHA advisory lock that
# serialises concurrent run-battery.sh invocations against the same HEAD SHA.
# Hermetic: every test runs in a throwaway temp dir, so behavior does not
# depend on the surrounding repo state.

setup() {
    LIB="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)/tools/lib/sha-lock.sh"
    WORK="$(mktemp -d)"
    cd "$WORK"
}

teardown() {
    rm -rf "$WORK"
}

@test "sha_lock_acquire: creates the lock dir and writes caller PID" {
    run bash -c "source '$LIB' && sha_lock_acquire '$WORK/x.lock' 5 && cat '$WORK/x.lock/pid'"
    [ "$status" -eq 0 ]
    [[ "$output" =~ ^[0-9]+$ ]]
    [ -d "$WORK/x.lock" ]
}

@test "sha_lock_acquire: rejects missing lockdir arg with exit 2" {
    run bash -c "source '$LIB' && sha_lock_acquire ''"
    [ "$status" -eq 2 ]
    [[ "$output" == *"missing lockdir argument"* ]]
}

@test "sha_lock_acquire: times out and exits 1 when a live holder blocks it" {
    mkdir "$WORK/held.lock"
    echo "$$" > "$WORK/held.lock/pid"

    run bash -c "source '$LIB' && sha_lock_acquire '$WORK/held.lock' 2"
    [ "$status" -eq 1 ]
    [[ "$output" == *"held the lock for >2s"* ]]
    [[ "$output" == *"Concurrent runs on the same HEAD SHA are not supported"* ]]
    [ -d "$WORK/held.lock" ]
    [ -f "$WORK/held.lock/pid" ]
}

@test "sha_lock_acquire: reclaims a stale lock (dead PID) and proceeds" {
    mkdir "$WORK/stale.lock"
    echo "999999" > "$WORK/stale.lock/pid"
    ! kill -0 999999 2>/dev/null

    run bash -c "source '$LIB' && sha_lock_acquire '$WORK/stale.lock' 5 && cat '$WORK/stale.lock/pid'"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Reclaiming stale cr-battery lock"* ]]
    [[ "$output" == *"999999"* ]]
    [[ ! "$output" == *"999999"$'\n'* ]] || false
}

@test "sha_lock_release: removes the lock dir when this process owns it" {
    run bash -c "source '$LIB' && sha_lock_acquire '$WORK/r.lock' 5 && sha_lock_release && [[ ! -d '$WORK/r.lock' ]] && echo cleaned"
    [ "$status" -eq 0 ]
    [[ "$output" == *"cleaned"* ]]
    [ ! -d "$WORK/r.lock" ]
}

@test "sha_lock_release: is a no-op when this process does NOT own the lock" {
    mkdir "$WORK/foreign.lock"
    echo "12345" > "$WORK/foreign.lock/pid"

    run bash -c "source '$LIB' && sha_lock_release"
    [ "$status" -eq 0 ]
    [ -d "$WORK/foreign.lock" ]
    [ -f "$WORK/foreign.lock/pid" ]
}

@test "sha_lock_release: fires on EXIT via trap even on early error" {
    run bash -c "source '$LIB' && trap sha_lock_release EXIT && sha_lock_acquire '$WORK/trap.lock' 5 && exit 7"
    [ "$status" -eq 7 ]
    [ ! -d "$WORK/trap.lock" ]
}

@test "sha_lock_hash_file: returns a stable sha256 for identical content" {
    echo "envelope contents v1" > "$WORK/env.json"
    hash1=$(bash -c "source '$LIB' && sha_lock_hash_file '$WORK/env.json'")
    hash2=$(bash -c "source '$LIB' && sha_lock_hash_file '$WORK/env.json'")
    [ -n "$hash1" ]
    [ "$hash1" = "$hash2" ]
    [[ "$hash1" =~ ^[0-9a-f]{64}$ ]]
}

@test "sha_lock_hash_file: hash CHANGES when the file content changes" {
    echo "envelope contents v1" > "$WORK/env.json"
    hash1=$(bash -c "source '$LIB' && sha_lock_hash_file '$WORK/env.json'")
    echo "envelope contents v2 mutated by a concurrent orchestrator" > "$WORK/env.json"
    hash2=$(bash -c "source '$LIB' && sha_lock_hash_file '$WORK/env.json'")
    [ -n "$hash1" ]
    [ -n "$hash2" ]
    [ "$hash1" != "$hash2" ]
}

@test "sha_lock_hash_file: silent no-op on missing file (bypass path)" {
    run bash -c "source '$LIB' && sha_lock_hash_file '$WORK/does-not-exist.json'"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "sha_lock: serialises two concurrent acquirers on the same lock" {
    bash -c "source '$LIB' && trap sha_lock_release EXIT && sha_lock_acquire '$WORK/ser.lock' 10 && sleep 2 && echo A-done" > "$WORK/a.out" 2>&1 &
    A=$!
    sleep 1
    bash -c "source '$LIB' && trap sha_lock_release EXIT && sha_lock_acquire '$WORK/ser.lock' 10 && echo B-done" > "$WORK/b.out" 2>&1 &
    B=$!
    wait $A
    RC_A=$?
    wait $B
    RC_B=$?
    [ "$RC_A" -eq 0 ]
    [ "$RC_B" -eq 0 ]
    [[ "$(cat "$WORK/a.out")" == *"A-done"* ]]
    [[ "$(cat "$WORK/b.out")" == *"B-done"* ]]
    [ ! -d "$WORK/ser.lock" ]
}

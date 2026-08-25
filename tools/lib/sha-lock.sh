#!/usr/bin/env bash
# tools/lib/sha-lock.sh -- per-SHA advisory lock for cr-battery
#
# Two run-battery.sh invocations against the same HEAD SHA (e.g. two worktrees,
# two agents on the same repo state) can race on the shared envelope file
# .cr-battery-runs/<sha>.json: orchestrator A writes envelope A, run-battery A
# reads it, orchestrator B overwrites the file with envelope B, and run-battery
# A now sentinel-binds to envelope B's claims instead of the ones it actually
# verified. mkdir is atomic across POSIX filesystems (single-syscall, no
# fallback race), so an mkdir-based lock deterministically serialises the
# verifier -> sentinel window on the same SHA.
#
# Callers must:
#   1) source this file
#   2) call `sha_lock_acquire <lockdir> [timeout_seconds]`
#   3) register `trap sha_lock_release EXIT INT TERM` before or immediately
#      after acquire so a crash always releases the lock
#
# sha_lock_acquire prints an info message on stale reclaim and an error message
# on timeout, then exits 1 on timeout. Callers therefore do not need to check
# the return code -- if it returns, the lock is held by this process.
#
# Local filesystem only; no NFS / network shares in scope, so the well-known
# mkdir-lock pitfalls (silent lease loss under network partition) do not apply.

_SHA_LOCK_DIR=""    # path to the lock directory, set at acquisition time
_SHA_LOCK_HELD=0    # 1 iff this process owns the lock -- guards the trap

sha_lock_acquire() {
    local lockdir="$1"
    local timeout="${2:-60}"
    local attempts=0
    local holder_pid

    if [[ -z "$lockdir" ]]; then
        echo "sha_lock_acquire: missing lockdir argument" >&2
        exit 2
    fi

    while ! mkdir "$lockdir" 2>/dev/null; do
        # Stale-lock recovery: if the recorded PID is dead, reclaim the lock.
        # Missing pid file (racing writer between mkdir and echo $$) is treated
        # as a live-in-flight holder until the attempt counter forces timeout.
        if [[ -f "$lockdir/pid" ]]; then
            holder_pid=$(cat "$lockdir/pid" 2>/dev/null || echo "")
            if [[ -n "$holder_pid" ]] && ! kill -0 "$holder_pid" 2>/dev/null; then
                echo "INFO: Reclaiming stale cr-battery lock (pid $holder_pid is not running)." >&2
                rm -f "$lockdir/pid" 2>/dev/null || true
                rmdir "$lockdir" 2>/dev/null || true
                continue
            fi
        fi
        attempts=$((attempts + 1))
        if [[ "$attempts" -ge "$timeout" ]]; then
            echo "ERROR: Another cr-battery run has held the lock for >${timeout}s on this SHA." >&2
            echo "   Lock: $lockdir" >&2
            echo "   Concurrent runs on the same HEAD SHA are not supported -- one" >&2
            echo "   orchestrator's envelope would clobber the other's mid-verify." >&2
            echo "   If the holder crashed, remove the lock dir manually and re-run." >&2
            exit 1
        fi
        sleep 1
    done

    echo "$$" > "$lockdir/pid"
    _SHA_LOCK_DIR="$lockdir"
    _SHA_LOCK_HELD=1
}

sha_lock_release() {
    # Only remove the lock directory if THIS process owns it. A trap firing
    # before acquisition (e.g. bad arg -> exit 2) must not touch a lock held
    # by a concurrent run. rmdir -- not rm -rf -- so a bug that populates the
    # lock dir with unexpected files surfaces loudly instead of silently
    # deleting evidence.
    if [[ "$_SHA_LOCK_HELD" == "1" ]] && [[ -n "$_SHA_LOCK_DIR" ]] && [[ -d "$_SHA_LOCK_DIR" ]]; then
        rm -f "$_SHA_LOCK_DIR/pid" 2>/dev/null || true
        rmdir "$_SHA_LOCK_DIR" 2>/dev/null || true
    fi
}

# Envelope-mutation guard. Callers pass a file path and compare the returned
# sha256 against a snapshot captured earlier. Empty string on hash-tool absence
# means "cannot verify" -- the caller decides how to handle that (run-battery
# treats an empty snapshot as a silent-success bypass so the existing behavior
# on hash-tool-free hosts is preserved).
sha_lock_hash_file() {
    local file="$1"
    if [[ ! -f "$file" ]]; then
        return 0
    fi
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum -- "$file" 2>/dev/null | awk '{print $1}'
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 -- "$file" 2>/dev/null | awk '{print $1}'
    else
        return 0
    fi
}

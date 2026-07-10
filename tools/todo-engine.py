#!/usr/bin/env python3
"""todo-engine.py — Cross-platform TODO.md CRUD engine.

Handles add, complete, move, list, next-id, defer, claim, unclaim, reap, cat,
path operations with built-in preflight (path resolution), advisory locking,
backup, structural validation, ID allocation, section targeting, safe multiline
content handling, and multi-agent claim coordination with TTL-based expiry.

Usage (typically called via todo-crud.sh wrapper):
    python3 todo-engine.py add --priority P3 --description "Task" --tags "#foo"
    python3 todo-engine.py complete --id 20260322-01
    python3 todo-engine.py move --id 20260322-01 --to P1
    python3 todo-engine.py list [--priority P1] [--tag "#plan-foo"] [--all]
    python3 todo-engine.py next-id
    python3 todo-engine.py defer --id 20260322-01 --reason "Blocked"
    python3 todo-engine.py claim --id 20260322-01 --agent myagent --ttl 30
    python3 todo-engine.py unclaim --id 20260322-01
    python3 todo-engine.py reap
"""

import argparse
import datetime
import json
import os
import re
import tempfile
import shutil
import subprocess
import sys
import time
from pathlib import Path

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------
LOCK_DIR_NAME = ".TODO.md.lock"
LOCK_TTL = 120  # seconds
LOCK_TIMEOUT = 8  # seconds
MAX_LOCK_TTL = 9999999  # ~115 days; bounds a declared ttl read from lock.json
SHADOW_DIR = os.path.expanduser("~/.codex/todo-shadow")

# Section markers (regex patterns)
RE_P1 = re.compile(r"^## P1\b", re.MULTILINE)
RE_P2 = re.compile(r"^## P2\b", re.MULTILINE)
RE_P3 = re.compile(r"^## P3\b", re.MULTILINE)
RE_HISTORY = re.compile(r"^# HISTORY\b", re.MULTILINE)
RE_DEFERRED = re.compile(r"^# DEFERRED\b", re.MULTILINE)
RE_TASK = re.compile(r"^- \[[ x/]\] \[(\d{8}-\d{2,})\]", re.MULTILINE)
RE_SECTION = re.compile(r"^(?:##? |---)", re.MULTILINE)
RE_CLAIM = re.compile(r"^  - Claimed: (\S+) by (\S+) ttl=(\d+)$", re.MULTILINE)
DEFAULT_CLAIM_TTL = 30  # minutes

PRIORITY_MARKERS = {"P1": RE_P1, "P2": RE_P2, "P3": RE_P3}

# File protection mode — read-only for owner, group, others.
# This prevents save-file, str-replace-editor, and shell redirects from
# overwriting TODO.md without going through todo-engine.py.
FILE_MODE_PROTECTED = 0o444   # r--r--r--

# Platform detection for immutability flags
PLATFORM = sys.platform  # 'darwin' (macOS), 'linux', etc.
FILE_MODE_WRITABLE  = 0o644   # rw-r--r--

# ---------------------------------------------------------------------------
# Path Resolution
# ---------------------------------------------------------------------------

def resolve_todo_path() -> str:
    """Resolve TODO.md path from private registry, env, or default.

    Priority: 1) TODO_FILE_PATH env var (for testing ONLY — not in .env)
              2) ~/.codex/.todo-registry (private file — agents don't see this)
              3) ~/.codex/.env TODO_FILE_PATH (backward compat, deprecated)
              4) Default ~/.codex/TODO.md

    The path is deliberately NOT advertised in .env or rules files.
    Agents should use todo-crud.sh which calls this function internally.
    """
    # 1. Check current environment first (allows export override for testing)
    env_path = os.environ.get("TODO_FILE_PATH", "").strip()
    if env_path:
        return os.path.expanduser(os.path.expandvars(env_path))

    # 2. Private registry — the preferred source (agents don't know about this)
    registry = Path.home() / ".codex" / ".todo-registry"
    if registry.exists():
        path = registry.read_text().strip()
        if path:
            return os.path.expanduser(os.path.expandvars(path))

    # 3. Backward compat: source ~/.codex/.env (deprecated — migrate to registry)
    env_file = Path.home() / ".codex" / ".env"
    if env_file.exists():
        try:
            result = subprocess.run(
                ["bash", "-c", f"source {env_file} 2>/dev/null && echo $TODO_FILE_PATH"],
                capture_output=True, text=True, timeout=5
            )
            path = result.stdout.strip()
            if path:
                return os.path.expanduser(os.path.expandvars(path))
        except (subprocess.TimeoutExpired, FileNotFoundError):
            pass

    # 4. Default — WARN loudly so agents notice the misconfiguration
    default = os.path.expanduser("~/.codex/TODO.md")
    print(
        f"WARNING: TODO path not found in .todo-registry, environment, or .env. "
        f"Falling back to default: {default}. "
        f"Create ~/.codex/.todo-registry with the real path.",
        file=sys.stderr,
    )
    return default


def ensure_file_exists(path: str) -> None:
    """Abort if TODO.md doesn't exist."""
    if not os.path.isfile(path):
        _error(f"TODO.md does not exist at {path}. "
               "Run todo-preflight.sh --create-if-missing first.")

# ---------------------------------------------------------------------------
# Advisory Locking (mkdir-based, compatible with todo-lock.sh)
# ---------------------------------------------------------------------------

def _lock_dir(todo_path: str) -> str:
    return os.path.join(os.path.dirname(todo_path), LOCK_DIR_NAME)


def _lock_meta(todo_path: str) -> str:
    return os.path.join(_lock_dir(todo_path), "lock.json")


def _lock_age(todo_path: str) -> int:
    meta = _lock_meta(todo_path)
    if os.path.isfile(meta):
        try:
            with open(meta) as f:
                data = json.load(f)
            return int(time.time()) - data.get("epoch", 0)
        except (json.JSONDecodeError, OSError, TypeError, ValueError):
            return 999999
    lock_dir = _lock_dir(todo_path)
    if os.path.isdir(lock_dir):
        # Lock directory exists but metadata hasn't been written yet -- this
        # is the normal state during a concurrent acquirer's brief
        # mkdir-then-write-metadata window, not necessarily a dead process.
        # Treating it as instantly orphaned let a concurrent waiter steal a
        # lock that was never abandoned, so both processes believed they held
        # it. Use the directory's own mtime as the age instead: a
        # genuinely-orphaned dir ages out via the same TTL as any stale lock.
        try:
            return int(time.time()) - int(os.stat(lock_dir).st_mtime)
        except OSError:
            return 999999
    return 0


def _lock_declared_ttl(todo_path: str, fallback: int) -> int:
    """Read the ttl an existing lock's own holder declared, if any.

    Staleness of an existing lock must be judged against what its HOLDER
    declared, not against whatever ttl the current caller happens to be
    configured with -- a caller with a short default ttl must not treat a
    long-running holder's lock (e.g. write-archives.sh's ttl=600) as stale
    just because its own patience is shorter. fallback applies only when
    there is no metadata yet to read a declared ttl from.
    """
    meta = _lock_meta(todo_path)
    if os.path.isfile(meta):
        try:
            with open(meta) as f:
                data = json.load(f)
            ttl = int(data.get("ttl", fallback))
        except (json.JSONDecodeError, OSError, TypeError, ValueError):
            return fallback
        # A negative or zero ttl makes age > ttl true almost immediately,
        # letting a live lock be force-removed the moment another process
        # checks it -- defeating the staleness check's fail-safe direction
        # instead of just failing to parse. An absurdly large ttl is bounded
        # too, matching todo-lock.sh's MAX_LOCK_TTL validation.
        if 0 < ttl <= MAX_LOCK_TTL:
            return ttl
        return fallback
    return fallback


def _lock_holder_pid_is_dead(todo_path: str) -> bool:
    """Mirrors todo-lock.sh's `kill -0` check: a lock declared by a dead
    process on THIS host is immediately reclaimable regardless of ttl --
    without this, every leaked lock (a crash, a killed process) takes the
    full declared ttl (up to 600s for write-archives.sh) to recover from,
    even though the dead PID is trivially, instantly detectable locally.
    """
    meta = _lock_meta(todo_path)
    if not os.path.isfile(meta):
        return False
    try:
        with open(meta) as f:
            data = json.load(f)
    except (json.JSONDecodeError, OSError):
        return False
    hostname = os.uname().nodename.split(".")[0]
    if data.get("hostname") != hostname:
        return False
    pid = data.get("pid")
    if not isinstance(pid, int) or pid <= 0:
        return False
    try:
        os.kill(pid, 0)
        return False  # process exists
    except ProcessLookupError:
        return True
    except PermissionError:
        return False  # exists, just not signalable by us


def _lock_holder_identity(todo_path: str) -> str:
    """Best-effort "host:pid" string for diagnostics. Never raises -- a
    malformed or missing lock.json must not prevent printing a timeout/steal
    message, it should just degrade to "unknown:unknown"."""
    meta = _lock_meta(todo_path)
    try:
        with open(meta) as f:
            data = json.load(f)
        return f"{data.get('hostname', 'unknown')}:{data.get('pid', 'unknown')}"
    except (json.JSONDecodeError, OSError, TypeError, ValueError):
        return "unknown:unknown"


def acquire_lock(todo_path: str, ttl: int = LOCK_TTL) -> bool:
    """Acquire advisory lock. Returns True on success.

    ttl is persisted into this lock's own metadata (if acquired) so other
    processes judge staleness against THIS holder's declared ttl -- see
    _lock_declared_ttl().
    """
    lock = _lock_dir(todo_path)
    deadline = time.time() + LOCK_TIMEOUT
    hostname = os.uname().nodename.split(".")[0]
    # getppid(), not getpid(): this is typically invoked as a short-lived
    # subprocess on behalf of a longer-lived parent shell/agent. Recording
    # this process's own PID would make every lock look abandoned the
    # instant this subprocess exits. Ownership checks (release_lock(),
    # _lock_holder_pid_is_dead()) rely on this same identity, so a caller
    # acquiring and releasing across two separate subprocess invocations
    # (as write-archives.sh does) only works because both calls share the
    # same living parent process.
    pid = os.getppid()

    while True:
        try:
            os.mkdir(lock)
            # Write metadata
            meta = {"hostname": hostname, "pid": pid,
                    "epoch": int(time.time()), "agent": "todo-engine",
                    "ttl": ttl}
            tmp = _lock_meta(todo_path) + f".tmp.{os.getpid()}"
            with open(tmp, "w") as f:
                # Compact separators (no space after ':'): todo-lock.sh's
                # _lock_hostname()/_lock_pid() parse this file with a strict
                # `"hostname":"..."` grep pattern (matching how it writes its
                # own metadata via printf) with no whitespace tolerance.
                # json.dump()'s default separators insert a space after each
                # colon, so every lock this function creates was silently
                # unparseable by the shell tool -- status showed a blank
                # holder, and a same-caller `todo-lock.sh release` could
                # never recognize itself as the owner.
                json.dump(meta, f, separators=(",", ":"))
            os.replace(tmp, _lock_meta(todo_path))
            return True
        except FileExistsError:
            age = _lock_age(todo_path)
            dead_pid = _lock_holder_pid_is_dead(todo_path)
            ttl_expired = age > _lock_declared_ttl(todo_path, ttl)
            if dead_pid or ttl_expired:
                # Distinguish the reason: a dead-PID steal can fire at
                # near-zero age (the crash could have happened seconds ago),
                # and "stealing stale lock (age=0s)" with no reason reads
                # like a bug in the staleness arithmetic to anyone who
                # doesn't already know about this separate short-circuit.
                reason = "dead-holder-pid" if dead_pid else "ttl-expired"
                print(f"todo-engine: stealing stale lock at {lock} "
                      f"(age={age}s, reason={reason}, "
                      f"holder={_lock_holder_identity(todo_path)})",
                      file=sys.stderr)
                shutil.rmtree(lock, ignore_errors=True)
                continue
            if time.time() >= deadline:
                print(f"todo-engine: timed out waiting for lock at {lock} "
                      f"(held by {_lock_holder_identity(todo_path)}, age={age}s)",
                      file=sys.stderr)
                return False
            time.sleep(1)


def release_lock(todo_path: str) -> bool:
    """Release advisory lock. Returns True if released (or nothing was held),
    False if refused. A refusal prints why to stderr -- callers that depend
    on this lock for a multi-minute hold (write-archives.sh) need a visible
    trail, not a lock that just silently never lets go.
    """
    lock = _lock_dir(todo_path)
    if not os.path.isdir(lock):
        return True
    # Ownership check: without this, release is functionally identical to a
    # forced steal -- any caller could drop a different, currently-live
    # holder's lock with no check at all.
    #
    # Missing metadata is ambiguous the same way it is in _lock_age(): it
    # means either "genuinely orphaned" (acquirer died before writing
    # metadata) or "a different process is mid-acquisition right now" (the
    # brief mkdir-then-write-metadata window). Falling through to unconditional
    # removal treated both cases as safe to delete, which can drop a lock a
    # different process just legitimately created. Use the same young/old
    # distinction _lock_age() uses: only remove a metadata-less dir once it's
    # old enough to be genuinely orphaned, not merely young (still being
    # acquired).
    #
    # A metadata file that exists but fails to parse must be treated as
    # "cannot verify ownership" -> refuse, not "safe to delete". Falling
    # through on parse failure reopened the exact hole this check exists to
    # close, just via corrupt data instead of no data.
    meta = _lock_meta(todo_path)
    if os.path.isfile(meta):
        try:
            with open(meta) as f:
                data = json.load(f)
        except (json.JSONDecodeError, OSError):
            print(f"todo-engine: refusing to release lock at {lock} -- "
                  "metadata is corrupt/unreadable, cannot verify ownership",
                  file=sys.stderr)
            return False
        hostname = os.uname().nodename.split(".")[0]
        pid = os.getppid()
        if data.get("hostname") != hostname or data.get("pid") != pid:
            print(f"todo-engine: refusing to release lock at {lock} -- "
                  f"held by {data.get('hostname')}:{data.get('pid')}, not "
                  f"this process ({hostname}:{pid})", file=sys.stderr)
            return False
    else:
        age = _lock_age(todo_path)
        if age < LOCK_TTL:
            print(f"todo-engine: refusing to release lock at {lock} -- no "
                  f"metadata yet and too young ({age}s) to be sure this "
                  "isn't a live mid-acquisition", file=sys.stderr)
            return False
    shutil.rmtree(lock, ignore_errors=True)
    return True


BAK_MAX_KEEP = 10  # Maximum .bak files to keep


def backup(todo_path: str) -> str:
    """Create timestamped backup in SHADOW_DIR and rotate old backups.

    Writes to ~/.codex/todo-shadow/ instead of alongside TODO.md so that
    backups work even when TODO.md lives on an immutable filesystem
    (e.g. OneDrive with chflags uchg).  Returns backup path.
    """
    os.makedirs(SHADOW_DIR, exist_ok=True)
    ts = datetime.datetime.now().strftime("%Y%m%d-%H%M%S")
    bak = os.path.join(SHADOW_DIR, f"TODO.{ts}.bak")
    # Use copyfile (content only) instead of copy2 (preserves flags).
    # copy2 would propagate uchg/immutability flags to the backup,
    # making old backups undeletable during rotation.
    shutil.copyfile(todo_path, bak)
    # Rotate: delete all but newest BAK_MAX_KEEP.
    # Store target BEFORE popping — if os.remove() raises OSError, the item
    # would already be gone from the list but still on disk, causing the loop
    # to terminate early while leaving the file in place and deleting a newer
    # valid backup on the next call instead.
    import glob
    bak_pattern = os.path.join(SHADOW_DIR, "TODO.*.bak")
    existing = sorted(glob.glob(bak_pattern))
    while len(existing) > BAK_MAX_KEEP:
        target = existing[0]
        try:
            os.remove(target)
            existing.pop(0)  # only pop after confirmed removal
        except OSError as exc:
            print(
                f"WARNING: backup rotation could not delete {target}: {exc}",
                file=sys.stderr,
            )
            existing.pop(0)  # still pop to avoid infinite loop on permanently stuck files
    return bak

# ---------------------------------------------------------------------------
# File Parsing Helpers
# ---------------------------------------------------------------------------

def read_file(path: str) -> str:
    with open(path, "r") as f:
        return f.read()


def _normalize_whitespace(content: str) -> str:
    """Collapse 3+ consecutive blank lines into 2 (one visual gap)."""
    return re.sub(r"\n{4,}", "\n\n\n", content)


# ---------------------------------------------------------------------------
# Structural Validation — last-resort safety gate
# ---------------------------------------------------------------------------
# Incident 2026-03-23: an agent used save-file to overwrite TODO.md with a raw
# task list, destroying dozens of unstarted tasks permanently.  This gate
# refuses to write content that does not match the canonical TODO.md structure.

# Required top-level headers in the order they must appear.
# FORMAT EVOLUTION NOTE: Adding a new required section (e.g. "# RECURRING") is a
# breaking change — all existing TODO.md files must be migrated before deploying the
# updated engine, or write_file() will refuse ALL writes to unmigrated files.
# Migration procedure: (1) run todo-maintenance.sh --dry-run to find affected files,
# (2) add the new header to each file via todo-crud.sh migrate-header (if implemented),
# or (3) temporarily remove the new entry from REQUIRED_HEADERS, deploy, migrate, then
# add it back. Never remove existing entries — that weakens the structural guarantee.
REQUIRED_HEADERS = ["# ACTIVE TASKS", "# HISTORY", "# DEFERRED", "# METRICS"]

# Required priority subsections under # ACTIVE TASKS, in order.
REQUIRED_SUBSECTIONS = ["## P1", "## P2", "## P3"]


def _find_anchored_headers(lines, headers):
    """Find line positions of anchored headers. Returns {header: [positions]}."""
    positions = {h: [] for h in headers}
    for i, line in enumerate(lines):
        stripped = line.rstrip()
        for h in headers:
            if stripped == h or stripped.startswith(h + " "):
                positions[h].append(i)
    return positions


def validate_structure(content: str) -> None:
    """Refuse to write content that lacks required TODO.md structure.

    Checks:
      1. All required top-level headers present and anchored at line start.
      2. Headers appear in the correct order (no reordering).
      3. No duplicate top-level headers.
      4. Priority subsections (P1/P2/P3) present, unique, and in order.
      5. Content has at least one non-header, non-separator line (task, date,
         metadata) to prevent scaffold-only wipes.

    SCOPE: Guards calls that go through write_file() (i.e., todo-crud.sh operations).
    First-time file creation via todo-preflight.sh --create-if-missing writes a
    scaffold directly via heredoc, intentionally bypassing this gate — the system
    is authoring the template, not an agent overwriting existing content.
    OS-level immutability (chflags uchg / chattr +i) guards against direct writes
    by agent tools (save-file, str-replace-editor, shell redirects) that never reach
    this function. See the 7-layer enforcement table in core.always.md.
    """
    lines = content.split("\n")

    # --- 1 & 3: Presence, anchoring, and uniqueness of top-level headers ---
    header_positions = _find_anchored_headers(lines, REQUIRED_HEADERS)

    missing = [h for h, pos in header_positions.items() if not pos]
    if missing:
        _error(
            f"REFUSED TO WRITE: TODO.md is missing required sections: "
            f"{', '.join(missing)}. Use todo-crud.sh for writes."
        )

    duplicates = [h for h, pos in header_positions.items() if len(pos) > 1]
    if duplicates:
        _error(
            f"REFUSED TO WRITE: TODO.md has duplicate headers: "
            f"{', '.join(duplicates)}. File is malformed."
        )

    # --- 2: Correct top-level order ---
    first_positions = [header_positions[h][0] for h in REQUIRED_HEADERS]
    if first_positions != sorted(first_positions):
        _error(
            "REFUSED TO WRITE: TODO.md headers are in the wrong order. "
            f"Expected: {' → '.join(REQUIRED_HEADERS)}. Use todo-crud.sh."
        )

    # --- 4: Priority subsections: present, unique, and ordered ---
    active_start = header_positions["# ACTIVE TASKS"][0]
    history_start = header_positions["# HISTORY"][0]
    active_lines = lines[active_start:history_start]
    sub_positions = _find_anchored_headers(active_lines, REQUIRED_SUBSECTIONS)

    missing_subs = [s for s, pos in sub_positions.items() if not pos]
    if missing_subs:
        _error(
            f"REFUSED TO WRITE: TODO.md ACTIVE TASKS section is missing "
            f"subsections: {', '.join(missing_subs)}. Use todo-crud.sh."
        )

    dup_subs = [s for s, pos in sub_positions.items() if len(pos) > 1]
    if dup_subs:
        _error(
            f"REFUSED TO WRITE: TODO.md has duplicate priority subsections: "
            f"{', '.join(dup_subs)}. File is malformed."
        )

    sub_first = [sub_positions[s][0] for s in REQUIRED_SUBSECTIONS]
    if sub_first != sorted(sub_first):
        _error(
            "REFUSED TO WRITE: TODO.md priority subsections are in the wrong "
            f"order. Expected: {' → '.join(REQUIRED_SUBSECTIONS)}. Use todo-crud.sh."
        )

    # --- 5: Reject scaffold-only wipes ---
    # A valid TODO.md must contain at least one real artifact: a task line
    # (- [ ], - [x], - [/], - [-]) or a history date header (## YYYY-MM-DD).
    # Files with only headers, separators, comments, or arbitrary filler are
    # rejected.  This catches empty scaffolds, template files, and near-empty
    # overwrites that would destroy existing content.
    task_re = re.compile(r"^- \[[ x/\-]\]")
    date_header_re = re.compile(r"^## \d{4}-\d{2}-\d{2}")
    has_artifact = any(
        task_re.match(line.strip()) or date_header_re.match(line.strip())
        for line in lines
    )
    if not has_artifact:
        _error(
            "REFUSED TO WRITE: TODO.md contains no task lines (- [ ]/[x]/[/]/[-]) "
            "and no history date headers (## YYYY-MM-DD). This looks like an "
            "empty scaffold that would destroy existing content. Use todo-crud.sh."
        )


# ---------------------------------------------------------------------------
# Annihilation Detection — Layer 5 shadow-comparison gate
# ---------------------------------------------------------------------------
# Maintains a plain copy of TODO.md at SHADOW_DIR/TODO.md (distinct from the
# timestamped .bak rotation files).  Before each write, the incoming content
# is compared against the shadow to catch size wipeouts and bulk task drops.
# Escape hatch: delete the shadow file to bypass for one write (e.g. bulk archive).

SHADOW_TODO_FILENAME = "TODO.md"   # plain copy, not a timestamped .bak
ANNIHILATION_SIZE_RATIO = 0.40     # block if new content < 40% of shadow (>60% drop)
MAX_ACTIVE_TASK_DROP = 5           # block if active task count drops by more than this


def _shadow_todo_path() -> str:
    return os.path.join(SHADOW_DIR, SHADOW_TODO_FILENAME)


def _count_active_tasks(content: str) -> int:
    """Count open/in-progress tasks (- [ ] / - [/]) in the ACTIVE TASKS section."""
    active_section = content.split("# HISTORY")[0] if "# HISTORY" in content else content
    return len(re.findall(r"^- \[[ /]\]", active_section, re.MULTILINE))


SHADOW_STALE_SECONDS = 60  # Shadow older than TODO.md by this much → treat as stale


def _check_annihilation(new_content: str, todo_path: str) -> None:
    """Compare incoming content against shadow; block suspicious wipeouts.

    Three checks (all bypass-able by deleting the shadow file):
      1. Size: new content < 40% of shadow → blocked
      2. Task-zero: active tasks drop to 0 from >0 → blocked
      3. Large drop: active tasks drop by more than MAX_ACTIVE_TASK_DROP → blocked

    Cross-machine stale detection: if the shadow is older than the real TODO.md
    by more than SHADOW_STALE_SECONDS, the shadow was written on a different
    machine (TODO.md synced via OneDrive/Dropbox while shadow stayed local).
    In that case checks 2 & 3 are skipped — the size check (check 1) still
    runs as a last-resort catastrophic-wipeout guard.

    Soft failures (shadow unreadable, shadow is a directory): warn and allow.
    No shadow present: allow (first run) and create shadow afterwards.
    """
    shadow = _shadow_todo_path()
    if not os.path.exists(shadow):
        return  # First write — no baseline yet; shadow will be created after write

    # Attempt to read shadow; degrade gracefully on any error
    try:
        with open(shadow, "r") as f:
            shadow_content = f.read()
    except OSError as exc:
        print(
            f"WARNING: Cannot read shadow TODO.md for annihilation check: {exc}. "
            f"Proceeding without check.",
            file=sys.stderr,
        )
        return

    # Cross-machine stale detection: shadow predates the real TODO.md, meaning
    # work happened on another machine (OneDrive synced the file, shadow stayed local).
    # Skip count-based checks — the size check still catches catastrophic wipeouts.
    shadow_stale = False
    try:
        shadow_mtime = os.path.getmtime(shadow)
        todo_mtime = os.path.getmtime(todo_path)
        if shadow_mtime < todo_mtime - SHADOW_STALE_SECONDS:
            print(
                f"WARNING: Shadow is stale (shadow written {int(todo_mtime - shadow_mtime)}s "
                f"before TODO.md was last modified). This is normal after cross-machine sync. "
                f"Skipping active-task-count checks; shadow will be refreshed after write.",
                file=sys.stderr,
            )
            shadow_stale = True
    except OSError:
        pass  # If we can't stat, proceed with normal checks

    # Check 1: size drop (always runs — catches catastrophic wipeouts even on stale shadow)
    shadow_size = len(shadow_content.encode("utf-8"))
    new_size = len(new_content.encode("utf-8"))
    if shadow_size > 0 and new_size < shadow_size * ANNIHILATION_SIZE_RATIO:
        pct = int((1 - new_size / shadow_size) * 100)
        _error(
            f"REFUSED TO WRITE: new content is {pct}% smaller than the shadow backup "
            f"({new_size} bytes vs {shadow_size} bytes). This looks like an "
            f"annihilation attempt. Delete {shadow} to bypass if this shrink is intentional."
        )

    if shadow_stale:
        return  # Skip count checks — shadow baseline is from a different machine

    # Check 2 & 3: active task counts
    shadow_active = _count_active_tasks(shadow_content)
    new_active = _count_active_tasks(new_content)
    if shadow_active > 0 and new_active == 0:
        _error(
            f"REFUSED TO WRITE: All {shadow_active} active tasks would be deleted. "
            f"Delete {shadow} to bypass if this is intentional."
        )
    if shadow_active > 0 and (shadow_active - new_active) > MAX_ACTIVE_TASK_DROP:
        _error(
            f"REFUSED TO WRITE: Active task count would drop from {shadow_active} to "
            f"{new_active} (loss of {shadow_active - new_active} tasks exceeds limit of "
            f"{MAX_ACTIVE_TASK_DROP}). Delete {shadow} to bypass if this is intentional."
        )


def _update_shadow(content: str) -> None:
    """Write the just-committed content to the shadow file for future comparisons.

    Uses an atomic temp-file + os.replace() write so the shadow file's own
    mode (even 0o444) never blocks the update — os.replace() only requires
    the directory write bit, not the target file's write bit.

    On failure, exits non-zero instead of silently degrading.  Annihilation
    detection must stay active; the 2026-03-23 incident happened because a
    warn-and-skip path left the system unguarded.
    """
    shadow = _shadow_todo_path()
    os.makedirs(SHADOW_DIR, exist_ok=True)
    tmp = None
    try:
        fd, tmp = tempfile.mkstemp(dir=SHADOW_DIR, prefix="todo-shadow-", suffix=".tmp")
        # os.fdopen() takes ownership of fd and closes it on exit — do not call
        # os.close(fd) separately.
        with os.fdopen(fd, "w") as f:
            f.write(content)
        # fd is now closed; proceed with atomic promotion.
        os.chmod(tmp, 0o644)   # shadow must stay writable (unlike canonical TODO.md)
        os.replace(tmp, shadow)  # atomic; only needs dir write bit, not shadow's mode
        tmp = None
    except OSError as exc:
        if tmp is not None:
            try:
                os.remove(tmp)
            except OSError:
                pass
        print(
            f"ERROR: Cannot update shadow TODO.md ({shadow}): {exc}. "
            f"Aborting to preserve annihilation-detection integrity.",
            file=sys.stderr,
        )
        sys.exit(1)


def _clear_immutable(path: str) -> None:
    """Clear OS-level immutable flag (chflags/chattr) if present.

    macOS: chflags nouchg
    Linux: chattr -i (may require elevated privileges)
    Other: no-op (fall through to chmod)
    """
    try:
        if PLATFORM == "darwin":
            subprocess.run(["chflags", "nouchg", path],
                           capture_output=True, timeout=5, check=True)
        elif PLATFORM == "linux":
            subprocess.run(["chattr", "-i", path],
                           capture_output=True, timeout=5, check=True)
    except (subprocess.CalledProcessError, FileNotFoundError, subprocess.TimeoutExpired):
        pass  # Command not available or failed; fall through to chmod


def _set_immutable(path: str) -> None:
    """Set OS-level immutable flag (chflags/chattr) for strongest protection.

    macOS: chflags uchg → 'Operation not permitted' for ANY write attempt
    Linux: chattr +i → same effect (may require elevated privileges)
    Other: no-op (rely on chmod 444 alone)

    Agents' save-file and str-replace-editor CANNOT clear these flags.
    Only todo-engine.py knows how to temporarily lift immutability.
    """
    try:
        if PLATFORM == "darwin":
            subprocess.run(["chflags", "uchg", path],
                           capture_output=True, timeout=5, check=True)
        elif PLATFORM == "linux":
            subprocess.run(["chattr", "+i", path],
                           capture_output=True, timeout=5, check=True)
    except (subprocess.CalledProcessError, FileNotFoundError, subprocess.TimeoutExpired):
        pass  # Best-effort; chmod 444 is the fallback


def _unprotect_file(path: str) -> None:
    """Make TODO.md writable. Clears immutable flag, then chmod 644.

    Raises RuntimeError if chmod fails after clearing immutability — this
    means something is seriously wrong with the filesystem.
    """
    if not os.path.exists(path):
        return  # File doesn't exist yet; nothing to unprotect
    _clear_immutable(path)
    try:
        os.chmod(path, FILE_MODE_WRITABLE)
    except OSError as exc:
        raise RuntimeError(
            f"CRITICAL: Cannot chmod TODO.md for writing: {exc}. "
            f"The file is deliberately read-only and immutable. "
            f"Use todo-crud.sh which handles protection automatically. "
            f"NEVER write TODO.md directly or fall back to a different path."
        ) from exc


def _validate_canonical_path(path: str) -> None:
    """Refuse writes if path doesn't match resolved TODO_FILE_PATH.

    Prevents agents from writing to ~/.codex/TODO.md or other stray
    locations when the real path is elsewhere (e.g., OneDrive).

    Incident 2026-03-26: A sibling agent bypassed todo-crud.sh, hit
    chmod 444, and fell back to ~/.codex/TODO.md — creating a stray
    disconnected TODO file. This gate prevents that.
    """
    canonical = resolve_todo_path()
    real_canonical = os.path.realpath(canonical)
    real_path = os.path.realpath(path)
    if real_path != real_canonical:
        _error(
            f"REFUSED: Write target '{path}' does not match "
            f"TODO_FILE_PATH '{canonical}'. This looks like a stray write. "
            f"Use todo-crud.sh which resolves the correct path automatically. "
            f"NEVER fall back to a different path when the real path is unwritable "
            f"— the read-only permission is intentional protection."
        )


def _protect_file(path: str) -> None:
    """Make TODO.md read-only (0444) + immutable (chflags uchg / chattr +i).

    Two layers of protection:
    1. chmod 444 — blocks normal write attempts (Permission denied)
    2. chflags uchg — blocks ALL write attempts including chmod changes
       (Operation not permitted). Agent tools cannot clear this flag.

    Only todo-engine.py knows to call _clear_immutable() before _unprotect_file().
    """
    if not os.path.exists(path):
        return  # Nothing to protect
    # Clear any existing immutable flag first (idempotent re-protection)
    _clear_immutable(path)
    try:
        os.chmod(path, FILE_MODE_PROTECTED)
    except OSError as exc:
        raise RuntimeError(
            f"CRITICAL: Cannot protect TODO.md after write: {exc}. "
            f"File is LEFT WRITABLE — manual chmod 0444 needed."
        ) from exc
    _set_immutable(path)


def write_file(path: str, content: str) -> None:
    _validate_canonical_path(path)
    validate_structure(content)
    content = _normalize_whitespace(content)
    _check_annihilation(content, path)   # Layer 5: shadow-based wipeout detection
    _unprotect_file(path)
    tmp = None  # initialized before try so except can guard os.remove if mkstemp fails
    try:
        target_dir = os.path.dirname(os.path.abspath(path))
        tmp_fd, tmp = tempfile.mkstemp(dir=target_dir, prefix=".todo-write.tmp.")
        with os.fdopen(tmp_fd, "w") as f:
            f.write(content)
            f.flush()
            os.fsync(f.fileno())
        os.replace(tmp, path)
    except Exception:
        if tmp is not None:
            try:
                os.remove(tmp)
            except OSError:
                pass
        try:
            _protect_file(path)
        except RuntimeError as _pexc:
            print(f"[todo-engine] WARNING: could not re-protect after failed write: {_pexc}", file=sys.stderr)
        raise
    # Narrow the mkstemp 0600 window before _protect_file adds the immutable flag.
    os.chmod(path, FILE_MODE_PROTECTED)
    _update_shadow(content)   # update shadow before protect; stale shadow on protect
                              # failure would cause false wipeout detection next run
    _protect_file(path)       # write succeeded — protect is mandatory, surface errors


def find_section_end(content: str, section_re: re.Pattern) -> int:
    """Find the end of a priority section (line before next section header).

    Returns the character index where new content should be inserted
    (just before the next section/heading).

    Uses a tighter boundary pattern than the module-level RE_SECTION so that
    stray ``## Heading`` lines inside task bodies do not masquerade as section
    terminators and cause add/move to insert content in the wrong place.
    Only actual structure markers are recognised:
      - ``## P1`` / ``## P2`` / ``## P3``  (priority sub-sections)
      - ``# ACTIVE`` / ``# HISTORY`` / ``# DEFERRED`` / ``# METRICS``
      - ``---``  (section separator, alone on its line)
    """
    _RE_REAL_BOUNDARY = re.compile(
        r"^(?:## P[1-9]\b|# (?:ACTIVE|HISTORY|DEFERRED|METRICS)\b|---$)",
        re.MULTILINE,
    )

    m = section_re.search(content)
    if not m:
        return -1

    start = m.end()
    # Find next *real* section boundary (skips arbitrary ## headings in task bodies)
    rest = content[start:]
    next_match = _RE_REAL_BOUNDARY.search(rest)
    if next_match:
        insert_at = start + next_match.start()
    else:
        insert_at = len(content)

    # Back up past trailing whitespace to insert cleanly
    while insert_at > start and content[insert_at - 1] == "\n":
        insert_at -= 1
    return insert_at


def next_task_id(content: str, today: str = None) -> str:
    """Allocate the next task ID for today. Format: YYYYMMDD-NN."""
    if today is None:
        today = datetime.date.today().strftime("%Y%m%d")
    pat = re.compile(r"\[" + re.escape(today) + r"-(\d+)\]")
    nums = [int(m) for m in pat.findall(content)]
    next_n = max(nums) + 1 if nums else 1
    return f"{today}-{next_n:02d}"


def find_task(content: str, task_id: str):
    """Find a task block by ID. Returns (start, end) char indices or None.

    A task block spans from the task header line to (but not including) the
    next hard boundary: another task header (``- [``), a priority section
    marker (``## P``), or a top-level section header (``# ``).  Bare ``---``
    lines are NOT boundaries — they appear as markdown horizontal rules inside
    task bodies and must not truncate the block.  This "content-until-next-task"
    model is more robust than the old indentation-only approach, which silently
    truncated blocks the moment any un-indented line appeared (headers, rules,
    blank lines) — causing complete/move to strand body content in ACTIVE.
    """
    pat = re.compile(
        r"^- \[[ x/]\] \[" + re.escape(task_id) + r"\].*$", re.MULTILINE
    )
    m = pat.search(content)
    if not m:
        return None
    start = m.start()

    # Patterns that unconditionally end a task block.
    # Compiled here (not module-level) to keep their semantics self-contained.
    #
    # NOTE: "---" is intentionally excluded.  In the TODO.md format, "---"
    # appears as a section separator *between* top-level sections (# HISTORY,
    # # DEFERRED, etc.), which are already covered by the "# [A-Z]" branch.
    # Inside a task body, "---" is a valid markdown horizontal rule and must
    # NOT terminate the block; omitting it here is intentional.
    _RE_NEXT_TASK = re.compile(r"^- \[[ x/]\]", re.MULTILINE)
    _RE_SECTION_HDR = re.compile(r"^(?:## P[1-9]\b|# [A-Z])", re.MULTILINE)

    rest_start = m.end()
    rest = content[rest_start:]

    t_m = _RE_NEXT_TASK.search(rest)
    s_m = _RE_SECTION_HDR.search(rest)

    boundary = None
    if t_m is not None and (s_m is None or t_m.start() <= s_m.start()):
        boundary = t_m
    elif s_m is not None:
        boundary = s_m

    if boundary is not None:
        raw_end = rest_start + boundary.start()
    else:
        raw_end = len(content)

    # Strip trailing blank lines so the block ends cleanly before the gap.
    block = content[start:raw_end].rstrip("\n")
    end = start + len(block) + 1   # +1 to include exactly one trailing newline
    if end > len(content):
        end = len(content)
    return (start, end)


# ---------------------------------------------------------------------------
# Output Helpers
# ---------------------------------------------------------------------------

def _output(data: dict, json_mode: bool) -> None:
    if json_mode:
        print(json.dumps(data))
    else:
        for k, v in data.items():
            print(f"{k}={v}")


def _error(msg: str, code: int = 1) -> None:
    print(json.dumps({"error": msg}) if "--json" in sys.argv else f"ERROR: {msg}",
          file=sys.stderr)
    sys.exit(code)


# ---------------------------------------------------------------------------
# CRUD Operations
# ---------------------------------------------------------------------------

def cmd_add(args, todo_path: str, json_mode: bool) -> None:
    """Add a new task to the specified priority section."""
    content = read_file(todo_path)
    task_id = next_task_id(content)
    today = datetime.date.today().strftime("%Y-%m-%d")

    priority = args.priority.upper()
    if priority not in PRIORITY_MARKERS:
        _error(f"Invalid priority: {priority}. Use P1, P2, or P3.")

    # Build task text
    tags = f" {args.tags}" if args.tags else ""
    task_line = f"- [ ] [{task_id}] {args.description}{tags}"
    sub_lines = [f"  - Added: {today}"]
    if args.note:
        # Support multiline notes — split on real newlines and escaped \n
        for note_line in args.note.replace("\\n", "\n").split("\n"):
            if note_line.strip():
                sub_lines.append(f"  - {note_line.strip()}")

    task_block = "\n".join([task_line] + sub_lines)

    # Find insert point
    section_re = PRIORITY_MARKERS[priority]
    insert_at = find_section_end(content, section_re)
    if insert_at == -1:
        _error(f"Could not find {priority} section in TODO.md")

    # Insert
    new_content = content[:insert_at] + "\n\n" + task_block + "\n" + content[insert_at:]
    write_file(todo_path, new_content)

    _output({"status": "added", "id": task_id, "priority": priority,
             "description": args.description}, json_mode)


def cmd_complete(args, todo_path: str, json_mode: bool) -> None:
    """Move a task from ACTIVE to HISTORY."""
    content = read_file(todo_path)
    loc = find_task(content, args.id)
    if not loc:
        _error(f"Task {args.id} not found in TODO.md")

    start, end = loc
    task_text = content[start:end].rstrip("\n")

    # Remove from active
    content = content[:start] + content[end:]

    # Mark as done
    task_text = task_text.replace("- [ ]", "- [x]", 1)
    task_text = task_text.replace("- [/]", "- [x]", 1)

    # Add completion timestamp
    today = datetime.date.today().strftime("%Y-%m-%d")
    note_line = f"\n  - Done: {today}"
    if args.note:
        # Indent each line of multiline notes as a metadata bullet
        for part in args.note.replace("\\n", "\n").split("\n"):
            if part.strip():
                note_line += f"\n  - Progress: {part.strip()}"
    task_text += note_line

    # Find HISTORY section
    hist = RE_HISTORY.search(content)
    if not hist:
        _error("HISTORY section not found in TODO.md")

    # Find or create today's date subsection
    date_header = f"## {today}"
    date_pos = content.find(date_header, hist.end())

    if date_pos != -1:
        # Insert after date header line
        line_end = content.find("\n", date_pos)
        if line_end == -1:
            line_end = len(content)
        insert_at = line_end
        content = content[:insert_at] + "\n" + task_text + "\n" + content[insert_at:]
    else:
        # Create new date section after HISTORY header
        hist_line_end = content.find("\n", hist.start())
        if hist_line_end == -1:
            hist_line_end = len(content)
        content = (content[:hist_line_end] + "\n\n" + date_header +
                   "\n" + task_text + "\n" + content[hist_line_end:])

    write_file(todo_path, content)
    _output({"status": "completed", "id": args.id, "date": today}, json_mode)


def cmd_move(args, todo_path: str, json_mode: bool) -> None:
    """Move a task to a different priority section."""
    content = read_file(todo_path)
    loc = find_task(content, args.id)
    if not loc:
        _error(f"Task {args.id} not found in TODO.md")

    target = args.to.upper()
    if target not in PRIORITY_MARKERS:
        _error(f"Invalid target priority: {target}. Use P1, P2, or P3.")

    start, end = loc
    task_text = content[start:end].rstrip("\n")

    # Remove from current location
    content = content[:start] + content[end:]

    # Find target section insert point
    insert_at = find_section_end(content, PRIORITY_MARKERS[target])
    if insert_at == -1:
        _error(f"Could not find {target} section in TODO.md")

    content = content[:insert_at] + "\n\n" + task_text + "\n" + content[insert_at:]
    write_file(todo_path, content)
    _output({"status": "moved", "id": args.id, "to": target}, json_mode)


def cmd_list(args, todo_path: str, json_mode: bool) -> None:
    """List tasks, optionally filtered by priority or tag."""
    content = read_file(todo_path)
    tasks = []

    for m in RE_TASK.finditer(content):
        task_id = m.group(1)
        line_start = m.start()
        # Get the full line
        line_end = content.find("\n", line_start)
        if line_end == -1:
            line_end = len(content)
        line = content[line_start:line_end]

        # Determine priority by position
        priority = "unknown"
        for p, marker_re in PRIORITY_MARKERS.items():
            pm = marker_re.search(content)
            if pm and pm.start() < line_start:
                hist = RE_HISTORY.search(content)
                if not hist or line_start < hist.start():
                    priority = p

        # Check if it's in history/deferred
        hist = RE_HISTORY.search(content)
        deferred = RE_DEFERRED.search(content)
        if hist and line_start >= hist.start():
            if args.priority or args.tag:
                continue  # skip history in filtered views
            priority = "HISTORY"
        if deferred and line_start >= deferred.start():
            priority = "DEFERRED"

        # Filter
        if args.priority and priority != args.priority.upper():
            continue
        if args.tag and args.tag not in line:
            continue
        if not args.show_all and priority in ("HISTORY", "DEFERRED"):
            continue

        # Extract checkbox state
        state = "open"
        if "[x]" in line[:20]:
            state = "done"
        elif "[/]" in line[:20]:
            state = "in-progress"

        tasks.append({
            "id": task_id,
            "priority": priority,
            "state": state,
            "text": line.strip()
        })

    if json_mode:
        print(json.dumps({"tasks": tasks, "count": len(tasks)}))
    else:
        if not tasks:
            print("No matching tasks found.")
        for t in tasks:
            print(t["text"])


def cmd_next_id(args, todo_path: str, json_mode: bool) -> None:
    """Output the next available task ID for today."""
    content = read_file(todo_path)
    tid = next_task_id(content)
    _output({"next_id": tid}, json_mode)


def cmd_cat(args, todo_path: str, json_mode: bool) -> None:
    """Print TODO.md contents from the resolved path."""
    content = read_file(todo_path)
    if json_mode:
        _output({"path": todo_path, "content": content}, json_mode)
    else:
        print(content, end="")


def cmd_path(args, todo_path: str, json_mode: bool) -> None:
    """Print the resolved TODO.md path (bare path in text mode)."""
    if json_mode:
        _output({"path": todo_path}, json_mode)
    else:
        print(todo_path)


def cmd_defer(args, todo_path: str, json_mode: bool) -> None:
    """Move a task to DEFERRED section."""
    content = read_file(todo_path)
    loc = find_task(content, args.id)
    if not loc:
        _error(f"Task {args.id} not found in TODO.md")

    start, end = loc
    task_text = content[start:end].rstrip("\n")

    # Remove from current location
    content = content[:start] + content[end:]

    # Add deferred metadata
    today = datetime.date.today().strftime("%Y-%m-%d")
    task_text += f"\n  - Deferred: {today}"
    if args.reason:
        # Indent each line of multiline reasons as a metadata bullet
        for part in args.reason.replace("\\n", "\n").split("\n"):
            if part.strip():
                task_text += f"\n  - Reason: {part.strip()}"

    # Find DEFERRED section
    deferred = RE_DEFERRED.search(content)
    if not deferred:
        _error("DEFERRED section not found in TODO.md")

    # Insert after DEFERRED header
    line_end = content.find("\n", deferred.start())
    if line_end == -1:
        line_end = len(content)
    content = content[:line_end] + "\n\n" + task_text + "\n" + content[line_end:]

    write_file(todo_path, content)
    _output({"status": "deferred", "id": args.id, "reason": args.reason or ""}, json_mode)


# ---------------------------------------------------------------------------
# Multi-Agent Claim Operations
# ---------------------------------------------------------------------------

def _parse_claim_line(line: str):
    """Parse a Claimed: metadata line. Returns (timestamp_str, agent, ttl_min) or None."""
    m = RE_CLAIM.match(line)
    if m:
        return m.group(1), m.group(2), int(m.group(3))
    return None


def _find_claim_in_block(content: str, task_id: str):
    """Find claim metadata within a task block. Returns (claim_line_start, claim_line_end, ts, agent, ttl) or None."""
    loc = find_task(content, task_id)
    if not loc:
        return None
    start, end = loc
    block = content[start:end]
    for line in block.split("\n"):
        parsed = _parse_claim_line(line)
        if parsed:
            ts_str, agent, ttl = parsed
            # Find the line position in the full content
            line_start = content.find(line, start)
            line_end = line_start + len(line)
            # Include the trailing newline if present
            if line_end < len(content) and content[line_end] == "\n":
                line_end += 1
            return line_start, line_end, ts_str, agent, ttl
    return None


def _is_claim_expired(ts_str: str, ttl_min: int) -> bool:
    """Check if a claim timestamp + TTL has expired."""
    try:
        claimed_at = datetime.datetime.fromisoformat(ts_str)
    except ValueError:
        return True  # unparseable = expired
    now = datetime.datetime.now()
    return now > claimed_at + datetime.timedelta(minutes=ttl_min)


def _reap_expired(content: str) -> tuple:
    """Reap all expired claims. Returns (new_content, reaped_ids)."""
    reaped = []
    # Find all claimed tasks (in-progress with Claimed: metadata)
    for m in RE_TASK.finditer(content):
        task_id = m.group(1)
        line_start = m.start()
        line = content[line_start:content.find("\n", line_start)]
        if "[/]" not in line[:20]:
            continue
        claim = _find_claim_in_block(content, task_id)
        if not claim:
            continue
        _, _, ts_str, _, ttl = claim
        if _is_claim_expired(ts_str, ttl):
            reaped.append(task_id)
    # Process reaped tasks (re-read content each time since indices shift)
    for tid in reaped:
        claim = _find_claim_in_block(content, tid)
        if claim:
            cl_start, cl_end, _, _, _ = claim
            content = content[:cl_start] + content[cl_end:]
        # Revert [/] to [ ]
        loc = find_task(content, tid)
        if loc:
            start, end = loc
            block = content[start:end]
            content = content[:start] + block.replace("[/]", "[ ]", 1) + content[end:]
    return content, reaped


def cmd_claim(args, todo_path: str, json_mode: bool) -> None:
    """Claim a task for this agent with a TTL."""
    content = read_file(todo_path)

    # Auto-reap expired claims first
    content, _ = _reap_expired(content)

    loc = find_task(content, args.id)
    if not loc:
        _error(f"Task {args.id} not found in TODO.md")

    start, end = loc
    block = content[start:end]

    # Cannot claim completed tasks
    if "[x]" in block[:20]:
        _error(f"Task {args.id} is already completed")

    agent = args.agent
    ttl = args.ttl

    # Check existing claim
    existing = _find_claim_in_block(content, args.id)
    if existing:
        _, _, _, existing_agent, existing_ttl = existing
        if existing_agent == agent:
            # Same agent: refresh the timestamp
            cl_start, cl_end = existing[0], existing[1]
            content = content[:cl_start] + content[cl_end:]
        else:
            # Different agent, check if expired (already reaped above, so not expired)
            _error(f"Task {args.id} is claimed by {existing_agent} (not expired)")

    # Re-find task after potential claim line removal
    loc = find_task(content, args.id)
    if not loc:
        _error(f"Task {args.id} lost during claim processing")
    start, end = loc
    block = content[start:end]

    # Change [ ] to [/]
    block = block.replace("[ ]", "[/]", 1)

    # Add claim metadata
    now = datetime.datetime.now().strftime("%Y-%m-%dT%H:%M:%S")
    claim_line = f"  - Claimed: {now} by {agent} ttl={ttl}\n"
    # Insert claim line after the last metadata line
    block_rstrip = block.rstrip("\n")
    block = block_rstrip + "\n" + claim_line

    content = content[:start] + block + content[end:]
    write_file(todo_path, content)
    _output({"status": "claimed", "id": args.id, "agent": agent,
             "ttl": ttl}, json_mode)


def cmd_unclaim(args, todo_path: str, json_mode: bool) -> None:
    """Release a claim on a task."""
    content = read_file(todo_path)
    loc = find_task(content, args.id)
    if not loc:
        _error(f"Task {args.id} not found in TODO.md")

    # Remove claim metadata line
    claim = _find_claim_in_block(content, args.id)
    if claim:
        cl_start, cl_end, _, _, _ = claim
        content = content[:cl_start] + content[cl_end:]

    # Revert [/] to [ ]
    loc = find_task(content, args.id)
    if loc:
        start, end = loc
        block = content[start:end]
        content = content[:start] + block.replace("[/]", "[ ]", 1) + content[end:]

    write_file(todo_path, content)
    _output({"status": "unclaimed", "id": args.id}, json_mode)


def cmd_reap(args, todo_path: str, json_mode: bool) -> None:
    """Reap all expired claims, reverting tasks to open."""
    content = read_file(todo_path)
    content, reaped = _reap_expired(content)
    write_file(todo_path, content)
    _output({"status": "reaped", "reaped": len(reaped),
             "reaped_ids": reaped}, json_mode)



def _extract_task_title(line: str) -> str:
    """Extract task title, skipping the ID bracket and status markers."""
    # Line format: "- [/] <!-- id:ABC --> Some task title"
    # Skip everything up to and including the closing -->
    m = re.search(r"-->\s*(.+)$", line)
    if m:
        return m.group(1).strip()
    # Fallback: take everything after the last ']'
    m = re.search(r"\]\s*(.+)$", line)
    return m.group(1).strip() if m else ""


def cmd_list_claims(args, todo_path: str, json_mode: bool) -> None:
    """List all currently claimed tasks with metadata."""
    content = read_file(todo_path)
    claims = []
    now = datetime.datetime.now()
    for m in RE_TASK.finditer(content):
        task_id = m.group(1)
        line_start = m.start()
        line = content[line_start:content.find("\n", line_start)]
        if "[/]" not in line[:20]:
            continue
        title = _extract_task_title(line)
        claim = _find_claim_in_block(content, task_id)
        if not claim:
            claims.append({
                "id": task_id, "agent": "(none)", "ttl": 0,
                "claimed_at": "", "age_min": -1, "expired": False,
                "title": title, "orphaned": True
            })
            continue
        _, _, ts_str, agent, ttl = claim
        try:
            claimed_at = datetime.datetime.fromisoformat(ts_str)
            age_min = round((now - claimed_at).total_seconds() / 60, 1)
        except ValueError:
            age_min = -1
        expired = _is_claim_expired(ts_str, ttl)
        claims.append({
            "id": task_id, "agent": agent, "ttl": ttl,
            "claimed_at": ts_str, "age_min": age_min, "expired": expired,
            "title": title, "orphaned": False
        })

    result = {"status": "ok", "claims": claims, "total": len(claims),
              "expired": sum(1 for c in claims if c["expired"]),
              "orphaned": sum(1 for c in claims if c["orphaned"])}

    if json_mode:
        _output(result, True)
    else:
        # Human-readable output
        if not claims:
            print("No active claims.")
            return
        print(f"{'ID':<8} {'Agent':<20} {'Age':<10} {'Status':<10} Title")
        print("-" * 72)
        for c in claims:
            age = f"{c['age_min']}m" if c['age_min'] >= 0 else "???"
            if c['orphaned']:
                status = "ORPHANED"
            elif c['expired']:
                status = "EXPIRED"
            else:
                status = "active"
            print(f"{c['id']:<8} {c['agent']:<20} {age:<10} {status:<10} {c['title'][:30]}")


# ---------------------------------------------------------------------------
# Main — Argument Parsing
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(
        description="TODO.md CRUD engine — cross-platform task management"
    )
    parser.add_argument("--json", action="store_true", help="JSON output mode")
    sub = parser.add_subparsers(dest="command", required=True)

    # add
    p_add = sub.add_parser("add", help="Add a new task")
    p_add.add_argument("--priority", "-p", default="P2", help="P1, P2, or P3")
    p_add.add_argument("--description", "-d", required=True, help="Task description")
    p_add.add_argument("--tags", "-t", default="", help="Space-separated tags")
    p_add.add_argument("--note", "-n", default="", help="Additional note")

    # complete
    p_complete = sub.add_parser("complete", help="Mark a task done")
    p_complete.add_argument("--id", required=True, help="Task ID (YYYYMMDD-NN)")
    p_complete.add_argument("--note", "-n", default="", help="Completion note")

    # move
    p_move = sub.add_parser("move", help="Move task to different priority")
    p_move.add_argument("--id", required=True, help="Task ID")
    p_move.add_argument("--to", required=True, help="Target priority (P1/P2/P3)")

    # list
    p_list = sub.add_parser("list", help="List tasks")
    p_list.add_argument("--priority", "-p", default="", help="Filter by priority")
    p_list.add_argument("--tag", "-t", default="", help="Filter by tag")
    p_list.add_argument("--all", dest="show_all", action="store_true",
                        help="Include history and deferred")

    # next-id
    sub.add_parser("next-id", help="Get next available task ID")

    # defer
    p_defer = sub.add_parser("defer", help="Defer a task")
    p_defer.add_argument("--id", required=True, help="Task ID")
    p_defer.add_argument("--reason", "-r", default="", help="Reason for deferral")

    # claim
    p_claim = sub.add_parser("claim", help="Claim a task for this agent")
    p_claim.add_argument("--id", required=True, help="Task ID (YYYYMMDD-NN)")
    p_claim.add_argument("--agent", "-a", default=None,
                         help="Agent identifier (default: AGENT_ID env or hostname:ppid)")
    p_claim.add_argument("--ttl", type=int, default=DEFAULT_CLAIM_TTL,
                         help=f"Claim TTL in minutes (default: {DEFAULT_CLAIM_TTL})")

    # unclaim
    p_unclaim = sub.add_parser("unclaim", help="Release claim on a task")
    p_unclaim.add_argument("--id", required=True, help="Task ID")

    # reap
    sub.add_parser("reap", help="Reap all expired claims")

    # list-claims
    sub.add_parser("list-claims", help="List all claimed tasks with metadata")

    # cat — print TODO.md contents from resolved path
    sub.add_parser("cat", help="Print TODO.md contents (resolved path)")

    # path — print resolved path only
    sub.add_parser("path", help="Print resolved TODO.md path")

    args = parser.parse_args()
    json_mode = args.json

    # --- Resolve agent identity for claim ---
    if hasattr(args, "agent") and args.agent is None:
        agent_env = os.environ.get("AGENT_ID", "").strip()
        if agent_env:
            args.agent = agent_env
        else:
            hostname = os.uname().nodename.split(".")[0]
            args.agent = f"{hostname}:{os.getppid()}"

    # --- Resolve path ---
    todo_path = resolve_todo_path()

    # path command doesn't need the file to exist
    if args.command == "path":
        cmd_path(args, todo_path, json_mode)
        return

    ensure_file_exists(todo_path)

    # --- Enforce file protection (transition: lock down unprotected files) ---
    _protect_file(todo_path)

    # --- Read-only commands (no lock needed) ---
    if args.command in ("list", "next-id", "cat", "list-claims"):
        dispatch = {"list": cmd_list, "next-id": cmd_next_id, "cat": cmd_cat,
                     "list-claims": cmd_list_claims}
        dispatch[args.command](args, todo_path, json_mode)
        return

    # --- Write commands: lock → backup → operate → release ---
    if not acquire_lock(todo_path):
        _error("Could not acquire TODO lock. Another session may be writing. "
               "Try again or run: todo-lock.sh steal")

    try:
        backup(todo_path)
        dispatch = {
            "add": cmd_add,
            "complete": cmd_complete,
            "move": cmd_move,
            "defer": cmd_defer,
            "claim": cmd_claim,
            "unclaim": cmd_unclaim,
            "reap": cmd_reap,
        }
        dispatch[args.command](args, todo_path, json_mode)
    finally:
        release_lock(todo_path)


if __name__ == "__main__":
    main()

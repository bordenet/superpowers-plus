#!/usr/bin/env python3
"""checkpoint-engine.py — Cross-platform checkpoint CRUD engine.

Handles init, step, heartbeat, read, set-context, set-calls, cleanup-calls,
set-resume-prompt, generate-resume-prompt, lock, unlock, renew-lock operations
with atomic writes, fail-closed error handling, and advisory locking.

Schema v2. Python 3.6+. Mirrors todo-engine.py patterns.

Usage (typically called via checkpoint.sh wrapper):
    python3 checkpoint-engine.py init <workflow-id> <workflow-name> [--steps N]
    python3 checkpoint-engine.py step <workflow-id> --description "..." --result success
    python3 checkpoint-engine.py heartbeat <workflow-id> --mode thinking
    python3 checkpoint-engine.py read <workflow-id>
    python3 checkpoint-engine.py set-context <workflow-id> --key foo --value bar
    python3 checkpoint-engine.py set-calls <workflow-id> --calls '["id1","id2"]'
    python3 checkpoint-engine.py cleanup-calls <workflow-id>
    python3 checkpoint-engine.py set-resume-prompt <workflow-id> --prompt "..."
    python3 checkpoint-engine.py generate-resume-prompt <workflow-id>
    python3 checkpoint-engine.py lock <workflow-id> --owner <uuid> [--lease 120]
    python3 checkpoint-engine.py unlock <workflow-id> --owner <uuid>
    python3 checkpoint-engine.py renew <workflow-id> --owner <uuid> [--lease 120]
"""

import argparse
import json
import os
import sys
import time

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------
CHECKPOINT_DIR = os.path.expanduser(os.environ.get("CHECKPOINT_DIR", "~/.augment-checkpoints"))
SCHEMA_VERSION = 2

VALID_MODES = {
    "initializing", "thinking", "running_tool", "test_in_progress",
    "waiting_on_child", "waiting_on_external", "step_complete", "aborting"
}

# ---------------------------------------------------------------------------
# Error helper (mirrors todo-engine.py pattern)
# ---------------------------------------------------------------------------

def _error(msg, code=1):
    print("ERROR: {}".format(msg), file=sys.stderr)
    sys.exit(code)

# ---------------------------------------------------------------------------
# Path helpers
# ---------------------------------------------------------------------------

def _ensure_dir():
    os.makedirs(CHECKPOINT_DIR, exist_ok=True)

def _checkpoint_path(workflow_id):
    _ensure_dir()
    return os.path.join(CHECKPOINT_DIR, "{}.json".format(workflow_id))

def _lock_path(workflow_id):
    _ensure_dir()
    return os.path.join(CHECKPOINT_DIR, "{}.lock".format(workflow_id))

# ---------------------------------------------------------------------------
# Atomic I/O (mirrors todo-engine.py _atomic_write pattern)
# ---------------------------------------------------------------------------

def _atomic_write(filepath, data):
    """Write JSON to filepath atomically via tmp + rename. Validates JSON before commit."""
    tmp = filepath + ".tmp.{}".format(os.getpid())
    try:
        with open(tmp, "w") as f:
            json.dump(data, f, indent=2)
        # Validate before committing
        with open(tmp, "r") as f:
            json.load(f)
        os.rename(tmp, filepath)
    except Exception as exc:
        try:
            os.unlink(tmp)
        except OSError:
            pass
        _error("Atomic write failed for {}: {}".format(filepath, exc))

def _read_checkpoint(workflow_id):
    """Read and parse checkpoint JSON. Fail-closed on any error."""
    path = _checkpoint_path(workflow_id)
    if not os.path.isfile(path):
        _error("Checkpoint not found for workflow '{}' at {}".format(workflow_id, path))
    try:
        with open(path, "r") as f:
            return json.load(f)
    except (json.JSONDecodeError, IOError) as exc:
        _error("Cannot read checkpoint '{}': {}".format(workflow_id, exc))

# ---------------------------------------------------------------------------
# Commands
# ---------------------------------------------------------------------------

def cmd_init(args):
    path = _checkpoint_path(args.workflow_id)
    now = int(time.time())
    data = {
        "workflowId": args.workflow_id,
        "workflowName": args.workflow_name,
        "startedAtEpoch": now,
        "lastHeartbeatEpoch": now,
        "heartbeatMode": "initializing",
        "currentStep": 0,
        "totalSteps": args.steps,
        "completedSteps": [],
        "branchSha": "",
        "deployedSha": "",
        "activeCallIds": [],
        "resumePrompt": "",
        "context": {},
        "version": SCHEMA_VERSION,
    }
    _atomic_write(path, data)
    print("initialized: {} ({})".format(args.workflow_id, path))

def cmd_step(args):
    data = _read_checkpoint(args.workflow_id)
    now = int(time.time())
    data["currentStep"] = data.get("currentStep", 0) + 1
    data["lastHeartbeatEpoch"] = now
    data["heartbeatMode"] = "step_complete"
    data.setdefault("completedSteps", []).append({
        "step": data["currentStep"],
        "name": args.description,
        "result": args.result,
        "epochTs": now,
    })
    _atomic_write(_checkpoint_path(args.workflow_id), data)
    print("step {}: {} [{}]".format(data["currentStep"], args.description, args.result))

def cmd_heartbeat(args):
    if args.mode not in VALID_MODES:
        _error("Invalid heartbeat mode '{}'. Valid: {}".format(
            args.mode, ", ".join(sorted(VALID_MODES))))
    data = _read_checkpoint(args.workflow_id)
    data["lastHeartbeatEpoch"] = int(time.time())
    data["heartbeatMode"] = args.mode
    _atomic_write(_checkpoint_path(args.workflow_id), data)
    print("heartbeat: {} mode={}".format(args.workflow_id, args.mode))

def cmd_read(args):
    data = _read_checkpoint(args.workflow_id)
    print(json.dumps(data, indent=2))

def cmd_set_context(args):
    data = _read_checkpoint(args.workflow_id)
    data.setdefault("context", {})[args.key] = args.value
    _atomic_write(_checkpoint_path(args.workflow_id), data)
    print("context[{}] = {}".format(args.key, args.value))

def cmd_set_calls(args):
    try:
        call_ids = json.loads(args.calls)
    except json.JSONDecodeError as exc:
        _error("--calls must be valid JSON array: {}".format(exc))
    if not isinstance(call_ids, list):
        _error("--calls must be a JSON array")
    data = _read_checkpoint(args.workflow_id)
    data["activeCallIds"] = call_ids
    _atomic_write(_checkpoint_path(args.workflow_id), data)
    print("activeCallIds set: {}".format(call_ids))

def cmd_cleanup_calls(args):
    data = _read_checkpoint(args.workflow_id)
    calls = data.get("activeCallIds", [])
    for call_id in calls:
        print("orphaned-call: {}".format(call_id))
    data["activeCallIds"] = []
    _atomic_write(_checkpoint_path(args.workflow_id), data)
    print("cleanup-calls: cleared {} call(s)".format(len(calls)))

def cmd_set_resume_prompt(args):
    data = _read_checkpoint(args.workflow_id)
    data["resumePrompt"] = args.prompt
    _atomic_write(_checkpoint_path(args.workflow_id), data)
    print("resumePrompt set ({} chars)".format(len(args.prompt)))

def cmd_generate_resume_prompt(args):
    data = _read_checkpoint(args.workflow_id)
    path = _checkpoint_path(args.workflow_id)
    name = data.get("workflowName", args.workflow_id)
    wid = data.get("workflowId", args.workflow_id)
    current_step = data.get("currentStep", 0)
    total_steps = data.get("totalSteps", 0)
    mode = data.get("heartbeatMode", "unknown")
    branch = data.get("branchSha", "")
    completed = data.get("completedSteps", [])
    last_desc = completed[-1].get("name", "(none)") if completed else "(none)"
    completed_names = ", ".join(
        "{}: {}".format(s.get("step"), s.get("name", "")) for s in completed
    ) or "(none)"
    prompt = (
        "Resume workflow '{name}' ({wid}). Read checkpoint at {path}. "
        "Last completed step: {current}/{total} -- '{last_desc}'. "
        "Mode at last heartbeat: {mode}. Branch: {branch}. "
        "Completed steps: {completed}. "
        "Next action: continue from step {next_step}."
    ).format(
        name=name, wid=wid, path=path,
        current=current_step, total=total_steps, last_desc=last_desc,
        mode=mode, branch=branch, completed=completed_names,
        next_step=current_step + 1,
    )
    data["resumePrompt"] = prompt
    _atomic_write(path, data)
    print(prompt)

# ---------------------------------------------------------------------------
# Lock / Unlock / Renew
# ---------------------------------------------------------------------------

def cmd_lock(args):
    lock_path = _lock_path(args.workflow_id)
    now = int(time.time())
    expiry = now + args.lease
    if os.path.isfile(lock_path):
        try:
            with open(lock_path, "r") as f:
                existing = json.load(f)
            existing_expiry = existing.get("expiryEpoch", 0)
            if existing_expiry > now:
                _error(
                    "Workflow '{}' is locked by owner '{}' until epoch {} ({}s remaining). "
                    "Fencing violation prevented.".format(
                        args.workflow_id,
                        existing.get("owner", "unknown"),
                        existing_expiry,
                        existing_expiry - now,
                    )
                )
            else:
                print(
                    "WARNING: Overriding expired lock (was owned by '{}')".format(
                        existing.get("owner", "unknown")
                    ),
                    file=sys.stderr,
                )
        except (json.JSONDecodeError, IOError):
            print("WARNING: Stale/corrupt lock file, overriding.", file=sys.stderr)
    lock_data = {
        "owner": args.owner,
        "claimedEpoch": now,
        "expiryEpoch": expiry,
    }
    _atomic_write(lock_path, lock_data)
    print("locked: {} owner={} expiry={}".format(args.workflow_id, args.owner, expiry))

def cmd_unlock(args):
    lock_path = _lock_path(args.workflow_id)
    if not os.path.isfile(lock_path):
        _error("No lock file found for workflow '{}'".format(args.workflow_id))
    try:
        with open(lock_path, "r") as f:
            existing = json.load(f)
    except (json.JSONDecodeError, IOError) as exc:
        _error("Cannot read lock file: {}".format(exc))
    if existing.get("owner") != args.owner:
        _error(
            "Fencing violation: lock owned by '{}', cannot unlock with owner '{}'".format(
                existing.get("owner", "unknown"), args.owner
            )
        )
    os.unlink(lock_path)
    print("unlocked: {}".format(args.workflow_id))

def cmd_renew(args):
    lock_path = _lock_path(args.workflow_id)
    if not os.path.isfile(lock_path):
        _error("No lock file found for workflow '{}'".format(args.workflow_id))
    try:
        with open(lock_path, "r") as f:
            existing = json.load(f)
    except (json.JSONDecodeError, IOError) as exc:
        _error("Cannot read lock file: {}".format(exc))
    if existing.get("owner") != args.owner:
        _error(
            "Fencing violation: lock owned by '{}', cannot renew with owner '{}'".format(
                existing.get("owner", "unknown"), args.owner
            )
        )
    now = int(time.time())
    existing["expiryEpoch"] = now + args.lease
    _atomic_write(lock_path, existing)
    print("renewed: {} owner={} new-expiry={}".format(
        args.workflow_id, args.owner, existing["expiryEpoch"]))

# ---------------------------------------------------------------------------
# Main — Argument Parsing
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(
        description="Checkpoint CRUD engine — workflow resilience"
    )
    sub = parser.add_subparsers(dest="command", required=True)

    p_init = sub.add_parser("init", help="Create new checkpoint")
    p_init.add_argument("workflow_id", help="Unique workflow identifier")
    p_init.add_argument("workflow_name", help="Human-readable workflow name")
    p_init.add_argument("--steps", type=int, default=0, help="Total expected steps")

    p_step = sub.add_parser("step", help="Record a completed step")
    p_step.add_argument("workflow_id")
    p_step.add_argument("--description", "-d", required=True, help="Step description")
    p_step.add_argument("--result", "-r", required=True,
                        choices=["success", "failure", "skipped"], help="Step result")

    p_hb = sub.add_parser("heartbeat", help="Update heartbeat timestamp and mode")
    p_hb.add_argument("workflow_id")
    p_hb.add_argument("--mode", "-m", required=True, help="Heartbeat mode")

    p_read = sub.add_parser("read", help="Print checkpoint JSON")
    p_read.add_argument("workflow_id")

    p_ctx = sub.add_parser("set-context", help="Set context key-value")
    p_ctx.add_argument("workflow_id")
    p_ctx.add_argument("--key", "-k", required=True)
    p_ctx.add_argument("--value", "-v", required=True)

    p_calls = sub.add_parser("set-calls", help="Set active call IDs")
    p_calls.add_argument("workflow_id")
    p_calls.add_argument("--calls", required=True, help="JSON array of call IDs")

    p_cleanup = sub.add_parser("cleanup-calls", help="Print and clear active call IDs")
    p_cleanup.add_argument("workflow_id")

    p_srp = sub.add_parser("set-resume-prompt", help="Set resume prompt text")
    p_srp.add_argument("workflow_id")
    p_srp.add_argument("--prompt", "-p", required=True)

    p_grp = sub.add_parser("generate-resume-prompt", help="Auto-generate resume prompt")
    p_grp.add_argument("workflow_id")

    p_lock = sub.add_parser("lock", help="Acquire advisory lock")
    p_lock.add_argument("workflow_id")
    p_lock.add_argument("--owner", required=True, help="Owner UUID")
    p_lock.add_argument("--lease", type=int, default=120, help="Lease duration in seconds")

    p_unlock = sub.add_parser("unlock", help="Release advisory lock")
    p_unlock.add_argument("workflow_id")
    p_unlock.add_argument("--owner", required=True, help="Owner UUID (must match)")

    p_renew = sub.add_parser("renew", help="Renew advisory lock lease")
    p_renew.add_argument("workflow_id")
    p_renew.add_argument("--owner", required=True, help="Owner UUID (must match)")
    p_renew.add_argument("--lease", type=int, default=120, help="New lease in seconds")

    args = parser.parse_args()

    dispatch = {
        "init": cmd_init,
        "step": cmd_step,
        "heartbeat": cmd_heartbeat,
        "read": cmd_read,
        "set-context": cmd_set_context,
        "set-calls": cmd_set_calls,
        "cleanup-calls": cmd_cleanup_calls,
        "set-resume-prompt": cmd_set_resume_prompt,
        "generate-resume-prompt": cmd_generate_resume_prompt,
        "lock": cmd_lock,
        "unlock": cmd_unlock,
        "renew": cmd_renew,
    }
    dispatch[args.command](args)


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Investigation State CRUD engine for superpowers-plus.

Manages JSON investigation files in ~/.superpowers/investigations/.
Called by investigation-crud.sh — not meant to be run directly.
"""
import json
import os
import re
import shutil
import sys
import time
import uuid
from datetime import datetime, timezone
from pathlib import Path

INVESTIGATIONS_DIR = Path.home() / ".superpowers" / "investigations"
LOCK_DIR = INVESTIGATIONS_DIR / ".lock"
LOCK_TTL = 120
LOCK_TIMEOUT = 8
VALID_STATUSES = {"active", "paused", "resolved", "abandoned"}
VALID_VERDICTS = {"confirmed", "rejected", "inconclusive"}
VALID_RESOLUTION_TYPES = {"fix-needed", "no-fix-needed", "external"}
UUID_RE = re.compile(r"^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$")

REQUIRED_KEYS = {"id", "status", "title", "hypotheses", "eliminated"}


def _error(msg):
    print(f"ERROR: {msg}", file=sys.stderr)
    sys.exit(1)


def now_utc():
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def validate_id(investigation_id):
    """Reject any ID that is not a valid UUID. Prevents path traversal."""
    if not UUID_RE.match(investigation_id):
        _error(f"Invalid investigation ID '{investigation_id}'. Must be a UUID.")


def ensure_dir():
    INVESTIGATIONS_DIR.mkdir(parents=True, exist_ok=True)
    gitignore = INVESTIGATIONS_DIR / ".gitignore"
    if not gitignore.exists():
        gitignore.write_text("*.json\n")


# --- Advisory locking (mkdir-based, compatible with todo-engine pattern) ---

def _lock_meta():
    return LOCK_DIR / "lock.json"


def _lock_age():
    meta = _lock_meta()
    if meta.is_file():
        try:
            with open(meta) as f:
                data = json.load(f)
            return int(time.time()) - data.get("epoch", 0)
        except (json.JSONDecodeError, KeyError, ValueError):
            return 999999
    if LOCK_DIR.is_dir():
        return 999999
    return 0


def acquire_lock():
    deadline = time.time() + LOCK_TIMEOUT
    hostname = os.uname().nodename.split(".")[0]
    pid = os.getppid()
    while True:
        try:
            LOCK_DIR.mkdir(parents=True)
            meta = {"hostname": hostname, "pid": pid,
                    "epoch": int(time.time()), "agent": "investigation-engine"}
            tmp = _lock_meta().with_suffix(f".tmp.{os.getpid()}")
            with open(tmp, "w") as f:
                json.dump(meta, f)
            os.replace(str(tmp), str(_lock_meta()))
            return True
        except FileExistsError:
            age = _lock_age()
            if age > LOCK_TTL:
                shutil.rmtree(str(LOCK_DIR), ignore_errors=True)
                continue
            if time.time() >= deadline:
                return False
            time.sleep(1)


def release_lock():
    if LOCK_DIR.is_dir():
        shutil.rmtree(str(LOCK_DIR), ignore_errors=True)


def backup(inv_id):
    """Create backup before write. Returns backup path or None."""
    src = INVESTIGATIONS_DIR / f"{inv_id}.json"
    if src.exists():
        ts = datetime.now().strftime("%Y%m%d-%H%M%S")
        bak = INVESTIGATIONS_DIR / f"{inv_id}.{ts}.bak"
        shutil.copy2(str(src), str(bak))
        return str(bak)
    return None


# --- Core I/O ---

def validate_schema(data, path_hint=""):
    """Basic schema check. Fails hard on missing required keys."""
    missing = REQUIRED_KEYS - set(data.keys())
    if missing:
        _error(f"Corrupt investigation file{path_hint}: missing keys {missing}")
    if not isinstance(data.get("hypotheses"), list):
        _error(f"Corrupt investigation file{path_hint}: 'hypotheses' must be a list")
    if not isinstance(data.get("eliminated"), list):
        _error(f"Corrupt investigation file{path_hint}: 'eliminated' must be a list")


def load(investigation_id):
    validate_id(investigation_id)
    path = INVESTIGATIONS_DIR / f"{investigation_id}.json"
    if not path.exists():
        _error(f"Investigation {investigation_id} not found")
    try:
        with open(path) as f:
            data = json.load(f)
    except json.JSONDecodeError as e:
        _error(f"Corrupt JSON in {path.name}: {e}")
    validate_schema(data, f" ({path.name})")
    return data


def save(data):
    ensure_dir()
    inv_id = data["id"]
    validate_id(inv_id)
    data["updated"] = now_utc()
    tmp = INVESTIGATIONS_DIR / f"{inv_id}.tmp.{os.getpid()}.json"
    final = INVESTIGATIONS_DIR / f"{inv_id}.json"
    with open(tmp, "w") as f:
        json.dump(data, f, indent=2)
        f.write("\n")
    os.replace(str(tmp), str(final))


def cmd_create(args):
    """create --title TITLE [--observed OBS] [--expected EXP] [--reproduction REP]"""
    title = get_required(args, "--title")
    inv_id = str(uuid.uuid4())
    data = {
        "id": inv_id,
        "created": now_utc(),
        "updated": now_utc(),
        "status": "active",
        "title": title,
        "symptoms": {
            "observed": get_opt(args, "--observed", ""),
            "expected": get_opt(args, "--expected", ""),
            "reproduction": get_opt(args, "--reproduction", ""),
        },
        "hypotheses": [],
        "eliminated": [],
        "currentTheory": None,
        "resolution": None,
        "nextSteps": [],
        "toolsConsulted": [],
        "relatedTodos": [],
        "relatedTickets": [],
    }
    save(data)
    short_id = inv_id[:8]
    print(json.dumps({"id": inv_id, "short_id": short_id, "title": title, "status": "active"}))


def cmd_list(args):
    """list [--status STATUS] [--stale]"""
    ensure_dir()
    status_filter = get_opt(args, "--status", None)
    stale = "--stale" in args
    results = []
    for f in sorted(INVESTIGATIONS_DIR.glob("*.json")):
        if ".tmp." in f.name or f.suffix == ".bak":
            continue
        try:
            with open(f) as fh:
                d = json.load(fh)
        except (json.JSONDecodeError, OSError) as e:
            print(f"WARNING: Skipping corrupt file {f.name}: {e}", file=sys.stderr)
            continue
        if status_filter and d.get("status") != status_filter:
            continue
        entry = {
            "id": d.get("id", f.stem),
            "short_id": d.get("id", f.stem)[:8],
            "title": d.get("title", ""),
            "status": d.get("status", ""),
            "updated": d.get("updated", ""),
            "hypotheses": len(d.get("hypotheses", [])),
        }
        if stale:
            updated = d.get("updated", "")
            try:
                ts = datetime.fromisoformat(updated.replace("Z", "+00:00"))
                age_days = (datetime.now(timezone.utc) - ts).days
                if age_days < 7:
                    continue
                entry["age_days"] = age_days
            except (ValueError, TypeError):
                entry["age_days"] = -1
        results.append(entry)
    print(json.dumps(results, indent=2))


def cmd_show(args):
    """show --id ID"""
    inv_id = get_required(args, "--id")
    data = load(inv_id)
    print(json.dumps(data, indent=2))


def cmd_add_hypothesis(args):
    """add-hypothesis --id ID --text TEXT"""
    inv_id = get_required(args, "--id")
    text = get_required(args, "--text")
    data = load(inv_id)
    next_id = max((h["id"] for h in data["hypotheses"]), default=0) + 1
    data["hypotheses"].append({
        "id": next_id,
        "text": text,
        "evidence": [],
        "verdict": None,
        "verdict_reason": None,
    })
    if data["currentTheory"] is None:
        data["currentTheory"] = next_id
    save(data)
    print(json.dumps({"hypothesis_id": next_id, "text": text}))


def cmd_add_evidence(args):
    """add-evidence --id ID --hypothesis HYP_ID --source SRC --finding FINDING"""
    inv_id = get_required(args, "--id")
    hyp_id = _parse_int(get_required(args, "--hypothesis"), "--hypothesis")
    source = get_required(args, "--source")
    finding = get_required(args, "--finding")
    data = load(inv_id)
    hyp = _find_hypothesis(data, hyp_id)
    hyp["evidence"].append({"source": source, "finding": finding, "timestamp": now_utc()})
    if source not in data.get("toolsConsulted", []):
        data.setdefault("toolsConsulted", []).append(source)
    save(data)
    print(json.dumps({"added": True, "hypothesis_id": hyp_id, "source": source}))


def cmd_set_verdict(args):
    """set-verdict --id ID --hypothesis HYP_ID --verdict VERDICT [--reason REASON]"""
    inv_id = get_required(args, "--id")
    hyp_id = _parse_int(get_required(args, "--hypothesis"), "--hypothesis")
    verdict = get_required(args, "--verdict")
    if verdict not in VALID_VERDICTS:
        _error(f"Invalid verdict '{verdict}'. Use: {', '.join(sorted(VALID_VERDICTS))}")
    reason = get_opt(args, "--reason", None)
    data = load(inv_id)
    hyp = _find_hypothesis(data, hyp_id)
    hyp["verdict"] = verdict
    hyp["verdict_reason"] = reason
    if verdict == "rejected" and data.get("currentTheory") == hyp_id:
        data["currentTheory"] = None
    save(data)
    print(json.dumps({"hypothesis_id": hyp_id, "verdict": verdict}))


def cmd_add_eliminated(args):
    """add-eliminated --id ID --approach APPROACH --reason REASON"""
    inv_id = get_required(args, "--id")
    approach = get_required(args, "--approach")
    reason = get_required(args, "--reason")
    data = load(inv_id)
    data["eliminated"].append({"approach": approach, "reason": reason, "timestamp": now_utc()})
    save(data)
    print(json.dumps({"added": True, "approach": approach}))


def cmd_set_status(args):
    """set-status --id ID --status STATUS [--resolution-type TYPE] [--summary TEXT] [--reason TEXT]"""
    inv_id = get_required(args, "--id")
    new_status = get_required(args, "--status")
    if new_status not in VALID_STATUSES:
        _error(f"Invalid status '{new_status}'. Use: {', '.join(sorted(VALID_STATUSES))}")
    data = load(inv_id)
    old_status = data["status"]
    valid_transitions = {
        "active": {"paused", "resolved", "abandoned"},
        "paused": {"active"},
        "resolved": set(),
        "abandoned": set(),
    }
    if new_status not in valid_transitions.get(old_status, set()):
        _error(f"Cannot transition from '{old_status}' to '{new_status}'")
    data["status"] = new_status
    if new_status == "resolved":
        res_type = get_opt(args, "--resolution-type", "no-fix-needed")
        if res_type not in VALID_RESOLUTION_TYPES:
            _error(f"Invalid resolution type '{res_type}'")
        summary = get_opt(args, "--summary", "")
        short_id = inv_id[:8]
        fix_todo = f"#investigation-{short_id}" if res_type == "fix-needed" else None
        data["resolution"] = {"type": res_type, "summary": summary, "fixTodo": fix_todo}
        if fix_todo and fix_todo not in data.get("relatedTodos", []):
            data.setdefault("relatedTodos", []).append(fix_todo)
    elif new_status == "abandoned":
        reason = get_opt(args, "--reason", None)
        data["resolution"] = {"type": "abandoned", "summary": reason or "", "fixTodo": None}
    save(data)
    result = {"id": inv_id, "old_status": old_status, "new_status": new_status}
    if new_status == "resolved" and data.get("resolution", {}).get("fixTodo"):
        result["fix_todo"] = data["resolution"]["fixTodo"]
    print(json.dumps(result))


def cmd_export(args):
    """export --id ID"""
    inv_id = get_required(args, "--id")
    data = load(inv_id)
    lines = []
    lines.append(f"# Investigation: {data['title']}")
    lines.append("")
    lines.append(f"**ID:** {data['id']} | **Status:** {data['status']} | **Started:** {data['created']} | **Updated:** {data['updated']}")
    lines.append("")
    s = data.get("symptoms", {})
    lines.append("## Symptoms")
    lines.append(f"- **Observed:** {s.get('observed', '')}")
    lines.append(f"- **Expected:** {s.get('expected', '')}")
    lines.append(f"- **Reproduction:** {s.get('reproduction', '')}")
    lines.append("")
    lines.append("## Hypotheses")
    lines.append("")
    for h in data.get("hypotheses", []):
        v = (h.get("verdict") or "ACTIVE").upper()
        suffix = " ← CURRENT THEORY" if data.get("currentTheory") == h["id"] else ""
        lines.append(f"### H{h['id']}: {h['text']} — {v}{suffix}")
        for e in h.get("evidence", []):
            lines.append(f"- {e['source']} — {e['finding']} ({e.get('timestamp', '')})")
        if h.get("verdict_reason"):
            lines.append(f"- Verdict: {h['verdict_reason']}")
        if not h.get("evidence") and not h.get("verdict_reason"):
            lines.append("- (no evidence yet)")
        lines.append("")
    elim = data.get("eliminated", [])
    if elim:
        lines.append("## Eliminated Approaches")
        for i, e in enumerate(elim, 1):
            lines.append(f"{i}. {e['approach']} — {e['reason']} ({e.get('timestamp', '')})")
        lines.append("")
    ns = data.get("nextSteps", [])
    if ns:
        lines.append("## Next Steps")
        for i, step in enumerate(ns, 1):
            lines.append(f"{i}. {step}")
        lines.append("")
    tc = data.get("toolsConsulted", [])
    if tc:
        lines.append("## Tools Consulted")
        lines.append(", ".join(tc))
        lines.append("")
    todos = data.get("relatedTodos", [])
    tickets = data.get("relatedTickets", [])
    if todos or tickets:
        lines.append("## Related")
        if todos:
            lines.append(f"- TODOs: {', '.join(todos)}")
        if tickets:
            lines.append(f"- Tickets: {', '.join(tickets)}")
        lines.append("")
    res = data.get("resolution")
    if res:
        lines.append("## Resolution")
        lines.append(f"- **Type:** {res.get('type', '')}")
        lines.append(f"- **Summary:** {res.get('summary', '')}")
        if res.get("fixTodo"):
            lines.append(f"- **Fix TODO:** {res['fixTodo']}")
        lines.append("")
    print("\n".join(lines))


def cmd_update(args):
    """update --id ID [--next-steps 'step1|step2'] [--current-theory N] [--add-ticket T]"""
    inv_id = get_required(args, "--id")
    data = load(inv_id)
    ns = get_opt(args, "--next-steps", None)
    if ns is not None:
        data["nextSteps"] = [s.strip() for s in ns.split("|") if s.strip()]
    ct = get_opt(args, "--current-theory", None)
    if ct is not None:
        if ct == "null":
            data["currentTheory"] = None
        else:
            ct_int = _parse_int(ct, "--current-theory")
            hyp_ids = {h["id"] for h in data.get("hypotheses", [])}
            if ct_int not in hyp_ids:
                _error(f"Hypothesis {ct_int} does not exist. Available: {sorted(hyp_ids)}")
            data["currentTheory"] = ct_int
    ticket = get_opt(args, "--add-ticket", None)
    if ticket:
        data.setdefault("relatedTickets", [])
        if ticket not in data["relatedTickets"]:
            data["relatedTickets"].append(ticket)
    save(data)
    print(json.dumps({"updated": True, "id": inv_id}))


# --- Argument helpers ---

def get_required(args, flag):
    try:
        idx = args.index(flag)
        return args[idx + 1]
    except (ValueError, IndexError):
        _error(f"{flag} is required")


def get_opt(args, flag, default):
    try:
        idx = args.index(flag)
        return args[idx + 1]
    except (ValueError, IndexError):
        return default


def _parse_int(value, flag):
    """Parse an integer from a CLI arg. Exits with clean error on failure."""
    try:
        return int(value)
    except (ValueError, TypeError):
        _error(f"{flag} must be an integer, got '{value}'")


def _find_hypothesis(data, hyp_id):
    """Find a hypothesis by ID. Exits with clean error if not found."""
    hyp = next((h for h in data.get("hypotheses", []) if h.get("id") == hyp_id), None)
    if not hyp:
        _error(f"Hypothesis {hyp_id} not found")
    return hyp


# --- Dispatch ---

READ_COMMANDS = {"list", "show", "export"}

COMMANDS = {
    "create": cmd_create,
    "list": cmd_list,
    "show": cmd_show,
    "add-hypothesis": cmd_add_hypothesis,
    "add-evidence": cmd_add_evidence,
    "set-verdict": cmd_set_verdict,
    "add-eliminated": cmd_add_eliminated,
    "set-status": cmd_set_status,
    "export": cmd_export,
    "update": cmd_update,
}

if __name__ == "__main__":
    if len(sys.argv) < 2 or sys.argv[1] in ("-h", "--help", "help"):
        print("Usage: investigation-engine.py <command> [options]")
        print(f"Commands: {', '.join(sorted(COMMANDS))}")
        sys.exit(0)
    cmd_name = sys.argv[1]
    if cmd_name not in COMMANDS:
        _error(f"Unknown command '{cmd_name}'. Available: {', '.join(sorted(COMMANDS))}")

    # Read-only commands: no lock needed
    if cmd_name in READ_COMMANDS:
        COMMANDS[cmd_name](sys.argv[2:])
    else:
        # Write commands: lock → backup → operate → release
        if not acquire_lock():
            _error("Could not acquire lock. Another session may be writing. "
                   "Try again or remove ~/.superpowers/investigations/.lock/")
        try:
            # Backup for mutating commands that have an --id
            if "--id" in sys.argv:
                try:
                    id_idx = sys.argv.index("--id")
                    backup(sys.argv[id_idx + 1])
                except (ValueError, IndexError):
                    pass
            COMMANDS[cmd_name](sys.argv[2:])
        finally:
            release_lock()

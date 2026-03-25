#!/usr/bin/env python3
"""Investigation State CRUD engine for superpowers-plus.

Manages JSON investigation files in ~/.superpowers/investigations/.
Called by investigation-crud.sh — not meant to be run directly.
"""
import json
import os
import sys
import uuid
from datetime import datetime, timezone
from pathlib import Path

INVESTIGATIONS_DIR = Path.home() / ".superpowers" / "investigations"
VALID_STATUSES = {"active", "paused", "resolved", "abandoned"}
VALID_VERDICTS = {None, "confirmed", "rejected", "inconclusive"}
VALID_RESOLUTION_TYPES = {"fix-needed", "no-fix-needed", "external"}


def now_utc():
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def ensure_dir():
    INVESTIGATIONS_DIR.mkdir(parents=True, exist_ok=True)
    gitignore = INVESTIGATIONS_DIR / ".gitignore"
    if not gitignore.exists():
        gitignore.write_text("*.json\n")


def load(investigation_id):
    path = INVESTIGATIONS_DIR / f"{investigation_id}.json"
    if not path.exists():
        print(f"ERROR: Investigation {investigation_id} not found", file=sys.stderr)
        sys.exit(1)
    with open(path) as f:
        return json.load(f)


def save(data):
    ensure_dir()
    inv_id = data["id"]
    data["updated"] = now_utc()
    tmp = INVESTIGATIONS_DIR / f"{inv_id}.tmp.json"
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
        if f.name.endswith(".tmp.json"):
            continue
        try:
            with open(f) as fh:
                d = json.load(fh)
        except (json.JSONDecodeError, OSError):
            continue
        if status_filter and d.get("status") != status_filter:
            continue
        if stale:
            updated = d.get("updated", "")
            try:
                ts = datetime.fromisoformat(updated.replace("Z", "+00:00"))
                age_days = (datetime.now(timezone.utc) - ts).days
                if age_days < 7:
                    continue
                d["_age_days"] = age_days
            except (ValueError, TypeError):
                d["_age_days"] = -1
        results.append({
            "id": d.get("id", f.stem),
            "short_id": d.get("id", f.stem)[:8],
            "title": d.get("title", ""),
            "status": d.get("status", ""),
            "updated": d.get("updated", ""),
            "hypotheses": len(d.get("hypotheses", [])),
            **({" _age_days": d["_age_days"]} if "_age_days" in d else {}),
        })
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
    hyp_id = int(get_required(args, "--hypothesis"))
    source = get_required(args, "--source")
    finding = get_required(args, "--finding")
    data = load(inv_id)
    hyp = next((h for h in data["hypotheses"] if h["id"] == hyp_id), None)
    if not hyp:
        print(f"ERROR: Hypothesis {hyp_id} not found", file=sys.stderr)
        sys.exit(1)
    hyp["evidence"].append({"source": source, "finding": finding, "timestamp": now_utc()})
    if source not in data["toolsConsulted"]:
        data["toolsConsulted"].append(source)
    save(data)
    print(json.dumps({"added": True, "hypothesis_id": hyp_id, "source": source}))


def cmd_set_verdict(args):
    """set-verdict --id ID --hypothesis HYP_ID --verdict VERDICT [--reason REASON]"""
    inv_id = get_required(args, "--id")
    hyp_id = int(get_required(args, "--hypothesis"))
    verdict = get_required(args, "--verdict")
    if verdict not in ("confirmed", "rejected", "inconclusive"):
        print(f"ERROR: Invalid verdict '{verdict}'. Use: confirmed, rejected, inconclusive", file=sys.stderr)
        sys.exit(1)
    reason = get_opt(args, "--reason", None)
    data = load(inv_id)
    hyp = next((h for h in data["hypotheses"] if h["id"] == hyp_id), None)
    if not hyp:
        print(f"ERROR: Hypothesis {hyp_id} not found", file=sys.stderr)
        sys.exit(1)
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
    """set-status --id ID --status STATUS [--resolution-type TYPE] [--summary TEXT]"""
    inv_id = get_required(args, "--id")
    new_status = get_required(args, "--status")
    if new_status not in VALID_STATUSES:
        print(f"ERROR: Invalid status '{new_status}'. Use: {', '.join(sorted(VALID_STATUSES))}", file=sys.stderr)
        sys.exit(1)
    data = load(inv_id)
    old_status = data["status"]
    # Validate transitions
    valid_transitions = {
        "active": {"paused", "resolved", "abandoned"},
        "paused": {"active"},
        "resolved": set(),
        "abandoned": set(),
    }
    if new_status not in valid_transitions.get(old_status, set()):
        print(f"ERROR: Cannot transition from '{old_status}' to '{new_status}'", file=sys.stderr)
        sys.exit(1)
    data["status"] = new_status
    if new_status == "resolved":
        res_type = get_opt(args, "--resolution-type", "no-fix-needed")
        if res_type not in VALID_RESOLUTION_TYPES:
            print(f"ERROR: Invalid resolution type '{res_type}'", file=sys.stderr)
            sys.exit(1)
        summary = get_opt(args, "--summary", "")
        short_id = inv_id[:8]
        fix_todo = f"#investigation-{short_id}" if res_type == "fix-needed" else None
        data["resolution"] = {"type": res_type, "summary": summary, "fixTodo": fix_todo}
        if fix_todo and fix_todo not in data.get("relatedTodos", []):
            data.setdefault("relatedTodos", []).append(fix_todo)
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
        data["currentTheory"] = int(ct) if ct != "null" else None
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
        print(f"ERROR: {flag} is required", file=sys.stderr)
        sys.exit(1)


def get_opt(args, flag, default):
    try:
        idx = args.index(flag)
        return args[idx + 1]
    except (ValueError, IndexError):
        return default


# --- Dispatch ---

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
    cmd = sys.argv[1]
    if cmd not in COMMANDS:
        print(f"ERROR: Unknown command '{cmd}'. Available: {', '.join(sorted(COMMANDS))}", file=sys.stderr)
        sys.exit(1)
    COMMANDS[cmd](sys.argv[2:])

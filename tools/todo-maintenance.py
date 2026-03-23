#!/usr/bin/env python3
"""Routine TODO.md housekeeping: audit + archive in one clean command."""

import argparse
import json
import os
import re
import subprocess
import sys
from datetime import date
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
PREFLIGHT = SCRIPT_DIR / "todo-preflight.sh"
ARCHIVE_SCRIPT = SCRIPT_DIR.parent / "skills" / "productivity" / "todo-archive" / "todo-archive.sh"
TASK_RE = re.compile(r"^- \[([ x/\-])\] \[(\d{8}-\d+)\] (.*)$")
TAG_RE = re.compile(r"(#[A-Za-z0-9._/-]+)")
META_RE = re.compile(r"^  - (Added|Done|Cancelled|Deferred):\s*([0-9]{4}-[0-9]{2}-[0-9]{2})")
ACTIVE_SECTIONS = {"P1", "P2", "P3"}


def fail(message: str, code: int = 1) -> None:
    print(f"ERROR: {message}", file=sys.stderr)
    raise SystemExit(code)


def run_preflight() -> dict:
    result = subprocess.run(
        [str(PREFLIGHT), "--json", "--create-if-missing"],
        capture_output=True,
        text=True,
        env=os.environ.copy(),
    )
    if result.returncode != 0:
        fail(result.stderr.strip() or result.stdout.strip() or "todo-preflight failed")
    return json.loads(result.stdout)


def parse_iso_day(value: str | None):
    if not value:
        return None
    try:
        return date.fromisoformat(value)
    except ValueError:
        return None


def inspect_todo(todo_path: str, stale_plan_days: int) -> dict:
    content = Path(todo_path).read_text()
    line_count = len(content.splitlines())
    section = None
    current = None
    tasks = []

    def flush_current():
        nonlocal current
        if current is not None:
            tasks.append(current)
            current = None

    for line in content.splitlines() + ["# __EOF__"]:
        if line.startswith("## P1"):
            flush_current(); section = "P1"; continue
        if line.startswith("## P2"):
            flush_current(); section = "P2"; continue
        if line.startswith("## P3"):
            flush_current(); section = "P3"; continue
        if line.startswith("# HISTORY"):
            flush_current(); section = "HISTORY"; continue
        if line.startswith("# DEFERRED"):
            flush_current(); section = "DEFERRED"; continue
        if line.startswith("# METRICS") or line.startswith("# __EOF__"):
            flush_current(); section = "METRICS"; continue

        match = TASK_RE.match(line)
        if match:
            flush_current()
            marker, task_id, tail = match.groups()
            current = {
                "id": task_id,
                "section": section,
                "state": {" ": "open", "x": "done", "/": "in-progress", "-": "cancelled"}[marker],
                "text": line.strip(),
                "tags": TAG_RE.findall(tail),
                "added": None,
                "done": None,
                "cancelled": None,
                "deferred": None,
            }
            continue

        if current is not None:
            meta = META_RE.match(line)
            if meta:
                field, value = meta.groups()
                current[field.lower()] = value

    today = date.today()
    active = [t for t in tasks if t["section"] in ACTIVE_SECTIONS]
    history = [t for t in tasks if t["section"] == "HISTORY"]
    deferred = [t for t in tasks if t["section"] == "DEFERRED"]

    oldest_history_age_days = None
    for task in history:
        completed = parse_iso_day(task.get("done") or task.get("cancelled"))
        if completed is None:
            continue
        age_days = (today - completed).days
        oldest_history_age_days = age_days if oldest_history_age_days is None else max(oldest_history_age_days, age_days)

    stale_plan_tasks = []
    for task in active:
        if task["state"] not in {"open", "in-progress"}:
            continue
        if not any(tag.startswith("#plan-") for tag in task["tags"]):
            continue
        added = parse_iso_day(task.get("added"))
        if added is None:
            continue
        age_days = (today - added).days
        if age_days >= stale_plan_days:
            stale_plan_tasks.append({
                "id": task["id"],
                "priority": task["section"],
                "age_days": age_days,
                "text": task["text"],
            })

    return {
        "line_count": line_count,
        "active_open_count": sum(1 for t in active if t["state"] == "open"),
        "active_in_progress_count": sum(1 for t in active if t["state"] == "in-progress"),
        "active_non_open_count": sum(1 for t in active if t["state"] not in {"open", "in-progress"}),
        "history_count": len(history),
        "deferred_count": len(deferred),
        "oldest_history_age_days": oldest_history_age_days,
        "stale_plan_count": len(stale_plan_tasks),
        "stale_plan_tasks": stale_plan_tasks,
    }


def archive_reasons(summary: dict, args) -> list[str]:
    reasons = []
    if summary["history_count"] >= args.history_threshold:
        reasons.append(f"history_count>={args.history_threshold}")
    if summary["line_count"] > args.line_threshold:
        reasons.append(f"line_count>{args.line_threshold}")
    oldest = summary.get("oldest_history_age_days")
    if oldest is not None and oldest > args.history_age_days:
        reasons.append(f"oldest_history_age_days>{args.history_age_days}")
    return reasons


def run_archive(todo_path: str) -> None:
    env = os.environ.copy()
    env["TODO_FILE_PATH"] = todo_path
    result = subprocess.run(
        [str(ARCHIVE_SCRIPT), "--force"],
        capture_output=True,
        text=True,
        env=env,
    )
    if result.returncode != 0:
        message = (result.stderr or "").strip() or (result.stdout or "").strip() or "todo archive failed"
        fail(message)


def emit_human(result: dict, stale_plan_days: int) -> None:
    before = result["before"]
    after = result["after"]
    print("🧹 TODO maintenance")
    print(f"   Path: {result['todo_path']}")
    print(
        "   Before: "
        f"{before['line_count']} lines | ACTIVE {before['active_open_count']} open / "
        f"{before['active_in_progress_count']} in-progress | HISTORY {before['history_count']} | "
        f"DEFERRED {before['deferred_count']}"
    )
    if result["archive_due"]:
        print(f"   Archive due: yes ({', '.join(result['archive_reasons'])})")
    else:
        print("   Archive due: no")
    if before["stale_plan_count"]:
        print(f"   Stale #plan-* tasks (≥{stale_plan_days}d): {before['stale_plan_count']}")
        for task in before["stale_plan_tasks"][:5]:
            print(f"     - {task['id']} ({task['priority']}, {task['age_days']}d): {task['text']}")
    if result["dry_run"] and result["archive_requested"]:
        print("   Archive action: dry-run (would run todo-archive.sh --force)")
    elif result["archive_performed"]:
        print("   Archive action: ran todo-archive.sh --force")
        print(
            "   After:  "
            f"{after['line_count']} lines | ACTIVE {after['active_open_count']} open / "
            f"{after['active_in_progress_count']} in-progress | HISTORY {after['history_count']} | "
            f"DEFERRED {after['deferred_count']}"
        )
    else:
        print("   Archive action: skipped")


def main() -> None:
    parser = argparse.ArgumentParser(description="TODO maintenance: audit + archive in one clean command")
    parser.add_argument("--json", action="store_true", help="machine-readable JSON output")
    parser.add_argument("--dry-run", action="store_true", help="report maintenance actions without modifying files")
    parser.add_argument("--no-archive", action="store_true", help="never run archive; report only")
    parser.add_argument("--force-archive", action="store_true", help="run todo-archive.sh --force even if thresholds are not met")
    parser.add_argument("--stale-plan-days", type=int, default=7, help="age threshold for stale #plan-* tasks")
    parser.add_argument("--history-threshold", type=int, default=5, help="archive when HISTORY has at least this many tasks")
    parser.add_argument("--line-threshold", type=int, default=200, help="archive when TODO.md exceeds this many lines")
    parser.add_argument("--history-age-days", type=int, default=7, help="archive when oldest HISTORY entry exceeds this age")
    args = parser.parse_args()

    if not PREFLIGHT.is_file():
        fail(f"todo-preflight.sh not found at {PREFLIGHT}")
    if not ARCHIVE_SCRIPT.is_file():
        fail(f"todo-archive.sh not found at {ARCHIVE_SCRIPT}")

    preflight = run_preflight()
    todo_path = preflight["todo_path"]
    before = inspect_todo(todo_path, args.stale_plan_days)
    reasons = archive_reasons(before, args)
    archive_due = bool(reasons)
    archive_requested = args.force_archive or archive_due
    archive_performed = False

    if archive_requested and not args.no_archive and not args.dry_run:
        run_archive(todo_path)
        archive_performed = True

    after = inspect_todo(todo_path, args.stale_plan_days)
    result = {
        "todo_path": todo_path,
        "created": preflight.get("created", False),
        "dry_run": args.dry_run,
        "archive_due": archive_due,
        "archive_reasons": reasons,
        "archive_requested": archive_requested,
        "archive_performed": archive_performed,
        "archive_mode": "force" if archive_requested and not args.no_archive else "none",
        "before": before,
        "after": after,
    }

    if args.json:
        print(json.dumps(result))
    else:
        emit_human(result, args.stale_plan_days)


if __name__ == "__main__":
    main()

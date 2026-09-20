#!/usr/bin/env python3
"""Summarize privacy-safe block events from retained Claude hook audit logs."""

from __future__ import annotations

import argparse
import errno
import os
import re
import stat
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import BinaryIO

DEFAULT_MAX_BYTES = 1024 * 1024
HARD_MAX_BYTES = 16 * 1024 * 1024
HOOKS = ("red-autonomy", "internal-terms", "git-identity")
RAW_CLASSES = ("TP", "FP", "fired", "unknown")
REPORT_CLASSES = ("fired", "unknown")
KNOWN_INPUT_KEYS = (
    "conversation_id",
    "cwd",
    "session_id",
    "tool_input",
    "tool_name",
    "transcript_path",
)

HEADER_RE = re.compile(
    r"^(?P<timestamp>\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z) "
    r"(?P<hook>red-autonomy|internal-terms|git-identity) (?P<fields>\S+(?: \S+)*)$"
)
FIELD_RE = re.compile(r"^(?P<key>[a-z_]+)=(?P<value>[^\s=]+)$")
REASON_RE = re.compile(r"^[A-Za-z0-9_.()/-]+$")
SID_RE = re.compile(r"^(?:-|[A-Za-z0-9_-]{1,128})$")
TOOL_RE = re.compile(r"^(?:-|[A-Za-z0-9_.:-]{1,64})$")
EXIT_RE = re.compile(r"^[1-9][0-9]{0,2}$")
UNKNOWN_KEYS_RE = re.compile(r"^(?:0|[1-9][0-9]{0,8})$")
ALLOWED_FIELDS = {
    "exit",
    "reason",
    "class",
    "sid",
    "tool",
    "input_keys",
    "unknown_keys",
}


@dataclass(frozen=True)
class AuditRecord:
    timestamp: str
    hook: str
    exit_code: int
    classification: str
    sid: str
    reason: str
    tool: str = "-"
    input_keys: str = "-"
    unknown_keys: int = 0


def max_bytes_arg(value: str) -> int:
    try:
        parsed = int(value)
    except ValueError as exc:
        raise argparse.ArgumentTypeError("max-bytes must be an integer") from exc
    if not 1 <= parsed <= HARD_MAX_BYTES:
        raise argparse.ArgumentTypeError(
            f"max-bytes must be between 1 and {HARD_MAX_BYTES}"
        )
    return parsed


def open_audit_log(path: Path) -> BinaryIO:
    if not hasattr(os, "O_NONBLOCK") or not hasattr(os, "O_NOFOLLOW"):
        raise ValueError("platform does not support nonblocking no-follow log opens")

    flags = os.O_RDONLY | os.O_NONBLOCK | os.O_NOFOLLOW
    if hasattr(os, "O_CLOEXEC"):
        flags |= os.O_CLOEXEC

    try:
        descriptor = os.open(path, flags)
    except OSError as exc:
        if exc.errno == errno.ELOOP:
            raise ValueError("audit log must not be a symlink") from exc
        raise

    try:
        info = os.fstat(descriptor)
        if not stat.S_ISREG(info.st_mode):
            raise ValueError("audit log must be a regular file")
        return os.fdopen(descriptor, "rb", closefd=True)
    except Exception:
        os.close(descriptor)
        raise


def read_stream_tail(stream: BinaryIO, size: int, max_bytes: int) -> tuple[list[str], bool]:
    truncated = size > max_bytes
    if truncated:
        # Read one byte immediately before the requested tail. It tells us
        # whether the tail starts at a record boundary, so a complete first
        # record is retained and an attacker-controlled partial line is not.
        start = size - max_bytes
        stream.seek(start - 1)
        window = stream.read(max_bytes + 1)
        boundary, data = window[:1], window[1:]
        if boundary != b"\n":
            _, separator, data = data.partition(b"\n")
            if not separator:
                data = b""
    else:
        data = stream.read(max_bytes)

    return data.decode("utf-8", errors="replace").splitlines(), truncated


def generation_state(paths: tuple[Path, ...]) -> tuple[tuple[int, ...] | None, ...]:
    state: list[tuple[int, ...] | None] = []
    for candidate in paths:
        try:
            info = candidate.lstat()
        except FileNotFoundError:
            state.append(None)
            continue
        state.append(
            (
                info.st_dev,
                info.st_ino,
                info.st_mode,
                info.st_size,
                info.st_mtime_ns,
            )
        )
    return tuple(state)


def read_retained_tail(path: Path, max_bytes: int) -> tuple[list[str], bool, int]:
    """Read one bounded chronological tail across .2, .1, and the live log."""
    candidates = (Path(f"{path}.2"), Path(f"{path}.1"), path)
    state_before = generation_state(candidates)
    remaining = max_bytes
    newest_first: list[list[str]] = []
    files_read = 0
    found = 0
    truncated = False

    for candidate in reversed(candidates):
        try:
            stream = open_audit_log(candidate)
        except FileNotFoundError:
            continue
        found += 1
        with stream:
            size = os.fstat(stream.fileno()).st_size
            if remaining == 0:
                truncated = truncated or size > 0
                continue
            lines, file_truncated = read_stream_tail(stream, size, remaining)
            newest_first.append(lines)
            files_read += 1
            truncated = truncated or file_truncated
            remaining = max(0, remaining - size)

    if found == 0:
        raise FileNotFoundError(path)
    if generation_state(candidates) != state_before:
        raise ValueError("audit log generations changed during read; retry")

    lines = [line for chunk in reversed(newest_first) for line in chunk]
    return lines, truncated, files_read


def valid_input_keys(value: str) -> bool:
    if value == "-":
        return True
    keys = value.split(",")
    return keys == sorted(set(keys)) and all(key in KNOWN_INPUT_KEYS for key in keys)


def parse_record(line: str) -> AuditRecord | None:
    header = HEADER_RE.fullmatch(line)
    if not header:
        return None

    fields: dict[str, str] = {}
    for token in header.group("fields").split(" "):
        match = FIELD_RE.fullmatch(token)
        if not match:
            return None
        key = match.group("key")
        if key not in ALLOWED_FIELDS or key in fields:
            return None
        fields[key] = match.group("value")

    exit_text = fields.get("exit", "")
    if not EXIT_RE.fullmatch(exit_text):
        return None
    exit_code = int(exit_text)
    if exit_code > 255 or "reason" not in fields:
        return None
    if not REASON_RE.fullmatch(fields["reason"]):
        return None

    classification = fields.get("class", "unknown")
    if classification not in RAW_CLASSES:
        return None
    if exit_code != 2 and (
        fields["reason"] != "malformed-input" or "class" not in fields
    ):
        return None
    sid = fields.get("sid", "-")
    tool = fields.get("tool", "-")
    input_keys = fields.get("input_keys", "-")
    unknown_keys_text = fields.get("unknown_keys", "0")
    if not SID_RE.fullmatch(sid):
        return None
    if not TOOL_RE.fullmatch(tool):
        return None
    if not valid_input_keys(input_keys):
        return None
    if not UNKNOWN_KEYS_RE.fullmatch(unknown_keys_text):
        return None

    # Legacy TP/FP labels were stamped by the gate itself, not by an
    # independent adjudicator. Treat both as fired-but-unadjudicated rather
    # than presenting either as evidence of correctness.
    if classification in {"TP", "FP"}:
        classification = "fired"

    return AuditRecord(
        timestamp=header.group("timestamp"),
        hook=header.group("hook"),
        exit_code=exit_code,
        classification=classification,
        sid=sid,
        reason=fields["reason"],
        tool=tool,
        input_keys=input_keys,
        unknown_keys=int(unknown_keys_text),
    )


def print_report(
    records: list[AuditRecord],
    excluded: int,
    truncated: bool,
    files_read: int,
    details: bool,
) -> None:
    counts: dict[str, dict[int, dict[str, int]]] = {hook: {} for hook in HOOKS}
    for record in records:
        values = counts[record.hook].setdefault(
            record.exit_code,
            {classification: 0 for classification in REPORT_CLASSES},
        )
        values[record.classification] += 1

    print("hook\texit\tfired_unadjudicated\tunknown")
    for hook in HOOKS:
        for exit_code in sorted({2, *counts[hook]}):
            values = counts[hook].get(
                exit_code,
                {classification: 0 for classification in REPORT_CLASSES},
            )
            print(
                f"{hook}\t{exit_code}\t{values['fired']}\t{values['unknown']}"
            )
    totals = {
        classification: sum(
            values[classification]
            for hook_counts in counts.values()
            for values in hook_counts.values()
        )
        for classification in REPORT_CLASSES
    }
    print(f"TOTAL\t-\t{totals['fired']}\t{totals['unknown']}")
    print(f"excluded_lines\t{excluded}")
    print(f"files_read\t{files_read}")
    print(f"truncated\t{'yes' if truncated else 'no'}")

    if details:
        print("LOCAL ONLY - DO NOT COMMIT DETAIL OUTPUT")
        print("timestamp\thook\texit\tclass\tsid\treason\ttool\tinput_keys\tunknown_keys")
        for record in records:
            print(
                f"{record.timestamp}\t{record.hook}\t{record.exit_code}\t"
                f"{record.classification}\t{record.sid}\t{record.reason}\t"
                f"{record.tool}\t{record.input_keys}\t{record.unknown_keys}"
            )


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Summarize fired/unadjudicated and unknown Claude hook events."
    )
    parser.add_argument(
        "--log",
        type=Path,
        default=Path("~/.claude/hooks/hook-audit.log").expanduser(),
        help="local hook audit log (default: ~/.claude/hooks/hook-audit.log)",
    )
    parser.add_argument(
        "--max-bytes",
        type=max_bytes_arg,
        default=DEFAULT_MAX_BYTES,
        help=(
            "maximum total tail bytes across LOG.2, LOG.1, and LOG "
            f"(default: {DEFAULT_MAX_BYTES}, max: {HARD_MAX_BYTES})"
        ),
    )
    parser.add_argument(
        "--details",
        action="store_true",
        help="include local-only whitelisted detail; never commit this output",
    )
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    try:
        lines, truncated, files_read = read_retained_tail(
            args.log.expanduser(), args.max_bytes
        )
    except (OSError, ValueError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1

    records: list[AuditRecord] = []
    excluded = 0
    for line in lines:
        if not line:
            continue
        record = parse_record(line)
        if record is None:
            excluded += 1
        else:
            records.append(record)

    print_report(records, excluded, truncated, files_read, args.details)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

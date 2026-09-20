#!/usr/bin/env python3
"""Measure advisory skill-router precision without printing prompt text."""

import argparse
import hashlib
import json
import os
import re
import stat
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Dict, Iterable, List, Optional, Tuple


DEFAULT_METRICS = Path.home() / ".claude" / "hooks" / "skill-router-metrics.jsonl"
DEFAULT_TRANSCRIPTS = Path.home() / ".claude" / "projects"
DEFAULT_MAX_METRICS_BYTES = 64 * 1024 * 1024
DEFAULT_MAX_TRANSCRIPT_BYTES = 16 * 1024 * 1024
DEFAULT_MAX_TOTAL_TRANSCRIPT_BYTES = 64 * 1024 * 1024
DEFAULT_MAX_LINE_BYTES = 1024 * 1024
DEFAULT_MAX_TRANSCRIPTS = 1000
DEFAULT_MAX_RECORDS = 100000
DEFAULT_MAX_SCAN_ENTRIES = 10000
DEFAULT_MAX_DEPTH = 4

SESSION_RE = re.compile(r"^[A-Za-z0-9_.-]{1,128}$")
SHA256_RE = re.compile(r"^[0-9a-f]{64}$")
SKILL_RE = re.compile(r"^[A-Za-z0-9_.:/-]{1,160}$")
SLASH_COMMAND_RE = re.compile(
    r"(?<!\S)(/[A-Za-z0-9][A-Za-z0-9_.:-]*)(?=$|[\s,;.!?])"
)
SLASH_ALIAS_RE = re.compile(r"^/[A-Za-z0-9][A-Za-z0-9_.:-]{0,159}$")


@dataclass
class ParseCounters:
    skipped_lines: int = 0
    byte_limit_hit: bool = False
    record_limit_hit: bool = False
    bytes_read: int = 0


@dataclass
class MetricRecord:
    session_id: Optional[str]
    prompt_sha256: Optional[str]
    hints: List[str]
    suggested: Optional[str]
    explicit_aliases: List[str]


@dataclass
class Turn:
    prompt_sha256: str
    prompt_text: str
    invocations: List[str] = field(default_factory=list)


def bounded_int(name: str, minimum: int, maximum: int):
    """Build an argparse converter with explicit resource bounds."""

    def convert(raw: str) -> int:
        try:
            value = int(raw)
        except ValueError as exc:
            raise argparse.ArgumentTypeError(f"{name} must be an integer") from exc
        if not minimum <= value <= maximum:
            raise argparse.ArgumentTypeError(
                f"{name} must be between {minimum} and {maximum}"
            )
        return value

    return convert


def iter_bounded_jsonl(
    path: Path,
    max_bytes: int,
    max_line_bytes: int,
    counters: ParseCounters,
    no_follow: bool = False,
) -> Iterable[dict]:
    """Yield JSON objects while bounding bytes and physical line length."""

    consumed = 0
    try:
        if no_follow:
            flags = os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0)
            descriptor = os.open(path, flags)
            if not stat.S_ISREG(os.fstat(descriptor).st_mode):
                os.close(descriptor)
                return
            handle = os.fdopen(descriptor, "rb")
        else:
            handle = path.open("rb")
    except OSError:
        return

    with handle:
        while consumed < max_bytes:
            remaining = max_bytes - consumed
            read_limit = min(max_line_bytes + 1, remaining)
            raw = handle.readline(read_limit)
            if not raw:
                break
            consumed += len(raw)
            counters.bytes_read = consumed

            complete = raw.endswith(b"\n")
            overlong = len(raw) > max_line_bytes or (
                not complete and len(raw) == max_line_bytes + 1
            )
            if overlong:
                counters.skipped_lines += 1
                while not complete and consumed < max_bytes:
                    remaining = max_bytes - consumed
                    chunk = handle.readline(min(8192, remaining))
                    if not chunk:
                        complete = True
                        break
                    consumed += len(chunk)
                    counters.bytes_read = consumed
                    complete = chunk.endswith(b"\n")
                if not complete:
                    counters.byte_limit_hit = True
                    break
                continue

            if not complete and consumed >= max_bytes:
                counters.byte_limit_hit = True
                counters.skipped_lines += 1
                break

            try:
                value = json.loads(raw.decode("utf-8"))
            except (UnicodeDecodeError, json.JSONDecodeError):
                counters.skipped_lines += 1
                continue
            if not isinstance(value, dict):
                counters.skipped_lines += 1
                continue
            yield value

        if consumed >= max_bytes:
            try:
                if handle.read(1):
                    counters.byte_limit_hit = True
            except OSError:
                pass


def valid_session_id(value: object) -> Optional[str]:
    if isinstance(value, str) and SESSION_RE.fullmatch(value):
        return value
    return None


def valid_sha256(value: object) -> Optional[str]:
    if isinstance(value, str):
        lowered = value.lower()
        if SHA256_RE.fullmatch(lowered):
            return lowered
    return None


def valid_skill(value: object) -> Optional[str]:
    if isinstance(value, str) and SKILL_RE.fullmatch(value):
        return value
    return None


def read_metrics(
    path: Path,
    max_bytes: int,
    max_line_bytes: int,
    max_records: int,
) -> Tuple[List[MetricRecord], ParseCounters, int]:
    counters = ParseCounters()
    records: List[MetricRecord] = []
    unsafe_session_ids = 0
    for value in iter_bounded_jsonl(path, max_bytes, max_line_bytes, counters):
        if len(records) >= max_records:
            counters.record_limit_hit = True
            break

        raw_session = value.get("session_id")
        session_id = valid_session_id(raw_session)
        if raw_session is not None and session_id is None:
            unsafe_session_ids += 1

        hints = []
        raw_hints = value.get("hints")
        if isinstance(raw_hints, list):
            for item in raw_hints[:32]:
                skill = valid_skill(item)
                if skill is not None:
                    hints.append(skill)

        explicit_aliases = []
        raw_aliases = value.get("explicit_aliases")
        if isinstance(raw_aliases, list):
            for item in raw_aliases[:16]:
                if isinstance(item, str) and SLASH_ALIAS_RE.fullmatch(item):
                    explicit_aliases.append(item.lower())

        records.append(
            MetricRecord(
                session_id=session_id,
                prompt_sha256=valid_sha256(value.get("prompt_sha256")),
                hints=hints,
                suggested=valid_skill(value.get("suggested")),
                explicit_aliases=explicit_aliases,
            )
        )
    return records, counters, unsafe_session_ids


def index_transcripts(
    root: Path,
    wanted_sessions: set,
    max_transcripts: int,
    max_scan_entries: int,
    max_depth: int,
) -> Tuple[Dict[str, Path], bool]:
    """Index regular JSONL files without following links or leaving root."""

    found: Dict[str, Path] = {}
    scanned = 0
    limited = False
    try:
        root = root.resolve(strict=True)
    except OSError:
        return found, False
    if not root.is_dir():
        return found, False

    for current, directories, files in os.walk(root, followlinks=False):
        current_path = Path(current)
        try:
            depth = len(current_path.relative_to(root).parts)
        except ValueError:
            continue

        directories[:] = sorted(
            name
            for name in directories
            if not (current_path / name).is_symlink()
        )
        scanned += len(directories)
        if scanned > max_scan_entries:
            limited = True
            return found, limited
        if depth >= max_depth:
            directories[:] = []

        for name in sorted(files):
            scanned += 1
            if scanned > max_scan_entries:
                limited = True
                return found, limited
            if len(found) >= max_transcripts:
                limited = True
                return found, limited
            if not name.endswith(".jsonl"):
                continue

            session_id = name[:-6]
            if session_id not in wanted_sessions or not SESSION_RE.fullmatch(session_id):
                continue
            candidate = current_path / name
            try:
                file_stat = os.stat(candidate, follow_symlinks=False)
            except OSError:
                continue
            if not stat.S_ISREG(file_stat.st_mode):
                continue
            found.setdefault(session_id, candidate)

    return found, limited


def message_content(record: dict) -> object:
    message = record.get("message")
    if isinstance(message, dict):
        return message.get("content")
    return record.get("content")


def user_text(record: dict) -> Optional[str]:
    # cr-battery 2026-09-19: these five exclusions had no rationale comment.
    # Claude Code transcripts interleave real typed prompts with synthetic
    # user-role records: isMeta/isSidechain mark subagent and tool-scaffolding
    # turns, promptSource=="system" marks an injected system reminder, and
    # userType in {system, meta, tool_result} marks a non-human turn emitted
    # by the harness itself -- none of these represent an actual user prompt
    # the router scored. See the "ignores system and meta user records"
    # bats test for the load-bearing behavior this defends.
    if record.get("type") != "user":
        return None
    if record.get("isMeta") is True or record.get("isSidechain") is True:
        return None
    if record.get("promptSource") == "system" or record.get("userType") in {
        "system",
        "meta",
        "tool_result",
    }:
        return None
    content = message_content(record)
    if isinstance(content, str):
        return content
    if not isinstance(content, list):
        return None

    parts = []
    for block in content[:64]:
        if not isinstance(block, dict) or block.get("type") != "text":
            continue
        text = block.get("text")
        if isinstance(text, str):
            parts.append(text)
    return "\n".join(parts) if parts else None


def assistant_invocations(record: dict) -> List[str]:
    if record.get("type") != "assistant":
        return []
    content = message_content(record)
    if not isinstance(content, list):
        return []

    invocations = []
    for block in content[:128]:
        if not isinstance(block, dict) or block.get("type") != "tool_use":
            continue
        tool_name = block.get("name")
        if not isinstance(tool_name, str) or tool_name.lower() not in {
            "skill",
            "use_skill",
        }:
            continue
        tool_input = block.get("input")
        if not isinstance(tool_input, dict):
            continue
        skill = valid_skill(tool_input.get("skill")) or valid_skill(
            tool_input.get("name")
        )
        if skill is not None:
            invocations.append(skill)
    return invocations


def read_transcript(
    path: Path,
    max_bytes: int,
    max_line_bytes: int,
) -> Tuple[Dict[str, List[Turn]], ParseCounters]:
    counters = ParseCounters()
    turns: Dict[str, List[Turn]] = {}
    current_turn: Optional[Turn] = None

    for record in iter_bounded_jsonl(
        path, max_bytes, max_line_bytes, counters, no_follow=True
    ):
        text = user_text(record)
        if text is not None:
            # Bash command substitution strips trailing newlines from the
            # hook's extracted prompt before its 4096-character cap. Mirror
            # that producer normalization exactly for a stable join key.
            canonical = text.rstrip("\n")[:4096]
            prompt_hash = hashlib.sha256(canonical.encode("utf-8")).hexdigest()
            current_turn = Turn(prompt_sha256=prompt_hash, prompt_text=text)
            turns.setdefault(prompt_hash, []).append(current_turn)
            continue
        if current_turn is not None:
            current_turn.invocations.extend(assistant_invocations(record))

    return turns, counters


def same_skill(invoked: str, suggested: str) -> bool:
    # cr-battery 2026-09-19: tail-only matching let a differently-namespaced
    # skill sharing a tail name count as a correct suggestion (e.g. invoking
    # anthropic-skills:brainstorming counted as matching a suggestion of
    # unscoped "brainstorming") -- reproduced live, precision reported 1.0 on
    # a confirmed false-positive match. This repo's router corpus only ever
    # suggests unscoped names (verified: no colon-qualified name exists in
    # the local skills corpus), so a namespace prefix on EITHER side means
    # the invocation resolved to a specific installed copy that may or may
    # not be the one suggested -- only tail-match when NEITHER side carries
    # a namespace prefix (a first-pass fix that required namespace equality
    # only when BOTH sides had one was verified live to NOT close this case,
    # since the reproduction has exactly one namespaced side -- fixed here).
    if invoked == suggested:
        return True
    # No legitimate tail-match case survives once either side has a
    # namespace prefix (see comment above) -- when neither side has a colon,
    # tail-matching and exact-matching are the same comparison anyway, so
    # this function is now just exact equality. Kept as an explicit function
    # (not inlined at call sites) so the reasoning above stays attached to
    # the one place this comparison is made.
    return False


def explicit_invocation(
    prompt_text: str, suggested: str, explicit_aliases: List[str]
) -> bool:
    suggested_lower = suggested.lower()
    suggested_tail = suggested_lower.rsplit(":", 1)[-1]
    known_slash_names = {
        f"/{suggested_lower}",
        f"/{suggested_tail}",
        *(alias.lower() for alias in explicit_aliases),
    }
    slash_names = {
        match.group(1).lower() for match in SLASH_COMMAND_RE.finditer(prompt_text)
    }
    if slash_names & known_slash_names:
        return True
    explicit_names = {suggested_lower, suggested_tail}
    explicit_names.update(alias.lstrip("/").lower() for alias in explicit_aliases)
    return any(
        re.search(
            rf"\b(?:use|invoke|run|load)\s+(?:the\s+)?(?:skill\s+)?{re.escape(name)}\b",
            prompt_text,
            re.IGNORECASE,
        )
        for name in explicit_names
    )


def analyze(
    records: List[MetricRecord],
    transcript_paths: Dict[str, Path],
    max_transcript_bytes: int,
    max_total_transcript_bytes: int,
    max_line_bytes: int,
) -> Tuple[dict, int, int, int, int, bool, int]:
    # cr-battery 2026-09-19 (Design Critic + Defect Finder, convergent): this
    # annotation drifted to 6 elements the moment schema_incomplete_hints was
    # added as a 7th return value, in the same diff that added it -- caught
    # by the review, not by anything mechanical (no mypy/type-check gate
    # exists in this repo). Fixed to match the actual return statement below.
    # A dataclass (matching this file's own ParseCounters/MetricRecord/Turn
    # convention) would remove the positional-arity risk entirely; deferred
    # as a larger, non-zero-regression-risk refactor -- tracked in TODO.md.
    total_hints = sum(len(record.hints) for record in records)
    hinted_prompts = sum(bool(record.hints) for record in records)
    evaluable = 0
    correct = 0
    suggested_not_invoked = 0
    matched_invocations = {"automatic": 0, "explicit": 0}
    missing_transcripts = 0
    unmatched_prompt_hashes = 0
    schema_incomplete_hints = 0
    transcript_lines_skipped = 0
    transcript_byte_limits = 0
    transcript_total_bytes = 0
    transcript_total_byte_limit = False
    records_by_session: Dict[str, List[MetricRecord]] = {}

    for record in records:
        if not record.hints:
            continue
        # PHR round 1 (2026-09-18) found these two conditions silently
        # dropped hinted records with NO counter incremented -- on a machine
        # where the installed hook writes an older/shorter record schema
        # (missing suggested/session_id/prompt_sha256 entirely), every
        # hinted record fails here, evaluable_suggestions is permanently 0,
        # and the old "Skipped:" line showed every NAMED reason at zero --
        # a diagnostic that could not account for its own null result.
        if record.suggested is None:
            schema_incomplete_hints += 1
            continue
        if record.session_id is None or record.prompt_sha256 is None:
            schema_incomplete_hints += 1
            continue
        records_by_session.setdefault(record.session_id, []).append(record)

    # Parse and release one transcript at a time. This bounds retained memory
    # to one per-file budget instead of max_transcripts * per-file bytes.
    for session_id, session_records in records_by_session.items():
        transcript_path = transcript_paths.get(session_id)
        if transcript_path is None:
            missing_transcripts += len(session_records)
            continue
        try:
            file_size = os.stat(transcript_path, follow_symlinks=False).st_size
        except OSError:
            missing_transcripts += len(session_records)
            continue
        if file_size > max_transcript_bytes:
            transcript_byte_limits += 1
            continue
        remaining_bytes = max_total_transcript_bytes - transcript_total_bytes
        if file_size > remaining_bytes:
            transcript_total_byte_limit = True
            break

        turns, counters = read_transcript(
            transcript_path,
            min(max_transcript_bytes, remaining_bytes),
            max_line_bytes,
        )
        transcript_total_bytes += counters.bytes_read
        transcript_lines_skipped += counters.skipped_lines
        if counters.byte_limit_hit:
            # Never mix a partial transcript into precision. The missing tail
            # could contain the invocation that changes the classification.
            if counters.bytes_read >= remaining_bytes:
                transcript_total_byte_limit = True
                break
            transcript_byte_limits += 1
            continue
        if counters.skipped_lines:
            # A skipped line may be the matching invocation or a user-turn
            # boundary. Never classify a partial logical transcript.
            continue

        turn_offsets: Dict[str, int] = {}
        for record in session_records:
            turns_for_hash = turns.get(record.prompt_sha256, [])
            offset = turn_offsets.get(record.prompt_sha256, 0)
            if offset >= len(turns_for_hash):
                unmatched_prompt_hashes += 1
                continue
            turn_offsets[record.prompt_sha256] = offset + 1
            turn = turns_for_hash[offset]
            evaluable += 1

            matched = any(
                same_skill(invoked, record.suggested)
                for invoked in turn.invocations
            )
            if not matched:
                suggested_not_invoked += 1
                continue

            correct += 1
            source = (
                "explicit"
                if explicit_invocation(
                    turn.prompt_text,
                    record.suggested,
                    record.explicit_aliases,
                )
                else "automatic"
            )
            matched_invocations[source] += 1

    prompts = len(records)
    report = {
        "prompts": prompts,
        "hinted_prompts": hinted_prompts,
        "total_hints": total_hints,
        "hint_rate": hinted_prompts / prompts if prompts else None,
        "hints_per_prompt": total_hints / prompts if prompts else None,
        "evaluable_suggestions": evaluable,
        "correct_suggestions": correct,
        "precision": correct / evaluable if evaluable else None,
        "matched_invocations": matched_invocations,
        "suggested_not_invoked": suggested_not_invoked,
    }
    return (
        report,
        missing_transcripts,
        unmatched_prompt_hashes,
        transcript_lines_skipped,
        transcript_byte_limits,
        transcript_total_byte_limit,
        schema_incomplete_hints,
    )


def percentage(value: Optional[float]) -> str:
    return "n/a" if value is None else f"{value * 100:.1f}%"


def decimal(value: Optional[float]) -> str:
    return "n/a" if value is None else f"{value:.3f}"


def print_human(report: dict) -> None:
    print("Skill router precision report")
    print(f"Prompts: {report['prompts']}")
    print(f"Hinted prompts: {report['hinted_prompts']}")
    print(f"Hint rate: {percentage(report['hint_rate'])}")
    print(f"Hints per prompt: {decimal(report['hints_per_prompt'])}")
    print(f"Evaluable suggestions: {report['evaluable_suggestions']}")
    print(f"Correct suggestions: {report['correct_suggestions']}")
    print(f"Precision: {percentage(report['precision'])}")
    print(
        "Automatic matched invocations: "
        f"{report['matched_invocations']['automatic']}"
    )
    print(
        "Explicit matched invocations: "
        f"{report['matched_invocations']['explicit']}"
    )
    print(f"Suggested but not invoked: {report['suggested_not_invoked']}")
    skipped = report["skipped"]
    print(
        "Skipped: "
        f"metrics_lines={skipped['metrics_lines']} "
        f"transcript_lines={skipped['transcript_lines']} "
        f"unsafe_session_ids={skipped['unsafe_session_ids']} "
        f"missing_transcripts={skipped['missing_transcripts']} "
        f"unmatched_prompt_hashes={skipped['unmatched_prompt_hashes']} "
        f"schema_incomplete_hints={skipped['schema_incomplete_hints']} "
        f"metrics_byte_limit={skipped['metrics_byte_limit']} "
        f"metrics_record_limit={skipped['metrics_record_limit']} "
        f"transcript_byte_limits={skipped['transcript_byte_limits']} "
        "transcript_total_byte_limit="
        f"{skipped['transcript_total_byte_limit']} "
        f"transcript_scan_limit={skipped['transcript_scan_limit']}"
    )
    if report["hinted_prompts"] > 0 and report["evaluable_suggestions"] == 0:
        hint_ratio = skipped["schema_incomplete_hints"] / report["hinted_prompts"]
        if hint_ratio > 0.5:
            print(
                "WARNING: precision is n/a because "
                f"{skipped['schema_incomplete_hints']}/{report['hinted_prompts']} "
                "hinted records are missing suggested/session_id/prompt_sha256 "
                "-- this is a record-schema mismatch (e.g. an installed hook "
                "older than this repo's), not 'insufficient data yet'. Compare "
                "the installed hook to tools/claude-hooks/"
                "user-prompt-submit-skill-router.sh.",
                file=sys.stderr,
            )


def parse_args(argv: Optional[List[str]] = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Report skill-router hint rate and precision from local metrics "
            "and Claude transcript JSONL without printing prompt text."
        )
    )
    parser.add_argument("--metrics", type=Path, default=DEFAULT_METRICS)
    parser.add_argument("--transcripts", type=Path, default=DEFAULT_TRANSCRIPTS)
    parser.add_argument("--json", action="store_true", help="emit JSON")
    parser.add_argument(
        "--max-metrics-bytes",
        type=bounded_int("max metrics bytes", 1024, 1024 * 1024 * 1024),
        default=DEFAULT_MAX_METRICS_BYTES,
    )
    parser.add_argument(
        "--max-transcript-bytes",
        type=bounded_int("max transcript bytes", 1024, 256 * 1024 * 1024),
        default=DEFAULT_MAX_TRANSCRIPT_BYTES,
    )
    parser.add_argument(
        "--max-total-transcript-bytes",
        type=bounded_int("max total transcript bytes", 1024, 2 * 1024 * 1024 * 1024),
        default=DEFAULT_MAX_TOTAL_TRANSCRIPT_BYTES,
    )
    parser.add_argument(
        "--max-line-bytes",
        type=bounded_int("max line bytes", 64, 8 * 1024 * 1024),
        default=DEFAULT_MAX_LINE_BYTES,
    )
    parser.add_argument(
        "--max-transcripts",
        type=bounded_int("max transcripts", 1, 10000),
        default=DEFAULT_MAX_TRANSCRIPTS,
    )
    parser.add_argument(
        "--max-records",
        type=bounded_int("max records", 1, 1000000),
        default=DEFAULT_MAX_RECORDS,
    )
    parser.add_argument(
        "--max-scan-entries",
        type=bounded_int("max scan entries", 1, 1000000),
        default=DEFAULT_MAX_SCAN_ENTRIES,
    )
    parser.add_argument(
        "--max-depth",
        type=bounded_int("max depth", 0, 10),
        default=DEFAULT_MAX_DEPTH,
    )
    return parser.parse_args(argv)


def main(argv: Optional[List[str]] = None) -> int:
    args = parse_args(argv)
    if not args.metrics.is_file():
        print(f"router-precision: metrics file not found: {args.metrics}", file=sys.stderr)
        return 2

    records, metric_counters, unsafe_session_ids = read_metrics(
        args.metrics,
        args.max_metrics_bytes,
        args.max_line_bytes,
        args.max_records,
    )
    wanted_sessions = {
        record.session_id for record in records if record.session_id is not None
    }
    transcript_paths, scan_limited = index_transcripts(
        args.transcripts,
        wanted_sessions,
        args.max_transcripts,
        args.max_scan_entries,
        args.max_depth,
    )
    (
        report,
        missing_transcripts,
        unmatched_prompt_hashes,
        transcript_lines_skipped,
        transcript_byte_limits,
        transcript_total_byte_limit,
        schema_incomplete_hints,
    ) = analyze(
        records,
        transcript_paths,
        args.max_transcript_bytes,
        args.max_total_transcript_bytes,
        args.max_line_bytes,
    )
    report["skipped"] = {
        "metrics_lines": metric_counters.skipped_lines,
        "transcript_lines": transcript_lines_skipped,
        "unsafe_session_ids": unsafe_session_ids,
        "missing_transcripts": missing_transcripts,
        "unmatched_prompt_hashes": unmatched_prompt_hashes,
        "schema_incomplete_hints": schema_incomplete_hints,
        "metrics_byte_limit": metric_counters.byte_limit_hit,
        "metrics_record_limit": metric_counters.record_limit_hit,
        "transcript_byte_limits": transcript_byte_limits,
        "transcript_total_byte_limit": transcript_total_byte_limit,
        "transcript_scan_limit": scan_limited,
    }

    if args.json:
        print(json.dumps(report, sort_keys=True))
    else:
        print_human(report)
    return 0


if __name__ == "__main__":
    sys.exit(main())

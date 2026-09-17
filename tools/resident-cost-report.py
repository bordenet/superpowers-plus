#!/usr/bin/env python3
"""resident-cost-report.py — project the resident context cost of the skill listing.

Two modes:

  --repo   CI-safe. Walks this repo's skills/**/skill.md (case-insensitive
           filename) and projects what Claude Code would list after install:
           one entry per model-visible skill. `coordination.internal` is repo
           workflow metadata, not a Claude visibility control. "manual"
           entries carry frontmatter `disable-model-invocation: true`
           (hidden from the listing, still typeable by name); "auto" is
           everything else that is listed. Only auto entries count toward
           listing_bytes -- that is the text loaded into every session.

  --host   Local only (never run in CI). Inspects the live Claude Code
           install: $CLAUDE_HOME/skills/*/[sS][kK][iI][lL][lL].md,
           $CLAUDE_HOME/commands/*.md, and the skills of every plugin
           enabled in $CLAUDE_HOME/settings.json's `enabledPlugins`
           (resolved via $CLAUDE_HOME/plugins/installed_plugins.json's
           `installPath`). It reads the latest successful SessionStart hook
           output already recorded in Claude's project transcripts; it never
           executes hook commands. Router-hint statistics come from at most
           the latest 1,000 records / 1 MiB of
           $CLAUDE_HOME/hooks/skill-router-metrics.jsonl.

           The Claude config resolves from $CLAUDE_HOME_OVERRIDE/.claude,
           then $CLAUDE_CONFIG_DIR, then $HOME/.claude.

Entry text (the thing that costs context) is defined as `name + description`
(bytes of the frontmatter name concatenated with the frontmatter description,
UTF-8, no separator) for every model-visible entry.
listing_tokens_est is listing_bytes / 4, rounded to the nearest integer --
the same rough bytes-per-token heuristic used elsewhere in this repo.

Canonical name (used for duplicate detection) = frontmatter `name:` if
present, else the file/dir basename, with a leading `source-command-`
prefix stripped and a leading `<plugin-short-name>:` prefix stripped.

Output: JSON to stdout by default (--json), or a human-readable key: value
dump with --text. Exit codes: 0 = report emitted, 1 = a required input was
missing or unreadable, 2 = usage error.
"""
from __future__ import annotations

import argparse
from datetime import datetime
import json
import os
import stat
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent

class ReportError(RuntimeError):
    """Required report input is incomplete or invalid."""


def parse_frontmatter_batch(paths: list[Path]) -> dict[Path, dict]:
    """Parse files once through the repository's canonical JS parser."""
    helper = REPO_ROOT / "tools" / "frontmatter-batch.js"
    try:
        result = subprocess.run(
            ["node", str(helper)],
            input=json.dumps([str(path) for path in paths]).encode("utf-8"),
            capture_output=True,
            timeout=30,
            cwd=str(REPO_ROOT),
        )
    except (OSError, subprocess.TimeoutExpired) as error:
        raise ReportError(f"canonical frontmatter parser unavailable: {error}") from error
    if result.returncode != 0:
        detail = result.stderr.decode("utf-8", errors="replace").strip()
        raise ReportError(f"canonical frontmatter parser failed: {detail or result.returncode}")
    try:
        payload = json.loads(result.stdout)
    except json.JSONDecodeError as error:
        raise ReportError("canonical frontmatter parser emitted invalid JSON") from error
    if payload.get("schema_version") != 1 or not isinstance(payload.get("results"), list):
        raise ReportError("canonical frontmatter parser schema mismatch")
    return {Path(row["path"]): row for row in payload["results"]}


def find_skill_files(root: Path) -> list[Path]:
    """Find skill files, following directory symlinks without following cycles."""
    try:
        root_stat = root.stat()
    except FileNotFoundError:
        return []
    except OSError as error:
        raise ReportError(f"skill traversal failed at {root}: {error}") from error
    if not stat.S_ISDIR(root_stat.st_mode):
        return []

    found = []
    stack: list[tuple[Path, frozenset[tuple[int, int]]]] = [(root, frozenset())]
    directories_scanned = 0
    while stack:
        directory, ancestors = stack.pop()
        try:
            directory_stat = directory.stat()
        except OSError as error:
            raise ReportError(f"skill traversal failed at {directory}: {error}") from error
        inode = (directory_stat.st_dev, directory_stat.st_ino)
        if inode in ancestors:
            continue
        directories_scanned += 1
        if directories_scanned > 10_000:
            raise ReportError(f"skill traversal directory limit exceeded at {directory}")
        descendants = ancestors | {inode}
        try:
            with os.scandir(directory) as entries:
                ordered = sorted(entries, key=lambda entry: entry.name)
        except OSError as error:
            raise ReportError(f"skill traversal failed at {directory}: {error}") from error

        child_dirs = []
        for entry in ordered:
            try:
                entry_stat = entry.stat(follow_symlinks=True)
            except OSError as error:
                raise ReportError(f"skill traversal failed at {entry.path}: {error}") from error
            if stat.S_ISDIR(entry_stat.st_mode):
                child_dirs.append(Path(entry.path))
            elif stat.S_ISREG(entry_stat.st_mode) and entry.name.lower() == "skill.md":
                found.append(Path(entry.path))
        for child in reversed(child_dirs):
            stack.append((child, descendants))
    return sorted(found)


# ---------------------------------------------------------------------------
# --repo mode
# ---------------------------------------------------------------------------


def build_repo_report(repo_root: Path) -> dict:
    skills_dir = repo_root / "skills"
    skill_files = find_skill_files(skills_dir)
    parsed = parse_frontmatter_batch(skill_files)

    listing_bytes = 0
    auto_count = 0
    manual_count = 0
    internal_count = 0
    max_description_bytes = 0
    max_description_skill = None
    max_skill_md_bytes = 0
    max_skill_md_skill = None
    descriptions_over_250 = 0
    visible_name_counts: dict[str, int] = {}
    all_name_counts: dict[str, int] = {}
    parse_failures = 0

    for path in skill_files:
        try:
            file_bytes = path.stat().st_size
        except OSError:
            file_bytes = 0
        row = parsed.get(path, {})
        fm = row.get("frontmatter")
        if row.get("error") or not isinstance(fm, dict):
            parse_failures += 1
            fm = {}
        name = fm.get("name")
        if not isinstance(name, str) or not name.strip():
            parse_failures += 1
            name = path.parent.name
        else:
            name = name.strip()

        if file_bytes > max_skill_md_bytes:
            max_skill_md_bytes = file_bytes
            max_skill_md_skill = name

        all_name_counts[name] = all_name_counts.get(name, 0) + 1

        coordination = fm.get("coordination", {})
        internal = coordination.get("internal") is True if isinstance(coordination, dict) else False
        if internal:
            internal_count += 1

        description = fm.get("description", "")
        if not isinstance(description, str):
            parse_failures += 1
            description = ""

        desc_bytes = len(description.encode("utf-8"))
        if desc_bytes > max_description_bytes:
            max_description_bytes = desc_bytes
            max_description_skill = name
        if len(description) > 250:
            descriptions_over_250 += 1

        manual_value = fm.get("disable_model_invocation", False)
        if not isinstance(manual_value, bool):
            parse_failures += 1
            manual_value = False
        manual = manual_value
        if manual:
            manual_count += 1
        else:
            auto_count += 1
            visible_name_counts[name] = visible_name_counts.get(name, 0) + 1
            entry_bytes = len(name.encode("utf-8")) + len(description.encode("utf-8"))
            listing_bytes += entry_bytes

    duplicate_names = sum(1 for count in visible_name_counts.values() if count > 1)
    all_name_collisions = sum(1 for count in all_name_counts.values() if count > 1)

    return {
        "schema_version": 1,
        "mode": "repo",
        "listing_bytes": listing_bytes,
        "listing_tokens_est": round(listing_bytes / 4),
        "auto_count": auto_count,
        "manual_count": manual_count,
        "internal_count": internal_count,
        "max_description_bytes": max_description_bytes,
        "max_description_skill": max_description_skill,
        "max_skill_md_bytes": max_skill_md_bytes,
        "max_skill_md_skill": max_skill_md_skill,
        "descriptions_over_250": descriptions_over_250,
        "duplicate_names": duplicate_names,
        "all_name_collisions": all_name_collisions,
        "skill_files_scanned": len(skill_files),
        "parse_failures": parse_failures,
    }


# ---------------------------------------------------------------------------
# --host mode
# ---------------------------------------------------------------------------


def resolve_claude_home() -> Path:
    override = os.environ.get("CLAUDE_HOME_OVERRIDE")
    if override:
        return Path(override) / ".claude"
    config_dir = os.environ.get("CLAUDE_CONFIG_DIR")
    if config_dir:
        return Path(config_dir)
    home = os.environ.get("HOME") or str(Path.home())
    return Path(home) / ".claude"


def canonicalize(name: str) -> str:
    name = name.strip()
    if name.startswith("source-command-"):
        name = name[len("source-command-"):]
    if ":" in name:
        name = name.split(":", 1)[1]
    return name


def load_json_if_exists(path: Path):
    if not path.exists():
        return None
    try:
        with path.open("r", encoding="utf-8") as fh:
            return json.load(fh)
    except (OSError, json.JSONDecodeError) as error:
        raise ReportError(f"invalid JSON input {path}: {error}") from error


def enabled_plugin_roots(claude_home: Path) -> list[tuple[str, Path]]:
    """Return [(plugin_short_name, install_path), ...] for enabled plugins."""
    settings = load_json_if_exists(claude_home / "settings.json") or {}
    enabled = settings.get("enabledPlugins", {})
    if not isinstance(enabled, dict):
        raise ReportError("settings.json enabledPlugins must be an object")
    enabled_keys = [key for key, value in enabled.items() if value is True]
    registry_path = claude_home / "plugins" / "installed_plugins.json"
    installed = load_json_if_exists(registry_path)
    if enabled_keys and installed is None:
        raise ReportError(f"enabled plugin missing from registry: {enabled_keys[0]}")
    plugins_map = installed.get("plugins", {}) if isinstance(installed, dict) else {}
    if not isinstance(plugins_map, dict):
        raise ReportError("installed plugin registry must contain a plugins object")

    roots = []
    for plugin_key in enabled_keys:
        short_name = plugin_key.split("@", 1)[0]
        entries = plugins_map.get(plugin_key)
        if not isinstance(entries, list) or not entries:
            raise ReportError(f"enabled plugin missing from registry: {plugin_key}")
        for entry in entries:
            install_path = entry.get("installPath") if isinstance(entry, dict) else None
            if not install_path:
                raise ReportError(f"enabled plugin has no installPath: {plugin_key}")
            root = Path(install_path)
            if not root.is_dir():
                raise ReportError(f"enabled plugin install path missing: {root}")
            roots.append((short_name, root))
    return roots


def collect_entry(name: str, description: str, hidden: bool, entries: list, name_bytes_override: str | None = None):
    raw_name = name_bytes_override if name_bytes_override is not None else name
    entries.append(
        {
            "raw_name": raw_name,
            "canonical_name": canonicalize(name),
            "description": description,
            "hidden": hidden,
        }
    )


def _timestamp_epoch(value: str) -> float | None:
    try:
        return datetime.fromisoformat(value.replace("Z", "+00:00")).timestamp()
    except ValueError:
        return None


def _injected_context(stdout: str) -> str:
    """Decode Claude hook-protocol JSON; plain stdout is context verbatim."""
    try:
        payload = json.loads(stdout)
    except json.JSONDecodeError:
        return stdout
    if isinstance(payload, dict):
        hook_output = payload.get("hookSpecificOutput")
        if isinstance(hook_output, dict):
            context = hook_output.get("additionalContext", "")
            return context if isinstance(context, str) else ""
        return ""
    return stdout


def _scan_latest_sessionstart(
    claude_home: Path,
    *,
    max_files: int = 2_048,
    max_bytes: int = 32 * 1024 * 1024,
) -> dict:
    """Worker implementation for bounded SessionStart discovery and reading."""
    if max_files < 1 or max_bytes < 1:
        raise ReportError("transcript scan limits must be positive")
    projects_dir = claude_home / "projects"
    if not projects_dir.is_dir():
        return {
            "context_bytes": None,
            "raw_stdout_bytes": None,
            "output_count": 0,
            "observed_at": None,
            "transcript_files_scanned": 0,
        }

    def walk_error(error: OSError) -> None:
        raise ReportError(f"transcript discovery failed: {error}") from error

    transcript_stats = []
    for dirpath, dirnames, filenames in os.walk(projects_dir, onerror=walk_error):
        dirnames.sort()
        for filename in sorted(filenames):
            if not filename.endswith(".jsonl"):
                continue
            transcript = Path(dirpath) / filename
            if len(transcript_stats) >= max_files:
                raise ReportError(f"transcript scan file limit exceeded ({max_files})")
            try:
                transcript_stats.append((transcript.stat().st_mtime_ns, transcript))
            except OSError as error:
                raise ReportError(f"transcript discovery failed at {transcript}: {error}") from error
    transcript_stats.sort(reverse=True)

    groups: dict[tuple[str, str], dict] = {}
    files_scanned = 0
    bytes_read = 0

    def reverse_lines(transcript: Path):
        nonlocal bytes_read
        try:
            fh = transcript.open("rb")
        except OSError as error:
            raise ReportError(f"transcript read failed at {transcript}: {error}") from error
        with fh:
            try:
                position = fh.seek(0, os.SEEK_END)
                carry = b""
                while position > 0:
                    remaining_budget = max_bytes - bytes_read
                    if remaining_budget <= 0:
                        raise ReportError(f"transcript scan byte limit exceeded ({max_bytes})")
                    chunk_size = min(64 * 1024, position, remaining_budget)
                    position -= chunk_size
                    fh.seek(position)
                    chunk = fh.read(chunk_size)
                    if len(chunk) != chunk_size:
                        raise ReportError(f"transcript short read at {transcript}")
                    bytes_read += len(chunk)
                    parts = (chunk + carry).split(b"\n")
                    carry = parts[0]
                    for raw_line in reversed(parts[1:]):
                        yield raw_line.decode("utf-8", errors="replace")
                if carry:
                    yield carry.decode("utf-8", errors="replace")
            except OSError as error:
                raise ReportError(f"transcript read failed at {transcript}: {error}") from error

    for index, (_mtime_ns, transcript) in enumerate(transcript_stats):
        files_scanned += 1
        selected_key = None
        selected_group = None
        for line in reverse_lines(transcript):
            if "SessionStart" not in line or "hook_success" not in line:
                continue
            try:
                record = json.loads(line)
            except json.JSONDecodeError:
                continue
            attachment = record.get("attachment")
            if not isinstance(attachment, dict):
                continue
            if attachment.get("type") != "hook_success" or attachment.get("hookEvent") != "SessionStart":
                continue
            stdout = attachment.get("stdout")
            if not isinstance(stdout, str):
                continue
            timestamp = str(record.get("timestamp") or "")
            timestamp_epoch = _timestamp_epoch(timestamp)
            if timestamp_epoch is None:
                continue
            key = (
                str(record.get("sessionId") or ""),
                str(attachment.get("toolUseID") or ""),
            )
            if selected_key is None:
                selected_key = key
                selected_group = {
                    "context_bytes": 0,
                    "raw_stdout_bytes": 0,
                    "output_count": 0,
                    "observed_at": timestamp,
                    "observed_epoch": timestamp_epoch,
                }
            elif key != selected_key:
                break
            selected_group["context_bytes"] += len(_injected_context(stdout).encode("utf-8"))
            selected_group["raw_stdout_bytes"] += len(stdout.encode("utf-8"))
            selected_group["output_count"] += 1
            if timestamp_epoch > selected_group["observed_epoch"]:
                selected_group["observed_at"] = timestamp
                selected_group["observed_epoch"] = timestamp_epoch

        if selected_key is not None and selected_group is not None:
            existing = groups.get(selected_key)
            if existing is None:
                groups[selected_key] = selected_group
            else:
                existing["context_bytes"] += selected_group["context_bytes"]
                existing["raw_stdout_bytes"] += selected_group["raw_stdout_bytes"]
                existing["output_count"] += selected_group["output_count"]
                if selected_group["observed_epoch"] > existing["observed_epoch"]:
                    existing["observed_at"] = selected_group["observed_at"]
                    existing["observed_epoch"] = selected_group["observed_epoch"]

        if groups and index + 1 < len(transcript_stats):
            latest = max(groups.values(), key=lambda group: group["observed_epoch"])
            latest_epoch = latest["observed_epoch"]
            next_mtime_epoch = transcript_stats[index + 1][0] / 1_000_000_000
            if next_mtime_epoch <= latest_epoch:
                break

    if not groups:
        return {
            "context_bytes": None,
            "raw_stdout_bytes": None,
            "output_count": 0,
            "observed_at": None,
            "transcript_files_scanned": files_scanned,
        }
    latest = max(groups.values(), key=lambda group: group["observed_epoch"])
    latest.pop("observed_epoch", None)
    latest["transcript_files_scanned"] = files_scanned
    return latest


def _worker_json(arguments: list[str], timeout_seconds: float, label: str) -> dict:
    """Run a bounded read in a child so the parent owns the hard deadline."""
    try:
        result = subprocess.run(
            [sys.executable, str(Path(__file__).resolve()), *arguments],
            capture_output=True,
            timeout=timeout_seconds,
        )
    except subprocess.TimeoutExpired as error:
        raise ReportError(f"{label} time limit exceeded ({timeout_seconds:g}s)") from error
    except OSError as error:
        raise ReportError(f"{label} worker unavailable: {error}") from error
    if result.returncode != 0:
        detail = result.stderr.decode("utf-8", errors="replace").strip()
        if detail.startswith("ERROR: "):
            detail = detail[7:]
        raise ReportError(detail or f"{label} worker failed with exit {result.returncode}")
    try:
        payload = json.loads(result.stdout)
    except json.JSONDecodeError as error:
        raise ReportError(f"{label} worker emitted invalid JSON") from error
    if not isinstance(payload, dict):
        raise ReportError(f"{label} worker emitted a non-object result")
    return payload


def latest_sessionstart_observation(
    claude_home: Path,
    *,
    max_files: int = 2_048,
    max_bytes: int = 32 * 1024 * 1024,
    timeout_seconds: float = 5.0,
) -> dict:
    """Read SessionStart data in a worker with a parent-enforced deadline."""
    if max_files < 1 or max_bytes < 1 or timeout_seconds <= 0:
        raise ReportError("transcript scan limits must be positive")
    return _worker_json(
        ["--_worker-sessionstart", str(claude_home), str(max_files), str(max_bytes)],
        timeout_seconds,
        "transcript scan",
    )


def _scan_router_hint_observation(
    metrics_path: Path,
    *,
    max_bytes: int = 1024 * 1024,
    max_records: int = 1_000,
) -> dict:
    """Read only a bounded tail window of append-only router metrics."""
    if max_bytes < 1 or max_records < 1:
        raise ReportError("router metric limits must be positive")
    if not metrics_path.exists():
        return {
            "router_prompts": 0,
            "router_hint_rate": 0,
            "router_hints_per_prompt": 0,
            "router_metrics_records_sampled": 0,
            "router_metrics_bytes_read": 0,
            "router_metrics_truncated": False,
        }
    try:
        size = metrics_path.stat().st_size
        bytes_to_read = min(size, max_bytes)
        with metrics_path.open("rb") as fh:
            fh.seek(size - bytes_to_read)
            raw = fh.read(bytes_to_read)
    except OSError as error:
        raise ReportError(f"router metrics read failed at {metrics_path}: {error}") from error
    if len(raw) != bytes_to_read:
        raise ReportError(f"router metrics short read at {metrics_path}")

    truncated = size > bytes_to_read
    if truncated:
        newline = raw.find(b"\n")
        raw = raw[newline + 1:] if newline >= 0 else b""
    lines = raw.splitlines()
    if len(lines) > max_records:
        lines = lines[-max_records:]
        truncated = True

    router_prompts = 0
    router_hinted = 0
    router_total_hints = 0
    for raw_line in lines:
        try:
            record = json.loads(raw_line)
        except (json.JSONDecodeError, UnicodeDecodeError):
            continue
        if not isinstance(record, dict) or "hints" not in record:
            continue
        router_prompts += 1
        hints = record.get("hints")
        if isinstance(hints, list) and hints:
            router_hinted += 1
            router_total_hints += len(hints)

    return {
        "router_prompts": router_prompts,
        "router_hint_rate": round(100 * router_hinted / router_prompts, 1) if router_prompts else 0,
        "router_hints_per_prompt": (
            round(router_total_hints / router_prompts, 3) if router_prompts else 0
        ),
        "router_metrics_records_sampled": router_prompts,
        "router_metrics_bytes_read": bytes_to_read,
        "router_metrics_truncated": truncated,
    }


def router_hint_observation(
    metrics_path: Path,
    *,
    max_bytes: int = 1024 * 1024,
    max_records: int = 1_000,
    timeout_seconds: float = 1.0,
) -> dict:
    """Sample recent router metrics in a worker with a hard deadline."""
    if max_bytes < 1 or max_records < 1 or timeout_seconds <= 0:
        raise ReportError("router metric limits must be positive")
    return _worker_json(
        ["--_worker-router", str(metrics_path), str(max_bytes), str(max_records)],
        timeout_seconds,
        "router metrics scan",
    )


def build_host_report(claude_home: Path) -> dict:
    entries: list[dict] = []
    sources: list[tuple[Path, str | None, bool]] = []

    # Surface 1: user-level installed skills.
    skills_dir = claude_home / "skills"
    for skill_md in find_skill_files(skills_dir):
        sources.append((skill_md, None, False))

    # Surface 2: user-level custom commands (includes claude-commands-mirror
    # output, source-command-* Codex imports, and hand-authored commands).
    commands_dir = claude_home / "commands"
    if commands_dir.is_dir():
        for cmd_file in sorted(commands_dir.glob("*.md")):
            sources.append((cmd_file, None, True))

    # Surface 3: skills bundled in every enabled plugin.
    for short_name, install_path in enabled_plugin_roots(claude_home):
        plugin_skills_dir = install_path / "skills"
        for skill_md in find_skill_files(plugin_skills_dir):
            sources.append((skill_md, short_name, False))

    parsed = parse_frontmatter_batch([source[0] for source in sources])
    host_parse_failures = 0
    for path, plugin_prefix, is_command in sources:
        row = parsed.get(path, {})
        fm = row.get("frontmatter")
        if row.get("error") or not isinstance(fm, dict):
            host_parse_failures += 1
            continue
        name = fm.get("name")
        if not isinstance(name, str) or not name.strip():
            if is_command:
                name = path.stem
            else:
                host_parse_failures += 1
                continue
        else:
            name = name.strip()
        description = fm.get("description")
        hidden = fm.get("disable_model_invocation", False)
        if not isinstance(description, str) or not isinstance(hidden, bool):
            host_parse_failures += 1
            continue
        display_name = f"{plugin_prefix}:{name}" if plugin_prefix else name
        collect_entry(display_name, description, hidden, entries, name_bytes_override=display_name)

    if host_parse_failures:
        raise ReportError(f"host frontmatter incomplete: {host_parse_failures} file(s)")

    host_entries = len(entries)
    host_hidden_entries = sum(1 for e in entries if e["hidden"])

    visible_counts: dict[str, int] = {}
    all_counts: dict[str, int] = {}
    for entry in entries:
        name = entry["canonical_name"]
        all_counts[name] = all_counts.get(name, 0) + 1
        if not entry["hidden"]:
            visible_counts[name] = visible_counts.get(name, 0) + 1
    host_duplicate_entries = sum(
        1 for entry in entries
        if not entry["hidden"] and visible_counts[entry["canonical_name"]] > 1
    )
    host_all_collision_entries = sum(1 for entry in entries if all_counts[entry["canonical_name"]] > 1)

    host_listing_bytes = 0
    for e in entries:
        if e["hidden"]:
            continue
        host_listing_bytes += len(e["raw_name"].encode("utf-8")) + len(e["description"].encode("utf-8"))

    # SessionStart output from the latest recorded successful event. Reading
    # Claude's transcript preserves the real payload while keeping this report
    # operationally read-only.
    sessionstart = latest_sessionstart_observation(claude_home)

    # Router hint metrics use a recent bounded window rather than replaying the
    # append-only history on every report.
    metrics_path = claude_home / "hooks" / "skill-router-metrics.jsonl"
    router = router_hint_observation(metrics_path)

    return {
        "schema_version": 1,
        "mode": "host",
        "host_listing_bytes": host_listing_bytes,
        "host_listing_tokens_est": round(host_listing_bytes / 4),
        "host_entries": host_entries,
        "host_hidden_entries": host_hidden_entries,
        "host_duplicate_entries": host_duplicate_entries,
        "host_all_collision_entries": host_all_collision_entries,
        "host_parse_failures": host_parse_failures,
        "host_missing_plugins": 0,
        "host_sessionstart_context_bytes": sessionstart["context_bytes"],
        "host_sessionstart_tokens_est": (
            round(sessionstart["context_bytes"] / 4)
            if sessionstart["context_bytes"] is not None else None
        ),
        "host_sessionstart_raw_stdout_bytes": sessionstart["raw_stdout_bytes"],
        "host_sessionstart_output_count": sessionstart["output_count"],
        "host_sessionstart_observed_at": sessionstart["observed_at"],
        "host_sessionstart_transcript_files_scanned": sessionstart["transcript_files_scanned"],
        **router,
    }


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------


def main(argv=None) -> int:
    arguments = list(sys.argv[1:] if argv is None else argv)
    if arguments and arguments[0] in ("--_worker-sessionstart", "--_worker-router"):
        try:
            if arguments[0] == "--_worker-sessionstart" and len(arguments) == 4:
                report = _scan_latest_sessionstart(
                    Path(arguments[1]), max_files=int(arguments[2]), max_bytes=int(arguments[3])
                )
            elif arguments[0] == "--_worker-router" and len(arguments) == 4:
                report = _scan_router_hint_observation(
                    Path(arguments[1]), max_bytes=int(arguments[2]), max_records=int(arguments[3])
                )
            else:
                raise ReportError("invalid internal worker arguments")
        except (ReportError, ValueError) as error:
            print(f"ERROR: {error}", file=sys.stderr)
            return 1
        print(json.dumps(report, separators=(",", ":")))
        return 0

    parser = argparse.ArgumentParser(
        description="Project the resident context cost of the Claude Code skill listing.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    mode_group = parser.add_mutually_exclusive_group(required=True)
    mode_group.add_argument(
        "--repo", action="store_true", help="CI-safe: project this repo's skills/ listing."
    )
    mode_group.add_argument(
        "--host", action="store_true", help="Local only: inspect the live Claude Code install."
    )
    parser.add_argument(
        "--repo-root",
        default=str(REPO_ROOT),
        help="Repo root to scan in --repo mode (default: this script's repo). "
        "Overridable so tests can point at a fixture tree.",
    )
    out_group = parser.add_mutually_exclusive_group()
    out_group.add_argument("--json", action="store_true", help="Emit JSON (default).")
    out_group.add_argument("--text", action="store_true", help="Emit human-readable key: value text.")

    args = parser.parse_args(arguments)

    try:
        if args.repo:
            repo_root = Path(args.repo_root).resolve()
            if not repo_root.is_dir():
                print(f"ERROR: --repo-root is not a directory: {repo_root}", file=sys.stderr)
                return 1
            if not (repo_root / "skills").is_dir():
                print(f"ERROR: skills directory not found: {repo_root / 'skills'}", file=sys.stderr)
                return 1
            report = build_repo_report(repo_root)
        else:
            claude_home = resolve_claude_home()
            if not claude_home.is_dir():
                print(f"ERROR: Claude home not found: {claude_home}", file=sys.stderr)
                return 1
            report = build_host_report(claude_home)
    except ReportError as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return 1

    if args.text:
        for key, value in report.items():
            print(f"{key}: {value}")
    else:
        print(json.dumps(report, indent=2, sort_keys=False))

    return 0


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Script: journey-probe.sh
# GUIDE: docs/JOURNEY_PROBE.md
# PURPOSE: Measure daily-driver skill verdict quality and token/context cost
#          for deterministic user journeys. Live mode drives the real `claude`
#          CLI against an immutable private snapshot of each prompt in
#          test/fixtures/journeys/ on a disposable git repo. Offline modes
#          validate snapshots, parse saved stream-json, and compare two result
#          sets without network access.
#
# LOCAL-ONLY: a real live run needs `claude` auth and spends real tokens. It is
# never wired into tools/test-all.sh, any pre-commit/pre-push gate, or CI. CI
# exercises the same live control path only with a local fake `claude` binary;
# --help, --lint-fixtures, --dry-run, --list, --compare, and --parse-stream are
# offline and free.
#
# USAGE:
#   tools/journey-probe.sh [OPTIONS]
#   tools/journey-probe.sh --compare A.jsonl B.jsonl
#   tools/journey-probe.sh --parse-stream FILE [--journey ID]
#                           [--fixture NAME] [--expected "skillA,skillB"]
#   tools/journey-probe.sh --lint-fixtures
#   tools/journey-probe.sh --help
#
# OPTIONS:
#   --journeys J1,J8      Comma-separated journey IDs to run (default: all
#                         in test/fixtures/journeys/). An ID is the fixture
#                         filename prefix up to the first '-' (e.g. "J1b"
#                         from J1b-incident.txt).
#   --repeat N            Repeat each selected journey N times, each on a
#                         fresh throwaway fixture repo (default: 1).
#   --model NAME          Passed through to `claude --model` (default: the
#                         claude CLI's own default; the flag is omitted).
#   --max-turns N         Kill the run once main-thread assistant turns
#                         exceed N (default: 40). Enforced by this script --
#                         the claude CLI has no native --max-turns flag
#                         (verified via `claude --help`).
#   --timeout SEC         Wall-clock safety kill per run, in seconds
#                         (default: 900).
#   --max-budget-usd USD  Per-run Claude CLI cost ceiling (default: 0.50).
#   --permission-mode M   Explicit Claude permission mode (default: manual).
#   --config-dir DIR      Required for live and dry-run modes. The source root
#                         must not be a symlink. Claude receives a sealed,
#                         private copy through CLAUDE_CONFIG_DIR. Results store
#                         separate control-configuration and J8-J10 treatment-
#                         skill fingerprints, never the source or copy path.
#   --results-file FILE   JSONL output path (default:
#                         ~/.cache/superpowers-plus/journey-probes/
#                         <UTC timestamp>.jsonl).
#   --compare A.jsonl B.jsonl
#                         Compare compatible result files: verdict counts and
#                         per-journey median/worst context cost, then enforce
#                         the Phase 2 J8-J10 quality/token gate. Accepts only
#                         the fixed treatment-skill fingerprint changing;
#                         rejects all control drift and exits 1 on regression.
#   --parse-stream FILE   Re-derive one result record from an already
#                         captured stream-json file instead of calling claude.
#                         Requires the adjacent FILE.meta.json capture sidecar.
#   --journey ID          Optional assertion for --parse-stream.
#   --fixture NAME        Optional sidecar assertion for --parse-stream.
#   --expected "a,b"      Optional sidecar assertion for --parse-stream.
#   --lint-fixtures       Validate the complete fixture corpus and required
#                         J8-J11 journeys, then exit. Runs only python3.
#   --list                Validate, then print journey IDs and fixture files in
#                         deterministic order. Runs only python3.
#   --dry-run             Print the commands that would run (including the
#                         fixture-repo setup) and exit. Uses python3 for fixture
#                         validation; calls neither git nor claude.
#   -v, --verbose         Verbose logging to stderr; also keeps the raw
#                         stream-json transcript and immutable metadata
#                         sidecar for each run under <results dir>/raw/.
#   -h, --help            Show this help.
#
# COST WARNING: default live-run mode calls the real, authenticated `claude`
# CLI and spends real tokens against your account. Never run a real authenticated
# live probe from CI, a hook, or any unattended script. CI's live-path tests use
# a local fake executable and make no model or network calls.
#
# EXIT: 0 = completed/pass; 1 = malformed fixture/stream/result, incompatible
# comparison, or Phase 2 regression; 2 = command usage error. A measured FAIL
# verdict is data and does not make a completed live run exit non-zero.
# -----------------------------------------------------------------------------
set -euo pipefail
umask 077

# Nested git calls below (fixture repo creation) must not inherit a leaked
# GIT_DIR/GIT_WORK_TREE from the caller's environment -- see AGENTS.md's
# "leaked GIT_DIR" incident writeup.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_PREFIX 2>/dev/null || true

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
FIXTURE_SOURCE_DIR="${JOURNEY_PROBE_FIXTURES_DIR:-$REPO_ROOT/test/fixtures/journeys}"
FIXTURES_DIR=""
DEFAULT_RESULTS_DIR="$HOME/.cache/superpowers-plus/journey-probes"
DEFAULT_MAX_TURNS=40
DEFAULT_TIMEOUT=900
DEFAULT_MAX_BUDGET_USD="0.50"
DEFAULT_PERMISSION_MODE="manual"

VERBOSE=0
DRY_RUN=0
LIST_ONLY=0
LINT_FIXTURES=0
JOURNEYS=""
REPEAT=1
MODEL=""
MAX_TURNS="$DEFAULT_MAX_TURNS"
TIMEOUT_SEC="$DEFAULT_TIMEOUT"
MAX_BUDGET_USD="$DEFAULT_MAX_BUDGET_USD"
PERMISSION_MODE="$DEFAULT_PERMISSION_MODE"
CONFIG_DIR=""
RESULTS_FILE=""
COMPARE_A=""
COMPARE_B=""
PARSE_STREAM_FILE=""
PS_JOURNEY=""
PS_FIXTURE=""
PS_EXPECTED=""
FIXTURE_SNAPSHOT_DIR=""
FIXTURE_SNAPSHOT_PARENT=""
CONFIG_SNAPSHOT_DIR=""
CONFIG_SNAPSHOT_PARENT=""
RUN_RECORDS_FILE=""
CURRENT_FIXTURE_REPO=""

usage() {
  awk 'NR>1 && /^#/ {sub(/^# ?/,""); print; next} NR>1 {exit}' "$0"
}

log() { [[ "$VERBOSE" -eq 1 ]] && echo "[journey-probe] $*" >&2 || true; }
die() { echo "ERROR: $*" >&2; exit 2; }
data_die() { echo "ERROR: $*" >&2; exit 1; }
require_cmd() { command -v "$1" >/dev/null 2>&1 || die "$1 not found on PATH"; }

require_option_value() {
  local option="$1"
  local value="${2:-}"
  [[ -n "$value" && "$value" != -* ]] || die "$option requires a value"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    -v|--verbose) VERBOSE=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    --list) LIST_ONLY=1; shift ;;
    --lint-fixtures) LINT_FIXTURES=1; shift ;;
    --journeys)
      require_option_value "$1" "${2:-}"
      JOURNEYS="$2"; shift 2 ;;
    --repeat)
      require_option_value "$1" "${2:-}"
      REPEAT="$2"; shift 2 ;;
    --model)
      require_option_value "$1" "${2:-}"
      MODEL="$2"; shift 2 ;;
    --max-turns)
      require_option_value "$1" "${2:-}"
      MAX_TURNS="$2"; shift 2 ;;
    --timeout)
      require_option_value "$1" "${2:-}"
      TIMEOUT_SEC="$2"; shift 2 ;;
    --max-budget-usd)
      require_option_value "$1" "${2:-}"
      MAX_BUDGET_USD="$2"; shift 2 ;;
    --permission-mode)
      require_option_value "$1" "${2:-}"
      PERMISSION_MODE="$2"; shift 2 ;;
    --config-dir)
      require_option_value "$1" "${2:-}"
      CONFIG_DIR="$2"; shift 2 ;;
    --results-file)
      require_option_value "$1" "${2:-}"
      RESULTS_FILE="$2"; shift 2 ;;
    --compare)
      if [[ -z "${2:-}" || "${2:-}" == -* || -z "${3:-}" || "${3:-}" == -* ]]; then
        die "--compare requires two files: --compare A.jsonl B.jsonl"
      fi
      COMPARE_A="$2"; COMPARE_B="$3"; shift 3 ;;
    --parse-stream)
      require_option_value "$1" "${2:-}"
      PARSE_STREAM_FILE="$2"; shift 2 ;;
    --journey)
      require_option_value "$1" "${2:-}"
      PS_JOURNEY="$2"; shift 2 ;;
    --fixture)
      require_option_value "$1" "${2:-}"
      PS_FIXTURE="$2"; shift 2 ;;
    --expected)
      require_option_value "$1" "${2:-}"
      PS_EXPECTED="$2"; shift 2 ;;
    *) die "Unknown flag: $1 (see --help)" ;;
  esac
done

PRIMARY_MODE_COUNT=$((DRY_RUN + LIST_ONLY + LINT_FIXTURES))
[[ -z "$COMPARE_A" ]] || PRIMARY_MODE_COUNT=$((PRIMARY_MODE_COUNT + 1))
[[ -z "$PARSE_STREAM_FILE" ]] || PRIMARY_MODE_COUNT=$((PRIMARY_MODE_COUNT + 1))
if [[ "$PRIMARY_MODE_COUNT" -gt 1 ]]; then
  die "choose exactly one primary mode: live (default), --dry-run, --list, --lint-fixtures, --compare, or --parse-stream"
fi
if [[ -z "$PARSE_STREAM_FILE" ]]; then
  [[ -z "$PS_JOURNEY" ]] || die "--journey is valid only with --parse-stream"
  [[ -z "$PS_FIXTURE" ]] || die "--fixture is valid only with --parse-stream"
  [[ -z "$PS_EXPECTED" ]] || die "--expected is valid only with --parse-stream"
fi

# ---------------------------------------------------------------------------
# Embedded python helper. Owns all stream-json parsing and the claude
# subprocess (mode "run"). Dispatched by argv[0] (the mode name); "$@" from
# the caller becomes sys.argv[1:].
# ---------------------------------------------------------------------------
py() {
  python3 - "$@" <<'PYEOF'
import argparse
import base64
import hashlib
import json
import math
import os
from pathlib import Path
import re
import select
import signal
import stat
import statistics
import subprocess
import sys
import time
from datetime import datetime, timezone

TOKEN_KEYS = (
    "input_tokens",
    "output_tokens",
    "cache_creation_input_tokens",
    "cache_read_input_tokens",
)
SCHEMA_VERSION = 3
REQUIRED_JOURNEYS = ("J8", "J9", "J10", "J11")
PHASE2_JOURNEYS = ("J8", "J9", "J10")
TREATMENT_SKILL_PATHS = (
    "skills/context-ferry",
    "skills/sp-debate",
    "skills/sp-phr",
)
JOURNEY_FILE_RE = re.compile(r"(J[0-9]+[a-z]?)-([a-z0-9][a-z0-9-]*)[.]txt")
SKILL_RE = re.compile(r"[a-z0-9][a-z0-9-]*")
SHA256_RE = re.compile(r"[0-9a-f]{64}")
UTC_TIMESTAMP_RE = re.compile(r"[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z")
VERDICTS = ("PASS", "PASS_WITH_NITS", "FAIL")
VERDICT_RANK = {"FAIL": 0, "PASS_WITH_NITS": 1, "PASS": 2}
PERMISSION_MODES = (
    "acceptEdits", "auto", "bypassPermissions", "manual", "dontAsk", "plan"
)


def die(msg, code=1):
    print(f"ERROR: {msg}", file=sys.stderr)
    sys.exit(code)


def now_iso():
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def empty_tokens():
    return {k: 0 for k in TOKEN_KEYS}


def add_usage(acc, usage):
    if not isinstance(usage, dict):
        return
    for k in TOKEN_KEYS:
        v = usage.get(k)
        if isinstance(v, (int, float)):
            acc[k] += v


def reject_json_constant(value):
    raise ValueError(f"non-standard JSON constant {value}")


def split_csv(s):
    return [x.strip() for x in (s or "").split(",") if x.strip()]


def journey_sort_key(journey_id):
    match = re.fullmatch(r"J([0-9]+)([a-z]?)", journey_id)
    if not match:
        return (sys.maxsize, journey_id)
    return (int(match.group(1)), match.group(2))


def read_regular_file(path, label):
    flags = os.O_RDONLY | getattr(os, "O_NONBLOCK", 0)
    if hasattr(os, "O_NOFOLLOW"):
        flags |= os.O_NOFOLLOW
    try:
        descriptor = os.open(path, flags)
    except OSError as exc:
        die(f"{label} must be an accessible regular file ({exc})")
    try:
        if not stat.S_ISREG(os.fstat(descriptor).st_mode):
            die(f"{label} must be a regular file")
        with os.fdopen(descriptor, "rb") as source:
            descriptor = -1
            return source.read()
    finally:
        if descriptor >= 0:
            os.close(descriptor)


def load_fixtures(directory):
    root = Path(directory)
    if not root.is_dir():
        die(f"fixture directory does not exist: {root}")

    fixtures = []
    by_id = {}
    for path in sorted(root.glob("*.txt"), key=lambda item: item.name):
        match = JOURNEY_FILE_RE.fullmatch(path.name)
        if not match:
            die(f"{path.name}: filename must match J<number>[suffix]-<slug>.txt")
        journey_id = match.group(1)
        if journey_id in by_id:
            die(
                f"duplicate journey ID {journey_id}: "
                f"{by_id[journey_id]['name']} and {path.name}"
            )

        raw_bytes = read_regular_file(path, path.name)
        try:
            text = raw_bytes.decode("utf-8")
        except UnicodeDecodeError as exc:
            die(f"{path.name}: fixture is not valid UTF-8 ({exc})")
        if "\x00" in text:
            die(f"{path.name}: fixture contains a NUL byte")
        lines = text.splitlines()
        if not lines:
            die(f"{path.name}: fixture is empty")
        metadata = re.fullmatch(
            r"# expect: ([a-z0-9][a-z0-9-]*(?:,[a-z0-9][a-z0-9-]*)*)",
            lines[0],
        )
        if not metadata:
            die(
                f"{path.name}:1: expected '# expect: skill-name[,skill-name]' "
                "with lowercase hyphenated skill names"
            )
        expected = metadata.group(1).split(",")
        if len(expected) != len(set(expected)):
            die(f"{path.name}:1: duplicate skill in # expect metadata")
        if not "\n".join(lines[1:]).strip():
            die(f"{path.name}: prompt body is empty")
        newline_index = raw_bytes.find(b"\n")
        if newline_index < 0:
            die(f"{path.name}: prompt body is empty")
        prompt_bytes = raw_bytes[newline_index + 1 :]

        fixture = {
            "id": journey_id,
            "name": path.name,
            "path": str(path),
            "expected": expected,
            "expected_csv": ",".join(expected),
            "sha256": hashlib.sha256(raw_bytes).hexdigest(),
            "prompt_b64": base64.b64encode(prompt_bytes).decode("ascii"),
        }
        fixtures.append(fixture)
        by_id[journey_id] = fixture

    if not fixtures:
        die(f"fixture directory contains no .txt fixtures: {root}")
    for journey_id in REQUIRED_JOURNEYS:
        if journey_id not in by_id:
            die(f"missing required journey fixture: {journey_id}")

    fixtures.sort(key=lambda item: journey_sort_key(item["id"]))
    return fixtures


def validate_nonnegative_integer(value, label):
    if isinstance(value, bool) or not isinstance(value, int) or value < 0:
        raise ValueError(f"{label} must be a non-negative integer")


def validate_usage(usage, label):
    if not isinstance(usage, dict):
        raise ValueError(f"{label} must be an object")
    for key in TOKEN_KEYS:
        if key not in usage:
            raise ValueError(f"{label} is missing {key}")
        validate_nonnegative_integer(usage[key], f"{label}.{key}")


def decode_event(raw_line, source, line_number):
    try:
        event = json.loads(raw_line, parse_constant=reject_json_constant)
    except json.JSONDecodeError as exc:
        raise ValueError(f"{source}:{line_number}: invalid JSON ({exc})") from exc
    except ValueError as exc:
        raise ValueError(f"{source}:{line_number}: {exc}") from exc
    if not isinstance(event, dict):
        raise ValueError(f"{source}:{line_number}: event must be a JSON object")
    return event


class StreamState:
    """Accumulates skill invocations, token usage, and turn count from a
    stream-json event sequence. Shared by the offline parser and the live
    subprocess runner so both paths are exercised by the same logic."""

    def __init__(self):
        self.skills_main = []
        self.skills_sub = []
        self.tokens_main = empty_tokens()
        self.tokens_sub = empty_tokens()
        self.main_turns = 0
        self.result_num_turns = None
        self.result_duration_ms = None
        self.result_subtype = None
        self.result_usage = None
        self.result_count = 0
        self.result_is_error = None
        self.observed_model = None
        self.init_count = 0
        self.event_count = 0

    def process_event(self, event):
        if self.result_count:
            raise ValueError("result event must be terminal")
        self.event_count += 1
        etype = event.get("type")
        is_sub = event.get("parent_tool_use_id") is not None
        if etype == "system" and event.get("subtype") == "init":
            self.init_count += 1
            if self.init_count > 1:
                raise ValueError("stream must contain exactly one system init event")
            if self.event_count != 1:
                raise ValueError("system init event must be first")
            model = event.get("model")
            if not isinstance(model, str) or not model:
                raise ValueError("system init model must be a non-empty string")
            self.observed_model = model
            return
        if self.init_count != 1:
            raise ValueError("system init event must be first")
        if etype == "assistant":
            msg = event.get("message")
            if not isinstance(msg, dict):
                raise ValueError("assistant event message must be an object")
            usage = msg.get("usage")
            if usage is not None:
                validate_usage(usage, "assistant message usage")
            content = msg.get("content")
            if not isinstance(content, list):
                raise ValueError("assistant event content must be an array")
            if is_sub:
                add_usage(self.tokens_sub, usage)
            else:
                add_usage(self.tokens_main, usage)
                self.main_turns += 1
            for block in content:
                if not isinstance(block, dict):
                    raise ValueError("assistant content block must be an object")
                if block.get("type") == "tool_use" and block.get("name") == "Skill":
                    inp = block.get("input")
                    skill_name = inp.get("skill") if isinstance(inp, dict) else None
                    if not isinstance(skill_name, str) or not SKILL_RE.fullmatch(skill_name):
                        raise ValueError("Skill tool call has an invalid skill name")
                    (self.skills_sub if is_sub else self.skills_main).append(skill_name)
        elif etype == "result":
            self.result_count += 1
            if self.result_count > 1:
                raise ValueError("stream must contain exactly one result event")
            self.result_num_turns = event.get("num_turns")
            self.result_duration_ms = event.get("duration_ms")
            self.result_subtype = event.get("subtype")
            self.result_usage = event.get("usage")
            self.result_is_error = event.get("is_error")

    def finalize(self, wall_time_fallback=None):
        if self.init_count != 1:
            raise ValueError("stream must contain exactly one system init event")
        if self.result_count != 1:
            raise ValueError("stream must contain exactly one result event")
        validate_nonnegative_integer(self.result_num_turns, "result.num_turns")
        if (
            isinstance(self.result_duration_ms, bool)
            or not isinstance(self.result_duration_ms, (int, float))
            or not math.isfinite(self.result_duration_ms)
            or self.result_duration_ms < 0
        ):
            raise ValueError("result.duration_ms must be a non-negative number")
        if not isinstance(self.result_subtype, str) or not self.result_subtype:
            raise ValueError("result.subtype must be a non-empty string")
        if not isinstance(self.result_is_error, bool):
            raise ValueError("result.is_error must be a boolean")
        validate_usage(self.result_usage, "result.usage")
        num_turns = self.result_num_turns if self.result_num_turns is not None else self.main_turns
        duration_ms = self.result_duration_ms
        wall_time = duration_ms / 1000.0 if isinstance(duration_ms, (int, float)) else wall_time_fallback
        if isinstance(self.result_usage, dict):
            tokens_main = empty_tokens()
            add_usage(tokens_main, self.result_usage)
        else:
            tokens_main = self.tokens_main
        return {
            "skills_main": self.skills_main,
            "skills_sub": self.skills_sub,
            "tokens_main": tokens_main,
            "tokens_sub": self.tokens_sub,
            "num_turns": num_turns,
            "wall_time_sec": wall_time,
            "result_subtype": self.result_subtype,
            "result_is_error": self.result_is_error,
            "reported_usage": self.result_usage,
            "observed_model": self.observed_model,
        }


def validate_capture_metadata(meta):
    if not isinstance(meta, dict):
        raise ValueError("capture metadata must be a JSON object")
    required = {
        "schema_version", "captured_at", "journey", "fixture", "fixture_sha256",
        "expected_skills", "repeat_index", "repeat_count", "requested_model",
        "control_config_fingerprint", "treatment_skill_fingerprint",
        "claude_cli_version", "permission_mode",
        "max_budget_usd", "max_turns", "timeout_sec",
    }
    missing = sorted(required - set(meta))
    extra = sorted(set(meta) - required)
    if missing:
        raise ValueError(f"capture metadata is missing {missing[0]}")
    if extra:
        raise ValueError(f"capture metadata contains unsupported field {extra[0]}")
    if meta["schema_version"] != SCHEMA_VERSION:
        raise ValueError(f"capture metadata schema_version must be {SCHEMA_VERSION}")
    if not isinstance(meta["captured_at"], str) or not UTC_TIMESTAMP_RE.fullmatch(
        meta["captured_at"]
    ):
        raise ValueError("capture metadata captured_at must be a UTC timestamp")
    if not isinstance(meta["journey"], str) or not re.fullmatch(
        r"J[0-9]+[a-z]?", meta["journey"]
    ):
        raise ValueError("capture metadata journey must match J<number>[suffix]")
    if not isinstance(meta["fixture"], str):
        raise ValueError("capture metadata fixture must be a string")
    fixture_match = JOURNEY_FILE_RE.fullmatch(meta["fixture"])
    if not fixture_match or fixture_match.group(1) != meta["journey"]:
        raise ValueError("capture metadata fixture does not match journey")
    if not isinstance(meta["fixture_sha256"], str) or not SHA256_RE.fullmatch(
        meta["fixture_sha256"]
    ):
        raise ValueError("capture metadata fixture_sha256 must be lowercase SHA-256")
    skills = meta["expected_skills"]
    if not isinstance(skills, list) or not skills or not all(
        isinstance(skill, str) and SKILL_RE.fullmatch(skill) for skill in skills
    ):
        raise ValueError("capture metadata expected_skills must be a non-empty skill array")
    if len(skills) != len(set(skills)):
        raise ValueError("capture metadata expected_skills must not contain duplicates")
    validate_nonnegative_integer(meta["repeat_index"], "capture metadata repeat_index")
    if meta["repeat_index"] < 1:
        raise ValueError("capture metadata repeat_index must be at least 1")
    validate_nonnegative_integer(meta["repeat_count"], "capture metadata repeat_count")
    if meta["repeat_count"] < 1:
        raise ValueError("capture metadata repeat_count must be at least 1")
    if meta["repeat_index"] > meta["repeat_count"]:
        raise ValueError("capture metadata repeat_index exceeds repeat_count")
    requested_model = meta["requested_model"]
    if requested_model is not None and (
        not isinstance(requested_model, str) or not requested_model
    ):
        raise ValueError("capture metadata requested_model must be null or non-empty")
    for field in ("control_config_fingerprint", "treatment_skill_fingerprint"):
        if not isinstance(meta[field], str) or not SHA256_RE.fullmatch(meta[field]):
            raise ValueError(f"capture metadata {field} must be lowercase SHA-256")
    if not isinstance(meta["claude_cli_version"], str) or not meta["claude_cli_version"]:
        raise ValueError("capture metadata claude_cli_version must be non-empty")
    if meta["permission_mode"] not in PERMISSION_MODES:
        raise ValueError("capture metadata permission_mode is invalid")
    budget = meta["max_budget_usd"]
    if (
        isinstance(budget, bool)
        or not isinstance(budget, (int, float))
        or not math.isfinite(budget)
        or budget <= 0
    ):
        raise ValueError("capture metadata max_budget_usd must be positive")
    validate_nonnegative_integer(meta["max_turns"], "capture metadata max_turns")
    if meta["max_turns"] < 1:
        raise ValueError("capture metadata max_turns must be at least 1")
    timeout = meta["timeout_sec"]
    if (
        isinstance(timeout, bool)
        or not isinstance(timeout, (int, float))
        or not math.isfinite(timeout)
        or timeout <= 0
    ):
        raise ValueError("capture metadata timeout_sec must be positive")
    return meta


def load_capture_metadata(path):
    try:
        with open(path, "r", encoding="utf-8") as source:
            meta = json.load(source, parse_constant=reject_json_constant)
    except OSError as exc:
        die(f"cannot read metadata sidecar: {exc}")
    except json.JSONDecodeError as exc:
        die(f"metadata sidecar contains invalid JSON ({exc})")
    except ValueError as exc:
        die(f"metadata sidecar contains {exc}")
    try:
        return validate_capture_metadata(meta)
    except ValueError as exc:
        die(str(exc))


def open_private_exclusive(path):
    descriptor = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    return os.fdopen(descriptor, "w", encoding="utf-8")


def write_capture_metadata(path, meta):
    try:
        destination = open_private_exclusive(path)
    except FileExistsError:
        die("metadata sidecar already exists; refusing to overwrite it")
    except OSError as exc:
        die(f"cannot create metadata sidecar: {exc}")
    with destination:
        json.dump(meta, destination, indent=2, sort_keys=True)
        destination.write("\n")
        destination.flush()
        os.fsync(destination.fileno())


def build_record(meta, summary):
    expected = meta["expected_skills"]
    actual_main = summary["skills_main"]
    actual_sub = summary["skills_sub"]
    actual_unique = list(dict.fromkeys(actual_main + actual_sub))
    actual_set = set(actual_unique)
    missing = [s for s in expected if s not in actual_set]
    unexpected = [s for s in actual_unique if s not in expected]
    matched_count = len(expected) - len(missing)
    recall = matched_count / len(expected) if expected else 0.0
    precision = matched_count / len(actual_unique) if actual_unique else 0.0
    exit_status = meta.get("exit_status")
    if not exit_status:
        exit_status = summary["result_subtype"]
    verdict_reasons = []
    if exit_status != "success" or summary["result_is_error"]:
        verdict_reasons.append(f"exit_status:{exit_status}")
    if missing:
        verdict_reasons.append("missing_skills")
    if unexpected:
        verdict_reasons.append("unexpected_skills")
    if any(reason != "unexpected_skills" for reason in verdict_reasons):
        verdict = "FAIL"
    elif unexpected:
        verdict = "PASS_WITH_NITS"
    else:
        verdict = "PASS"

    usage = summary["reported_usage"]
    context_tokens = (
        usage["input_tokens"]
        + usage["cache_creation_input_tokens"]
        + usage["cache_read_input_tokens"]
    )
    output_tokens = usage["output_tokens"]
    return {
        "schema_version": SCHEMA_VERSION,
        "timestamp": meta["captured_at"],
        "journey": meta["journey"],
        "fixture": meta["fixture"],
        "fixture_sha256": meta["fixture_sha256"],
        "observed_model": summary["observed_model"],
        "requested_model": meta["requested_model"],
        "repeat_index": meta["repeat_index"],
        "repeat_count": meta["repeat_count"],
        "control_config_fingerprint": meta["control_config_fingerprint"],
        "treatment_skill_fingerprint": meta["treatment_skill_fingerprint"],
        "claude_cli_version": meta["claude_cli_version"],
        "permission_mode": meta["permission_mode"],
        "max_budget_usd": meta["max_budget_usd"],
        "max_turns": meta["max_turns"],
        "timeout_sec": meta["timeout_sec"],
        "expected_skills": expected,
        "actual_skills_main": actual_main,
        "actual_skills_subagent": actual_sub,
        "missing_skills": missing,
        "unexpected_skills": unexpected,
        "verdict": verdict,
        "verdict_reasons": verdict_reasons,
        "quality": {
            "expected_count": len(expected),
            "actual_unique_count": len(actual_unique),
            "matched_count": matched_count,
            "recall": round(recall, 6),
            "precision": round(precision, 6),
        },
        "reported_usage": usage,
        "cost": {
            "context_tokens": context_tokens,
            "output_tokens": output_tokens,
            "total_tokens": context_tokens + output_tokens,
        },
        "observed_usage": {
            "main_assistant": summary["tokens_main"],
            "subagent_assistant": summary["tokens_sub"],
        },
        "num_turns": summary["num_turns"],
        "wall_time_sec": summary["wall_time_sec"],
        "exit_status": exit_status,
        "result_is_error": summary["result_is_error"],
    }


def cmd_parse_stream(args):
    meta = load_capture_metadata(args.metadata_file)
    if args.assert_journey and args.assert_journey != meta["journey"]:
        die("--journey does not match the immutable metadata sidecar")
    if args.assert_fixture and args.assert_fixture != meta["fixture"]:
        die("--fixture does not match the immutable metadata sidecar")
    if args.assert_expected and split_csv(args.assert_expected) != meta["expected_skills"]:
        die("--expected does not match the immutable metadata sidecar")
    if args.file:
        try:
            with open(args.file, "r", encoding="utf-8") as fh:
                lines = fh.readlines()
        except OSError as exc:
            die(f"cannot read stream file: {exc}")
    else:
        lines = sys.stdin.readlines()
    state = StreamState()
    for line_number, line in enumerate(lines, start=1):
        line = line.strip()
        if not line:
            continue
        try:
            event = decode_event(line, args.file or "<stdin>", line_number)
            state.process_event(event)
        except ValueError as exc:
            die(str(exc))
    try:
        summary = state.finalize(wall_time_fallback=None)
    except ValueError as exc:
        die(f"{args.file or '<stdin>'}: {exc}")
    meta = dict(meta)
    meta["exit_status"] = None
    record = build_record(meta, summary)
    print(json.dumps(record))


PROCESS_GROUP_TERM_GRACE_SEC = 0.25
PROCESS_GROUP_REAP_GRACE_SEC = 0.5


def terminate_process_group(proc, deadline):
    # proc is an unreaped supervisor and the process-group leader. Keeping that
    # PID reserved until all group signals are sent prevents a recycled PGID
    # from receiving cleanup intended for this run.
    try:
        os.killpg(proc.pid, signal.SIGTERM)
    except (ProcessLookupError, PermissionError):
        pass

    remaining = max(0.0, deadline - time.monotonic())
    term_grace = min(PROCESS_GROUP_TERM_GRACE_SEC, remaining)
    if term_grace:
        time.sleep(term_grace)

    try:
        os.killpg(proc.pid, signal.SIGKILL)
    except (ProcessLookupError, PermissionError):
        pass
    try:
        proc.wait(timeout=PROCESS_GROUP_REAP_GRACE_SEC)
    except subprocess.TimeoutExpired as exc:
        raise RuntimeError("Claude process-group supervisor could not be reaped") from exc


SUPERVISOR_CODE = r'''
import json
import os
import signal
import subprocess
import sys

status_fd = int(sys.argv[1])
message = {"kind": "spawn_error"}
try:
    payload = json.loads(sys.stdin.buffer.readline())
    child = subprocess.Popen(
        payload["cmd"],
        cwd=payload["cwd"],
        env=os.environ.copy(),
    )
    message = {"kind": "exit", "returncode": child.wait()}
except BaseException:
    message = {"kind": "spawn_error"}
finally:
    try:
        os.write(status_fd, json.dumps(message, separators=(",", ":")).encode() + b"\n")
    finally:
        os.close(status_fd)
        os.close(1)

while True:
    signal.pause()
'''


def cmd_run(args):
    try:
        prompt_text = base64.b64decode(
            args.prompt_b64.encode("ascii"), validate=True
        ).decode("utf-8")
    except (UnicodeDecodeError, UnicodeEncodeError, ValueError) as exc:
        die(f"internal prompt payload is invalid: {exc}")

    cmd = [
        "claude", "-p", prompt_text,
        "--output-format", "stream-json",
        "--verbose",
        "--forward-subagent-text",
        "--no-session-persistence",
        "--permission-mode", args.permission_mode,
        "--max-budget-usd", str(args.max_budget_usd),
    ]
    if args.model:
        cmd += ["--model", args.model]

    env = os.environ.copy()
    for key in list(env):
        if key.startswith("GIT_"):
            del env[key]
    env["GIT_CONFIG_NOSYSTEM"] = "1"
    env["GIT_CONFIG_GLOBAL"] = "/dev/null"
    env["CLAUDE_CONFIG_DIR"] = args.config_dir

    meta = {
        "schema_version": SCHEMA_VERSION,
        "captured_at": now_iso(),
        "journey": args.journey,
        "fixture": args.fixture,
        "fixture_sha256": args.fixture_sha256,
        "expected_skills": split_csv(args.expected),
        "repeat_index": args.repeat_index,
        "repeat_count": args.repeat_count,
        "requested_model": args.model or None,
        "control_config_fingerprint": args.control_config_fingerprint,
        "treatment_skill_fingerprint": args.treatment_skill_fingerprint,
        "claude_cli_version": args.claude_cli_version,
        "permission_mode": args.permission_mode,
        "max_budget_usd": args.max_budget_usd,
        "max_turns": args.max_turns,
        "timeout_sec": args.timeout_sec,
    }
    try:
        validate_capture_metadata(meta)
    except ValueError as exc:
        die(str(exc))

    raw_fh = None
    stderr_fh = subprocess.DEVNULL
    if args.raw_out:
        write_capture_metadata(args.raw_out + ".meta.json", meta)
        try:
            raw_fh = open_private_exclusive(args.raw_out)
            stderr_fh = open_private_exclusive(args.raw_out + ".stderr.log")
        except FileExistsError:
            die("raw output already exists; refusing to overwrite it")
        except OSError as exc:
            die(f"cannot create private raw output: {exc}")

    state = StreamState()
    status = None
    stream_error = None
    stream_line_number = 0
    stream_buffer = bytearray()

    def handle_line(raw_line):
        nonlocal stream_line_number
        stream_line_number += 1
        if raw_fh:
            raw_fh.write(raw_line)
        s = raw_line.strip()
        if not s:
            return
        event = decode_event(s, "claude stream", stream_line_number)
        state.process_event(event)

    def handle_chunk(chunk):
        stream_buffer.extend(chunk)
        while True:
            newline_index = stream_buffer.find(b"\n")
            if newline_index < 0:
                return False
            raw_bytes = bytes(stream_buffer[: newline_index + 1])
            del stream_buffer[: newline_index + 1]
            try:
                raw_line = raw_bytes.decode("utf-8")
            except UnicodeDecodeError as exc:
                raise ValueError(f"claude stream is not valid UTF-8 ({exc})") from exc
            handle_line(raw_line)
            if state.result_count == 0 and state.main_turns > args.max_turns:
                return True

    def handle_final_buffer():
        if not stream_buffer:
            return False
        raw_bytes = bytes(stream_buffer)
        stream_buffer.clear()
        try:
            raw_line = raw_bytes.decode("utf-8")
        except UnicodeDecodeError as exc:
            raise ValueError(f"claude stream is not valid UTF-8 ({exc})") from exc
        handle_line(raw_line)
        return state.result_count == 0 and state.main_turns > args.max_turns

    status_read_fd, status_write_fd = os.pipe()
    os.set_inheritable(status_write_fd, True)
    start = time.monotonic()
    deadline = start + args.timeout_sec
    try:
        proc = subprocess.Popen(
            [sys.executable, "-c", SUPERVISOR_CODE, str(status_write_fd)],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=stderr_fh,
            env=env,
            start_new_session=True,
            pass_fds=(status_write_fd,),
        )
    except OSError as exc:
        os.close(status_read_fd)
        os.close(status_write_fd)
        if raw_fh:
            raw_fh.close()
        if stderr_fh is not subprocess.DEVNULL:
            stderr_fh.close()
        die(f"cannot start Claude process-group supervisor: {exc}")
    os.close(status_write_fd)

    stdout_fd = proc.stdout.fileno()
    os.set_blocking(stdout_fd, False)
    os.set_blocking(status_read_fd, False)
    child_returncode = None
    supervisor_error = None
    cleanup_error = None
    stdout_eof = False
    status_eof = False
    status_buffer = bytearray()

    def handle_status_chunk(chunk):
        nonlocal child_returncode, supervisor_error
        status_buffer.extend(chunk)
        newline_index = status_buffer.find(b"\n")
        if newline_index < 0:
            return
        if child_returncode is not None or supervisor_error is not None:
            raise ValueError("Claude supervisor emitted duplicate status")
        raw_status = bytes(status_buffer[:newline_index])
        del status_buffer[: newline_index + 1]
        if status_buffer:
            raise ValueError("Claude supervisor emitted trailing status data")
        try:
            message = json.loads(raw_status)
        except (UnicodeDecodeError, json.JSONDecodeError) as exc:
            raise ValueError("Claude supervisor emitted malformed status") from exc
        if message == {"kind": "spawn_error"}:
            supervisor_error = "cannot start claude CLI"
            return
        if not isinstance(message, dict) or message.get("kind") != "exit":
            raise ValueError("Claude supervisor emitted unsupported status")
        returncode = message.get("returncode")
        if isinstance(returncode, bool) or not isinstance(returncode, int):
            raise ValueError("Claude supervisor emitted invalid exit status")
        child_returncode = returncode

    try:
        payload = json.dumps(
            {"cmd": cmd, "cwd": args.cwd},
            ensure_ascii=False,
            separators=(",", ":"),
        ).encode("utf-8") + b"\n"
        proc.stdin.write(payload)
        proc.stdin.close()

        while status is None and stream_error is None and supervisor_error is None:
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                status = "timeout"
                break

            descriptors = []
            if not stdout_eof:
                descriptors.append(stdout_fd)
            if not status_eof:
                descriptors.append(status_read_fd)
            if not descriptors:
                supervisor_error = "Claude supervisor exited without status"
                break

            ready, _, _ = select.select(descriptors, [], [], min(remaining, 0.25))
            for descriptor in ready:
                try:
                    chunk = os.read(descriptor, 65536)
                except BlockingIOError:
                    continue
                if descriptor == stdout_fd:
                    if not chunk:
                        stdout_eof = True
                    elif handle_chunk(chunk):
                        status = "max_turns_exceeded"
                        break
                elif not chunk:
                    status_eof = True
                else:
                    handle_status_chunk(chunk)

            if child_returncode is not None:
                status = "success" if child_returncode == 0 else "error"
            elif status_eof and supervisor_error is None:
                supervisor_error = "Claude supervisor exited without status"
    except (BrokenPipeError, OSError) as exc:
        supervisor_error = f"Claude supervisor communication failed: {exc}"
    except ValueError as exc:
        stream_error = str(exc)
    finally:
        try:
            terminate_process_group(proc, deadline)
        except RuntimeError as exc:
            cleanup_error = str(exc)

        # The group is gone and the supervisor is reaped, so only already
        # buffered stream bytes can remain. Drain them without starting a new
        # wait budget, then validate the final partial line if present.
        try:
            while not stdout_eof:
                try:
                    chunk = os.read(stdout_fd, 65536)
                except BlockingIOError:
                    break
                if not chunk:
                    stdout_eof = True
                    break
                if handle_chunk(chunk) and status is None:
                    status = "max_turns_exceeded"
            if stream_error is None and handle_final_buffer() and status is None:
                status = "max_turns_exceeded"
        except ValueError as exc:
            stream_error = str(exc)

        proc.stdout.close()
        os.close(status_read_fd)
        if raw_fh:
            raw_fh.close()
        if stderr_fh is not subprocess.DEVNULL:
            stderr_fh.close()

    if stream_error:
        die(stream_error)
    if supervisor_error:
        die(supervisor_error)
    if cleanup_error:
        die(cleanup_error)
    wall = time.monotonic() - start
    try:
        summary = state.finalize(wall_time_fallback=wall)
    except ValueError as exc:
        die(f"claude stream: {exc}")
    meta["exit_status"] = status
    record = build_record(meta, summary)
    print(json.dumps(record))


def validate_skill_list(value, label, allow_duplicates=False):
    if not isinstance(value, list) or not all(
        isinstance(item, str) and SKILL_RE.fullmatch(item) for item in value
    ):
        raise ValueError(f"{label} must be an array of lowercase skill names")
    if not allow_duplicates and len(value) != len(set(value)):
        raise ValueError(f"{label} must not contain duplicates")


def expected_verdict(exit_status, result_is_error, missing, unexpected):
    reasons = []
    if exit_status != "success" or result_is_error:
        reasons.append(f"exit_status:{exit_status}")
    if missing:
        reasons.append("missing_skills")
    if unexpected:
        reasons.append("unexpected_skills")
    if any(reason != "unexpected_skills" for reason in reasons):
        return "FAIL", reasons
    if unexpected:
        return "PASS_WITH_NITS", reasons
    return "PASS", reasons


def validate_record(record):
    if not isinstance(record, dict):
        raise ValueError("record must be a JSON object")
    required = {
        "schema_version", "timestamp", "journey", "fixture", "fixture_sha256",
        "observed_model", "requested_model", "repeat_index", "repeat_count",
        "control_config_fingerprint", "treatment_skill_fingerprint",
        "claude_cli_version", "permission_mode", "max_budget_usd", "max_turns",
        "timeout_sec", "expected_skills", "actual_skills_main",
        "actual_skills_subagent", "missing_skills", "unexpected_skills",
        "verdict", "verdict_reasons", "quality", "reported_usage", "cost", "observed_usage",
        "num_turns", "wall_time_sec", "exit_status", "result_is_error",
    }
    missing_fields = sorted(required - set(record))
    extra_fields = sorted(set(record) - required)
    if missing_fields:
        raise ValueError(f"missing required field '{missing_fields[0]}'")
    if extra_fields:
        raise ValueError(f"unsupported field '{extra_fields[0]}'")

    if record["schema_version"] != SCHEMA_VERSION:
        raise ValueError(
            f"schema_version must be {SCHEMA_VERSION} (got {record['schema_version']!r})"
        )
    if not isinstance(record["timestamp"], str) or not UTC_TIMESTAMP_RE.fullmatch(
        record["timestamp"]
    ):
        raise ValueError("timestamp must be a UTC timestamp")
    if not isinstance(record["journey"], str) or not re.fullmatch(
        r"J[0-9]+[a-z]?", record["journey"]
    ):
        raise ValueError("journey must match J<number>[suffix]")
    if not isinstance(record["fixture"], str) or not record["fixture"]:
        raise ValueError("fixture must be a non-empty string")
    fixture_match = JOURNEY_FILE_RE.fullmatch(record["fixture"])
    if not fixture_match or fixture_match.group(1) != record["journey"]:
        raise ValueError("fixture filename does not match journey")
    if not isinstance(record["fixture_sha256"], str) or not SHA256_RE.fullmatch(
        record["fixture_sha256"]
    ):
        raise ValueError("fixture_sha256 must be 64 lowercase hex characters")
    if not isinstance(record["observed_model"], str) or not record["observed_model"]:
        raise ValueError("observed_model must be a non-empty string")
    if record["requested_model"] is not None and (
        not isinstance(record["requested_model"], str)
        or not record["requested_model"]
    ):
        raise ValueError("requested_model must be null or a non-empty string")
    for field in ("control_config_fingerprint", "treatment_skill_fingerprint"):
        if not isinstance(record[field], str) or not SHA256_RE.fullmatch(record[field]):
            raise ValueError(f"{field} must be 64 lowercase hex characters")
    if not isinstance(record["claude_cli_version"], str) or not record["claude_cli_version"]:
        raise ValueError("claude_cli_version must be a non-empty string")
    if record["permission_mode"] not in PERMISSION_MODES:
        raise ValueError("permission_mode is invalid")
    budget = record["max_budget_usd"]
    if (
        isinstance(budget, bool)
        or not isinstance(budget, (int, float))
        or not math.isfinite(budget)
        or budget <= 0
    ):
        raise ValueError("max_budget_usd must be a positive number")
    validate_nonnegative_integer(record["max_turns"], "max_turns")
    if record["max_turns"] < 1:
        raise ValueError("max_turns must be at least 1")
    timeout = record["timeout_sec"]
    if (
        isinstance(timeout, bool)
        or not isinstance(timeout, (int, float))
        or not math.isfinite(timeout)
        or timeout <= 0
    ):
        raise ValueError("timeout_sec must be a positive number")
    validate_nonnegative_integer(record["repeat_index"], "repeat_index")
    if record["repeat_index"] < 1:
        raise ValueError("repeat_index must be at least 1")
    validate_nonnegative_integer(record["repeat_count"], "repeat_count")
    if record["repeat_count"] < 1:
        raise ValueError("repeat_count must be at least 1")
    if record["repeat_index"] > record["repeat_count"]:
        raise ValueError("repeat_index exceeds repeat_count")

    validate_skill_list(record["expected_skills"], "expected_skills")
    if not record["expected_skills"]:
        raise ValueError("expected_skills must not be empty")
    validate_skill_list(record["actual_skills_main"], "actual_skills_main", True)
    validate_skill_list(
        record["actual_skills_subagent"], "actual_skills_subagent", True
    )
    validate_skill_list(record["missing_skills"], "missing_skills")
    validate_skill_list(record["unexpected_skills"], "unexpected_skills")

    actual_unique = list(
        dict.fromkeys(
            record["actual_skills_main"] + record["actual_skills_subagent"]
        )
    )
    actual_set = set(actual_unique)
    expected = record["expected_skills"]
    missing = [skill for skill in expected if skill not in actual_set]
    unexpected = [skill for skill in actual_unique if skill not in expected]
    if record["missing_skills"] != missing:
        raise ValueError("missing_skills does not match expected versus actual skills")
    if record["unexpected_skills"] != unexpected:
        raise ValueError("unexpected_skills does not match expected versus actual skills")

    if not isinstance(record["exit_status"], str) or not record["exit_status"]:
        raise ValueError("exit_status must be a non-empty string")
    if not isinstance(record["result_is_error"], bool):
        raise ValueError("result_is_error must be a boolean")
    verdict, reasons = expected_verdict(
        record["exit_status"], record["result_is_error"], missing, unexpected
    )
    if record["verdict"] not in VERDICTS or record["verdict"] != verdict:
        raise ValueError(f"verdict must be {verdict} for this record")
    if record["verdict_reasons"] != reasons:
        raise ValueError("verdict_reasons does not match the record outcome")

    matched_count = len(expected) - len(missing)
    expected_quality = {
        "expected_count": len(expected),
        "actual_unique_count": len(actual_unique),
        "matched_count": matched_count,
        "recall": round(matched_count / len(expected), 6),
        "precision": round(
            matched_count / len(actual_unique) if actual_unique else 0.0, 6
        ),
    }
    if record["quality"] != expected_quality:
        raise ValueError("quality does not match expected versus actual skills")

    validate_usage(record["reported_usage"], "reported_usage")
    usage = record["reported_usage"]
    context_tokens = (
        usage["input_tokens"]
        + usage["cache_creation_input_tokens"]
        + usage["cache_read_input_tokens"]
    )
    expected_cost = {
        "context_tokens": context_tokens,
        "output_tokens": usage["output_tokens"],
        "total_tokens": context_tokens + usage["output_tokens"],
    }
    if record["cost"] != expected_cost:
        raise ValueError("cost does not match reported_usage")
    observed_usage = record["observed_usage"]
    if not isinstance(observed_usage, dict):
        raise ValueError("observed_usage must be an object")
    for scope in ("main_assistant", "subagent_assistant"):
        if scope not in observed_usage:
            raise ValueError(f"observed_usage is missing {scope}")
        validate_usage(observed_usage[scope], f"observed_usage.{scope}")

    validate_nonnegative_integer(record["num_turns"], "num_turns")
    wall_time = record["wall_time_sec"]
    if (
        isinstance(wall_time, bool)
        or not isinstance(wall_time, (int, float))
        or not math.isfinite(wall_time)
        or wall_time < 0
    ):
        raise ValueError("wall_time_sec must be a non-negative number")
    return record


def load_jsonl(path):
    records = []
    seen_runs = set()
    try:
        source = open(path, "r", encoding="utf-8")
    except OSError as exc:
        die(f"cannot read {path}: {exc}")
    with source:
        for line_number, line in enumerate(source, start=1):
            line = line.strip()
            if not line:
                continue
            try:
                record = json.loads(line, parse_constant=reject_json_constant)
            except json.JSONDecodeError as exc:
                die(f"{path}:{line_number}: invalid JSON ({exc})")
            except ValueError as exc:
                die(f"{path}:{line_number}: {exc}")
            try:
                validate_record(record)
            except ValueError as exc:
                die(f"{path}:{line_number}: {exc}")
            run_key = (record["journey"], record["repeat_index"])
            if run_key in seen_runs:
                die(
                    f"{path}:{line_number}: duplicate run for "
                    f"{record['journey']} repeat_index {record['repeat_index']}"
                )
            seen_runs.add(run_key)
            records.append(record)
    if not records:
        die(f"{path}: result file contains no records")
    for journey, group in group_records(records).items():
        repeat_counts = {record["repeat_count"] for record in group}
        if len(repeat_counts) != 1:
            die(f"{path}: repeat_count mismatch within {journey}")
        repeat_count = repeat_counts.pop()
        indices = sorted(record["repeat_index"] for record in group)
        expected_indices = list(range(1, repeat_count + 1))
        if indices != expected_indices:
            die(
                f"{path}: repeat indices for {journey} must be complete "
                f"1..{repeat_count} (got {indices})"
            )
    return records


def print_table(headers, rows):
    widths = [len(h) for h in headers]
    for row in rows:
        for i, cell in enumerate(row):
            widths[i] = max(widths[i], len(cell))

    def fmt_row(cells):
        return "  ".join(cell.ljust(widths[i]) for i, cell in enumerate(cells))

    print(fmt_row(headers))
    print(fmt_row(["-" * w for w in widths]))
    for row in rows:
        print(fmt_row(row))


def verdict_counts(records):
    counts = {verdict: 0 for verdict in VERDICTS}
    for record in records:
        counts[record["verdict"]] += 1
    return f"{counts['PASS']}/{counts['PASS_WITH_NITS']}/{counts['FAIL']}"


def median_value(values):
    return statistics.median(values)


def group_records(records):
    grouped = {}
    for record in records:
        grouped.setdefault(record["journey"], []).append(record)
    return grouped


def cmd_table(args):
    records = load_jsonl(args.file)
    by_journey = group_records(records)
    headers = [
        "Journey", "Runs", "Verdicts (P/N/F)", "Median ctx", "Worst ctx",
        "Median total", "Worst total", "Median recall", "Median precision",
        "Median wall(s)",
    ]
    rows = []
    for journey in sorted(by_journey, key=journey_sort_key):
        recs = by_journey[journey]
        contexts = [record["cost"]["context_tokens"] for record in recs]
        totals = [record["cost"]["total_tokens"] for record in recs]
        recalls = [record["quality"]["recall"] for record in recs]
        precisions = [record["quality"]["precision"] for record in recs]
        walls = [record["wall_time_sec"] for record in recs]
        rows.append([
            journey,
            str(len(recs)),
            verdict_counts(recs),
            str(median_value(contexts)),
            str(max(contexts)),
            str(median_value(totals)),
            str(max(totals)),
            str(round(statistics.median(recalls), 3)),
            str(round(statistics.median(precisions), 3)),
            str(round(statistics.median(walls), 1)),
        ])
    print_table(headers, rows)


def cmd_compare(args):
    a_records = load_jsonl(args.a)
    b_records = load_jsonl(args.b)
    ga, gb = group_records(a_records), group_records(b_records)
    if set(ga) != set(gb):
        die("journey set mismatch between comparison inputs")
    for journey in sorted(ga, key=journey_sort_key):
        a_group = ga[journey]
        b_group = gb[journey]
        if len(a_group) != len(b_group):
            die(f"run-count mismatch for {journey}")
        for field, label in (
            ("fixture", "fixture name"),
            ("fixture_sha256", "fixture hash"),
            ("expected_skills", "expected skills"),
            ("control_config_fingerprint", "control config fingerprint"),
            ("claude_cli_version", "Claude CLI version"),
            ("requested_model", "requested model"),
            ("observed_model", "observed model"),
            ("permission_mode", "permission mode"),
            ("repeat_count", "repeat count"),
            ("max_budget_usd", "max budget"),
            ("max_turns", "max turns"),
            ("timeout_sec", "timeout"),
        ):
            a_values = {json.dumps(record[field], sort_keys=True) for record in a_group}
            b_values = {json.dumps(record[field], sort_keys=True) for record in b_group}
            if len(a_values) != 1 or len(b_values) != 1 or a_values != b_values:
                die(f"{label} mismatch for {journey}")

    missing_gate_journeys = sorted(set(PHASE2_JOURNEYS) - set(ga), key=journey_sort_key)
    if missing_gate_journeys:
        die(
            "comparison is missing required Phase 2 gate journey "
            + missing_gate_journeys[0]
        )

    for records, input_name in ((a_records, "baseline"), (b_records, "Phase 2")):
        for field, label in (
            ("control_config_fingerprint", "control config fingerprint"),
            ("treatment_skill_fingerprint", "treatment skill fingerprint"),
            ("claude_cli_version", "Claude CLI version"),
            ("requested_model", "requested model"),
            ("permission_mode", "permission mode"),
            ("repeat_count", "repeat count"),
            ("max_budget_usd", "max budget"),
            ("max_turns", "max turns"),
            ("timeout_sec", "timeout"),
        ):
            values = {json.dumps(record[field], sort_keys=True) for record in records}
            if len(values) != 1:
                die(f"{label} is not uniform within {input_name} input")

    a_treatment = {record["treatment_skill_fingerprint"] for record in a_records}.pop()
    b_treatment = {record["treatment_skill_fingerprint"] for record in b_records}.pop()
    if a_treatment == b_treatment:
        die("treatment skill fingerprint did not change between P1g and Phase 2")

    journeys = sorted(ga, key=journey_sort_key)
    headers = [
        "Journey", "A runs", "A verdicts (P/N/F)", "A median ctx",
        "A worst ctx", "B runs", "B verdicts (P/N/F)", "B median ctx",
        "B worst ctx", "d median ctx", "d worst ctx", "Phase 2 gate",
    ]
    rows = []
    gate_reasons = []
    for journey in journeys:
        a_group, b_group = ga[journey], gb[journey]
        a_contexts = [record["cost"]["context_tokens"] for record in a_group]
        b_contexts = [record["cost"]["context_tokens"] for record in b_group]
        a_median = median_value(a_contexts)
        b_median = median_value(b_contexts)
        a_worst = max(a_contexts)
        b_worst = max(b_contexts)
        journey_reasons = []
        if journey in PHASE2_JOURNEYS:
            a_by_repeat = {record["repeat_index"]: record for record in a_group}
            b_by_repeat = {record["repeat_index"]: record for record in b_group}
            for repeat_index in sorted(a_by_repeat):
                if (
                    VERDICT_RANK[b_by_repeat[repeat_index]["verdict"]]
                    < VERDICT_RANK["PASS_WITH_NITS"]
                ):
                    journey_reasons.append(
                        f"treatment_verdict_below_floor_repeat_{repeat_index}"
                    )
                if (
                    VERDICT_RANK[b_by_repeat[repeat_index]["verdict"]]
                    < VERDICT_RANK[a_by_repeat[repeat_index]["verdict"]]
                ):
                    journey_reasons.append(f"verdict_downgrade_repeat_{repeat_index}")
            if b_median >= a_median:
                journey_reasons.append("median_context_not_lower")
            if b_worst > a_worst:
                journey_reasons.append("worst_context_regressed")
            gate_reasons.extend(
                f"{journey}:{reason}" for reason in journey_reasons
            )
        rows.append([
            journey,
            str(len(a_group)),
            verdict_counts(a_group),
            str(a_median),
            str(a_worst),
            str(len(b_group)),
            verdict_counts(b_group),
            str(b_median),
            str(b_worst),
            str(b_median - a_median),
            str(b_worst - a_worst),
            "REPORT_ONLY" if journey not in PHASE2_JOURNEYS else (
                "PASS" if not journey_reasons else "REGRESSION"
            ),
        ])
    print_table(headers, rows)
    verdict = "PASS" if not gate_reasons else "REGRESSION"
    print(
        "MACHINE_VERDICT "
        + json.dumps(
            {
                "gate": "phase2-j8-j10",
                "reasons": gate_reasons,
                "verdict": verdict,
            },
            sort_keys=True,
            separators=(",", ":"),
        )
    )
    if gate_reasons:
        sys.exit(1)


def cmd_fixtures(args):
    fixtures = load_fixtures(args.directory)
    if args.list:
        for fixture in fixtures:
            fields = [
                fixture["id"],
                fixture["name"],
                fixture["expected_csv"],
                fixture["sha256"],
            ]
            if args.include_prompt:
                fields.append(fixture["prompt_b64"])
            print("\t".join(fields))
        return
    required = " ".join(REQUIRED_JOURNEYS)
    print(f"fixtures OK: {len(fixtures)} journeys (required: {required})")


def cmd_snapshot_fixtures(args):
    source_root = Path(args.source)
    destination_root = Path(args.destination)
    if not source_root.is_dir():
        die("fixture source directory does not exist")
    if destination_root.is_symlink() or not destination_root.is_dir():
        die("fixture snapshot destination must be a directory")
    try:
        if any(destination_root.iterdir()):
            die("fixture snapshot destination must be empty")
        os.chmod(destination_root, 0o700)
        source_entries = sorted(source_root.iterdir(), key=lambda item: item.name)
    except OSError as exc:
        die(f"fixture snapshot cannot be initialized: {exc}")

    for source_path in source_entries:
        if not source_path.name.endswith(".txt"):
            continue
        if source_path.is_symlink():
            die(f"{source_path.name}: fixture source must not be a symlink")
        raw_bytes = read_regular_file(source_path, source_path.name)
        destination_path = destination_root / source_path.name
        try:
            descriptor = os.open(
                destination_path,
                os.O_WRONLY | os.O_CREAT | os.O_EXCL,
                0o400,
            )
            with os.fdopen(descriptor, "wb") as destination:
                destination.write(raw_bytes)
                destination.flush()
                os.fsync(destination.fileno())
            os.chmod(destination_path, 0o400)
        except OSError as exc:
            die(f"{source_path.name}: cannot create private fixture snapshot ({exc})")


def open_directory_nofollow(path, label):
    try:
        metadata = os.lstat(path)
    except OSError as exc:
        die(f"{label} does not exist or cannot be inspected ({exc})")
    if stat.S_ISLNK(metadata.st_mode):
        die(f"{label} must not be a symlink")
    if not stat.S_ISDIR(metadata.st_mode):
        die(f"{label} must be a directory")

    flags = os.O_RDONLY | getattr(os, "O_DIRECTORY", 0)
    if hasattr(os, "O_NOFOLLOW"):
        flags |= os.O_NOFOLLOW
    try:
        descriptor = os.open(path, flags)
    except OSError as exc:
        die(f"{label} cannot be opened safely ({exc})")
    if not stat.S_ISDIR(os.fstat(descriptor).st_mode):
        os.close(descriptor)
        die(f"{label} must be a directory")
    return descriptor


def read_regular_at(directory_fd, name, label):
    flags = os.O_RDONLY | getattr(os, "O_NONBLOCK", 0)
    if hasattr(os, "O_NOFOLLOW"):
        flags |= os.O_NOFOLLOW
    try:
        descriptor = os.open(name, flags, dir_fd=directory_fd)
    except OSError as exc:
        die(f"{label} must be an accessible regular file ({exc})")
    try:
        if not stat.S_ISREG(os.fstat(descriptor).st_mode):
            die(f"{label} must be a regular file")
        with os.fdopen(descriptor, "rb") as source:
            descriptor = -1
            return source.read()
    finally:
        if descriptor >= 0:
            os.close(descriptor)


def copy_config_tree(source_fd, destination_fd, relative=()):
    try:
        names = sorted(os.listdir(source_fd))
    except OSError as exc:
        die(f"config source cannot be listed safely ({exc})")

    for name in names:
        display = "/".join(relative + (name,))
        try:
            metadata = os.stat(name, dir_fd=source_fd, follow_symlinks=False)
        except OSError as exc:
            die(f"config entry cannot be inspected safely: {display} ({exc})")
        if stat.S_ISLNK(metadata.st_mode):
            die(f"config directory must not contain symlinks: {display}")
        if stat.S_ISDIR(metadata.st_mode):
            source_flags = os.O_RDONLY | getattr(os, "O_DIRECTORY", 0)
            if hasattr(os, "O_NOFOLLOW"):
                source_flags |= os.O_NOFOLLOW
            try:
                child_source_fd = os.open(name, source_flags, dir_fd=source_fd)
                if not stat.S_ISDIR(os.fstat(child_source_fd).st_mode):
                    os.close(child_source_fd)
                    die(f"config entry must remain a directory: {display}")
                os.mkdir(name, 0o700, dir_fd=destination_fd)
                child_destination_fd = os.open(
                    name,
                    os.O_RDONLY | getattr(os, "O_DIRECTORY", 0),
                    dir_fd=destination_fd,
                )
            except OSError as exc:
                die(f"config directory cannot be snapshotted safely: {display} ({exc})")
            try:
                copy_config_tree(
                    child_source_fd,
                    child_destination_fd,
                    relative + (name,),
                )
            finally:
                os.close(child_source_fd)
                os.close(child_destination_fd)
        elif stat.S_ISREG(metadata.st_mode):
            raw_bytes = read_regular_at(source_fd, name, f"config entry {display}")
            flags = os.O_WRONLY | os.O_CREAT | os.O_EXCL
            if hasattr(os, "O_NOFOLLOW"):
                flags |= os.O_NOFOLLOW
            try:
                descriptor = os.open(name, flags, 0o600, dir_fd=destination_fd)
                with os.fdopen(descriptor, "wb") as destination:
                    destination.write(raw_bytes)
                    destination.flush()
                    os.fsync(destination.fileno())
                    os.fchmod(destination.fileno(), 0o400)
            except OSError as exc:
                die(f"config file cannot be snapshotted safely: {display} ({exc})")
        else:
            die(f"config directory contains an unsupported special file: {display}")
    os.fchmod(destination_fd, 0o500)


def cmd_snapshot_config(args):
    source_fd = open_directory_nofollow(args.source, "config source")
    destination_fd = open_directory_nofollow(
        args.destination, "config snapshot destination"
    )
    try:
        if os.listdir(destination_fd):
            die("config snapshot destination must be empty")
        os.chmod(args.destination, 0o700)
        copy_config_tree(source_fd, destination_fd)
    finally:
        os.close(source_fd)
        os.close(destination_fd)


def cmd_config_fingerprints(args):
    root = Path(args.directory)
    if root.is_symlink():
        die("config directory must not be a symlink")
    if not root.is_dir():
        die("config directory must be a directory")

    treatment_roots = tuple(Path(path) for path in TREATMENT_SKILL_PATHS)
    for relative_root in treatment_roots:
        candidate = root / relative_root
        if candidate.is_symlink() or not candidate.is_dir():
            die(
                "controlled config is missing required treatment skill directory "
                f"{relative_root.as_posix()}"
            )

    control_digest = hashlib.sha256(b"journey-probe-control-config-v1\0")
    treatment_digest = hashlib.sha256(b"journey-probe-treatment-skills-v1\0")
    for relative_root in treatment_roots:
        encoded = relative_root.as_posix().encode("utf-8")
        # Bind the partition itself into both identities. Changing which paths
        # count as treatment must therefore change the control identity too.
        control_digest.update(b"T\0" + encoded + b"\0")
        treatment_digest.update(b"T\0" + encoded + b"\0")

    try:
        entries = sorted(root.rglob("*"), key=lambda item: item.relative_to(root).as_posix())
        for entry in entries:
            relative_path = entry.relative_to(root)
            relative = relative_path.as_posix().encode("utf-8")
            if entry.is_symlink():
                die("config directory must not contain symlinks")
            is_treatment = any(
                relative_path == treatment_root
                or treatment_root in relative_path.parents
                for treatment_root in treatment_roots
            )
            digest = treatment_digest if is_treatment else control_digest
            if entry.is_dir():
                digest.update(b"D\0" + relative + b"\0")
            elif entry.is_file():
                digest.update(b"F\0" + relative + b"\0")
                with open(entry, "rb") as source:
                    for chunk in iter(lambda: source.read(65536), b""):
                        digest.update(chunk)
                digest.update(b"\0")
            else:
                die("config directory contains an unsupported special file")
    except (OSError, UnicodeError):
        die("config directory cannot be fingerprinted safely")
    print(f"{control_digest.hexdigest()}\t{treatment_digest.hexdigest()}")


def main():
    parser = argparse.ArgumentParser(prog="journey-probe")
    sub = parser.add_subparsers(dest="mode", required=True)

    p_parse = sub.add_parser("parse-stream")
    p_parse.add_argument("--file", default="")
    p_parse.add_argument("--metadata-file", required=True)
    p_parse.add_argument("--assert-journey", default="")
    p_parse.add_argument("--assert-fixture", default="")
    p_parse.add_argument("--assert-expected", default="")
    p_parse.set_defaults(func=cmd_parse_stream)

    p_run = sub.add_parser("run")
    p_run.add_argument("--prompt-b64", required=True)
    p_run.add_argument("--cwd", required=True)
    p_run.add_argument("--journey", required=True)
    p_run.add_argument("--fixture", required=True)
    p_run.add_argument("--fixture-sha256", required=True)
    p_run.add_argument("--expected", default="")
    p_run.add_argument("--model", default="")
    p_run.add_argument("--max-turns", type=int, default=40)
    p_run.add_argument("--timeout-sec", type=float, default=900)
    p_run.add_argument("--max-budget-usd", type=float, required=True)
    p_run.add_argument("--permission-mode", required=True)
    p_run.add_argument("--config-dir", required=True)
    p_run.add_argument("--control-config-fingerprint", required=True)
    p_run.add_argument("--treatment-skill-fingerprint", required=True)
    p_run.add_argument("--claude-cli-version", required=True)
    p_run.add_argument("--repeat-index", type=int, default=1)
    p_run.add_argument("--repeat-count", type=int, required=True)
    p_run.add_argument("--raw-out", default="")
    p_run.set_defaults(func=cmd_run)

    p_table = sub.add_parser("table")
    p_table.add_argument("--file", required=True)
    p_table.set_defaults(func=cmd_table)

    p_cmp = sub.add_parser("compare")
    p_cmp.add_argument("--a", required=True)
    p_cmp.add_argument("--b", required=True)
    p_cmp.set_defaults(func=cmd_compare)

    p_fixtures = sub.add_parser("fixtures")
    p_fixtures.add_argument("--directory", required=True)
    p_fixtures.add_argument("--list", action="store_true")
    p_fixtures.add_argument("--include-prompt", action="store_true")
    p_fixtures.set_defaults(func=cmd_fixtures)

    p_snapshot = sub.add_parser("snapshot-fixtures")
    p_snapshot.add_argument("--source", required=True)
    p_snapshot.add_argument("--destination", required=True)
    p_snapshot.set_defaults(func=cmd_snapshot_fixtures)

    p_config_snapshot = sub.add_parser("snapshot-config")
    p_config_snapshot.add_argument("--source", required=True)
    p_config_snapshot.add_argument("--destination", required=True)
    p_config_snapshot.set_defaults(func=cmd_snapshot_config)

    p_fingerprint = sub.add_parser("config-fingerprints")
    p_fingerprint.add_argument("--directory", required=True)
    p_fingerprint.set_defaults(func=cmd_config_fingerprints)

    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
PYEOF
}

# ---------------------------------------------------------------------------
# Fixture repo: a tiny disposable git repo with one failing test, a short
# plan, and a fixture-only fake codename, so any journey prompt has
# something real to operate on. Fresh repo per run -- never shared, never
# pushed anywhere.
# ---------------------------------------------------------------------------
write_fixture_files() {
  local dir="$1"
  mkdir -p "$dir/src" "$dir/tests" || return 1
  : > "$dir/src/__init__.py" || return 1

  cat > "$dir/README.md" <<'EOF' || return 1
# journey-probe fixture repo

Ephemeral repo created by tools/journey-probe.sh for one probe run. Never
pushed, never merged, safe to delete.
EOF

  cat > "$dir/src/calc.py" <<'EOF' || return 1
def add(a, b):
    return a - b  # BUG: should be a + b


def multiply(a, b):
    return a * b
EOF

  cat > "$dir/tests/test_calc.py" <<'EOF' || return 1
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from src.calc import add, multiply


def test_add():
    assert add(2, 3) == 5


def test_multiply():
    assert multiply(2, 3) == 6
EOF

  cat > "$dir/PLAN.md" <<'EOF' || return 1
# Plan: fix calc.add()

1. Reproduce the failing test (`pytest tests/test_calc.py::test_add`).
2. Fix the sign bug in `src/calc.py`.
3. Re-run the test suite and confirm green.
4. Commit locally (no push).
EOF

  cat > "$dir/NOTES.md" <<'EOF' || return 1
# Fixture notes

This is a throwaway fixture repo generated by tools/journey-probe.sh for
journey-probe measurement runs. It contains a fictitious internal
codename, PROJECT-FIXTURE-WOMBAT, used only to exercise the
public-repo-ip-audit journey (J11). It is not a real internal term.
EOF
}

create_fixture_repo() {
  local dir template_dir hooks_dir
  dir="$(mktemp -d "${TMPDIR:-/tmp}/journey-probe.XXXXXX")" || return 1
  template_dir="$(mktemp -d "${TMPDIR:-/tmp}/journey-probe-template.XXXXXX")" || {
    rm -rf "$dir"
    return 1
  }

  fixture_git() {
    env -i PATH="$PATH" GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null \
      git -C "$dir" "$@"
  }

  fixture_git init -q --template="$template_dir" || {
    rm -rf "$template_dir" "$dir"
    return 1
  }
  rm -rf "$template_dir" || {
    rm -rf "$dir"
    return 1
  }
  hooks_dir="$dir/.git/journey-probe-hooks"
  mkdir -p "$hooks_dir" || {
    rm -rf "$dir"
    return 1
  }
  fixture_git config user.email "journey-probe@example.invalid" || {
    rm -rf "$dir"
    return 1
  }
  fixture_git config user.name "journey-probe" || {
    rm -rf "$dir"
    return 1
  }
  fixture_git config commit.gpgSign false || {
    rm -rf "$dir"
    return 1
  }
  fixture_git config core.hooksPath "$hooks_dir" || {
    rm -rf "$dir"
    return 1
  }
  write_fixture_files "$dir" || {
    rm -rf "$dir"
    return 1
  }
  fixture_git add -A || {
    rm -rf "$dir"
    return 1
  }
  fixture_git commit -q -m "chore: initial fixture state (journey-probe)" || {
    rm -rf "$dir"
    return 1
  }
  printf '%s' "$dir"
}

# ---------------------------------------------------------------------------
# Journey discovery
# ---------------------------------------------------------------------------
list_journey_files() {
  py fixtures --directory "$FIXTURES_DIR" --list --include-prompt
}

filter_journeys() {
  if [[ -z "$JOURNEYS" ]]; then
    cat
    return
  fi
  local id fixture expected sha256 prompt_b64 w match
  local -a wanted
  IFS=',' read -r -a wanted <<<"$JOURNEYS"
  while IFS=$'\t' read -r id fixture expected sha256 prompt_b64; do
    match=0
    for w in "${wanted[@]}"; do
      [[ "$id" == "$w" ]] && { match=1; break; }
    done
    [[ "$match" -eq 1 ]] && printf '%s\t%s\t%s\t%s\t%s\n' \
      "$id" "$fixture" "$expected" "$sha256" "$prompt_b64"
  done
  return 0  # the while loop's own exit status is read's EOF failure (1); do not propagate it
}

cleanup() {
  if [[ -n "$RUN_RECORDS_FILE" ]]; then
    rm -f "$RUN_RECORDS_FILE"
  fi
  if [[ -n "$CURRENT_FIXTURE_REPO" ]]; then
    case "$CURRENT_FIXTURE_REPO" in
      "${TMPDIR:-/tmp}"/journey-probe.*) rm -rf "$CURRENT_FIXTURE_REPO" ;;
      *) echo "WARNING: refusing to remove unexpected fixture path: $CURRENT_FIXTURE_REPO" >&2 ;;
    esac
  fi
  if [[ -n "$FIXTURE_SNAPSHOT_DIR" ]]; then
    case "$FIXTURE_SNAPSHOT_DIR" in
      "$FIXTURE_SNAPSHOT_PARENT"/journey-probe-fixtures.*) rm -rf "$FIXTURE_SNAPSHOT_DIR" ;;
      *) echo "WARNING: refusing to remove unexpected snapshot path" >&2 ;;
    esac
  fi
  if [[ -n "$CONFIG_SNAPSHOT_DIR" ]]; then
    case "$CONFIG_SNAPSHOT_DIR" in
      "$CONFIG_SNAPSHOT_PARENT"/journey-probe-config.*)
        chmod -R u+rwX "$CONFIG_SNAPSHOT_DIR" 2>/dev/null || true
        rm -rf "$CONFIG_SNAPSHOT_DIR"
        ;;
      *) echo "WARNING: refusing to remove unexpected config snapshot path" >&2 ;;
    esac
  fi
}
trap cleanup EXIT

# ---------------------------------------------------------------------------
# Modes that never spawn claude
# ---------------------------------------------------------------------------
require_cmd python3

if [[ -n "$COMPARE_A" ]]; then
  [[ -n "$COMPARE_B" ]] || die "--compare requires two files: --compare A.jsonl B.jsonl"
  [[ -f "$COMPARE_A" ]] || die "compare file not found: $COMPARE_A"
  [[ -f "$COMPARE_B" ]] || die "compare file not found: $COMPARE_B"
  py compare --a "$COMPARE_A" --b "$COMPARE_B"
  exit 0
fi

if [[ -n "$PARSE_STREAM_FILE" ]]; then
  [[ -f "$PARSE_STREAM_FILE" ]] || die "stream file not found: $PARSE_STREAM_FILE"
  METADATA_FILE="$PARSE_STREAM_FILE.meta.json"
  [[ -f "$METADATA_FILE" ]] || data_die "metadata sidecar not found: $METADATA_FILE"
  py parse-stream \
    --file "$PARSE_STREAM_FILE" \
    --metadata-file "$METADATA_FILE" \
    --assert-journey "$PS_JOURNEY" \
    --assert-fixture "$PS_FIXTURE" \
    --assert-expected "$PS_EXPECTED"
  exit 0
fi

# Every fixture-backed mode validates the complete corpus before selecting a
# subset. Copy each source fixture once, then validate, hash, and prompt only
# from that private read-only snapshot. Later source edits cannot relabel or
# alter a measured prompt.
FIXTURE_SNAPSHOT_PARENT="${TMPDIR:-/tmp}"
FIXTURE_SNAPSHOT_PARENT="${FIXTURE_SNAPSHOT_PARENT%/}"
FIXTURE_SNAPSHOT_DIR="$(mktemp -d "$FIXTURE_SNAPSHOT_PARENT/journey-probe-fixtures.XXXXXX")"
chmod 700 "$FIXTURE_SNAPSHOT_DIR"
py snapshot-fixtures \
  --source "$FIXTURE_SOURCE_DIR" \
  --destination "$FIXTURE_SNAPSHOT_DIR"
FIXTURES_DIR="$FIXTURE_SNAPSHOT_DIR"
FIXTURE_RECORDS="$(list_journey_files)"

validate_requested_journeys() {
  [[ -n "$JOURNEYS" ]] || return 0
  local requested id _ found=0
  local seen="|"
  local -a requested_ids
  IFS=',' read -r -a requested_ids <<<"$JOURNEYS"
  for requested in "${requested_ids[@]}"; do
    [[ "$requested" =~ ^J[0-9]+[a-z]?$ ]] || die "invalid journey ID: '$requested'"
    case "$seen" in
      *"|$requested|"*) die "duplicate journey ID in --journeys: $requested" ;;
      *) seen="${seen}${requested}|" ;;
    esac
    found=0
    while IFS=$'\t' read -r id _; do
      if [[ "$id" == "$requested" ]]; then
        found=1
        break
      fi
    done <<<"$FIXTURE_RECORDS"
    [[ "$found" -eq 1 ]] || data_die "requested journey fixture not found: $requested"
  done
}

validate_requested_journeys

if [[ "$LINT_FIXTURES" -eq 1 ]]; then
  py fixtures --directory "$FIXTURES_DIR"
  exit 0
fi

if [[ "$LIST_ONLY" -eq 1 ]]; then
  # `|| true`: the while loop's own exit status is read's EOF failure (1) on
  # normal completion; under pipefail that would abort the script via set -e
  # before the explicit `exit 0` below ever runs.
  printf '%s\n' "$FIXTURE_RECORDS" | filter_journeys | \
    while IFS=$'\t' read -r id fixture_name _ _; do
      printf '%s\t%s\n' "$id" "$fixture_name"
  done || true
  exit 0
fi

# ---------------------------------------------------------------------------
# Validate numeric options
# ---------------------------------------------------------------------------
[[ "$REPEAT" =~ ^[0-9]+$ && "$REPEAT" -ge 1 ]] || die "--repeat must be a positive integer"
[[ "$MAX_TURNS" =~ ^[0-9]+$ && "$MAX_TURNS" -ge 1 ]] || die "--max-turns must be a positive integer"
[[ "$TIMEOUT_SEC" =~ ^[0-9]+$ && "$TIMEOUT_SEC" -ge 1 ]] || die "--timeout must be a positive integer (seconds)"
[[ "$MAX_BUDGET_USD" =~ ^[0-9]+([.][0-9]+)?$ ]] || die "--max-budget-usd must be a positive number"
if ! python3 -c 'from decimal import Decimal; import sys; sys.exit(0 if Decimal(sys.argv[1]) > 0 else 1)' "$MAX_BUDGET_USD"; then
  die "--max-budget-usd must be greater than zero"
fi
case "$PERMISSION_MODE" in
  acceptEdits|auto|bypassPermissions|manual|dontAsk|plan) ;;
  *) die "--permission-mode must be one of: acceptEdits, auto, bypassPermissions, manual, dontAsk, plan" ;;
esac
[[ -n "$CONFIG_DIR" ]] || die "--config-dir is required for live and --dry-run modes"
CONFIG_SNAPSHOT_PARENT="${TMPDIR:-/tmp}"
CONFIG_SNAPSHOT_PARENT="${CONFIG_SNAPSHOT_PARENT%/}"
CONFIG_SNAPSHOT_DIR="$(mktemp -d "$CONFIG_SNAPSHOT_PARENT/journey-probe-config.XXXXXX")"
chmod 700 "$CONFIG_SNAPSHOT_DIR"
py snapshot-config --source "$CONFIG_DIR" --destination "$CONFIG_SNAPSHOT_DIR"
CONFIG_FINGERPRINTS="$(py config-fingerprints --directory "$CONFIG_SNAPSHOT_DIR")"
IFS=$'\t' read -r CONTROL_CONFIG_FINGERPRINT TREATMENT_SKILL_FINGERPRINT \
  <<<"$CONFIG_FINGERPRINTS"
[[ -n "$CONTROL_CONFIG_FINGERPRINT" && -n "$TREATMENT_SKILL_FINGERPRINT" ]] || \
  data_die "configuration fingerprinting returned incomplete identities"

SELECTED=()
# Bash 3.2 compatibility: mapfile/readarray were added in Bash 4 and are not
# available in stock macOS /bin/bash.
while IFS= read -r entry; do
  [[ -n "$entry" ]] && SELECTED+=("$entry")
done < <(printf '%s\n' "$FIXTURE_RECORDS" | filter_journeys)
[[ "${#SELECTED[@]}" -gt 0 ]] || die "no journeys matched --journeys '$JOURNEYS' (see --list)"

if [[ "$DRY_RUN" -eq 1 ]]; then
  for entry in "${SELECTED[@]}"; do
    IFS=$'\t' read -r id fixture_name _ _ <<<"$entry"
    for ((i = 1; i <= REPEAT; i++)); do
      echo "# journey $id ($fixture_name) run $i/$REPEAT"
      echo "(create fresh throwaway fixture repo via create_fixture_repo)"
      echo "cd <fixture-repo> && claude -p <prompt from $fixture_name>" \
           "--output-format stream-json --verbose --forward-subagent-text" \
           "--no-session-persistence --permission-mode $PERMISSION_MODE" \
           "--max-budget-usd $MAX_BUDGET_USD${MODEL:+ --model $MODEL}"
      echo "  control-config-fingerprint=$CONTROL_CONFIG_FINGERPRINT" \
           "treatment-skill-fingerprint=$TREATMENT_SKILL_FINGERPRINT" \
           "max-turns=$MAX_TURNS  timeout=${TIMEOUT_SEC}s"
    done
  done
  exit 0
fi

if [[ -z "$RESULTS_FILE" ]]; then
  mkdir -p "$DEFAULT_RESULTS_DIR"
  RESULTS_FILE="$DEFAULT_RESULTS_DIR/$(date -u +%Y%m%dT%H%M%SZ).jsonl"
fi
[[ ! -e "$RESULTS_FILE" ]] || data_die "results file already exists: $RESULTS_FILE"
mkdir -p "$(dirname "$RESULTS_FILE")"
if ! (set -o noclobber; : > "$RESULTS_FILE") 2>/dev/null; then
  data_die "results file already exists or cannot be created safely: $RESULTS_FILE"
fi
chmod 600 "$RESULTS_FILE"

require_cmd claude
require_cmd git
CLAUDE_CLI_VERSION="$(claude --version 2>/dev/null)" || data_die "claude --version failed"
if [[ -z "$CLAUDE_CLI_VERSION" || "$CLAUDE_CLI_VERSION" == *$'\n'* || "${#CLAUDE_CLI_VERSION}" -gt 256 ]]; then
  data_die "claude --version returned malformed output"
fi

RAW_DIR="$(dirname "$RESULTS_FILE")/raw"
mkdir -p "$RAW_DIR"
chmod 700 "$RAW_DIR"

RUN_RECORDS_FILE="$(mktemp)"

log "results file: $RESULTS_FILE"

for entry in "${SELECTED[@]}"; do
  IFS=$'\t' read -r id fixture_name expected_csv fixture_sha256 prompt_b64 <<<"$entry"

  for ((i = 1; i <= REPEAT; i++)); do
    if ! fixture_repo="$(create_fixture_repo)"; then
      data_die "failed to create fixture repository"
    fi
    CURRENT_FIXTURE_REPO="$fixture_repo"
    log "journey $id run $i/$REPEAT: fixture repo $fixture_repo"

    raw_out=""
    if [[ "$VERBOSE" -eq 1 ]]; then
      raw_out="$RAW_DIR/$(date -u +%Y%m%dT%H%M%SZ).${id}.r${i}.jsonl"
    fi

    record="$(py run \
      --prompt-b64 "$prompt_b64" \
      --cwd "$fixture_repo" \
      --journey "$id" \
      --fixture "$fixture_name" \
      --fixture-sha256 "$fixture_sha256" \
      --expected "$expected_csv" \
      --model "$MODEL" \
      --max-turns "$MAX_TURNS" \
      --timeout-sec "$TIMEOUT_SEC" \
      --max-budget-usd "$MAX_BUDGET_USD" \
      --permission-mode "$PERMISSION_MODE" \
      --config-dir "$CONFIG_SNAPSHOT_DIR" \
      --control-config-fingerprint "$CONTROL_CONFIG_FINGERPRINT" \
      --treatment-skill-fingerprint "$TREATMENT_SKILL_FINGERPRINT" \
      --claude-cli-version "$CLAUDE_CLI_VERSION" \
      --repeat-index "$i" \
      --repeat-count "$REPEAT" \
      --raw-out "$raw_out")"

    POST_CONFIG_FINGERPRINTS="$(py config-fingerprints --directory "$CONFIG_SNAPSHOT_DIR")"
    IFS=$'\t' read -r POST_CONTROL_CONFIG_FINGERPRINT POST_TREATMENT_SKILL_FINGERPRINT \
      <<<"$POST_CONFIG_FINGERPRINTS"
    if [[ "$POST_CONTROL_CONFIG_FINGERPRINT" != "$CONTROL_CONFIG_FINGERPRINT" ]]; then
      data_die "control configuration changed during measurement; discard this run"
    fi
    if [[ "$POST_TREATMENT_SKILL_FINGERPRINT" != "$TREATMENT_SKILL_FINGERPRINT" ]]; then
      data_die "treatment skills changed during measurement; discard this run"
    fi

    echo "$record" >> "$RESULTS_FILE"
    echo "$record" >> "$RUN_RECORDS_FILE"
    rm -rf "$fixture_repo"
    CURRENT_FIXTURE_REPO=""
  done
done

echo "Results written to: $RESULTS_FILE" >&2
py table --file "$RUN_RECORDS_FILE"

#!/usr/bin/env bash
# tools/measure-artifact-sizes.sh — artifact size budget regression tool
#
# Measures context-bearing artifacts and skill inventory against committed baselines.
# Artifacts include resident listings, bootstrap payloads, host rules, and skill bodies.
#
# Usage:
#   measure-artifact-sizes.sh [--dry-run]           measure + compare vs baselines
#   measure-artifact-sizes.sh --rebaseline --reason "text"  regenerate baselines
#   measure-artifact-sizes.sh --rebaseline [--include-host] [--allow-breach ID] --reason "text"
#   measure-artifact-sizes.sh --help
#
# Artifact kinds:
#   file            stats a path, measures byte count.
#   process-output  runs a command, measures its stdout byte count.
#   metric          runs a command, parses its stdout as JSON, reads
#                   `json_key`, and compares that value against `size_bytes`
#                   (the baseline) with the same tolerance math as the other
#                   kinds -- so a metric row's "size_bytes" may be a byte
#                   count, a plain count, or a rate; the field name is kept
#                   for schema consistency. For a metric whose baseline is 0
#                   (a rate or count that should stay at zero), the same
#                   tolerance math already breaches on any value > 0, since
#                   budget = baseline * (1 + tolerance) = 0.
#
# BUDGET_MODE env var: strict (default) or advisory (warn only, exit 0)
#
# --rebaseline requires an interactive terminal (tty) to prevent CI accidents.
# Use FORCE_REBASELINE=1 to override in tests.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MANIFEST="$REPO_ROOT/tests/harness/artifact-baselines.json"
BUDGET_MODE="${BUDGET_MODE:-strict}"
MODE="compare"
REASON=""
INCLUDE_HOST=0
ALLOW_BREACH_IDS=()

usage() {
  grep '^#' "$0" | sed 's/^# \{0,1\}//' | tail -n +2
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)    MODE="dry-run" ;;
    --rebaseline) MODE="rebaseline" ;;
    --include-host) INCLUDE_HOST=1 ;;
    --allow-breach)
      if [[ $# -lt 2 || -z "$2" || "$2" == --* ]]; then
        echo "ERROR: --allow-breach requires an artifact ID" >&2; exit 2
      fi
      ALLOW_BREACH_IDS+=("$2"); shift ;;
    --allow-breach=*)
      if [[ -z "${1#--allow-breach=}" ]]; then
        echo "ERROR: --allow-breach requires an artifact ID" >&2; exit 2
      fi
      ALLOW_BREACH_IDS+=("${1#--allow-breach=}") ;;
    --reason)
      if [[ $# -lt 2 ]]; then
        echo "ERROR: --reason requires an argument" >&2; exit 2
      fi
      REASON="$2"; shift ;;
    --reason=*)   REASON="${1#--reason=}" ;;
    --help|-h)    usage ;;
    *)            echo "Unknown option: $1" >&2; exit 2 ;;
  esac
  shift
done

if [[ "$INCLUDE_HOST" -eq 1 && "$MODE" != "rebaseline" ]]; then
  echo "ERROR: --include-host is valid only with --rebaseline" >&2
  exit 2
fi

if [[ "${#ALLOW_BREACH_IDS[@]}" -gt 0 && "$MODE" != "rebaseline" ]]; then
  echo "ERROR: --allow-breach is valid only with --rebaseline" >&2
  exit 2
fi

if [[ "$MODE" == "rebaseline" ]]; then
  if [[ -z "$REASON" ]]; then
    echo "ERROR: --rebaseline requires --reason \"explanation\"" >&2
    exit 2
  fi
  if [[ -z "${FORCE_REBASELINE:-}" ]] && ! test -t 0; then
    echo "ERROR: --rebaseline requires an interactive terminal. Set FORCE_REBASELINE=1 to override." >&2
    exit 2
  fi
fi

if [[ ! -f "$MANIFEST" ]]; then
  echo "ERROR: manifest not found: $MANIFEST" >&2
  exit 2
fi

python3 - "$REPO_ROOT" "$MANIFEST" "$MODE" "$REASON" "$BUDGET_MODE" "$INCLUDE_HOST" "${ALLOW_BREACH_IDS[@]}" <<'PYEOF'
import sys, json, os, subprocess, hashlib, shlex, tempfile, datetime, math
from decimal import Decimal, InvalidOperation
from fractions import Fraction

repo_root, manifest_path, mode, reason, budget_mode, include_host_raw, *allow_breach_raw = sys.argv[1:]
include_host = include_host_raw == '1'
allow_breach = set(allow_breach_raw)

if budget_mode not in ('strict', 'advisory'):
    print(f"ERROR: BUDGET_MODE must be 'strict' or 'advisory', got: {budget_mode!r}", file=sys.stderr)
    sys.exit(2)

with open(manifest_path) as f:
    data = json.load(f)

artifacts = data.get('artifacts') if isinstance(data, dict) else None
if not isinstance(artifacts, list):
    print("ERROR: manifest artifacts must be an array", file=sys.stderr)
    sys.exit(2)
artifact_ids = set()
for index, artifact in enumerate(artifacts):
    if not isinstance(artifact, dict):
        print(f"ERROR: artifact row {index} must be an object", file=sys.stderr)
        sys.exit(2)
    artifact_id = artifact.get('id')
    if not isinstance(artifact_id, str) or not artifact_id:
        print(f"ERROR: artifact row {index} has a missing or non-string ID", file=sys.stderr)
        sys.exit(2)
    if artifact_id in artifact_ids:
        print(f"ERROR: duplicate artifact ID: {artifact_id}", file=sys.stderr)
        sys.exit(2)
    artifact_ids.add(artifact_id)
unknown_overrides = sorted(allow_breach - artifact_ids)
if unknown_overrides:
    print(f"ERROR: unknown --allow-breach artifact ID(s): {', '.join(unknown_overrides)}", file=sys.stderr)
    sys.exit(2)
in_ci = bool(os.environ.get('CI'))
budget_breaches = []
acquisition_errors = []
rebaseline_errors = []
pending_updates = []
command_cache = {}
json_cache = {}

def numeric_fraction(value, label, *, integer_only=False):
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        print(f"ERROR: {label} must be numeric", file=sys.stderr)
        sys.exit(2)
    if integer_only and not isinstance(value, int):
        print(f"ERROR: {label} must be an integer", file=sys.stderr)
        sys.exit(2)
    try:
        decimal_value = Decimal(str(value))
    except (InvalidOperation, ValueError):
        print(f"ERROR: {label} must be finite and non-negative", file=sys.stderr)
        sys.exit(2)
    if not decimal_value.is_finite() or decimal_value < 0:
        print(f"ERROR: {label} must be finite and non-negative", file=sys.stderr)
        sys.exit(2)
    return Fraction(decimal_value)

def display_fraction(value):
    if isinstance(value, int):
        return str(value)
    numerator = value.numerator
    denominator = value.denominator
    if denominator == 1:
        return str(numerator)
    twos = 0
    fives = 0
    reduced = denominator
    while reduced % 2 == 0:
        reduced //= 2
        twos += 1
    while reduced % 5 == 0:
        reduced //= 5
        fives += 1
    if reduced != 1:
        return f"{numerator}/{denominator}"
    scale = max(twos, fives)
    scaled = abs(numerator) * (2 ** (scale - twos)) * (5 ** (scale - fives))
    digits = str(scaled).rjust(scale + 1, '0')
    whole = digits[:-scale] if scale else digits
    fraction = digits[-scale:].rstrip('0') if scale else ''
    rendered = whole + (f".{fraction}" if fraction else '')
    return f"-{rendered}" if numerator < 0 else rendered

def run_command(cmd_str):
    key = (cmd_str, repo_root, 30)
    if key in command_cache:
        return command_cache[key]
    try:
        result = subprocess.run(
            shlex.split(cmd_str), capture_output=True, cwd=repo_root, timeout=30
        )
    except (subprocess.TimeoutExpired, OSError) as error:
        print(f"  WARN  command unavailable: {cmd_str[:60]}: {error}", file=sys.stderr)
        result = None
    command_cache[key] = result
    return result

def measure(artifact):
    kind = artifact['kind']
    if kind == 'process-output':
        cmd_str = os.path.expandvars(artifact['command'])
        result = run_command(cmd_str)
        if result is None or result.returncode != 0:
            return None, None   # tool not installed; treat as MISS
        raw = result.stdout
        return len(raw), hashlib.sha256(raw).hexdigest()
    elif kind == 'file':
        path = os.path.expanduser(artifact['path'])
        if not os.path.exists(path):
            return None, None
        with open(path, 'rb') as f:
            raw = f.read()
        return len(raw), hashlib.sha256(raw).hexdigest()
    elif kind == 'metric':
        cmd_str = os.path.expandvars(artifact['command'])
        json_key = artifact['json_key']
        result = run_command(cmd_str)
        if result is None or result.returncode != 0 or not result.stdout:
            return None, None
        if cmd_str not in json_cache:
            try:
                json_cache[cmd_str] = json.loads(result.stdout)
            except json.JSONDecodeError:
                print(f"  WARN  metric command output was not valid JSON: {cmd_str[:60]}", file=sys.stderr)
                json_cache[cmd_str] = None
        parsed = json_cache[cmd_str]
        if not isinstance(parsed, dict) or json_key not in parsed:
            print(f"  WARN  json_key '{json_key}' not found in metric output: {cmd_str[:60]}", file=sys.stderr)
            return None, None
        value = parsed[json_key]
        if (
            not isinstance(value, (int, float))
            or isinstance(value, bool)
            or (isinstance(value, float) and not math.isfinite(value))
            or (value < 0 and not artifact.get('allow_negative', False))
        ):
            print(f"  WARN  json_key '{json_key}' must be finite and non-negative: {value!r}", file=sys.stderr)
            return None, None
        value_hash = hashlib.sha256(json.dumps(value, sort_keys=True).encode()).hexdigest()
        return value, value_hash
    else:
        raise ValueError(f"Unknown kind: {kind}")

for art in artifacts:
    art_id = art['id']
    host_only = art.get('host_only', False)
    if mode == 'rebaseline' and host_only and not include_host:
        print(f"  SKIP  {art_id} (host_only; pass --include-host to rebaseline)")
        continue
    if host_only and in_ci:
        print(f"  SKIP  {art_id} (host_only, running in CI)")
        continue

    cur_bytes, cur_sha = measure(art)
    if cur_bytes is None:
        if art.get('kind') == 'metric' and not art.get('optional', False):
            msg = f"{art_id}: measurement unavailable"
            print(f"  FAIL  {msg}")
            acquisition_errors.append(msg)
        else:
            print(f"  MISS  {art_id}: path or command unavailable, skipping")
        continue

    unit = 'bytes' if art['kind'] != 'metric' else art.get('json_key', 'value')
    if 'size_bytes' not in art:
        print(f"ERROR: missing size_bytes for {art_id}", file=sys.stderr)
        sys.exit(2)
    baseline = art['size_bytes']
    tol = art.get('tolerance', data.get('tolerance_default', 0.05))
    baseline_fraction = numeric_fraction(
        baseline, f"size_bytes for {art_id}", integer_only=art['kind'] != 'metric'
    )
    tolerance_fraction = numeric_fraction(tol, f"tolerance for {art_id}")
    comparison = art.get('comparison', 'maximum')
    if comparison not in ('maximum', 'minimum', 'exact'):
        print(f"ERROR: invalid comparison for {art_id}: {comparison!r}", file=sys.stderr)
        sys.exit(2)
    upper_fraction = baseline_fraction * (1 + tolerance_fraction)
    lower_fraction = baseline_fraction * (1 - tolerance_fraction)
    if art['kind'] == 'metric':
        upper = upper_fraction
        lower = lower_fraction
    else:
        upper = upper_fraction.numerator // upper_fraction.denominator
        lower = -(-lower_fraction.numerator // lower_fraction.denominator)
    upper_display = display_fraction(upper)
    lower_display = display_fraction(lower)
    current_fraction = Fraction(Decimal(str(cur_bytes)))

    if comparison == 'maximum':
        breached = current_fraction > upper
        detail = f"{cur_bytes} {unit} > budget {upper_display}"
    elif comparison == 'minimum':
        breached = current_fraction < lower
        detail = f"{cur_bytes} {unit} < floor {lower_display}"
    else:
        breached = current_fraction < lower or current_fraction > upper
        detail = f"{cur_bytes} {unit} outside {lower_display}..{upper_display}"

    if mode == 'dry-run':
        flag = 'BREACH' if breached else 'OK    '
        suffix = f"; {detail}" if breached else ""
        print(f"  {flag}  {art_id}: {cur_bytes} {unit} (baseline {baseline}, comparison {comparison}{suffix})")
    elif mode == 'compare':
        if breached:
            tolerance_percent = display_fraction(tolerance_fraction * 100)
            msg = f"BUDGET BREACH  {art_id}: {detail} (baseline {baseline}, tolerance {tolerance_percent}%)"
            print(f"  FAIL  {msg}")
            budget_breaches.append(msg)
        else:
            print(f"  OK    {art_id}: {cur_bytes} {unit} (comparison {comparison}, baseline {baseline})")
    elif mode == 'rebaseline':
        if breached and art_id not in allow_breach:
            msg = f"{art_id}: rebaseline would bless comparison breach ({detail})"
            print(f"  FAIL  {msg}")
            rebaseline_errors.append(msg)
            continue
        pending_updates.append((art, cur_bytes, cur_sha))
        label = 'OVERRIDE' if breached else 'SET     '
        print(f"  {label}  {art_id}: {baseline} -> {cur_bytes} {unit}")

if acquisition_errors or rebaseline_errors:
    if acquisition_errors:
        print(f"\n{len(acquisition_errors)} required acquisition error(s).")
    if rebaseline_errors:
        print(f"\n{len(rebaseline_errors)} unreviewed comparison breach(es).")
    print("Manifest not updated.")
    sys.exit(1)

if mode == 'rebaseline':
    for art, cur_bytes, cur_sha in pending_updates:
        art['size_bytes'] = cur_bytes
        if cur_sha:
            art['sha256'] = cur_sha
    data['generated_at'] = datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
    if reason:
        data.setdefault('rebaseline_history', []).append(
            {'at': data['generated_at'], 'reason': reason}
        )
    dirpath = os.path.dirname(manifest_path)
    with tempfile.NamedTemporaryFile('w', dir=dirpath, delete=False, suffix='.tmp') as tmp:
        json.dump(data, tmp, indent=2)
        tmp.write('\n')
        tmpname = tmp.name
    os.replace(tmpname, manifest_path)
    print(f"\nManifest updated: {manifest_path}")

if budget_breaches:
    print(f"\n{len(budget_breaches)} artifact(s) exceeded budget.")
    if budget_mode == 'advisory':
        print("BUDGET_MODE=advisory — exiting 0 (warnings only)")
        sys.exit(0)
    sys.exit(1)
elif mode == 'compare':
    print("\nAll artifacts within budget.")
PYEOF

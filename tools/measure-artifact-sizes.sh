#!/usr/bin/env bash
# tools/measure-artifact-sizes.sh — artifact size budget regression tool
#
# Measures byte sizes of always-on session artifacts against committed baselines.
# Artifacts: bootstrap payload, AGENTS.md files, ~/.augment/rules/*.md
#
# Usage:
#   measure-artifact-sizes.sh [--dry-run]           measure + compare vs baselines
#   measure-artifact-sizes.sh --rebaseline --reason "text"  regenerate baselines
#   measure-artifact-sizes.sh --help
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

usage() {
  grep '^#' "$0" | sed 's/^# \{0,1\}//' | tail -n +2
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)    MODE="dry-run" ;;
    --rebaseline) MODE="rebaseline" ;;
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

python3 - "$REPO_ROOT" "$MANIFEST" "$MODE" "$REASON" "$BUDGET_MODE" <<'PYEOF'
import sys, json, os, subprocess, hashlib, shlex, tempfile, datetime

repo_root, manifest_path, mode, reason, budget_mode = sys.argv[1:]

if budget_mode not in ('strict', 'advisory'):
    print(f"ERROR: BUDGET_MODE must be 'strict' or 'advisory', got: {budget_mode!r}", file=sys.stderr)
    sys.exit(2)

with open(manifest_path) as f:
    data = json.load(f)

artifacts = data['artifacts']
in_ci = bool(os.environ.get('CI'))
failures = []
updates = []

def measure(artifact):
    kind = artifact['kind']
    if kind == 'process-output':
        cmd_str = os.path.expandvars(artifact['command'])
        try:
            result = subprocess.run(
                shlex.split(cmd_str), capture_output=True, cwd=repo_root, timeout=30
            )
        except subprocess.TimeoutExpired:
            print(f"  WARN  subprocess timed out after 30s: {cmd_str[:60]}", file=sys.stderr)
            return None, None
        if result.returncode != 0 or not result.stdout:
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
    else:
        raise ValueError(f"Unknown kind: {kind}")

for art in artifacts:
    art_id = art['id']
    host_only = art.get('host_only', False)
    if host_only and in_ci:
        print(f"  SKIP  {art_id} (host_only, running in CI)")
        continue

    cur_bytes, cur_sha = measure(art)
    if cur_bytes is None:
        print(f"  MISS  {art_id}: path not found, skipping")
        continue

    baseline = art['size_bytes']
    tol = art.get('tolerance', data.get('tolerance_default', 0.05))
    budget = int(baseline * (1 + tol))

    if mode == 'dry-run':
        flag = 'OVER' if cur_bytes > budget else 'OK  '
        print(f"  {flag}  {art_id}: {cur_bytes} bytes (baseline {baseline}, budget {budget})")
    elif mode == 'compare':
        if cur_bytes > budget:
            msg = f"BUDGET BREACH  {art_id}: {cur_bytes} bytes > budget {budget} (baseline {baseline}, +{tol*100:.0f}%)"
            print(f"  FAIL  {msg}")
            failures.append(msg)
        else:
            print(f"  OK    {art_id}: {cur_bytes} bytes (budget {budget})")
    elif mode == 'rebaseline':
        art['size_bytes'] = cur_bytes
        if cur_sha:
            art['sha256'] = cur_sha
        print(f"  SET   {art_id}: {baseline} -> {cur_bytes} bytes")

if mode == 'rebaseline':
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

if failures:
    print(f"\n{len(failures)} artifact(s) exceeded budget.")
    if budget_mode == 'advisory':
        print("BUDGET_MODE=advisory — exiting 0 (warnings only)")
        sys.exit(0)
    sys.exit(1)
elif mode == 'compare':
    print("\nAll artifacts within budget.")
PYEOF

#!/usr/bin/env bats
# tests/harness/artifact-budgets.bats
# Byte-size budget regression tests for always-on session artifacts.
# See docs/harness/artifact-budgets.md for the full budget contract.
#
# BUDGET_MODE env var: strict (default, fail on breach) or advisory (warn, pass).
# Host-only artifacts are skipped in CI (CI env var set).
#
# The manifest ships EMPTY of artifact rows -- populate it locally with
# `tools/measure-artifact-sizes.sh --rebaseline` and add matching `@test`
# blocks below. Two suite-wide tests always run: the drift catcher (host-only)
# and the measure-script smoke test.

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
MEASURE="$REPO_ROOT/tools/measure-artifact-sizes.sh"
MANIFEST="$REPO_ROOT/tests/harness/artifact-baselines.json"

# ---------------------------------------------------------------------------
# Drift catcher: every ~/.augment/rules/*.md must have a manifest entry.
# Host-only; skipped in CI.
# ---------------------------------------------------------------------------

@test "drift catcher: no untracked augment rule files" {
  if [ -n "${CI:-}" ]; then
    skip "host-only check; skipped in CI"
  fi
  if [ ! -d "$HOME/.augment/rules" ]; then
    skip "~/.augment/rules not present on this host"
  fi

  python3 - "$MANIFEST" <<'PYEOF'
import sys, json, os, glob

manifest_path = sys.argv[1]
with open(manifest_path) as f:
    data = json.load(f)

tracked = set()
for art in data['artifacts']:
    if art.get('kind') == 'file' and '/.augment/rules/' in art.get('path', ''):
        tracked.add(os.path.basename(os.path.expanduser(art['path'])))

if not tracked:
    # Empty template: the drift catcher is opt-in. Once the manifest tracks
    # at least one augment rule file, this check activates and enforces
    # that every rule file has a manifest entry.
    print("SKIP: manifest tracks 0 augment rule files (drift catcher inactive)")
    sys.exit(0)

rule_dir = os.path.expanduser('~/.augment/rules')
untracked = []
for fp in sorted(glob.glob(os.path.join(rule_dir, '*.md'))):
    fname = os.path.basename(fp)
    if fname not in tracked:
        untracked.append(fname)

if untracked:
    print("UNTRACKED rule files (add to artifact-baselines.json):")
    for f in untracked:
        print(f"  {f}")
    sys.exit(1)
print(f"OK: {len(tracked)} augment rule files tracked, none untracked")
PYEOF
}

# ---------------------------------------------------------------------------
# Smoke test: measure script itself runs cleanly
# ---------------------------------------------------------------------------

@test "measure-artifact-sizes.sh --dry-run exits 0" {
  run bash "$MEASURE" --dry-run
  [ "$status" -eq 0 ]
}

@test "measure-artifact-sizes.sh --help exits 0" {
  run bash "$MEASURE" --help
  [ "$status" -eq 0 ]
}

@test "artifact manifest is valid JSON" {
  run python3 -c "import json,sys; json.load(open('$MANIFEST'))"
  [ "$status" -eq 0 ]
}

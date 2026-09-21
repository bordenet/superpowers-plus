#!/usr/bin/env bats
# tests/harness/artifact-budgets.bats
# Byte-size budget regression tests for always-on session artifacts.
# See docs/harness/artifact-budgets.md for the full budget contract.
#
# BUDGET_MODE env var: strict (default, fail on breach) or advisory (warn, pass).
# Host-only artifacts are skipped in CI (CI env var set).
#
# The manifest contains repo metrics that run in CI and host-only metrics that
# run on developer machines. The measure script evaluates every manifest row;
# tests below verify the runner plus deterministic repo/host fixtures.

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
MEASURE="$REPO_ROOT/tools/measure-artifact-sizes.sh"
MANIFEST="$REPO_ROOT/tests/harness/artifact-baselines.json"
REPORT="$REPO_ROOT/tools/resident-cost-report.py"
RESIDENT_FIXTURE="$REPO_ROOT/test/fixtures/resident-cost"

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

@test "artifact budgets compare and expose advisory output" {
  run bash "$MEASURE"
  printf '%s\n' "$output" >&3
  [ "$status" -eq 0 ]
  [[ "$output" == *"resident-listing-bytes"* ]]
}

@test "measure-artifact-sizes.sh --help exits 0" {
  run bash "$MEASURE" --help
  [ "$status" -eq 0 ]
}

@test "artifact manifest is valid JSON" {
  run python3 -c "import json,sys; json.load(open('$MANIFEST'))"
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Resident-cost report: deterministic repo and host fixtures
# ---------------------------------------------------------------------------

@test "resident-cost --repo classifies automatic, manual, internal, and duplicate skills" {
  run python3 "$REPORT" --repo --repo-root "$RESIDENT_FIXTURE/repo" --json
  [ "$status" -eq 0 ]

  REPORT_JSON="$output" python3 - <<'PYEOF'
import json
import os

report = json.loads(os.environ["REPORT_JSON"])
assert report["schema_version"] == 1
assert report["listing_bytes"] == 137
assert report["listing_tokens_est"] == 34
assert report["auto_count"] == 2
assert report["manual_count"] == 3
assert report["internal_count"] == 1
assert report["max_description_bytes"] == 260
assert report["max_description_skill"] == "long-manual-skill"
assert report["max_skill_md_bytes"] == 458
assert report["max_skill_md_skill"] == "long-manual-skill"
assert report["descriptions_over_250"] == 1
assert report["duplicate_names"] == 0
assert report["all_name_collisions"] == 1
assert report["skill_files_scanned"] == 5
assert report["parse_failures"] == 0
PYEOF
}

@test "resident-cost fixture cannot masquerade as a live project skill" {
  [ ! -d "$RESIDENT_FIXTURE/home/.claude/skills" ]
  [ -d "$RESIDENT_FIXTURE/home/dot-claude/skills" ]
}

@test "resident-cost --host measures installed skills, commands, plugin payload, and router hints" {
  fixture_home="$BATS_TEST_TMPDIR/home"
  cp -R "$RESIDENT_FIXTURE/home" "$fixture_home"
  mv "$fixture_home/dot-claude" "$fixture_home/.claude"
  mkdir -p "$fixture_home/.claude/plugins"
  cp -R "$RESIDENT_FIXTURE/plugin-cache" "$fixture_home/plugin-cache"
  mkdir -p "$fixture_home/.claude/projects/old"
  printf '%s\n' '{"type":"unrelated"}' >"$fixture_home/.claude/projects/old/old.jsonl"
  python3 - "$fixture_home/.claude/projects/old/old.jsonl" \
    "$fixture_home/.claude/projects/demo/session.jsonl" <<'PYEOF'
from datetime import datetime
import os
import sys

old_path, current_path = sys.argv[1:]
os.utime(old_path, (datetime.fromisoformat("2026-09-17T11:00:00+00:00").timestamp(),) * 2)
os.utime(current_path, (datetime.fromisoformat("2026-09-17T12:00:02+00:00").timestamp(),) * 2)
PYEOF

  python3 - "$fixture_home/.claude/plugins/installed_plugins.json" \
    "$fixture_home/plugin-cache/demoplugin" <<'PYEOF'
import json
import sys

path, install_path = sys.argv[1:]
with open(path, "w", encoding="utf-8") as fh:
    json.dump(
        {
            "plugins": {
                "demoplugin@demo-marketplace": [
                    {"installPath": install_path}
                ]
            }
        },
        fh,
    )
PYEOF

  run env HOME=/var/empty CLAUDE_CONFIG_DIR="$fixture_home/.claude" \
    python3 "$REPORT" --host --json
  [ "$status" -eq 0 ]

  REPORT_JSON="$output" python3 - <<'PYEOF'
import json
import os

report = json.loads(os.environ["REPORT_JSON"])
assert report["schema_version"] == 1
assert report["host_entries"] == 4
assert report["host_hidden_entries"] == 2
assert report["host_listing_bytes"] == 103
assert report["host_listing_tokens_est"] == 26
assert report["host_duplicate_entries"] == 2
assert report["host_all_collision_entries"] == 3
assert report["host_sessionstart_context_bytes"] == 41
assert report["host_sessionstart_tokens_est"] == 10
assert report["host_sessionstart_output_count"] == 3
assert report["host_sessionstart_observed_at"] == "2026-09-17T12:00:01.200Z"
assert report["host_sessionstart_transcript_files_scanned"] == 1
assert report["host_parse_failures"] == 0
assert report["host_missing_plugins"] == 0
assert report["router_prompts"] == 4
assert report["router_hint_rate"] == 50.0
assert report["router_hints_per_prompt"] == 0.75
assert report["router_metrics_records_sampled"] == 4
assert 0 < report["router_metrics_bytes_read"] <= 1024 * 1024
assert report["router_metrics_truncated"] is False
PYEOF

  [ ! -e "$fixture_home/plugin-cache/demoplugin/hook-executed" ]
}

@test "resident-cost --host fails when an enabled plugin is missing from the registry" {
  fixture_home="$BATS_TEST_TMPDIR/incomplete-home"
  cp -R "$RESIDENT_FIXTURE/home" "$fixture_home"
  mv "$fixture_home/dot-claude" "$fixture_home/.claude"

  run env CLAUDE_CONFIG_DIR="$fixture_home/.claude" python3 "$REPORT" --host --json
  [ "$status" -eq 1 ]
  [[ "$output" == *"enabled plugin missing from registry"* ]]
}

@test "resident-cost --host fails on malformed installed frontmatter" {
  fixture_home="$BATS_TEST_TMPDIR/malformed-home"
  cp -R "$RESIDENT_FIXTURE/home" "$fixture_home"
  mv "$fixture_home/dot-claude" "$fixture_home/.claude"
  cp -R "$RESIDENT_FIXTURE/plugin-cache" "$fixture_home/plugin-cache"
  mkdir -p "$fixture_home/.claude/plugins" "$fixture_home/.claude/skills/broken"
  printf '%s\n' '---' 'name: broken' >"$fixture_home/.claude/skills/broken/SKILL.md"
  python3 - "$fixture_home/.claude/plugins/installed_plugins.json" \
    "$fixture_home/plugin-cache/demoplugin" <<'PYEOF'
import json
import sys

with open(sys.argv[1], "w", encoding="utf-8") as fh:
    json.dump({"plugins":{"demoplugin@demo-marketplace":[{"installPath":sys.argv[2]}]}}, fh)
PYEOF

  run env CLAUDE_CONFIG_DIR="$fixture_home/.claude" python3 "$REPORT" --host --json
  [ "$status" -eq 1 ]
  [[ "$output" == *"host frontmatter incomplete"* ]]
}

@test "resident-cost --host follows symlinked skill directories without looping" {
  fixture_home="$BATS_TEST_TMPDIR/symlink-home"
  mkdir -p "$fixture_home/.claude/skills" "$fixture_home/linked-target"
  printf '%s\n' '{}' >"$fixture_home/.claude/settings.json"
  cat >"$fixture_home/linked-target/SKILL.md" <<'MDEOF'
---
name: linked-skill
description: Linked fixture skill
---
# Linked fixture
MDEOF
  ln -s "$fixture_home/linked-target" "$fixture_home/.claude/skills/linked-skill"
  ln -s "$fixture_home/.claude/skills" "$fixture_home/.claude/skills/loop"

  run env CLAUDE_CONFIG_DIR="$fixture_home/.claude" python3 "$REPORT" --host --json
  [ "$status" -eq 0 ]

  REPORT_JSON="$output" python3 - <<'PYEOF'
import json
import os

report = json.loads(os.environ["REPORT_JSON"])
assert report["host_entries"] == 1
assert report["host_listing_bytes"] == len("linked-skillLinked fixture skill")
assert report["host_parse_failures"] == 0
PYEOF
}

@test "SessionStart scan fails closed when its global byte bound is exhausted" {
  fixture_home="$BATS_TEST_TMPDIR/bounded-transcript-home"
  mkdir -p "$fixture_home/.claude/projects/demo"
  printf '%s\n' '{}' >"$fixture_home/.claude/settings.json"
  python3 - "$fixture_home/.claude/projects/demo/session.jsonl" <<'PYEOF'
from pathlib import Path
import sys

Path(sys.argv[1]).write_text('{"type":"unrelated"}\n' * 40, encoding="utf-8")
PYEOF

  run python3 - "$REPORT" "$fixture_home/.claude" <<'PYEOF'
import importlib.util
from pathlib import Path
import sys

spec = importlib.util.spec_from_file_location("resident_cost_report", sys.argv[1])
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
try:
    module.latest_sessionstart_observation(Path(sys.argv[2]), max_bytes=128)
except module.ReportError as error:
    print(error)
    raise SystemExit(0)
raise SystemExit("expected transcript scan to fail closed")
PYEOF
  [ "$status" -eq 0 ]
  [[ "$output" == *"transcript scan byte limit"* ]]
}

@test "SessionStart parent converts a delayed worker into a hard timeout" {
  fixture_home="$BATS_TEST_TMPDIR/timed-transcript-home"
  mkdir -p "$fixture_home/projects/demo"
  : >"$fixture_home/projects/demo/empty.jsonl"

  run python3 - "$REPORT" "$fixture_home" <<'PYEOF'
import importlib.util
from pathlib import Path
import subprocess
import sys

spec = importlib.util.spec_from_file_location("resident_cost_report", sys.argv[1])
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

def delayed_worker(*args, **kwargs):
    raise subprocess.TimeoutExpired(args[0], kwargs.get("timeout", 0))

module.subprocess.run = delayed_worker
try:
    module.latest_sessionstart_observation(Path(sys.argv[2]), timeout_seconds=0.01)
except module.ReportError as error:
    print(error)
    raise SystemExit(0)
raise SystemExit("expected parent-side transcript timeout")
PYEOF
  [ "$status" -eq 0 ]
  [[ "$output" == *"transcript scan time limit"* ]]
}

@test "router metrics use a bounded recent window" {
  metrics="$BATS_TEST_TMPDIR/router-metrics.jsonl"
  python3 - "$metrics" <<'PYEOF'
from pathlib import Path
import json
import sys

rows = [json.dumps({"hints": [str(index)] if index % 2 else []}) for index in range(40)]
Path(sys.argv[1]).write_text("\n".join(rows) + "\n", encoding="utf-8")
PYEOF

  run python3 - "$REPORT" "$metrics" <<'PYEOF'
import importlib.util
from pathlib import Path
import sys

spec = importlib.util.spec_from_file_location("resident_cost_report", sys.argv[1])
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
report = module.router_hint_observation(Path(sys.argv[2]), max_bytes=128, max_records=2)
assert report["router_prompts"] == 2
assert report["router_metrics_records_sampled"] == 2
assert report["router_metrics_bytes_read"] <= 128
assert report["router_metrics_truncated"] is True
PYEOF
  [ "$status" -eq 0 ]
}

@test "resident-cost --repo fails when the skills directory is missing" {
  fixture_repo="$BATS_TEST_TMPDIR/no-skills"
  mkdir -p "$fixture_repo"

  run python3 "$REPORT" --repo --repo-root "$fixture_repo" --json
  [ "$status" -eq 1 ]
  [[ "$output" == *"skills directory not found"* ]]
}

@test "required repo metric fails closed when its command fails" {
  fixture_repo="$BATS_TEST_TMPDIR/metric-failure"
  mkdir -p "$fixture_repo/tools" "$fixture_repo/tests/harness"
  cp "$MEASURE" "$fixture_repo/tools/measure-artifact-sizes.sh"

  cat >"$fixture_repo/tests/harness/artifact-baselines.json" <<'JSONEOF'
{
  "version": 1,
  "tolerance_default": 0.05,
  "artifacts": [
    {
      "id": "broken-required-metric",
      "kind": "metric",
      "command": "python3 tools/does-not-exist.py",
      "json_key": "value",
      "size_bytes": 1,
      "host_only": false
    }
  ]
}
JSONEOF

  run env BUDGET_MODE=strict bash "$fixture_repo/tools/measure-artifact-sizes.sh"
  [ "$status" -eq 1 ]
  [[ "$output" == *"FAIL  broken-required-metric: measurement unavailable"* ]]
}

@test "manifest rejects duplicate artifact IDs before measurement" {
  fixture_repo="$BATS_TEST_TMPDIR/duplicate-artifact-ids"
  mkdir -p "$fixture_repo/tools" "$fixture_repo/tests/harness"
  cp "$MEASURE" "$fixture_repo/tools/measure-artifact-sizes.sh"
  cat >"$fixture_repo/tools/metric.py" <<'PYEOF'
from pathlib import Path
import json

Path("measured").write_text("yes")
print(json.dumps({"first": 1, "second": 2}))
PYEOF
  cat >"$fixture_repo/tests/harness/artifact-baselines.json" <<'JSONEOF'
{"version":1,"generated_at":"unchanged","artifacts":[
  {"id":"duplicate","kind":"metric","command":"python3 tools/metric.py","json_key":"first","size_bytes":0,"host_only":false},
  {"id":"duplicate","kind":"metric","command":"python3 tools/metric.py","json_key":"second","size_bytes":0,"host_only":false}
]}
JSONEOF
  cp "$fixture_repo/tests/harness/artifact-baselines.json" "$fixture_repo/before.json"

  run env FORCE_REBASELINE=1 bash "$fixture_repo/tools/measure-artifact-sizes.sh" \
    --rebaseline --allow-breach duplicate --reason "must reject ambiguity"
  [ "$status" -eq 2 ]
  [[ "$output" == *"duplicate artifact ID"* ]]
  [ ! -e "$fixture_repo/measured" ]
  cmp "$fixture_repo/before.json" "$fixture_repo/tests/harness/artifact-baselines.json"
}

@test "attempted host metric fails closed outside CI" {
  fixture_repo="$BATS_TEST_TMPDIR/host-metric-failure"
  mkdir -p "$fixture_repo/tools" "$fixture_repo/tests/harness"
  cp "$MEASURE" "$fixture_repo/tools/measure-artifact-sizes.sh"

  cat >"$fixture_repo/tests/harness/artifact-baselines.json" <<'JSONEOF'
{
  "version": 1,
  "tolerance_default": 0.05,
  "artifacts": [
    {
      "id": "broken-host-metric",
      "kind": "metric",
      "command": "python3 tools/does-not-exist.py",
      "json_key": "value",
      "size_bytes": 1,
      "host_only": true
    }
  ]
}
JSONEOF

  run env -u CI BUDGET_MODE=strict bash "$fixture_repo/tools/measure-artifact-sizes.sh"
  [ "$status" -eq 1 ]
  [[ "$output" == *"FAIL  broken-host-metric: measurement unavailable"* ]]
}

@test "metric comparison rejects non-finite values and unexpected scan-count drops" {
  fixture_repo="$BATS_TEST_TMPDIR/metric-integrity"
  mkdir -p "$fixture_repo/tools" "$fixture_repo/tests/harness"
  cp "$MEASURE" "$fixture_repo/tools/measure-artifact-sizes.sh"

  cat >"$fixture_repo/tools/metrics.py" <<'PYEOF'
import json
print(json.dumps({"not_finite": float("nan"), "negative": -1, "huge": 10 ** 1000, "scanned": 3}))
PYEOF
  cat >"$fixture_repo/tests/harness/artifact-baselines.json" <<'JSONEOF'
{
  "version": 1,
  "tolerance_default": 0.05,
  "artifacts": [
    {
      "id": "finite-required",
      "kind": "metric",
      "command": "python3 tools/metrics.py",
      "json_key": "not_finite",
      "size_bytes": 0,
      "host_only": false
    },
    {
      "id": "scan-floor",
      "kind": "metric",
      "command": "python3 tools/metrics.py",
      "json_key": "scanned",
      "size_bytes": 4,
      "comparison": "minimum",
      "tolerance": 0,
      "host_only": false
    },
    {
      "id": "negative-count",
      "kind": "metric",
      "command": "python3 tools/metrics.py",
      "json_key": "negative",
      "size_bytes": 0,
      "host_only": false
    },
    {
      "id": "huge-count",
      "kind": "metric",
      "command": "python3 tools/metrics.py",
      "json_key": "huge",
      "size_bytes": 0,
      "host_only": false
    }
  ]
}
JSONEOF

  run env BUDGET_MODE=strict bash "$fixture_repo/tools/measure-artifact-sizes.sh"
  [ "$status" -eq 1 ]
  [[ "$output" == *"finite-required: measurement unavailable"* ]]
  [[ "$output" == *"negative-count: measurement unavailable"* ]]
  [[ "$output" == *"scan-floor: 3 scanned < floor 4"* ]]
  [[ "$output" == *"BUDGET BREACH  huge-count"* ]]
}

@test "huge integer metric remains comparable after rebaseline" {
  fixture_repo="$BATS_TEST_TMPDIR/huge-metric"
  mkdir -p "$fixture_repo/tools" "$fixture_repo/tests/harness"
  cp "$MEASURE" "$fixture_repo/tools/measure-artifact-sizes.sh"
  cat >"$fixture_repo/tools/metric.py" <<'PYEOF'
import json
print(json.dumps({"huge": 10 ** 1000 - 1, "rate": 0.1}))
PYEOF
  cat >"$fixture_repo/tests/harness/artifact-baselines.json" <<'JSONEOF'
{"version":1,"artifacts":[
  {"id":"huge","kind":"metric","command":"python3 tools/metric.py","json_key":"huge","size_bytes":0,"comparison":"exact","tolerance":0,"host_only":false},
  {"id":"fractional-rate","kind":"metric","command":"python3 tools/metric.py","json_key":"rate","size_bytes":0.1,"comparison":"exact","tolerance":0,"host_only":false}
]}
JSONEOF

  run env FORCE_REBASELINE=1 bash "$fixture_repo/tools/measure-artifact-sizes.sh" \
    --rebaseline --allow-breach huge --allow-breach fractional-rate \
    --reason "exact numeric regression"
  [ "$status" -eq 0 ]

  run env BUDGET_MODE=strict bash "$fixture_repo/tools/measure-artifact-sizes.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"OK    huge"* ]]
  [[ "$output" == *"OK    fractional-rate"* ]]
}

@test "required acquisition errors stay blocking in advisory mode" {
  fixture_repo="$BATS_TEST_TMPDIR/advisory-acquisition"
  mkdir -p "$fixture_repo/tools" "$fixture_repo/tests/harness"
  cp "$MEASURE" "$fixture_repo/tools/measure-artifact-sizes.sh"
  cat >"$fixture_repo/tests/harness/artifact-baselines.json" <<'JSONEOF'
{"version":1,"artifacts":[{"id":"required","kind":"metric","command":"python3 tools/missing.py","json_key":"value","size_bytes":0,"host_only":false}]}
JSONEOF

  run env BUDGET_MODE=advisory bash "$fixture_repo/tools/measure-artifact-sizes.sh"
  [ "$status" -eq 1 ]
  [[ "$output" == *"required acquisition error"* ]]
}

@test "advisory mode softens only genuine budget breaches" {
  fixture_repo="$BATS_TEST_TMPDIR/advisory-breach"
  mkdir -p "$fixture_repo/tools" "$fixture_repo/tests/harness"
  cp "$MEASURE" "$fixture_repo/tools/measure-artifact-sizes.sh"
  cat >"$fixture_repo/tools/metric.py" <<'PYEOF'
import json
print(json.dumps({"value": 2}))
PYEOF
  cat >"$fixture_repo/tests/harness/artifact-baselines.json" <<'JSONEOF'
{"version":1,"artifacts":[{"id":"over","kind":"metric","command":"python3 tools/metric.py","json_key":"value","size_bytes":1,"tolerance":0,"host_only":false}]}
JSONEOF

  run env BUDGET_MODE=advisory bash "$fixture_repo/tools/measure-artifact-sizes.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"BUDGET BREACH"* ]]
  [[ "$output" == *"warnings only"* ]]
}

@test "failed rebaseline leaves the manifest byte-identical" {
  fixture_repo="$BATS_TEST_TMPDIR/rebaseline-atomic"
  mkdir -p "$fixture_repo/tools" "$fixture_repo/tests/harness"
  cp "$MEASURE" "$fixture_repo/tools/measure-artifact-sizes.sh"
  cat >"$fixture_repo/tools/good.py" <<'PYEOF'
import json
print(json.dumps({"value": 2}))
PYEOF
  cat >"$fixture_repo/tests/harness/artifact-baselines.json" <<'JSONEOF'
{"version":1,"generated_at":"unchanged","artifacts":[
  {"id":"good","kind":"metric","command":"python3 tools/good.py","json_key":"value","size_bytes":1,"host_only":false},
  {"id":"bad","kind":"metric","command":"python3 tools/missing.py","json_key":"value","size_bytes":1,"host_only":false}
]}
JSONEOF
  cp "$fixture_repo/tests/harness/artifact-baselines.json" "$fixture_repo/before.json"

  run env FORCE_REBASELINE=1 BUDGET_MODE=advisory \
    bash "$fixture_repo/tools/measure-artifact-sizes.sh" --rebaseline --reason "must not write"
  [ "$status" -eq 1 ]
  cmp "$fixture_repo/before.json" "$fixture_repo/tests/harness/artifact-baselines.json"
}

@test "rebaseline refuses to bless comparison breaches without explicit override" {
  fixture_repo="$BATS_TEST_TMPDIR/rebaseline-breach"
  mkdir -p "$fixture_repo/tools" "$fixture_repo/tests/harness"
  cp "$MEASURE" "$fixture_repo/tools/measure-artifact-sizes.sh"
  cat >"$fixture_repo/tools/metric.py" <<'PYEOF'
import json
print(json.dumps({"parse_failures": 1, "listing_bytes": 2}))
PYEOF
  cat >"$fixture_repo/tests/harness/artifact-baselines.json" <<'JSONEOF'
{"version":1,"generated_at":"unchanged","artifacts":[
  {"id":"parse-integrity","kind":"metric","command":"python3 tools/metric.py","json_key":"parse_failures","size_bytes":0,"comparison":"maximum","tolerance":0,"host_only":false},
  {"id":"listing-growth","kind":"metric","command":"python3 tools/metric.py","json_key":"listing_bytes","size_bytes":1,"comparison":"maximum","tolerance":0,"host_only":false}
]}
JSONEOF
  cp "$fixture_repo/tests/harness/artifact-baselines.json" "$fixture_repo/before.json"

  run env FORCE_REBASELINE=1 bash "$fixture_repo/tools/measure-artifact-sizes.sh" \
    --rebaseline --reason "must be reviewed"
  [ "$status" -eq 1 ]
  [[ "$output" == *"rebaseline would bless comparison breach"* ]]
  cmp "$fixture_repo/before.json" "$fixture_repo/tests/harness/artifact-baselines.json"

  run env FORCE_REBASELINE=1 bash "$fixture_repo/tools/measure-artifact-sizes.sh" \
    --rebaseline --allow-breach parse-integrity --reason "reviewed integrity contract change"
  [ "$status" -eq 1 ]
  [[ "$output" == *"OVERRIDE  parse-integrity"* ]]
  [[ "$output" == *"listing-growth: rebaseline would bless comparison breach"* ]]
  cmp "$fixture_repo/before.json" "$fixture_repo/tests/harness/artifact-baselines.json"

  run env FORCE_REBASELINE=1 bash "$fixture_repo/tools/measure-artifact-sizes.sh" \
    --rebaseline --allow-breach parse-integrity --allow-breach listing-growth \
    --reason "reviewed integrity and listing contract changes"
  [ "$status" -eq 0 ]
  [[ "$output" == *"OVERRIDE  parse-integrity"* ]]
  [[ "$output" == *"OVERRIDE  listing-growth"* ]]

  python3 - "$fixture_repo/tests/harness/artifact-baselines.json" <<'PYEOF'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as fh:
    artifacts = {row["id"]: row for row in json.load(fh)["artifacts"]}
assert artifacts["parse-integrity"]["size_bytes"] == 1
assert artifacts["listing-growth"]["size_bytes"] == 2
PYEOF
}

@test "empty process output is measured and minimum bounds round up" {
  fixture_repo="$BATS_TEST_TMPDIR/minimum-rounding"
  mkdir -p "$fixture_repo/tools" "$fixture_repo/tests/harness"
  cp "$MEASURE" "$fixture_repo/tools/measure-artifact-sizes.sh"
  cat >"$fixture_repo/tests/harness/artifact-baselines.json" <<'JSONEOF'
{"version":1,"artifacts":[
  {"id":"one-byte-floor","kind":"process-output","command":"true","size_bytes":1,"comparison":"minimum","tolerance":0.05,"host_only":false}
]}
JSONEOF

  run env BUDGET_MODE=strict bash "$fixture_repo/tools/measure-artifact-sizes.sh" --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"BREACH  one-byte-floor"* ]]
  [[ "$output" == *"floor 1"* ]]
}

@test "rebaseline leaves host-only values unchanged unless explicitly included" {
  fixture_repo="$BATS_TEST_TMPDIR/rebaseline-scope"
  mkdir -p "$fixture_repo/tools" "$fixture_repo/tests/harness"
  cp "$MEASURE" "$fixture_repo/tools/measure-artifact-sizes.sh"

  cat >"$fixture_repo/tools/metrics.py" <<'PYEOF'
import json
print(json.dumps({"repo": 2, "host": 9}))
PYEOF
  cat >"$fixture_repo/tests/harness/artifact-baselines.json" <<'JSONEOF'
{
  "version": 1,
  "tolerance_default": 0.05,
  "artifacts": [
    {
      "id": "repo-value",
      "kind": "metric",
      "command": "python3 tools/metrics.py",
      "json_key": "repo",
      "size_bytes": 1,
      "host_only": false
    },
    {
      "id": "host-value",
      "kind": "metric",
      "command": "python3 tools/metrics.py",
      "json_key": "host",
      "size_bytes": 5,
      "host_only": true
    }
  ]
}
JSONEOF

  run env FORCE_REBASELINE=1 bash "$fixture_repo/tools/measure-artifact-sizes.sh" \
    --rebaseline --allow-breach repo-value --reason "fixture"
  [ "$status" -eq 0 ]
  [[ "$output" == *"SKIP  host-value (host_only; pass --include-host to rebaseline)"* ]]

  python3 - "$fixture_repo/tests/harness/artifact-baselines.json" <<'PYEOF'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as fh:
    artifacts = {row["id"]: row for row in json.load(fh)["artifacts"]}
assert artifacts["repo-value"]["size_bytes"] == 2
assert artifacts["host-value"]["size_bytes"] == 5
PYEOF
}

@test "identical metric commands execute once per budget run" {
  fixture_repo="$BATS_TEST_TMPDIR/metric-cache"
  mkdir -p "$fixture_repo/tools" "$fixture_repo/tests/harness"
  cp "$MEASURE" "$fixture_repo/tools/measure-artifact-sizes.sh"

  cat >"$fixture_repo/tools/counting-metric.py" <<'PYEOF'
import json
from pathlib import Path

counter = Path("counter.txt")
count = int(counter.read_text() or "0") if counter.exists() else 0
counter.write_text(str(count + 1))
print(json.dumps({"first": 1, "second": 2}))
PYEOF
  cat >"$fixture_repo/tests/harness/artifact-baselines.json" <<'JSONEOF'
{
  "version": 1,
  "tolerance_default": 0.05,
  "artifacts": [
    {"id":"first","kind":"metric","command":"python3 tools/counting-metric.py","json_key":"first","size_bytes":1,"host_only":false},
    {"id":"second","kind":"metric","command":"python3 tools/counting-metric.py","json_key":"second","size_bytes":2,"host_only":false}
  ]
}
JSONEOF

  run env BUDGET_MODE=strict bash "$fixture_repo/tools/measure-artifact-sizes.sh"
  [ "$status" -eq 0 ]
  [ "$(cat "$fixture_repo/counter.txt")" -eq 1 ]
}

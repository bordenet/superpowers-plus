#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd -P)"
  export REPO_ROOT
}

_sha256() {
  python3 -c 'import hashlib, sys; print(hashlib.sha256(sys.stdin.buffer.read()).hexdigest())'
}

@test "router-precision reports hint rate, density, precision, and invocation source" {
  local fixture_dir metrics transcripts
  local prompt_auto prompt_explicit prompt_none prompt_miss
  local hash_auto hash_explicit hash_none hash_miss
  fixture_dir="$(mktemp -d "${BATS_TEST_TMPDIR}/router-precision.XXXXXX")"
  metrics="$fixture_dir/metrics.jsonl"
  transcripts="$fixture_dir/transcripts"
  mkdir -p "$transcripts"

  prompt_auto="Please diagnose the widget"
  prompt_explicit="/sp-brainstorm design this widget"
  prompt_none="Record this status"
  prompt_miss="Write a release plan"
  hash_auto="$(printf '%s' "$prompt_auto" | _sha256)"
  hash_explicit="$(printf '%s' "$prompt_explicit" | _sha256)"
  hash_none="$(printf '%s' "$prompt_none" | _sha256)"
  hash_miss="$(printf '%s' "$prompt_miss" | _sha256)"

  {
    printf '{"session_id":"s-auto","prompt_sha256":"%s","hints":["systematic-debugging"],"suggested":"systematic-debugging","score":2.1,"runner_up":0.4,"matched_terms":["diagnose"],"threshold":0.55}\n' "$hash_auto"
    printf '{"session_id":"s-explicit","prompt_sha256":"%s","hints":["brainstorming"],"suggested":"brainstorming","explicit_aliases":["/sp-brainstorm"],"score":3.2,"runner_up":0.2,"matched_terms":["brainstorm"],"threshold":0.55}\n' "$hash_explicit"
    printf '{"session_id":"s-none","prompt_sha256":"%s","hints":[],"suggested":null,"score":null,"runner_up":null,"matched_terms":[],"threshold":0.55}\n' "$hash_none"
    printf '{"session_id":"s-miss","prompt_sha256":"%s","hints":["writing-plans"],"suggested":"writing-plans","score":1.4,"runner_up":1.2,"matched_terms":["plan"],"threshold":0.55}\n' "$hash_miss"
  } > "$metrics"

  {
    printf '{"type":"user","message":{"role":"user","content":"%s"}}\n' "$prompt_auto"
    printf '%s\n' '{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","name":"Skill","input":{"skill":"systematic-debugging"}}]}}'
  } > "$transcripts/s-auto.jsonl"

  {
    printf '{"type":"user","message":{"role":"user","content":"%s"}}\n' "$prompt_explicit"
    printf '%s\n' '{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","name":"Skill","input":{"skill":"brainstorming"}}]}}'
  } > "$transcripts/s-explicit.jsonl"

  {
    printf '{"type":"user","message":{"role":"user","content":"%s"}}\n' "$prompt_none"
    printf '%s\n' '{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"Noted."}]}}'
  } > "$transcripts/s-none.jsonl"

  {
    printf '{"type":"user","message":{"role":"user","content":"%s"}}\n' "$prompt_miss"
    printf '%s\n' '{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","name":"Skill","input":{"skill":"test-driven-development"}}]}}'
  } > "$transcripts/s-miss.jsonl"

  run python3 "$REPO_ROOT/tools/router-precision.py" \
    --metrics "$metrics" \
    --transcripts "$transcripts" \
    --json

  [ "$status" -eq 0 ]
  ROUTER_PRECISION_JSON="$output" python3 -c '
import json
import os

report = json.loads(os.environ["ROUTER_PRECISION_JSON"])
assert report["prompts"] == 4, report
assert report["hinted_prompts"] == 3, report
assert report["total_hints"] == 3, report
assert report["hint_rate"] == 0.75, report
assert report["hints_per_prompt"] == 0.75, report
assert report["evaluable_suggestions"] == 3, report
assert report["correct_suggestions"] == 2, report
assert abs(report["precision"] - (2 / 3)) < 1e-9, report
assert report["matched_invocations"] == {"automatic": 1, "explicit": 1}, report
assert report["suggested_not_invoked"] == 1, report
'
}

@test "router-precision skips malformed and overlong JSONL records within configured bounds" {
  local fixture_dir metrics transcripts prompt prompt_hash
  fixture_dir="$(mktemp -d "${BATS_TEST_TMPDIR}/router-precision-bounds.XXXXXX")"
  metrics="$fixture_dir/metrics.jsonl"
  transcripts="$fixture_dir/transcripts"
  mkdir -p "$transcripts"
  prompt="Diagnose the bounded parser"
  prompt_hash="$(printf '%s' "$prompt" | _sha256)"

  python3 -c '
import sys
path, digest = sys.argv[1:]
valid = "{\"session_id\":\"safe-session\",\"prompt_sha256\":\"%s\",\"hints\":[\"systematic-debugging\"],\"suggested\":\"systematic-debugging\"}\n" % digest
with open(path, "w", encoding="utf-8") as handle:
    handle.write("x" * 400 + "\n")
    handle.write("{malformed}\n")
    handle.write(valid)
' "$metrics" "$prompt_hash"

  python3 -c '
import json
import sys
path, prompt = sys.argv[1:]
with open(path, "w", encoding="utf-8") as handle:
    handle.write("y" * 400 + "\n")
    handle.write(json.dumps({"type": "user", "message": {"content": prompt}}) + "\n")
    handle.write(json.dumps({"type": "assistant", "message": {"content": [{"type": "tool_use", "name": "Skill", "input": {"skill": "systematic-debugging"}}]}}) + "\n")
' "$transcripts/safe-session.jsonl" "$prompt"

  run python3 "$REPO_ROOT/tools/router-precision.py" \
    --metrics "$metrics" \
    --transcripts "$transcripts" \
    --max-line-bytes 256 \
    --json

  [ "$status" -eq 0 ]
  ROUTER_PRECISION_JSON="$output" python3 -c '
import json
import os

report = json.loads(os.environ["ROUTER_PRECISION_JSON"])
assert report["prompts"] == 1, report
assert report["evaluable_suggestions"] == 0, report
assert report["precision"] is None, report
assert report["skipped"]["metrics_lines"] == 2, report
assert report["skipped"]["transcript_lines"] == 1, report
'
}

@test "router-precision reports a metrics record limit without a metrics byte limit" {
  local fixture_dir metrics transcripts
  fixture_dir="$(mktemp -d "${BATS_TEST_TMPDIR}/router-precision-record-limit.XXXXXX")"
  metrics="$fixture_dir/metrics.jsonl"
  transcripts="$fixture_dir/transcripts"
  mkdir -p "$transcripts"
  {
    printf '%s\n' '{"session_id":null,"prompt_sha256":null,"hints":[],"suggested":null}'
    printf '%s\n' '{"session_id":null,"prompt_sha256":null,"hints":[],"suggested":null}'
  } > "$metrics"

  run python3 "$REPO_ROOT/tools/router-precision.py" \
    --metrics "$metrics" \
    --transcripts "$transcripts" \
    --max-records 1 \
    --json

  [ "$status" -eq 0 ]
  ROUTER_PRECISION_JSON="$output" python3 -c '
import json
import os

report = json.loads(os.environ["ROUTER_PRECISION_JSON"])
assert report["prompts"] == 1, report
assert report["skipped"]["metrics_record_limit"] is True, report
assert report["skipped"]["metrics_byte_limit"] is False, report
'
}

@test "router-precision reports a metrics byte limit without a metrics record limit" {
  local fixture_dir metrics transcripts
  fixture_dir="$(mktemp -d "${BATS_TEST_TMPDIR}/router-precision-byte-limit.XXXXXX")"
  metrics="$fixture_dir/metrics.jsonl"
  transcripts="$fixture_dir/transcripts"
  mkdir -p "$transcripts"

  python3 -c '
import json
import sys

with open(sys.argv[1], "w", encoding="utf-8") as handle:
    handle.write(json.dumps({
        "session_id": None,
        "prompt_sha256": None,
        "hints": [],
        "suggested": None,
    }) + "\n")
    handle.write(json.dumps({"padding": "x" * 1500}) + "\n")
' "$metrics"

  run python3 "$REPO_ROOT/tools/router-precision.py" \
    --metrics "$metrics" \
    --transcripts "$transcripts" \
    --max-metrics-bytes 1024 \
    --max-records 100 \
    --json

  [ "$status" -eq 0 ]
  ROUTER_PRECISION_JSON="$output" python3 -c '
import json
import os

report = json.loads(os.environ["ROUTER_PRECISION_JSON"])
assert report["prompts"] == 1, report
assert report["skipped"]["metrics_byte_limit"] is True, report
assert report["skipped"]["metrics_record_limit"] is False, report
'
}

@test "router-precision excludes a transcript when a skipped line could contain the matching invocation" {
  local fixture_dir metrics transcripts prompt prompt_hash
  fixture_dir="$(mktemp -d "${BATS_TEST_TMPDIR}/router-precision-skipped-invoke.XXXXXX")"
  metrics="$fixture_dir/metrics.jsonl"
  transcripts="$fixture_dir/transcripts"
  mkdir -p "$transcripts"
  prompt="Diagnose the skipped invocation"
  prompt_hash="$(printf '%s' "$prompt" | _sha256)"

  printf '{"session_id":"skipped-invoke","prompt_sha256":"%s","hints":["systematic-debugging"],"suggested":"systematic-debugging"}\n' "$prompt_hash" > "$metrics"
  python3 -c '
import json
import sys

path, prompt = sys.argv[1:]
with open(path, "w", encoding="utf-8") as handle:
    handle.write(json.dumps({"type": "user", "message": {"content": prompt}}) + "\n")
    handle.write("x" * 400 + "\n")
' "$transcripts/skipped-invoke.jsonl" "$prompt"

  run python3 "$REPO_ROOT/tools/router-precision.py" \
    --metrics "$metrics" \
    --transcripts "$transcripts" \
    --max-line-bytes 256 \
    --json

  [ "$status" -eq 0 ]
  ROUTER_PRECISION_JSON="$output" python3 -c '
import json
import os

report = json.loads(os.environ["ROUTER_PRECISION_JSON"])
assert report["evaluable_suggestions"] == 0, report
assert report["correct_suggestions"] == 0, report
assert report["suggested_not_invoked"] == 0, report
assert report["precision"] is None, report
assert report["skipped"]["transcript_lines"] == 1, report
'
}

@test "router-precision counts only the suggested skill or its known slash aliases as explicit" {
  local fixture_dir metrics transcripts
  fixture_dir="$(mktemp -d "${BATS_TEST_TMPDIR}/router-precision-explicit.XXXXXX")"
  metrics="$fixture_dir/metrics.jsonl"
  transcripts="$fixture_dir/transcripts"
  mkdir -p "$transcripts"

  python3 -c '
import hashlib
import json
import sys

metrics, transcripts = sys.argv[1:]
prompts = {
    "alias": "/sp-debug diagnose the widget",
    "path": "Diagnose /tmp/widget",
    "unrelated": "/status then diagnose the widget",
}
with open(metrics, "w", encoding="utf-8") as metric_handle:
    for session, prompt in prompts.items():
        metric_handle.write(json.dumps({
            "session_id": session,
            "prompt_sha256": hashlib.sha256(prompt.encode()).hexdigest(),
            "hints": ["systematic-debugging"],
            "suggested": "systematic-debugging",
            "explicit_aliases": ["/sp-debug"],
        }) + "\n")
        with open(f"{transcripts}/{session}.jsonl", "w", encoding="utf-8") as transcript:
            transcript.write(json.dumps({"type": "user", "message": {"content": prompt}}) + "\n")
            transcript.write(json.dumps({"type": "assistant", "message": {"content": [{
                "type": "tool_use", "name": "Skill", "input": {"skill": "systematic-debugging"}
            }]}}) + "\n")
' "$metrics" "$transcripts"

  run python3 "$REPO_ROOT/tools/router-precision.py" \
    --metrics "$metrics" \
    --transcripts "$transcripts" \
    --json

  [ "$status" -eq 0 ]
  ROUTER_PRECISION_JSON="$output" python3 -c '
import json
import os

report = json.loads(os.environ["ROUTER_PRECISION_JSON"])
assert report["correct_suggestions"] == 3, report
assert report["matched_invocations"] == {"automatic": 2, "explicit": 1}, report
'
}

@test "router-precision runs under the macOS system Python 3.9 runtime" {
  if [[ ! -x /usr/bin/python3 ]]; then
    skip "/usr/bin/python3 not present"
  fi

  local fixture_dir metrics transcripts prompt prompt_hash
  fixture_dir="$(mktemp -d "${BATS_TEST_TMPDIR}/router-precision-python39.XXXXXX")"
  metrics="$fixture_dir/metrics.jsonl"
  transcripts="$fixture_dir/transcripts"
  mkdir -p "$transcripts"
  prompt="Diagnose with the system Python"
  prompt_hash="$(printf '%s' "$prompt" | _sha256)"
  printf '{"session_id":"python39","prompt_sha256":"%s","hints":["systematic-debugging"],"suggested":"systematic-debugging"}\n' "$prompt_hash" > "$metrics"
  {
    printf '{"type":"user","message":{"content":"%s"}}\n' "$prompt"
    printf '%s\n' '{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Skill","input":{"skill":"systematic-debugging"}}]}}'
  } > "$transcripts/python39.jsonl"

  run /usr/bin/python3 "$REPO_ROOT/tools/router-precision.py" \
    --metrics "$metrics" \
    --transcripts "$transcripts" \
    --json

  [ "$status" -eq 0 ]
  ROUTER_PRECISION_JSON="$output" /usr/bin/python3 -c '
import json
import os

report = json.loads(os.environ["ROUTER_PRECISION_JSON"])
assert report["precision"] == 1.0, report
'
}

@test "router-precision rejects unsafe session identifiers instead of traversing paths" {
  local fixture_dir metrics transcripts outside prompt prompt_hash
  fixture_dir="$(mktemp -d "${BATS_TEST_TMPDIR}/router-precision-path.XXXXXX")"
  metrics="$fixture_dir/metrics.jsonl"
  transcripts="$fixture_dir/transcripts"
  outside="$fixture_dir/outside.jsonl"
  mkdir -p "$transcripts"
  prompt="Do not leave the transcript root"
  prompt_hash="$(printf '%s' "$prompt" | _sha256)"

  printf '{"session_id":"../../outside","prompt_sha256":"%s","hints":["security-privacy"],"suggested":"security-privacy"}\n' "$prompt_hash" > "$metrics"
  {
    printf '{"type":"user","message":{"content":"%s"}}\n' "$prompt"
    printf '%s\n' '{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Skill","input":{"skill":"security-privacy"}}]}}'
  } > "$outside"

  run python3 "$REPO_ROOT/tools/router-precision.py" \
    --metrics "$metrics" \
    --transcripts "$transcripts" \
    --json

  [ "$status" -eq 0 ]
  ROUTER_PRECISION_JSON="$output" python3 -c '
import json
import os

report = json.loads(os.environ["ROUTER_PRECISION_JSON"])
assert report["prompts"] == 1, report
assert report["evaluable_suggestions"] == 0, report
assert report["skipped"]["unsafe_session_ids"] == 1, report
'
}

@test "router-precision does not follow transcript symlinks" {
  local fixture_dir metrics transcripts outside prompt prompt_hash
  fixture_dir="$(mktemp -d "${BATS_TEST_TMPDIR}/router-precision-symlink.XXXXXX")"
  metrics="$fixture_dir/metrics.jsonl"
  transcripts="$fixture_dir/transcripts"
  outside="$fixture_dir/outside.jsonl"
  mkdir -p "$transcripts"
  prompt="Do not follow the transcript link"
  prompt_hash="$(printf '%s' "$prompt" | _sha256)"

  printf '{"session_id":"linked-session","prompt_sha256":"%s","hints":["security-privacy"],"suggested":"security-privacy"}\n' "$prompt_hash" > "$metrics"
  {
    printf '{"type":"user","message":{"content":"%s"}}\n' "$prompt"
    printf '%s\n' '{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Skill","input":{"skill":"security-privacy"}}]}}'
  } > "$outside"
  ln -s "$outside" "$transcripts/linked-session.jsonl"

  run python3 "$REPO_ROOT/tools/router-precision.py" \
    --metrics "$metrics" \
    --transcripts "$transcripts" \
    --json

  [ "$status" -eq 0 ]
  ROUTER_PRECISION_JSON="$output" python3 -c '
import json
import os

report = json.loads(os.environ["ROUTER_PRECISION_JSON"])
assert report["evaluable_suggestions"] == 0, report
assert report["skipped"]["missing_transcripts"] == 1, report
'
}

@test "router-precision human report names every required operator metric" {
  local fixture_dir metrics transcripts
  fixture_dir="$(mktemp -d "${BATS_TEST_TMPDIR}/router-precision-human.XXXXXX")"
  metrics="$fixture_dir/metrics.jsonl"
  transcripts="$fixture_dir/transcripts"
  mkdir -p "$transcripts"
  printf '%s\n' '{"session_id":null,"prompt_sha256":null,"hints":[],"suggested":null}' > "$metrics"

  run python3 "$REPO_ROOT/tools/router-precision.py" \
    --metrics "$metrics" \
    --transcripts "$transcripts"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Hint rate:"* ]]
  [[ "$output" == *"Hints per prompt:"* ]]
  [[ "$output" == *"Precision:"* ]]
  [[ "$output" == *"Automatic matched invocations:"* ]]
  [[ "$output" == *"Explicit matched invocations:"* ]]
  [[ "$output" == *"metrics_byte_limit=False"* ]]
  [[ "$output" == *"metrics_record_limit=False"* ]]
}

@test "router-precision docs inventory routing telemetry and trigger terms" {
  run python3 -c '
import sys

text = open(sys.argv[1], encoding="utf-8").read()
privacy = text.split("## Privacy and retention", 1)[1]
for field in ("ts", "rebuilt", "max_hints"):
    marker = chr(96) + field + chr(96)
    assert marker in privacy, (field, privacy)
assert "published positive trigger phrases" in privacy, privacy
' "$REPO_ROOT/docs/router-precision.md"

  [ "$status" -eq 0 ]
}

@test "router-precision correlates the router's 4096-character prompt digest" {
  local fixture_dir metrics transcripts
  fixture_dir="$(mktemp -d "${BATS_TEST_TMPDIR}/router-precision-truncated.XXXXXX")"
  metrics="$fixture_dir/metrics.jsonl"
  transcripts="$fixture_dir/transcripts"
  mkdir -p "$transcripts"

  python3 -c '
import hashlib
import json
import sys

metrics, transcript = sys.argv[1:]
prompt = "a" * 4096 + " trailing transcript content"
digest = hashlib.sha256(prompt[:4096].encode()).hexdigest()
with open(metrics, "w", encoding="utf-8") as handle:
    handle.write(json.dumps({
        "session_id": "long-session",
        "prompt_sha256": digest,
        "hints": ["long-context-skill"],
        "suggested": "long-context-skill",
    }) + "\n")
with open(transcript, "w", encoding="utf-8") as handle:
    handle.write(json.dumps({"type": "user", "message": {"content": prompt}}) + "\n")
    handle.write(json.dumps({"type": "assistant", "message": {"content": [{
        "type": "tool_use", "name": "Skill", "input": {"skill": "long-context-skill"}
    }]}}) + "\n")
' "$metrics" "$transcripts/long-session.jsonl"

  run python3 "$REPO_ROOT/tools/router-precision.py" \
    --metrics "$metrics" \
    --transcripts "$transcripts" \
    --json

  [ "$status" -eq 0 ]
  ROUTER_PRECISION_JSON="$output" python3 -c '
import json
import os

report = json.loads(os.environ["ROUTER_PRECISION_JSON"])
assert report["evaluable_suggestions"] == 1, report
assert report["precision"] == 1.0, report
'
}

@test "router-precision canonicalizes trailing newlines like the shell hook" {
  local fixture_dir metrics transcripts
  fixture_dir="$(mktemp -d "${BATS_TEST_TMPDIR}/router-precision-newline.XXXXXX")"
  metrics="$fixture_dir/metrics.jsonl"
  transcripts="$fixture_dir/transcripts"
  mkdir -p "$transcripts"

  python3 -c '
import hashlib
import json
import sys

metrics, transcript = sys.argv[1:]
prompt = "Diagnose the pasted failure\n\n"
digest = hashlib.sha256(prompt.rstrip("\n").encode()).hexdigest()
with open(metrics, "w", encoding="utf-8") as handle:
    handle.write(json.dumps({
        "session_id": "newline-session",
        "prompt_sha256": digest,
        "hints": ["systematic-debugging"],
        "suggested": "systematic-debugging",
    }) + "\n")
with open(transcript, "w", encoding="utf-8") as handle:
    handle.write(json.dumps({"type": "user", "message": {"content": prompt}}) + "\n")
    handle.write(json.dumps({"type": "assistant", "message": {"content": [{
        "type": "tool_use", "name": "Skill", "input": {"skill": "systematic-debugging"}
    }]}}) + "\n")
' "$metrics" "$transcripts/newline-session.jsonl"

  run python3 "$REPO_ROOT/tools/router-precision.py" \
    --metrics "$metrics" \
    --transcripts "$transcripts" \
    --json

  [ "$status" -eq 0 ]
  ROUTER_PRECISION_JSON="$output" python3 -c '
import json
import os

report = json.loads(os.environ["ROUTER_PRECISION_JSON"])
assert report["evaluable_suggestions"] == 1, report
assert report["precision"] == 1.0, report
'
}

@test "router-precision ignores system and meta user records between a prompt and invocation" {
  local fixture_dir metrics transcripts prompt prompt_hash
  fixture_dir="$(mktemp -d "${BATS_TEST_TMPDIR}/router-precision-system.XXXXXX")"
  metrics="$fixture_dir/metrics.jsonl"
  transcripts="$fixture_dir/transcripts"
  mkdir -p "$transcripts"
  prompt="Diagnose the widget"
  prompt_hash="$(printf '%s' "$prompt" | _sha256)"

  printf '{"session_id":"system-session","prompt_sha256":"%s","hints":["systematic-debugging"],"suggested":"systematic-debugging"}\n' "$prompt_hash" > "$metrics"
  {
    printf '{"type":"user","promptSource":"typed","message":{"content":"%s"}}\n' "$prompt"
    printf '%s\n' '{"type":"user","promptSource":"system","message":{"content":"scheduled internal event"}}'
    printf '%s\n' '{"type":"user","isMeta":true,"message":{"content":[{"type":"text","text":"metadata"}]}}'
    printf '%s\n' '{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Skill","input":{"skill":"systematic-debugging"}}]}}'
  } > "$transcripts/system-session.jsonl"

  run python3 "$REPO_ROOT/tools/router-precision.py" \
    --metrics "$metrics" \
    --transcripts "$transcripts" \
    --json

  [ "$status" -eq 0 ]
  ROUTER_PRECISION_JSON="$output" python3 -c '
import json
import os

report = json.loads(os.environ["ROUTER_PRECISION_JSON"])
assert report["evaluable_suggestions"] == 1, report
assert report["precision"] == 1.0, report
'
}

@test "router-precision enforces an aggregate transcript byte budget" {
  local fixture_dir metrics transcripts
  fixture_dir="$(mktemp -d "${BATS_TEST_TMPDIR}/router-precision-total.XXXXXX")"
  metrics="$fixture_dir/metrics.jsonl"
  transcripts="$fixture_dir/transcripts"
  mkdir -p "$transcripts"

  python3 -c '
import hashlib
import json
import sys

metrics, transcripts = sys.argv[1:]
with open(metrics, "w", encoding="utf-8") as metric_handle:
    for index in (1, 2):
        prompt = f"Diagnose widget {index}"
        metric_handle.write(json.dumps({
            "session_id": f"budget-{index}",
            "prompt_sha256": hashlib.sha256(prompt.encode()).hexdigest(),
            "hints": ["systematic-debugging"],
            "suggested": "systematic-debugging",
        }) + "\n")
        with open(f"{transcripts}/budget-{index}.jsonl", "w", encoding="utf-8") as transcript:
            transcript.write(json.dumps({"type": "user", "message": {"content": prompt}}) + "\n")
            transcript.write(json.dumps({"type": "assistant", "message": {"content": [{
                "type": "text", "text": "x" * 500
            }]}}) + "\n")
            transcript.write(json.dumps({"type": "assistant", "message": {"content": [{
                "type": "tool_use", "name": "Skill", "input": {"skill": "systematic-debugging"}
            }]}}) + "\n")
' "$metrics" "$transcripts"

  run python3 "$REPO_ROOT/tools/router-precision.py" \
    --metrics "$metrics" \
    --transcripts "$transcripts" \
    --max-total-transcript-bytes 1024 \
    --json

  [ "$status" -eq 0 ]
  ROUTER_PRECISION_JSON="$output" python3 -c '
import json
import os

report = json.loads(os.environ["ROUTER_PRECISION_JSON"])
assert report["evaluable_suggestions"] == 1, report
assert report["precision"] == 1.0, report
assert report["skipped"]["transcript_total_byte_limit"] is True, report
'
}

@test "router-precision excludes an oversized transcript from precision" {
  local fixture_dir metrics transcripts prompt prompt_hash
  fixture_dir="$(mktemp -d "${BATS_TEST_TMPDIR}/router-precision-oversized.XXXXXX")"
  metrics="$fixture_dir/metrics.jsonl"
  transcripts="$fixture_dir/transcripts"
  mkdir -p "$transcripts"
  prompt="Diagnose the oversized transcript"
  prompt_hash="$(printf '%s' "$prompt" | _sha256)"

  printf '{"session_id":"oversized-session","prompt_sha256":"%s","hints":["systematic-debugging"],"suggested":"systematic-debugging"}\n' "$prompt_hash" > "$metrics"
  python3 -c '
import json
import sys

path, prompt = sys.argv[1:]
with open(path, "w", encoding="utf-8") as handle:
    handle.write(json.dumps({"type": "user", "message": {"content": prompt}}) + "\n")
    handle.write(json.dumps({"type": "assistant", "message": {"content": [{
        "type": "text", "text": "x" * 1200
    }]}}) + "\n")
    handle.write(json.dumps({"type": "assistant", "message": {"content": [{
        "type": "tool_use", "name": "Skill", "input": {"skill": "systematic-debugging"}
    }]}}) + "\n")
' "$transcripts/oversized-session.jsonl" "$prompt"

  run python3 "$REPO_ROOT/tools/router-precision.py" \
    --metrics "$metrics" \
    --transcripts "$transcripts" \
    --max-transcript-bytes 1024 \
    --json

  [ "$status" -eq 0 ]
  ROUTER_PRECISION_JSON="$output" python3 -c '
import json
import os

report = json.loads(os.environ["ROUTER_PRECISION_JSON"])
assert report["evaluable_suggestions"] == 0, report
assert report["precision"] is None, report
assert report["skipped"]["transcript_byte_limits"] == 1, report
'
}

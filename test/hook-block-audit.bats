#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd -P)"
  TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/hook-block-audit.XXXXXX")"
  TEST_HOME="$TEST_ROOT/home"
  mkdir -p "$TEST_HOME/.claude/hooks"
}

teardown() {
  rm -rf "$TEST_ROOT"
}

run_report_with_timeout() {
  python3 - "$REPO_ROOT/tools/hook-block-report.py" "$@" <<'PY'
import subprocess
import sys

report, *args = sys.argv[1:]
try:
    completed = subprocess.run(
        [sys.executable, report, *args],
        capture_output=True,
        text=True,
        timeout=2,
    )
except subprocess.TimeoutExpired:
    print("REPORT TIMED OUT", file=sys.stderr)
    raise SystemExit(124)

sys.stdout.write(completed.stdout)
sys.stderr.write(completed.stderr)
raise SystemExit(completed.returncode)
PY
}

make_repo() {
  TEST_REPO="$TEST_ROOT/repo"
  git -C "$TEST_ROOT" init -q repo
  git -C "$TEST_REPO" config user.email "wrong@example.com"
  git -C "$TEST_REPO" config user.name "Test User"
  git -C "$TEST_REPO" commit -q --allow-empty -m "contains private-block-marker"
  git -C "$TEST_REPO" remote add origin "https://github.com/example/repo.git"
}

write_identity_rules() {
  cat > "$TEST_REPO/AGENTS.md" <<'EOF'
# Test identity

| Context | Email | Git User |
|---------|-------|----------|
| github.com/* | expected@example.com | Test User |
EOF
}

@test "red-autonomy block logs fired class and sanitized session id without command text" {
  local transcript payload log
  transcript="$TEST_ROOT/transcript.jsonl"
  printf '%s\n' '{"role":"user","content":"please inspect this"}' > "$transcript"
  payload="$(jq -cn \
    --arg transcript "$transcript" \
    '{tool_name:"Bash",tool_input:{command:"git push origin private-branch-name"},transcript_path:$transcript,session_id:"red/session!42",cwd:"/tmp"}')"

  HOME="$TEST_HOME" \
    CLAUDE_HOOKS_PATTERNS_FILE_OVERRIDE="$REPO_ROOT/claude-config/red-autonomy-patterns.txt" \
    run bash "$REPO_ROOT/tools/claude-hooks/pre-tool-use-red-autonomy.sh" <<<"$payload"

  [ "$status" -eq 2 ]
  log="$(cat "$TEST_HOME/.claude/hooks/hook-audit.log")"
  [[ "$log" == *"red-autonomy exit=2 reason=no-approval class=fired sid=redsession42"* ]]
  [[ "$log" != *"private-branch-name"* ]]
}

@test "internal-terms block logs fired class and session id without matched content" {
  local patterns payload log
  make_repo
  patterns="$TEST_ROOT/patterns.txt"
  printf '%s\n' 'private-block-marker' > "$patterns"
  payload="$(jq -cn \
    --arg cwd "$TEST_REPO" \
    '{tool_name:"Bash",tool_input:{command:"git push origin main"},session_id:"terms-session",cwd:$cwd}')"

  HOME="$TEST_HOME" CLAUDE_HOOKS_PATTERNS_FILE_OVERRIDE="$patterns" \
    run bash "$REPO_ROOT/tools/claude-hooks/pre-tool-use-internal-terms.sh" <<<"$payload"

  [ "$status" -eq 2 ]
  log="$(cat "$TEST_HOME/.claude/hooks/hook-audit.log")"
  [[ "$log" == *"internal-terms exit=2 reason=hits-found class=fired sid=terms-session"* ]]
  [[ "$log" != *"private-block-marker"* ]]
}

@test "git-identity block logs fired class and session id without identity values" {
  local payload log
  make_repo
  write_identity_rules
  payload="$(jq -cn \
    --arg cwd "$TEST_REPO" \
    '{tool_name:"Bash",tool_input:{command:"git commit -m private-message"},session_id:"identity-session",cwd:$cwd}')"

  HOME="$TEST_HOME" \
    run bash "$REPO_ROOT/tools/claude-hooks/pre-tool-use-git-identity.sh" <<<"$payload"

  [ "$status" -eq 2 ]
  log="$(cat "$TEST_HOME/.claude/hooks/hook-audit.log")"
  [[ "$log" == *"git-identity exit=2 reason=mismatch class=fired sid=identity-session"* ]]
  [[ "$log" != *"private-message"* ]]
  [[ "$log" != *"wrong@example.com"* ]]
  [[ "$log" != *"expected@example.com"* ]]
}

@test "malformed hook input logs metadata keys only and preserves existing exit policy" {
  local payload hook expected_status log
  payload='{"tool_name":"Bash","tool_input":"private-command-value","session_id":"sid-1","private_key":"private-value"}'

  while IFS=: read -r hook expected_status; do
    rm -f "$TEST_HOME/.claude/hooks/hook-audit.log"
    HOME="$TEST_HOME" \
      run bash "$REPO_ROOT/tools/claude-hooks/$hook" <<<"$payload"

    [ "$status" -eq "$expected_status" ]
    log="$(cat "$TEST_HOME/.claude/hooks/hook-audit.log")"
    [[ "$log" == *"reason=malformed-input class=unknown sid=sid-1 tool=Bash input_keys=session_id,tool_input,tool_name unknown_keys=1"* ]]
    [[ "$log" != *"private_key"* ]]
    [[ "$log" != *"private-command-value"* ]]
    [[ "$log" != *"private-value"* ]]
  done <<'EOF'
pre-tool-use-red-autonomy.sh:2
pre-tool-use-internal-terms.sh:5
pre-tool-use-git-identity.sh:5
EOF
}

@test "hook block report counts real malformed hook exits end to end" {
  local payload audit expected
  payload='{"tool_name":"Bash","tool_input":"private-command-value","session_id":"sid-1","private_key":"private-value"}'
  audit="$TEST_HOME/.claude/hooks/hook-audit.log"

  HOME="$TEST_HOME" run bash "$REPO_ROOT/tools/claude-hooks/pre-tool-use-red-autonomy.sh" <<<"$payload"
  [ "$status" -eq 2 ]
  HOME="$TEST_HOME" run bash "$REPO_ROOT/tools/claude-hooks/pre-tool-use-internal-terms.sh" <<<"$payload"
  [ "$status" -eq 5 ]
  HOME="$TEST_HOME" run bash "$REPO_ROOT/tools/claude-hooks/pre-tool-use-git-identity.sh" <<<"$payload"
  [ "$status" -eq 5 ]

  expected=$'hook\texit\tfired_unadjudicated\tunknown\nred-autonomy\t2\t0\t1\ninternal-terms\t2\t0\t0\ninternal-terms\t5\t0\t1\ngit-identity\t2\t0\t0\ngit-identity\t5\t0\t1\nTOTAL\t-\t0\t3\nexcluded_lines\t0\nfiles_read\t1\ntruncated\tno'

  run python3 "$REPO_ROOT/tools/hook-block-report.py" --log "$audit"

  [ "$status" -eq 0 ]
  [ "$output" = "$expected" ]
}

@test "hook block report produces stable aggregate classifications from adversarial input" {
  local audit expected
  audit="$TEST_ROOT/hook-audit.log"
  cat > "$audit" <<'EOF'
2026-09-17T10:00:00Z red-autonomy exit=2 reason=no-approval class=TP sid=s-red
2026-09-17T10:00:01Z internal-terms exit=2 reason=hits-found class=FP sid=s-terms
2026-09-17T10:00:01Z internal-terms exit=2 reason=hits-found class=fired sid=s-current
2026-09-17T10:00:02Z git-identity exit=2 reason=mismatch
2026-09-17T10:00:03Z red-autonomy exit=0 reason=approved class=TP sid=s-red
2026-09-17T10:00:04Z red-autonomy exit=2 reason=no-approval class=TP class=FP sid=duplicate
2026-09-17T10:00:05Z made-up-hook exit=2 reason=no-approval class=TP sid=evil
forged prefix 2026-09-17T10:00:06Z red-autonomy exit=2 reason=no-approval class=TP sid=evil
2026-09-17T10:00:07Z red-autonomy exit=2 reason=no-approval class=INVALID sid=evil
2026-09-17T10:00:08Z internal-terms exit=5 reason=malformed-input class=unknown sid=s-malformed tool=Bash input_keys=session_id,tool_input,tool_name unknown_keys=1
2026-09-17T10:00:09Z internal-terms exit=5 reason=not-push class=unknown sid=s-invalid
2026-09-17T10:00:10Z internal-terms exit=5 reason=malformed-input sid=s-legacy
EOF
  expected=$'hook\texit\tfired_unadjudicated\tunknown\nred-autonomy\t2\t1\t0\ninternal-terms\t2\t2\t0\ninternal-terms\t5\t0\t1\ngit-identity\t2\t0\t1\nTOTAL\t-\t3\t2\nexcluded_lines\t7\nfiles_read\t1\ntruncated\tno'

  run python3 "$REPO_ROOT/tools/hook-block-report.py" --log "$audit"

  [ "$status" -eq 0 ]
  [ "$output" = "$expected" ]
}

@test "hook block report detail mode prints only whitelisted local metadata" {
  local audit
  audit="$TEST_ROOT/hook-audit.log"
  cat > "$audit" <<'EOF'
2026-09-17T10:00:00Z red-autonomy exit=2 reason=malformed-input class=unknown sid=s-red tool=Bash input_keys=cwd,tool_input,tool_name unknown_keys=0
2026-09-17T10:00:01Z red-autonomy exit=2 reason=no-approval class=TP sid=s-secret command=do-not-print-this
2026-09-17T10:00:02Z red-autonomy exit=2 reason=malformed-input class=unknown sid=s-leak tool=Bash input_keys=private_key unknown_keys=0
EOF

  run python3 "$REPO_ROOT/tools/hook-block-report.py" --log "$audit" --details

  [ "$status" -eq 0 ]
  [[ "$output" == *"LOCAL ONLY - DO NOT COMMIT DETAIL OUTPUT"* ]]
  [[ "$output" == *$'2026-09-17T10:00:00Z\tred-autonomy\t2\tunknown\ts-red\tmalformed-input\tBash\tcwd,tool_input,tool_name\t0'* ]]
  [[ "$output" != *"do-not-print-this"* ]]
  [[ "$output" != *"command="* ]]
  [[ "$output" != *"private_key"* ]]
}

@test "hook block report reads only the requested tail of a large log" {
  local audit
  audit="$TEST_ROOT/hook-audit.log"
  {
    printf '%s\n' '2026-09-17T10:00:00Z red-autonomy exit=2 reason=no-approval class=TP sid=outside-window'
    printf '%0800d\n' 0
    printf '%s\n' '2026-09-17T10:00:01Z internal-terms exit=2 reason=hits-found class=FP sid=inside-window'
  } > "$audit"

  run python3 "$REPO_ROOT/tools/hook-block-report.py" --log "$audit" --max-bytes 256

  [ "$status" -eq 0 ]
  [[ "$output" == *$'red-autonomy\t2\t0\t0'* ]]
  [[ "$output" == *$'internal-terms\t2\t1\t0'* ]]
  [[ "$output" == *$'TOTAL\t-\t1\t0'* ]]
  [[ "$output" == *$'truncated\tyes'* ]]
}

@test "hook block report retains a complete record at the tail boundary" {
  local audit first second tail_bytes
  audit="$TEST_ROOT/hook-audit.log"
  first='2026-09-17T10:00:00Z red-autonomy exit=2 reason=no-approval class=TP sid=at-boundary'
  second='2026-09-17T10:00:01Z git-identity exit=2 reason=mismatch class=TP sid=last-record'
  {
    printf '%s\n' 'outside-window'
    printf '%s\n' "$first"
    printf '%s\n' "$second"
  } > "$audit"
  tail_bytes="$(printf '%s\n%s\n' "$first" "$second" | wc -c | tr -d ' ')"

  run python3 "$REPO_ROOT/tools/hook-block-report.py" --log "$audit" --max-bytes "$tail_bytes"

  [ "$status" -eq 0 ]
  [[ "$output" == *$'red-autonomy\t2\t1\t0'* ]]
  [[ "$output" == *$'git-identity\t2\t1\t0'* ]]
  [[ "$output" == *$'TOTAL\t-\t2\t0'* ]]
  [[ "$output" == *$'truncated\tyes'* ]]
}

@test "hook block report rejects an unbounded read request" {
  local audit
  audit="$TEST_ROOT/hook-audit.log"
  : > "$audit"

  run python3 "$REPO_ROOT/tools/hook-block-report.py" --log "$audit" --max-bytes 16777217

  [ "$status" -eq 2 ]
  [[ "$output" == *"max-bytes must be between 1 and 16777216"* ]]
}

@test "hook block report rejects a FIFO without blocking" {
  local fifo
  fifo="$TEST_ROOT/hook-audit.fifo"
  mkfifo "$fifo"

  run run_report_with_timeout --log "$fifo"

  [ "$status" -eq 1 ]
  [[ "$output" == *"audit log must be a regular file"* ]]
  [[ "$output" != *"REPORT TIMED OUT"* ]]
}

@test "hook block report refuses symlink logs without reading their target" {
  local target link
  target="$TEST_ROOT/private-target.log"
  link="$TEST_ROOT/hook-audit.log"
  printf '%s\n' '2026-09-17T10:00:00Z red-autonomy exit=2 reason=no-approval class=TP sid=must-not-read' > "$target"
  ln -s "$target" "$link"

  run run_report_with_timeout --log "$link" --details

  [ "$status" -eq 1 ]
  [[ "$output" == *"audit log must not be a symlink"* ]]
  [[ "$output" != *"must-not-read"* ]]
  [[ "$output" != *"REPORT TIMED OUT"* ]]
}

@test "hook block report reads rotated generations oldest to newest" {
  local audit
  audit="$TEST_ROOT/hook-audit.log"
  printf '%s\n' '2026-09-17T10:00:00Z red-autonomy exit=2 reason=no-approval class=TP sid=oldest' > "$audit.2"
  printf '%s\n' '2026-09-17T10:00:01Z internal-terms exit=2 reason=hits-found class=FP sid=middle' > "$audit.1"
  printf '%s\n' '2026-09-17T10:00:02Z git-identity exit=2 reason=mismatch class=fired sid=newest' > "$audit"

  run python3 "$REPO_ROOT/tools/hook-block-report.py" --log "$audit" --max-bytes 4096 --details

  [ "$status" -eq 0 ]
  [[ "$output" == *$'TOTAL\t-\t3\t0'* ]]
  [[ "$output" == *$'files_read\t3'* ]]
  [[ "$output" == *$'truncated\tno'* ]]
  [[ "$output" == *$'2026-09-17T10:00:00Z\tred-autonomy'* ]]
  [[ "$output" == *$'2026-09-17T10:00:02Z\tgit-identity'* ]]
  [[ "$output" == *$'2026-09-17T10:00:00Z\tred-autonomy'*$'\n'*$'2026-09-17T10:00:01Z\tinternal-terms'*$'\n'*$'2026-09-17T10:00:02Z\tgit-identity'* ]]
  [[ "$output" != *$'\tTP\t'* ]]
  [[ "$output" != *$'\tFP\t'* ]]
}

@test "hook block report applies one byte ceiling across all generations" {
  local audit newest_bytes
  audit="$TEST_ROOT/hook-audit.log"
  printf '%s\n' '2026-09-17T10:00:00Z red-autonomy exit=2 reason=no-approval class=fired sid=oldest' > "$audit.2"
  printf '%s\n' '2026-09-17T10:00:01Z internal-terms exit=2 reason=hits-found class=fired sid=middle' > "$audit.1"
  printf '%s\n' '2026-09-17T10:00:02Z git-identity exit=2 reason=mismatch class=fired sid=newest' > "$audit"
  newest_bytes="$(wc -c < "$audit" | tr -d ' ')"

  run python3 "$REPO_ROOT/tools/hook-block-report.py" --log "$audit" --max-bytes "$newest_bytes"

  [ "$status" -eq 0 ]
  [[ "$output" == *$'TOTAL\t-\t1\t0'* ]]
  [[ "$output" == *$'files_read\t1'* ]]
  [[ "$output" == *$'truncated\tyes'* ]]
}

@test "hook block report refuses a symlinked rotated generation" {
  local audit target
  audit="$TEST_ROOT/hook-audit.log"
  target="$TEST_ROOT/private-generation.log"
  printf '%s\n' '2026-09-17T10:00:00Z red-autonomy exit=2 reason=no-approval class=fired sid=must-not-read' > "$target"
  ln -s "$target" "$audit.1"
  printf '%s\n' '2026-09-17T10:00:01Z git-identity exit=2 reason=mismatch class=fired sid=live' > "$audit"

  run run_report_with_timeout --log "$audit" --max-bytes 4096 --details

  [ "$status" -eq 1 ]
  [[ "$output" == *"audit log must not be a symlink"* ]]
  [[ "$output" != *"must-not-read"* ]]
  [[ "$output" != *"REPORT TIMED OUT"* ]]
}

@test "hook block report rejects a rotated FIFO without blocking" {
  local audit
  audit="$TEST_ROOT/hook-audit.log"
  mkfifo "$audit.2"
  printf '%s\n' '2026-09-17T10:00:01Z git-identity exit=2 reason=mismatch class=fired sid=live' > "$audit"

  run run_report_with_timeout --log "$audit" --max-bytes 4096

  [ "$status" -eq 1 ]
  [[ "$output" == *"audit log must be a regular file"* ]]
  [[ "$output" != *"REPORT TIMED OUT"* ]]
}

@test "hook block report rejects a generation set that changes during the read" {
  local audit
  audit="$TEST_ROOT/hook-audit.log"
  printf '%s\n' '2026-09-17T10:00:01Z git-identity exit=2 reason=mismatch class=fired sid=live' > "$audit"

  run python3 - "$REPO_ROOT/tools/hook-block-report.py" "$audit" <<'PY'
import importlib.util
import pathlib
import sys

spec = importlib.util.spec_from_file_location("hook_block_report", sys.argv[1])
module = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = module
spec.loader.exec_module(module)
audit = pathlib.Path(sys.argv[2])
original_open = module.open_audit_log
mutated = False

def mutating_open(path):
    global mutated
    stream = original_open(path)
    if path == audit and not mutated:
        with path.open("ab") as target:
            target.write(b"concurrent append\n")
        mutated = True
    return stream

module.open_audit_log = mutating_open
try:
    module.read_retained_tail(audit, 4096)
except ValueError as exc:
    print(exc)
    raise SystemExit(0)
raise SystemExit(1)
PY

  [ "$status" -eq 0 ]
  [[ "$output" == *"changed during read"* ]]
  [[ "$output" == *"retry"* ]]
}

@test "hook block report rejects the exact generation rename race" {
  local audit
  audit="$TEST_ROOT/hook-audit.log"
  printf '%s\n' '2026-09-17T10:00:00Z red-autonomy exit=2 reason=no-approval class=fired sid=older' > "$audit.1"
  printf '%s\n' '2026-09-17T10:00:01Z git-identity exit=2 reason=mismatch class=fired sid=old-live' > "$audit"

  run python3 - "$REPO_ROOT/tools/hook-block-report.py" "$audit" <<'PY'
import importlib.util
import pathlib
import sys

spec = importlib.util.spec_from_file_location("hook_block_report", sys.argv[1])
module = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = module
spec.loader.exec_module(module)
audit = pathlib.Path(sys.argv[2])
original_open = module.open_audit_log
rotated = False

def rotating_open(path):
    global rotated
    stream = original_open(path)
    if path == audit and not rotated:
        pathlib.Path(f"{audit}.1").replace(pathlib.Path(f"{audit}.2"))
        audit.replace(pathlib.Path(f"{audit}.1"))
        audit.write_text(
            "2026-09-17T10:00:02Z internal-terms exit=2 "
            "reason=hits-found class=fired sid=new-live\n",
            encoding="utf-8",
        )
        rotated = True
    return stream

module.open_audit_log = rotating_open
try:
    module.read_retained_tail(audit, 4096)
except ValueError as exc:
    print(exc)
    raise SystemExit(0)
raise SystemExit(1)
PY

  [ "$status" -eq 0 ]
  [[ "$output" == *"changed during read"* ]]
  [[ "$output" == *"retry"* ]]
}

#!/usr/bin/env bash
# skill-trigger-audit battery runner.
#
# Runs a battery of prompts through the real, installed skill-router hook
# and classifies each PASS/FAIL/SKIPPED, persisting results progressively.
#
# Usage: bash battery-runner.sh <hook_path> <target_skill> <battery_json_file>
#
# Must run as a single script invocation -- not a series of separate
# per-prompt tool calls. CLAUDE_SKILL_ROUTER_METRICS/CACHE overrides below
# must persist across every hook invocation in the run; environment state
# does not carry across separate shell invocations in this ecosystem's own
# execution environment, only the working directory does. A per-prompt-call
# implementation would silently revert every invocation after the first to
# the hook's real production paths.
#
# All untrusted/variable data (CLI args, file contents, derived paths) is
# passed to every embedded python3 call via sys.argv, never interpolated
# into the Python source string -- interpolating a value containing a
# single quote into a `python3 -c "...'$VAR'..."` string is arbitrary code
# execution, not a formatting bug.
set -uo pipefail

if ! command -v python3 >/dev/null 2>&1; then
  echo "ERROR: python3 not found on PATH -- required for JSON handling" >&2
  exit 1
fi

if [ "$#" -lt 3 ]; then
  echo "ERROR: usage: battery-runner.sh <hook_path> <target_skill> <battery_json_file>" >&2
  exit 1
fi

HOOK_PATH="$1"
TARGET_SKILL="$2"
BATTERY_FILE="$3"

RUN_DIR=".trigger-audit-runs"
mkdir -p "$RUN_DIR"

RUN_ID=$(python3 -c "import uuid; print(uuid.uuid4().hex[:8])")
if [ -z "$RUN_ID" ]; then
  echo "ERROR: failed to generate a run ID" >&2
  exit 1
fi
RESULTS_STREAM="$RUN_DIR/${RUN_ID}.results.jsonl"
SUMMARY_FILE="$RUN_DIR/${RUN_ID}.json"

# HOOK_PATH must be a genuine regular file, never a special/device path
# (/dev/stdin, /dev/fd/0, a named pipe, etc). Without this check, a
# HOOK_PATH aliasing this script's own redirected stdin would make
# `bash "$HOOK_PATH" < "$payload_file"` read its SCRIPT from the same
# stream as the per-prompt payload content being fed to it -- an
# attacker-controlled JSON prompt could then be interpreted as shell
# script instead of inert data. `-f` rejects device/pipe/socket special
# files; only a real regular file passes. The check and the snapshot copy
# below are deliberately adjacent, with RUN_DIR/RUN_ID already established
# above -- no intervening work widens the check-then-copy window.
if [ ! -f "$HOOK_PATH" ] || [ ! -r "$HOOK_PATH" ]; then
  echo "ERROR: hook path is not a readable regular file: $HOOK_PATH" >&2
  exit 1
fi
# Snapshot HOOK_PATH to a private scratch copy this script exclusively owns,
# for the same reason the battery file is snapshotted below: the check above
# is a one-time stat, but the hook is invoked live from the caller-supplied
# path on every single prompt (up to N times per run) with no
# re-validation -- a concurrent edit to the hook file mid-run (plausible: a
# developer iterating on the very hook this harness audits, in a sibling
# session, on a shared checkout) would let different prompts in the same
# run silently score against different hook code, with no detection in the
# summary. Snapshot once here; every invocation below uses the private copy,
# never $HOOK_PATH again. (Assumes the hook has no BASH_SOURCE-relative
# sourcing of sibling files -- confirmed absent in the real installed hook
# at review time; a hook generation that added such sourcing would need a
# different fix here.)
HOOK_SNAPSHOT=$(mktemp "$RUN_DIR/${RUN_ID}.hook-snapshot.XXXXXX") || { echo "ERROR: mktemp failed for hook snapshot" >&2; exit 1; }
if ! cp "$HOOK_PATH" "$HOOK_SNAPSHOT"; then
  echo "ERROR: failed to snapshot hook path: $HOOK_PATH" >&2
  rm -f "$HOOK_SNAPSHOT"
  exit 1
fi

if [ -z "$TARGET_SKILL" ]; then
  echo "ERROR: target skill name (arg 2) is empty" >&2
  rm -f "$HOOK_SNAPSHOT"
  exit 1
fi
if [ ! -f "$BATTERY_FILE" ] || [ ! -r "$BATTERY_FILE" ]; then
  echo "ERROR: battery file is not a readable regular file: $BATTERY_FILE" >&2
  rm -f "$HOOK_SNAPSHOT"
  exit 1
fi

# Validate the battery file is well-formed JSON with at least one of the
# three expected class arrays, and that each present key's value is a list
# of strings -- BEFORE running anything. Without this, a corrupted or
# truncated battery/fixture file (this org routinely runs parallel AI
# sessions against shared checkouts, so a torn concurrent write is a real,
# not hypothetical, risk) crashes the per-prompt loop's json.load() silently,
# or (a string/null value under a present key) gets iterated
# character-by-character as bogus prompts.
#
# The validated data is immediately snapshotted to a private scratch file
# this script exclusively owns (VALIDATED_BATTERY below); every later read
# uses that snapshot, never $BATTERY_FILE again. Re-opening the original
# path a second time for prompt generation -- after validating it once --
# is a TOCTOU: a concurrent write between the two reads could swap in
# content the validation step never saw, defeating this check entirely.
# One open, one validate, one snapshot -- no second read of shared state.
VALIDATED_BATTERY=$(mktemp "$RUN_DIR/${RUN_ID}.battery-validated.XXXXXX") || { echo "ERROR: mktemp failed for validated battery snapshot" >&2; rm -f "$HOOK_SNAPSHOT"; exit 1; }
if ! python3 -c "
import json, sys
try:
    data = json.load(open(sys.argv[1]))
except (json.JSONDecodeError, OSError) as e:
    print(f'battery file is not valid JSON: {e}', file=sys.stderr)
    sys.exit(1)
if not isinstance(data, dict) or not any(k in data for k in ('positive', 'negative', 'adversarial')):
    print('battery file has none of the expected positive/negative/adversarial keys', file=sys.stderr)
    sys.exit(1)
for k in ('positive', 'negative', 'adversarial'):
    if k in data and (not isinstance(data[k], list) or not all(isinstance(p, str) for p in data[k])):
        print(f'battery file key {k!r} must be a list of strings', file=sys.stderr)
        sys.exit(1)
try:
    with open(sys.argv[2], 'w') as out:
        json.dump(data, out)
except OSError as e:
    print(f'failed to write validated battery snapshot: {e}', file=sys.stderr)
    sys.exit(1)
" "$BATTERY_FILE" "$VALIDATED_BATTERY"; then
  echo "ERROR: battery file failed validation: $BATTERY_FILE -- this is a corrupt-input stop, not a legitimately-empty battery" >&2
  rm -f "$VALIDATED_BATTERY" "$HOOK_SNAPSHOT"
  exit 1
fi

# -- Scratch-path isolation, set ONCE for the whole run (single-script constraint) --
# No suffix after the XXXXXX template component: BSD mktemp (stock macOS)
# does not randomize the X's when literal text follows them, unlike GNU
# mktemp's --suffix. Nothing downstream globs on file extension.
#
# Each failure branch below cleans up everything created so far in this
# setup section, not just its own resource -- an earlier round left this
# implicit and a later mktemp failure (this one) leaked HOOK_SNAPSHOT,
# VALIDATED_BATTERY, and the results stream every time.
METRICS_SCRATCH=$(mktemp "$RUN_DIR/${RUN_ID}.hook-metrics-scratch.XXXXXX") || { echo "ERROR: mktemp failed for metrics scratch file" >&2; rm -f "$VALIDATED_BATTERY" "$HOOK_SNAPSHOT"; exit 1; }
CACHE_SCRATCH=$(mktemp -d "$RUN_DIR/${RUN_ID}.cache-scratch.XXXXXX") || { echo "ERROR: mktemp -d failed for cache scratch dir" >&2; rm -f "$METRICS_SCRATCH" "$VALIDATED_BATTERY" "$HOOK_SNAPSHOT"; exit 1; }
export CLAUDE_SKILL_ROUTER_METRICS="$METRICS_SCRATCH"
export CLAUDE_SKILL_ROUTER_CACHE="$CACHE_SCRATCH/cache.json"

# Only now, after every scratch resource above succeeds, create the durable
# results stream -- it is the last thing created in this setup section, so
# no later failure in this section can orphan it. `set -o noclobber` makes
# the creation itself fail loudly (rather than silently succeed, or silently
# follow a pre-planted symlink) if anything already exists at this path --
# RUN_ID is fresh per run, but becomes observable to a same-user watcher of
# RUN_DIR as soon as HOOK_SNAPSHOT's filename appears above, so treat the
# eventual results-stream path as a race target, not a guaranteed-fresh name.
if ! (umask 077; set -o noclobber; : > "$RESULTS_STREAM") 2>/dev/null; then
  echo "ERROR: failed to create results stream (already exists or not writable): $RESULTS_STREAM" >&2
  rm -rf "$CACHE_SCRATCH"
  rm -f "$METRICS_SCRATCH" "$VALIDATED_BATTERY" "$HOOK_SNAPSHOT"
  exit 1
fi
# umask 077 inside the same subshell as the noclobber create gives the file
# 0600 atomically at creation -- no separate chmod-by-path afterward, which
# would otherwise leave its own (low-severity, but needless) TOCTOU window
# between create and chmod.

# Hold a single write file descriptor open for the rest of the run instead
# of reopening $RESULTS_STREAM by path on every append below. `noclobber`
# above only protects the one-time creation; every subsequent path-based
# `>>` append (and the final summary's path-based read) would otherwise
# silently follow a symlink planted at this path AFTER creation -- a much
# wider window (the whole per-prompt loop) than the create-time race
# noclobber closes. Once fd 3 is open, writes go to the original inode
# regardless of what the path later resolves to.
exec 3>>"$RESULTS_STREAM" || {
  echo "ERROR: failed to open results stream for writing: $RESULTS_STREAM" >&2
  rm -rf "$CACHE_SCRATCH"
  rm -f "$METRICS_SCRATCH" "$VALIDATED_BATTERY" "$HOOK_SNAPSHOT" "$RESULTS_STREAM"
  exit 1
}

# -- Kill-tier detection, once. Mirrors Step 0's own multi-path hook-detection convention. --
# Probes that the binary actually supports --kill-after, not just that a
# binary named "timeout"/"gtimeout" exists on PATH: a BusyBox "timeout"
# applet (e.g. on an Alpine/musl runner) has no --kill-after flag and would
# otherwise fail at first real use instead of falling through to native.
KILL_TIER="none"
if command -v timeout >/dev/null 2>&1 && timeout --kill-after=1 1 true >/dev/null 2>&1; then
  KILL_TIER="timeout"
elif command -v gtimeout >/dev/null 2>&1 && gtimeout --kill-after=1 1 true >/dev/null 2>&1; then
  KILL_TIER="gtimeout"
else
  KILL_TIER="native"
fi

TIMEOUT_SECS="${SKILL_TRIGGER_AUDIT_TIMEOUT:-10}"
GRACE_SECS="${SKILL_TRIGGER_AUDIT_GRACE:-3}"

# Extracts the exact skill name from each "[skill-router] Likely match:
# <name> — <description>" line in the hook's stdout and checks whether
# $TARGET_SKILL appears as one of those names EXACTLY -- never a substring
# match, since this corpus has genuine name-nesting collisions
# (core-boards / core-boards-reader, X / sp-X alias pairs, etc.) that a
# bare `grep -q` would misclassify. stdout and target name are both passed
# via sys.argv, never interpolated into the Python source.
target_present_in_hints() {
  local stdout_text="$1" target="$2"
  python3 -c "
import json, re, sys
stdout_text, target = sys.argv[1], sys.argv[2]
names = re.findall(r'^\[skill-router\] Likely match: (\S+)', stdout_text, re.MULTILINE)
print(json.dumps({'present': target in names, 'hints': names}))
" "$stdout_text" "$target"
}

# Runs one prompt through the hook and writes a JSON object describing the
# outcome to $1 (a caller-supplied output file) -- never printed as a
# pipe-delimited string, since the hook's own stdout (and, more remotely,
# a prompt) can legitimately contain a literal "|" (confirmed: several
# real installed skills' descriptions already do), which would silently
# truncate a naive `IFS='|'` split downstream.
run_one_prompt() {
  local out_file="$1" prompt="$2" class="$3"
  local payload_file
  payload_file=$(mktemp "$RUN_DIR/${RUN_ID}.payload.XXXXXX") || { echo "ERROR: mktemp failed for payload file" >&2; return 1; }
  if ! python3 -c "
import json, sys
prompt = sys.argv[1]
print(json.dumps({'hook_event_name': 'UserPromptSubmit', 'prompt': prompt, 'cwd': '.'}))
" "$prompt" > "$payload_file"; then
    echo "ERROR: failed to write hook payload" >&2
    rm -f "$payload_file"
    return 1
  fi

  local lines_before lines_after status="" stdout_out="" timed_out=0 exit_code=0
  lines_before=$(wc -l < "$METRICS_SCRATCH" 2>/dev/null || echo 0)

  case "$KILL_TIER" in
    timeout)
      # Invoke via input redirection, never a pipe: a piped invocation's $!
      # captures the last pipeline command, not the first, silently breaking
      # any process-group derivation downstream. `bash --` (all three tiers
      # below) stops option parsing before the path: a hook path beginning
      # with `-` would otherwise be parsed as bash options, silently failing
      # (stderr is redirected to /dev/null) while the script still reports a
      # confident-but-wrong "hook lacks the metrics mechanism" diagnosis.
      stdout_out=$(timeout --kill-after="${GRACE_SECS}" "${TIMEOUT_SECS}" bash -- "$HOOK_SNAPSHOT" < "$payload_file" 2>/dev/null)
      exit_code=$?
      # GNU timeout: 124 = killed after TIMEOUT_SECS, 137 = killed by
      # --kill-after's SIGKILL escalation. Both mean the hook actually hung.
      if [ "$exit_code" -eq 124 ] || [ "$exit_code" -eq 137 ]; then timed_out=1; fi
      ;;
    gtimeout)
      stdout_out=$(gtimeout --kill-after="${GRACE_SECS}" "${TIMEOUT_SECS}" bash -- "$HOOK_SNAPSHOT" < "$payload_file" 2>/dev/null)
      exit_code=$?
      if [ "$exit_code" -eq 124 ] || [ "$exit_code" -eq 137 ]; then timed_out=1; fi
      ;;
    native)
      # Bash-native fallback: set -m gives the backgrounded job its own
      # process group (a bash builtin, no external binary required).
      set -m
      local native_stdout
      native_stdout=$(mktemp "$RUN_DIR/${RUN_ID}.native-stdout.XXXXXX") || { echo "ERROR: mktemp failed for native-tier stdout capture" >&2; rm -f "$payload_file"; set +m; return 1; }
      bash -- "$HOOK_SNAPSHOT" < "$payload_file" > "$native_stdout" 2>/dev/null &
      local pid=$!
      local waited=0
      while kill -0 "$pid" 2>/dev/null && [ "$waited" -lt "$TIMEOUT_SECS" ]; do
        sleep 1; waited=$((waited + 1))
      done
      if kill -0 "$pid" 2>/dev/null; then
        # The wait loop above only exits early on natural completion; reaching
        # here means TIMEOUT_SECS elapsed with the process still alive.
        timed_out=1
        # Negative PID targets the whole process group, not just $pid.
        kill -TERM -- -"$pid" 2>/dev/null
        sleep "$GRACE_SECS"
        # Confirm dead by checking the whole process group, not just the
        # original PID -- a lone-PID check can report clean while a
        # re-parented or already-detached child is still running. If pgrep
        # itself isn't available, fail toward killing (escalate anyway)
        # rather than silently treating "can't check" as "already dead."
        if ! command -v pgrep >/dev/null 2>&1 || pgrep -g "$pid" >/dev/null 2>&1; then
          kill -KILL -- -"$pid" 2>/dev/null
        fi
      fi
      wait "$pid" 2>/dev/null
      stdout_out=$(cat "$native_stdout" 2>/dev/null)
      rm -f "$native_stdout"
      set +m
      ;;
  esac
  rm -f "$payload_file"

  # Named residual risk, not claimed closed: a grandchild that detaches
  # into its own session before the kill fires (os.setsid()/
  # start_new_session=True) escapes a process-group kill regardless of
  # mechanism above.

  if [ "$timed_out" -eq 1 ]; then
    python3 -c "
import json, sys
print(json.dumps({'prompt': sys.argv[1], 'class': sys.argv[2], 'status': 'skipped', 'skip_reason': 'timeout', 'hints': None}))
" "$prompt" "$class" > "$out_file"
    return
  fi

  lines_after=$(wc -l < "$METRICS_SCRATCH" 2>/dev/null || echo 0)

  if [ "$lines_after" -le "$lines_before" ]; then
    python3 -c "
import json, sys
print(json.dumps({'prompt': sys.argv[1], 'class': sys.argv[2], 'status': 'skipped', 'skip_reason': 'no_metrics_record', 'hints': None}))
" "$prompt" "$class" > "$out_file"
    return
  fi

  local new_line
  new_line=$(tail -n "+$((lines_before + 1))" "$METRICS_SCRATCH" 2>/dev/null | tail -1)
  status=$(python3 -c "
import json, sys
try:
    parsed = json.loads(sys.argv[1])
    print(parsed.get('status', 'metrics_line_unparseable') if isinstance(parsed, dict) else 'metrics_line_unparseable')
except json.JSONDecodeError:
    print('metrics_line_unparseable')
" "$new_line")

  if [ "$status" != "ok" ]; then
    python3 -c "
import json, sys
print(json.dumps({'prompt': sys.argv[1], 'class': sys.argv[2], 'status': 'skipped', 'skip_reason': sys.argv[3], 'hints': None}))
" "$prompt" "$class" "$status" > "$out_file"
    return
  fi

  local hints_json
  if ! hints_json=$(target_present_in_hints "$stdout_out" "$TARGET_SKILL"); then
    python3 -c "
import json, sys
print(json.dumps({'prompt': sys.argv[1], 'class': sys.argv[2], 'status': 'skipped', 'skip_reason': 'scoring_error', 'hints': None}))
" "$prompt" "$class" > "$out_file"
    return
  fi
  local target_present
  target_present=$(python3 -c "import json,sys; print('true' if json.loads(sys.argv[1])['present'] else 'false')" "$hints_json")

  local verdict="fail"
  case "$class" in
    positive)    [ "$target_present" = "true" ] && verdict="pass" || verdict="fail" ;;
    negative)    [ "$target_present" = "true" ] && verdict="fail" || verdict="pass" ;;
    adversarial) [ "$target_present" = "true" ] && verdict="fail" || verdict="pass" ;;
  esac

  # Persist the extracted hint list (skill names, in rank order) for every
  # scored prompt -- not just an aggregate pass/fail boolean -- so a FAIL
  # detail can report "what it matched instead" from the run record itself,
  # without re-invoking the hook.
  python3 -c "
import json, sys
hints = json.loads(sys.argv[4])['hints']
print(json.dumps({'prompt': sys.argv[1], 'class': sys.argv[2], 'status': sys.argv[3], 'skip_reason': None, 'hints': hints}))
" "$prompt" "$class" "$verdict" "$hints_json" > "$out_file"
}

# -- Iterate every prompt in the battery, classify, append to the JSONL stream --
# Records are NUL-delimited JSON objects (never tab/newline-delimited raw
# text): a prompt containing a literal newline or tab is a realistic,
# ordinary multi-sentence prompt, not an edge case, and would otherwise
# desynchronize a line-oriented read loop. NUL cannot appear inside a JSON
# string, so it is a safe, unambiguous record separator here.
while IFS= read -r -d '' record; do
  class=$(python3 -c "import json,sys; print(json.loads(sys.argv[1])['class'])" "$record")
  prompt=$(python3 -c "import json,sys; print(json.loads(sys.argv[1])['prompt'])" "$record")
  if ! result_file=$(mktemp "$RUN_DIR/${RUN_ID}.result.XXXXXX"); then
    # Same "never let a prompt vanish uncounted" treatment as
    # run_one_prompt's own internal mktemp failures: record and continue,
    # never abort the whole run over one scratch-file allocation failure.
    echo "ERROR: mktemp failed for result file -- recording this one prompt as skipped, continuing run" >&2
    python3 -c "
import json, sys
print(json.dumps({'prompt': sys.argv[1], 'class': sys.argv[2], 'status': 'skipped', 'skip_reason': 'internal_error', 'hints': None}))
" "$prompt" "$class" >&3
    echo >&3
    continue
  fi
  if run_one_prompt "$result_file" "$prompt" "$class"; then
    cat "$result_file" >&3
  else
    # run_one_prompt failed internally (e.g. its own mktemp call failed)
    # before ever writing $out_file -- never let this prompt silently
    # vanish from the report uncounted; record it as skipped instead.
    python3 -c "
import json, sys
print(json.dumps({'prompt': sys.argv[1], 'class': sys.argv[2], 'status': 'skipped', 'skip_reason': 'internal_error', 'hints': None}))
" "$prompt" "$class" >&3
  fi
  echo >&3
  rm -f "$result_file"
done < <(python3 -c "
import json, sys
data = json.load(open(sys.argv[1]))
for cls in ('positive', 'negative', 'adversarial'):
    for p in data.get(cls, []):
        sys.stdout.write(json.dumps({'class': cls, 'prompt': p}))
        sys.stdout.write('\0')
" "$VALIDATED_BATTERY")
rm -f "$VALIDATED_BATTERY"

# Close the write fd now that every prompt has been recorded -- flushes and
# releases it before the summary step reads the same path back. The final
# read below is still path-based (a live fd opened for writing can't be
# handed to the summary's read-mode open() the same way), so re-check that
# the path is still a genuine regular file, not a symlink planted after
# fd 3 was opened above, narrowing this to a single check-then-open window
# rather than leaving the whole run open to it.
exec 3>&-
if [ -L "$RESULTS_STREAM" ]; then
  echo "ERROR: results stream path became a symlink during the run -- refusing to read a potentially attacker-redirected file: $RESULTS_STREAM" >&2
  rm -rf "$CACHE_SCRATCH"
  rm -f "$METRICS_SCRATCH" "$HOOK_SNAPSHOT"
  exit 1
fi

# -- Assemble final summary via atomic write (same directory as destination,
#    to avoid a cross-filesystem EXDEV rename failure). All variable data
#    (run id, target skill, hook path, paths) is passed via sys.argv, never
#    interpolated into this source string. --
python3 -c "
import json, hashlib, os, sys, tempfile

run_id, target_skill, hook_path, results_stream, cache_scratch, run_dir, summary_file = sys.argv[1:8]

results = []
with open(results_stream) as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        try:
            rec = json.loads(line)
        except json.JSONDecodeError:
            continue  # drop a torn trailing line from a mid-write crash
        if not isinstance(rec, dict) or rec.get('class') not in ('positive', 'negative', 'adversarial'):
            continue  # defensive: a syntactically valid but wrong-shaped record (not just a JSON parse failure) must not corrupt aggregation either
        results.append(rec)

skipped = {'positive': 0, 'negative': 0, 'adversarial': 0}
counts = {'positive': {'pass': 0, 'fail': 0}, 'negative': {'pass': 0, 'fail': 0}, 'adversarial': {'pass': 0, 'fail': 0}}
for r in results:
    cls = r['class']
    if r['status'] == 'skipped':
        skipped[cls] += 1
    else:
        counts[cls][r['status']] += 1

pass_rate = {}
total_pass = total_fail = 0
for cls in ('positive', 'negative', 'adversarial'):
    p, f = counts[cls]['pass'], counts[cls]['fail']
    total_pass += p; total_fail += f
    pass_rate[cls] = (p / (p + f)) if (p + f) > 0 else None
pass_rate['overall'] = (total_pass / (total_pass + total_fail)) if (total_pass + total_fail) > 0 else None

total_skipped = sum(skipped.values())
total_prompts = len(results)
all_skipped = total_prompts > 0 and total_skipped == total_prompts

# corpus_hash: SHA-256 over sorted, deduplicated skill names from the
# hook's own cache entries (never an independent filesystem scan, which
# could disagree with what the hook itself is using), joined by a single
# newline with no trailing newline after the last name. Deduplicated so
# an alias pair sharing one canonical name (e.g. a bare name and its
# sp-prefixed alias) doesn't double-count that name as two distinct
# skills.
corpus_hash = None
skill_count = None
try:
    with open(os.path.join(cache_scratch, 'cache.json')) as f:
        cache = json.load(f)
    # Some hook generations wrote a pre-migration cache as a bare JSON
    # list with no 'entries' key at all -- not just missing/malformed,
    # a genuinely different top-level shape. Treat anything that isn't a
    # dict, or any non-dict/nameless entry within it, as unusable rather
    # than crashing the whole summary.
    if not isinstance(cache, dict):
        raise ValueError('cache.json is not a JSON object')
    names = sorted({e['name'] for e in cache.get('entries', []) if isinstance(e, dict) and 'name' in e})
    corpus_hash = 'sha256:' + hashlib.sha256('\n'.join(names).encode('utf-8')).hexdigest()
    skill_count = len(names)
except (OSError, json.JSONDecodeError, KeyError, ValueError, AttributeError, TypeError):
    pass  # cache was never built (OSError covers FileNotFoundError/PermissionError), or was written by a hook generation with an incompatible shape

summary = {
    'run_id': run_id,
    'skill': target_skill,
    'hook_path': hook_path,
    'results_stream_path': results_stream,
    'corpus_identity': {'skill_count': skill_count, 'corpus_hash': corpus_hash},
    'results': results,
    'skipped': skipped,
    'pass_rate': pass_rate,
    'all_skipped_pattern': all_skipped,
}

tmp_fd, tmp_path = tempfile.mkstemp(dir=run_dir, suffix='.json.tmp')
try:
    with os.fdopen(tmp_fd, 'w') as f:
        json.dump(summary, f, indent=2)
    os.replace(tmp_path, summary_file)
except BaseException:
    try:
        os.unlink(tmp_path)
    except OSError:
        pass
    raise  # never leave a *.json.tmp scratch file behind on a dump/replace failure

if all_skipped and total_prompts > 0:
    print('EVERY PROMPT WAS SKIPPED -- this likely means the installed hook predates or lacks the required metrics mechanism entirely (confirmed possible on a Codex-CLI-generation hook), not that routing itself failed.')
print(f'Summary written: {summary_file}')
" "$RUN_ID" "$TARGET_SKILL" "$HOOK_PATH" "$RESULTS_STREAM" "$CACHE_SCRATCH" "$RUN_DIR" "$SUMMARY_FILE"
SUMMARY_EXIT=$?
if [ "$SUMMARY_EXIT" -ne 0 ]; then
  echo "ERROR: summary assembly failed (exit $SUMMARY_EXIT) -- no summary file was written; this is a tool failure, not a completed run" >&2
  rm -rf "$CACHE_SCRATCH"
  rm -f "$HOOK_SNAPSHOT" "$METRICS_SCRATCH"
  exit 1
fi

# Cleanup scratch cache dir, hook snapshot, and metrics scratch file (results
# stream and summary file are the durable record)
rm -rf "$CACHE_SCRATCH"
rm -f "$HOOK_SNAPSHOT" "$METRICS_SCRATCH"

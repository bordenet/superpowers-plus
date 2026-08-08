---
name: skill-trigger-audit
source: superpowers-plus
augment_menu: true
auto_invoke: false
description: "Dynamic, behavioral audit of whether a skill wins, loses, or wrongly wins the skill-router hook's routing decision against positive, negative, and adversarial prompts -- complements skill-health-check's structural lint, which never runs a prompt through the real scorer. Requires the installed skill-router hook; degrades to a clear error, not a guess, when absent."
summary: "Use when: verifying a skill's routing actually works before/after editing its triggers or description, or reproducing a reported false-positive/false-negative misfire against the live hook. Not a structural lint (skill-health-check) or a static trigger-phrase check (tools/skill-trigger-validator.sh) -- this runs real prompts through the real scorer."
triggers:
  - "/sp-skill-trigger-audit"
  - "/skill-trigger-audit"
  - "audit skill triggers"
  - "test skill routing"
  - "does this skill actually fire"
  - "trigger reliability test"
  - "adversarial trigger test"
  - "reproduce a routing false positive"
anti_triggers:
  - "skill structure lint"
  - "skill frontmatter check"
  - "review this PR"
  - "fix the router"
  - "audit codeowners"
  - "scan for secrets"
  - "create a branch"
  - "open an MR"
coordination:
  group: observability
  order: 1
  requires: []
  enables: []
  escalates_to: []
  internal: false
composition:
  consumes: [skill-definition, installed-skill-router-hook]
  produces: [trigger-audit-report, trigger-audit-run-record]
  capabilities: [dynamic-routing-audit, adversarial-prompt-generation]
  priority: 30
  optional: false
  requires_all: false
---

> **Purpose:** Runs a battery of real prompts through the real, installed skill-router hook for one target skill, and reports whether it actually wins, loses, or wrongly wins each routing decision.
>
> **Wrong skill?** Structural `skill.md` lint → `skill-health-check`. Static `triggers:` phrase lint → `tools/skill-trigger-validator.sh`. Skill-prose LLM-execution-safety review → `llm-skill-review`.

**Announce at start:** "I'm running the **skill-trigger-audit** dynamic routing test."

Run `skill-health-check` alongside this, not instead of it -- one is
structural, the other behavioral; neither substitutes for the other.
Full neighbor comparison in `reference.md`.

## When to Use

- Verifying a skill's routing actually works after editing its `triggers:`/`description`
- Reproducing a reported false-positive or false-negative misfire against the live hook
- Not for structural lint (frontmatter shape) or a static trigger-phrase check -- this runs real prompts through the real scorer

## Step 0: Locate the installed skill-router hook

Check, in order: `$SKILL_ROUTER_HOOK_PATH` (explicit override), then
`~/.claude/hooks/user-prompt-submit-skill-router.sh`, then
`~/.codex/hooks/user-prompt-submit-skill-router.sh`. If none exist, stop:
"no installed skill-router hook found at any known path -- this audit
requires the superpowers-plus hook to be installed." There is no
static-only fallback -- the entire audit is dynamic by definition.

**Codex-CLI scope note:** Step 3's metrics-based detection is only
verified against the Claude Code hook path -- a Codex-CLI hook predating
the metrics mechanism produces a 100%-SKIPPED run (see Failure Modes).

**Preflight canary, before anything else runs:** check whether
`CLAUDE_HOOKS_BYPASS=1` is set in the environment (the hook's own
second executable line, after its `set` builtin). If set, stop:
"CLAUDE_HOOKS_BYPASS=1 is set -- the installed hook will exit
immediately with no output for every invocation; unset it to run a real
audit." Do not burn a full battery discovering this one prompt at a
time.

## Step 1: Locate the target skill

Search this repo's `skills/**/skill.md` first, then the merged personal
skills directory the located hook itself reads from
(`SKILLS_DIR="${CODEX_SKILLS_DIR:-$HOME/.codex/skills}"` -- the hook's
own resolution line; `CODEX_SKILLS_DIR` is the only override it
recognizes). If not found in either place, stop: "skill '<name>' not
found in this repo or the installed corpus." Parse its frontmatter
(`name`, `description`, `triggers`, `anti_triggers`) -- handle a plain
inline array, a multiline YAML list, and an unclosed/malformed bracket
(fall back to an empty list, don't crash).

**Corpus-staleness preflight (required):** the hook scores against
`SKILLS_DIR` -- a deployed copy this repo's `install.sh` doesn't directly
control the layout of, never a live symlink back to this repo. Editing a
skill here doesn't change what the hook sees until reinstalled.
Confirmed on a real install: `SKILLS_DIR` is flat
(`SKILLS_DIR/<skill-directory-name>/skill.md`, no domain subdirectory --
e.g. `skill-health-check`, not `observability/skill-health-check`).
Before running the battery, compare the target skill's `skill.md` mtime
here against that flat installed path: if missing or older, stop and
report "the installed copy of '<name>' is stale -- reinstall before
auditing an edit, or results will reflect the OLD version." Verified
only on this one install; a different deploy mechanism nesting by
domain would need a fallback search.

## Step 2: Build the prompt battery

Always attempt both sources:

1. **Fixture first:** if `.trigger-audit-fixtures/<skill-name>.json`
   exists, load its `positive`/`negative`/`adversarial` lists. If it
   exists but fails to parse as JSON, stop with a distinct error naming
   the fixture path -- never silently treat it as empty and regenerate
   over it, which would discard whatever it held (this file is
   hand-curated, repo-tracked data, not disposable scratch output).
2. **Generate to fill gaps:** for any class with fewer than 3 prompts,
   dispatch one sub-agent with the target skill's frontmatter plus up to
   3 sibling skills' frontmatter -- same domain folder, sorted
   alphabetically by skill name, first 3 -- for adversarial contrast.
   Instruct it to return exactly N (default 3) prompts per class as JSON
   matching the fixture schema below, and nothing else -- it never sees
   the hook's output. **No wall-clock timeout is enforceable on this
   dispatch from the calling side** -- treat a response that never
   returns, or returns malformed/incomplete JSON, as the failure signal
   instead: retry once; if it fails a second time, proceed with whatever
   valid prompts exist (none, if neither attempt returned anything) and
   report the shortfall explicitly per class (e.g. "adversarial: 1/3
   generated").

Append every newly-generated prompt back into
`.trigger-audit-fixtures/<skill-name>.json` (create it if missing) --
append-only, deduped by exact string, via the same temp-file-plus-rename
pattern Step 3 uses for its own summary file (temp file, same directory,
then rename over the original), not an in-place edit -- concurrent
sessions can run against a shared checkout, and this is the same
torn-write risk Step 3 already guards against. Fixture files are
repo-tracked, not gitignored (hand-curated test data meant to be
committed and reviewed, unlike `.trigger-audit-runs/`'s machine-local
scratch output). A second run reuses what this run paid to generate.

Fixture schema:

```json
{
  "positive": ["<prompt that should route here>", "..."],
  "negative": ["<generic prompt that should not route here>", "..."],
  "adversarial": ["<prompt sharing vocabulary but asking for something else>", "..."]
}
```

## Step 3: Score the battery and persist progressively

**Run this from the repository root** -- every relative path here
(`.trigger-audit-fixtures/`, `.trigger-audit-runs/`, the script path
itself) is repo-root-relative and diverges or fails elsewhere, matching
`skill-health-check`'s own convention.

Run `bash skills/observability/skill-trigger-audit/scripts/battery-runner.sh
<hook_path> <target_skill> <battery_json_file>` (from Step 0/1/2's
outputs). **Must run as a single script invocation**, not a series of
separate per-prompt tool calls -- the env var overrides it sets must
persist across every hook invocation in the run, and environment state
does not carry across separate shell invocations in this execution
environment (only the working directory does). A per-prompt-call
implementation would silently revert every invocation after the first
to the hook's real production paths.

The script (see its own header comment and inline comments for full
detail):

- Isolates `CLAUDE_SKILL_ROUTER_METRICS`/`CLAUDE_SKILL_ROUTER_CACHE` to
  fresh scratch paths, set once for the whole run.
- Invokes the hook via input redirection (never a pipe -- a piped
  invocation's `$!` captures the last pipeline command, not the first).
- Detects a timeout mechanism in order (`timeout --kill-after` ->
  `gtimeout` -> a bash-native `set -m` + negative-PID-kill fallback) and
  confirms dead via the whole process group (`pgrep -g`), not a single
  PID. **Named residual risk, not claimed closed:** a grandchild that
  detaches into its own session before the kill fires escapes a
  process-group kill regardless of mechanism.
- Reads the hook's own metrics-file channel (never its exit code -- the
  hook's documented contract is "NEVER blocks, always exits 0") to
  classify each prompt `ok` / `cache_unreadable` / `scoring_error` /
  `unknown_exit_N` / `no_metrics_record` / `timeout` /
  `metrics_line_unparseable` (the metrics line itself was found but
  wasn't valid JSON or wasn't the expected shape -- distinct from
  `no_metrics_record`, where no line appeared at all).
- Persists progressively: an append-only `<run-id>.results.jsonl` stream
  (parse-validated to drop a torn trailing line or wrong-shaped record)
  plus a `<run-id>.json` summary written atomically at the end (temp
  file + rename, same directory, avoiding a cross-filesystem `EXDEV`
  failure). Every scored record includes the hint-name list in rank
  order, so Step 4's FAIL-detail requirement is answerable from the run
  record itself, without re-invoking the hook.
- Detects the all-or-nothing 100%-SKIPPED pattern (distinct from a
  single skipped prompt) and prints an explicit hook-incompatibility
  warning rather than a silent all-null table.
- Holds a single write file descriptor open for the results stream for
  the whole run and snapshots both the hook path and the battery file to
  private scratch copies before use, rather than repeatedly reopening
  either by path -- closes a class of TOCTOU/symlink risk on any path
  supplied by the caller.

## Step 4: Print the report

Never write it anywhere automatically. Report a per-class table
(Total/Pass/Fail/Skipped/Pass rate, excluding Skipped from both
numerator and denominator) plus one detail block per FAIL (prompt,
class, expected, actual hint list in rank order -- the hook never
prints a numeric score, only
`[skill-router] Likely match: <name> — <description>`). For any SKIPPED
prompt, name the actual `skip_reason` verbatim. If `all_skipped_pattern`
is true, lead with that finding, not a null table.

## Explicitly out of scope (v1)

Full list with rationale in `reference.md`. Summary: full-corpus/
multi-skill batching, auto-pruning stale fixtures, auto-fixing a failing
skill, CI/scheduled runs, auditing Claude Code's or Augment's own native
routing, `.trigger-audit-runs/` retention, a circuit breaker for a
systemically-broken hook, the orchestrating-process-killed-externally
case, per-prompt latency telemetry, and graceful degradation when the
executing agent has no sub-agent-dispatch capability.

## Failure Modes

| Failure | Symptom | Recovery |
|---|---|---|
| No installed hook found | Cannot invoke anything | Hard stop with checked paths listed |
| `CLAUDE_HOOKS_BYPASS=1` set | Every invocation exits with no output | Preflight canary (Step 0) stops before any prompt runs |
| Hook-side failure (poisoned cache field) | Hook still exits 0 -- exit code cannot detect this | Read the scratch metrics file's `status` field instead; mark SKIPPED with that status value verbatim (`cache_unreadable`, `scoring_error`, or `unknown_exit_N`) as `skip_reason` |
| No metrics line appended at all | Cannot distinguish `ok` from a hook-side failure | Mark SKIPPED (no_metrics_record) -- includes the case of a Codex-CLI hook generation that predates this mechanism entirely (confirmed: zero metrics/`anti_triggers`/IDF machinery in at least one real installation) |
| Every class 100% SKIPPED (no_metrics_record) | All-null pass-rate table looks like noise | Report explicitly as a likely hook-generation incompatibility, not a routing failure; a partially-upgraded hook producing a partial-skip pattern is a named, unsolved residual case |
| Invocation hangs | Blocks the whole battery indefinitely | Hard timeout; kill the whole process group (not just the PID) and confirm dead before moving to the next prompt |
| Generated battery malformed/incomplete | Battery incomplete for one or more classes | Retry the dispatch once; then run with whatever valid prompts exist and report the shortfall |
| The battery file passed to Step 3 is corrupt JSON | Without a check, this silently produces a false-clean "0 results" summary indistinguishable from a legitimately empty battery | `battery-runner.sh` validates it before anything runs; hard stop with a distinct error, never a silent empty summary. Only covers the file as Step 2 hands it off -- if the pre-existing fixture itself was corrupt, Step 2's own read-step handling (above) is what catches that, not this check |
| Fixture file exists but is itself corrupt JSON (pre-existing corruption, not introduced by this run) | Step 2's Step-3-facing check can't see this -- it only validates what Step 2 produces, after Step 2 has already read (or failed to read) the original fixture | Step 2 stops with a distinct error naming the fixture path rather than silently discarding and regenerating it |
| Corpus composition changes between runs | Same prompt can legitimately score differently | Compare `corpus_hash` between two run records before treating a delta as a regression |
| Env var overrides set per-prompt instead of once | Isolation silently reverts to production paths after the first invocation | Run the entire battery loop as one script invocation, never as separate per-prompt tool calls (see Step 3) |

## Testing status

`battery-runner.sh` went through 8 rounds of adversarial code review
before landing -- final score 9.75/10, 0 unresolved Critical/Important
findings. Full hardening history in `reference.md`.

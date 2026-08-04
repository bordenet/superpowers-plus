# skill-trigger-audit: reference

Supplementary detail for `skill.md` -- scope boundaries and rationale
that don't need to be re-read on every invocation. See `skill.md` for
the actual Process steps.

## Explicitly out of scope (v1)

- Full-corpus sweep or multi-skill batching in one invocation -- refuse
  and point to a future corpus-scale phase; single-skill only.
- Auto-detecting/pruning a stale fixture -- report the fixture's mtime
  vs. the skill's `skill.md` mtime; a human re-generates by deleting the
  fixture.
- Auto-fixing a failing skill's `triggers:`/`description` -- diagnosis
  only.
- CI integration / scheduled runs -- on-demand and conversational.
- Auditing Claude Code's own native `description`-driven routing
  decision, or Augment's -- this audits only the advisory hook's hint
  output; Augment routes via `triggers:`/`anti_triggers:` natively, with
  no comparable shell hook for this design to invoke or measure.
- Retention/cleanup of `.trigger-audit-runs/` -- grows without bound
  across repeat runs, matching this repo's existing scratch-output
  precedent for similar tools.
- A circuit breaker for a systemically-broken hook -- every prompt pays
  the full timeout+grace cost before a human sees the pattern.
- The orchestrating process itself being killed externally mid-run,
  orphaning an in-flight hook child -- distinct from the disclosed
  setsid-escape risk in Step 3.
- Per-prompt latency telemetry -- only an aggregate is recorded.
- Graceful degradation when the executing agent has no sub-agent-dispatch
  capability at all (Step 2 assumes one exists, e.g. Claude Code's Task
  tool) -- not established whether every supported agent host has an
  equivalent.
- Mutual exclusion on the fixture file's read-merge-write cycle. Step 2's
  temp-file-plus-rename write prevents a torn/corrupt write, not a lost
  update: two sessions concurrently regenerating the same skill's fixture
  can each read the same "before" state and each write an "after" state,
  with the last writer's version silently missing the other's newly-
  generated prompts. Self-healing (a later run regenerates the gap at
  cost) but not detected or reported when it happens.
- A hard guarantee on Step 2's sub-agent dispatch actually returning at
  all. "Treat a non-returning or malformed/incomplete response as the
  failure signal" describes what to do once a response is judged absent,
  but a synchronous tool call that never returns doesn't hand control
  back to make that judgment mid-flight -- a platform constraint, not
  something this design can route around.

## Disambiguation vs neighbors

| Neighbor | It does | This skill does |
|---|---|---|
| `skill-health-check` | Structural lint of `skill.md` | Dynamic behavioral routing test |
| `tools/skill-trigger-validator.sh` | Static `triggers:` phrase lint (overlaps, missing triggers, registry) | Real prompts through the real scorer |
| `llm-skill-review` | LLM-execution-safety review pre-merge | Behavioral routing test, run after reinstalling an edited skill (Step 1's preflight check enforces this) or as a post-merge regression check |

## Testing status

`battery-runner.sh` went through 8 rounds of adversarial code review
before landing, each round finding and fixing real, empirically
reproduced defects rather than theoretical ones: two structurally
distinct remote-code-execution vectors (unescaped string interpolation
into an embedded interpreter call; a hook-path/stdin-aliasing bug), two
TOCTOU vulnerabilities on caller-supplied paths (closed by snapshotting
each to a private, script-owned scratch copy before use), a results-file
symlink vulnerability at both create-time and append-time (closed by
holding a single write file descriptor open for the run instead of
repeatedly reopening the path), and several resource-leak/silent-record-
loss bugs. Every fix was verified against a live reproduction of the
issue it closed, including a full end-to-end regression run against a
real installed skill-router hook after each round. Final score: 9.75/10,
0 unresolved Critical/Important findings, 1 accepted Minor (a held file
descriptor is inherited by hook child processes; assessed as
non-exploitable against this tool's actual threat model -- a local
dev-tool run by one user, not a multi-tenant privilege boundary).

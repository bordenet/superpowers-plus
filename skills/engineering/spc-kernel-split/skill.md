---
name: spc-kernel-split
source: superpowers-plus
augment_menu: true
auto_invoke: false
description: "Partition any target skill.md into a resident safety kernel and an on-demand reference. Proposes a split using keyword scoring, applies on confirmation, and installs a permanent context-budget regression test."
summary: "Use when: splitting a large skill.md into a kernel (always loaded) and reference (on demand). Triggers on: large skill, skill too big, reduce context budget, skill byte budget, kernel split, partition skill."
triggers: ["/sp-spc-kernel-split", "split skill", "partition skill", "kernel split", "reference split", "skill too big", "reduce skill size", "skill byte budget", "context budget", "skill context reduction"]
anti_triggers: ["split feature", "split service", "split PR", "split ticket"]
coordination:
  group: engineering
  order: 50
  requires: []
  enables: []
  escalates_to: []
  internal: false
composition:
  produces: [proposed-kernel.md, proposed-reference.md, ambiguous-items.md, reference.md, context-budget-test]
  consumes: [skill.md]
  capabilities: []
  priority: 50
  optional: false
  requires_all: false
---

# spc-kernel-split

> **Announce at start:** "I'm using the **spc-kernel-split** skill to partition `<target-skill.md>`."

Partition any large `skill.md` into a resident kernel and an on-demand reference, using the keyword-scoring rubric. Prove the split with a permanent context-budget regression test.

## When to Use

- A skill's `wc -c` exceeds the byte budget (>6 KB) and it's causing context pressure in production sessions
- The doctor reports the skill is oversized or failing context-budget regression tests
- A skill has a large reference section that is rarely needed at trigger time

**NOT when:** the skill is appropriately sized — splitting for its own sake adds maintenance overhead without benefit.

## Reference index

Load `reference.md` selectively. Do not load it for a routine operation.

| Need | Read this reference section |
|---|---|
| Full keyword scoring rubric and Failure Modes safety carve-out | `Scoring rubric` |
| Handling ambiguous sections | `Ambiguous section decisions` |
| Edge cases and safety-critical content rules | `Edge cases` |
| How to apply this skill to a new skill | `How to apply spc-kernel-split to your skill` |

## Prerequisites

Before partitioning, verify:

1. `tools/section-loader.sh` exists and is executable.
2. `tools/skill-partitioner` exists and is executable.
3. The target skill has at least 3 behavioral bats tests. If fewer than 3: add tests first, commit them, then proceed.
4. Record the target skill's current byte count -- this is the `before` baseline.

```text
wc -c <path/to/skill.md>
```

## Workflow

### Step 1 -- Propose the split

```text
tools/skill-partitioner propose <path/to/skill.md>
```

The tool prints per-section scores and writes three files to a temp dir:
- `proposed-kernel.md` -- sections scoring >= +2
- `proposed-reference.md` -- sections scoring <= -1
- `ambiguous-items.md` -- sections scoring -1 to +1 (human decision required)

Review the proposal. Move ambiguous sections manually into the correct proposed file before proceeding. Read `reference.md` under `Ambiguous section decisions` for guidance.

### Step 2 -- Apply the split

```text
tools/skill-partitioner apply <path/to/skill.md> <proposed-kernel.md> <proposed-reference.md>
```

This overwrites `skill.md` with the kernel content (routing table prepended) and writes `reference.md` alongside it.

Verify the routing table rows match the reference headings. Fill in the `Need` column with plain-language descriptions.

### Step 3 -- Wire the section-loader call

The kernel's routing table uses `reference.md` sections. The kernel must also embed a section-loader call (between marker comments) so agents can load individual reference sections on demand. Use a four-backtick outer fence so the inner ```bash block renders correctly:

````text
<!-- spc-kernel-split-reference-loader:start -->
```bash
_project_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
_spc_ref=""
for _candidate in \
  "$_project_root/skills/<domain>/<skill-name>/reference.md" \
  "$HOME/.agents/skills/<skill-name>/reference.md"
do
  if [ -r "$_candidate" ]; then _spc_ref="$_candidate"; break; fi
done
_spc_loader="$_project_root/tools/section-loader.sh"
[ -r "$_spc_ref" ] || { printf 'reference missing\n' >&2; exit 1; }
_section='<section heading>'
bash "$_spc_loader" "$_spc_ref" "$_section" \
  || { printf 'section not found: %s\n' "$_section" >&2; exit 1; }
```
<!-- spc-kernel-split-reference-loader:end -->
````

### Step 4 -- Add a context-budget regression test

Add an entry to `tests/engineering/spc-kernel-split-context.bats`:

```text
@test "SKILLNAME kernel stays within byte budget" {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd -P)"
  SKILL="$REPO_ROOT/skills/DOMAIN/SKILLNAME/skill.md"
  BEFORE_BYTES=99999  # replace with actual pre-split byte count
  BUDGET_RATIO_PERCENT=60
  MAX_BYTES=$(( BEFORE_BYTES * BUDGET_RATIO_PERCENT / 100 ))
  current="$(wc -c < "$SKILL" | tr -d ' ')"
  [ "$current" -le "$MAX_BYTES" ]
}
```

### Step 5 -- Verify

```bash
bats tests/engineering/spc-kernel-split.bats
bats tests/engineering/spc-kernel-split-context.bats
```

Verify: kernel byte count <= 60% of before, and the full behavioral test suite for the target skill passes.

## Safety invariants

- **Smallest safe, not smallest.** Safety-critical content (hard gates, NEVER rules, scope checks) stays in the kernel even if it is long.
- **Never move YAML frontmatter.** It always stays in the kernel (scored +999).
- **Never silently omit preflight blocks.** A section containing a mandatory pre-write checklist must either stay in the kernel, or be listed in the routing table with an explicit "load before every write" note so agents always fetch it before the associated operation.
- **The section-loader must fail loudly** (non-zero exit) when a heading is missing -- it never falls back to whole-file.
- **The budget test is permanent** -- it fails if the kernel grows past the pinned ratio. Do not delete it.

## Failure Modes

| Failure | Fix |
|---|---|
| Kernel is still too large after split | Move additional Failure Modes and worked-example content to reference; re-run verify |
| Section-loader exits non-zero for a valid heading | Check the heading text matches exactly (case-sensitive, no trailing spaces) |
| Budget test fails after a legitimate kernel addition | Bump `BEFORE_BYTES` and `BUDGET_RATIO_PERCENT` in the test, document the rationale in a comment |
| Ambiguous sections moved to kernel incorrectly | Re-read `reference.md` under `Edge cases`; safety-critical wins ties |

## Companion tools

- `tools/section-loader.sh` -- section-precise reference reader
- `tools/skill-partitioner` -- propose and apply subcommands
- `tests/engineering/spc-kernel-split-context.bats` -- fleet-wide budget regression suite

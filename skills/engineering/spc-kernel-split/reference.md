# spc-kernel-split -- Reference

Companion reference for `skill.md`. Contains the full scoring rubric, ambiguous section guidance, and the "How to apply" walkthrough.

## Contents

- Scoring rubric
- Ambiguous section decisions
- Edge cases
- How to apply spc-kernel-split to your skill

## Scoring rubric

Each section of the target `skill.md` is scored by scanning its heading text and the first 200 characters of its content against two keyword lists.

### Kernel-hint keywords (+2 per match)

| Keyword | Rationale |
|---|---|
| `auth` | Authentication state -- must be in the resident kernel |
| `verify` | Verification gates -- critical for correctness |
| `gate` | Explicit gate -- always kernel |
| `delegate` | Delegation to a scope-checked sub-system |
| `merge` | Merge authorization -- hard gate |
| `prod` | Production-environment caution |
| `secret` | Secrets handling -- always kernel |
| `credential` | Credential management |
| `irreversible` | Irreversible operations -- warn in kernel |
| `destructive` | Destructive operations |
| `hard gate` | Explicit hard-gate label |
| `must` | Mandatory instruction |
| `never` | Prohibition |
| `mandatory` | Mandatory instruction |

Threshold: sections scoring **>= +2** go to `proposed-kernel.md`.

### Reference-hint keywords (-1 per match)

| Keyword | Rationale |
|---|---|
| `example` | Examples add context but are not execution-critical |
| `walkthrough` | Step-by-step walkthroughs are reference material |
| `troubleshoot` | Troubleshooting is looked up, not always needed |
| `catalog` | Command catalogs are reference tables |
| `edge case` | Edge case handling is looked up on demand |
| `optional` | Optional steps |

Threshold: sections scoring **<= -1** go to `proposed-reference.md`.

### Special rules (override keyword scores)

| Condition | Score | Outcome |
|---|---|---|
| YAML frontmatter (lines 1 through closing `---`) | +999 | Always kernel |
| Section heading contains "failure mode" or "failure modes" AND body has no `never` / `must` / `hard gate` / `mandatory` keyword in first 200 chars | -999 | Always reference |
| `EXTREMELY_IMPORTANT` tag in first 200 chars | +4 | Strong kernel signal |

The Failure Modes rule is gated on the absence of hard-gate keywords in the section body so a Failure Modes table that carries a "NEVER proceed" or "MUST abort" instruction stays resident in the kernel. Pure lookup-table Failure Modes (no hard-gate keywords) still demote to reference.

### Scoring ambiguity

Sections with net score **-1 to +1** land in `ambiguous-items.md`. A human must decide whether each belongs in the kernel or reference before `apply` can run.

Decision heuristic for ambiguous sections:

1. Does an agent need this content on EVERY invocation of the skill, even the most routine? -> kernel
2. Is this content consulted only for specific, less-common operations? -> reference
3. Does the section contain a NEVER, MUST, or hard-gate instruction? -> kernel even if other signals are weak

## Ambiguous section decisions

When `proposed-kernel.md` and `proposed-reference.md` are populated, `ambiguous-items.md` contains the sections that scored between -1 and +1 exclusive.

**Decision process:**

1. Read each ambiguous section heading and its first 200 characters.
2. Ask: "Does an agent need this on EVERY invocation?"
   - Yes -> move to `proposed-kernel.md`
   - No -> move to `proposed-reference.md`
3. Ask: "Does it contain a NEVER, MUST, or hard-gate instruction?"
   - Yes -> kernel (overrides step 2)
4. Document your decision in a comment on the relevant line.

**Common patterns:**

| Pattern | Decision |
|---|---|
| "When to use" or routing section | kernel |
| Shared policy block (tighten-on-edit, etc.) | kernel |
| Command tables or catalogs | reference |
| Troubleshooting tables | reference |
| Setup or installation steps | reference |
| Auth or credential details | kernel |

## Edge cases

### Safety-critical content that is long

A section containing a NEVER or hard-gate instruction but 2,000+ bytes of supporting text can be **split at the sub-section level** rather than moved wholesale. Keep the safety instruction in the kernel and move the explanatory prose to reference.

### Skills with no clear reference material

If `proposed-reference.md` is under 20% of the original size, the split may not be worth the overhead. Document this in the skill's changelog and file a follow-up rather than forcing a split.

### Skills with embedded code blocks

Code blocks that are EXECUTED by the agent (not just shown as examples) must stay in the kernel. Code blocks shown as examples or walkthroughs can move to reference.

The section-loader is designed for this: `tools/section-loader.sh <reference.md> <section>` loads exactly one section on demand, including any code blocks in that section.

### Budget ratio other than 0.6

The default budget ratio is 0.6 (kernel must be <= 60% of original). For skills with a small critical-safety core and large reference material, a ratio of 0.4 is appropriate. Document the chosen ratio in the context-budget bats test as a comment.

## How to apply spc-kernel-split to your skill

1. **Check prerequisites** (behavioral tests, tools present).
2. **Record the before baseline:** `wc -c skills/<domain>/<skill-name>/skill.md`
3. **Run propose:** `tools/skill-partitioner propose skills/<domain>/<skill-name>/skill.md`
4. **Review** `proposed-kernel.md`, `proposed-reference.md`, `ambiguous-items.md`.
5. **Resolve ambiguous sections** using the decision table above.
6. **Run apply:** `tools/skill-partitioner apply skills/<domain>/<skill-name>/skill.md <proposed-kernel.md> <proposed-reference.md>`
7. **Fill in the routing table** in the new `skill.md` (replace TBD `Need` values).
8. **Add the section-loader call** (see `skill.md` Step 3).
9. **Add the budget test** to `tests/engineering/spc-kernel-split-context.bats`.
10. **Run bats:** `bats tests/engineering/spc-kernel-split.bats && bats tests/engineering/spc-kernel-split-context.bats`
11. **Verify** the kernel is at least 40% smaller than before.
12. **Commit** the split as its own commit (isolable for rollback).
13. **Add a row** to `docs/harness/reduction-history.md` recording the before/after bytes and reduction percentage.

# Investigation State — Multi-Source Evidence Synthesis

> Reference material for the `investigation-state` skill.
> See `skill.md` for core guidance.

When an investigation has gathered evidence from multiple tools, use this technique to synthesize findings into a coherent diagnostic narrative before forming the next hypothesis.

---

## The Problem

Evidence from different tools arrives in fragments:
- A database query shows missing rows
- A pipeline log shows a failed migration step
- A git diff shows a schema change
- A ticket says "fixed in v2.3"

Without synthesis, agents form hypotheses from individual fragments rather than the full picture. This leads to narrow theories that miss the root cause.

---

## The Synthesis Process

### Step 1: Evidence Timeline

Arrange all evidence chronologically:

```
[timestamp] [source] — [finding]
[timestamp] [source] — [finding]
...
```

This reveals temporal patterns: what happened first, what followed, what correlates.

### Step 2: Source Triangulation

For each key finding, ask: **does evidence from a different source confirm or contradict this?**

| Finding | Confirming Source | Contradicting Source |
|---------|-------------------|----------------------|
| "Migration completed successfully" (pipeline log) | ? | "253 rows missing" (database query) |
| "Schema updated in v2.3" (git diff) | "Ticket marked resolved" (Linear) | "Docs still describe v2.2 schema" (wiki) |

Contradictions between sources are the most valuable signals — they narrow the search space.

### Step 3: Gap Analysis

After triangulation, identify what you **don't** know:

- Which tools haven't been consulted yet?
- Which time periods have no evidence?
- Which components of the system haven't been examined?

Gaps suggest where to look next. Update the investigation's `nextSteps` with specific queries to fill gaps.

### Step 4: Narrative Construction

Write a 2-3 sentence diagnostic narrative that explains ALL the evidence:

> "The migration script ran successfully (pipeline log) but skipped 253 records that had NULL values in the `email` column (database query). The schema change in v2.3 added a NOT NULL constraint (git diff) that the migration script doesn't handle. The ticket was closed prematurely (Linear) because the migration's exit code was 0 despite the skipped rows."

This narrative becomes the basis for the next hypothesis. If you can't construct a narrative that explains all evidence, you need more evidence.

---

## When to Synthesize

Trigger synthesis when:

1. **Evidence spans 3+ sources** — individual findings may not tell the full story
2. **Contradictions appear** — two sources disagree about the state of the system
3. **Current hypothesis was rejected** — before forming a new one, review all evidence holistically
4. **Investigation has 5+ evidence entries** — time to step back and see the pattern

---

## Anti-Patterns

| Anti-Pattern | Fix |
|-------------|-----|
| Forming hypothesis from single source | Synthesize across sources first |
| Ignoring contradictions | Contradictions are the strongest signal — investigate them |
| Narrative that ignores inconvenient evidence | All evidence must be explained, even if it complicates the theory |
| Skipping gap analysis | Missing evidence is as important as present evidence |

---

## Integration with Investigation State

After synthesis:

1. **Update `nextSteps`** with specific queries to fill evidence gaps
2. **Form new hypothesis** based on the diagnostic narrative
3. **Log the synthesis** as an evidence entry with source `synthesis` and the narrative as the finding
4. **Write JSON** via atomic write to persist the updated state

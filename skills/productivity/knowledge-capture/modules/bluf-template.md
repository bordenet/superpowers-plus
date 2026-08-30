# Module: BLUF article template

Load before Phase 3 (drafting).

BLUF = bottom line up front. A reader who stops after the first two sentences
should still have the single most useful takeaway.

## Structure

```markdown
# <Title: the topic, as a reader would search for it>

## Bottom Line

<1-2 sentences. The decision, the mechanism, or the "what you need to know"
stated plainly. No preamble.>

## Background

<Why this exists, who owns it, where it sits. 1-2 short paragraphs.>

## How It Works

<The mechanism. Steps, components, or flow. Use a numbered list or a small
table. Concrete names, not "the system".>

## Failure Modes

| Symptom | Cause | Recovery |
|---------|-------|----------|
| ... | ... | ... |

## Common Mistakes

<Optional. What newcomers get wrong.>

## References

- <source doc / dashboard / code path / ticket>

## Source Notes (appendix)

<Provenance for every non-obvious claim: `[sme-stated]` or `[inferred]`, with
the interview-log entry number. This is the ONLY place provenance tags appear —
never inline in the article body.>
```

## Rules

- No marketing language, no "in today's fast-paced world" openers.
- Every claim in the body traces to a Source Notes entry or a linked reference.
- Provenance tags live in the appendix only.

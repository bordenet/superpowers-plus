# Evidence Challenge Pass

> **Purpose:** Shared anti-fabrication technique for any skill that synthesizes a document from a
> transcript, interview, recording, or other source text.
> **Used by:** Any synthesis-style skill producing a summary, report, or debrief from raw source material —
> reference this file rather than re-deriving the rule locally. No skill in this repo currently does; this
> is forward-positioned for a synthesis-style skill (e.g. meeting notes, interview debriefs) to adopt.
> **Related:** `evidence-schema.md` (structured evidence for forked-debugging investigators — codebase/infra
> artifacts, not transcript-sourced claims). This file addresses the narrower, complementary case of claims
> drawn from spoken or written source text.

## The Rule

Before delivering any document synthesized from a transcript or similar source, walk every factual or
evaluative claim in the draft and do one of two things:

1. **Cite it** — point to the exact sentence, quote, or timestamp in the source that supports the claim.
2. **Delete it** — if no specific source line supports it, remove the claim rather than keep it as
   plausible-sounding filler.

A claim that "sounds right" because it's a reasonable inference is not the same as a claim the source
actually made. Only the latter survives this pass.

## Voice Preservation

When a source uses its own evaluative language — a judgment, a rating, a strong opinion — preserve that
language rather than paraphrasing it into something blander or more hedged. Paraphrasing a source's own
assessment away is a subtle form of the same fabrication problem: the synthesized document ends up asserting
something in the AI's voice that the source never actually said in those terms, even if the general gist
survives. Quote or closely paraphrase the source's own words for anything evaluative; reserve free paraphrase
for purely factual, non-evaluative content.

## Why This Matters

Synthesis-from-transcript work is uniquely prone to a specific failure mode: the summary reads fluently and
plausibly, so a reader has no natural signal that a given sentence is invented rather than sourced. Unlike
code (which can be tested) or metrics (which can be measured against a baseline), a synthesized narrative's
only check is manual traceability back to the source — which is exactly what this pass forces before the
document ships.

## Procedure

1. Draft the synthesis normally.
2. Before presenting it, re-read every sentence that makes a claim about what was said, decided, observed,
   or concluded.
3. For each such sentence, locate the specific source line it traces to. If found, optionally add an inline
   citation (timestamp, quote, or line reference) for traceability.
4. If no source line supports it, delete the sentence — do not soften it into a hedge ("it seems that...",
   "possibly...") as a substitute for removal. A hedged fabrication is still a fabrication.
5. Re-read the full document once more after deletions to confirm it still reads coherently; a synthesis with
   several claims removed may need light structural adjustment, not just silent gaps.

## Failure Modes

| Failure | Fix |
|---------|-----|
| Claim sounds plausible so it's kept without checking | Every claim gets challenged, not just claims that already look uncertain |
| Hedging language used to avoid deleting an unsupported claim | Hedging is not a substitute for citation — delete if unsupported |
| Source's own strong/blunt assessment softened in synthesis | Preserve the source's evaluative language; don't launder it into blander AI prose |
| Pass run once at the end, treated as a formality | Run the pass as a genuine adversarial re-read, sentence by sentence, not a skim |

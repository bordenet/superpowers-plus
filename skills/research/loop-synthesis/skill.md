---
name: loop-synthesis
source: superpowers-[product]
description: "Phase 5: Synthesize loop interview into BLUF debrief format. Use when user says 'synthesize loop interview', 'debrief from system design', 'just finished implementation interview', 'process loop transcript'."
triggers: ["synthesize loop interview", "debrief from system design", "just finished implementation interview", "process loop transcript"]
---

# Loop Synthesis

## When to Use

- After completing a loop interview — synthesize transcript into BLUF debrief
- User provides Fathom transcript or says "synthesize loop interview", "debrief from system design"
- Produces handoff-ready debrief document for hiring decision

> **Pipeline:** Phase 5 of 5 (FINAL) | **Next:** Debrief meeting
> **Input:** Fathom transcript + loop-prep doc + session type
> **Output:** BLUF debrief with interview transcript

---

## Before Writing: Load Evidence Standards

```bash
view ~/.codex/modules/evidence-standards.md
```

**This is SYNTHESIS, not PREP.** Do NOT include prep scaffolding.

---

## Citation Standards (NON-NEGOTIABLE)

| Element | Method |
|---------|--------|
| Candidate responses | Verbatim from Fathom + timestamp + speaker verification |
| Interviewer questions | Copy/paste from loop prep doc |
| Observations | `<< Observation: ... >>` format |

**NEVER:** Fabricate recording IDs • Attribute to wrong speaker • Omit timestamps • Paraphrase without marking

---

## Output Structure (BLUF)

1. **Bottom Line Up Front** — Hire? Role? Leveling? Verdict.
2. **Three Points FOR** — transcript evidence + quotes/timestamps
3. **Three Points AGAINST** — specific evidence
4. **Interview Transcript** — chronological, `<< Observation >>` inline
5. **Scoring Summary** — dimensions 1-4 scale
6. **Debrief-Ready Summary** — 3 min read-aloud script
7. **Actions** — verdict, Teams, tracker

See `references/output-template.md` for full template.

### Banned Language

**FOR/AGAINST:** "thoughtful", "genuine", "excellent", "will ramp", "at scale"
**AGAINST:** "no red flags", "should be fine" (absence ≠ evidence)

---

## Verdicts

| Verdict | Next Step |
|---------|-----------|
| HIRE | Debrief → Offer |
| STRONG HIRE | Debrief → Expedited offer |
| NO HIRE | Debrief → Rejection |
| NEVER HIRE | Debrief → Immediate rejection |

## Level Calibration

| Level | System Design | Implementation | Behavioral |
|-------|---------------|----------------|------------|
| L2 Senior | Complete design with tradeoffs | Working code, edge cases | L2 depth on all questions |
| L3 Staff | Novel approaches, scale expertise | Elegant solutions, teaches | Influence beyond team |

---

## Pre-Commit Checklist

- [ ] Every claim tagged (`[resume]`, `[inference]`, `[assessment]`)
- [ ] No banned adjectives or predictions
- [ ] No cross-candidate comparisons
- [ ] Every strength/concern cites transcript evidence
- [ ] Fathom recording ID verified via API

---

## Reference Files

| File | Contents |
|------|----------|
| `references/output-template.md` | Full BLUF template with all sections |

## Failure Modes & Recovery

- **Incomplete loop coverage**: If only some sessions have transcripts, synthesize available sessions and explicitly list missing ones
- **No-show to one session**: Note the no-show, assess remaining sessions, and flag that the loop is incomplete for decision-making
- **Contradictory session results**: Present each session's evidence independently — never average across sessions

## Cross-References

| Resource | Location |
|----------|----------|
| Evidence Standards | `_shared/evidence-standards.md` |
| Loop Prep | `loop-prep/skill.md` |
| Career Ladder | [wiki](https://wiki.int.[company].net/doc/sr-sde-career-ladder-xMt5Ry9Jwp) |
| Debrief Meetings | [wiki](https://wiki.int.[company].net/doc/interview-de-brief-meetings-W54Bdc0U76) |

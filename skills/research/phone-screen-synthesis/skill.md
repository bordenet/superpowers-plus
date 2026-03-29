---
name: phone-screen-synthesis
source: superpowers-[product]
description: "Phase 3: Synthesize phone screen into BLUF debrief format. TRIGGERS: Fathom transcript provided, 'synthesize phone screen', 'debrief from call', 'create synthesis file'. Transforms transcript into handoff-ready document."
triggers:
  - "Fathom transcript"
  - "fathom.video"
  - "synthesize phone screen"
  - "synthesize the call"
  - "create synthesis"
  - "debrief from call"
  - "process transcript"
  - "just finished phone screen"
  - "__SYNTHESIS.md"
---

# Phone Screen Synthesis

## When to Use

- After completing a phone screen — synthesize Fathom transcript into BLUF debrief
- User provides Fathom transcript URL/text, or says "synthesize phone screen", "debrief from call"
- Transforms transcript into handoff-ready synthesis document

> **Pipeline:** Phase 3 of 5 | **Next:** loop-prep (if HIRE)
> **Input:** Fathom transcript + phone-screen-prep doc
> **Output:** `*__SYNTHESIS.md` (BLUF synthesis with interview transcript)
> **Env:** `$RECRUITING_PHONE_SCREENS_DIR` — run `source ~/.codex/.env`

---

## Trigger: Fathom Transcript = SYNTHESIS

**If user provides a Fathom transcript (URL or text), this skill fires. No exceptions.**

| Signal | Action |
|--------|--------|
| `fathom.video` URL | CREATE `__SYNTHESIS.md` file |
| Transcript text pasted | CREATE `__SYNTHESIS.md` file |
| "just finished call with" | ASK for Fathom link, then CREATE |

**File naming:** `FirstName_LastName__SrSDE__YYYY-MM-DD__SYNTHESIS.md` (the `__SYNTHESIS` suffix is MANDATORY)

**Before writing:** Load evidence standards module: `view ~/.codex/modules/evidence-standards.md`

---

## Citation Standards (NON-NEGOTIABLE)

| Element | Requirement |
|---------|-------------|
| Candidate quotes | Verbatim + timestamp + speaker verification |
| Interviewer quotes | Verbatim + timestamp |
| Observations | `<< Observation: ... >>` format |

**Speaker verification:** CHECK `speaker.display_name` before attributing. Common error: attributing interviewer's words to candidate.

**NEVER:** Invent Fathom recording IDs • Attribute to wrong speaker • Omit timestamps • Present interviewer as candidate

**Recording ID:** Always fetch from API first: `curl -H "X-Api-Key: $FATHOM_API_KEY" "https://api.fathom.ai/external/v1/meetings?limit=30" | jq ...`

---

## Output Structure (BLUF)

1. **Bottom Line Up Front** — Hire for [Company]? Role? Leveling assessment? Verdict.
2. **Three Points FOR** — transcript evidence + quotes/timestamps. Tag `[resume]` if not from call.
3. **Three Points AGAINST** — specific evidence from call.
4. **Areas to Probe in Loop** — gaps + suggested questions.
5. **Interview Transcript** — chronological, `<< Observation >>` inline.
6. **Signal Checklist** — 4 quadrants: Company, Core Skills, Mindset, Behaviors.
7. **Actions** — verdict recorded, Paylocity updated, next steps.

See `references/output-template.md` for full template.

### Banned Language

**In FOR/AGAINST:** "thoughtful", "genuine", "natural", "great", "excellent", "will ramp"
**In AGAINST:** "no red flags", "should be fine", "won't be a problem" (absence ≠ evidence)
**In Evidence:** "fits culture", "good instincts", "will ramp quickly", "at scale" (without metrics)

---

## Transcript Processing

1. Chronological order (call flow, not topic grouping)
2. Quote when impactful, paraphrase routine answers
3. Preserve all interviewer notes
4. Remove scaffolding (no prep scripts, probing menus)
5. `<< Observation >>` for real-time gut reactions — preserve raw voice, don't sanitize

---

## Pre-Commit Checklist

- [ ] Every claim tagged (`[resume]`, `[inference]`, `[assessment]`)
- [ ] No banned adjectives or predictions
- [ ] No cross-candidate comparisons
- [ ] Every strength/concern cites transcript evidence
- [ ] Fathom recording ID verified via API
- [ ] `__SYNTHESIS` suffix in filename

---

## Reference Files

| File | Contents |
|------|----------|
| `references/output-template.md` | Full BLUF template with all sections |
| `_shared/evidence-standards.md` | Source attribution rules (shared module) |

## Example Usage

```bash
source ~/.codex/.env
# Find transcript for synthesis
ls "$RECRUITING_DIR/Phone Screens/" | grep -i "lastname"
```

## Failure Modes & Recovery

- **Transcript too short**: If Fathom transcript is under 5 minutes, flag as potential connection issue — ask user to confirm call actually happened
- **Missing phone screen prep**: If no prep file exists for this candidate, note the gap but proceed with synthesis from transcript alone
- **Ambiguous signals**: When candidate gives contradictory answers, quote both verbatim and flag the contradiction rather than averaging

## Cross-References

| Resource | Location |
|----------|----------|
| Phone Screen Prep | `phone-screen-prep/skill.md` |
| Loop Prep (next) | `loop-prep/skill.md` |
| Four Quadrants | [wiki](https://wiki.int.[company].net/doc/core-behaviors-the-four-quadrants-8d4JNjomwk) |
| Career Ladder | [wiki](https://wiki.int.[company].net/doc/sr-sde-career-ladder-xMt5Ry9Jwp) |

---
name: interview-synthesis
source: superpowers-recruiting
description: Use when an interview is complete and you need to create a debrief, summarize interview notes, or prepare for debrief meeting. Triggers on "create debrief for", "synthesize interview notes", "finalize interview record", "prep my debrief", "what's my recommendation for [candidate]", "just finished interviewing". Produces clean BLUF debrief record from raw notes/transcript.
triggers: ["create debrief for", "synthesize interview notes", "finalize interview record", "prep my debrief", "just finished interviewing"]
---

# Interview Synthesis

> **Pipeline:** `resume-screening → phone-screen-prep → interview-prep → interview-synthesis` ← YOU ARE HERE
> **Wiki:** [Debrief Meetings](https://wiki.int.callbox.net/doc/interview-de-brief-meetings-W54Bdc0U76)
> **Env:** `$RECRUITING_DIR` — run `source ~/.codex/.env`

**Input:** Interview prep sheet + Fathom transcript OR raw notes
**Output:** `$RECRUITING_DIR/Debriefs/{Name}__debrief__{YYYY-MM-DD}.md` (PII — NEVER commit)

---

## Citation Standards (NON-NEGOTIABLE)

| Element | Source | Method |
|---------|--------|--------|
| Interview questions | Interview Sheet | **COPY/PASTE verbatim** |
| Candidate responses | Fathom transcript | **Direct quotes** + timestamps + **SPEAKER VERIFICATION** |
| Interviewer observations | Your notes | Clearly marked `[Interviewer observation]` |

**Source hierarchy:** Question text → Interview Sheet. Response → Fathom transcript. Assessment → Interviewer judgment.

**Speaker verification:** Before attributing ANY quote, CHECK `speaker.display_name` in Fathom transcript JSON. Common error: attributing interviewer's words to candidate.

**NEVER:** Paraphrase questions • Summarize "generally said" • Fabricate Fathom recording IDs • Attribute without verifying speaker

---

## No Scaffolding Rule

Final debrief must contain ONLY observed data:
- ✅ Questions asked (verbatim from Interview Sheet)
- ✅ Candidate responses (direct quotes with timestamps)
- ✅ Interviewer assessment (Signal: ✅/⚠️/❌ + rationale)
- ✅ Signal Checklist, DECISION, Actions

**Exclude:** Probing menus, reference answers, calibration rubrics, "If X then Y" logic, meta-commentary about the interviewer.

---

## Behavioral Coverage Labels

| Label | Meaning |
|-------|---------|
| `✅ ASKED (direct)` | Scripted question asked verbatim |
| `✅ COVERED (indirect)` | Signal emerged organically, interviewer acknowledged |
| `⚠️ PARTIAL` | Some evidence, not fully explored |
| `❌ NOT COVERED` | No evidence in transcript |

**Before marking "NOT COVERED":** Search for indirect signals — see `references/signal-detection.md`.

---

## Decision Guidance

| Decision | When to Use |
|----------|-------------|
| **HIRE** | Meets bar across quadrants, evidence supports success |
| **NO-HIRE** | Gaps in quadrants, insufficient evidence |
| **STRONG-HIRE** | Exceptional across all quadrants (use sparingly) |
| **NEVER-HIRE** | Rude, unprofessional, offensive (extremely rare) |

---

## Synthesis Rules

| Keep | Transform into |
|------|----------------|
| Raw behavioral notes | Top 3 strengths / detractors with quadrant evidence |
| Candidate questions | Verbatim in presentation notes |
| Depth/quality observations | Hire/No-Hire rationale |
| Concerns | Detractor items with specific gaps |

---

## Two Outputs Required

1. **Debrief Presentation (3 min max):** Quadrant focus, top 3 strengths, top 3 detractors, candidate questions
2. **Teams Record:** Decision, level, strengths, detractors, rationale, next steps

See `references/output-templates.md` for full BLUF template and Teams post format.

---

## Example Usage

```bash
source ~/.codex/.env
# Check for existing debrief files
ls "$RECRUITING_DIR/Debriefs/" | grep -i "lastname"
```

## Failure Modes & Recovery

- **No interview prep sheet**: If prep file is missing, synthesize from transcript alone but flag the gap in the debrief
- **Incomplete notes**: If transcript covers only part of the interview, note which sections are missing and avoid rating those competencies
- **Conflicting interviewer signals**: When multiple interviewers disagree, present both views with evidence rather than averaging

## Reference Files

| File | Contents |
|------|----------|
| `references/output-templates.md` | Full BLUF debrief template, Teams post format, deepening probes |
| `references/signal-detection.md` | Indirect signal detection patterns, transcript search patterns |

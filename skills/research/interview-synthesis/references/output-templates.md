# Output Templates

## BLUF Debrief Document

```yaml
---
candidate: [Name]
role: Senior SDE
date: YYYY-MM-DD
document_type: debrief
predecessor: ./Interview Prep/{Name}__interview-prep__YYYY-MM-DD.md
pipeline_position: 4 of 4
decision: [HIRE | NO-HIRE | STRONG-HIRE | NEVER-HIRE]
---
```

```markdown
## 🎯 DECISION (BLUF)

**Recommendation:** [HIRE / NO-HIRE / STRONG-HIRE / NEVER-HIRE]
**Hire for CallBox?** Y / N
**Hire for role?** Y / N

**Rationale:** [1-2 sentences]
**Next Steps:** [Offer / Rejection / Hold / Archive]

---

## Debrief Presentation (3 min max)

**Quadrant focus:** "I covered..." [area]

**Top 3 strengths:**
1. [Quadrant evidence with example]
2. [Quadrant evidence with example]
3. [Quadrant evidence with example]

**Top 3 detractors:**
1. [Gap vs. bar]
2. [Gap vs. bar]
3. [Gap vs. bar]

**Candidate questions:** [What they asked]

---

## [Behavioral Area]
> [STATUS LABEL] — [Question/signal]:
> - [Response quotes/summary]
> **Signal:** [✅/⚠️/❌] [Assessment]

---

## Signal Checklist

| Area | Rating (1-4) | Evidence |
|------|--------------|----------|
| Growth Mindset | | |
| Customer Obsession | | |
| Conflict Management | | |
| Technical Depth | | |
| Communication | | |
```

## Teams Channel Post

```markdown
DECISION: [HIRE / NO-HIRE / STRONG-HIRE / NEVER-HIRE]
LEVEL: [Confirmed level or concerns]

TOP STRENGTHS:
- [Quadrant evidence #1]
- [Quadrant evidence #2]
- [Quadrant evidence #3]

TOP DETRACTORS:
- [Gap vs. bar #1]
- [Gap vs. bar #2]
- [Gap vs. bar #3]

RATIONALE: [1-2 sentences]
NEXT STEPS: [Offer / Rejection / Hold / Archive]
```

## Citation Format

**Questions:** `> ✅ **ASKED** — "[Exact text from Interview Sheet]"`

**Responses:**
```markdown
**Response:** [Summary]
**Quote:** "[Verbatim from Fathom]" *(timestamp)*
```

## Deepening Probes (Reference)

| Probe | Purpose |
|-------|---------|
| "What did that cost?" | Stakes and consequences |
| "What would you do differently?" | Learning and growth |
| "How did the other person experience that?" | Empathy |
| "What was the hardest part?" | Past rehearsed answers |
| "What did you learn about yourself?" | Self-awareness |
| "How did that change how you operate?" | Lasting impact |

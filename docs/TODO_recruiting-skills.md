# TODO: Recruiting Skills Enhancement

> **Source PRD**: [PRD_recruiting-skills-enhancement.md](./PRD_recruiting-skills-enhancement.md)
> **Created**: 2026-02-01

## Summary

Gap analysis between current `resume-screening` and `phone-screen-prep` skills and best-practices identified in PRD.

---

## resume-screening Gaps

### P0 — Critical

| # | Gap | Current State | Required State | Lines |
|---|-----|---------------|----------------|-------|
| RS-1 | **Contractor penalty too harsh** | Flat -25 to -35 pts for consecutive contracts (L108-146) | Context-aware scoring: long-term = positive, specialist = neutral, short gigs = minor penalty | 108-146 |
| RS-2 | **No credibility positive signals** | Only red flags (weaknesses); no positive evidence tracking | Add positive signals: quantified achievements, technical depth progression, learning from failures | Throughout |
| RS-3 | **AI detection binary** | Binary "detect slop → reject" (L230-274) | Distinguish AI-assisted polish (no penalty) from AI-fabricated content (flag for verification) | 230-274 |

### P1 — High

| # | Gap | Current State | Required State | Lines |
|---|-----|---------------|----------------|-------|
| RS-4 | **No complexity/depth guidance** | Experience evaluated by years only | Add complexity assessment: scale of systems, architectural decisions, trade-off evidence | Pass Matrix |
| RS-5 | **No bias audit checklist** | No explicit bias warnings | Add bias audit section: contractor, gap, pedigree, education bias warnings | New section |
| RS-6 | **Questions not STAR format** | Questions phrased as "walk me through" or direct | Convert to STAR behavioral format with mandatory follow-ups | 335-339 |

### P2 — Medium

| # | Gap | Current State | Required State | Lines |
|---|-----|---------------|----------------|-------|
| RS-7 | **No probing depth calibration** | All concerns treated equally | Match question depth to severity (minor/moderate/serious) | Flags section |
| RS-8 | **No credibility score output** | Output shows flags only | Add "Credibility Assessment" section with positive signals + concerns + score | Output Format |

---

## phone-screen-prep Gaps

### P0 — Critical

| # | Gap | Current State | Required State | Lines |
|---|-----|---------------|----------------|-------|
| PS-1 | **No STAR question format** | Generic question templates (L109-122) | All questions use STAR format: Situation→Task→Action→Result with mandatory follow-ups | 109-122 |
| PS-2 | **No interview rubric** | No competency scoring guidance | Add 6-competency rubric with behavioral anchors: Technical Depth, Systems Thinking, Problem-Solving, Communication, Leadership, Learning Agility | New section |
| PS-3 | **No timing structure** | No timing recommendations | Add 35-40 min structure: intro (5-10), trajectory (8-10), competency (15-20), candidate Qs (5), close (2) | New section |

### P1 — High

| # | Gap | Current State | Required State | Lines |
|---|-----|---------------|----------------|-------|
| PS-4 | **No probing depth calibration** | Same question depth for all concerns | Match probing depth to concern severity | Common Concerns |
| PS-5 | **No role-specific profiles** | Single approach for all senior roles | Add role profiles: IC Depth, Team Lead, Cross-Functional with different competency weights | New section |
| PS-6 | **No contractor assessment protocol** | Uses resume-screening contractor flags | Add contractor-specific STAR questions and pattern decoder | New section |

### P2 — Medium

| # | Gap | Current State | Required State | Lines |
|---|-----|---------------|----------------|-------|
| PS-7 | **No accessibility options** | Assumes phone screen format | Add accommodation options: phone/video/text, extended time, questions in advance | New section |
| PS-8 | **No bias audit checklist** | No explicit bias guidance for interviewer | Add interviewer bias checklist | New section |

---

## Implementation Order

### Phase 1: Core STAR & Rubric (Highest Impact)

1. **PS-1**: Convert phone-screen-prep questions to STAR format
2. **PS-2**: Add interview rubric with behavioral anchors
3. **RS-6**: Convert resume-screening questions to STAR format
4. **PS-3**: Add timing structure

### Phase 2: Contractor & Credibility (Fairness)

5. **RS-1**: Refactor contractor evaluation to context-aware scoring
6. **RS-2**: Add credibility positive signals
7. **PS-6**: Add contractor assessment protocol
8. **RS-3**: Refine AI detection to distinguish polish vs fabrication

### Phase 3: Calibration & Bias (Quality)

9. **RS-5**: Add bias audit checklist to resume-screening
10. **PS-8**: Add bias audit checklist to phone-screen-prep
11. **RS-7**: Add probing depth calibration
12. **PS-4**: Add probing depth calibration

### Phase 4: Role Profiles & Accessibility (Polish)

13. **PS-5**: Add role-specific assessment profiles
14. **PS-7**: Add accessibility options
15. **RS-4**: Add complexity/depth guidance
16. **RS-8**: Add credibility score output

---

## Estimated LOC Changes

| Skill | Current Lines | Estimated New Lines | Net Change |
|-------|---------------|---------------------|------------|
| resume-screening/SKILL.md | 480 | +150 | ~630 |
| phone-screen-prep/SKILL.md | 164 | +200 | ~365 |

---

## Validation Criteria

After implementation, run sample resumes through tools and verify:

- [ ] All generated questions use STAR format
- [ ] Contractor evaluation shows context-aware scoring (not flat penalty)
- [ ] Credibility assessment includes positive signals
- [ ] AI detection distinguishes polish from fabrication
- [ ] Interview rubric covers all 6 competencies with behavioral anchors
- [ ] Timing structure is included in phone screen notes
- [ ] Bias audit checklist is present


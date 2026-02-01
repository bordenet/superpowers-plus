# PRD: Recruiting Skills Enhancement

> **Parent Document**: [Vision_PRD.md](./Vision_PRD.md)
> **Related Skills**: `resume-screening`, `phone-screen-prep`, `detecting-ai-slop`
> **Guidelines**: [CLAUDE.md](../CLAUDE.md)
> **Research Date**: 2026-02-01

## 1. Executive Summary

This PRD defines enhancements to the `resume-screening` and `phone-screen-prep` skills based on comprehensive research from Perplexity.ai covering state-of-the-art technical hiring practices, bias mitigation, AI-assisted hiring tools, and structured interview methodology.

**Key Finding**: Unstructured employment interviews have only ~57% predictive validity (marginally better than coin flip). Structured approaches with explicit criteria show significantly higher correlation with job performance.

## 2. Problem Statement

### Current Limitations

1. **Resume Screening**:
   - Contractor pattern penalty may introduce bias against protected groups
   - AI slop detection is binary rather than nuanced (assisted vs. fabricated)
   - Credibility assessment focuses on red flags rather than capability evidence
   - Limited guidance on evaluating depth vs. breadth of experience

2. **Phone Screen Prep**:
   - Questions lack STAR (Situation, Task, Action, Result) behavioral framing
   - No interview rubric or scoring guidance
   - Missing calibration between "PROBE" concerns and question depth
   - No structured timing recommendations

### Research-Backed Insights

| Finding | Source | Implication |
|---------|--------|-------------|
| Resume screening when done poorly is most damaging point in recruitment | Perplexity Research | Shift from "hunt for weaknesses" to "identify capability" |
| Top performers have more failures in background | Research | Employment gaps/failures may indicate ambition |
| STAR behavioral questions outperform hypotheticals | Interview research | Reframe question generation |
| 79% candidates want AI transparency | Surveys | Disclosure vs. disqualification |
| Contractor bias correlates with demographic discrimination | Legal research | Audit contractor penalty |

## 3. Goals & Success Criteria

### Goals

| # | Goal | Metric |
|---|------|--------|
| G1 | Reduce false negatives (rejecting qualified candidates) | Track "PROBE" → "HIRE" conversion |
| G2 | Improve phone screen question predictiveness | STAR-formatted questions |
| G3 | Add structured interview rubrics | Rubric coverage for all competencies |
| G4 | Mitigate bias in contractor evaluation | Nuanced scoring, not binary penalty |
| G5 | Distinguish AI-assisted writing from fabrication | Credibility signals over polish detection |

### Success Criteria

- [ ] All phone screen questions use STAR behavioral format
- [ ] Interview rubric covers 6 senior engineer competencies
- [ ] Contractor evaluation uses context-aware scoring (not flat penalty)
- [ ] AI detection distinguishes "polished" vs "fabricated" content
- [ ] Credibility assessment includes positive signals, not just flags

## 4. Current State Analysis

### 4.1 resume-screening SKILL.md (480 lines)

**Strengths**:
- Comprehensive 100-point scoring system
- Integration with `detecting-ai-slop` skill
- GitHub verification workflow
- Clear BLUF output format

**Gaps Identified**:
- Lines 108-146: Contractor penalty too harsh (-35 pts max)
- Lines 230-274: AI slop detection doesn't distinguish assisted vs. fabricated
- No positive credibility signals (only red flags)
- Experience evaluation lacks complexity/depth guidance

### 4.2 phone-screen-prep SKILL.md (164 lines)

**Strengths**:
- Integration with resume screening concerns
- Template-based workflow
- File naming conventions

**Gaps Identified**:
- Lines 110-122: Questions lack STAR format
- No interview rubric or competency definitions
- No timing recommendations (research: 35-40 min optimal)
- Missing calibration levels for probing depth

## 5. Proposed Enhancements

### 5.1 Resume Screening Enhancements

#### FR1: Credibility Assessment Framework

Replace "hunt for weaknesses" with balanced assessment:

**Positive Signals** (NEW):
- Quantified achievements with plausible metrics
- Technical depth progression across roles
- Specific implementation details (not generic language)
- Consistent narrative across resume/LinkedIn/GitHub
- Evidence of learning from failures

**Credibility Flags** (refined from red flags):
- Implausible quantitative claims (e.g., "50% improvement across entire system")
- Generic language lacking specificity
- Mismatch between title/tenure and described complexity
- Inconsistency across available sources

#### FR2: Nuanced Contractor Evaluation

Replace binary penalty with contextual assessment:

| Contractor Pattern | Old Penalty | New Assessment |
|-------------------|-------------|----------------|
| 3+ consecutive contractor roles | -35 pts | Probe motivation & depth |
| Long-term contractor (2+ years same client) | -35 pts | +5 pts (demonstrates value retention) |
| Specialist consultant (infrastructure/security) | -35 pts | Neutral to positive |
| Short gigs (<3 months) | -35 pts | -10 pts (limited depth evidence) |

**Evaluation Criteria**:
1. Did contractor solve substantive problems?
2. Engagement long enough for genuine expertise (3+ months)?
3. Verifiable outcomes or references?
4. Why interested in FTE now?

#### FR3: AI Content Credibility Assessment

Distinguish between:

| Category | Detection | Action |
|----------|-----------|--------|
| AI-assisted polish | Smooth writing, few typos | No penalty |
| AI-optimized keywords | ATS optimization | No penalty |
| AI-fabricated content | Generic claims, implausible metrics, hollow specificity | Flag for verification |
| AI-inflated complexity | Junior claiming senior-level work | Red flag |

**Credibility over Polish**: Focus on verifiability, not linguistic perfection.

### 5.2 Phone Screen Prep Enhancements

#### FR4: STAR-Formatted Question Generation

Transform current question format:

**Before** (current):
```
"[Most critical flag — phrase as direct question]"
```

**After** (STAR behavioral):
```
"Tell me about a time when [situation related to concern].
What was the [task/challenge]? What [action] did you take?
What was the [result]?"
```

**Question Bank by Competency**:

| Competency | Example STAR Question |
|------------|----------------------|
| Technical Depth | "Tell me about a particularly difficult bug you debugged. What made it hard, and how did you identify the root cause?" |
| Systems Thinking | "Describe a time you had to choose between technical approaches with significant trade-offs. What were the options and constraints?" |
| Leadership/Influence | "Tell me about when you had to get a change adopted when stakeholders disagreed. How did you approach it?" |
| Learning from Failure | "Tell me about a project that didn't go as planned. What went wrong and what did you learn?" |

#### FR5: Interview Rubric System

Add structured rubric for senior engineer competencies:

**Competency Definitions** (from research):

| Competency | Strong | Adequate | Weak |
|------------|--------|----------|------|
| Technical Depth | Demonstrates mastery in relevant domains; explains trade-offs clearly | Shows solid understanding; some depth gaps | Surface knowledge; cannot explain decisions |
| Systems Thinking | Considers scalability, ops, trade-offs proactively | Addresses when prompted | Focuses narrowly on feature implementation |
| Problem-Solving | Systematic methodology; explains reasoning | Generally structured approach | Trial-and-error; no clear method |
| Communication | Explains complex concepts clearly | Adequate clarity | Confusing; cannot simplify |
| Leadership/Influence | Evidence of gaining buy-in; driving decisions | Some influence examples | Defers to authority; no initiative |
| Learning Agility | Clear examples of growth from failures | Some learning examples | Defensive about mistakes |

#### FR6: Structured Timing Recommendations

**Optimal Phone Screen Structure** (35-40 minutes):

| Phase | Duration | Focus |
|-------|----------|-------|
| Introduction & Context | 5-10 min | Role overview, mutual interest |
| Career Trajectory | 8-10 min | Why transitions, what drew them |
| Targeted Competency Assessment | 15-20 min | STAR questions on concerns |
| Candidate Questions | 5 min | Their questions about role/team |
| Next Steps | 2 min | Timeline and process |

#### FR7: Probing Depth Calibration

Match question depth to concern severity:

| Concern Level | Probing Approach |
|---------------|-----------------|
| Minor (yellow flag) | Single STAR question; accept reasonable explanation |
| Moderate (orange flag) | 2-3 follow-up questions; seek specific examples |
| Serious (red flag) | Deep dive with verification requests; ask for references |

### 5.3 Bias Mitigation Features

#### FR8: Bias Audit Checklist

Add to both skills:

- [ ] Contractor evaluation uses context, not binary penalty
- [ ] Employment gaps evaluated for circumstance, not commitment
- [ ] Education evaluated for relevance, not prestige
- [ ] Name/demographic info not influencing evaluation
- [ ] Focus on capability evidence, not "cultural fit"

#### FR9: Pedigree Bias Warning

Flag when evaluation over-weights:
- University prestige vs. demonstrated capability
- FAANG background vs. actual accomplishments
- Recent employer vs. career trajectory

## 6. Technical Architecture

### 6.1 Skill Dependencies

```
resume-screening
├── detecting-ai-slop (for content authenticity)
├── credibility-assessment (NEW sub-module)
└── contractor-context-evaluator (NEW sub-module)

phone-screen-prep
├── resume-screening (for concerns)
├── star-question-generator (NEW sub-module)
├── interview-rubric (NEW sub-module)
└── timing-guide (NEW sub-module)
```

### 6.2 Output Format Changes

**resume-screening Output** (enhanced):

```markdown
## HIRE | NO HIRE | PROBE

---

## Credibility Assessment
**Positive Signals**: [List evidence of genuine capability]
**Concerns**: [List items requiring verification]
**Credibility Score**: [High/Medium/Low]

## Phone Screen Questions
1. "[STAR-formatted question targeting concern #1]"
2. "[STAR-formatted question targeting concern #2]"
...

## Rationale
[2-3 sentences explaining the decision]

## Supporting Evidence
**Experience:** [X years] — [Company trajectory]
**Contractor Context:** [If applicable — contextualized assessment]
**Salary:** $[X]k [✓ in range / ✗ over cap]
**GitHub:** [URL or N/A]
**AI Content:** [Polished/Fabrication concerns/None detected]

## Flags
| Flag | Severity | Probing Depth |
|------|----------|---------------|
```

**phone-screen-prep Output** (enhanced):

```markdown
## Phone Screen Notes: [Candidate Name]

### Interview Structure (35-40 min)
- [ ] Introduction (5-10 min)
- [ ] Career Trajectory (8-10 min)
- [ ] Competency Assessment (15-20 min)
- [ ] Candidate Questions (5 min)
- [ ] Next Steps (2 min)

### Screening Concerns — Targeted STAR Questions

| Concern | Severity | STAR Question | Rubric |
|---------|----------|---------------|--------|
| [Concern 1] | [Minor/Moderate/Serious] | "Tell me about a time..." | [Competency] |

### Interview Rubric

| Competency | Rating (1-5) | Notes |
|------------|--------------|-------|
| Technical Depth | | |
| Systems Thinking | | |
| Problem-Solving | | |
| Communication | | |
| Leadership/Influence | | |
| Learning Agility | | |

### Recommendation
[ ] Advance to technical interview
[ ] Reject — concerns not addressed
[ ] Hold — need additional information
```

## 7. Validation Plan

### 7.1 Internal Testing

1. **Retrospective Analysis**: Run enhanced skills on past candidate resumes with known outcomes
2. **Bias Audit**: Check if contractor/gap penalties correlate with demographics
3. **Question Quality**: Validate STAR questions address actual concerns

### 7.2 Sample Application Testing

1. Harvest 5-10 sample resumes from public sources (Perplexity research)
2. Run through enhanced `resume-screening`
3. Generate `phone-screen-prep` notes
4. Evaluate output quality and appropriateness

### 7.3 Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| STAR question coverage | 100% | All generated questions use STAR format |
| Contractor context usage | 100% | All contractor evaluations use contextual scoring |
| Credibility signals | ≥2 per candidate | Positive signals identified |
| Rubric completeness | 6/6 competencies | All competencies have rating guidance |

## 8. Implementation Priority

| Priority | Enhancement | Effort |
|----------|-------------|--------|
| P0 | STAR question format (FR4) | Low |
| P0 | Interview rubric (FR5) | Medium |
| P1 | Nuanced contractor evaluation (FR2) | Medium |
| P1 | Credibility assessment framework (FR1) | Medium |
| P2 | AI content credibility (FR3) | Low |
| P2 | Timing recommendations (FR6) | Low |
| P3 | Bias audit checklist (FR8) | Low |
| P3 | Probing depth calibration (FR7) | Low |

## 9. Perplexity Review Feedback (Incorporated)

Based on comprehensive Perplexity review, the following critical gaps were identified and addressed:

### Gap 1: Observable Behavioral Anchors

**Problem**: Rubric names competencies without specifying observable behaviors.
**Solution**: Added 4-level behavioral rubrics (Strong Yes/Yes/Mixed/No) for each competency.

**Example - Technical Depth Behavioral Anchors**:

| Rating | Observable Behaviors |
|--------|---------------------|
| Strong Yes | Explains architectural decisions at multiple abstraction levels; identifies trade-offs and constraints proactively; articulates why choices made sense at the time even if different now |
| Yes | Explains technical choices with rationale; addresses trade-off questions when prompted |
| Mixed | Describes choices but struggles with trade-offs; vague explanations |
| No | Cannot explain choices coherently; describes implementation without design understanding |

**Example - Learning Agility Behavioral Anchors**:

| Rating | Observable Behaviors |
|--------|---------------------|
| Strong Yes | Describes specific learning from failure; explains behavioral changes implemented; shows pattern of applying lessons across subsequent situations |
| Yes | Identifies lessons learned; some evidence of behavioral change |
| Mixed | Generic lessons; unclear if behavior actually changed |
| No | Defensive about failures; no evidence of learning or growth |

### Gap 2: Role-Specific Assessment Profiles

**Problem**: Single rubric for all senior roles ignores different capability requirements.
**Solution**: Added role-specific competency weighting.

**Role Profile Examples**:

| Role Type | High Priority (40%) | Medium Priority (35%) | Supporting (25%) |
|-----------|--------------------|-----------------------|------------------|
| IC Depth (Staff/Principal) | Technical Depth, Systems Thinking | Problem-Solving, Learning Agility | Leadership, Communication |
| Team Lead | Leadership, Communication | Technical Depth, Systems Thinking | Problem-Solving, Learning Agility |
| Cross-Functional | Communication, Learning Agility | Systems Thinking, Leadership | Technical Depth, Problem-Solving |

### Gap 3: Legal/Compliance Framework

**Problem**: AI credibility assessment lacks regulatory compliance guidance.
**Solution**: Added compliance requirements.

**AI Hiring Compliance Checklist**:
- [ ] Annual bias audits (NYC Local Law 144)
- [ ] Impact assessments for high-risk AI systems (Colorado AI Act)
- [ ] Data collection and retention policies documented
- [ ] Candidate consent and opt-out procedures
- [ ] Transparency disclosures about AI use in hiring
- [ ] Human-in-the-loop for all final decisions

### Gap 4: Accessibility & Inclusion

**Problem**: Process assumes all candidates have same communication preferences.
**Solution**: Added accommodation protocols.

**Accommodation Options**:
- Phone, video, or text-based screen options
- Extended time upon request
- Interview questions provided in advance (for certain disabilities)
- Interpreter availability
- Diverse interviewer representation upon request

### Gap 5: Interviewer Calibration Protocols

**Problem**: Rubric without calibration produces inconsistent ratings.
**Solution**: Added calibration requirements.

**Calibration Protocol**:
1. Monthly: Interviewers jointly rate sample responses using rubric
2. Quarterly: Review hiring outcomes vs. interview assessments
3. Annual: Full bias audit tracking pass-through rates by demographic
4. Per-role: Establish minimum acceptable scores per competency

### Gap 6: Refined STAR Questions with Follow-ups

**Enhanced Technical Depth Question**:
```
"Tell me about a particularly difficult technical problem—bug, performance issue,
or design flaw—that you debugged. What made it hard to diagnose, and walk me
through how you approached solving it. What did you learn, and how did it change
how you approach similar problems in the future?"
```

**Mandatory Follow-ups**:
- "Walk me through a decision you made in that situation. What would you do differently?"
- "Have you encountered similar situations since? How did you handle them differently?"
- "What did the team learn vs. what did you personally learn?"

### Gap 7: Contractor Career Assessment Protocol

**Enhanced Contractor Evaluation Questions**:
1. "Describe the scope and technical depth of a recent contract engagement" (doesn't require confidential details)
2. "How did you continue learning and maintaining skills while contracting?"
3. "What drew you to contract work, and what draws you to FTE now?"

**Contractor Pattern Decoder**:
| Pattern | Signal | Assessment |
|---------|--------|------------|
| 5+ years same client | Deep expertise, client retention | Positive |
| 5 different clients, 1 year each | Breadth, adaptability | Neutral—probe depth |
| Short gigs (<3 months) | Limited depth opportunity | Probe learning |
| Contractor by choice | Flexibility preference | Neutral |
| Contractor by necessity | Market positioning | Probe carefully |

## 10. References

- Perplexity Research: Technical Hiring Best Practices (2026-02-01)
- Perplexity Review: PRD Feedback & Gap Analysis (2026-02-01)
- Tech Interview Handbook: Resume Guidelines
- EEOC: AI Bias in Hiring Guidance
- Research: Structured Interview Predictive Validity
- GPTZero: AI Content Detection Methodology
- NYC Local Law 144: AI Hiring Audits
- Colorado AI Act: High-Risk AI Systems
- Karat: Interview Engineering Rubrics

---

## Appendix A: Research Key Findings

### Predictive Validity

- Unstructured interviews: ~57% (near coin flip)
- Structured interviews: Significantly higher correlation
- STAR behavioral questions > hypothetical scenarios
- Specialized domain expertise > general programming ability

### Contractor Evaluation

- Contractor bias may correlate with demographic discrimination
- Legal: Cannot systematically penalize contractor status
- Many senior contributions come from specialized contractors
- Focus on: substantive work, engagement length, verifiable outcomes

### AI Detection

- GPTZero claims 99% accuracy (with false positive risks)
- Focus on credibility, not polish
- AI-assisted ≠ AI-fabricated
- 79% candidates want transparency about AI use

### Bias Mitigation

- Blind screening reduces name bias
- Structured criteria reduce subjective bias
- Diverse panels reduce group bias
- Data monitoring identifies disparate impact


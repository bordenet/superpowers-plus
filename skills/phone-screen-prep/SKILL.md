---
name: phone-screen-prep
description: "Prepare phone screen notes file from template with targeted questions based on screening concerns."
---

# Phone Screen Prep

> **Guidelines:** See [CLAUDE.md](../../CLAUDE.md) for writing standards.
> **Last Updated:** 2026-02-01
>
> **📋 Screening criteria source:** https://wiki.int.callbox.net/doc/llm-prompt-LfFH19Gj0y
>
> **⚠️ Check for updates daily.** Targeted questions are derived from the canonical screening prompt.

---

## Integration with AI Slop Detection

When resume screening flags high AI slop (bullshit factor >50), add targeted questions to probe authenticity:

| Slop Flag | Phone Screen Question |
|-----------|----------------------|
| Skills list matches JD exactly | "Walk me through a project using [specific skill]. What was the hardest part?" |
| Power verbs without metrics | "You said you 'spearheaded' X. What specifically did you do vs. your team?" |
| Generic bullets | "This bullet says 'improved performance.' Give me the numbers—before/after." |
| ChatGPT clichés | "Your cover letter mentions 'intersection of X and Y.' What specifically attracted you to CallBox?" |

**Add to Screening Concerns section when bullshit factor >50:**

```markdown
### AI-Generated Content Concern
**Bullshit Factor:** [X]/100

**Flag:** [Specific concern from slop analysis]

_"Tell me about [specific claim] in your own words. What were the challenges you faced?"_

_"Walk me through the technical details of [project]. What would you do differently?"_
```

---

---

## 🔗 Cross-References

| Resource | Location | Update When |
|----------|----------|-------------|
| **Phone Screen Template** | `a.People/Recruiting/Phone Screen Notes/_TEMPLATE.md` | Changing interview structure |
| **Phone Screen Guide** | `a.People/Recruiting/Sr Eng Phone Screen Guide.md` | Changing questions or flow |
| **Resume Screening Skill** | `superpowers-skills/resume-screening/skill.md` | Changing what concerns to probe |
| **Completed Phone Screens** | `a.People/Recruiting/Phone Screen Notes/DONE/` | Reference for examples |
| **Wiki LLM Prompt** | [wiki.int.callbox.net](https://wiki.int.callbox.net/doc/llm-prompt-LfFH19Gj0y) | Source of truth for criteria |

### Dependency Chain

```
resume-screening skill (identifies concerns)
       │
       ▼ feeds into
phone-screen-prep skill (THIS FILE — generates targeted questions)
       │
       ▼ copies and customizes
_TEMPLATE.md (master template)
       │
       ▼ creates
Phone Screen Notes/FirstName_LastName__YYYY-MM-DD.md
       │
       ▼ interviewer fills, then pastes back for
LLM Synthesis (produces clean debrief summary)
```

---

## Overview

Creates a phone screen notes file for a candidate, including **targeted questions based on screening concerns** identified from their resume evaluation.

## Invocation

User says one of:
- "Prep phone screen for [First Last]"
- "Create phone screen file for [Name]"
- "Set up interview notes for [Name]"

Include:
- Paylocity URL
- Resume PDF path (for screening concerns)
- LinkedIn URL (optional)
- GitHub URL (optional)

## Workflow

1. **Run resume screening** on the candidate's resume to identify concerns
2. **Copy template** from: `a.People/Recruiting/Phone Screen Notes/_TEMPLATE.md`
3. **Create new file**: `a.People/Recruiting/Phone Screen Notes/FirstName_LastName__YYYY-MM-DD.md`
4. **Replace placeholders**:
   - `[CANDIDATE NAME]` → Candidate's full name
   - `[YYYY-MM-DD]` → Today's date
   - `[Paylocity]()` → `[Paylocity](url)` if provided
   - `[GitHub]()` → `[GitHub](url)` if provided
   - `[LinkedIn]()` → `[LinkedIn](url)` if provided
   - Salary expectation from screening
5. **Add "Screening Concerns — Targeted Questions" section** with:
   - Each concern from the resume screening
   - 1-2 specific questions to probe that concern
   - Placed before the "Why CallBox?" section

## Interview Structure (35-40 minutes)

**Research-backed optimal phone screen structure:**

| Phase | Duration | Focus |
|-------|----------|-------|
| **Introduction & Context** | 5-10 min | Role overview, confirm mutual interest, set expectations |
| **Career Trajectory** | 8-10 min | Understand growth pattern, why senior, transition motivations |
| **Competency Assessment** | 15-20 min | STAR questions targeting 2-3 key concerns from screening |
| **Candidate Questions** | 5 min | Their questions about role/team/company (don't interrupt) |
| **Next Steps** | 2 min | Timeline, process clarity |

---

## 📋 Interview Rubric (6 Competencies)

Rate each competency on phone screen. Use behavioral evidence only.

### Technical Depth

| Rating | Observable Behaviors |
|--------|---------------------|
| **Strong Yes** | Explains architectural decisions at multiple abstraction levels; proactively identifies trade-offs and constraints; articulates why choices made sense at the time |
| **Yes** | Explains technical choices with reasonable rationale; addresses trade-off questions when prompted |
| **Mixed** | Describes choices but struggles with trade-offs; gives vague explanations |
| **No** | Cannot explain choices coherently; describes implementation without design understanding |

### Systems Thinking

| Rating | Observable Behaviors |
|--------|---------------------|
| **Strong Yes** | Considers 3+ dimensions (performance, maintainability, ramp-up time); identifies decision points; reflects on learning |
| **Yes** | Describes 2 main trade-offs; reasonable explanation but doesn't proactively articulate constraints |
| **Mixed** | Struggles to articulate trade-offs; defaults to "we picked the obvious choice" |
| **No** | Cannot identify meaningful trade-offs; single-dimension thinking |

### Problem-Solving

| Rating | Observable Behaviors |
|--------|---------------------|
| **Strong Yes** | Systematic methodology; explains reasoning clearly; generalizes from specific to system-wide |
| **Yes** | Generally structured approach; can walk through reasoning when prompted |
| **Mixed** | Some structure but gaps; trial-and-error elements |
| **No** | No clear method; cannot explain reasoning |

### Communication

| Rating | Observable Behaviors |
|--------|---------------------|
| **Strong Yes** | Explains complex concepts clearly; adjusts detail level appropriately; asks clarifying questions |
| **Yes** | Adequate clarity; can simplify when prompted |
| **Mixed** | Some confusion; difficulty simplifying complex topics |
| **No** | Confusing explanations; cannot simplify |

### Leadership/Influence

| Rating | Observable Behaviors |
|--------|---------------------|
| **Strong Yes** | Evidence of gaining buy-in without authority; driving decisions; examples of persuading skeptical stakeholders |
| **Yes** | Some influence examples; can describe how they've shaped decisions |
| **Mixed** | Limited influence examples; mostly follows established patterns |
| **No** | Defers to authority; no initiative evidence |

### Learning Agility

| Rating | Observable Behaviors |
|--------|---------------------|
| **Strong Yes** | Specific learning from failure; explains behavioral changes; pattern of applying lessons |
| **Yes** | Identifies lessons learned; some evidence of behavioral change |
| **Mixed** | Generic lessons; unclear if behavior actually changed |
| **No** | Defensive about failures; no evidence of learning |

---

## ⚠️ STAR Question Format (Required)

**All questions must use STAR behavioral format:**

```
"Tell me about a time when [SITUATION related to concern].
What was the [TASK/challenge]?
What [ACTION] did you take?
What was the [RESULT]?"
```

**Mandatory follow-ups for each STAR question:**
1. "Walk me through a specific decision you made. What would you do differently?"
2. "Have you encountered similar situations since? How did you handle them differently?"
3. "What did you personally learn vs. what the team learned?"

---

## Targeted Questions Format

```markdown
## ⚠️ Screening Concerns — Targeted Questions

Based on resume screening, probe these specific gaps using STAR format:

### 1. [Concern Area] — [Severity: Minor/Moderate/Serious]
**Concern:** [What the screening identified]
**Competency:** [Which rubric competency this maps to]
**Probing Depth:** [1 question for Minor, 2-3 for Moderate, deep dive for Serious]

_"Tell me about a time when [situation]. What was the challenge? What action did you take? What was the result?"_

**Follow-ups:**
- _"What would you do differently?"_
- _"How has this changed your approach?"_
```

---

## Probing Depth by Severity

| Severity | Probing Approach |
|----------|-----------------|
| **Minor** (Yellow flag) | Single STAR question; accept reasonable explanation |
| **Moderate** (Orange flag) | 2-3 follow-up questions; seek specific examples |
| **Serious** (Red flag) | Deep dive with verification; request references if needed |

---

## Common Concerns → STAR Questions

| Concern | Severity | STAR Question |
|---------|----------|---------------|
| **Frontend-heavy** | Moderate | "Tell me about a time you built a backend system from scratch. What was the challenge? How did you design the data model and handle failure cases? What was the result?" |
| **No IaC** | Minor | "Tell me about a time you automated infrastructure. What was the situation? What tools did you use? What did you learn?" |
| **Weak scale metrics** | Moderate | "Tell me about the highest-traffic system you worked on. What scale challenges did you face? How did you solve them? What were the results?" |
| **Consulting/agency** | Serious | "Tell me about a project you owned end-to-end through multiple release cycles. What was your role? How did you handle long-term maintenance? What did you learn about ownership?" |
| **Short tenure** | Moderate | "Tell me about a time you made a job transition. What drove that decision? What did you learn about what you need from a role?" |
| **No real-time** | Minor | "Tell me about a time you worked with latency-sensitive systems. What was the challenge? How did you approach performance?" |
| **No LLM experience** | Minor | "Tell me about a time you integrated a new technology you hadn't used before. What was the situation? How did you ramp up? What was the result?" |
| **Contractor pattern** | Serious | "Tell me about a project you owned as a contractor. What was your scope? How did you maintain ownership without being FTE? What drew you to contract work, and what draws you to FTE now?" |

---

## Contractor Assessment Protocol

When screening flags contractor concerns, use these specific probes:

**STAR Questions for Contractor Experience:**

1. _"Tell me about the scope and technical depth of a recent contract engagement. What was the situation? What were you responsible for? What did you deliver?"_

2. _"Tell me about a time you had to maintain ownership or accountability without being a permanent team member. What was the challenge? How did you handle it?"_

3. _"Tell me about how you continued learning and maintaining skills while contracting. What was your approach? What did you learn?"_

**Contractor Pattern Decoder:**

| Pattern | Signal | Assessment |
|---------|--------|------------|
| 5+ years same client | Deep expertise, client retention | Positive |
| 5 different clients, 1 year each | Breadth, adaptability | Neutral—probe depth |
| Short gigs (<3 months) | Limited depth opportunity | Probe learning |
| Contractor by choice | Flexibility preference | Neutral |
| Contractor by necessity | Market positioning | Probe carefully |

## NOT Concerns (Do Not Flag)

| Pattern | Why It's Normal |
|---------|-----------------|
| Empty/recent GitHub for big-company engineers | Google, Meta, Amazon, etc. use internal monorepos. Engineers often only create public repos when job hunting or after layoff. This is expected behavior, not a red flag. |
| No public OSS contributions | Many companies have strict IP policies. Lack of public OSS ≠ lack of coding ability. |
| GitHub created recently | Common post-layoff or pre-job-search. Ask for context if curious, but don't treat as suspicious. |

## File Naming Convention

`FirstName_LastName__YYYY-MM-DD.md`

Examples:
- `Daniel_Lee__2026-01-12.md`
- `Shoaib_Beil__2026-01-13.md`

## Template Location

`a.People/Recruiting/Phone Screen Notes/_TEMPLATE.md`

---

## 🎯 Role-Specific Assessment Profiles

Different senior roles require different competency emphasis:

| Role Type | High Priority (40%) | Medium Priority (35%) | Supporting (25%) |
|-----------|--------------------|-----------------------|------------------|
| **IC Depth** (Staff/Principal) | Technical Depth, Systems Thinking | Problem-Solving, Learning Agility | Leadership, Communication |
| **Team Lead** | Leadership, Communication | Technical Depth, Systems Thinking | Problem-Solving, Learning Agility |
| **Cross-Functional** | Communication, Learning Agility | Systems Thinking, Leadership | Technical Depth, Problem-Solving |

**When generating targeted questions, prioritize probing the High Priority competencies for the role type.**

---

## ♿ Accessibility & Accommodation Options

Offer these accommodations when scheduling:

- **Format**: Phone, video, or text-based screen options
- **Time**: Extended time upon request
- **Preparation**: Interview questions provided in advance (for certain disabilities)
- **Support**: Interpreter availability for deaf candidates
- **Representation**: Diverse interviewer options upon request

**Add to scheduling email:**
> "Please let us know if you need any accommodations for this interview. We offer extended time, alternative formats, and other support as needed."

---

## ✅ Interviewer Bias Checklist

Complete before submitting evaluation:

- [ ] I evaluated contractor experience using context, not flat penalty
- [ ] I evaluated employment gaps for circumstance, not as commitment issue
- [ ] I evaluated education for relevance, not prestige
- [ ] I focused on capability evidence, not "cultural fit" impressions
- [ ] I did not over-weight FAANG/pedigree background
- [ ] I asked the same core STAR questions as other candidates for this role
- [ ] I used the behavioral rubric to score, not subjective impression

---

## Output Format (Enhanced)

Generate phone screen notes file with this structure:

```markdown
# Phone Screen Notes: [Candidate Name]

**Date:** [YYYY-MM-DD]
**Interviewer:** [Name]
**Role Type:** [IC Depth / Team Lead / Cross-Functional]

## Interview Structure (35-40 min)
- [ ] Introduction (5-10 min)
- [ ] Career Trajectory (8-10 min)
- [ ] Competency Assessment (15-20 min)
- [ ] Candidate Questions (5 min)
- [ ] Next Steps (2 min)

## ⚠️ Screening Concerns — Targeted STAR Questions

| Concern | Severity | STAR Question | Competency |
|---------|----------|---------------|------------|
| [Concern 1] | [Minor/Moderate/Serious] | "Tell me about a time..." | [Competency] |
| [Concern 2] | [Minor/Moderate/Serious] | "Tell me about a time..." | [Competency] |

### Follow-up Notes
[Space for interviewer to capture answers and follow-ups]

## Interview Rubric

| Competency | Rating (Strong Yes/Yes/Mixed/No) | Behavioral Evidence |
|------------|----------------------------------|---------------------|
| Technical Depth | | |
| Systems Thinking | | |
| Problem-Solving | | |
| Communication | | |
| Leadership/Influence | | |
| Learning Agility | | |

## Bias Checklist
- [ ] Context-aware contractor evaluation
- [ ] Fair gap evaluation
- [ ] Capability over pedigree
- [ ] Same questions as other candidates

## Recommendation
- [ ] **Advance** to technical interview
- [ ] **Reject** — concerns not addressed
- [ ] **Hold** — need additional information

**Rationale:** [2-3 sentences explaining decision with specific behavioral evidence]
```

---

## Workflow Output

1. Confirm file created with full path
2. List the targeted STAR questions added with severity levels
3. Confirm interview structure timing is included
4. Confirm rubric is included
5. Remind user to fill in notes during the call
6. After call, user pastes filled notes and agent synthesizes using LLM prompt at bottom of template

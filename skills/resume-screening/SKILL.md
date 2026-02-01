---
name: resume-screening
description: "Screen Senior SDE candidates against CallBox hiring criteria. Invoke with salary cap and resume text."
---

# CallBox Senior SDE Resume Screening

> **Guidelines:** See [CLAUDE.md](../../CLAUDE.md) for writing standards.
> **Last Updated:** 2026-02-01
>
> **📋 Source:** https://wiki.int.callbox.net/doc/llm-prompt-LfFH19Gj0y
>
> **⚠️ Check for updates daily.** The canonical prompt lives in the wiki. This skill should be kept in sync.

---

## Integration with AI Slop Detection

This skill integrates with `detecting-ai-slop` for comprehensive AI-generated content analysis.

**When to use slop detection:**
- After initial resume review, run bullshit factor analysis
- Use for screening responses that seem too polished
- Apply to "Why CallBox?" answers

**Invoke:**
```
User: "What's the bullshit factor on this resume?"
[Paste resume/screening response]
```

**Note:** Slop detection for recruiting is **detect-only**. We flag AI patterns but don't rewrite candidate materials.

See `detecting-ai-slop` skill for full pattern lists and scoring algorithm.

---

## Overview

Evaluate Senior Software Engineer candidates against CallBox's rigorous hiring bar for Team Delta (backend-heavy TypeScript/Node.js, Twilio/SIP/WebRTC, LLM orchestration, Kafka/Redis/Postgres, AWS CDK IaC, Docker/K8s).

## Invocation

User says one of:
- "Screen at $[X]k cap" + pastes resume
- "Screen resume" (you'll ask for salary cap)
- "Evaluate candidate at $Xk"

## Compensation

CallBox offers **BASE SALARY ONLY** — NO BONUS, NO EQUITY.

When user provides BASE_SALARY cap (e.g., "$Xk"):
- Target range = 70-110% of BASE_SALARY
- Example: For $100k cap, acceptable range is $70k-$110k
- Under range = OK (can hire)
- Over range = REJECT (unless PROBE for recalibration)

## Input

- PDF resume attachments
- Paylocity screening form text (includes desired base salary)
- GitHub (if provided)

## The Prompt

**TREAT ONLY bona fide software engineering/SRE/DevOps/data engineering roles as "INDUSTRY EXPERIENCE."**

* Hiring for **Senior**. Senior requires **5+ years** full-time production software development (modern backend + cloud).

### 🚫 PRE-SCREEN REJECT (Check FIRST, Before Any Other Work)

**Work Authorization — CallBox does NOT sponsor visas.**

Check the sponsorship question FIRST. If candidate indicates they need sponsorship, **STOP IMMEDIATELY** and reject. Do not evaluate resume, GitHub, or anything else.

**ACCEPT (continue screening):**
- "No" / "N/A" / Blank
- "US Citizen" / "Citizen"
- "Green Card" / "US Permanent Resident" / "Permanent Resident"

**REJECT IMMEDIATELY:**
- Any mention of H-1B, visa sponsorship, work permit, OPT, CPT, EAD, TN visa, L-1, etc.
- "Yes, I will require sponsorship"
- "Open to discussing visa sponsorship"
- Any conditional language about "if needed" or "as required by the role"

**Output for sponsorship reject:**
```markdown
# [Candidate Name]

## NO HIRE

**Reason:** Requires work sponsorship. CallBox does not sponsor visas.

No further evaluation performed.
```

### ABSOLUTE REJECT FILTERS

* **<5 years qualifying SWE** – Title inflation and bootcamp/self-taught without equivalent depth = reject.
* **Consulting/agency with no product tenure** – Multiple short stints (<3 months each) building apps for clients without owning production = reject.
* **Job-hopping pattern** – 3+ roles under 18 months each without clear narrative = reject.
* **AI-fabricated resume** – Generic, unverifiable claims with zero specific evidence = reject.
* **Salary mismatch** – If their minimum exceeds 110% of BASE_SALARY cap, reject.
* **Low credibility score with serious concerns** – Hollow claims, fabricated-looking content = reject.

### 🔄 CONTRACTOR/CONSULTANT EVALUATION — CONTEXT-AWARE

**Contractors and consultants require nuanced evaluation, not automatic rejection.**

> **⚠️ BIAS WARNING:** Contractor bias may correlate with demographic discrimination. Many senior engineers choose contract work for flexibility, skill diversity, or portfolio building. Systematic penalization without context is both unfair and potentially discriminatory.

#### Context-Aware Scoring (NOT Flat Penalties)

| Pattern | Signal | Scoring | Action |
|---------|--------|---------|--------|
| **Long-term contractor (2+ years same client)** | Deep expertise, client retention | **+5 pts** | Positive signal |
| **Specialist consultant (infrastructure/security/data)** | Deep domain expertise | **Neutral to +5** | Probe depth |
| **Contract-to-hire that converted** | Company wanted to keep them | **No penalty** | Positive signal |
| **1 contract in otherwise FTE career** | Sometimes makes sense | **No penalty** | Neutral |
| **5 different clients, 1 year each** | Breadth, adaptability | **Neutral** | Probe depth vs breadth |
| **2 consecutive contracts** | May be strategic | **-5 pts** | PROBE: motivation |
| **Short gigs (<3 months)** | Limited depth opportunity | **-10 pts** | PROBE: learning |
| **Contract at unknown company** | Body shop risk | **-5 pts** | PROBE: direct or agency? |

#### Contractor Assessment Questions

Generate these STAR questions when contractor pattern detected:

1. _"Tell me about the scope and technical depth of a recent contract engagement. What was your responsibility? What did you deliver?"_
2. _"Tell me about a time you maintained ownership or accountability without being a permanent team member."_
3. _"What drew you to contract work, and what draws you to FTE now?"_

#### What to Look For (Positive Signals)

- **Substantive work**: Did they solve real problems, not just fill a seat?
- **Engagement length**: 6+ months indicates genuine expertise development
- **Verifiable outcomes**: Can they describe specific deliverables and impact?
- **Strategic choice**: Contractor by choice (flexibility, learning) vs necessity
- **Transition motivation**: Clear reason for wanting FTE now

#### Contractor Pattern Decoder

| Pattern | Interpretation |
|---------|---------------|
| 5+ years same client | Deep expertise, high value to client → Positive |
| Serial 1-year contracts, different domains | Breadth-seeker or difficulty with fit → Probe carefully |
| Contracts after layoff | Common and reasonable → Neutral |
| Contracts only at unknown companies | Body shop risk → Probe quality |
| Mix of FTE + strategic consulting | Deliberate portfolio building → Neutral to Positive |

**Contract detection keywords:** "Contract", "Contractor", "Consulting", "Consultant", "Freelance", "Independent", "Corp-to-Corp", "C2C", "W-2 Contract", "1099"

**When reviewing resumes, ALWAYS note:**
- Total FTE years vs contractor years
- Pattern of contracts (scattered vs consecutive)
- Whether contracts converted to FTE
- Quality of contract clients
- Evidence of depth vs breadth

### PHONE SCREEN FILTERS (Flag, Don't Auto-Reject)

These warrant a phone screen to probe deeper before rejecting:

* **Frontend-heavy presentation** – Resume emphasizes React/Vue/Angular but mentions backend work. Flag for probe: "Walk me through a backend system you built from scratch." Many strong backend devs undersell this on resumes.
* **Vague backend bullets** – "Built APIs", "integrated Stripe" without architecture details. Could be shallow OR just poor resume writing. Probe in screen.
* **No explicit IaC evidence** – Zero CDK/Terraform/CloudFormation/Pulumi mentioned, but has AWS/cloud experience. Flag as gap to probe; don't auto-reject.
* **Salary at edge of range** – If their range overlaps only 10-20% with cap, flag for recalibration conversation rather than auto-reject.

### 🔍 ADDITIONAL PROBE TRIGGERS

These patterns require explicit probe questions. They are NOT auto-reject, but MUST be addressed.

#### 1. Single-Employer Tenure (Big Company Risk)

**Pattern:** 8+ years at one company, especially FAANG/Big Tech (Uber, Google, Meta, Amazon, Microsoft, Netflix, etc.)

**Why it matters:** Big Tech engineers often rely on dedicated infra teams, established tooling, and massive existing systems. At a 15-person startup, you build from scratch with no safety net.

**Auto-generate loop question:**
> "Walk me through building something from zero — no existing tooling, no platform team, no established patterns. How did you make technical decisions without a paved road?"

**In output, add flag:**
> ⚠️ **Single-employer tenure (X years at [Company])** — Probe startup readiness

#### 2. Stack Mismatch (Fungibility Check)

**Pattern:** Resume shows different primary language than our stack (we need TypeScript/Node.js, resume shows Python/Java/Go heavy)

**Why it matters:** We hire FUNGIBLE engineers who can learn quickly. Stack mismatch is NOT a reject — but we need to probe adaptability.

**Auto-generate phone screen question:**
> "Your resume shows mostly [Python/Java/etc.]. How quickly do you typically ramp on new languages/frameworks? Give me an example of learning a new stack on the job."

**Auto-generate loop question:**
> "Walk me through your TypeScript/Node.js experience specifically. How much of your day-to-day has been in our stack vs. [their primary language]?"

**In output, add flag:**
> ⚠️ **Stack mismatch** — Resume shows [X], we need TypeScript/Node.js. Probe fungibility, not rejection.

#### 3. Contribution Ambiguity (Team vs IC)

**Pattern:** Resume bullets use team language without specific IC deliverables:
- "Led initiative to..."
- "Collaborated with cross-functional teams to..."
- "We built..."
- "Drove platform improvements..."

**Why it matters:** At a 15-person company, we need ICs who deliver, not coordinators who facilitate. Team language can hide unclear individual contribution.

**Auto-generate phone screen question:**
> "When you say 'led' or 'we built' — what was YOUR specific contribution? What code did YOU write? What decisions did YOU make?"

**In output, add flag:**
> ⚠️ **Contribution ambiguity** — Resume uses team language. Probe IC deliverables.

#### 4. Strong Candidate Warning (Selling Risk)

**Pattern:** Candidate appears very strong (FAANG, 10+ years, direct domain experience, etc.)

**Why it matters:** Strong candidates cause interviewers to "sell" rather than assess. You get excited and forget to probe weaknesses.

**In output, add explicit warning:**
> ⚠️ **STRONG CANDIDATE — ASSESS, DON'T SELL.** This candidate looks great on paper. Ensure phone screen and loop PROBE weaknesses rather than confirming strengths. Ask the hard questions.

### ⚠️ SKILLS LIST VS WORK HISTORY — Critical Distinction

**Skills lists are often aspirational. Work history is evidence.**

When screening, distinguish between:

| Type | Example | How to Handle |
|------|---------|---------------|
| **EVIDENCED** | "Built Kafka pipeline at Comcast for real-time event streaming" | ✅ Can probe depth: "Walk me through that Kafka architecture" |
| **NOT EVIDENCED** | Skills list says "Kafka, LLM, Telephony" but zero projects mention them | ❌ Flag as concern: "Claims [X] in skills but no work history evidence. Probe if aspirational or real." |

**Red flag for skills inflation:** When a resume lists our exact job requirements (LLM, telephony, real-time, SLIs/SLOs) in the skills section but work history is generic enterprise CRUD, this is often GPT-optimized resume padding.

When generating PROBE questions:
- **DO:** Ask about technologies that appear in job bullets with context
- **DON'T:** Ask detailed questions about skills-list-only claims as if they're proven
- **DO:** Flag skills-list-only claims as concerns to validate: "Is this aspirational or did you build something?"

### ✅ CREDIBILITY ASSESSMENT — POSITIVE SIGNALS

> **Balance evaluation:** Don't just hunt for weaknesses. Actively look for credibility signals.

**Strong Positive Signals (Add to credibility score):**

| Signal | Evidence | Weight |
|--------|----------|--------|
| **Quantified achievements** | Specific metrics: "Reduced p99 latency from 800ms to 120ms" | +15 pts |
| **Technical depth progression** | Moved from feature work → architecture → systems design | +10 pts |
| **Specific implementation details** | Named technologies with context, not just buzzword lists | +10 pts |
| **Learning from failures** | Mentions what went wrong and what they learned | +10 pts |
| **Coherent career narrative** | Clear reason for each transition, growth story | +10 pts |
| **Verifiable claims** | Company names, dates, projects that can be cross-referenced | +5 pts |
| **Admits limitations** | "I haven't used X, but I've done Y which is similar" | +5 pts |
| **Asks specific questions** | Questions about architecture, team, technical decisions | +5 pts |

**Credibility Assessment Output:**
```markdown
## Credibility Assessment

**Positive Signals:** [List specific signals found]
**Concerns:** [List specific concerns]
**Credibility Score:** [High (60+ pts) / Medium (30-59 pts) / Low (<30 pts)]
```

---

### 🔍 AI CONTENT ASSESSMENT — DISTINGUISH POLISH FROM FABRICATION

> **⚠️ CRITICAL DISTINCTION:** AI-assisted polish (no penalty) ≠ AI-fabricated content (flag for verification)

**The Goal:** Detect fabrication and hollow claims, NOT penalize good writing.

#### Three Categories of AI Use

| Category | Example | Action |
|----------|---------|--------|
| **AI-Assisted Polish** | Well-structured sentences, clear formatting, good grammar | **No penalty** — smart tool use |
| **AI-Enhanced Claims** | Buzzwords without substance, perfect structure but hollow content | **Flag for verification** — probe depth |
| **AI-Fabricated Content** | Claims that can't be verified, generic content, zero specifics | **Serious concern** — deep verification |

#### What Matters: VERIFIABILITY, Not Polish

**Evaluate on:**
1. **Can claims be verified?** (Company existed, project shipped, metrics make sense)
2. **Is there substance behind the polish?** (Specific decisions, trade-offs, lessons)
3. **Does depth exist when probed?** (Can they explain the "why" behind choices)

#### Screening Response Red Flags (Flag for Verification, Not Auto-Reject)

| Pattern | Example | Action |
|---------|---------|--------|
| **No specific details** | "I built scalable systems" with no specifics | PROBE: "Walk me through a specific system" |
| **Claims match JD exactly** | Lists our exact stack with no work history evidence | PROBE: "Tell me about your [Kafka/Twilio] work" |
| **Generic company praise** | "CallBox is revolutionizing the industry" | PROBE: "What specifically attracted you?" |
| **Answers all questions identically** | Same structure across all responses | PROBE: "Tell me more about [specific claim]" |
| **ChatGPT clichés** | "Intersection of", "needle in haystack", "passionate about" | NOTE: concern but don't auto-reject |

#### Resume Red Flags (Flag for Verification)

| Pattern | Example | Action |
|---------|---------|--------|
| **Skills list matches JD exactly** | Lists Twilio, WebRTC, Kafka, LLM, CDK | PROBE: depth on each |
| **Power verbs without metrics** | "Spearheaded initiative to improve..." | PROBE: "What specifically?" |
| **Claims expertise in 20+ technologies** | Lists every buzzword | PROBE: "Which 3 are you deepest in?" |

#### What GOOD Content Looks Like (AI-Assisted or Not)

* **Specific and verifiable**: "At Stripe, I debugged a Kafka consumer lag issue by analyzing JMX metrics and discovered our partition strategy..."
* **Admits limitations with context**: "I haven't used WebRTC directly but I've built SIP integrations with Twilio Voice SDK..."
* **Shows personality and opinions**: "I'm skeptical of microservices for small teams—we went monolith-first at my last startup..."
* **Asks specific questions back**: "I noticed CallBox uses CDK—are you using the L2 or L3 constructs for your Twilio integrations?"

#### Scoring (Credibility-Based)

* **High credibility (verifiable claims, depth evident)**: Proceed regardless of polish level
* **Medium credibility (some verifiable, some hollow)**: Proceed with targeted STAR questions
* **Low credibility (generic, unverifiable, hollow)**: Flag serious concerns; deep verification needed
* **Zero specific CallBox research**: Strong concern—shows minimal effort

### PASS MATRIX

**Experience – PASS if:**
* 5+ years **qualifying industry SWE** (product company, startup, or Big Tech).
* Title explicitly states SWE/SDE/Backend/Staff/Principal/SRE.
* 2+ shipped release cycles as individual contributor or tech lead.
* **Contractor experience evaluated in context** — See contractor evaluation section for nuanced scoring.

**Stack Fit – PASS if (TypeScript/Node primary):**
* Backend-heavy production work (Node/TypeScript, Python, Go, Java OK as secondary).
* Real-time systems experience (WebSockets, Socket.io, Twilio, SIP, WebRTC) = strong signal.
* LLM/AI integration (prompt engineering, RAG, tool calling, evals) = strong signal.
* Event-driven architecture (Kafka, RabbitMQ, Redis Pub/Sub) = strong signal.
* IaC fluency (AWS CDK preferred; Terraform, CloudFormation, Pulumi acceptable).
* Containerization + orchestration (Docker, Kubernetes, ECS).

**Scale – PASS if ANY:**
* Tier-1 production metrics cited (DAU, RPS, revenue, latency SLAs).
* Owned system serving >100K users or >1K RPS.
* On-call/incident response experience with postmortems.

**Leadership – PASS if ANY:**
* Led project or team (2+ engineers).
* Mentored junior engineers.
* Drove technical decisions that shipped.

**Salary – PASS if:**
* Their stated range overlaps with 70-110% of BASE_SALARY cap.

### BONUS SIGNALS (Not required, but strong positive indicators)

**GitHub Presence – BONUS if:**
* If candidate provides GitHub link, **GO ASSESS IT**
* Look for: original repos (not just forks), tests, documentation, recent commits
* Strong GitHub can offset resume weaknesses
* Empty/academic-only GitHub is neutral, not negative

**AI-First Workflow – BONUS if:**
* Mentions Claude/Copilot/LLM in their workflow
* Demonstrates AI-assisted development practices

## Output Format

**BOTTOM LINE UP FRONT.** Decision first. Questions second. Evidence last.

We are hiring FUNGIBLE ENGINEERS, not stack-matching code monkeys. Do not over-index on specific technologies. A strong engineer who built Zoom SDK integrations can learn Twilio. Focus on:
- Can they learn new systems?
- Do they have transferable patterns?
- Do they show growth across their career?

```markdown
# [Candidate Name]

## HIRE | NO HIRE | PROBE

---

## Phone Screen Questions (STAR Format)

Use STAR behavioral questions for all flags:

1. **[Critical flag]** — [Severity: Minor/Moderate/Serious]
   _"Tell me about a time when [situation]. What was the challenge? What action did you take? What was the result?"_
   **Follow-up:** _"What would you do differently?"_

2. **[Second flag]** — [Severity]
   _"Tell me about a time when..."_
   **Follow-up:** _"How has this changed your approach?"_

3. **[Third flag if needed]** — [Severity]
   _"Tell me about a time when..."_

---

## Loop Questions (First Interviewer)

1. _"Tell me about a time you built something from zero with no established patterns. What was the situation? How did you make technical decisions? What was the result?"_ (Startup readiness)

2. _"Tell me about a time you had to learn a completely new domain or technology stack. What was the challenge? How did you ramp up? What did you learn?"_ (Learning agility)

3. _"Tell me about a time you influenced a technical decision without formal authority. What was the situation? How did you build consensus? What was the outcome?"_ (Leadership)

---

## Credibility Assessment

**Positive Signals:**
- [Specific verifiable claim 1]
- [Specific verifiable claim 2]

**Concerns:**
- [Specific unverifiable or hollow claim 1]
- [Specific concern 2]

**Credibility Score:** [High (60+ pts) / Medium (30-59 pts) / Low (<30 pts)]

---

## Rationale

[2-3 sentences explaining the decision. Include key strengths and what the flags are. This comes AFTER the questions because the questions are the action items.]

---

## Supporting Evidence

**Experience:** [X years] — [Company trajectory]
**Contractor Assessment:** [Context-aware evaluation — see contractor section]
**Education:** [Degree, school]
**Salary:** $[X]k [✓ in range / ✗ over cap]
**GitHub:** [URL or N/A]

| Screening Answer | Matches Resume? | Verifiable? |
|------------------|-----------------|-------------|
| [Key claim from screening response] | ✓/✗ [Which bullet] | ✓/✗ |
| [Key claim from screening response] | ✓/✗ [Which bullet] | ✓/✗ |

**AI Content Assessment:** [High credibility / Medium — probe depth / Low — verify carefully]

---

## Flags

| Flag | Severity | Probing Depth | STAR Question |
|------|----------|---------------|---------------|
| [Specific concern] | Red/Yellow/Low | [1Q / 2-3Q / Deep dive] | Phone Q# |
| [Specific concern] | Red/Yellow/Low | [1Q / 2-3Q / Deep dive] | Phone Q# |
```

---

## ✅ Bias Audit Checklist (Complete Before Submitting)

> **⚠️ MANDATORY:** Review these before finalizing any candidate evaluation.

- [ ] **Contractor evaluation:** Did I use context-aware scoring, not flat penalties?
- [ ] **Gap evaluation:** Did I evaluate gaps for circumstance, not as commitment issues?
- [ ] **Pedigree bias:** Did I evaluate based on capability evidence, not company prestige?
- [ ] **Education bias:** Did I evaluate education for relevance, not school ranking?
- [ ] **AI content:** Did I distinguish polish from fabrication?
- [ ] **Skills vs evidence:** Did I verify skills-list claims against work history?
- [ ] **Cultural fit:** Did I focus on capability, not "fit" impressions?

**If any checkbox is "No", revise the evaluation before proceeding.**

### Flag Severity Guide

- **Red:** Potential fabrication, title inflation, or disqualifying concern. Must resolve before proceeding.
- **Yellow:** Ambiguous signal that needs clarification. Phone screen should resolve.
- **Low:** Minor gap that a fungible engineer can close. Note but don't over-weight.

### Examples of Red Flags

- Resume claims a level/title that doesn't exist at that company (e.g., "L8 Staff at Amazon")
- Screening answers don't match resume bullets
- Skills list includes our exact JD requirements but zero work history evidence
- Salary expectation 2x+ our cap
- **Low credibility score** with unverifiable claims throughout
- **AI-fabricated content** with generic, hollow claims that can't be probed

### Examples of Yellow Flags

- Short tenure at current role (<12 months)
- Stack experience is adjacent but not exact (e.g., Go instead of Node.js)
- Big company background, unclear if can work scrappy
- Generic "Why CallBox?" answer
- **Multiple short contract gigs** (<3 months each) — probe for learning and depth
- **Medium credibility score** — some claims verifiable, some hollow

### Examples of Low Flags (Don't Over-Weight)

- Uses Terraform instead of CDK (same pattern)
- Has WebRTC but not SIP/Twilio (adjacent domain)
- Python-primary but has Node.js exposure (fungible)

## GitHub Verification — MANDATORY

<CRITICAL>
**ALWAYS check GitHub if a URL is provided.** Do NOT skip this step. Do NOT defer it. Do NOT write "GitHub Check Needed" and move on.

A strong GitHub can salvage a weak resume. A fabricated GitHub URL is a red flag. You MUST verify.
</CRITICAL>

### If No GitHub Provided

If candidate answered "N/A", "NA", left blank, or provided no URL:
- Note "No public GitHub provided" in Supporting Evidence
- Do NOT penalize — many good engineers don't have public repos
- Proceed with resume-only evaluation

### If GitHub URL Provided — VERIFY IMMEDIATELY

**Step 1: Check profile exists**
```bash
curl -s -o /dev/null -w "%{http_code}" https://github.com/USERNAME
```

- **200** = Profile exists → proceed to Step 2
- **404** = Profile does not exist → RED FLAG (fabricated or typo)

**Step 2: Fetch repo list**
```bash
# Use web-fetch on the repositories tab
web-fetch https://github.com/USERNAME?tab=repositories
```

**Step 3: Evaluate repos — FORKS DON'T COUNT**

| What to Look For | Why It Matters |
|------------------|----------------|
| **Original repos** (not forks) | Shows initiative, not just cloning tutorials |
| **Recent commits** (last 6-12 months) | Active developer vs abandoned profile |
| **Backend/systems projects** | Relevant to our stack |
| **Tests, docs, CI config** | Shows engineering maturity |
| **Commit messages** | "fix bug" vs "Refactor auth middleware to handle token refresh" |

| Red Flags | Why |
|-----------|-----|
| All forks, no original repos | No evidence of independent work |
| Only tutorial/bootcamp projects | No production experience signal |
| Empty repos or README-only | Placeholder, not real work |
| Last commit 2+ years ago | Not actively coding |

### GitHub Summary in Output

Add to Supporting Evidence section:

```markdown
**GitHub:** https://github.com/USERNAME
- **Original repos:** X (list names)
- **Forks:** Y (ignore these)
- **Last activity:** [date]
- **Relevant projects:** [list any backend/systems work]
- **Assessment:** [Strong signal / Weak signal / Red flag]
```

## Context Management

- **ALWAYS use fresh chat** for each candidate to prevent context accumulation
- One candidate per chat session
- Candidates who pass proceed to phone screen prep

## Role Summary

**Role:** Backend-heavy TypeScript/Node.js (Twilio/SIP/WebRTC), LLM orchestration, Kafka/Redis/Postgres, AWS CDK IaC, Docker/K8s for CallBox automotive AI voice platform.


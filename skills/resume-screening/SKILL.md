---
name: resume-screening
description: "Screen Senior SDE candidates against CallBox hiring criteria. Invoke with salary cap and resume text."
---

# CallBox Senior SDE Resume Screening

> **📋 Source:** https://wiki.int.callbox.net/doc/llm-prompt-LfFH19Gj0y
>
> **⚠️ Check for updates daily.** The canonical prompt lives in the wiki. This skill should be kept in sync.

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
* **Consulting/agency with no product tenure** – Multiple short stints building apps for clients without owning production = reject.
* **Job-hopping pattern** – 3+ roles under 18 months each without clear narrative = reject.
* **AI-generated slop resume** – Buzzword-heavy, no specifics, claims everything = reject.
* **Salary mismatch** – If their minimum exceeds 110% of BASE_SALARY cap, reject.
* **Chronic contractor pattern** – 3+ consecutive contract roles OR >50% of career as contractor = reject. See below.

### 🚨 CONTRACTOR/CONSULTANT RED FLAG — CRITICAL

**Contractors and consultants are NOT equivalent to full-time product engineers.**

| Pattern | Impact | Action |
|---------|--------|--------|
| **3+ consecutive contract roles** | No ownership, no long-term accountability | **AUTO-REJECT** |
| **>50% of career as contractor** | Never invested in a product/team | **AUTO-REJECT** |
| **2 consecutive contracts** | Yellow flag, needs strong narrative | **PROBE: Why contracts?** |
| **Contract at FAANG/Big Tech** | Often vendor work, not core team | **PROBE: What team? What access?** |
| **"Contract" with no end-client detail** | May be body-shop/staffing agency | **PROBE: Direct or through agency?** |

**Why contractors are risky:**

1. **No ownership** — Contractors deliver features, not outcomes. They don't own on-call, don't own technical debt, don't own production.
2. **No accountability** — When the contract ends, they leave. No incentive to build maintainable systems.
3. **No team investment** — Contractors don't mentor, don't drive culture, don't hire. They're resources, not teammates.
4. **Often excluded from core systems** — Contractors at big companies rarely get access to the most critical/sensitive systems.
5. **Selection bias** — Engineers who CAN get FTE roles at good companies usually DO. Chronic contractors often can't.

**How to score contractor experience:**

| Scenario | Scoring |
|----------|---------|
| 1 contract role in otherwise FTE career | No penalty — sometimes makes sense |
| 2 consecutive contracts | -10 points, probe why in phone screen |
| 3+ consecutive contracts | -25 points minimum, likely reject |
| >50% career as contractor | -30 points, reject unless extraordinary circumstances |
| Contract-to-hire that converted | No penalty — shows company wanted to keep them |
| Contract at unknown company | Additional -5 points (body shop risk) |

**Contract detection keywords:** "Contract", "Contractor", "Consulting", "Consultant", "Freelance", "Independent", "Corp-to-Corp", "C2C", "W-2 Contract", "1099"

**When reviewing resumes, ALWAYS note:**
- Total FTE years vs contractor years
- Pattern of contracts (scattered vs consecutive)
- Whether contracts converted to FTE
- Quality of contract clients (FAANG contractor ≠ unknown startup contractor)

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

### 🚨 AI SLOP DETECTION — BE RUTHLESS

**You have been fooled before. Do NOT be naive.** Candidates use ChatGPT to write screening responses. Detect and reject.

#### Screening Response Red Flags (ANY = strong suspicion, 2+ = reject)

| Pattern | Example | Why It's Slop |
|---------|---------|---------------|
| **"Intersection of X and Y"** | "CallBox sits at the intersection of AI and automotive" | ChatGPT's favorite cliché |
| **"Needle in a haystack"** | "Finding the right role is like finding a needle..." | Overused GPT metaphor |
| **"Passionate about"** | "I'm passionate about building scalable systems" | Empty enthusiasm, no evidence |
| **"Excited to leverage"** | "Excited to leverage my skills to drive innovation" | Corporate word salad |
| **"Aligns with my values"** | "CallBox's mission aligns with my values" | What values? Be specific or it's slop |
| **"Thrilled by the opportunity"** | Any variant of performative excitement | Real engineers don't write like this |
| **"Make a meaningful impact"** | "I want to make a meaningful impact" | Meaningless without specifics |
| **"Dynamic environment"** | "I thrive in dynamic environments" | Every job posting says this |
| **Generic company praise** | "CallBox is revolutionizing the industry" | Did they even research us? |
| **No specific CallBox details** | Response could apply to any company | Copy-paste job |
| **Perfect grammar + zero personality** | Reads like a corporate press release | Real humans have voice |
| **Answers all questions identically** | Same tone/structure across all responses | Batch-generated |

#### Resume Red Flags

| Pattern | Example | Why It's Slop |
|---------|---------|---------------|
| **Skills list matches JD exactly** | Lists Twilio, WebRTC, Kafka, LLM, CDK when those are our exact requirements | GPT resume optimization |
| **"Spearheaded", "Orchestrated", "Architected" overuse** | Every bullet starts with power verbs | Resume generator output |
| **No metrics, all adjectives** | "Built robust, scalable, enterprise-grade solutions" | What did you actually do? |
| **Claims expertise in 20+ technologies** | Lists every buzzword imaginable | Nobody is expert in everything |
| **Bullets that could apply anywhere** | "Collaborated with cross-functional teams" | Generic filler |

#### What GOOD Answers Look Like

* **Specific CallBox reference**: "I read about your Twilio-based voice AI for dealerships and noticed you're using CDK..."
* **Concrete past work**: "At [Company], I debugged a Kafka consumer lag issue by analyzing JMX metrics..."
* **Admits limitations**: "I haven't used WebRTC directly but I've built SIP integrations with..."
* **Shows personality**: Humor, frustration, opinions — real humans have these
* **Asks questions back**: Genuine curiosity about the role/stack

#### Scoring

* **0 red flags**: Proceed normally
* **1 red flag**: Note concern but evaluate holistically
* **2+ red flags**: Strong suspicion of AI-generated response — reject unless resume is exceptional
* **"Why CallBox?" is generic slop**: Automatic NO-HIRE (shows zero research/effort)

### PASS MATRIX

**Experience – PASS if:**
* 5+ years **qualifying industry SWE** (product company, startup, or Big Tech).
* Title explicitly states SWE/SDE/Backend/Staff/Principal/SRE.
* 2+ shipped release cycles as individual contributor or tech lead.
* **Majority FTE tenure** — More than 50% of career as full-time employee, not contractor.

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

## Phone Screen Questions

1. "[Most critical flag — phrase as direct question]"
2. "[Second critical flag]"
3. "[Third flag if needed]"
4. "[Fourth flag if needed]"

---

## Loop Questions (First Interviewer)

1. "[Question that validates startup readiness / scrappy execution]"
2. "[Question that validates growth mindset / learning new domains]"
3. "[Question that validates leadership / mentorship]"

---

## Rationale

[2-3 sentences explaining the decision. Include key strengths and what the flags are. This comes AFTER the questions because the questions are the action items.]

---

## Supporting Evidence

**Experience:** [X years] — [Company trajectory]
**Education:** [Degree, school]
**Salary:** $[X]k [✓ in range / ✗ over cap]
**GitHub:** [URL or N/A]

| Screening Answer | Matches Resume? |
|------------------|-----------------|
| [Key claim from screening response] | ✓/✗ [Which bullet] |
| [Key claim from screening response] | ✓/✗ [Which bullet] |

**AI Slop:** [None detected / Detected — explain]

---

## Flags

| Flag | Severity | Covered By |
|------|----------|------------|
| [Specific concern] | Red/Yellow/Low | Phone Q# |
| [Specific concern] | Red/Yellow/Low | Phone Q# |
```

### Flag Severity Guide

- **Red:** Potential fabrication, title inflation, or disqualifying concern. Must resolve before proceeding.
- **Yellow:** Ambiguous signal that needs clarification. Phone screen should resolve.
- **Low:** Minor gap that a fungible engineer can close. Note but don't over-weight.

### Examples of Red Flags

- Resume claims a level/title that doesn't exist at that company (e.g., "L8 Staff at Amazon")
- Screening answers don't match resume bullets
- Skills list includes our exact JD requirements but zero work history evidence
- Salary expectation 2x+ our cap
- **3+ consecutive contract roles** (no ownership, no accountability)
- **>50% of career as contractor/consultant** (never invested in a product)

### Examples of Yellow Flags

- Short tenure at current role (<12 months)
- Stack experience is adjacent but not exact (e.g., Go instead of Node.js)
- Big company background, unclear if can work scrappy
- Generic "Why CallBox?" answer
- **2 consecutive contract roles** (probe: why contracts? why not FTE?)

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


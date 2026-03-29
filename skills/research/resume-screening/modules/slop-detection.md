# AI Slop Detection Module

> **Load when:** ANY candidate (both direct-apply and recruiter-sourced)
> **Purpose:** Detect AI-generated resume content and screening answers

## What Is Slop?

AI-generated text that sounds professional but lacks substance. GPT-optimized resumes are rampant.

---

## Slop Patterns in Screening Answers

| Pattern | Example | Red Flag Level |
|---------|---------|----------------|
| Generic opener | "I'm excited about this role because..." | 🟡 Medium |
| Buzzword stacking | "intersection of real-time systems, customer engagement, measurable impact" | 🔴 High |
| Mirrors JD exactly | "accelerate product velocity, raise platform reliability" | 🔴 High |
| Too polished, no personality | Every answer perfectly structured | 🟡 Medium |
| No [Company]-specific reference | Generic company praise | 🟡 Medium |
| "Eager to contribute" | Generic enthusiasm | 🟡 Medium |

### High-Confidence Slop Indicators

- "Why [Company]?" answer uses exact JD phrases: "reliable, intelligent, real-time systems"
- Every answer starts with "I" + power verb
- Answers reference technologies not in work history
- Same cadence/structure across all answers

---

## Slop Patterns in Resumes

| Pattern | Example | Red Flag Level |
|---------|---------|----------------|
| Skills match JD exactly | Lists "LLM, telephony, SIP, WebRTC" but no evidence | 🔴 High |
| Power verb stacking | "Spearheaded, Orchestrated, Championed" every bullet | 🟡 Medium |
| Claims 20+ technologies | Nobody is expert in everything | 🔴 High |
| "Collaborated with cross-functional teams" | Generic filler | 🟡 Medium |
| Buzzword-to-evidence ratio > 3:1 | Many claims, few specifics | 🔴 High |

### Skills List vs Work History

**Critical distinction:**
- **EVIDENCED:** "Built Kafka pipeline at Comcast for real-time streaming" → ✅ Probe depth
- **NOT EVIDENCED:** Skills list says "Kafka, LLM" but zero projects mention them → ❌ Flag

When skills section matches our exact JD but work history is generic CRUD → GPT-padded resume.

---

## What GOOD Answers Look Like

| Signal | Example |
|--------|---------|
| Specific company reference | "I read about your Twilio-based voice AI..." |
| Concrete past work | "At [Company], I debugged a Kafka consumer lag issue..." |
| Admits limitations | "I haven't used WebRTC directly but..." |
| Shows personality | Humor, frustration, opinions |
| Specific metrics | "Reduced p99 latency from 800ms to 120ms" |

---

## Scoring Rubric

| Score | Meaning | Action |
|-------|---------|--------|
| **0-2 slop indicators** | Authentic | ✅ Proceed normally |
| **3-4 slop indicators** | Likely AI-assisted | ⚠️ Flag, probe authenticity |
| **5+ slop indicators** | Heavy AI generation | 🚨 Strong concern, consider reject |

---

## Output Format

In the screening report, include:

```markdown
**AI Slop:** [None detected / Light (2 indicators) / Heavy (5+ indicators) — explain]
```

### Examples

```markdown
**AI Slop:** None detected — screening answers reference specific project at Stripe, admits WebRTC gap.
```

```markdown
**AI Slop:** Heavy (6 indicators) — "Why [Company]?" mirrors JD verbatim, skills list matches our requirements exactly but no work history evidence, every answer starts with generic opener.
```

---

## Form Field Red Flags

| Field Content | Meaning |
|---------------|---------|
| `nil`, `null`, `undefined` | AI form-filling, no human review |
| URL in salary field | Bot/automation |
| Same text in multiple fields | Copy-paste or AI |
| "N/A" everywhere | Low effort (probe, don't auto-reject) |

---

## Key Principle

**A polished resume that says nothing specific is worse than a rough resume with concrete evidence.**

Skills inflation without evidence = likely GPT-padded. Always verify claims against work history bullets.

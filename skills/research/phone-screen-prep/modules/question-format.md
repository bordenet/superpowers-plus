# Prioritized Question Block Format

> **Purpose:** Generate Q1-Q6 questions ordered by risk to hiring decision

## Question Block Template

```markdown
## Questions

### 1. Backend Depth
<!-- Concern: Resume shows frontend-heavy experience -->

_"Walk me through a backend system you built from scratch — data model, scaling, failure handling."_

**Notes:**
-

---

### 2. Real-Time Systems
<!-- Concern: No WebSocket/streaming experience shown -->

_"What experience do you have with low-latency systems — WebSockets, audio streaming, sub-100ms pipelines?"_

**Notes:**
-

---

### 3. Ownership + Scale
<!-- Probe: Validate production ownership claims -->

_"Walk me through something you built that's still running in production. What would break if you weren't there?"_

**Notes:**
-

---
... (continue through Q6)
```

---

## Priority Order Logic

Order questions by **risk to hiring decision**:

1. **Highest risk concerns first** — Things that could immediately disqualify (e.g., no backend depth for backend role)
2. **Resume claims to validate** — Ownership, scale, production experience
3. **Domain fit** — Real-time, LLM, observability depending on resume gaps
4. **Career arc / motivation** — Why looking, what they want
5. **Culture fit** — Team culture, feedback style (always last or near-last)

---

## Common Question Topics

| Topic | When to Prioritize | Sample Questions |
|-------|-------------------|------------------|
| Backend Depth | Frontend-heavy resume | "Walk me through a backend system you built from scratch." |
| Real-Time | No streaming/WebSocket experience | "What's the lowest latency target you've worked against?" |
| Ownership | Large-company background | "Tell me about a production system you owned end-to-end." |
| LLM/AI | No LLM experience shown | "Have you integrated LLMs into production? Prompt engineering, evals?" |
| Scale | Weak metrics on resume | "What's the highest traffic system? Give me RPS, latency, DB size." |
| Consulting Depth | Consulting/agency background | "How many release cycles did you own end-to-end?" |
| Tenure | Short stints pattern | "What drove the transitions between roles?" |

---

## NOT Concerns (Do Not Flag)

| Pattern | Why It's Normal |
|---------|-----------------|
| Empty/recent GitHub for big-company engineers | Google, Meta, Amazon use internal monorepos. Expected behavior. |
| No public OSS contributions | Many companies have strict IP policies. Not a red flag. |
| GitHub created recently | Common post-layoff or pre-job-search. |

---

## File Naming Convention

`FirstName_LastName__YYYY-MM-DD.md`

Examples:
- `Daniel_Lee__2026-01-12.md`
- `Shoaib_Beil__2026-01-13.md`

---

## Template Location

`templates/phone-screen.md (in superpowers-[product] or superpowers-[company] repo)`

---

## Output Checklist

1. Confirm file created with full path
2. Show the prioritized question order with rationale
3. Remind user of the interview flow:
   - Opening → Tell me about yourself → Q1-Q6 → Comp gate (if viable) → Their questions
4. Note: Compensation discussion comes AFTER questions, and only if candidate is still in consideration

**⚠️ Remind user:** This file contains PII and is excluded from git. Do NOT manually add it.

# Stack Fit Assessment Module

> **Load when:** ANY candidate (both direct-apply and recruiter-sourced)
> **Purpose:** Evaluate technical stack match for [Company] Senior SDE role

## [Company] Tech Stack

**Primary:** Backend-heavy TypeScript/Node.js
**Telephony:** Telnyx/SIP/WebRTC + [Company] proprietary platform
**AI/ML:** LLM orchestration, prompt engineering, RAG, tool calling
**Messaging:** Kafka, RabbitMQ, Redis Pub/Sub
**Data:** Postgres, Redis
**Infrastructure:** AWS CDK IaC, Docker, Kubernetes/ECS
**Platform:** Automotive AI voice platform

---

## Stack Fit Scoring

### STRONG FIT ✅

| Signal | Weight |
|--------|--------|
| Node.js/TypeScript backend production | High |
| LLM/AI integration (any provider) | High |
| Real-time systems (WebSockets, SIP, WebRTC) | High |
| Event-driven architecture (Kafka, pub/sub) | High |
| IaC experience (CDK, Terraform, CF) | Medium |
| Kubernetes/ECS production | Medium |

### ADJACENT FIT ⚠️ (Transferable)

| They Have | We Use | Transferability |
|-----------|--------|-----------------|
| Go backend | Node.js | High — similar async patterns |
| Python backend | Node.js | Medium — different paradigm but learnable |
| Java/Spring | Node.js | Medium — enterprise patterns transfer |
| Zoom SDK | Telnyx/SIP | High — same domain |
| Twilio | Telnyx | High — direct competitor experience |
| Azure IaC | AWS CDK | High — same concepts |

### WEAK FIT ❌

| Signal | Concern |
|--------|---------|
| Frontend-only (React/Vue/Angular) | No backend depth |
| Mobile-only (iOS/Android) | Different domain |
| Data science only (ML/models) | No production engineering |
| WordPress/Wix/Squarespace | Not SWE |

---

## Key Principle: FUNGIBLE ENGINEERS

**We hire fungible engineers, not stack-matching code monkeys.**

Do NOT over-index on exact technology matches. Focus on:
- Can they learn new systems?
- Do they have transferable patterns?
- Do they show growth across career?

A strong engineer who built Zoom SDK integrations can learn Telnyx.

---

## LLM/AI Experience Evaluation

| Level | Evidence |
|-------|----------|
| **Strong** | Built production RAG/LLM system, prompt engineering, evals |
| **Medium** | Integrated GPT API, used embeddings |
| **Weak** | "Familiar with AI" — no evidence |
| **None** | No mention — not disqualifying, but probe interest |

**Note:** LLM experience is a BONUS, not a requirement. Strong backend engineers can learn LLM patterns quickly.

---

## Pass Matrix

### Experience — PASS if:
- 5+ years qualifying industry SWE
- Title explicitly states SWE/SDE/Backend/Staff/Principal/SRE
- 2+ shipped release cycles as IC or tech lead

### Stack Fit — PASS if:
- Backend-heavy production work (Node/TS primary, Python/Go/Java OK as secondary)
- Real-time systems experience = strong signal
- LLM/AI integration = strong signal
- Event-driven architecture = strong signal
- IaC fluency = strong signal
- Containerization + orchestration experience

### Scale — PASS if ANY:
- Tier-1 production metrics cited (DAU, RPS, revenue, latency SLAs)
- Owned system serving >100K users or >1K RPS
- On-call/incident response with postmortems

### Leadership — PASS if ANY:
- Led project or team (2+ engineers)
- Mentored junior engineers
- Drove technical decisions that shipped

---

## Low-Weight Gaps (Don't Over-Penalize)

| Gap | Why It's OK |
|-----|-------------|
| Terraform instead of CDK | Same pattern |
| WebRTC but not SIP/Telnyx | Adjacent domain |
| Python-primary but has Node | Fungible |
| No explicit IaC but strong AWS | Can learn CDK |

---

## Output Integration

Include in screening report's Supporting Evidence:

```markdown
**Stack Fit:** [Strong/Adjacent/Weak] — [1-2 sentence justification]
```

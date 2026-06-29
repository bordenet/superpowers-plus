---
name: model-selector
source: superpowers-plus
description: Use when user explicitly asks which AI model to use, says "pick a model", "what model should I use", "which model is best for this", "should I switch models", or "help me choose a model". Guides model selection from the approved list to optimize cost without compromising quality.
summary: "Use when: user explicitly asks which AI model to use for a task."
augment_menu: true
triggers:
  - "/sp-model-selector"
  - "pick a model"
  - "what model should we use"
  - "what model should I use"
  - "which model is best for this"
  - "which model is best for"
  - "which ai model should"
  - "should I switch models"
  - "help me choose a model"
  - "best model for this task"
  - "model recommendation"
coordination:
  group: productivity
  order: 1
  requires: []
  enables: []
  escalates_to: []
  internal: false
anti_triggers:
  - "model context protocol"
  - "MCP server"
  - "data model"
  - "domain model"
  - "ML model"
  - "model training"
  - "model schema"
  - "model definition"
  - "train a model"
  - "fine-tune a model"
  - "deploy a model"
composition:
  produces: []
  consumes: [user-intent]
  capabilities: []
  priority: 50
  optional: false
  requires_all: false
---

# Model Selector

## When to Use

Invoke when the user explicitly asks which AI model to use for a task.

> **Explicit-only skill.** Do NOT auto-load. Only engage when user explicitly asks for a model recommendation.
>
> **Scope statement:** This skill estimates AI agent selection for AI-driven work. It does NOT apply to human staffing decisions, incident response timelines, or consulting ROI calculations. If the user is asking which model a human should use to write documents or emails, this skill still applies. If the user is asking how many engineers to hire or how long a sprint will take with a human team, defer with: "This skill selects AI models, not human teams."

## Purpose

Recommend the most cost-effective model for the work at hand — without compromising quality. When planning can enable a lighter model, do the planning first, then recommend.

**Relative cost tiers (approximate, verify at vendor for precise pricing):**
`Opus 4.6` > `Sonnet 4.6 ≈ Sonnet 4.5` > `Sonnet 4` > `Haiku 4.5`. External models (GPT, Gemini) incur additional ecosystem cost: loss of codebase-retrieval access, requiring manual context pasting.

---

## Approved Model Taxonomy

*Last updated: 2026-04-04. Verify against current model availability before citing specific version numbers.*

### Claude-native (keeps codebase-retrieval)

| Model | Tier | Use When | Avoid When |
|-------|------|----------|------------|
| **Opus 4.6** | Frontier | Security decisions, complex architecture, go/no-go analysis, stuck escalation, novel reasoning | Implementation of a clear spec, mechanical tasks |
| **Sonnet 4.6** | Strong | Research, debugging, implementation, most coding, moderate reasoning | Purely mechanical repetition |
| **Sonnet 4.5** | Strong | Same as 4.6 — slightly less capable; use 4.6 if available. If 4.6 is unavailable or rate-limited, Sonnet 4.5 is the preferred fallback before dropping to Sonnet 4. | Same as 4.6 |
| **Sonnet 4** | Mid | Well-specified mechanical work, executing a detailed plan | Tasks requiring novel decisions mid-execution |
| **Haiku 4.5** | Light | Monitoring, data collection, structured repetitive tasks, simple lookups | Anything requiring reasoning or judgment |
| ~~**Opus 4.5**~~ | ⛔ Deprecated | — | Always. Superseded by 4.6 at same cost. |

### External models (⚠️ loses codebase-retrieval)

| Model | Use When | Cost of Switching |
|-------|----------|-------------------|
| **GPT-5.4** | Pure text/analysis with zero codebase reads. GPT-specific capability needed (see definition above). | Loses all codebase context. High. |
| **GPT-5.2 / 5.1 / 5** | Same as 5.4, progressively less capable | Same |
| **Gemini 3.1 Pro Preview** | Multimodal tasks (image + text analysis). No codebase access needed. | Loses all codebase context. High. |

> ⚠️ **Taxonomy staleness:** Model names and capabilities shift frequently. The external model names above follow the naming conventions as of the taxonomy's last verification date (2026-04-04). Verify current model names and availability at the respective vendor pricing/status pages before citing specific version numbers in high-stakes recommendations.

---

## The Critical Filter: Codebase-Retrieval

**Before any recommendation, ask this first:**

> "Does this task require reading, understanding, or editing existing code?"

- **Yes** → Claude-native only (Opus 4.6, Sonnet 4.6, Sonnet 4.5, Sonnet 4, Haiku 4.5). GPT and Gemini are off the table.
- **No** → All models eligible; apply cost tiers below.

**What "loses codebase-retrieval" means in plain English:**
When you switch to GPT or Gemini, those models can't see your files. They operate on only what you paste into the conversation. For any task touching existing code, this is almost always the wrong trade-off.

---

## Task Discovery Protocol

If the user invokes this skill speculatively (no specific task yet), run discovery first:

1. "What are we about to work on? Describe the task in 1–3 sentences."
2. If still vague: "Is this exploratory research, implementation, debugging, or planning?"
3. If scope is unclear: "How many files do you expect to touch? Known codebase or new ground?"

Once you have enough to classify the task, proceed to the Diagnostic Questions below.

---

## Diagnostic Questions (run sequentially — stop when recommendation is clear)

**Q1 — Codebase access (mandatory):**
> "Does this task require reading or editing existing code?"
- Yes → Claude-native tier. Skip to Q3.
- No → All tiers available. Continue to Q2.

**Q1-note — Context window size:** If the task involves files or documents likely to exceed 150K tokens of total context (very large codebases, long documents, or many files in scope), prefer a model confirmed to have a large context window (≥200K). Check current model specs at the vendor before assuming window size, as context limits change between versions. This check applies regardless of Q1 answer.

**Q2 — External model need (only if Q1 = No):**
> "Do you need GPT-specific capability, or does this involve images/multimodal input?"

**GPT-specific capability defined:** A task qualifies *only* when: (a) it must call the OpenAI API directly with a pre-existing GPT system prompt the user has written, or (b) a specific GPT capability has been confirmed absent in the current Claude release (e.g., a particular tool format). Novelty or "I heard GPT is better at X" does not qualify. When uncertain, use Claude.

> ⚠️ **Taxonomy verification gate:** Model names for external models shift frequently. Before citing GPT-5.4, GPT-5.2, GPT-5.1, Gemini 3.1 Pro Preview, or any other external model by name in a recommendation, verify that model is currently available at the vendor. Use "the strongest available GPT-5-series model" when the exact version is unknown.

- GPT-specific (confirmed by the definition above) → strongest available GPT-5-series model
- Multimodal → Gemini 3.1 Pro Preview (or the strongest available Gemini multimodal model)
- Neither → Claude tier; continue to Q3.

**Q3 — Task complexity:**
> "Is this: (A) novel architecture/security/go-no-go decision, (B) standard implementation or debugging, or (C) mechanical execution of a clear spec?"
- A → Opus 4.6
- B → Sonnet 4.6
- C → Continue to Q4.

**Q4 — Plan sufficiency (only if Q3 = C):**
> "Do you have a written plan with ALL of: (a) ≤10 specific steps with expected outputs for each, (b) ≤5 files explicitly named, (c) defined success criteria that are checkable without judgment, AND (d) no novel architectural decisions anticipated during execution?"
- Yes, all four criteria met → Continue to Q5.
- No plan yet, or plan is incomplete → Run the Downgrade Protocol below to create a qualifying plan before downgrading.

**Q5 — Task type (only if Q4 = Yes):**
> "Is this task exclusively data collection, CI monitoring, or structured repetitive lookup with no judgment required?"
- Yes → Haiku 4.5
- No → Sonnet 4



---

## Downgrade Protocol (inline minimum)

Stay on the current model and write: steps, expected outputs, file list, success criteria. Present to user → get approval → switch. Tell user: "If the lighter model hits a decision it can't resolve, escalate back."

**Plan qualifies for downgrade when ALL of the following are true (mirrors Q4):**
1. The plan lists ≤10 specific steps with expected outputs for each
2. No novel architectural decisions are anticipated during execution
3. Scope is ≤5 files AND those files are explicitly named in the plan
4. Success criteria are defined and checkable without judgment

**Escalation-back signal:** After completing each step of the plan, the lighter model must evaluate: "Did this step require any judgment or decision not explicitly described in the plan?" If yes, stop and surface the specific blocker before proceeding to the next step. Request re-engagement on the stronger model for that sub-problem. This check is mandatory after every step — not just when the model encounters an obvious blocker.

**Escalation-back handoff template** (lighter model → user):
> "I've completed steps 1–N. Step [N+1] requires a decision not specified in the plan: [describe the decision]. I recommend re-engaging [stronger model] for this step. Context so far: [1-sentence summary]."

The user should then re-engage the stronger model with this context before the lighter model continues.

## Recommendation Output Format

After running the diagnostic questions, produce this structure:

```
**Recommended model:** [model name]
**Reason:** [1 sentence — e.g., "Task requires existing codebase reads; Sonnet 4 has a clear plan"]
**Codebase-retrieval impact:** [Retained / Lost — state explicitly]
**Next-phase model:** [if multi-phase work is expected]
```

If the user overrides the recommendation: document the override in session context and proceed. Do not repeat the recommendation unless asked.

---

## Multi-Phase Task Guidance

| Phase type | Model |
|------------|-------|
| Architecture / design / security review | Opus 4.6 |
| Implementation (clear spec) | Sonnet 4.6 or Sonnet 4 |
| Testing, refactoring, mechanical cleanup | Sonnet 4 |
| CI monitoring, data collection | Haiku 4.5 |

Suggest the next model change proactively when the current phase ends.

---

## Recommendation Matrix

This matrix is a shortcut reference. For non-obvious cases, always run the Diagnostic Questions (Q1–Q5) — the matrix does not replace that flow, and it cannot encode all the nuance of Q4's plan sufficiency gate.

| Codebase? | Complexity | Plan? | Recommended Model |
|-----------|------------|-------|-------------------|
| Yes | Novel/security | — | **Opus 4.6** |
| Yes | Standard impl/debug | — | **Sonnet 4.6** |
| Yes | Mechanical | Specific (Q4 ✓) | **Sonnet 4** |
| Yes | Mechanical | Vague or no Q4 | **Sonnet 4.6** (run Downgrade Protocol first) |
| Yes | Data/monitoring only (Q3=C, Q5 verified) | Plan ✓ | **Haiku 4.5** — only after Q5 confirms no judgment required |
| No | GPT-specific (confirmed) | — | Strongest available GPT-5-series model |
| No | Multimodal | — | Strongest available Gemini multimodal model |
| No | Standard text | — | **Sonnet 4.6** (stay in ecosystem) |
| Any | Sonnet 4.6 unavailable/rate-limited | — | **Sonnet 4.5** (fallback), then Sonnet 4 |
| Any | Context >150K tokens expected | — | Verify current model context window at vendor; prefer ≥200K model |

---

## ⚠️ External Model Switch Warning

Before switching to GPT or Gemini, **always say:**
> "Switching will lose all codebase context. You'll need to paste code manually. Is that acceptable?"

Claude → Claude switches summarize context automatically; cost is low.

---

## Failure Modes

| Failure | Fix |
|---------|-----|
| Recommending without discovery | Always run Task Discovery protocol first |
| Downgrading without a plan | Enforce the plan sufficiency checklist (≤5 named files, ≤10 steps, no novel decisions) before downgrading |
| Switching to GPT without warning | Mandatory continuity warning before any external model switch |
| Recommending Opus 4.6 by default for mechanical work | Apply Q3/Q4/Q5 before defaulting to frontier; frontier pricing for mechanical work wastes budget |
| Recommended model is unavailable or rate-limited | Substitute next tier down: Opus 4.6 → Sonnet 4.6 → Sonnet 4 → Haiku 4.5. Document the substitution in session context. |
| Lighter model stalls on a decision not in the plan | Escalation-back signal fires; stop and re-engage on the stronger model for that sub-problem |
| Recommends model not in approved list | Approved list is hard-gated; if user wants a non-approved model, surface the exception explicitly |
| Taxonomy is stale | Model list last reviewed 2026-04-04. Verify model availability at vendor pricing/status pages before high-volume or production recommendations. Deprecated models: Opus 4.5 (superseded by 4.6). |

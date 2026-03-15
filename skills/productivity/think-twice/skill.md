---
name: think-twice
source: superpowers-plus
triggers: ["think twice", "you're stuck", "you're looping", "you're going in circles", "stuck in a loop", "spiraling", "stop and think", "fresh perspective", "second opinion", "try a different approach", "stuck:reasoning", "stuck:perspective"]
description: Helps the AI coding assistant break out of spirals and stuck loops. Auto-detects circular reasoning, repeated failures, or exhaustion signals. When triggered (by user or self-detection), pauses to consult a fresh sub-agent with zero shared context.
coordination:
  group: stuck-escalation
  order: 1
  requires: []
  enables: []
  escalates_to: ["perplexity-research"]
  internal: false
---

# Think Twice

> **Break through blockers by consulting a fresh perspective.**

## Overview

When you're stuck on a coding or technical problem, Think Twice automates the
pattern of distilling the problem into a comprehensive brief and dispatching it
to a sub-agent with zero shared context. The act of writing the consultation
prompt forces problem crystallization; the response brings fresh reasoning and
web-sourced knowledge.

## When to Use

### Explicit Triggers (Invoke Immediately)

| User Says | Action |
|-----------|--------|
| "think twice" or "think twice!" | Invoke |
| "get unstuck" or "I'm stuck" | Invoke |
| "try a different approach" | Invoke |
| "consult another model" | Invoke |
| "second opinion" / "get a second opinion" | Invoke |
| "fresh eyes" / "get fresh eyes" | Invoke |
| "consult" / "phone a friend" | Invoke |

### Auto-Detection (Suggest, Don't Auto-Invoke)

Monitor for stuck signals. When cumulative score ≥ 7, **suggest** Think Twice:

| Signal | Weight |
|--------|--------|
| Same fix pattern tried 3+ times | 3 |
| Circular reasoning (referencing own failed output) | 3 |
| Same error message 3+ times after fixes | 3 |
| "I've tried everything" / exhaustion language | 3 |
| "I'm not sure why" / uncertainty hedging | 2 |
| "Let me try a completely different approach" without rationale | 2 |
| Conversation > 80% context window, no resolution | 2 |

**Suggested prompt when threshold met:**

```
I'm detecting signs we might be stuck on this problem:
- [list matched signals]

Would you like me to **Think Twice**? I'll distill the problem into a 
comprehensive brief and consult a fresh sub-agent for a different perspective.
```

See `references/heuristic-signals.md` for full detection criteria.

## The Process

### Step 1: Generate Consultation Prompt

Fill the template from `references/consultation-prompt-template.md`:

1. **Problem Statement** — 2-4 sentences, plain English
2. **Technical Context** — Language, framework, versions, environment
3. **What Has Been Tried** — Numbered list with outcomes
4. **Current Error/Blocker** — Exact error messages, not paraphrased
5. **Relevant Code** — Minimal reproducible snippet (NOT entire files)
6. **Constraints** — Non-obvious limitations
7. **What I Need** — Specific ask
8. **Research Guidance** — Specific search topics

**Quality requirements:**
- Fully self-contained (any engineer could pick it up cold)
- Under 2000 tokens
- Facts separated from speculation
- Includes what was tried AND why it failed

### Step 2: Pre-Dispatch Review Gate

**Always ask:**

```
I've drafted the consultation prompt. Want to review it before I dispatch, 
or should I send it now?
```

- If user reviews: Display full prompt, accept edits, then dispatch
- If user skips: Dispatch immediately

### Step 3: Dispatch to Sub-Agent

**Environment detection (in order):**

```
If Task() tool available → Use Claude Code subagent dispatch
If Augment agent API available → Use Augment dispatch
If THINK_TWICE_USE_PERPLEXITY=true AND perplexity_reason_perplexity available → Use Perplexity MCP
Else → Fall back to manual dispatch
```

#### Claude Code Dispatch (Primary)

```
Task("Think Twice Consultant: [brief problem summary]")

[Generated consultation prompt]
```

The subagent has:
- ✅ Web search (REQUIRED)
- ✅ File read (if paths provided)
- ❌ File write (consultant does not modify code)

See `prompts/consultant-persona.md` for the sub-agent's instructions.

#### Perplexity MCP Dispatch (Disabled by Default)

> ⚠️ **Cost Warning:** Perplexity API calls cost real money (~$0.01/query for `reason`).
> To enable, set `THINK_TWICE_USE_PERPLEXITY=true` in your `.env` file.

If `THINK_TWICE_USE_PERPLEXITY=true` AND `perplexity_reason_perplexity` tool is available:

```
perplexity_reason_perplexity(
  query: [Generated consultation prompt]
)
```

**Why `reason` vs other Perplexity tools:**

| Tool | Use Case | Why Not |
|------|----------|---------|
| `perplexity_ask_perplexity` | Simple factual questions | Too shallow for debugging |
| `perplexity_search_perplexity` | Find sources | Returns links, not analysis |
| `perplexity_reason_perplexity` | Complex multi-step reasoning | ✅ Best fit for debugging |
| `perplexity_research_perplexity` | Deep research reports | Overkill, expensive |

The response from Perplexity is processed the same as other dispatch methods (Step 4).

#### Manual Fallback

If no dispatch methods available:

1. Generate the consultation prompt
2. Save to `docs/think-twice/consultation-{timestamp}.md`
3. Copy to clipboard (if possible)
4. Tell user:
   ```
   I've generated a consultation prompt and saved it to
   docs/think-twice/consultation-{timestamp}.md

   Paste this into Perplexity, Gemini, or another LLM for a fresh perspective.
   When you have the response, paste it back here and I'll integrate the insights.
   ```

### Step 4: Score and Integrate Response

Score the response using `references/scoring-rubric.md`:

| Dimension | Weight |
|-----------|--------|
| Relevance | 30% |
| Novelty | 25% |
| Specificity | 25% |
| Feasibility | 20% |

**Report to user:**

```markdown
## Think Twice Results

**Effectiveness Score:** [X]/100

**Summary:** [1-2 sentence synthesis]

**Key Recommendations:**
- [Recommendation 1]
- [Recommendation 2]

**Suggested Next Step:** [Single most promising action]
```

### Step 5: Retry Logic (If Score < 50)

```
The consultation scored [X]/100 — below the threshold for high confidence.
The main gap was: [weakest dimension].

Options:
1. Retry with a refined prompt (I'll sharpen the brief based on what came back)
2. Proceed with the best suggestion anyway
3. Switch to manual dispatch (paste into Perplexity yourself)
```

- Maximum retries: 1 (total of 2 consultations per invocation)
- Refined prompt MUST include what first consultation suggested and why insufficient

## Reference Files

- `references/consultation-prompt-template.md` — The prompt template
- `references/scoring-rubric.md` — Scoring dimensions and weights
- `references/heuristic-signals.md` — Auto-detection criteria
- `prompts/consultant-persona.md` — Sub-agent persona and constraints

---

## "I'm Stuck" Escalation Path

Both `think-twice` and `perplexity-research` trigger on "I'm stuck". Use this decision tree:

```
"I'm stuck"
    │
    ├─► Is this a REASONING problem?
    │   (logic, approach, design, architecture)
    │   └─► Use think-twice FIRST (free, internal)
    │       └─► Still stuck? → Escalate to perplexity-research
    │
    └─► Is this a KNOWLEDGE problem?
        (API docs, error codes, library versions, facts)
        └─► Use perplexity-research FIRST (external knowledge)
            └─► Still stuck? → Use think-twice for fresh reasoning
```

**Default order:** `think-twice` → `perplexity-research`
- Think-twice is free and instant
- Perplexity costs money and requires justification
- Try internal reasoning before external research

**See also:** `perplexity-research` skill for knowledge-based research

---

## Version

- **Current:** 0.1.0 (MVP)
- **Scope:** Coding and technical problems only
- **Future:** Writing, architecture review, performance, security (Phase 5)

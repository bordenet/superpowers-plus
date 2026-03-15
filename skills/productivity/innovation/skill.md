---
name: innovation
source: superpowers-plus
triggers: ["innovate", "what's the boldest move", "radical improvement", "breakthrough idea", "game-changing", "most impactful change", "10x improvement", "transform this project", "moonshot", "blue sky thinking", "disruptive idea"]
description: Prompts radical, high-impact thinking beyond incremental improvements. Use when seeking transformative ideas, not practical fixes — extends brainstorming into bold territory.
---

# Innovation

> **Ask yourself:** What's the single smartest, most radically innovative, accretive, useful, and compelling addition I could make to this project right now?

## Overview

This skill shifts your thinking from "what's the next incremental fix" to "what's the transformative leap". It's designed for moments when you need bold ideas, not polished implementations. The output is speculative, ambitious, and may require significant effort — that's the point.

**This is NOT a practical skill.** If you need incremental improvements, use `brainstorming`. If you need to debug, use `systematic-debugging`. Innovation is for paradigm shifts.

## When to Invoke

### Explicit Triggers (Invoke Immediately)

| User Says | Action |
|-----------|--------|
| "What's the boldest move here?" | Invoke |
| "How could this be 10x better?" | Invoke |
| "What's the most transformative change?" | Invoke |
| "Give me a breakthrough idea" | Invoke |
| "Blue sky thinking" / "moonshot" | Invoke |
| "Innovate on this" | Invoke |

### Suggested Contexts (Propose, Don't Auto-Invoke)

Consider proposing innovation mode when:
- A project has stabilized and needs fresh direction
- The user is choosing between multiple architectures
- The conversation reveals systemic limitations
- "What's next?" energy without a clear roadmap

**Suggested prompt:**

```
The project seems stable. Would you like me to run **Innovation** mode?
I'll analyze the current state and propose 3-5 radical but feasible ideas
ranked by transformative impact.
```

## The Process

### Step 1: Analyze Current State

Gather context:
- What does this project do today?
- What are its current limitations?
- What adjacent problems exist?
- Who uses it and what do they struggle with?
- What patterns in the codebase are architectural constraints vs. historical accidents?

### Step 2: Ask the Core Question

Explicitly ask yourself:

> "What's the single smartest, most radically innovative, accretive, useful, and compelling addition I could make to this project right now?"

Key dimensions:
- **Radically innovative** — Not incremental; a leap
- **Accretive** — Builds on existing strengths
- **Useful** — Solves real problems (not novelty for its own sake)
- **Compelling** — Would make people excited

### Step 3: Generate 3-5 Radical Ideas

For each idea, evaluate across these categories:

| Category | What to Consider |
|----------|------------------|
| **Technical Innovation** | New architectures, performance breakthroughs, novel algorithms |
| **UX Breakthrough** | Paradigm-shifting interfaces, removing friction entirely |
| **Architectural Shift** | Restructuring that enables new capabilities |
| **Novel Integration** | Combining with unexpected external systems |
| **Paradigm Shift** | Redefining what the project fundamentally is |

### Step 4: Present Ideas (Ranked by Impact)

For each idea, provide:

```markdown
## Idea [N]: [Title]

**What it is:** [1-2 sentence description]

**Why it's transformative:** [Why this is a 10x improvement, not a 10% improvement]

**What it would require:**
- [Major prerequisite 1]
- [Major prerequisite 2]
- [Estimated complexity: Low / Medium / High / Very High]

**Risk/Uncertainty:** [What could go wrong or what's unknown]
```

Rank ideas by:
1. Impact × Feasibility score
2. Alignment with project direction
3. Uniqueness (ideas that only this project could do)

### Step 5: If Stuck — Invoke Think-Twice Pattern

If you cannot generate compelling ideas, generate a consultation prompt:

```markdown
## 🔍 Research Needed

I'm having difficulty generating transformative ideas. Here's a research prompt
for Perplexity or another model:

---
**Context:** [Project summary]

**Current capabilities:** [What it does well]

**Known limitations:** [What constrains it]

**Question:** What are the most innovative approaches in [adjacent domain]
that could be adapted to [this project's problem space]? Looking for paradigm
shifts, not incremental improvements.

**Specifically interested in:**
- [Angle 1]
- [Angle 2]
---
```

Then either dispatch to Perplexity (if available) or present to user for manual research.

## Output Format

```markdown
# Innovation Analysis: [Project Name]

**Context analyzed:** [Brief summary of what you learned]

**Core question:** What's the single smartest, most radically innovative,
accretive, useful, and compelling addition I could make right now?

---

## Idea 1: [Title] ⭐ (Recommended)
[Full idea format from Step 4]

## Idea 2: [Title]
[Full idea format from Step 4]

## Idea 3: [Title]
[Full idea format from Step 4]

---

**Recommended next step:** [Single most promising action]

**If you want to pursue Idea [N]:** [What the first concrete step would be]
```

## Integration with Other Skills

| Skill | Relationship |
|-------|--------------|
| `brainstorming` | Innovation → generates bold direction; brainstorming → refines into actionable design |
| `think-twice` | Fallback when stuck generating ideas |
| `perplexity-research` | Research support for unfamiliar domains |
| `writing-plans` | After innovation idea is selected, brainstorming refines it, then writing-plans implements |

**Typical flow:**
1. `innovation` — Generate transformative ideas
2. User selects direction
3. `brainstorming` — Refine into concrete design
4. `writing-plans` — Create implementation plan

## Do NOT Invoke When

- User needs a bug fix (use `systematic-debugging`)
- User is mid-implementation (use `engineering-rigor`)
- User asked for incremental improvements (use `brainstorming`)
- Project is in crisis mode (stabilize first)

## Key Principles

1. **Bold over safe** — Innovation means accepting risk for transformative upside
2. **Feasible over fantasy** — Radical ≠ impossible; ideas should be buildable
3. **Accretive over orthogonal** — Build on project strengths, don't ignore them
4. **One direction at a time** — Multiple ideas for selection, but pursue one
5. **Speculation is OK** — This skill produces hypotheses, not guarantees

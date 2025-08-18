---
name: innovation
source: superpowers-plus
triggers: ["innovate", "innovation mode", "what's the boldest move", "radical improvement", "breakthrough idea", "game-changing", "most impactful change", "10x improvement", "transform this project", "moonshot", "blue sky thinking", "disruptive idea", "reimagine", "step-change", "new business model", "greenfield idea", "what if we started from scratch", "rethink architecture", "paradigm shift", "new product idea", "strategic pivot", "what would a world-class team do"]
anti_triggers: ["fix this bug", "small refactor", "add this field", "update the docs", "incremental improvement", "quick win", "minor change", "cleanup"]
description: INVOKE when user explicitly seeks transformative, 10x-level ideas — product innovations, architectural paradigm shifts, or new business models. NOT for incremental improvements, bug fixes, or feature requests. Outputs ranked ideas with effort/impact scores and concrete next-week prototypes.
---

# Innovation

> **Core question:** What's the single smartest, most radically innovative, accretive, useful, and compelling addition I could make to this project right now?

**Announce at start:** "I'm using the **innovation** skill to generate transformative ideas."

---

## Overview

This skill shifts thinking from "what's the next incremental fix" to "what's the transformative leap." It produces **shippable innovation outputs**: ranked ideas with effort/impact scores, risk assessments, and concrete next-week experiments.

**This is NOT for:**
- Bug fixes → use `systematic-debugging`
- Incremental features → use `brainstorming`
- Mid-implementation questions → use `engineering-rigor`
- Crisis stabilization → stabilize first, then innovate

**This IS for:**
- Product capability step-changes
- Architectural paradigm shifts
- New business model exploration
- Service boundary rethinking
- Internal tool/process innovation

---

## When to Invoke

### ✅ Invoke Immediately (Explicit Triggers)

| User Says | Why It's Innovation |
|-----------|---------------------|
| "What's the boldest move here?" | Seeking transformative leap |
| "How could this be 10x better?" | Magnitude thinking |
| "Reimagine this from scratch" | Paradigm shift |
| "What would a world-class team do?" | Best-in-class benchmark |
| "Moonshot" / "blue sky thinking" | Explicit innovation language |
| "New business model" / "strategic pivot" | Business transformation |
| "Rethink the architecture" | Structural innovation |
| "Step-change improvement" | Beyond incremental |

### ❌ Do NOT Invoke (Anti-Triggers)

| User Says | Use Instead |
|-----------|-------------|
| "Fix this bug" | `systematic-debugging` |
| "Add this feature" | `brainstorming` |
| "Small refactor" / "cleanup" | `engineering-rigor` |
| "Incremental improvement" | `brainstorming` |
| "Quick win" | Direct implementation |
| "Update the docs" | `wiki-editing` |

### 🤔 Propose (Don't Auto-Invoke)

Consider **suggesting** innovation mode when:
- Project has stabilized and user says "what's next?"
- User is choosing between multiple architectures
- Conversation reveals systemic limitations
- Long-term planning without clear direction

**Suggested prompt:**
```
The project seems stable. Would you like me to run **Innovation** mode?
I'll analyze the current state and propose 3-5 radical but feasible ideas
ranked by impact × feasibility, each with a concrete next-week experiment.
```

---

## The Process

### Step 0: Gather Input Context (NEW)

Before generating ideas, ask for or identify:

1. **PRD/RFC snippet** — If the user has planning docs, request a paste
2. **Code folder** — Identify the relevant `src/` or service directory
3. **User pain points** — What's frustrating about the current state?
4. **Constraints** — Budget, timeline, team size, tech stack limits

If missing, ask **briefly** (one question):
```
Before I run innovation mode, can you share:
(a) a PRD/RFC snippet or current architecture diagram, OR
(b) the top 1-2 pain points you're experiencing?
```

### Step 1: Analyze Current State

Gather context from repo:
- What does this project do today? (Read README, main entry points)
- What are its current limitations? (Check issues, TODOs, tech debt)
- What adjacent problems exist? (Dependencies, integrations)
- Who uses it and what do they struggle with? (User feedback, analytics if available)
- What patterns are architectural constraints vs. historical accidents?

### Step 2: Ask the Core Question

Explicitly ask yourself:

> "What's the single smartest, most radically innovative, accretive, useful, and compelling addition I could make to this project right now?"

Key dimensions:
- **Radically innovative** — Not incremental; a leap (10x, not 10%)
- **Accretive** — Builds on existing strengths, not orthogonal
- **Useful** — Solves real problems (not novelty for its own sake)
- **Compelling** — Would make people excited to use/build

### Step 3: Generate 3-5 Radical Ideas

Evaluate across these innovation categories:

| Category | What to Consider | Example |
|----------|------------------|---------|
| **Technical Innovation** | Performance breakthroughs, novel algorithms | "Replace batch processing with streaming for 50x latency improvement" |
| **UX Breakthrough** | Zero-friction interfaces | "Eliminate login entirely with device-based auth" |
| **Architectural Shift** | Enable new capabilities | "Split monolith into event-driven services" |
| **Novel Integration** | Unexpected combinations | "Connect to Slack to automate 80% of routine tasks" |
| **Paradigm Shift** | Redefine what this is | "Turn the tool into a platform" |

### Step 4: Score and Rank Ideas

For each idea, calculate:

| Dimension | Score (1-5) | Weight |
|-----------|-------------|--------|
| **Impact** | How transformative? | 3x |
| **Feasibility** | Can we build it? | 2x |
| **Alignment** | Fits project direction? | 1x |
| **Uniqueness** | Only we can do this? | 1x |

**Formula:** `(Impact × 3) + (Feasibility × 2) + Alignment + Uniqueness`

### Step 5: Present Ideas with Actionable Next Steps

For each idea, provide:

```markdown
## Idea [N]: [Title] — Score: [X]/35

**What it is:** [1-2 sentence description]

**Why it's transformative:** [Why 10x, not 10%]

**Impact × Feasibility:**
| Dimension | Score | Rationale |
|-----------|-------|-----------|
| Impact | [1-5] | [why] |
| Feasibility | [1-5] | [why] |
| Alignment | [1-5] | [why] |
| Uniqueness | [1-5] | [why] |

**What it would require:**
- [Major prerequisite 1]
- [Major prerequisite 2]
- Estimated effort: [1 week / 1 sprint / 1 quarter]

**Risks & Unknowns:**
- [Risk 1]
- [Risk 2]

**🧪 Next-Week Prototype:**
[Concrete experiment that validates the idea in ≤5 days]
Example: "Build a Slack bot that handles 3 specific request types to validate demand"
```

### Step 6: If Stuck — Invoke Think-Twice or Research

If you cannot generate compelling ideas:

1. **Use `perplexity-research`** to explore adjacent domains:
   ```
   "What are the most innovative approaches in [adjacent domain] that could be
   adapted to [this problem space]? Looking for paradigm shifts, not incremental
   improvements."
   ```

2. **Or invoke `think-twice`** for a fresh perspective from a sub-agent

---

## Output Format

```markdown
# Innovation Analysis: [Project Name]

**Input context:** [What user provided — PRD snippet, pain points, code folder]

**Current state:** [Brief summary of project today]

**Core question:** What's the single smartest, most radically innovative,
accretive, useful, and compelling addition I could make right now?

---

## Idea 1: [Title] ⭐ Recommended — Score: X/35

[Full idea format from Step 5 with scoring table and next-week prototype]

## Idea 2: [Title] — Score: X/35

[Full idea format]

## Idea 3: [Title] — Score: X/35

[Full idea format]

---

## Recommended Path Forward

**Top recommendation:** Idea [N] because [reason]

**This week:** [Concrete next-week experiment]

**If you want to go deeper:** I can turn Idea [N] into:
- [ ] A one-pager / RFC
- [ ] An experiment plan with success criteria
- [ ] A prototype implementation
```

---

## Integration with Other Skills

| Skill | Relationship |
|-------|--------------|
| `brainstorming` | Innovation → bold direction; brainstorming → refines into design |
| `think-twice` | Fallback when stuck generating ideas |
| `perplexity-research` | Research support for unfamiliar domains |
| `writing-plans` | After idea selected → create implementation plan |
| `engineering-rigor` | After plan approved → implementation guidance |

**Typical flow:**
```
innovation → user selects → brainstorming → writing-plans → implementation
```

---

## Key Principles

1. **Bold over safe** — Accept risk for transformative upside
2. **Feasible over fantasy** — Radical ≠ impossible; must be buildable
3. **Accretive over orthogonal** — Build on existing strengths
4. **Concrete over abstract** — Every idea needs a next-week experiment
5. **One direction at a time** — Multiple ideas for selection, pursue one

---

## Follow-Up Offers

After presenting ideas, always offer:

1. **Turn into RFC** — "Want me to draft a one-pager for Idea X?"
2. **Prototype plan** — "Want me to create an experiment plan with success criteria?"
3. **Deep dive** — "Want me to research [specific aspect] further?"

---

## Version

- **v2.0** — 2026-03-15: Added scoring system, next-week prototypes, input context step
- **v1.0** — Initial release

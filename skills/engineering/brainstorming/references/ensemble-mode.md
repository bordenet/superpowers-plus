# Brainstorming Ensemble Mode

> **Purpose:** Multi-perspective ideation for broad, ambiguous, or design-heavy prompts.
> **Activation:** Automatic when multi-agent activation rubric score ≥ 6. Score = 5 → ask user first.
> **Default:** Single-agent brainstorming (existing behavior). Ensemble is escalation.

## When Ensemble Mode Activates

Apply the shared multi-agent activation rubric (`skills/_shared/multi-agent-activation-rubric.md`).

**Brainstorming-specific boosters:**

- Broad/ambiguous prompt (user hasn't specified approach) → +1
- Architectural impact (changes system shape) → +1

**Brainstorming-specific dampeners:**

- Known solution exists → -1
- Time-sensitive ("just do it", "quick") → -1

**Cost cap:** 1.5× single-agent tokens. If you need more, the ensemble isn't helping.

## Ensemble Protocol

### Step 1: Announce Mode

"I'm using **ensemble brainstorming** — dispatching multiple perspective lenses to explore this problem more broadly than a single viewpoint can."

### Step 2: Select Lenses (3–4 from 6)

Choose the most relevant lenses for this task:

| Lens | Select When | Skip When |
|------|------------|-----------|
| **Product / User Value** | User-facing feature, UX decision | Internal tooling, infrastructure |
| **Architecture** | System design, integration, scaling | UI-only change, config change |
| **Reliability / Ops** | Production system, SLA-bound, distributed | Prototype, internal tool |
| **Security / Abuse** | User input, data access, external API | Read-only feature, internal |
| **Simplicity / DX** | Always relevant unless explicitly exploring complex options | Never skip — always include |
| **Contrarian / Skeptic** | Novel feature, unvalidated assumption, hype-driven request | Well-established pattern, minor change |

**Always include Simplicity/DX.** Select 2–3 others based on task characteristics.

### Step 3: Dispatch Lenses as Parallel Sub-Agents

Each lens agent receives:

```python
CONTEXT: [full task description and relevant codebase context]

YOUR LENS: [Lens Name]
YOUR QUESTION: [Key question from lens definition]

PRODUCE:
1. Top 3–5 ideas from your perspective (1 sentence each + rationale)
2. Top 2 risks you see (from your perspective only)
3. What you would REJECT and why (at least 1 idea that seems tempting but bad)
4. Key assumption you're making
5. Confidence: How relevant is your lens to this task? (0.0–1.0)

FORMAT: Structured JSON matching the lens output schema.
BUDGET: [token limit, max 25% of total]
```

### Step 4: Collect and Validate

As lens outputs return:

- Check: is output actually from the assigned perspective? (not generic brainstorming)
- Check: confidence score ≥ 0.3? (kill irrelevant lenses)
- Check: at least 1 rejection included? (prevents pure-positive output)

### Step 5: Synthesize

The synthesizer (conductor agent or post-processing) must:

1. **Cluster similar ideas** — group by theme, not by lens
2. **Preserve contrarian ideas explicitly** — flag as "minority view" with lens source
3. **Remove true duplicates** — same idea, different words
4. **Rank by feasibility × impact** — but keep high-risk/high-reward ideas in separate section
5. **Aggregate risks** — merge overlapping risks, count how many lenses flagged each
6. **Produce planning-ready handoff:**

```markdown
## Brainstorm Results: [Topic]

### Top Recommendations (ranked)
1. **[Idea]** — [rationale] · Feasibility: [H/M/L] · Impact: [H/M/L]
   - Risks: [aggregated from lenses]
   - Source lenses: [which lenses proposed this]

### High-Upside / High-Risk Ideas
- **[Idea]** — [why it's interesting but risky]

### Recurring Concerns (flagged by ≥2 lenses)
- [Concern] — flagged by [Lens A, Lens C]

### Rejected Ideas (with reasons)
- [Idea] — rejected by [Lens] because [reason]

### Open Questions for Planning
- [Question that needs resolution before planning can begin]

### Ensemble Metadata
- Lenses activated: [list]
- Total ideas generated: N → synthesized to M
- Cost: [tokens used] ([ratio]× single-agent)
```

### Step 6: Hand Off

Output feeds directly into plan-and-execute or design-triad as input.
If ensemble output is low-quality (synthesizer confidence < 0.5), fall back to single-agent brainstorming and note why.

## Failure Modes

| Failure | Detection | Recovery |
|---------|-----------|----------|
| Lenses produce identical ideas | >70% overlap in synthesis | Note low diversity; suggest single-agent is sufficient |
| Contrarian lens is empty negativity | No constructive alternatives offered | Kill branch; synthesis notes "contrarian had no actionable input" |
| Synthesis loses nuance | Merged output lacks specific details from individual lenses | Include "lens highlights" appendix with best insights per lens |
| Cost exceeds 1.5× | Token tracking | Stop dispatching; synthesize what we have |
| All lenses low confidence | All < 0.5 | Fall back to single-agent; task may be too narrow for ensemble |

## Adaptive Lens Selection (BS-11)

Instead of always selecting 3–4 lenses manually, the conductor can auto-select based on task signals:

| Task Signal | Lenses Auto-Selected | Rationale |
|-------------|---------------------|-----------|
| User-facing feature mentioned | Product/User Value, Simplicity/DX | Direct UX impact |
| "scalability", "distributed", "services" | Architecture, Reliability/Ops | System-level concern |
| User input, auth, external API | Security/Abuse, Simplicity/DX | Attack surface present |
| "redesign", "rethink", unvalidated assumption | Contrarian/Skeptic, Architecture | Challenge needed |
| Ambiguous/vague (no clear approach) | All 6 as candidate set, then prune to max 4 | Exploration mode |

**Rules:**

1. Simplicity/DX is always included (unchanged)
2. Auto-selection produces a **candidate set**; the conductor may prune if >4 lenses selected
3. Prune by lowest expected relevance (task-lens fit), not by alphabetical or fixed order
4. Log which lenses were auto-selected and which were pruned, with reasoning

**Override:** User can explicitly request specific lenses. User selection always wins.

## Iterative Brainstorming (BS-12)

After synthesis (Step 5), the conductor evaluates whether a second round would improve quality:

**Second-round triggers** (ALL must be true):

1. Synthesis diversity score < 0.5 (too many overlapping ideas)
2. Budget remaining ≥ 40% (enough headroom for another pass)
3. Total synthesized ideas < 3 (thin output)

**Second-round protocol:**

1. Each lens receives the synthesized output from round 1
2. Prompt: "Given these existing ideas, what was MISSED? What adjacent possibilities were overlooked?"
3. Second-round output is merged with round 1 via the same synthesis protocol
4. Maximum: 2 rounds total. If round 2 still scores < 0.5 diversity, accept and note low diversity.

**Cost guard:** Round 2 cannot exceed 50% of round 1's token usage. If it would, stop early and synthesize what's available.

## Cross-Lens Contradiction Clarification (BS-13)

> **Not a debate.** The strategy doc (§Design Alternatives) rejected debate format because it narrows possibility space. This is a targeted **clarification pass** — it asks lenses to explain contradictions, not argue for convergence. The goal is to surface assumptions, not resolve disagreements.

After individual lens outputs (Step 4) but before synthesis (Step 5), an optional clarification pass:

**Clarification triggers** (ANY):

1. Two lenses produced directly contradictory recommendations on the same topic
2. Architecture lens and Simplicity/DX lens disagree on fundamental approach

**Clarification protocol:**

1. Identify the specific contradiction point
2. Each contradicting lens receives the other's reasoning (not full output)
3. Prompt: "Lens [X] reached a different conclusion: [Y]. What assumption in YOUR reasoning would need to change for [X]'s conclusion to be correct?"
4. Responses feed into synthesis as **assumption evidence** (tagged separately, not merged with original ideas)

**Guardrails:**

- Maximum 1 clarification round (not iterative)
- Clarification must surface hidden assumptions, not restate positions
- If both lenses identify the same assumptions, synthesis notes the **explicit tradeoff** (no resolution attempted)
- Clarification is OPTIONAL — only triggered by direct contradictions, never by agreement or mild differences
- This does NOT narrow the idea space — both positions and their assumptions are preserved in synthesis

## Historical Idea Dedup (BS-15)

Prevent re-generating ideas that have already been brainstormed in the current session or recent sessions:

**Dedup protocol:**

1. Before synthesis, hash each idea summary (lowercase, stop-words removed, stemmed)
2. Compare against session idea store (in-memory for current session)
3. Jaccard similarity > 0.7 with a previous idea → flag as "previously explored"
4. Flagged ideas are NOT removed — they are annotated: `[Previously explored in: {context}]`
5. Synthesis ranks previously-explored ideas lower unless new evidence supports them

**Session store:** Array of `{ hash, summary, session_id, timestamp }` entries. Persisted as a JSON array in the brainstorming output metadata. Cross-session dedup requires the user to provide prior session output.

**Limitation:** No persistent idea store exists yet. Dedup is session-scoped. Cross-session dedup is manual: user pastes prior output into context.

## Lens Output Schema

```json
{
  "lens": "string — lens name",
  "confidence": 0.0-1.0,
  "ideas": [
    { "summary": "string", "rationale": "string", "feasibility": "H|M|L", "impact": "H|M|L" }
  ],
  "risks": [
    { "description": "string", "severity": "high|medium|low", "mitigation": "string|null" }
  ],
  "rejections": [
    { "idea": "string", "reason": "string" }
  ],
  "keyAssumption": "string",
  "tokensUsed": 0
}
```

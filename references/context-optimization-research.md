# Context Optimization Research Findings

**Compiled:** 2026-03-20
**Purpose:** Durable reference for context optimization research — DO NOT RE-RESEARCH
**Status:** ✅ Complete (verified 2026-03-25) — all phases implemented, all success criteria met

## Source 1: Anthropic — "Effective Context Engineering for AI Agents" (Sep 2025)

**URL:** <https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents>

### Key Findings (Direct Quotes)

1. **Attention is finite and quadratic:**
   > "LLMs have an 'attention budget'... Every new token introduced depletes this budget... This results in n² pairwise relationships for n tokens."

2. **Context rot is real:**
   > "As the number of tokens in the context window increases, the model's ability to accurately recall information from that context decreases."

3. **Right altitude principle:**
   > "The optimal altitude strikes a balance: specific enough to guide behavior effectively, yet flexible enough to provide the model with strong heuristics."
   - Too specific = "brittle if-else hardcoded prompts"
   - Too vague = "overly general guidance that fails to give concrete signals"

4. **Examples beat rules:**
   > "Teams will often stuff a laundry list of edge cases into a prompt... We do not recommend this. Instead, curate a set of diverse, canonical examples."

5. **Bloated tool sets = #1 failure mode:**
   > "One of the most common failure modes we see is bloated tool sets that cover too much functionality or lead to ambiguous decision points."

6. **Just-in-time context:**
   > "Rather than pre-processing all relevant data up front, agents maintain lightweight identifiers and use these references to dynamically load data into context at runtime."

7. **Minimal viable set:**
   > "You should be striving for the minimal set of information that fully describes your expected behavior."

8. **Compaction for long-horizon tasks:**
   > "Compaction distills the contents of a context window in a high-fidelity manner... The art lies in the selection of what to keep versus what to discard."

9. **Structured note-taking:**
   > "The agent regularly writes notes persisted to memory outside of the context window. These notes get pulled back into the context window at later times."

## Source 2: OpenDev Paper — arXiv 2603.05344v3 (Mar 2026)

**URL:** <https://arxiv.org/html/2603.05344v3>
**Title:** "Building Effective AI Coding Agents for the Terminal"

### Key Architecture Patterns

1. **Priority-ordered conditional prompt composition (Section 2.3.1):**
   - System prompt assembled from independent sections with priority numbers
   - Sections load ONLY when contextually relevant (e.g., git section only if git repo)
   - Split into cacheable and non-cacheable segments

2. **Event-driven system reminders (Section 2.3.4):**
   - 12 total reminders across 3 categories: safety, behavioral, JSON retry
   - Fire at point of decision, NOT upfront
   - Example: "After 5+ consecutive read-only tool calls, break the exploration spiral"
   - One-shot flags prevent reminder degeneration into noise

3. **Compaction stages (Section 2.3.6):**
   - Four graduated thresholds: 70% warn, 80% mask, 90% aggressive mask, 99% full
   - Tool result clearing is "safest lightest touch form of compaction"

4. **Subagent isolation (Section 2.2.7):**
   - Each subagent gets filtered tool access + independent conversation history
   - Returns condensed summary (1,000-2,000 tokens) regardless of exploration depth

5. **Skill lazy loading (Section 2.4.8):**
   - Skills discovered via keyword-scored search, loaded on demand
   - Agent sees skill catalog (names + descriptions) but NOT full content until invoked

## Source 3: Microsoft LLMLingua (EMNLP 2023)

**URL:** <https://www.microsoft.com/en-us/research/blog/llmlingua-innovating-llm-efficiency-with-prompt-compression/>

### Key Findings

- Achieves up to 20x compression on ICL and reasoning prompts
- Uses small LM (GPT-2 or LLaMA-7B) to identify and remove unimportant tokens
- Compressed prompts are hard for humans to read but effective for LLMs
- **NOT applicable to behavioral instructions** — designed for data/retrieval context
- Conclusion: Selective loading > compression for instruction-type content

## Synthesis: What This Means for Superpowers

| Strategy | Applicable? | Why |
|----------|-------------|-----|
| Token compression (LLMLingua) | ❌ No | Risks losing behavioral instructions |
| Conditional loading | ✅ Yes | Biggest single win — stop loading irrelevant always-rules |
| Example-driven format | ✅ Yes | Anthropic explicitly recommends over rule lists |
| Skill merging | ✅ Yes | Reduces ambiguous routing decisions |
| Event-driven reminders | ⚠️ Partial | Requires platform support; can approximate with trigger refinement |
| Altitude raising | ✅ Yes | Replace checklists with heuristics + 1 example |
| Cost tiering | ✅ Yes | Skip expensive skills when confidence is low |

## Implementation: `lib/compress.js`

The actual compression implementation uses a two-phase pipeline applied after selective loading (conditional loading above):

- **Phase 1 (structural):** Section stripping by heading pattern — removes `When to Use`, `Examples`, `Anti-Patterns`, etc. This is the "selective loading" strategy applied at the section level.
- **Phase 2 (density):** Prose reduction outside code blocks — removes redundant formatting, collapses whitespace.

**Critical constraint (incident 2026-04-14):** Compression must preserve operative sections — `Failure Modes`, `Hallucination Prevention`, `Incident Log/Record/History`, `References` (pointer sections), and `<EXTREMELY_IMPORTANT>` blocks. Stripping these caused wiki authoring to regress (broken hyperlinks from fabricated URLs). The pipeline now extracts EI blocks before section stripping and restores them after. See `lib/compress.js` for the authoritative strip/preserve lists.

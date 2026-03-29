# PRD: knowledge-capture Skill

> Renamed from `expert-capture` on 2026-03-26. Reactive mode (conversation harvest) added.

## Bottom Line

Build a superpowers skill that conducts structured SME interviews and produces BLUF-style wiki articles. The skill scopes a topic, interviews a human using a coverage-driven question strategy, synthesizes responses into structured content, drafts and progressively reviews a wiki article with the interviewee, and publishes to Outline wiki.

## Problem Statement

Domain expertise at [Company] lives in people's heads. When an SME leaves, changes roles, or simply forgets, that knowledge is lost. Current documentation is ad-hoc — engineers write docs when they remember to, with inconsistent quality, depth, and discoverability.

There is no structured process for extracting expert knowledge into a durable, findable, reviewed artifact.

## Triggers and Anti-Triggers

```yaml
triggers:
  # Proactive — user initiates knowledge extraction
  - "interview me about"
  - "capture my expertise on"
  - "I'm the expert on"
  - "document my knowledge of"
  - "I want to create a reference article"
  # Reactive — user wants to formalize existing conversation
  - "turn this into wiki documentation"
  - "capture this as a knowledge base article"
  - "promote this tribal knowledge into documentation"
  - "codify this workflow as documentation"
  - "distill this into a shareable doc"
  - "formalize this discussion for the wiki"
  - "turn this debug session into a learning artifact"
anti_triggers:
  - "edit this wiki page"       # → wiki editing
  - "update the docs"           # → wiki editing
  - "write an ADR"              # → ADR process
  - "write a design doc"        # → brainstorming skill
  - "fix this wiki"             # → wiki-verify
  - "brainstorm approaches"     # → brainstorming
  - "help me think through"     # → brainstorming
```

## Core Workflow

### Phase 1: Scoping (2-3 exchanges)

**Required inputs from interviewee:**
1. **Topic:** What domain(s) do you want to cover?
2. **Audience:** Who will read this? (new hires, on-call engineers, PMs, leadership?)
3. **Intent:** What type of article? (reference, runbook, architecture explainer, onboarding guide, FAQ)
4. **Use case:** What task or decision should a reader be able to complete after reading this?
5. **Scope boundaries:** What's in, what's explicitly out?

**New-vs-update detection (before interview begins):**
1. Search Outline for existing documents matching the topic keywords
2. If match found: present to interviewee — "There's already a page on [topic]. Do you want to update it, write a companion page, or start fresh?"
3. Branch: UPDATE (fetch existing content, interview covers deltas) or CREATE (new article)

**State written:** Scoping summary → state file (see Resumability)

### Phase 2: Structured Interview (coverage-driven, not turn-count-driven)

**Question generation policy:**

After scoping, build a coverage matrix for the topic. **The matrix is internal steering for the agent — the interviewee should experience a natural conversation, not a checklist.** The interview proceeds by filling gaps in this matrix, one question at a time:

| Coverage Area | Priority | Status |
|---------------|----------|--------|
| Purpose / audience | P0 | ☐ |
| System boundaries / components | P0 | ☐ |
| Workflows / processes | P0 | ☐ |
| Dependencies (upstream/downstream) | P1 | ☐ |
| Decisions made and trade-offs (WHY) | P1 | ☐ |
| Failure modes / troubleshooting / gotchas | P1 | ☐ |
| Concrete examples / scenarios | P1 | ☐ |
| Terminology / glossary | P2 | ☐ |
| Known exceptions / edge cases | P2 | ☐ |
| Open questions / uncertainties | P2 | ☐ |

**Question selection algorithm:**
1. Pick the highest-priority uncovered area
2. Ask a specific question (not "tell me more") — prefer: "What happens when X fails?", "Walk me through how Y works end-to-end", "Why did you choose Z over alternatives?"
3. After each answer:
   a. Mark coverage area as covered, partial, or still open
   b. If answer introduces undefined nouns → ask for clarification
   c. If answer contradicts earlier response → surface and resolve
   d. If answer is thin (< 2 sentences of substance) → probe deeper with a follow-up, max 3 attempts then mark as partial
4. Tag each response with provenance: `[sme-stated]`, `[doc-verified]`, `[code-verified]`, `[inferred]`, `[contested]`

**Sufficiency gate — interview is complete when ALL of these are true:**
- All P0 coverage areas are covered or explicitly marked N/A
- At least 3 of 6 P1 areas are covered
- At least 1 concrete example is captured
- At least 2 failure modes / trade-offs are captured (if applicable to the topic — skip for descriptive/glossary topics)
- Zero unresolved contradictions on core claims
- Interviewee confirms: "Yes, that covers it" or explicitly requests stop

If sufficiency is not reached after 20 exchanges: offer to narrow scope, mark as partial, or schedule a follow-up session.

**State written:** Interview notes, coverage matrix status, source-quality tags → state file

### Phase 2.5: Synthesis (agent-internal, no user interaction needed)

Before drafting, the agent must:
1. Extract discrete claims from interview notes
2. Cluster claims by topic/coverage area
3. Surface contradictions — flag for interviewee if unresolved
4. Preserve provenance tags from interview — do not flatten `[sme-stated]` into unmarked prose
5. Map claims into article outline sections
6. Identify missing sections that need follow-up questions
7. If follow-ups needed, return to Phase 2 briefly

**State written:** Structured outline with claim mapping → state file

### Phase 3: Article Drafting

Produce a BLUF-style wiki article from synthesized content. Present draft to interviewee for initial reaction before review.

**Do NOT publish without explicit interviewee approval.**

### Phase 4: Progressive Harsh Review (2+ rounds)

**Review rubric — reviewer must check each item:**

| Check | Severity if failed |
|-------|-------------------|
| Bottom Line accurately summarizes the article | Critical |
| No factual claims without source tag | Critical |
| Scope/audience stated clearly | Major |
| All coverage areas from matrix are addressed or explicitly excluded | Major |
| Contradictions surfaced, not flattened | Major |
| No undefined jargon or acronyms | Minor |
| Cross-links to related pages present | Minor |
| Grammar, formatting, readability | Minor |

**Convergence:** No critical or major issues remaining after round 2.
**Escalation:** After 3 rounds without convergence, present remaining blockers to interviewee and ask for decision.

**Authority model:**
- SME is primary source for: intent, history, reasoning, trade-offs
- Code/docs/tickets are primary source for: verifiable current-state facts
- If SME memory conflicts with code/docs: surface both, label the conflict, let interviewee decide resolution
- Unresolved conflicts are published as-is with explicit "[Contested]" labels

**State written:** Review round, unresolved findings → state file

### Phase 5: Publish

**Pre-publish checks:**
1. Scan for secrets/sensitive data (API keys, tokens, internal URLs that shouldn't be public)
2. Duplicate detection: search Outline for existing pages with similar title/content
3. If UPDATE mode: fetch existing page, apply changes, warn about embed/table-width risks per outline-wiki-guardrails

**Wiki placement algorithm:**
1. Search Outline documents by topic keywords and synonyms (documents.search API)
2. Inspect top 5 results — extract their collection and parent document path
3. Cluster results by parent location
4. Rank locations by: number of related pages in that location > keyword relevance > collection breadth
5. If confidence is high (3+ related pages in one location): propose that location
6. If ambiguous: present top 2-3 options to interviewee
7. If no related pages found: ask interviewee directly

**Publish execution:**
1. Create or update document via Outline API (co-activate outline-wiki-guardrails)
2. Post-publish verification: re-fetch, scan for `\[`, `&nbsp;`, broken embeds
3. Open published page in default browser (`open` macOS, `xdg-open` Linux, `cmd.exe /c start` Windows/WSL)
4. Report published URL to interviewee

**Outline outage fallback:**
- If API is unavailable: save approved draft to local file, persist "publish pending" in state file
- Do NOT claim success
- Provide retry instructions: "Run knowledge-capture resume — draft is ready, just needs publishing"

**State written:** Published URL or "publish pending" → state file


## Output Artifact: BLUF Wiki Article

### Required Sections

```markdown
## Bottom Line
[1-3 sentences: what this is, why it matters, who should read it]

## Audience
[Who should read this. What task/decision they can complete after reading.]

## Scope
- **Covers:** [explicit boundaries]
- **Does not cover:** [explicit exclusions]

## Key Findings
- [Finding 1] `[sme-stated]`
- [Finding 2] `[doc-verified]`
- [Finding 3-5]

## [Domain Section — derived from coverage matrix]
[Content with provenance tags: `[sme-stated]`, `[doc-verified]`, `[code-verified]`, `[inferred]`, `[contested]`]

### [Sub-section as needed]

## Terminology
| Term | Definition |
|------|-----------|
| [Term] | [Definition] |

## Failure Modes / Gotchas
- [Failure mode with context and known remediation]

## Trade-offs and Decisions
- [Decision made, alternatives considered, why this choice]

## Open Questions
- [Unresolved items with context on why they're open]

## Confidence and Limitations
- [What was verified vs stated from memory]
- [Known gaps in coverage]

## Source
- **Subject Matter Expert:** [Name]
- **Interview Date:** [Date]
- **Reviewed/Approved by SME:** [Yes/No]
- **Related Pages:** [cross-links]
- **Owner:** [who maintains this page]
- **Review Cadence:** [when to revisit — e.g., quarterly, after next major change]
```

### Section rules
**Always required:** Bottom Line, Audience, Scope, Key Findings, Source, at least one domain section.
**Conditional — include only if interview produced relevant content:**
- Terminology — if the topic introduced domain-specific terms
- Failure Modes / Gotchas — if failure modes were discussed
- Trade-offs and Decisions — if trade-offs were captured
- Open Questions — if unresolved items exist
- Confidence and Limitations — if any claims are `[inferred]` or `[contested]`

Domain sections are derived from the coverage matrix, not from a static list:
- Technical topics get: Components, Architecture, Dependencies
- Process topics get: Workflow Steps, Inputs/Outputs, Exception Handling
- Operational topics get: Runbook Steps, Monitoring, Escalation

## Resumability

### State storage design
Each interview gets a **dedicated state file**, not entries in the global TODO file.

**State file location:** `$HOME/.codex/knowledge-capture/<capture-id>.md`
**TODO file:** Contains only a pointer task — `"knowledge-capture: <topic> — Phase N in progress. State: ~/.codex/knowledge-capture/<id>.md"`

### State schema (v1 — optimized for reliable LLM maintenance)

The state file is a simple markdown file, not JSON. LLMs are more reliable at reading/writing structured markdown than maintaining normalized JSON across many updates.

**File format:** `~/.codex/knowledge-capture/<capture-id>.md`

```markdown
# knowledge-capture state: <topic>
- **Phase:** scoping|interview|synthesis|drafting|review|publish|complete
- **Mode:** create|update
- **Topic:** <topic>
- **Audience:** <audience>
- **Intent:** <reference|runbook|architecture|onboarding|faq>
- **Scope in:** <list>
- **Scope out:** <list>
- **Existing page:** <outline-doc-id or "none">
- **Draft path:** <local file path or "not yet">
- **Publish URL:** <url or "pending" or "not yet">
- **Review round:** <number>

## Coverage Matrix
| Area | Priority | Status |
|------|----------|--------|
| Purpose / audience | P0 | covered |
| System boundaries | P0 | partial |
| ... | ... | ... |

## Interview Log (append-only)
### Q1: <question>
**A:** <answer>
**Provenance:** [sme-stated]
**Coverage:** <area>

### Q2: <question>
**A:** <answer>
**Provenance:** [doc-verified]
**Coverage:** <area>

## Unresolved Contradictions
- <contradiction 1 — or "none">

## Review Findings
### Round 1
- [major] <finding> — resolved/open
- [minor] <finding> — resolved/open
```

**Design rationale:** Append-only interview log avoids corruption from partial writes. Coverage matrix is a simple table update. Phase is a single-field update. This is within the reliability envelope of current LLM-based agents.

### Resume behavior
Resume requires an **explicit trigger** — the interviewee must say "resume knowledge-capture" or equivalent. The skill does NOT auto-resume from a dangling state file.

On explicit resume trigger:
1. Check for state files in `~/.codex/knowledge-capture/`
2. If multiple exist, list them and ask which to resume
3. Read state file, present interviewee with summary of where we left off
4. Ask interviewee: "Resume from Phase N, or abandon this capture?"
5. Continue from confirmed phase

## Non-Goals

- Does NOT record audio/video — text conversation only
- Does NOT replace ADRs, design docs, or incident reports
- Does NOT auto-detect when someone should be interviewed — triggered explicitly
- Does NOT guarantee factual truth beyond stated provenance — source tags indicate confidence
- Does NOT resolve conflicts between SME memory and code/docs automatically — surfaces both, interviewee decides
- Does NOT merge multiple SMEs into a consensus doc unless explicitly scoped
- Does NOT generate diagrams unless explicitly requested
- Does NOT publish without explicit interviewee approval
- Does NOT sanitize secrets automatically — flags potential secrets for interviewee review
- Does NOT create a wiki page if the result is too partial and interviewee declines publication

## Success Criteria

### Automated (testable in bats / integration tests)
| Criterion | Binary Test |
|-----------|------------|
| No duplicate page created | documents.search pre-check returns no page with >80% title overlap |
| Contradictions surfaced | `[contested]` tags present for any unresolved conflicts |
| Provenance preserved | Every factual claim in the article has a provenance tag |
| State survives interruption | Simulated kill mid-Phase-2 → resume reconstructs coverage matrix and continues |
| Publish is idempotent | Re-running publish on same state file does not create a duplicate page |
| Post-publish verification | Re-fetch finds no `\[`, `&nbsp;`, or broken formatting |

### Human-verified (validated during manual E2E test)
| Criterion | Validation |
|-----------|-----------|
| Article passes harsh review | 0 critical, 0 major findings after round 2 |
| Correct wiki placement | Interviewee confirms location |
| Interviewee confirms accuracy | Explicit approval recorded in state file |
| Article is findable | Searchable by title in Outline after publish |

## Edge Cases

| Edge Case | Handling |
|-----------|----------|
| Thin answers | Probe deeper, max 3 follow-ups per area. Mark as partial after 3 attempts. |
| Topic too broad | Help decompose into multiple articles. Capture one at a time. |
| Interviewee stops early | Save state, offer to publish partial with "[Partial — additional interview needed]" marker. Require explicit approval. |
| Multi-session interview | State file enables pickup. TODO pointer persists across sessions. |
| Contradictory information | Surface contradiction explicitly. Ask for resolution. If unresolved, publish with `[contested]` label. |
| Existing page overlap | Detected in Phase 1 new-vs-update check. Offer update, companion, or fresh. |
| Interviewee wants private draft | Save locally, skip publish. Persist draft path in state file. |
| Interviewee stops responding during review | Save state. Do not publish. Interviewee must explicitly resume or abandon. |
| Publish succeeds, verification fails | Log failure, alert interviewee, provide manual fix instructions. |
| Sensitive information detected | Flag to interviewee before publish. Do not auto-redact — interviewee decides. |
| Topic requires diagrams | Note in article that diagrams are needed. Add to Open Questions. |
| Outline API unavailable | Save draft locally, persist "publish pending", provide retry instructions. |
| Interviewee disagrees with reviewer | SME is authority for intent/history. Code/docs are authority for current-state. Label conflicts. |

## Technical Dependencies

### Runtime dependencies (co-activated during execution)
- `outline-wiki-guardrails` — platform guardrails for all wiki create/update operations
- Outline Wiki API — documents.search, documents.create, documents.update, documents.info, collections.list
- Sub-agent capability — for progressive harsh review dispatch
- File system — for state file persistence (`~/.codex/knowledge-capture/`)
- Default browser — for post-publish open

### Build-time dependencies (used during design/PRD phase)
- `brainstorming` — interview flow design ideation
- `design-triad` — architecture selection
- `think-twice` — edge case stress testing

### Environment gating
| Dependency | Check | Failure behavior |
|-----------|-------|-----------------|
| OUTLINE_API_KEY | Env var present | Block publish; allow interview + draft |
| ~/.codex/knowledge-capture/ dir | Writable | Create on first run |
| Sub-agent support | Agent capability | Degrade: self-review instead of sub-agent |
| Browser open command | `which open` / `which xdg-open` | Skip browser open, print URL |

## Skill Metadata (Frontmatter)

See `skill.md` for the canonical frontmatter. The PRD's trigger/anti-trigger section above is the source of truth for trigger design rationale.

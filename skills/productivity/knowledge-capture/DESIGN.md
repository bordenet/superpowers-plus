# Design: knowledge-capture Skill

> Renamed from `expert-capture` on 2026-03-26. See "Reactive Mode" section for the major addition.

## Selected Approach: Modular Skill with On-Demand Modules

### Structure
```
productivity/knowledge-capture/
├── skill.md              Core flow, hard gates, phase transitions
├── modules/
│   ├── coverage-matrix.md    Interview coverage matrix template + usage rules
│   ├── bluf-template.md      BLUF article structure with conditional sections
│   ├── review-rubric.md      Harsh review checklist with severity levels
│   ├── state-format.md       State file format for resumability
│   └── wiki-placement.md     Placement algorithm and fallback rules
├── PRD.md                Product requirements (approved)
└── DESIGN.md             This document
```

### Why This Approach
- Follows the modular skill pattern (core skill.md + `modules/` directory)
- skill.md stays under 150 lines (one load)
- Modules loaded on-demand per phase (saves context window)
- Each module is independently reviewable

### Rejected Alternatives

**Option A: Single monolithic skill.md** — Rejected because the coverage matrix, BLUF template, review rubric, and state format together exceed 300 lines. A monolithic file wastes context window on modules not relevant to the current phase.

**Option C: Multi-skill pipeline** — Rejected because the knowledge-capture workflow is inherently conversational and state-heavy. Splitting into separate skills (expert-scope, expert-interview, etc.) would require complex inter-skill state passing that the superpowers framework doesn't natively support. Pipeline skills (e.g., phone-screen-prep/synthesis in superpowers-[product]) work because there's a natural break point (the actual phone call). Knowledge-capture has no such break — it's one continuous session.

> **Note (2026-03-25):** Recruiting skills (phone-screen-prep, etc.) have been extracted to [superpowers-[product]](https://[INTERNAL-GITLAB]/mbordenet/superpowers-[product]) to eliminate "interview" keyword collisions with this skill.

### 8. Reactive Mode (added 2026-03-26)

The skill supports two entry modes:

**Proactive mode** (original): User initiates a fresh interview. Phase 1 → Phase 2 (full interview) → Phase 2.5 → ...

**Reactive mode** (new): User wants to formalize an existing conversation. Phase 1 → Phase 1.5 (harvest conversation) → Phase 2 (gap-fill only) → Phase 2.5 → ...

**Why this works without a separate skill:**
- The output artifact is identical (BLUF wiki article)
- The modules (coverage-matrix, bluf-template, review-rubric, wiki-placement) are unchanged
- The state file format adds one field (`Source: interview|conversation`)
- Phase 1.5 reuses the same coverage matrix and provenance model
- Phase 2 in gap-fill mode is just Phase 2 with pre-filled coverage — no new logic

**Key design decision:** Phase 1.5 harvests claims from conversation context and maps them to the coverage matrix. If gaps remain, Phase 2 runs in gap-fill mode (asking only about uncovered areas). If coverage is sufficient, Phase 2 is skipped entirely and the flow proceeds to synthesis.

**Harvest entry format:** Harvested entries use `H<N>` prefix (not `Q<N>`) in the interview log to distinguish conversation-sourced content from interview-sourced content. Provenance is `[sme-stated]` for direct user statements and `[inferred]` for agent synthesis.

## Key Design Decisions

### 1. State File Identity
Each capture gets a unique state file: `~/.codex/knowledge-capture/<topic-slug>-<YYYY-MM-DD>.md`

- Topic slug is sanitized (lowercase, hyphens, no special chars)
- Date provides uniqueness for same-topic captures
- On resume, list all state files and ask user which to resume
- On new capture, check for existing state files on same topic — warn about potential duplication

### 2. Provenance Model
Provenance tags (`[sme-stated]`, `[doc-verified]`, `[code-verified]`, `[inferred]`, `[contested]`) are tracked during interview and synthesis but are NOT published inline in the article body.

Instead:
- Article body contains clean, readable prose
- A "Source Notes" appendix at the bottom maps key claims to provenance
- Example: "The claim that provider failover takes <200ms is `[sme-stated]` and has not been independently verified."
- This preserves trust metadata without making the article ugly

### 3. Module Loading Rules
```
| Module              | Load BEFORE                    |
|---------------------|-------------------------------|
| coverage-matrix.md  | Starting Phase 2 (interview)   |
| bluf-template.md    | Starting Phase 3 (drafting)    |
| review-rubric.md    | Starting Phase 4 (review)      |
| state-format.md     | Any state file read/write      |
| wiki-placement.md   | Starting Phase 5 (publish)     |
```

### 4. Outline Integration
- Load `outline-wiki-guardrails` skill before any wiki API call (per core.always.md rule)
- Use `documents.search` API for placement and duplicate detection
- Use `url` field (not `urlId`) for all user-facing links
- Post-publish verification per guardrails

### 5. Interview Flow Architecture
The interview is **adaptive, not scripted**. The coverage matrix is internal steering:

```
[Scoping] → [Coverage Matrix Init] → [Question Loop] → [Sufficiency Gate] → [Synthesis]
                                          ↑                    |
                                          └── if gaps found ───┘
```

The question loop:
1. Agent selects highest-priority uncovered area
2. Asks ONE specific question (not "tell me more")
3. After answer: update coverage, check for contradictions, tag provenance
4. Repeat until sufficiency gate passes

The interviewee experiences a natural conversation. The matrix is never shown.

### 6. Review Architecture
- Preferred: sub-agent reviewer with review-rubric.md context
- Fallback: self-review with explicit role switch (per design-triad rules)
- Min 2 rounds, max 3 before escalating to interviewee

## Edge Cases (from design-triad Step 4)

| Edge Case | Design Response |
|-----------|----------------|
| Two captures on same topic by same SME | State file naming includes date; on new capture, warn if existing file for same topic exists |
| Topic requires multiple SMEs | Out of scope for v1. Skill captures one SME at a time. Multiple captures can be cross-linked manually. |
| Topic needs diagrams/code | Note in Open Questions. Skill captures text knowledge; diagrams added by SME post-publish. |
| Outline API contract changes | Decouple via outline-wiki-guardrails skill — platform changes are absorbed there, not here. |
| Outline search returns irrelevant results for placement | Fallback: ask interviewee directly. Placement is never auto-committed. |
| State file grows very large (20+ Q&A pairs) | Acceptable — markdown is compact. 20 Q&A pairs ≈ 5KB. No action needed. |
| Agent hallucates content not stated by SME | Provenance model catches this — `[inferred]` tag in Source Notes section flags agent-generated claims. Interviewee reviews draft before publish. |
| Interviewee provides sensitive information | Pre-publish check scans for common patterns (API keys, tokens). Interviewee must approve. |

## Harsh Review Findings and Resolutions

### Round 1 (Red Team)
| Finding | Severity | Resolution |
|---------|----------|------------|
| State file identity underspecified — wrong state file could be resumed | Critical | Added topic-slug + date naming; resume lists all files and asks user to select |
| Inline provenance tags will be stripped by readers/editors | Major | Moved to Source Notes appendix — clean prose body, provenance preserved in metadata |
| `co_activate` not an established frontmatter convention | Major | Dropped from frontmatter; skill.md will load outline-wiki-guardrails explicitly per core.always.md rule |
| `references/` directory name doesn't match existing pattern | Minor | Renamed to `modules/` to match phone-screen-prep convention |
| bats test claims not grounded in existing test harness | Minor | Phase 2 test plan will define realistic test scope — metadata and trigger matching only |

### Round 2 Verification
All Round 1 fixes are reflected in the design above:
- State file naming: Section 1 (line 37)
- Provenance model: Section 2 (line 44)
- No co_activate in frontmatter: Section 4 (line 61)
- modules/ directory: Structure section (line 6)
- Test scope: acknowledged, deferred to Phase 2
- Convergence: 0 critical, 0 major findings

### 7. Resume Architecture
- State file is structured markdown (not JSON) for LLM reliability
- Append-only interview log prevents corruption from partial writes
- TODO file contains only a pointer: "knowledge-capture: <topic> — Phase N. State: <path>"
- Resume requires EXPLICIT user trigger — no auto-resume
- On resume: read state, summarize progress, ask "resume or abandon?"

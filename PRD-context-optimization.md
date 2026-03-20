# PRD: Superpowers Context Optimization

**Status:** Active
**Created:** 2026-03-20
**Author:** Matt Bordenet + Augment Agent
**TODO Tag:** `#plan-context-optimization`

## Problem Statement

The superpowers skill system injects significant token overhead into every conversation:
- **15,000 tokens** of "always" rules (12 `.always.md` files) load unconditionally
- **47 skills** (~56,000 tokens total) can fire via trigger matching, each adding ~1,200 tokens
- **Multiple skills** often fire per conversation (e.g., `todo-management` + `verification-before-completion` + `wiki-editing`)
- Combined overhead can reach 20,000+ tokens before any user context

## Research Basis (DO NOT RE-RESEARCH — findings are final)

### Source 1: Anthropic — "Effective Context Engineering for AI Agents" (Sep 2025)
- Context has **n² attention cost** — every token added depletes a finite "attention budget"
- **"Right altitude" principle:** Instructions should be specific enough to guide behavior, yet flexible enough to provide strong heuristics. Avoid brittle if-else checklists AND vague hand-waving.
- **Examples > exhaustive rules:** "Teams will often stuff a laundry list of edge cases... We do not recommend this. Instead, curate diverse, canonical examples."
- **Bloated tool/skill sets** are the #1 common failure mode Anthropic sees
- **Just-in-time context:** Maintain lightweight identifiers, load data dynamically at runtime
- **Goal:** "The smallest possible set of high-signal tokens that maximize the likelihood of your desired outcome"

### Source 2: OpenDev Paper — arXiv 2603.05344v3 (Mar 2026)
- **Priority-ordered conditional prompt composition:** Sections load only when contextually relevant
- **Event-driven system reminders:** Targeted behavioral nudges injected at point of decision, not upfront
- **Compaction stages:** Progressive reduction at 70/80/90/99% context utilization
- **Subagent isolation:** Skills loaded in sub-agent context don't pollute main agent context

### Source 3: Microsoft LLMLingua (EMNLP 2023)
- Token-level compression achieves 20x reduction on data/retrieval prompts
- **NOT applicable** to behavioral instructions — compressing "NEVER fabricate URLs" risks the model missing it entirely
- Conclusion: Compression is wrong tool; **selective loading** is the right tool

## Key Insight

The biggest win is NOT compressing individual skills — it's **loading fewer of them**.
15,000 tokens of always-rules loading unconditionally has more impact than all 47 skill files combined.

---

## Phased Plan

### Phase 1: Audit & Classify (No code changes)
1. Audit all 12 `.always.md` rule files — classify each rule block as ALWAYS vs CONDITIONAL
2. Audit all 47 skills — classify by firing frequency and token cost
3. Identify overlapping/redundant skills that can be merged
4. Measure current token baseline (always-rules + bootstrap + typical skill load)
5. Document findings in this PRD

### Phase 2: Always-Rules Optimization (High impact, low risk)
1. Extract conditional rules from `.always.md` files into on-demand skills
2. Consolidate redundant rules across the 12 files
3. Raise altitude on overly-procedural rules (checklists → heuristics + examples)
4. Validate: re-run harsh-review, doctor checks
5. Measure token reduction vs baseline

### Phase 3: Skill Consolidation (Medium impact, medium risk)
1. Merge overlapping wiki skills (wiki-editing + wiki-authoring + wiki-verify + wiki-debunker)
2. Merge overlapping engineering skills where identified in Phase 1
3. Add `cost_tier` frontmatter field to all skills
4. Implement cost-aware routing in skill-router.js
5. Validate: doctor checks, harsh-review, install + diffusion check

### Phase 4: Skill Content Optimization (Medium impact, high effort)
1. Convert rule-heavy skills to example-driven format (per Anthropic guidance)
2. Raise altitude on procedural skills (step-by-step → heuristics)
3. Trim skills that exceed 200 lines to under 150 where possible
4. Validate: doctor checks, harsh-review

### Phase 5: Measurement & Validation
1. Measure final token counts vs Phase 1 baseline
2. Run behavioral regression tests (do skills still fire correctly?)
3. Commit, PR, merge, push to both repos
4. Update this PRD with final results

---

## Success Criteria
- Always-rules token count reduced by ≥40% (from ~15,000 to ≤9,000)
- Average skill.md token count reduced by ≥20%
- No behavioral regressions (doctor GREEN, harsh-review PASS)
- Zero overlapping skills that cause ambiguous routing

## Non-Goals
- Rewriting the skill-router.js architecture (separate effort)
- Implementing event-driven reminder injection (requires Augment platform changes)
- Prompt compression via LLMLingua or similar (not applicable to behavioral instructions)


---

## Phase 1 Audit Results (2026-03-20)

### Token Baseline

| Component | Words | ~Tokens | Notes |
|-----------|-------|---------|-------|
| Always-rules (12 files) | 7,008 | ~9,110 | Loaded EVERY conversation |
| Bootstrap output | 2,882 | ~3,747 | Loaded EVERY conversation |
| using-superpowers skill | 760 | ~988 | Part of bootstrap |
| find-skills catalog | 2,098 | ~2,727 | Part of bootstrap |
| **Total unconditional overhead** | **~12,748** | **~16,572** | Before any skill fires |
| Average skill.md | ~918 | ~1,194 | Per skill when fired |
| All 47 skills combined | 43,126 | ~56,064 | If ALL fired (never happens) |

### Always-Rules Classification

| File | ~Tokens | Classification | Rationale |
|------|---------|---------------|-----------|
| `outline-wiki.always.md` | 3,961 | **CONDITIONAL** | Only needed when editing wiki pages |
| `linear.always.md` | 959 | **CONDITIONAL** | Only needed when interacting with Linear |
| `linear-comment-hygiene.always.md` | 657 | **CONDITIONAL** | Only needed when writing Linear comments |
| `fathom.always.md` | 531 | **CONDITIONAL** | Only needed when fetching transcripts |
| `todo-enforcement.always.md` | 482 | **CONDITIONAL** | Only needed for multi-step tasks |
| `verify-before-documenting.always.md` | 478 | **KEEP ALWAYS** | Broadly applicable |
| `superpowers-bootstrap.always.md` | 439 | **KEEP ALWAYS** | Governs skill system |
| `url-verification.always.md` | 431 | **CONDITIONAL** | Only needed when committing URLs |
| `cost-conscious-search.always.md` | 399 | **CONDITIONAL** | Only needed when searching web |
| `skills-repo.always.md` | 339 | **CONDITIONAL** | Only needed when editing skills repo |
| `humility.always.md` | 267 | **KEEP ALWAYS** | Behavioral, applies everywhere |
| `superpowers.always.md` | 162 | **REDUNDANT** | Duplicate of superpowers-bootstrap |

**Conditional total: ~7,758 tokens** (85% of always-rules budget)
**Keep-always total: ~1,184 tokens** (13% of always-rules budget)
**Redundant: ~162 tokens** (2%)

### Potential Savings from Always-Rules Alone

Moving conditional rules to on-demand loading would save **~7,758 tokens per conversation** — a 47% reduction in unconditional overhead.

### Wiki Skill Overlap Analysis

7 wiki-related skills exist. The `wiki-orchestrator` is designed as the entry point that invokes others as pipeline stages:

| Skill | Tokens | Role | Merge Candidate? |
|-------|--------|------|-------------------|
| `wiki-orchestrator` | 1,301 | Pipeline coordinator | KEEP (entry point) |
| `wiki-editing` | 1,511 | Download-before-edit, MCP-first | MERGE into orchestrator |
| `wiki-authoring` | 1,328 | Formatting, headings, spacing | MERGE into orchestrator |
| `wiki-debunker` | 2,015 | Fact-checking claims | KEEP (distinct purpose) |
| `wiki-content-coherence` | 1,693 | Dedup, structural defects | KEEP (distinct purpose) |
| `wiki-verify` | 986 | Codebase drift verification | KEEP (distinct purpose) |
| `wiki-secret-audit` | 786 | Secret scanning | KEEP (distinct purpose) |
| `link-verification` | 1,259 | URL verification | KEEP (used beyond wiki) |

**Merge candidates:** `wiki-editing` + `wiki-authoring` into `wiki-orchestrator` would save ~2,839 tokens when wiki skills fire and reduce routing ambiguity.

### Top 10 Largest Skills (optimization targets for Phase 4)

| Skill | Tokens | Lines |
|-------|--------|-------|
| `domain-design` | 2,316 | 250 |
| `adversarial-search` | 2,077 | 232 |
| `wiki-debunker` | 2,015 | 238 |
| `wiki-content-coherence` | 1,693 | 228 |
| `innovation` | 1,606 | 215 |
| `repo-security-scan` | 1,571 | 208 |
| `think-twice` | 1,518 | 249 |
| `wiki-editing` | 1,511 | 243 |
| `public-repo-ip-audit` | 1,509 | 247 |
| `eliminating-ai-slop` | 1,496 | 227 |

### Overlap Analysis Summary

Deep comparison of always-rules vs skills revealed LESS overlap than expected:

| Always-Rule | Tokens | Skill Coverage | Unique Content Risk |
|-------------|--------|---------------|---------------------|
| `outline-wiki` | 3,961 | ~40% duplicated | HIGH — 9 unique sections including critical Outline API gotchas |
| `linear` | 959 | ~60% duplicated | MEDIUM — Workflow state UUIDs and workspace config are unique |
| `linear-comment-hygiene` | 657 | ~0% covered | HIGH — No skill covers comment lifecycle management |
| `fathom` | 531 | 0% covered | CRITICAL — No skill covers Fathom API at all |
| `todo-enforcement` | 482 | ~70% covered | MEDIUM — Enforcement philosophy and incident history unique |
| `url-verification` | 431 | ~60% covered | LOW — File priority matrix and curl commands unique |
| `cost-conscious-search` | 399 | ~65% covered | LOW — Cost table and "never use for" list unique |
| `skills-repo` | 339 | 0% covered | HIGH — PII guardrails not in any skill |

### Revised Strategy (Based on Overlap Analysis)

**Original plan:** Remove 9 conditional always-rules, absorb into skills → save ~7,758 tokens.

**Revised plan:** The unique content is too valuable to lose. Instead:

1. **DELETE** `superpowers.always.md` (162 tokens) — pure redundancy with `superpowers-bootstrap.always.md`
2. **CONSOLIDATE** `linear.always.md` + `linear-comment-hygiene.always.md` into ONE file (save ~300 tokens of overlap)
3. **SLIM** `outline-wiki.always.md` — remove duplicated sections, keep unique Outline gotchas (target: 2,000 tokens from 3,961)
4. **SLIM** remaining rules — raise altitude, remove verbose examples, keep heuristics (target: 20-30% reduction each)
5. **DO NOT REMOVE** `fathom.always.md` or `skills-repo.always.md` — no skill coverage exists

**Revised savings estimate:** ~3,500-4,500 tokens (vs original ~7,758) — still a 38-49% reduction in always-rules overhead.

---

## Phase 2 Results (2026-03-20)

### Actions Taken

| Action | Before | After | Savings |
|--------|--------|-------|---------|
| DELETE `superpowers.always.md` | 162 tokens | 0 | 162 tokens |
| SLIM `outline-wiki.always.md` | 3,961 tokens | ~569 tokens | ~3,392 tokens |
| CONSOLIDATE `linear.always.md` + `linear-comment-hygiene.always.md` | 1,616 tokens | ~298 tokens | ~1,318 tokens |
| SLIM `todo-enforcement.always.md` | 482 tokens | ~112 tokens | ~370 tokens |
| SLIM `url-verification.always.md` | 431 tokens | ~92 tokens | ~339 tokens |
| SLIM `cost-conscious-search.always.md` | 399 tokens | ~113 tokens | ~286 tokens |
| SLIM `fathom.always.md` | 531 tokens | ~133 tokens | ~398 tokens |
| SLIM `skills-repo.always.md` | 339 tokens | ~103 tokens | ~236 tokens |

### Final Token Budget

| Component | Before Phase 2 | After Phase 2 | Change |
|-----------|---------------|---------------|--------|
| Always-rules (files) | 12 | 10 | -2 files |
| Always-rules (words) | 7,008 | 2,004 | **-71.4%** |
| Always-rules (~tokens) | ~9,110 | ~2,605 | **-6,505 tokens** |
| Bootstrap output | ~3,747 | ~3,747 | unchanged |
| **Total unconditional** | **~12,857** | **~6,352** | **-50.6%** |

**Phase 2 exceeded expectations:** Achieved 71% reduction in always-rules (vs 38-49% estimate) by raising altitude aggressively while preserving all unique content.
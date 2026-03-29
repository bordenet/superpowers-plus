# Phase 5: Progressive Rewrite + Review

> **Purpose:** Rewrite all pages per the writing plan, with each page passing 3-round progressive review.
> **Input:** `wiki-writing-plan.md` + content snapshots
> **Output:** `refactored-wiki/*.md`
> **Timebox:** 45 minutes
> **Prerequisite:** Operator approved writing plan at human checkpoint.

## Rewrite Protocol

For each page in priority order (P1 → P2 → P3):

### 1. Draft

- Pull source content from snapshots (not live wiki — use Phase 1 snapshot)
- Follow the section outline from the writing plan page card
- Apply writing standards:
  - Technical, precise, direct prose
  - One idea per sentence
  - Active voice
  - No empty hedging ("might", "could potentially", "it is possible that")
  - Evidence-backed qualifiers ARE allowed: "depends on version", "if enabled", "varies by deployment mode"
  - No filler ("it should be noted that", "in order to", "as a matter of fact")
  - Concrete examples over abstract descriptions
- Resolve any contradictions flagged in Phase 4 (verify against source of truth)
- Add cross-references per the writing plan

### 2. PRD Check

**🔴 Before writing to disk:** Check page slug against `prd-quarantine-list`. If match → HALT.

### 3. Progressive Review (3 rounds)

Each page is reviewed by 5 wiki-specific reviewers. All reviewers have **full access** to all pages, snapshots, and the writing plan. Independence comes from distinct starting points and priorities.

#### Reviewer 1: Factual Accuracy Reviewer
**START FROM** claims and assertions in the page.
**PRIORITIZE** verifiable facts, version-specific statements, configuration values, command syntax.
- Are stated defaults correct?
- Are version requirements current?
- Do code/CLI examples actually work?
- Are there unsourced claims that could be fabricated?

#### Reviewer 2: Structure Critic
**START FROM** page purpose (from writing plan card) and heading hierarchy.
**PRIORITIZE** single-responsibility pages, logical heading flow, consistent depth.
- Does the page serve exactly one purpose?
- Do headings follow a logical progression?
- Is content under the right heading?
- Could any section be its own page?

#### Reviewer 3: Standards Enforcer
**START FROM** naming conventions and cross-references.
**PRIORITIZE** link validity, consistent terminology, page naming patterns.
- Do all internal links point to valid pages in the new structure?
- Is terminology consistent with the rest of the refactored wiki?
- Does the page follow the naming convention for its type?
- Are "See Also" links present and correct?

#### Reviewer 4: Completeness Auditor
**START FROM** prerequisites and assumptions.
**PRIORITIZE** missing context, undefined terms, gaps in procedures.
- Are all prerequisites listed?
- Are all terms defined (or linked to definitions)?
- Are all procedure steps complete? No missing steps?
- Would a reader need to consult another source to complete the task?

#### Reviewer 5: Reader Advocate
**START FROM** a newcomer's perspective.
**PRIORITIZE** discoverability, jargon density, time-to-answer.
- Can a newcomer understand this page without reading 5 other pages first?
- Is jargon minimized or defined on first use?
- How quickly can someone find the answer to the most common question this page addresses?
- Is the page scannable (headers, lists, tables vs walls of text)?

### Review Scoring

Each reviewer scores 1-10 on wiki-specific dimensions (not the code-review dimensions from progressive-harsh-review — wiki content needs different quality lenses):
- **Accuracy** (30%) — factual correctness
- **Structure** (20%) — page organization and hierarchy
- **Completeness** (25%) — no gaps or missing context
- **Readability** (25%) — clear, scannable, newcomer-accessible

### Automated Link Verification (required before PASS)

Before any page can receive a PASS verdict, run automated link verification:
1. Extract all internal links from the page (wiki links, cross-references, "See Also")
2. Verify each target exists in the new structure (not just the old structure)
3. Flag broken links as blocking findings — a page with broken links cannot PASS

This catches link breakage incrementally (per page) rather than only at the end (Phase 7), when repair cost is highest.

**Verdict:** Weighted mean across all 5 reviewers AND link verification passes.

| Weighted Mean | Links | Verdict | Action |
|---------------|-------|---------|--------|
| ≥8 | All valid | **PASS** | Proceed to next page |
| ≥8 | Broken links | **PASS_WITH_FIXES** | Fix links, re-verify |
| 6-7 | Any | **PASS_WITH_FIXES** | Fix findings, re-review changed sections only |
| <6 | Any | **REJECT** | Major rewrite, full re-review |

**Cap:** 3 rounds per page. If still failing after 3 rounds → escalate to human.

**Critical veto:** Any reviewer scoring Accuracy ≤4 with a cited factual error → automatic REJECT.

## Failure Modes

| Symptom | Cause | Response |
|---------|-------|----------|
| Page fails 3 rounds | Content quality won't converge | Escalate to human for manual rewrite |
| All reviewers agree (no findings) | Possible correlated blind spot | Verify each reviewer's output shows starting-point-specific evidence |
| Source content contradicts itself | Wiki had conflicting info | Flag to operator; do not guess which version is correct |
| PRD checkpoint fires | PRD in rewrite scope | HALT — full stop |

---
name: knowledge-capture
source: superpowers-[company]
description: "Use when capturing SME expertise through structured interviewing (proactive), or formalizing conversations/debug sessions/tribal knowledge into durable wiki documentation (reactive). BLUF articles with provenance, published to Outline. NOT for editing existing wiki pages, design exploration, or casual Q&A."
summary: "SME interview → wiki article. Structured Q&A → BLUF documentation with source attribution."
triggers: ["interview me about", "capture my expertise on", "I'm the expert on", "document my knowledge of", "I want to create a reference article", "turn this into wiki documentation", "capture this as a knowledge base article", "promote this tribal knowledge into documentation", "codify this workflow as documentation", "distill this into a shareable doc", "formalize this discussion for the wiki", "turn this debug session into a learning artifact"]
anti_triggers: ["edit this wiki page", "update the docs", "write an ADR", "write a design doc", "fix this wiki", "brainstorm approaches", "help me think through"]
coordination:
  group: productivity
  order: 1
  requires: []
  enables: []
  escalates_to: ['wiki-orchestrator']
  internal: false
---

# knowledge-capture

> **Announce at start:** "I'm using the **knowledge-capture** skill to capture expertise and produce a wiki article."

## 🚨 THIS IS KNOWLEDGE CAPTURE, NOT WIKI EDITING OR BRAINSTORMING

| Signal | Wrong Skill | Right Skill |
|--------|-------------|-------------|
| "interview me about..." | ❌ wiki editing | ✅ knowledge-capture |
| "turn this conversation into a wiki article" | ❌ brainstorming | ✅ knowledge-capture |
| "edit this wiki page" | ❌ knowledge-capture | ✅ wiki editing |
| "write a design doc" | ❌ knowledge-capture | ✅ brainstorming |
| "fix this wiki page" | ❌ knowledge-capture | ✅ wiki-verify |

## ⚠️ Collision Note: `expert-interviewer` (superpowers-plus)

`expert-interviewer` in superpowers-plus shares the trigger "interview me about". When both skills are installed, **knowledge-capture takes precedence** — it is the heavier-duty, wiki-integrated version. If the user explicitly wants the lightweight, artifact-agnostic version, they should invoke `expert-interviewer` by name.

> **Resolved:** `expert-interviewer` now has anti-triggers for "interview me about" and "knowledge capture" (superpowers-plus PR #281).

---

## 🚨 Module Loading (MANDATORY)

| Module | Load BEFORE |
|--------|-------------|
| `modules/state-format.md` | Any state file read/write |
| `modules/coverage-matrix.md` | Starting Phase 1.5 or Phase 2 |
| `modules/bluf-template.md` | Starting Phase 3 (drafting) |
| `modules/review-rubric.md` | Starting Phase 4 (review) |
| `modules/wiki-placement.md` | Starting Phase 5 (publish) |
| `outline-wiki-guardrails` | Any Outline API call |

---

## Two Entry Modes

| Mode | Trigger Signal | Entry Point |
|------|---------------|-------------|
| **Proactive** | "interview me about...", "capture my expertise..." | Phase 1 → Phase 2 (full interview) |
| **Reactive** | "turn this into wiki docs...", "formalize this discussion..." | Phase 1 → Phase 1.5 (harvest conversation) → Phase 2 (gap-fill only) |

The agent determines the mode during Phase 1 scoping based on the user's trigger and whether substantive domain content already exists in the current conversation.

---

## Pipeline

```
                    ┌─ Proactive ─→ [Phase 2: Interview] ──────────────────┐
[Phase 1: Scope] ──┤                                                       ├→ [Phase 2.5: Synthesize] → [Phase 3: Draft] → [Phase 4: Review] → [Phase 5: Publish]
                    └─ Reactive ──→ [Phase 1.5: Harvest] → [Phase 2: Gap-fill] ┘
     ↑                                                          ↑                                                                    |
     └── resume from state file ───────────────────────────────┘                                               if gaps found ───────┘
```

---

## Phase 1: Scope (2-3 exchanges)

1. Ask: What domain/topic? Who will read this? What type? (reference/runbook/architecture/onboarding) What task should a reader complete after reading?
2. Confirm scope boundaries: in and out.
3. **New-vs-update check:** Search Outline for existing pages. If match: ask — update, companion, or new? If Outline is unreachable, proceed with `Mode: create` and note "duplicate check deferred — Outline unavailable during scoping."
4. **Determine entry mode:**
   - If the current conversation already contains substantive domain content (e.g., a debug session, a technical discussion, pasted notes) AND the user's trigger was reactive → set `Source: conversation` in state file → proceed to Phase 1.5.
   - Otherwise → set `Source: interview` → proceed to Phase 2.
5. 🔴 Load `modules/state-format.md` → create state file. Persist `Existing page ID` and `Existing page URL` if update mode.

⛔ **HARD GATE:** Do not proceed without: topic, audience, intent, scope, entry mode, and new-vs-update decision (or explicit "create" if Outline was unreachable).

---

## Phase 1.5: Conversation Harvest (reactive mode only)

> Skip this phase entirely in proactive mode.

1. 🔴 Load `modules/coverage-matrix.md`
2. Initialize coverage matrix in state file.
3. Scan the current conversation for domain-relevant content. Extract discrete claims, decisions, examples, failure modes, and terminology.
4. For each extracted claim: tag provenance as `[sme-stated]` (from user's own words in conversation) or `[inferred]` (agent synthesis of multiple statements).
5. Map extracted claims to coverage matrix areas. Mark areas as `covered`, `partial`, or `open`.
6. Append extracted content to interview log in state file as harvested entries (use `H<N>` prefix, not `Q<N>`):
   ```
   ### H1: [harvested from conversation]
   **A:** <direct user statement extracted verbatim or closely paraphrased>
   **Provenance:** [sme-stated]
   **Coverage:** <area name>

   ### H2: [harvested from conversation]
   **A:** <agent synthesis of multiple user statements>
   **Provenance:** [inferred]
   **Coverage:** <area name>
   ```
7. Present a summary to the user: "Here's what I extracted from our conversation: [coverage summary]. These areas still have gaps: [list]."
8. **If all P0 areas are covered** → proceed to Phase 2.5 (synthesis).
9. **If gaps remain** → proceed to Phase 2 in gap-fill mode.

⛔ **HARD GATE:** Do not skip this phase in reactive mode. The conversation IS the raw material — it must be harvested before synthesis.

---

## Phase 2: Interview (coverage-driven)

**In proactive mode:** Full interview from scratch.
**In reactive mode (after Phase 1.5):** Gap-fill only — ask questions ONLY for uncovered areas.

1. 🔴 Load `modules/coverage-matrix.md` (if not already loaded from Phase 1.5)
2. **Proactive mode:** Initialize coverage matrix in state file (all areas `open`).
   **Reactive mode:** Resume coverage matrix from state file (Phase 1.5 already initialized and partially filled it).
3. **Reactive mode shortcut:** Check sufficiency gate immediately. If Phase 1.5 already covered all P0 areas and ≥3 P1 areas, ask user: "Coverage looks sufficient based on our conversation. Proceed to synthesis, or do you want me to ask follow-up questions?" If user confirms → skip to Phase 2.5. If user wants more → continue with gap-fill below.
4. Run question loop: one question at a time, driven by highest-priority uncovered area.
5. **The interviewee should experience a natural conversation, NOT a checklist.**
6. After each answer: update coverage, tag provenance, check for contradictions.
7. Append Q&A to interview log in state file (append-only).
8. Check sufficiency gate per coverage-matrix module.

⛔ **HARD GATE:** Do not proceed to Phase 2.5 without sufficiency gate passing OR interviewee explicitly requesting stop.

---

## Phase 2.5: Synthesize (agent-internal)

1. Extract discrete claims from interview log.
2. Cluster by coverage area.
3. Surface contradictions — if unresolved, return to Phase 2 briefly.
4. Preserve provenance tags.
5. Map claims into article outline.

---

## Phase 3: Draft

1. 🔴 Load `modules/bluf-template.md`
2. Generate article following template rules. Include conditional sections only if relevant.
3. Provenance goes in Source Notes appendix, NOT inline.
4. Present draft to interviewee for initial reaction.

⛔ **HARD GATE:** Do not proceed to Phase 4 without interviewee seeing the draft.

---

## Phase 4: Review (min 2 rounds)

1. 🔴 Load `modules/review-rubric.md`
2. Dispatch sub-agent reviewer with rubric context. Fallback: self-review with explicit role switch.
3. Present findings to interviewee. Ask about any gaps or disagreements.
4. Fix → re-review → repeat. Min 2 rounds, max 3.
5. Update state file with review findings.

⛔ **HARD GATE:** Do not proceed to Phase 5 without 0 critical + 0 major findings.

---

## Phase 5: Publish

1. 🔴 Load `modules/wiki-placement.md` and `outline-wiki-guardrails` skill.
2. Run pre-publish checks: secret scan, duplicate detection.
3. Run placement algorithm. Ask interviewee to confirm location.
4. **Ask for explicit publish approval.**
5. Publish. Verify. Open in browser. Update state file.

⛔ **HARD GATE:** Do not publish without explicit interviewee approval.

---

## Resume

On "resume knowledge-capture" or equivalent:
1. Check `~/.codex/knowledge-capture/` for state files. Also check `~/.codex/expert-capture/` for legacy state files (backward compat).
2. List with topic, phase, and source mode. Ask: resume or abandon?
3. On resume: load state, continue from current phase.
4. On abandon: archive to `~/.codex/knowledge-capture/archive/`.

## When to Use

**Proactive mode:**
- User says "interview me about...", "capture my expertise on...", "I'm the expert on..."
- Knowledge lives in someone's head and needs to be captured durably
- User wants to document tribal/operational knowledge as a wiki article

**Reactive mode:**
- User says "turn this into wiki documentation", "formalize this discussion..."
- A conversation, debug session, or technical discussion has already happened and the user wants to preserve it
- User pastes notes, transcripts, or raw content and wants it structured as a wiki article

## Scope Exclusions

- Editing an existing wiki page (use wiki editing)
- Writing design docs or ADRs (use brainstorming)
- Fixing wiki formatting (use wiki-verify)
- Design exploration or brainstorming approaches (use brainstorming)
- Recording meeting notes (use fathom-meeting-notes)
- General-purpose lightweight knowledge extraction without wiki output (use expert-interviewer from superpowers-plus)

## Failure Modes

| Failure | Fix |
|---------|-----|
| Generic questions (not topic-specific) | Use coverage matrix. Ask about specifics, not "tell me more." |
| Checklist-feeling interview | Matrix is internal. Conversation should feel natural. |
| State file corruption on resume | Append-only log. Phase is single-field update. |
| Published article has inline provenance tags | Tags go in Source Notes appendix only. |
| Duplicate wiki page created | Run duplicate detection before publish. |
| Reactive mode skips harvest phase | Phase 1.5 is mandatory in reactive mode. Conversation must be harvested before synthesis. |
| Reactive harvest misses content | Present coverage summary to user after harvest. User confirms or points to missed content. |
| Wrong mode selected | Agent determines mode in Phase 1 based on trigger + conversation context. If wrong, user can correct. |


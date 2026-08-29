---
name: knowledge-capture
source: superpowers-plus
augment_menu: true
description: "Use when capturing SME expertise through structured interviewing (proactive), or formalizing conversations/debug sessions/tribal knowledge into durable wiki documentation (reactive). Bottom-line-up-front articles with provenance, published to your team's wiki. NOT for editing existing wiki pages, design exploration, or casual Q&A."
summary: "SME interview -> wiki article. Structured Q&A -> wiki documentation with bottom-line-up-front format and source attribution."
triggers: ["/sp-knowledge-capture", "interview me about", "capture my expertise on", "I'm the expert on", "document my knowledge of", "I want to create a reference article", "turn this into wiki documentation", "capture this as a knowledge base article", "promote this tribal knowledge into documentation", "codify this workflow as documentation", "distill this into a shareable doc", "formalize this discussion for the wiki", "turn this debug session into a learning artifact"]
anti_triggers: ["edit this wiki page", "update the docs", "write an ADR", "write a design doc", "fix this wiki", "brainstorm approaches", "help me think through"]
coordination:
  group: productivity
  order: 1
  requires: []
  enables: []
  escalates_to: []
  internal: false
composition:
  produces: []
  consumes: [user-intent]
  capabilities: []
  priority: 50
  optional: false
  requires_all: false
---

# knowledge-capture

> **Announce at start:** "I'm using the **knowledge-capture** skill to capture expertise and produce a wiki article."

## Routing

| Signal | Wrong Skill | Right Skill |
|--------|-------------|-------------|
| "interview me about..." | wiki editing | knowledge-capture |
| "turn this conversation into a wiki article" | brainstorming | knowledge-capture |
| "edit this wiki page" | knowledge-capture | wiki editing |
| "write a design doc" | knowledge-capture | brainstorming |

**Collision note:** `expert-interviewer` shares "interview me about". `knowledge-capture` takes precedence — it is the heavier-duty, wiki-integrated version.

---

## Module Loading (MANDATORY)

| Module | Load BEFORE | If unavailable, use: |
|--------|-------------|---------------------|
| `modules/state-format.md` | Any state file read/write | Track state in a Markdown file with sections: Topic, Phase, Source (interview/conversation), Wiki Page ID, Interview Log (append-only Q&A) |
| `modules/coverage-matrix.md` | Starting Phase 1.5 or Phase 2 | Use areas: Context/Background, Core Concepts, How it Works, Failure Modes, Common Mistakes, Expert Tips, References. Mark each: open/partial/covered. |
| `modules/bluf-template.md` | Starting Phase 3 (drafting) | Article format: ## Bottom Line (1-2 sentences), ## Background, ## How It Works, ## Failure Modes, ## References + Source Notes |
| `modules/review-rubric.md` | Starting Phase 4 (review) | Check: accuracy vs stated claims, no unsourced assertions, BLUF is present and correct, all P0 coverage areas addressed, no inline provenance tags |
| `modules/wiki-placement.md` | Starting Phase 5 (publish) | Place under the most relevant existing parent page. Confirm location with user before publishing. |

---

## Two Entry Modes

| Mode | Trigger Signal | Entry Point |
|------|---------------|-------------|
| **Proactive** | "interview me about...", "capture my expertise..." | Phase 1 -> Phase 2 (full interview) |
| **Reactive** | "turn this into wiki docs...", "formalize this discussion..." | Phase 1 -> Phase 1.5 (harvest conversation) -> Phase 2 (gap-fill only) |

---

## Phase 1: Scope (2-3 exchanges)

1. Ask: What domain/topic? Who will read this? What type? (reference/runbook/architecture/onboarding)
2. Confirm scope boundaries: in and out.
3. **New-vs-update check:** Search your team's wiki for existing pages on this topic. If match: ask -- update, companion, or new?
4. **Determine entry mode:** if the conversation already contains substantive domain content AND the user's trigger was reactive -> set `Source: conversation` -> proceed to Phase 1.5. Otherwise -> set `Source: interview` -> proceed to Phase 2.
5. Load `modules/state-format.md` -> create state file. Persist existing page ID and URL if update mode.

**HARD GATE:** Do not proceed without: topic, audience, intent, scope, entry mode, and new-vs-update decision.

---

## Phase 1.5: Conversation Harvest (reactive mode only)

1. Load `modules/coverage-matrix.md` -> initialize coverage matrix in state file.
2. Scan the current conversation for domain-relevant content. Extract claims, decisions, examples, failure modes, terminology.
3. For each claim: tag provenance as `[sme-stated]` (from user's words) or `[inferred]` (agent synthesis).
4. Map extracted claims to coverage matrix. Mark areas as `covered`, `partial`, or `open`.
5. Append to interview log as harvested entries (`H<N>` prefix, not `Q<N>`).
6. Present summary to user: "Here's what I extracted... These areas still have gaps: [list]."
7. **If all P0 areas covered** -> Phase 2.5 (synthesis). **If gaps remain** -> Phase 2 (gap-fill).

**HARD GATE:** Do not skip this phase in reactive mode.

---

## Phase 2: Interview (coverage-driven)

1. Load `modules/coverage-matrix.md` if not already loaded (proactive mode).
2. **Reactive mode shortcut:** if Phase 1.5 covered all P0 areas and >=3 P1 areas, ask: "Proceed to synthesis or do you want follow-up questions?"
3. Run question loop: one question at a time, driven by highest-priority uncovered area.
4. The interviewee should experience a natural conversation, NOT a checklist.
5. After each answer: update coverage, tag provenance, check for contradictions.
6. Append Q&A to interview log (append-only, `Q<N>` prefix).

**HARD GATE:** Do not proceed to Phase 2.5 without sufficiency gate passing OR explicit user stop.

---

## Phase 2.5: Synthesize (agent-internal)

Extract claims from log. Cluster by coverage area. Surface contradictions (return to Phase 2 if unresolved). Preserve provenance. Map claims to article outline.

---

## Phase 3: Draft

1. Load `modules/bluf-template.md`.
2. Generate article per template. Provenance goes in Source Notes appendix, NOT inline.
3. Present draft to interviewee for initial reaction.

**HARD GATE:** Interviewee must see the draft before proceeding.

---

## Phase 4: Review (min 2 rounds)

1. Load `modules/review-rubric.md`.
2. Dispatch sub-agent reviewer or self-review with explicit role switch.
3. Present findings. Ask about gaps or disagreements.
4. Fix -> re-review -> repeat. Min 2 rounds, max 3.

**HARD GATE:** 0 critical + 0 major findings before Phase 5.

---

## Phase 5: Publish

1. Load `modules/wiki-placement.md`.
2. Run pre-publish checks: secret scan, duplicate detection.
3. Run placement algorithm. Ask interviewee to confirm location.
4. Ask for explicit publish approval.
5. Publish. Verify. Update state file.

**HARD GATE:** Explicit interviewee approval required before publishing.

---

## Resume

On "resume knowledge-capture": check state file in `~/.codex/knowledge-capture/`. List topic, phase, source mode. Ask: resume or abandon? On abandon -> archive.

Full detail: `references/scope-and-resume.md`

## Failure Modes

| Failure | Fix |
|---------|-----|
| Generic questions (not topic-specific) | Use coverage matrix. Ask about specifics, not "tell me more." |
| Checklist-feeling interview | Matrix is internal. Conversation should feel natural. |
| State file corruption on resume | Append-only log. Phase is single-field update. |
| Published article has inline provenance tags | Tags go in Source Notes appendix only. |
| Duplicate wiki page created | Run duplicate detection before publish. |
| Reactive mode skips harvest phase | Phase 1.5 is mandatory in reactive mode. |
| Wrong mode selected | Agent determines mode in Phase 1 based on trigger + conversation context. |

---
name: context-ferry
source: superpowers-plus
augment_menu: true
auto_invoke: true
triggers:
  - "/context-ferry"
  - "context is running low"
  - "about to auto-compact"
  - "running out of context"
  - "low context"
  - "context limit"
anti_triggers:
  - "session-handoff"
  - "cold start"
  - "what changed in"
description: "Generates a self-contained resume prompt before context compaction. Updates any in-progress execution doc, captures pending questions and queued tasks verbatim, then writes a ferry prompt to ~/context-ferry-<timestamp>.md and prints it in-conversation. Fires automatically via PreCompact hook in Claude Code; invoke manually with /context-ferry on any platform."
summary: "Pre-compact context transfer: update plan doc -> capture pending questions/tasks -> write ferry prompt -> save and print."
coordination:
  group: pre-compact
  order: 10
  requires: []
  enables: []
  internal: false
composition:
  consumes: [conversation-state, execution-doc, task-list]
  produces: [context-ferry-prompt]
  capabilities: [context-preservation, session-transfer]
  priority: 100
---

# context-ferry

> **Wrong skill?** Cold-start git sibling activity check -> `session-handoff`. Stuck in a loop -> `think-twice`. Task tracking -> `todo-management`.
>
> **Rescue your session before context compaction swallows it.**

Generates a fully self-contained resume prompt so a fresh session -- on a different machine, a different tab, or a different AI platform -- can pick up exactly where this one left off. Fires automatically on PreCompact in Claude Code; invoke manually at any time with `/context-ferry`.

## When This Fires

| Trigger | Why |
|---------|-----|
| UserPromptSubmit hook (turn-count) | Early warning at ~20 assistant turns (fires while context pressure is still low) -- fires exactly once per session via hysteresis flag |
| PreCompact hook (Claude Code) | Backstop at ~95% context -- enriches ferry file with git state, branch, commits, and CLAUDE.md excerpt so model only needs to append Key Decisions |
| `/context-ferry` | Manual -- invoke any time; works on any platform |
| Natural language: "context is running low" | Phrase-matched trigger |

**Turn-count trigger:** `user-prompt-submit-context-ferry.sh` counts `"role":"assistant"` occurrences in the session transcript JSONL. Default threshold: 20 turns (override via `CONTEXT_FERRY_TURN_THRESHOLD` env var). Writes a per-session flag file (`~/.claude/.context-ferry-warned-<session_id>`) so the warning fires exactly once per session — by design. To re-trigger for the same session, delete that flag file. Turn count is immune to large tool-output spikes that would distort a file-size proxy.

**PreCompact backstop:** When compaction fires at ~95%, `pre-compact-context-ferry.sh` generates a rich scaffold (`~/context-ferry-<timestamp>.md`) pre-populated with branch, recent commits, working tree status, unpushed commits, and CLAUDE.md excerpt. Model only appends Key Decisions, Pending Questions, and Next 3 Actions to the existing file -- minimizes token spend at critical context.

**On Augment Code:** No hooks. Use `/context-ferry` manually before context gets critical.

## The 5-Step Sequence

**Execution path depends on how this fired:**

| Trigger | Path |
|---------|------|
| UserPromptSubmit hook (early warning) | Full 5-Step Sequence below |
| Manual `/context-ferry` | Full 5-Step Sequence below |
| PreCompact hook (backstop) | **Abbreviated path only** — the hook has pre-filled `~/context-ferry-<timestamp>.md` with git state and CLAUDE.md excerpt. Your only job: open that file and append to the three TODO sections (Key Decisions, Pending Questions, Next 3 Actions). Do NOT run Steps 1-5 — context is critically low. |

For the full path: execute Steps 1-5 in order. Each section is written as a discrete block so that even if auto-compact fires mid-generation, the highest-value sections (Original Goal, Pending Questions, Pending Tasks) already exist in the conversation and can be recovered.

### Step 1 -- Update the execution doc (if one exists)

Identify any in-progress execution or plan document open in this session: a `docs/superpowers/plans/YYYY-MM-DD-*.md` checklist, a task plan the user referenced, or any checklist document you have read or written during this session.

**If found:**
- Check off completed items: `- [ ]` -> `- [x]`
- Add a brief status note to in-progress items: e.g. `*(in progress: partial -- see ferry prompt)*`
- Add a `BLOCKED:` comment to blocked items
- Write the updated file back to its existing path

This step is mandatory. A stale plan doc is worse than no plan doc -- the new session will trust it.

If multiple plan docs: update the most recently modified one; note all candidate paths in the ferry prompt.
If no execution doc exists: skip to Step 2.

### Step 2 -- Collect pending state

**Pending questions:** Review this conversation for any question you asked the user that has not been answered. Capture each verbatim -- do not paraphrase.

**Pending tasks:** If `todo-management` is active or a task file exists (e.g. `TODO.md`, `.tasks`, a Taskfile), read it and extract all incomplete items. Task file is authoritative over conversation memory. If tasks exist only in conversation memory, capture them and note they are not yet in a task file.

### Step 3 -- Write the ferry prompt, section by section

Write each section as a discrete block in this exact order. Do not generate the entire prompt as one atomic block.

````
## CONTEXT FERRY -- <ISO date> <HH:MM UTC>
Generated by context-ferry. Paste into a fresh session to resume.
Fidelity: <see Fidelity Signal section below>

---

### Original Goal
<1-3 sentences: what we set out to accomplish and why it matters.>

### Pending Questions for You
Re-ask these before doing anything else -- they were unanswered when this session ended:
  1. "<exact question text, verbatim>"
*(Omit this section entirely if no questions are pending.)*

### Pending / Queued Tasks
Planned but not started (source: <task file path | conversation memory>):
  - [ ] <task text>
*(Omit this section entirely if the task queue is empty.)*

### Key Decisions Made
Conversation-only context -- git cannot provide this:
  - Chose X over Y because Z
  - Rejected approach A (reason: ...)
  - User clarified: ...

### Execution Document
*Updated and current as of this ferry. Read this before doing anything:*
  `<absolute path to plan/checklist doc>`
*(Omit if no execution doc exists -- full task state is above.)*

### In Progress / Blocked
  - In progress: <what's partially done and its current state>
  - Blocked: <what's blocked and why>

### Next 3 Actions
<If Pending Questions exist, action 1 is always: re-ask question 1.>
  1. <exact action>
  2. <exact action>
  3. <exact action>

### Key Files & Diffs
<File paths and relevance. If hook-provided: git stat output appears here automatically.>
  - `path/to/file` -- <what it is / its current state>
````

### Step 4 -- Write file

Write the completed ferry prompt to:
```
~/context-ferry-<YYYY-MM-DD>T<HHMMss>.md
```

Use the Write tool. If unavailable, print `cat > ~/context-ferry-<timestamp>.md` with the content and ask the user to run it.

### Step 5 -- Print in conversation

Render the ferry prompt inside a fenced markdown block so the user can copy it immediately, then print one summary line:

```
Ferry written to: ~/context-ferry-<timestamp>.md
```

## Fidelity Signal

Set the `Fidelity:` line based on estimated remaining context:

| Context remaining | Signal |
|-------------------|--------|
| > 20% | `high (generated proactively -- full fidelity)` |
| 10-20% | `moderate (generated under context pressure -- verify specifics)` |
| < 10% | `degraded (generated at critical low context -- verify Key Files with git/file reads)` |

The new session should trust Goal, Key Decisions, Pending Questions, and Pending Tasks at any fidelity level. It should verify Key Files at degraded fidelity by running `git status` and reading relevant files directly.

## Sensitive Content Warning

Before writing the file, consider: does this session involve credentials, tokens, API keys, PII, or internal URLs that should not live in a plaintext home-directory file?

If yes, prepend a warning before the ferry block:
```
Warning: this session may contain sensitive content.
Review ~/context-ferry-<timestamp>.md before sharing it.
```

Do not block or skip generation. The file still gets written. The user decides what to do with it.

## Failure Modes

| Failure | Recovery |
|---------|---------|
| Auto-compact fires before Step 3 completes | Sections already written survive in conversation history; new session reads what's there and proceeds |
| No execution doc found | All task/progress state goes inline -- omit the Execution Document section |
| Pending question was implicit (never phrased as a question) | Rephrase it as a clear direct question; do not omit it |
| Task file unreadable | Note "task file at `<path>` could not be read" and fall back to conversation-memory tasks |
| No git repo in working directory | Hook writes "No git repository" note; skill proceeds normally |
| Write tool unavailable | Print the ferry prompt only; tell user to save manually |
| Early-warning hook fired but model continued without running /context-ferry | PreCompact backstop will still catch it and write the scaffold. High-context sessions should treat the hook warning as a genuine interruption, not a suggestion. |
| Context exhausted mid-skill (full path started too late) | Stop wherever you are; write the ferry file with whatever sections completed. Partial ferry is better than no ferry. |

## Companion Skills

- **session-handoff**: Cold-start git sibling activity check (different concern)
- **think-twice**: Break out of stuck loops (different concern)
- **todo-management**: Source for pending task list
- **branch-sync-gate**: Resume an existing branch after a cold start

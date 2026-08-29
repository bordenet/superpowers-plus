# Knowledge Capture -- Scope & Resume Reference

Loaded on demand by `knowledge-capture` skill.

---

## When to Use

**Proactive mode:**
- User says "interview me about...", "capture my expertise on...", "I'm the expert on..."
- Knowledge lives in someone's head and needs to be captured durably
- User wants to document tribal/operational knowledge as a wiki article

**Reactive mode:**
- User says "turn this into wiki documentation", "formalize this discussion..."
- A conversation, debug session, or technical discussion has already happened
- User pastes notes, transcripts, or raw content and wants it structured as a wiki article

---

## Resume

On "resume knowledge-capture" or equivalent:
1. Check `~/.codex/knowledge-capture/` for state files.
2. List with topic, phase, and source mode. Ask: resume or abandon?
3. On resume: load state, continue from current phase.
4. On abandon: archive to `~/.codex/knowledge-capture/archive/`.

---

## Scope Exclusions

Do NOT use this skill for:
- Editing an existing wiki page -- use wiki editing
- Writing design docs or ADRs -- use brainstorming
- Fixing wiki formatting -- use wiki-verify
- Design exploration or brainstorming approaches -- use brainstorming
- General-purpose lightweight knowledge extraction without wiki output -- use expert-interviewer

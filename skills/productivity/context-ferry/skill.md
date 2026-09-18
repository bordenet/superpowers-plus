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
description: "Preserve a session before compaction: update its execution doc, capture pending questions and work, then save and print a resume prompt. PreCompact appends to its scaffold."
summary: "Before compaction, update durable state and save a self-contained resume prompt."
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

## Reference index

Load each named section before its step; load the others on demand.

| Need | Section |
|---|---|
| Diagnose hook behavior | Trigger mechanics |
| Full path, before writing | Output template |
| Full path, before saving | Fidelity and sensitive content |
| Choose a neighboring workflow | Companion skills |


# context-ferry

> Cold-start sibling activity -> `session-handoff`; stuck reasoning -> `think-twice`; task tracking -> `todo-management`.

Preserve verified state so a fresh session can resume without reconstructing this conversation.

## Trigger paths

| Trigger | Required path |
|---|---|
| Early-warning hook or manual invocation | Full sequence |
| PreCompact with generated scaffold | Abbreviated path only |
| PreCompact but scaffold missing | Full sequence fallback |

**PreCompact abbreviated path:** append only Key Decisions, Pending Questions, and Next 3 Actions to `~/context-ferry-<timestamp>.md`. Do NOT run the full sequence when that scaffold exists. If missing, use the full sequence.

Use `/context-ferry` manually where hooks are unavailable. Load `Trigger mechanics` only to diagnose a hook.

## Full sequence

Run in order. Write discrete blocks so partial work survives compaction.

1. **Update the execution doc.** Find the active plan/checklist; track completed, partial, or blocked work. Required when found. If several exist, update the most recently modified execution plan; list all candidates.
2. **Collect pending state.** Capture unanswered questions verbatim. The task file is authoritative; copy its incomplete work. Label memory-only tasks and unreadable sources; never invent content.
3. **Build the resume prompt.** Load `Output template` and fill each applicable field. If a question is pending, action 1 re-asks it.
4. **Apply handling signals.** Load `Fidelity and sensitive content`, record fidelity honestly, and add its warning for secrets or private data. Do not block or skip generation.
5. **Save and expose.** Write `~/context-ferry-<YYYY-MM-DD>T<HHMMss>.md`, print the complete prompt in a Markdown fence, and report the path. If writing fails, print it for the user to save.

Partial ferry is better than no ferry. If context becomes critical mid-sequence, save or print the completed blocks immediately.

## Safety invariants

- Durable sources outrank conversational recall.
- Never paraphrase an unanswered user question.
- Do not claim an execution doc is current unless it was updated in this run.
- At degraded fidelity, direct the new session to verify key decisions, files, branch, and status from Git or file reads.
- Preserve pending authority boundaries and approvals; do not infer new authorization for the resumed session.

## Reference loading

`Output template` and `Fidelity and sensitive content` are mandatory for the full path. Other sections are on demand.

<!-- kernel-split-reference-loader:start -->
```bash
_project_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
_ks_ref=""
for _candidate in \
  "$HOME/.claude/skills/context-ferry/reference.md" \
  "$HOME/.codex/skills/context-ferry/reference.md" \
  "$HOME/.agents/skills/context-ferry/reference.md"
do
  if [ -r "$_candidate" ]; then _ks_ref="$_candidate"; break; fi
done
_ks_loader="$HOME/.codex/superpowers-plus/tools/section-loader.sh"
_source_dir="$_project_root/skills/productivity/context-ferry"
if [ -z "$_ks_ref" ] && [ -n "$_project_root" ] && \
   [ -r "$_source_dir/skill.md" ] && [ -r "$_source_dir/reference.md" ] && \
   [ -r "$_project_root/tools/section-loader.sh" ]; then
  _ks_ref="$_source_dir/reference.md"
  _ks_loader="$_project_root/tools/section-loader.sh"
fi
[ -r "$_ks_ref" ] || { printf 'reference missing\n' >&2; exit 1; }
[ -r "$_ks_loader" ] || { printf 'section-loader missing\n' >&2; exit 1; }
_section='<section heading>'
bash "$_ks_loader" "$_ks_ref" "$_section" \
  || { printf 'section not found: %s\n' "$_section" >&2; exit 1; }
```
<!-- kernel-split-reference-loader:end -->

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

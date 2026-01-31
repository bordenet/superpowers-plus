# Session Resumption Pattern

> **Priority**: HIGH - For projects with complex state  
> **Source**: codebase-reviewer/docs/CLAUDE.md

## 🔄 READ THIS FIRST (In New Conversations)

BEFORE doing anything else in a new conversation/session:

1. ✅ **ALWAYS read `.resumption_state.md`** in the repository root
2. ✅ **Check current sprint, task state, and exact next steps**
3. ✅ **Review what NOT to do** (avoid recreating working code)
4. ✅ **Continue from the exact checkpoint**

## Resumption State File Format

Create `.resumption_state.md` at repo root:

```markdown
# Session Resumption State

> Last updated: YYYY-MM-DD HH:MM

## Current Sprint
[Sprint name/goal]

## Task State
- [x] Completed task 1
- [/] In-progress task (current step: X)
- [ ] Not started task

## Exact Next Steps
1. [Precise next action]
2. [Following action]

## DO NOT
- Do NOT recreate [specific file/feature that's working]
- Do NOT change [specific pattern that was decided]

## Context
[Brief context for what's been happening]
```

## When to Update

Update `.resumption_state.md`:
- At end of each work session
- Before known context switch
- After completing major milestones
- When blocked and leaving for user input

## When to Use This Pattern

Best for:
- Multi-day/multi-session projects
- Complex features with many steps
- Projects with specific decisions to preserve
- Team projects with handoffs

Not needed for:
- Quick one-off tasks
- Simple bug fixes
- Documentation updates


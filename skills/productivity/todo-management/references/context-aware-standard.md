# Context-Aware TODO Standard (Plan-Level Tasks)

When creating tasks that represent meaningful work units (not mechanical sub-steps), enforce these fields:

| Field | Required Content | Max Length | Skip For |
|-------|-----------------|-----------|----------|
| **Purpose** | WHY this task exists — what problem does completing it solve? | 1 line | Sub-steps that share parent context |
| **Trinity** | **WHY** (rationale), **WHAT** (deliverable), **HOW** (approach + file paths) | 1 bullet each (3 total) | Trivial tasks (< 5 min) |
| **Success Criteria** | Binary done/not-done — verifiable by command or state check | 1 bullet | Sub-steps with obvious completion |
| **Handoff State** | Branch, last commit, partial work, gotchas — enough for a fresh agent | 3 bullets max | Tasks that won't span sessions |

**When to enforce:** Any TODO tagged with `#plan-*` that could be picked up by a different agent. If a sub-step shares context with its parent, the parent carries the context fields.

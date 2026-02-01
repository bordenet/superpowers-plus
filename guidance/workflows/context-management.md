### Context Management

Manage context window effectively to prevent context rot and maximize signal-to-noise ratio.

#### Core Principles

1. **Context Rot**: Model accuracy degrades as context window fills. Prioritize high-signal tokens.

2. **Attention Budget**: LLMs have limited attention - each token depletes this budget.

3. **Right Altitude**: Instructions should be specific enough to guide behavior, flexible enough to generalize.

#### Progressive Disclosure Strategy

Load context in stages, not all upfront:

```
Level 1: Agents.md (always loaded)
  └── Essential rules, quality gates, banned phrases

Level 2: On-demand modules (loaded when relevant)
  └── Language-specific, project-type, workflow details

Level 3: Just-in-time retrieval (loaded per task)
  └── Code snippets, API docs, error context
```

#### When to Compact Context

Recognize these signals:
- Conversation exceeds 50 exchanges
- Repeated similar errors suggesting lost context
- Model asks for information already provided
- Responses become generic or off-target

#### Compaction Techniques

1. **Summarize, don't repeat**: Replace verbose history with structured summary
2. **Keep artifacts, drop discussion**: Preserve code/decisions, remove exploration
3. **Reference, don't inline**: Point to files instead of pasting large blocks
4. **Prune dead ends**: Remove failed approaches once resolved

#### Structured Note-Taking

For complex multi-step tasks, maintain notes:

```markdown
## Session Notes

### Current State
- Working on: [feature/bug description]
- Blockers: [if any]

### Key Decisions
1. [Decision + rationale]

### Pending Items
- [ ] Item 1
- [ ] Item 2

### Files Modified
- path/to/file.ext - [what was changed]
```

#### Session Resumption

When resuming after context switch or new session:

1. Load Agents.md (compact if available)
2. Review recent git commits: `git log --oneline -10`
3. Check modified files: `git status`
4. Load session notes if maintained
5. State current understanding before proceeding

#### Anti-Patterns to Avoid

| Anti-Pattern | Problem | Better Approach |
|--------------|---------|-----------------|
| Pasting entire files | Wastes tokens | Use view with line ranges |
| Repeating instructions | Context bloat | Reference Agents.md |
| Including full stack traces | Low signal | Extract relevant lines |
| Verbose error descriptions | Token waste | State error + hypothesis |

#### Token Budget Guidelines

| Context Size | Action |
|--------------|--------|
| < 50% window | Continue normally |
| 50-75% window | Start summarizing history |
| 75-90% window | Aggressive compaction |
| > 90% window | Fresh session with summary |


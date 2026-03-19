# Perplexity Research — Escalation Path

> Reference material for the `perplexity-research` skill.
> See `skill.md` for core agent guidance.

## "I'm Stuck" Escalation Path

Both `think-twice` and `perplexity-research` trigger on "I'm stuck". Use this decision tree:

```
"I'm stuck"
    │
    ├─► Is this a KNOWLEDGE problem?
    │   (API docs, error codes, library versions, facts)
    │   └─► Use perplexity-research FIRST (external knowledge)
    │       └─► Still stuck? → Use think-twice for fresh reasoning
    │
    └─► Is this a REASONING problem?
        (logic, approach, design, architecture)
        └─► Use think-twice FIRST (free, internal)
            └─► Still stuck? → Escalate to perplexity-research
```

**Default order:** `think-twice` → `perplexity-research`
- Think-twice is free and instant
- Perplexity costs money and requires justification (Step 0: try free tools first)
- For pure reasoning problems, external research won't help

**See also:** `think-twice` skill for fresh perspective via sub-agent consultation


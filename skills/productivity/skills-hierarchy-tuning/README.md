# Skills Hierarchy Tuning

Meta-skill for maintaining the skills directory structure and progressive loading system.

## When to Invoke

- ADR-001 review triggers fire (structural, operational, or usability signals)
- Domain grows beyond 8 skills
- Skill exceeds 200 lines
- Module loading failures occur
- Quarterly hierarchy review

## Invocation

```bash
node ~/.codex/superpowers-augment/superpowers-augment.js use-skill superpowers:skills-hierarchy-tuning
```

Or trigger phrases:
- "Review skills hierarchy"
- "Rebalance skill domains"
- "Tune loading triggers"
- "ADR-001 review"

## Related Documentation

| Resource | Purpose |
|----------|---------|
| [ADR-001](https://wiki.int.[company].net/doc/adr-001-skills-directory-structure-dP99DPNhJf) | Decision record with review triggers |
| [Refactoring (AI-Maintained)](https://wiki.int.[company].net/doc/refactoring-ai-maintained-2nV606J5uY) | Progressive loading implementation |
| [Superpowers Skills](https://wiki.int.[company].net/doc/superpowers-skills-cASQJAkNFD) | Skills overview |

## Author

Created 2026-02-13 by Augment Agent during progressive loading refactor.

Captures institutional knowledge for future AI agents to maintain the hierarchy.


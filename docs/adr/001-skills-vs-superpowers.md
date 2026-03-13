# ADR-001: Skills vs Superpowers Taxonomy

**Status:** Accepted  
**Date:** 2026-03-13  
**Decision Makers:** @bordenet  

## Context

The codebase uses "skill" and "superpower" interchangeably, causing confusion:

- The upstream repository is named [obra/superpowers](https://github.com/obra/superpowers)
- Everything inside is called "skills" (directory names, file names, documentation)
- Some skills have `triggers: [...]` in frontmatter, others don't
- No formal distinction existed between auto-triggered and explicit-invocation behaviors
- User queries like "What are my superpowers?" vs "What skills do I have?" had no clear answer

## Decision

Establish a formal taxonomy distinguishing two types of skills:

| Term | Definition | Frontmatter | Behavior |
|------|------------|-------------|----------|
| **Superpower** | A skill with auto-triggers | `triggers: ["phrase1", "phrase2"]` | AI auto-invokes when trigger phrases detected |
| **Explicit Skill** | A skill without triggers | `triggers: []` or absent | Must be explicitly invoked by name |

### Detection Rule

```javascript
const isSuperpower = skill.triggers && skill.triggers.length > 0;
```

### User Query Mapping

| User Says | Response |
|-----------|----------|
| "What are my superpowers?" | List only auto-triggered skills (with triggers) |
| "What skills do I have?" | List all skills, categorized |
| "Run [skill-name]" | Load and execute the specific skill |

## Consequences

### Positive

1. **Clear user mental model** — Users understand superpowers "just work" while explicit skills require invocation
2. **Better discoverability** — `find-skills superpowers` vs `find-skills explicit` 
3. **Reduced validator noise** — Explicit skills no longer flagged as "missing triggers"
4. **Backward compatible** — No breaking changes to existing skills

### Negative

1. **Terminology divergence** — obra/superpowers doesn't use this taxonomy
2. **Maintenance overhead** — `EXPLICIT_SKILLS` array in validator must be updated

### Neutral

1. **No code behavior change** — Auto-triggering is AI-side behavior, not wrapper-side
2. **Upstream compatibility preserved** — obra/superpowers skills work unchanged

## Implementation

### Files Changed

| File | Change |
|------|--------|
| `superpowers-augment.js` | Extract `triggers` from frontmatter, add `isSuperpower` flag, support `find-skills superpowers|explicit` |
| `docs/ARCHITECTURE.md` | Add "Terminology" section, clarify frontmatter fields |
| `docs/CONTRIBUTING.md` | Add "Superpowers vs Explicit Skills" guidance |
| `skills/productivity/superpowers-help/skill.md` | Distinguish types in output |
| `tools/skill-trigger-validator.sh` | Add `EXPLICIT_SKILLS` array, skip them in "missing triggers" check |

### New Commands

```bash
# List all skills (categorized)
node ~/.codex/superpowers-augment/superpowers-augment.js find-skills

# List only superpowers (auto-triggered)
node ~/.codex/superpowers-augment/superpowers-augment.js find-skills superpowers

# List only explicit skills
node ~/.codex/superpowers-augment/superpowers-augment.js find-skills explicit
```

## Alternatives Considered

### 1. Rename everything to "skills" only

Rejected — "superpowers" is the upstream brand and provides useful distinction.

### 2. Add `type: superpower|explicit` to frontmatter

Rejected — Redundant with `triggers` presence. Would require updating all existing skills.

### 3. Implement auto-triggering in the wrapper

Rejected — Auto-triggering is an AI-side behavior based on pattern matching. The wrapper just loads skills on demand.

## References

- [obra/superpowers](https://github.com/obra/superpowers) — Upstream framework
- [ARCHITECTURE.md](../ARCHITECTURE.md) — Updated with taxonomy
- [CONTRIBUTING.md](../CONTRIBUTING.md) — Updated with guidance

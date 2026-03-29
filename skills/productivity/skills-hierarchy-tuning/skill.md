---
name: skills-hierarchy-tuning
source: superpowers-callbox
description: Use when reviewing skill organization, rebalancing domains, adjusting loading triggers, or responding to ADR-001 review signals. Triggers on "reorganize skills", "skill hierarchy needs adjustment", "too many skills in domain", "split this skill folder", "domain rebalancing".
summary: "Use when: adjusting skill priority, composition, or trigger hierarchy."
triggers: ["reorganize skills", "skill hierarchy needs adjustment", "too many skills in domain", "split this skill folder", "domain rebalancing"]
coordination:
  group: productivity
  order: 1
  requires: []
  enables: []
  escalates_to: []
  internal: false
---

# Skills Hierarchy Tuning

> **Context:** [ADR-001](https://wiki.int.callbox.net/doc/adr-001-skills-directory-structure-dP99DPNhJf) | [Refactoring (AI-Maintained)](https://wiki.int.callbox.net/doc/refactoring-ai-maintained-2nV606J5uY)

---

## When to Invoke

| Trigger | Action |
|---------|--------|
| "skills audit" | Full hierarchy review |
| "domain too big" | Domain has >8 skills |
| "can't find skill for X" | Discovery failing |
| "wrong skill loaded" | Trigger mismatch |
| "skills not firing" | Module loading issues |

---

## Step 1: Gather Current State

```bash
# Count skills per domain
for domain in */; do
  [ -d "$domain" ] && [ "$domain" != "_shared/" ] && [ "$domain" != "_archive/" ] && \
  echo "$domain: $(find "$domain" -name "skill.md" | wc -l | tr -d ' ') skills"
done

# Identify oversized skills
find . -name "skill.md" -exec wc -l {} \; | sort -rn | head -20
```

---

## Step 2: Check ADR-001 Review Triggers

| Category | Signal | Threshold |
|----------|--------|-----------|
| Structural | Domain >8 skills | Any domain |
| Structural | Orphan skills | >2 orphans |
| Operational | "File not found" errors | >3 in 1 week |
| Operational | Wrong skill loaded | >2 occurrences |
| Loading | Module path errors | >3 in 1 week |

---

## Step 3: Diagnose & Fix

| Problem | Symptoms | Solution |
|---------|----------|----------|
| **Domain too large** | >8 skills, hard to find | Split into sub-domains |
| **Skill too large** | >250 lines, AI misses rules | Extract to `references/` directory |
| **Module not loading** | Trigger doesn't fire | Make triggers more explicit with action words |
| **Shared module conflicts** | Two skills need variations | Use skill-specific sections in shared module |

---

## Step 4: Execute

**Moving skills:** `mv old-domain/skill/ new-domain/skill/` → run `install.sh` → update cross-references

**Creating domains:** `mkdir new-domain` → move skills → `install.sh` auto-discovers

**Extracting references:** Move sections >50 lines to `references/*.md`, add pointer in core skill

**After changes:** Run `install.sh`, update wiki pages, commit and push.

See `references/procedures.md` for detailed commands and examples.

---

## Key Metrics

| Metric | Target |
|--------|--------|
| Core skill.md | ≤250 lines |
| Reference files | ≤150 lines each |
| Critical rules | First 30 lines |
| Domains | 3-8 skills each |

---


## Failure Modes

| Mode | Symptom | Recovery |
|------|---------|----------|
| Misconfigure triggers | Wrong skill fires | Test anti_triggers after changes |

## References

| File | Contents |
|------|----------|
| `references/procedures.md` | Detailed rebalancing commands, module extraction steps, historical context |

## Common Failure Modes

- **Breaking existing triggers:** Changing hierarchy in a way that orphans existing skill trigger routes
- **Circular dependencies:** Creating skill A → B → A reference loops
- **Missing parent skills:** Adding child skills without updating the parent orchestrator

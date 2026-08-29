---
name: skills-hierarchy-tuning
source: superpowers-plus
augment_menu: true
description: Use when reviewing skill organization, rebalancing domains, adjusting loading triggers, or responding to structural review signals. Triggers on "reorganize skills", "skill hierarchy needs adjustment", "too many skills in domain", "split this skill folder", "domain rebalancing".
summary: "Use when: adjusting skill priority, composition, or trigger hierarchy."
triggers: ["/sp-skills-hierarchy-tuning", "reorganize skills", "skill hierarchy needs adjustment", "too many skills in domain", "split this skill folder", "domain rebalancing"]
coordination:
  group: engineering
  order: 1
  requires: []
  enables: []
  escalates_to: []
  internal: false
composition:
  produces: []
  consumes: [user-intent]
  capabilities: []
  priority: 50
  optional: false
  requires_all: false
---

# Skills Hierarchy Tuning

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

## Step 2: Check Review Triggers

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

**Moving skills:** `mv old-domain/skill/ new-domain/skill/` → re-run your install/deploy mechanism → update cross-references

**Creating domains:** `mkdir new-domain` → move skills → your install auto-discovers

**Extracting references:** Move sections >50 lines to `references/*.md`, add pointer in core skill

**After changes:** Re-run install, update any documentation that lists skills or counts, commit and push.

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
| Breaking existing triggers | Changing hierarchy orphans trigger routes | Audit all trigger strings before and after a move |
| Circular dependencies | Skill A → B → A reference loops | Draw the dependency graph before restructuring |
| Missing parent skills | Child skills added without updating orchestrator | Check all `escalates_to` / `enables` references after a move |

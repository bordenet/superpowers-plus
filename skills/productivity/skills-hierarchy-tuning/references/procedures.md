# Skills Hierarchy Tuning — Detailed Procedures

## Moving a Skill to Different Domain

```bash
# 1. Move the skill
mv old-domain/skill-name/ new-domain/skill-name/

# 2. Verify install.sh still discovers it
./install.sh

# 3. Update any cross-references
grep -r "old-domain/skill-name" --include="*.md" .

# 4. Commit
git add -A && git commit -m "refactor: move skill-name from old-domain to new-domain"
```

## Creating a New Domain

```bash
mkdir new-domain
mv skill-a/ new-domain/
mv skill-b/ new-domain/
./install.sh  # auto-discovers
```

Update wiki: Superpowers Skills page, ADR-001 if significant.

## Extracting References from Oversized Skill

1. **Identify candidates:** Sections >50 lines on single topic, content only needed for specific triggers
2. **Create:** `mkdir -p skill-name/references && # move content`
3. **Update core:** Add pointer table, verify total ≤250 lines
4. **Test:** `node ~/.codex/superpowers-augment/superpowers-augment.js use-skill superpowers:<skill-name>`

## Post-Change Documentation

1. Run `install.sh` — verify auto-discovery
2. Update wiki pages:
   - [Superpowers Skills](https://wiki.int.callbox.net/doc/superpowers-skills-cASQJAkNFD)
   - [Refactoring (AI-Maintained)](https://wiki.int.callbox.net/doc/refactoring-ai-maintained-2nV606J5uY)
3. Update ADR-001 if decision criteria change
4. Commit and push

---

## Problem Diagnosis Details

### Problem A: Domain Too Large (>8 skills)

```
# Example: If a domain grows to 10+ skills
large-domain/
├── sub-domain-a/       ← New sub-domain
│   ├── skill-one/
│   └── skill-two/
└── sub-domain-b/       ← New sub-domain
    ├── skill-three/
    └── candidate-tracker/
```

### Problem B: Skill Too Large (>250 lines)

Extract to `references/` directory. The core skill points to reference files with a table.

### Problem C: Module Not Loading

- Is trigger phrase in loading table clear?
- Is module path correct?
- Make triggers explicit: ❌ vague keywords → ✅ "When user says '<specific-phrase>'"

### Problem D: Shared Module Conflicts

Use skill-specific sections in shared module.

---

## Historical Context

### The Original Problem (2026-02-10)

AI created 5 duplicate wiki pages despite `outline-wiki-editing` containing a duplicate-check rule at line 191. Rule was ignored due to context window bloat:

- 50-line skill: AI follows all rules
- 500-line skill: Important context crowded out
- 1000-line skill: AI misses half the rules

### The Solution: Progressive Loading + References

Small core (≤250 lines) with references directory. Critical rules in first 30 lines.

### ADR-001 Signal Thresholds

| Category | Signal | Threshold |
|----------|--------|-----------|
| Structural | Domain >8 skills | Any domain |
| Structural | Orphan skills | >2 orphans |
| Structural | Cross-domain skill | >1 occurrence |
| Operational | "File not found" | >3 in 1 week |
| Operational | Wrong skill loaded | >2 occurrences |
| Loading | Module path errors | >3 in 1 week |
| Loading | Shared module missing | >2 occurrences |
| Loading | Catch-all firing too often | >50% of invocations |

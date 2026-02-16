# Critical Invariants — Always Follow

> **Load at START of every conversation.**

## Self-Management Protocol

After editing ANY guidance file, run: `wc -l Agents.md .ai-guidance/*.md 2>/dev/null`

| File | Limit | Action if exceeded |
|------|-------|-------------------|
| `Agents.md` | 250 lines | Extract to `.ai-guidance/*.md` |
| `.ai-guidance/*.md` | 250 lines | Split into sub-directory |

**If threshold exceeded:** STOP → Refactor (zero data loss) → Verify → Resume

## Zero Data Loss Checklist

- [ ] Snapshot captured: `cat <file> > /tmp/original.md`
- [ ] Every section accounted for in new structure
- [ ] No rules deleted (only moved/split)
- [ ] Diff shows reorganization, not deletion

## Refactoring Steps

**Agents.md → .ai-guidance/:**
1. Snapshot → `mkdir -p .ai-guidance` → Classify by topic
2. Extract to sub-files (≤250 lines each) → Update loading table
3. Verify: `wc -l Agents.md` ≤250

**Sub-file → sub-directory** (e.g., `testing.md` exceeds 250 lines):
1. `mkdir -p .ai-guidance/testing`
2. Split into topic files (`unit.md`, `integration.md`, etc.)
3. Replace original with index referencing sub-files
4. Verify: each file ≤250 lines

**Recovery:** If verification fails, restore from `/tmp/original.md`


---
name: skill-health-check
source: superpowers-plus
triggers: ["skill health", "skill regression", "validate skills", "check skill quality",
           "skill coverage report", "are skills healthy"]
description: "Validates all skills have required structure: YAML frontmatter, coordination metadata, failure modes, cross-references, and line count limits. Reports coverage gaps and structural regressions. Run periodically or after bulk skill changes."
summary: "Use when: checking skill ecosystem health after changes or periodically."
coordination:
  group: observability
  order: 3
  requires: []
  enables: ["superpowers-doctor"]
  escalates_to: []
  internal: false
---

# Skill Health Check

> **Purpose:** Detect structural regressions across the skill ecosystem.

**Announce at start:** "I'm running the **skill-health-check** to validate skill ecosystem health."

## When to Use

- After creating or modifying skills
- Periodically (weekly or before releases)
- When `harsh-review.sh` reports skill count drift

## Checks

### Check 1: YAML Frontmatter
Every `skill.md` must have valid YAML frontmatter with required fields:
- `name` (string)
- `source` (string)
- `triggers` (array, non-empty)
- `description` (string)

### Check 2: Coordination Metadata
Every `skill.md` should have `coordination:` block with:
- `group` (string)
- `order` (number)
- `requires` (array)
- `enables` (array)
- `escalates_to` (array)
- `internal` (boolean)

### Check 3: Failure Modes
Every `skill.md` should have a `## Failure Modes` section with a table of at least 2 rows.

### Check 4: Line Count
No `skill.md` should exceed 250 lines.

### Check 5: Cross-References
Skills that reference other skills by name should reference skills that actually exist.

### Check 6: README Consistency
The README.md skill count and domain counts should match the actual filesystem.

## Running the Check

```bash
# Quick check via harsh-review.sh (checks 4 + 6)
bash tools/harsh-review.sh

# Full ecosystem health
python3 -c "
import yaml, os, sys
skills_dir = 'skills'
errors, warnings = [], []
for root, dirs, files in os.walk(skills_dir):
    for f in files:
        if f != 'skill.md': continue
        path = os.path.join(root, f)
        with open(path) as fh: content = fh.read()
        parts = content.split('---')
        if len(parts) < 3:
            errors.append(f'{path}: No YAML frontmatter')
            continue
        data = yaml.safe_load(parts[1])
        # Check 1: Required fields
        for field in ['name', 'source', 'triggers', 'description']:
            if field not in data:
                errors.append(f'{path}: Missing {field}')
        # Check 2: Coordination
        if 'coordination' not in data:
            warnings.append(f'{path}: Missing coordination metadata')
        # Check 3: Failure modes
        if '## Failure Modes' not in content:
            warnings.append(f'{path}: Missing Failure Modes section')
        # Check 4: Line count
        lines = content.count('\n')
        if lines > 250:
            errors.append(f'{path}: {lines} lines (max 250)')
for e in errors: print(f'ERROR: {e}')
for w in warnings: print(f'WARN:  {w}')
print(f'\n{len(errors)} errors, {len(warnings)} warnings')
"
```

## Failure Modes

| Failure | Fix |
|---------|-----|
| New skill created without running health check | Run after every skill creation — catches missing fields immediately |
| README count drifted | Update README counts when adding/removing skills |
| Cross-reference points to renamed/deleted skill | Search for old skill name across all `skill.md` files |

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

## Running the Check

```bash
# Quick check (skill count + line limits)
bash tools/harsh-review.sh

# Full ecosystem health (checks 1-4, uses Ruby YAML parser)
ruby -ryaml -e '
  errors = []; warnings = []
  Dir.glob("skills/**/skill.md").each do |path|
    content = File.read(path)
    parts = content.split("---", 3)
    if parts.length < 3
      errors << "#{path}: No YAML frontmatter"; next
    end
    data = YAML.safe_load(parts[1]) rescue (errors << "#{path}: Invalid YAML"; next)
    %w[name source triggers description].each do |f|
      errors << "#{path}: Missing #{f}" unless data&.key?(f)
    end
    warnings << "#{path}: Missing coordination" unless data&.key?("coordination")
    warnings << "#{path}: Missing Failure Modes" unless content.include?("## Failure Modes")
    lines = content.count("\n")
    errors << "#{path}: #{lines} lines (max 250)" if lines > 250
  end
  errors.each { |e| puts "ERROR: #{e}" }
  warnings.each { |w| puts "WARN:  #{w}" }
  puts "\n#{errors.length} errors, #{warnings.length} warnings"
'
```

## Failure Modes

| Failure | Fix |
|---------|-----|
| New skill created without running health check | Run after every skill creation — catches missing fields immediately |
| README count drifted | Update README counts when adding/removing skills |
| Cross-reference points to renamed/deleted skill | Search for old skill name across all `skill.md` files |

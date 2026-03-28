---
name: skill-health-check
source: superpowers-plus
triggers: ["skill lint", "skill structure check", "validate skill yaml", "skill regression test",
           "skill coverage report"]
anti_triggers: ["doctor", "diagnose", "runtime skill issue"]
description: "Cheap structural lint for skill files: validates YAML frontmatter has required fields, checks line count limits, and reports missing coordination metadata and Failure Modes sections as warnings. Does NOT check runtime behavior (use superpowers-doctor for that)."
summary: "Use when: checking skill file structure after bulk changes. For runtime diagnostics use superpowers-doctor."
coordination:
  group: observability
  order: 1
  requires: []
  enables: []
  escalates_to: ["superpowers-doctor"]
  internal: false
---

# Skill Health Check

> **Purpose:** Cheap structural lint for skill files. Not a runtime diagnostic.

**Announce at start:** "I'm running the **skill-health-check** structural lint."

## When to Use

- After creating or modifying skills
- After bulk skill changes (marathons, domain redesigns)
- NOT for: runtime issues, install problems, broken tool paths (use `superpowers-doctor`)

## What It Checks

| Check | Severity | What it validates |
|-------|----------|-------------------|
| YAML frontmatter | ERROR | `name`, `source`, `triggers`, `description` fields present |
| Line count | ERROR | No `skill.md` exceeds 250 lines |
| Coordination metadata | WARN | `coordination:` block present (presence only, not semantic validity) |
| Failure modes section | WARN | `## Failure Modes` heading present (presence only) |

**What it does NOT check:** coordination semantic validity, cross-reference accuracy, runtime behavior, install state. Those are `superpowers-doctor` territory.

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

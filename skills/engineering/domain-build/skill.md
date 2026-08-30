---
name: domain-build
source: superpowers-plus
augment_menu: true
triggers: ["/sp-domain-build", "build the P0 skills", "implement the domain design", "ship the walking skeleton", "build domain skills", "execute domain plan"]
description: Use when building, deploying, and documenting skills from a completed domain-design output. Handles the walking skeleton -> remaining P0s -> cookbook -> handoff cycle.
summary: "Use when: building skills from a completed domain-design output. Counterpart to domain-design."
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

# Domain Build -- Build, Deploy, Document

> **Purpose:** Execute the build/deploy/document cycle for a designed skill domain.
> **Prerequisite:** A completed `domain-design` output -- prioritized skill roster, architecture decision, infrastructure map.

**Announce at start:** "I'm using the **domain-build** skill to implement the designed domain."

## TODO Persistence

Use `todo-management` skill for all 4 phases. Tag tasks `#plan-build-{domain}`. Track each phase + post-build gates.

---

## The 4-Phase Process

**Input from `domain-design`:** P0-P3 roster + architecture decision + walking skeleton design.

### Phase 1: WALKING SKELETON

Build the simplest P0 skill to prove the full pattern end-to-end.

1. Create `skills/{domain}/{skill-name}/skill.md` with frontmatter:
   ```yaml
   ---
   name: skill-name
   source: superpowers-plus
   triggers: [...]
   description: Use when...
   ---
   ```
2. Include the verified query/API call from the domain design.
3. Define the output format the agent should produce.
4. Install/deploy the skill per your overlay's install mechanism.
5. Verify the skill is discoverable: run the discovery command for your skill system.
6. Test against a real data source (not mocked/fabricated output).
7. Commit and push.

**Gate:** Walking skeleton must be discoverable AND return real data before proceeding.

### Phase 2: REMAINING P0s

For each remaining P0 skill in the roster:

1. Create `skills/{domain}/{skill-name}/skill.md`.
2. Deploy: run the install mechanism.
3. Verify discoverable.
4. Test against real data.
5. Commit and push.

Batch commits are acceptable for remaining P0s.

### Phase 3: COOKBOOK

Create documentation with real-world recipes. For each P0 skill, write one recipe with:

- **When to use** -- scenario description
- **Ask the agent** -- exact prompt to copy-paste
- **What you get back** -- real output (run the actual query, do not fabricate)
- **Behind the scenes** -- the query/API call

Add a "Chaining Recipes" section showing multi-skill workflows.
Add a "What's Coming Next" section: blocked skills + their ticket links + owners.

Publish to your team's documentation platform nested under the design document.

**Data freshness:** All examples MUST use real data from the current session.

### Phase 4: HANDOFF

1. **Design document:** Mark P0 skills as Shipped with dates. Update file layout. Verify all ticket links.
2. **Tracking page:** Add build phase rows. Add "What's Blocked" with ticket details. Update Key Findings.
3. **Repo:** All skills committed and pushed. Skills discoverable via your install system.
4. **Report to user:** Table of skills + status, blockers with tickets + owners, documentation links.

---

## Hard Limits

**250-line cap for skill.md:** If a skill exceeds 250 lines, split into `skill.md` (core, <=250L) + `examples.md` + `references/*.md`. Verify: `wc -l skills/{domain}/{skill-name}/skill.md`.

---

## Completion Checklist

Do NOT report "Domain Build Complete" until ALL items are checked.

### Per-Skill Gates
- [ ] `skill.md` created with valid YAML frontmatter
- [ ] `skill.md` is under 250 lines (`wc -l`)
- [ ] Install/deploy exits 0
- [ ] Skill is discoverable via the skill system
- [ ] Tested against real data (no fabricated output)
- [ ] Committed and pushed

### Documentation
- [ ] **Design document** -- P0 skills marked Shipped with dates, file layout updated
- [ ] **Tracking page** -- build phase rows added, blockers current
- [ ] **Cookbook** -- published with real data from the current session
- [ ] **Skills index** (if applicable) -- new skills listed with trigger conditions
- [ ] **Skill count** -- any file that states a total skill count is updated

## Failure Modes

| Mode | Symptom | Recovery |
|------|---------|----------|
| Fabricated test output | Skill "works" in demo but fails in production | Always run against real data; never mock |
| Skipped validation | Build fails silently | Verify discovery + real-data test before claiming done |
| Cookbook uses stale data | Recipes mislead users | Pull fresh data during the current session |
| Incomplete checklist | "Done" declared prematurely | The checklist is a hard gate; partial completion = not done |

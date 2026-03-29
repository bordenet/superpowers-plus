---
name: domain-build
source: superpowers-[company]
triggers: ["build the P0 skills", "implement the domain design", "ship the walking skeleton", "build domain skills", "execute domain plan"]
description: Use when building, deploying, and documenting skills from a completed domain-design output. Handles the walking skeleton → remaining P0s → cookbook → handoff cycle. Specific to [Company]'s superpowers-[company] deployment pipeline.
summary: "Use when: building skills from a completed domain-design output. [Company]-specific."
coordination:
  group: [company]
  order: 1
  requires: []
  enables: []
  escalates_to: []
  internal: false
---

# Domain Build — Build, Deploy, Document

> **Purpose:** Execute the build/deploy/document cycle for a designed skill domain.
> **Prerequisite:** A completed `domain-design` output (prioritized skill roster, architecture decision, infrastructure map).
> **Origin:** Codified from the Call Review Domain build phase (March 2026).

**Announce at start:** "I'm using the **domain-build** skill to implement the designed domain."

## ⛔ TODO.md Persistence

> **Full protocol:** See the `todo-management` skill — covers preflight, lock/write/release, phase completion, and cross-session recovery.

**Domain-build specific:** Use `#plan-build-{domain}` tags for all 4 phases + post-build gates. Mirror to MCP as supplementary.

## The Process (4 Phases)

**Input:** P0-P3 roster + architecture decision + walking skeleton design + wiki URL from `domain-design`.

### Phase 1: WALKING SKELETON

Build the simplest P0 skill to prove the full pattern end-to-end.

1. Create `[company]/{skill-name}/skill.md` with proper frontmatter:
   ```yaml
   ---
   name: skill-name
   source: superpowers-[company]
   triggers: [...]
   description: Use when...
   ---
   ```
2. Include the verified SQL query / API call from the domain design
3. Define the output format the agent should use
4. Update `lib/install/summary.sh` with the new skill
5. Run `./install.sh --verbose --skip-secrets`
6. Verify: `node ~/.codex/superpowers-augment/superpowers-augment.js find-skills | grep {skill-name}`
7. Test against prod with a real query
8. Commit and push to GitLab

**Gate:** Walking skeleton must be discoverable via `find-skills` AND return real data from prod before proceeding.

### Phase 2: REMAINING P0s

For each remaining P0 skill in the roster:

1. Create `[company]/{skill-name}/skill.md`
2. Deploy: `./install.sh --verbose --skip-secrets`
3. Verify: `find-skills | grep {skill-name}`
4. Test against prod
5. Commit and push

**Batch commits are acceptable** for remaining P0s (unlike the walking skeleton, which gets its own commit).

### Phase 3: COOKBOOK

Create a wiki page nested under the design document with real-world recipes.

1. For each P0 skill: write one recipe with:
   - **When to use** — scenario description
   - **Ask the agent** — exact prompt to copy-paste
   - **What you get back** — real prod output (run the actual query)
   - **Behind the scenes** — the SQL/API call
2. Add a "Chaining Recipes" section showing multi-skill workflows
3. Add a "What's Coming Next" section with:
   - Blocked skills + their Linear ticket links
   - Direct callouts to specific people who own blockers
4. Publish via `create_document_outline` nested under design doc

**Data freshness:** All examples MUST use real data from the current day. Do not fabricate output.

### Phase 4: HANDOFF

Update all documentation to reflect completion:

1. **Design document (wiki):**
   - Mark P0 skills as ✅ Shipped with dates
   - Update file layout to show actual paths
   - Verify all Linear ticket links are integrated into P1 blocker tables

2. **Tracking page (wiki):**
   - Add build phase rows (one per P0 skill + cookbook)
   - Add "What's Blocked" section with Linear ticket details
   - Update Key Findings with any build-phase discoveries

3. **GitLab repo:**
   - All skills committed and pushed
   - `summary.sh` lists all new skills

4. **Report to user:** Table of skills + status, blockers with Linear tickets + owners, wiki links (design doc, cookbook, tracking).

## ⛔ Skill File Size — HARD LIMIT: 250 lines

If >250 lines, split: `skill.md` (core ≤250L) + `examples.md` + `references/*.md`. Verify: `wc -l [company]/{skill-name}/skill.md`.

## Deployment Checklist (per skill)

From `CLAUDE.md` — mandatory for every skill:

- [ ] Create `[company]/{skill-name}/skill.md` with frontmatter
- [ ] Verify `skill.md` is under 250 lines: `wc -l [company]/{skill-name}/skill.md`
- [ ] Update `lib/install/summary.sh` domain listing
- [ ] Run `./install.sh --verbose --skip-secrets`
- [ ] Verify via `find-skills`: `node ~/.codex/superpowers-augment/superpowers-augment.js find-skills | grep {skill-name}`
- [ ] Test against prod with a real query
- [ ] Commit and push to GitLab

## ⛔ Post-Build Documentation Sync — HARD GATE

After ALL skills are built and before reporting completion, you MUST update every downstream document. Do NOT report "Domain Build Complete" until every item is checked.

### Repo-Level Documentation

- [ ] **`lib/install/summary.sh`** — Every new skill appears in the domain listing
- [ ] **`CLAUDE.md`** — If new triggers or deployment patterns were introduced, update the checklist
- [ ] **Skill count** — If any README, AGENTS.md, or wiki page states a total skill count (e.g., "97 total skills"), update it. Run `find-skills` and count the output.

### Wiki Documentation

- [ ] **Superpowers Skills index page** (`https://wiki.int.[company].net/doc/superpowers-skills-cASQJAkNFD`) — Add each new skill with its trigger condition to the appropriate domain table
- [ ] **Domain design document** — P0 skills marked ✅ Shipped with dates, file layout updated
- [ ] **Domain tracking page** — Build phase rows added, blocker section current
- [ ] **Cookbook** — Published with real prod data

### Verification

`./install.sh --verbose --skip-secrets` → `find-skills | grep {skill}` → `grep -c "[company]:" lib/install/summary.sh`. **If ANY item unchecked, do not report completion.**

## Failure Modes

| Mode | Symptom | Recovery |
|------|---------|----------|
| Skip validation | Build fails silently | Verify build output before proceeding |

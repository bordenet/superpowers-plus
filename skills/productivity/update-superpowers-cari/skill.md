---
name: update-superpowers-[product]
source: superpowers-[product]
triggers: ["update my [product] superpowers", "update superpowers", "upgrade superpowers", "pull superpowers", "refresh superpowers", "update skills", "upgrade skills", "sp-update", "superpowers-update"]
anti_triggers: ["install superpowers", "uninstall superpowers"]
description: "Pull latest changes across all superpowers repos (including [product] + recruiting), run the full install chain, and fix any issues found by sp-doctor. Overrides the base update-superpowers from superpowers-[company]."
summary: "Use when: updating all superpowers repos to latest and ensuring the full skill chain is healthy."
coordination:
  group: [product]
  order: 1
  requires: []
  enables: []
  escalates_to: []
  internal: false
---

# Update My [Product] Superpowers

> **Override:** This skill replaces the base `update-superpowers` from `superpowers-[company]`. It adds superpowers-[product] and superpowers-[product] repos, and runs the install from superpowers-[product] (which cascades through the full chain).

Pulls latest from all superpowers source repos, runs the cascading install, and heals any drift via sp-doctor.

## When to Use

- User says "update my superpowers" or "upgrade skills"
- After a known change has been pushed to any superpowers repo
- Periodic maintenance to stay current

## Procedure

Run each step in order. Failure handling varies by step — see rules below.

### Step 1: Pull all superpowers source repos

Pull each repo from its correct remote. **Order matters** — upstream repos first, overlays last.

```bash
source ~/.codex/.env

# 1a. obra/superpowers (upstream base)
cd ~/.codex/superpowers && git pull origin main --ff-only

# 1b. superpowers-plus (GitHub is source of truth)
cd "${SPP_SOURCE_DIR:-$HOME/.codex/superpowers-plus}" && git pull upstream main --ff-only

# 1c. superpowers-[company] (discovered from .env)
cd "$SPC_SOURCE_DIR" && git pull origin main --ff-only

# 1d. superpowers-[product] (discovered from .env)
cd "$PRODUCT_SOURCE_DIR" && git pull origin main --ff-only

# 1e. superpowers-[product] (discovered from .env)
cd "$SPR_SOURCE_DIR" && git pull origin main --ff-only
```

**Rules:**
- Always `source ~/.codex/.env` first — paths come from `SPC_SOURCE_DIR`, `PRODUCT_SOURCE_DIR`, `SPR_SOURCE_DIR`, etc.
- Always use `--ff-only` — never create merge commits during update
- If ff-only fails due to **uncommitted local changes**: warn the user, **skip that repo**, continue with the rest
- If ff-only fails due to **diverged history**: **stop entirely** and report. Do NOT force-pull or reset. The user must resolve manually.
- superpowers-plus pulls from `upstream` (GitHub), NOT `origin` (GitLab). See `~/git/.ai-guidance/superpowers-plus-workflow.md`.

### Step 2: Run the cascading install

```bash
cd "$PRODUCT_SOURCE_DIR" && bash install.sh --upgrade
```

This cascades: `obra/superpowers → superpowers-plus → superpowers-[company] → superpowers-[product]` (superpowers-[product] is pulled in Step 1 but has no install chain dependency — its skills are standalone)

All skills are installed to `~/.codex/skills/` and `~/.claude/skills/`.

### Step 3: Run sp-doctor and fix issues

```bash
bash ~/.codex/superpowers-plus/tools/doctor-checks.sh --fix --yes
```

This runs all diagnostic checks and auto-fixes:
- Sync drift between source and installed copies
- CRLF / BOM issues
- Name mismatches in skill frontmatter
- Missing or stale reference files
- Deprecated trigger patterns

- If the doctor **command itself fails to run** (non-zero exit, crash) → stop and report to user
- If doctor **runs successfully but reports unfixable findings** → report findings, continue to Step 4

### Step 4: Verify

```bash
node ~/.codex/superpowers-augment/superpowers-augment.js bootstrap
```

Confirm skills load successfully. Report the skill count to the user.

## For Agents

When the user says "update my superpowers":

1. Run Step 1 (all pulls) — report each repo's result
2. Run Step 2 (install --upgrade) — report success/failure
3. Run Step 3 (doctor --fix) — report findings and fixes
4. Run Step 4 (bootstrap) — confirm skill count
5. Summarize: repos updated, skills installed, doctor findings

Failure handling per step:
- **Step 1 pull fails (dirty worktree):** warn, skip that repo, continue
- **Step 1 pull fails (diverged history):** stop entirely, report to user
- **Step 2 install fails:** stop, report to user (install chain is sequential)
- **Step 3 doctor command crashes/fails to run:** stop, report to user
- **Step 3 doctor runs but reports unfixable findings:** continue to Step 4, report findings to user

## Important Notes

- This skill does NOT push anything. It only pulls and installs locally.
- superpowers-plus has a special workflow (GitHub-first). This skill only pulls; it never pushes to GitLab origin.
- After updating, any new skills or triggers are immediately available in the current session.

## Failure Modes

| Mode | Symptom | Recovery |
|------|---------|----------|
| Network timeout | Partial broken install | Re-run install.sh --upgrade |
| Version mismatch | Missing functions | Run sp-doctor to diagnose |

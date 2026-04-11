---
name: update-superpowers
source: superpowers-plus
triggers: ["/sp-update", "update superpowers", "upgrade superpowers", "pull superpowers", "refresh superpowers", "update skills", "upgrade skills", "sp-update", "superpowers-update", "sp-update --branch", "update superpowers staging", "update superpowers dev"]
anti_triggers: ["install superpowers", "uninstall superpowers"]
description: "Update superpowers-plus to latest, reruns the install cascade (obra/superpowers → superpowers-plus → configured overlays), and verify with sp-doctor. Supports --branch to update a specific superpowers-plus branch."
summary: "Use when: updating superpowers to latest and ensuring the full skill chain is healthy."
coordination:
  group: productivity
  order: 1
  requires: []
  enables: []
  escalates_to: []
  internal: false
composition:
  consumes: []
  produces: [updated-installation]
  capabilities: [updates-skills]
  priority: 50
---

# Update Superpowers

Pulls latest from all superpowers source repos, runs the cascading install, and heals any drift via sp-doctor.

> **Override:** Organization-specific overlays may override this skill with additional repos and install targets. This base version covers the core chain only.

## When to Use

- User says "update my superpowers" or "upgrade skills"
- User says "sp-update --branch staging" to target a specific branch
- After a known change has been pushed to any superpowers repo
- Periodic maintenance to stay current

## Branch Targeting

`sp-update` operates on the currently checked-out superpowers-plus branch. The user can specify which branch to update:

- `sp-update --branch staging` — update and checkout the staging branch
- `sp-update --branch dev` — update and checkout the dev branch
- `sp-update` (no branch) — update the current branch
- `sp-update --branch main` — update and checkout main

**Valid branches:** `main`, `staging`, `dev`. The three-tier flow is `dev → staging → main`.

When the user specifies a branch, sp-update will fetch, checkout, and update that branch. After the update, the superpowers-plus checkout remains on the specified branch until changed explicitly.

## Procedure

Run each step in order. Failure handling varies by step — see rules below.

### Step 0: Determine target branch

Parse the user's request for a `--branch` parameter. If not specified, sp-update operates on the currently checked-out branch.

- If the user says `sp-update --branch staging` → update the staging branch
- If the user says `sp-update --branch dev` → update the dev branch
- If the user says `sp-update --branch main` → update the main branch
- If the user says `sp-update` (no branch) → update the current branch
- If the user specifies any other branch name → sp-update will error: "Failed to checkout branch"

### Step 1: Run sp-update to pull and reinstall

Use `sp-update` to update superpowers-plus and cascade the install.

```bash
# Specify branch if needed, otherwise operates on current branch
sp-update --branch main --verbose
# or just:
sp-update --verbose
```

**What sp-update does:**
1. Fetches the specified branch from remote
2. Checks out the branch (if specified)
3. Fast-forward merges or force-resets to latest remote
4. Runs `install.sh --upgrade` to cascade the install
   - `install.sh` updates obra/superpowers from origin main
   - Deploys superpowers-plus assets and skills to ~/.codex/skills/
   - Overlay installs are NOT handled by sp-update; they're auto-discovered by sp-doctor

**Rules:**
- sp-update is the primary tool for updating superpowers-plus
- If fetch fails (network, auth) → sp-update exits with error; manual resolution needed
- If checkout fails (branch doesn't exist, dirty worktree) → sp-update exits with error
- If merge fails due to divergence → sp-update auto-resets to latest remote (force-safe mode)
- After the update, superpowers-plus remains on the branch specified (or current if not specified)

### Step 2: Cascading install (handled by sp-update)

sp-update automatically runs the cascading install. The flow is:
1. `install.sh --upgrade` updates obra/superpowers
2. Deploys superpowers-plus skills to ~/.codex/skills/
3. Deploys work tools to ~/.local/bin/

All skills are installed to `~/.codex/skills/` and `~/.claude/skills/`. If you need to re-run the install manually:

```bash
cd ~/.codex/superpowers-plus && bash install.sh --upgrade --verbose
```

This is normally not needed — sp-update handles it automatically.

### Step 3: Verify installation health

```bash
sp-doctor
```

This runs all diagnostic checks on the installed skills. sp-doctor REPORTS (does not fix) issues like:
- Sync drift between source and installed copies (ERROR if >10% different)
- Content changes and version mismatches
- Installation completeness
- superpowers-plus divergence from remote

**Handling:**
- If sp-doctor reports ERRORS → investigate root cause. Some errors are pre-existing (e.g., content drift in personal overlays). Do NOT ignore.
- If sp-doctor reports WARNINGS → usually non-critical, can be ignored.
- If sp-doctor command fails to run → report error to user (installation may be broken).

To auto-fix safe issues (file endings, CRLF), use `sp-doctor --fix-safe` or run the full auto-fixer: `bash ~/.codex/superpowers-plus/tools/doctor-checks.sh --fix --yes`

### Step 4: Verify

```bash
node ~/.codex/superpowers-augment/superpowers-augment.js bootstrap
```

Confirm skills load successfully. Report the skill count to the user.

## For Agents

When the user says "update my superpowers" or "sp-update":

1. Parse for `--branch <name>` — if specified, use it; otherwise sp-update uses current branch
2. Run `sp-update --branch <branch> --verbose` (if branch specified) or `sp-update --verbose` (if not)
3. Run `sp-doctor` to verify installation health
4. If sp-doctor reports errors, investigate (some may require manual fixes)
5. Run `node ~/.codex/superpowers-augment/superpowers-augment.js bootstrap` to confirm skills load
6. Report summary: branch used, installation status, any doctor findings

**Key behaviors:**
- sp-update fetches, checks out, and pulls the specified branch (or current if not specified)
- sp-update auto-resets diverged branches to prevent stale installations
- sp-update cascades: obra/superpowers → superpowers-plus → skill deployment
- sp-doctor REPORTS issues (use `--fix-safe` or `doctor-checks.sh --fix` for auto-fixes)
- Overlay source dirs are auto-discovered by sp-doctor, not by sp-update

## Important Notes

- This skill does NOT push anything. It only pulls and installs locally.
- sp-update automatically resets diverged branches to ensure FRESH installs are always delivered (no stale code).
- After updating, any new skills or triggers are immediately available in the current session.
- **Organization overlays** may override this skill with their own version that includes additional repos and a different install entry point.
- sp-doctor findings (like content drift) are pre-existing and non-critical — they don't block updates.

## Failure Modes

| Mode | Symptom | Recovery |
|------|---------|----------|
| Fetch fails (network/auth) | `git fetch` error, sp-update exits | Resolve network/auth, re-run sp-update |
| Branch doesn't exist on remote | `git checkout` fails with "no upstream tracking" | Verify branch exists: `git branch -r` |
| Dirty worktree blocks checkout | `git checkout` refuses to switch branches | `git status`, commit or stash changes, re-run |
| Fast-forward merge fails | Non-FF history, sp-update auto-resets | sp-update force-resets to remote (intentional safety) |
| install.sh fails | Install exits with error, skills not deployed | Check error message, may need manual `install.sh --upgrade --verbose` |
| sp-doctor reports errors | Content drift, version mismatches, divergence | Investigate each error; use `doctor-checks.sh --fix` for safe auto-fixes |

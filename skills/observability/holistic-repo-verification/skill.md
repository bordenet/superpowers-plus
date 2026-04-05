---
name: holistic-repo-verification
source: superpowers-plus
triggers: ["repo health", "verify repo", "CI is green", "check all workflows", "before creating PR"]
anti_triggers: ["fix CI", "debug pipeline", "write tests"]
description: Verify ALL aspects of repository health before claiming work is complete. Checks CI workflows, GitHub Pages deployment, and any other workflows that affect repo status.
summary: "Use when: verifying repo health (CI, deployments) before claiming done."
coordination:
  group: observability
  order: 1
  requires: []
  enables: []
  escalates_to: []
  internal: false
composition:
  consumes: [code-changes]
  produces: [verification-report]
  capabilities: [verifies-repo-health]
  priority: 30
---

# holistic-repo-verification

**MANDATORY**: Use this skill before claiming any repository work is complete, before creating PRs, and before reporting that "CI is green."

> **Wrong skill?** Pre-commit code quality → `pre-commit-gate`. Output verification → `output-verification`. Completion gate → `verification-before-completion`.

## When to Use

- Before a major release or after large refactoring
- After merging multiple feature branches
- When CI passes but something still feels wrong
- Periodic health check on repo consistency

## The Core Principle

**A repository is only "green" when ALL status indicators are green.**

This includes:

- CI workflow (`.github/workflows/ci.yml`)
- GitHub Pages deployment (`pages build and deployment`)
- Any other custom workflows in `.github/workflows/`
- GitHub Pages status via API

**Never claim "CI passes" when only checking the CI workflow. That's a narrow, incomplete verification.**

## Verification Checklist

### 1. Check ALL GitHub Actions Workflows

```bash
# List all workflow runs for the repo (most recent first)
gh api /repos/{owner}/{repo}/actions/runs --jq '.workflow_runs[:10] | .[] | "\(.name): \(.conclusion) (\(.display_title))"'
```

Or via GitHub API:

```text
GET /repos/{owner}/{repo}/actions/runs?per_page=10
```

**Check for:**

- `CI` workflow: must show `conclusion: success`
- `pages build and deployment` workflow: must show `conclusion: success`
- Any other workflows: must show `conclusion: success`

### 2. Check GitHub Pages Status (if repo uses Pages)

```bash
gh api /repos/{owner}/{repo}/pages --jq '.status'
```

Or via GitHub API:

```text
GET /repos/{owner}/{repo}/pages
```

**Expected:** `status: built` (not `errored` or `building`)

### 3. Verify No Failing Workflow Runs

Look at the most recent run of EACH distinct workflow. All must pass.

## Common Failures and Fixes

### Pages "Upload artifact" Failure

**Symptom:** CI passes but Pages fails with tar errors about files being "removed before we read it"

**Cause:** Symlinks in the repository pointing to external directories that don't exist on GitHub runners

**Fix:** Replace symlinks with actual file copies

### Pages Build Failure

**Symptom:** `status: errored` on Pages API

**Cause:** Various - check the workflow run logs for specific errors

**Fix:** Examine the failing job's logs via:

```text
GET /repos/{owner}/{repo}/actions/runs/{run_id}/jobs
```

## Reporting Format

When verifying repository health, report like this:

```markdown
## Repository Health: {repo-name}

| Workflow | Status | Run # |
|----------|--------|-------|
| CI | ✅ success | 169 |
| pages build and deployment | ✅ success | 128 |

GitHub Pages: ✅ built

**Overall Status: GREEN** ✅
```

If failing: add `### Failing Workflow Details` with workflow name, run #, error.

## Failure Modes

| Failure | Fix |
|---------|-----|
| Checking only most recent workflow run, not most recent of EACH workflow | List all distinct workflows, check latest run of each |
| Claiming "all green" while a workflow is still running | Wait for completion — "in progress" is not "success" |
| Only checking GitHub Actions — missing Azure DevOps pipelines | Use the appropriate CI/CD API for the repo's hosting platform |
| Not waiting for Pages deployment after push | Pages builds are async — poll until status is `built` or `errored` |

## Success Criteria

ALL workflow runs `conclusion: success` · GitHub Pages `status: built` (if applicable) · no `failure/cancelled/errored`.

**If failing:** Identify failing workflow → get specific error from job logs → fix root cause (not re-run) → wait for ALL workflows → re-check holistically.

## Companion Skills

- **completeness-check**: Quick scope check (lighter than this)
- **pre-commit-gate**: Pre-commit quality gate
- **verification-before-completion**: Task completion verification
- **output-verification**: Verifying generated output
- **exhaustive-audit-validation**: Deep audit (this is repo-level)
- **measurement-integrity**: Metric integrity checks

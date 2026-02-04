---
name: holistic-repo-verification
description: "Verify ALL aspects of repository health before claiming work is complete. Checks CI workflows, GitHub Pages deployment, and any other workflows that affect repo status."
---

# holistic-repo-verification

**MANDATORY**: Use this skill before claiming any repository work is complete, before creating PRs, and before reporting that "CI is green."

## The Core Principle

**A repository is only "green" when ALL status indicators are green.**

This includes:
- CI workflow (`.github/workflows/ci.yml`)
- GitHub Pages deployment (`pages build and deployment`)
- Any other custom workflows in `.github/workflows/`
- GitHub Pages status via API

**Never claim "CI passes" when only checking the CI workflow. That's a narrow, incomplete verification.**

## When to Use This Skill

Use this skill:
- Before claiming work is complete on any GitHub repository
- Before creating a Pull Request
- Before reporting that "all tests pass" or "CI is green"
- After pushing commits that should fix broken builds
- When verifying repository health status

## Verification Checklist

### 1. Check ALL GitHub Actions Workflows

```bash
# List all workflow runs for the repo (most recent first)
gh api /repos/{owner}/{repo}/actions/runs --jq '.workflow_runs[:10] | .[] | "\(.name): \(.conclusion) (\(.display_title))"'
```

Or via GitHub API:
```
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
```
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
```
GET /repos/{owner}/{repo}/actions/runs/{run_id}/jobs
```

## Reporting Format

When verifying repository health, report like this:

```
## Repository Health: {repo-name}

| Workflow | Status | Run # |
|----------|--------|-------|
| CI | ✅ success | 169 |
| pages build and deployment | ✅ success | 128 |

GitHub Pages: ✅ built

**Overall Status: GREEN** ✅
```

Or if failing:

```
## Repository Health: {repo-name}

| Workflow | Status | Run # |
|----------|--------|-------|
| CI | ✅ success | 169 |
| pages build and deployment | ❌ failure | 127 |

GitHub Pages: ❌ errored

**Overall Status: RED** ❌

### Failing Workflow Details
- pages build and deployment (run 127): Upload artifact step failed
- Error: tar: ./validator/js/core: File removed before we read it
```

## Integration with Other Skills

This skill complements:
- `superpowers:verification-before-completion` - adds repo health to the verification checklist
- `superpowers:requesting-code-review` - ensures repo is healthy before requesting review
- `enforce-style-guide` - code quality before commit, this skill verifies after push

## Success Criteria

This skill succeeds when:

✅ ALL workflow runs show `conclusion: success`
✅ GitHub Pages shows `status: built` (if applicable)
✅ Repository badge/status indicator shows green
✅ No workflow is in `failure`, `cancelled`, or `errored` state

## Failure Response

If any workflow is failing:

1. **Identify the failing workflow** - not just CI
2. **Get the specific error** - check job logs
3. **Fix the root cause** - don't just re-run
4. **Verify the fix** - wait for ALL workflows to complete
5. **Re-check holistically** - confirm everything is green

**DO NOT claim work is complete until ALL workflows pass.**

---

**Remember**: When someone says "make CI green" or "fix the build," they mean the ENTIRE repository should show a healthy status, not just one specific workflow.


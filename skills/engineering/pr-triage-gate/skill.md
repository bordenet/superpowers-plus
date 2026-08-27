---
name: pr-triage-gate
source: superpowers-plus
augment_menu: true
auto_invoke: false
description: "Semantic redundancy gate -- before debugging CI or fixing any pull request, verify the PR's stated goals are not already on the target branch. Close obsolete PRs immediately rather than waste tokens on CI triage."
summary: "MANDATORY before any CI debug work on an existing PR. Diff stated goals vs target branch first."
triggers:
  - "land this PR"
  - "fix this PR"
  - "debug CI for"
  - "PR is failing"
  - "get this PR green"
  - "merge this PR"
  - "work on PR"
  - "fix pull request"
  - "unblock PR"
  - "PR #"
anti_triggers:
  - "open a new PR"
  - "create PR"
  - "new pull request"
  - "draft PR"
coordination:
  group: engineering
  order: 1
  requires: []
  enables: ["systematic-debugging", "code-review-battery"]
  escalates_to: []
  internal: false
---

# PR Triage Gate

> **Purpose:** Before touching CI logs or fixing test failures on any PR, answer: "Does the target branch already have this?"
>
> **Why this exists:** A PR whose stated features are already on the target branch is a no-op; every minute spent debugging its CI is wasted. A two-command check at the start catches this before the debugging loop starts.

**Announce at start:** "I'm using the **pr-triage-gate** skill to verify this PR is still needed before debugging CI."

## MANDATORY -- Run before any CI debug work

### Step 1: Read the PR description (30 seconds)

GitHub via `gh`:

```bash
gh pr view <number> --json title,baseRefName,body \
  --template '{{.title}}{{"\n"}}Target: {{.baseRefName}}{{"\n"}}---{{"\n"}}{{.body}}'
```

If your remote is GitLab, use `glab` instead:

```bash
PROJECT="$(git remote get-url origin | sed -E 's#.*[:/]([^/]+/[^/.]+)(\.git)?$#\1#' | sed 's#/#%2F#g')"
glab api "projects/${PROJECT}/merge_requests/<iid>" \
  --jq '{title,target:.target_branch,description}'
```

**If the API call fails or returns an error, STOP and report -- do not guess at PR goals.**

Extract the **stated goals**: what functions, flags, or behaviors does this PR claim to add or change?

### Step 2: Check if the target branch already has each stated goal (60 seconds)

For each stated goal, run the single most relevant check:

```text
# Does the function already exist on the target branch?
git fetch origin <target-branch>
git show origin/<target-branch>:<file> | grep -n "<function-name>"

# Is the flag or default already set on the target branch?
git show origin/<target-branch>:<file> | grep -n "<flag-or-default>"

# How much does the file actually differ between the PR branch and the target?
git diff origin/<target-branch>..HEAD -- <file> | wc -l
```

**If `git show` fails (file does not exist on the target), that stated goal is genuinely new -- note it and continue.**

### Step 3: Verdict

| Finding | Action |
|---|---|
| All stated goals already on target | **Close the PR immediately.** `gh pr close <number>` (or `glab mr close <iid>`) |
| Some goals already on target | Strip redundant commits, keep only novel changes |
| No goals on target | Proceed to CI debug -- move on to `systematic-debugging` and the review battery |

## FORBIDDEN

- Do NOT open CI logs before completing Steps 1-3
- Do NOT retry pipelines before completing Steps 1-3
- Do NOT fix test failures before verifying the PR is still needed
- Do NOT rebase or squash before verifying the PR is still needed

## Failure modes

| Failure | Symptom | Fix |
|---|---|---|
| Skipped Step 1 | Debugging starts with CI logs | Close current investigation, restart at Step 1 |
| Vague stated goals | PR body is empty or hand-wavey | Read the commit messages instead; if still vague, ask the author |
| False negative on Step 2 | `grep` misses a rename or refactor | Widen the search to a fuzzy identifier; if still ambiguous, compare with `git log --oneline origin/<target-branch> -- <file>` |
| Target branch has drifted | Local target is stale | `git fetch origin <target-branch>` before each check |

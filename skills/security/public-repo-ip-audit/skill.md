---
name: public-repo-ip-audit
source: superpowers-plus
triggers: ["commit to public repo", "push to public repo", "push to public", "extract to public", "migrate to public", "create public repo", "before committing to public", "open source release", "releasing to open source", "publishing open source", "commit:ip-audit", "commit:public"]
anti_triggers: ["scan for CVEs", "vulnerability scan", "dependency audit"]
description: Audit public repositories for proprietary IP before commit/push. Prevents leakage of internal references, URLs, ticket IDs, and confidential content to public repositories regardless of hosting platform (GitHub, GitLab, Bitbucket, Codeberg, SourceHut, self-hosted, etc.).
summary: "Use when: committing to public repos. Checks for proprietary IP leakage."
coordination:
  group: commit-gates
  order: 5
  requires: ["professional-language-audit"]
  enables: []
  escalates_to: []
  internal: false
---

# public-repo-ip-audit


## When to Use

- Before pushing code to any public repository
- After adding new dependencies or vendored code
- When a private repo is being converted to public
- Pre-release audit for license compliance

## Mandatory Gates (run in order, block push)

1. **Working tree scan** — `grep -rE "$PATTERNS" .` across all tracked files.
2. **Staged changes** — `git diff --staged | grep -E "$PATTERNS"`.
3. **Unpushed commits** — `git log -p origin/main..HEAD | grep -E "$PATTERNS"`.
4. **Design docs in PRIVATE repo** — Planning/extraction docs NEVER go in the public repo.
5. **Pre-push verification** — Gates 1-4 must pass before every push.

## Advisory: Full History Audit (opt-in, non-blocking)

Run `tools/public-repo-ip-check.sh --history` to scan full git history. This is **diagnostic** — it may flag old commits that predate pattern adoption. Rewriting published history is destructive for forks/clones and is NOT required. Use it to identify what was historically exposed, not as a push gate.

## IP Pattern Registry

Define org-specific patterns. Categories to cover:

```bash
PATTERNS="TICKET-[0-9]+|YourCompany|ProductName"
PATTERNS+="|wiki\.internal\.yourco\.net|username@yourcompany\.com"
# Internal git hosting (GitHub Enterprise, GitLab, Azure DevOps, Gitea, etc.)
PATTERNS+="|dev\.azure\.com/YourOrg|gitlab\.yourcompany\.com"
# Issue trackers (Jira, YouTrack, Shortcut, Asana, etc.)
PATTERNS+="|tracker\.yourcompany\.com|yourcompany\.atlassian\.net"
# CI/CD (Jenkins, CircleCI, TeamCity, Buildkite, etc.)
PATTERNS+="|jenkins\.yourcompany\.com|circleci\.com/gh/YourOrg"
```

## Blocking Conditions

**DO NOT commit/push if:** pattern match in working tree, staged changes, or unpushed commits. Also block on: design docs in public repo, internal URLs, internal emails, ticket references, private git hosting URLs, CI/CD URLs. Full history hits are advisory — document and triage, do not block.

## Incident Reference

**2026-03-06:** Design doc created in public repo; sanitization only checked subdirectory; history not audited. Resolution: full git history rewrite (orphan branch).

**Gate order:** `pre-commit-gate` → `enforce-style-guide` → `progressive-code-review-gate` → `professional-language-audit` → **this skill**.


> **Wrong skill?** Scanning code for secrets/CVEs → `repo-security-scan`. Wiki content secrets → `wiki-secret-audit`. Dependency upgrades → `security-upgrade`.

## Procedure

### Step 1: Identify Public Repos

Confirm the target repo is public. Check `git remote -v` and verify against the hosting platform's API.

### Step 2: Build Pattern Registry

Create org-specific patterns (see IP Pattern Registry above). Customize for your organization's:
- Internal domain names and subdomains
- Issue tracker prefixes (JIRA/Linear/Azure DevOps project keys)
- Employee email patterns
- Internal tool URLs (CI/CD, wiki, monitoring)

### Step 3: Run Mandatory Gates (in order)

1. **Working tree scan:** `git ls-files -z | xargs -0 grep -lnE "$PATTERNS"`
2. **Staged changes:** `git diff --staged | grep -nE "$PATTERNS"`
3. **Unpushed commits:** `git log -p origin/main..HEAD | grep -nE "$PATTERNS"`
4. **Design docs check:** Verify no planning/extraction docs exist in public repo

### Step 4: Triage Matches

| Match Type | Action |
|------------|--------|
| Internal URL | **HARD BLOCK** — remove before push |
| Employee email | **HARD BLOCK** — replace with generic |
| Ticket key (PROJ-123) | **BLOCK** — remove or genericize |
| Company name in code comment | **WARN** — review context, may be acceptable in attribution |

### Step 5: Fix and Re-scan

After fixing, re-run ALL gates. Zero matches required before push.

## Failure Modes

| Failure | Fix |
|---------|-----|
| Audit skipped because "it's just a README" | ALL files in public repos get audited, no exceptions |
| Internal URL patterns not in deny list | Update deny list with new internal domains immediately |
| Agent rationalizes "it's not really sensitive" | Hard block — any match requires explicit user override |
| Pattern registry is stale — new internal tools not covered | Review and update patterns quarterly; add new tools on adoption |


## Scope Exclusions

- Code review → `progressive-code-review-gate`
- Secret scanning → `repo-security-scan`
- Pre-commit lint/tests → `pre-commit-gate`

## Companion Skills

- **repo-security-scan**: Broader security audit (secrets, CVEs, code patterns)
- **pre-commit-gate**: General pre-commit checks
- **professional-language-audit**: Language checks before public commits

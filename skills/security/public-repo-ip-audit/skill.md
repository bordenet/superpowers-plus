---
name: public-repo-ip-audit
source: superpowers-plus
triggers: ["commit to public repo", "push to public repo", "push to public", "extract to public", "migrate to public", "create public repo", "before committing to public", "open source release", "releasing to open source", "publishing open source", "commit:ip-audit", "commit:public"]
description: Audit public repositories for proprietary IP before commit/push. Prevents leakage of internal references, URLs, ticket IDs, and confidential content to public repositories regardless of hosting platform (GitHub, GitLab, Bitbucket, Codeberg, SourceHut, self-hosted, etc.).
coordination:
  group: commit-gates
  order: 4
  requires: ["professional-language-audit"]
  enables: []
  escalates_to: []
  internal: false
---

# public-repo-ip-audit

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

**Gate order:** `pre-commit-gate` → `enforce-style-guide` → `professional-language-audit` → **this skill**.

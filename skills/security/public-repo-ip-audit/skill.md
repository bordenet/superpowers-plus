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

## Mandatory Gates (run in order)

1. **History audit** — Before ANY work, scan target repo's full git history: `git log -p --all | grep -E "$PATTERNS"`. If contaminated, STOP and clean history first.
2. **Design docs in PRIVATE repo** — Planning/extraction docs NEVER go in the public repo.
3. **Full-repo grep** — Search entire repo (`grep -rE "$PATTERNS" repo/`), not just the target directory.
4. **Staged + history check** — `git diff --staged | grep -E "$PATTERNS"` AND `git log -p origin/main..HEAD | grep -E "$PATTERNS"`
5. **Pre-push verification** — All of the above must pass before every push.

## IP Pattern Registry

Define org-specific patterns. Categories to cover:

```bash
PATTERNS="TICKET-[0-9]+|YourCompany|ProductName"
PATTERNS+="|wiki\.internal\.yourco\.net|username@yourcompany\.com"
# Internal git hosting (GitHub Enterprise, GitLab, Azure DevOps, Gitea, etc.)
PATTERNS+="|dev\.azure\.com/YourOrg|gitlab\.yourcompany\.com"
# Issue trackers (Linear, Jira, YouTrack, Shortcut, Asana, etc.)
PATTERNS+="|linear\.app/your-team|yourcompany\.atlassian\.net"
# CI/CD (Jenkins, CircleCI, TeamCity, Buildkite, etc.)
PATTERNS+="|jenkins\.yourcompany\.com|circleci\.com/gh/YourOrg"
```

## Blocking Conditions

**DO NOT commit/push if:** pattern match in working tree, staged changes, unpushed commits, or git history. Also block on: design docs in public repo, internal URLs, internal emails, ticket references, private git hosting URLs, CI/CD URLs.

## Incident Reference

**2026-03-06:** Design doc created in public repo; sanitization only checked subdirectory; history not audited. Resolution: full git history rewrite (orphan branch).

**Gate order:** `pre-commit-gate` → `enforce-style-guide` → `professional-language-audit` → **this skill**.

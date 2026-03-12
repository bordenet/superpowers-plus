---
name: public-repo-ip-audit
source: superpowers-plus
triggers: ["commit to public repo", "push to GitHub", "extract to public", "migrate to public", "create public repo", "before committing to public"]
description: Audit public repositories for proprietary IP before commit/push. Prevents leakage of internal references, URLs, ticket IDs, and confidential content to public GitHub repositories.
---

# public-repo-ip-audit

## CONTEXT
When working with proprietary codebases (internal repos, private company code), content may need to be extracted or migrated to public repositories. This skill ensures NO proprietary intellectual property (IP) leaks to public repositories.

## MANDATORY GATES

### Gate 1: Pre-Work History Audit
**BEFORE starting any extraction/migration work, audit the TARGET public repo's full git history:**

```bash
# Search ALL commits in the repo's history
git log --all --oneline | while read sha msg; do
  if git show "$sha" 2>/dev/null | grep -qE "PATTERN_LIST"; then
    echo "CONTAMINATED: $sha $msg"
  fi
done
```

If contamination found: **STOP. Clean history BEFORE adding new content.**

### Gate 2: Design Documents Go In PRIVATE Repo
**Planning documents for proprietary work MUST be created in the PRIVATE source repo, NEVER in the public target repo.**

| Document Type | Correct Location | Wrong Location |
|---------------|------------------|----------------|
| Extraction design doc | PRIVATE repo | ❌ Public repo |
| Migration plan | PRIVATE repo | ❌ Public repo |
| IP sanitization checklist | PRIVATE repo | ❌ Public repo |

### Gate 3: Full-Repo Verification (Not Just Target Directory)
**Search the ENTIRE repository, not just the directory you're working in:**

```bash
# WRONG - scoped to subdirectory
grep -rE "PATTERN" repo/skills/engineering/

# CORRECT - entire repo
grep -rE "PATTERN" repo/
```

### Gate 4: Git History Verification
**Search staged changes AND full commit history:**

```bash
# Staged changes
git diff --staged | grep -E "PATTERN"

# Full history (all commits, all branches)
git log -p --all | grep -E "PATTERN"
```

### Gate 5: Pre-Push Verification
**Before EVERY push to a public repo, verify:**

```bash
# 1. Working tree clean
grep -rE "PATTERN" . | grep -v ".git/"

# 2. Staged changes clean
git diff --staged | grep -E "PATTERN"

# 3. All local commits clean (since last push)
git log -p origin/main..HEAD | grep -E "PATTERN"
```

## IP PATTERN REGISTRY

Define proprietary patterns for each organization. Example:

```bash
# Example patterns (customize for your organization)
PATTERNS="TICKET-[0-9]+|YourCompany|yourcompany|ProductName"
PATTERNS+="|internal-service|Team Name|wiki\.internal\.yourco\.net"
PATTERNS+="|dev\.azure\.com/YourOrg|linear\.app/your-team"
PATTERNS+="|username@yourcompany\.com"
```

## VERIFICATION SCRIPT

Run this before ANY commit to a public repo:

```bash
#!/bin/bash
# public-repo-ip-check.sh

PATTERNS="YOUR_ORG_PATTERNS_HERE"

echo "=== Public Repo IP Audit ==="

# Check working tree
echo "Checking working tree..."
if grep -rE "$PATTERNS" . 2>/dev/null | grep -v ".git/"; then
  echo "❌ FAIL: IP found in working tree"
  exit 1
fi

# Check staged changes
echo "Checking staged changes..."
if git diff --staged | grep -E "$PATTERNS"; then
  echo "❌ FAIL: IP found in staged changes"
  exit 1
fi

# Check unpushed commits
echo "Checking unpushed commits..."
if git log -p origin/main..HEAD 2>/dev/null | grep -E "$PATTERNS"; then
  echo "❌ FAIL: IP found in unpushed commits"
  exit 1
fi

echo "✅ PASS: No proprietary IP detected"
```

## BLOCKING CONDITIONS

**DO NOT commit/push if ANY of these are true:**

1. ❌ Pattern match found in working tree
2. ❌ Pattern match found in staged changes
3. ❌ Pattern match found in unpushed commits
4. ❌ Pattern match found in git history (requires history rewrite)
5. ❌ Design documents present in public repo
6. ❌ Internal URLs present (wiki, ticketing, CI/CD)
7. ❌ Internal email addresses present
8. ❌ Ticket/issue references present (JIRA, Linear, ADO)

## INCIDENT REFERENCE

**2026-03-06: IP Leak During Skill Extraction**

| Failure | Root Cause |
|---------|------------|
| Design doc in wrong repo | Created planning doc in PUBLIC repo instead of PRIVATE |
| Internal wiki URLs | Sanitization only checked target directory, not full repo |
| Internal ticket reference | Verification grep scoped too narrowly |
| Pre-existing history contamination | Target repo history not audited before work began |

**Resolution:** Full git history rewrite using orphan branch technique.

## CHECKLIST

Before committing to public repo:

- [ ] Audited target repo's FULL git history for pre-existing contamination
- [ ] Design documents created in PRIVATE repo only
- [ ] Ran full-repo grep (not just target directory)
- [ ] Ran git history grep on all unpushed commits
- [ ] Verified no internal URLs (wiki, ticketing, CI/CD)
- [ ] Verified no internal email addresses
- [ ] Verified no ticket/issue references
- [ ] Verified no company names or product names
- [ ] Verification script passed with exit code 0

## OUTCOMES

✅ Zero proprietary IP in public repository working tree
✅ Zero proprietary IP in public repository git history
✅ Design documents remain in private repositories
✅ Audit trail of verification before each commit

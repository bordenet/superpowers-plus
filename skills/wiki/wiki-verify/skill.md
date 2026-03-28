---
name: wiki-verify
source: superpowers-plus
triggers: ["verify this wiki page", "fact-check the vendor page", "check if wiki is up to date", "run wiki audit", "is this documentation stale", "validate wiki accuracy", "check wiki accuracy", "verify wiki facts"]
anti_triggers: ["edit wiki", "update wiki page", "create wiki page", "write wiki"]
description: Use when wiki pages reference codebase details (versions, repos, configs) that may drift. Verifies claims against authoritative sources and updates stale content interactively.
summary: "Use when: wiki references codebase details that may have drifted. Skip when: reading wiki only."
coordination:
  group: wiki
  order: 4
  requires: []
  enables: []
  escalates_to: ['wiki-orchestrator']
  internal: false
---

# Skill: wiki-verify

> **Wrong skill?** Checking links in wiki → `link-verification`. Scanning for secrets → `wiki-secret-audit`. Full wiki editing → `wiki-orchestrator`. Content duplication → `wiki-content-coherence`.

## Triggers

- "Verify this wiki page"
- "Fact-check the vendor page"
- "Check if wiki is up to date"
- "Run wiki audit"
- "Verify all pages in wiki-sources.yaml"
- Before pushing wiki changes
- When you notice potentially stale technical claims

## Modes

| Mode | Flag | Behavior |
|------|------|----------|
| **Interactive** | (default) | Prompt before each fix |
| **Report** | `--report` | Output diff only, no changes |
| **Fix** | `--fix` | Auto-fix without prompts |

## Source Discovery

### Step 1: Check Page Tail Section

Look for a `## 🔍 Verification Sources` section at the bottom of the wiki page:

```markdown

## 🔍 Verification Sources

<!-- wiki-verify:sources
repos:
  - backend-service
  - settings-service
files:
  - backend-service/package.json#dependencies
  - settings-service/src/integrations/**
-->

*🔄 AI-maintained — invoke wiki-verify skill to update*
```

### Step 2: Fallback to Central Registry

If no tail section found, check `superpowers-plus/wiki-sources.yaml`:

```yaml
pages:
  - id: example-vendors-page-abc123
    url: https://your-wiki.example.com/doc/example-vendors-page-abc123
    sources:
      repos: [backend-service, your-shared-lib]
      files: [backend-service/package.json]
```

### Step 3: No Sources Configured

If neither exists, STOP and report:
> "This page has no verification sources configured. Add a tail section or entry in wiki-sources.yaml."

## Claim Types to Verify

| Claim Type | Example in Wiki | How to Verify |
|------------|-----------------|---------------|
| **Version numbers** | "SDK v3.2.1" | Check `package.json` or `requirements.txt` |
| **Repo existence** | "backend-service repo" | Repository adapter or git |
| **File paths** | "`src/integrations/service.ts`" | Git file existence check |
| **Vendor names** | "We use Service X for Y" | Grep codebase for imports/configs |
| **Config values** | "Default timeout: 30s" | Check config files |
| **PR/commit refs** | "Fixed in PR #123" | Repository adapter |
| **Dates** | "Added in January 2026" | Git history |

## Verification Process

```
1. Fetch wiki page content (use adapter's get_page operation)
2. Parse tail section OR lookup in wiki-sources.yaml
3. Clone/fetch relevant repos if not local
4. Extract verifiable claims from page content
5. For each claim:
   a. Query authoritative source
   b. Compare wiki content vs source
   c. Classify: ✅ CURRENT | ⚠️ STALE | ❌ WRONG | ❓ UNVERIFIABLE
6. Report or fix based on mode
```

## Interactive Flow (Default)

```
🔍 Verifying: YourProduct Production Stack & Vendors

Sources: backend-service (package.json), settings-service

Checking 12 claims...

⚠️  STALE: Deepgram SDK version
    Wiki says: v3.2.1
    package.json says: v3.4.0
    → [U]pdate / [S]kip / [A]ll / [Q]uit? _

✅ CURRENT: Twilio integration (found in src/integrations/twilio.ts)
✅ CURRENT: OpenAI dependency (gpt-4o-mini in config)

❌ WRONG: "Redis for caching"
    Wiki says: Redis
    Codebase shows: No Redis imports found
    → [D]elete claim / [S]kip / [Q]uit? _

Summary: 10 ✅ | 1 ⚠️ updated | 1 ❌ skipped
```

## After Verification

1. Ensure the maintenance footer exists (see below)
2. Push changes via adapter's update_page operation
3. Report summary to user

## Required Page Footer

Add if missing: `*🔄 AI-maintained — invoke wiki-verify skill to update*`
Place after `## 🔍 Verification Sources` section. Omit "Last verified" dates and page URLs.

## Authoritative Sources

Git repos (`git show/log`) · repository adapter · `package.json` · `requirements.txt` · config files (YAML/JSON/TOML) · `.env.example`.

## Registry

Central fallback: `superpowers-plus/wiki-sources.yaml`. Add new wiki pages with codebase dependencies here.

## Companion Skills

- **wiki-debunker**: Deeper fact-checking of specific claims
- **link-verification**: Checking wiki page links
- **wiki-orchestrator**: Full wiki editing pipeline

## When to Use

- After wiki pages referencing code/configs are updated
- During periodic wiki health reviews
- When a service version or dependency is upgraded
- When wiki-orchestrator pipeline triggers verification stage

## Failure Modes

| Failure | Fix |
|---------|-----|
| Verification source is also stale | Cross-reference multiple sources (repo, docs, API) |
| UNVERIFIABLE claims left unmarked | Flag and tag for human review — don't silently skip |
| False positive STALE on intentionally pinned versions | Check for `pinned:` or version lock annotations |

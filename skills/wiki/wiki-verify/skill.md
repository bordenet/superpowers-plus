---
name: wiki-verify
source: superpowers-plus
triggers: ["verify this wiki page", "fact-check the vendor page", "check if wiki is up to date", "run wiki audit", "is this documentation stale", "validate wiki accuracy"]
description: Use when wiki pages reference codebase details (versions, repos, configs) that may drift. Verifies claims against authoritative sources and updates stale content interactively.
---

# Skill: wiki-verify

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
---

## 🔍 Verification Sources

<!-- wiki-verify:sources
repos:
  - backend-service
  - settings-service
files:
  - backend-service/package.json#dependencies
  - settings-service/src/integrations/**
azure-devops:
  - project: Your Project
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
| **Version numbers** | "Deepgram SDK v3.2.1" | Check `package.json` or `requirements.txt` |
| **Repo existence** | "backend-service repo" | Azure DevOps API or git |
| **File paths** | "`src/integrations/twilio.ts`" | Git file existence check |
| **Vendor names** | "We use Twilio for SMS" | Grep codebase for imports/configs |
| **Config values** | "Default timeout: 30s" | Check config files |
| **PR/commit refs** | "Fixed in PR #25008" | Azure DevOps API |
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

**Every wiki page maintained by this skill MUST have this single-line footer at the bottom:**

```markdown
---

*🔄 AI-maintained — invoke wiki-verify skill to update*
```

**Rules:**
- If footer is missing, ADD it during verification
- The footer goes AFTER the `## 🔍 Verification Sources` section (if present)
- If page only uses central registry (no tail section), the footer is the only tail content
- **Omit** "Last verified" or "Last updated" lines — they add noise without value
- **Omit** full page URL — the skill can determine context

## Authoritative Sources Reference

| Source Type | How to Access |
|-------------|---------------|
| **Git repos** | `git show`, `git log`, file reads |
| **Azure DevOps** | Azure DevOps MCP or REST API |
| **package.json** | Parse JSON, check `dependencies`/`devDependencies` |
| **requirements.txt** | Parse pinned versions |
| **Config files** | Parse YAML/JSON/TOML configs |
| **Environment vars** | Check `.env.example` or config docs |

## Example Invocations

```
# Verify a specific page
"Verify https://your-wiki.example.com/doc/example-vendors-page-abc123"

# Verify all configured pages
"Verify all pages in wiki-sources.yaml"

# Report only (no changes)
"Verify the vendor page --report"

# Auto-fix without prompts
"Verify all pages --fix"
```

## Registry Location

Central fallback registry: `superpowers-plus/wiki-sources.yaml`

When adding new wiki pages with codebase dependencies, add them to this registry.


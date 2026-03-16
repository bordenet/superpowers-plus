---
name: wiki-secret-audit
source: superpowers-plus
triggers: ["scan wiki for secrets", "audit wiki for credentials", "check for exposed API keys", "wiki security scan", "find leaked tokens in wiki"]
description: Use when scanning wiki pages for exposed secrets, after security incidents, or during periodic security reviews. Detects credentials, API keys, tokens that may have been published before secret detection.
composition:
  consumes: [markdown-content]
  produces: [sanitized-content]
  capabilities: [detects-secrets]
  priority: 25
---

# Wiki Secret Audit

> **Adapter:** See `skills/wiki/_adapters/` for platform-specific configuration
> This skill enables retroactive scanning of existing wiki pages for exposed secrets.

## When to Use

Invoke this skill when:
- Auditing existing wiki pages for credentials
- After a security incident to find other potential leaks
- Periodically scanning high-risk wiki areas
- User says: "scan wiki for secrets", "audit wiki security", "check for exposed credentials"

---

## Audit Procedure

### Step 1: Define Scope

Determine which pages to scan using your adapter's operations:

```
# Option A: Single page
# Use adapter's get_page operation

# Option B: Collection (all pages)
# Use adapter's list_pages operation

# Option C: Search by keyword (high-risk content)
# Use adapter's search_pages operation with query: "password OR connection string OR api key"
```

### Step 2: Fetch and Scan Each Page

For each page in scope:

1. **Fetch content** via adapter's `get_page` operation
2. **Search for secret patterns** (see patterns below)
3. **Log findings** in the report format below

### Step 3: Generate Report

Use this format for findings:

```markdown
## Wiki Secret Audit Report

**Date:** YYYY-MM-DD
**Scope:** [Collection name / Page list]
**Scanned:** X pages

### 🔴 Findings (Secrets Detected)

| Page | URL | Pattern | Line | Match Preview |
|------|-----|---------|------|---------------|
| Page Title | /doc/slug | Password Assignment | 42 | `Password=j69...` |

### ✅ Clean Pages

- Page A (no secrets)
- Page B (no secrets)

### Actions Required

1. [Page Title] — Remove/redact credential at line 42
2. [Page Title] — Rotate exposed API key, then redact
```

---

## Secret Patterns to Search

Search for these regex patterns (case-insensitive):

### HIGH Priority (Real Credentials)

```regex
# SQL Connection Strings
(Server|Data Source)=[^;]*Password=[^;]+

# Database URLs
(postgres|mysql|mongodb|redis)://[^:]+:[^@]+@

# Password Assignments
password\s*[:=]\s*['"]?[A-Za-z0-9_!@#$%^&*()-]{8,}

# Bearer Tokens
Bearer\s+[A-Za-z0-9_-]{20,}

# API Keys
(api[_-]?key|apikey)\s*[:=]\s*['"]?[A-Za-z0-9_-]{20,}

# Private Keys
-----BEGIN\s+(RSA|EC|OPENSSH)?\s*PRIVATE\s+KEY-----

# AWS Keys
AKIA[0-9A-Z]{16}

# Known Service Tokens (add your platform-specific patterns)
sk-[A-Za-z0-9]{32,}         # OpenAI
gh[pousr]_[A-Za-z0-9]{30,}  # GitHub
xox[baprs]-[A-Za-z0-9-]{10,} # Slack
sk_live_[A-Za-z0-9]{20,}    # Stripe
```

### EXCLUDE (False Positives)

Skip matches that are:
- Environment variable references: `$PASSWORD`, `${VAR}`, `process.env.VAR`
- Redacted placeholders: `[REDACTED]`, `<YOUR_VALUE>`
- Documentation examples: "password must be 8+ chars"

---

## High-Risk Wiki Areas

Prioritize scanning these areas:

| Area | Why High Risk |
|------|---------------|
| Development setup docs | Often contain real connection strings |
| Environment configuration | Database credentials, API keys |
| Architecture docs | Service-to-service auth |
| Runbooks | Production access credentials |
| Personal notes | Quick dumps may include secrets |

---

## Remediation Steps

When secrets are found:

1. **IMMEDIATE:** Remove/redact the secret from wiki page
2. **ROTATE:** Change the compromised credential (password, key, token)
3. **AUDIT:** Check if credential was accessed by unauthorized parties
4. **DOCUMENT:** Log the incident in the audit report
5. **NOTIFY:** Inform relevant team members

---

## Related Resources

- **Shared Module:** `skills/_shared/secret-detection.md`
- **PRE_PUSH_WIKI_AUDIT:** `skills/wiki/PRE_PUSH_WIKI_AUDIT.md`

---
name: wiki-authoring
source: superpowers-plus
triggers: ["fix wiki formatting", "structure this wiki page", "improve readability", "wiki markdown rules"]
description: Use when structuring wiki content, fixing wiki formatting issues, or ensuring platform compatibility. Enforces semantic headings, spacing rules, anchor format, and no-HTML constraints. Companion to wiki-editing (workflow) and wiki-orchestrator (pipeline). See skills/wiki/_adapters/ for platform-specific rules.
---

# Wiki Authoring

> **Companion skill:** `wiki-editing` handles download-before-edit workflow.
> **Adapter:** See `skills/wiki/_adapters/` for platform-specific formatting rules.
> **See also:** [reference.md](./reference.md) (formatting), [examples.md](./examples.md) (patterns)

## Overview

Wiki platforms store content in Markdown with platform-specific constraints. This skill ensures reliable rendering and easy parsing.

**Core principles:**
- Semantic headings (H1 once, H2/H3 max 2-3 levels)
- Consistent spacing (one blank line between elements)
- No inline HTML (most platforms escape it)
- Code blocks always specify language

---

## ⚠️ Required Skill Invocations

<EXTREMELY_IMPORTANT>

**Before pushing wiki content, you MUST invoke these skills:**

| Skill | When | Why |
|-------|------|-----|
| **🔒 Secret Scan** | ALWAYS — before ANY wiki push | Prevents publishing credentials |
| `superpowers:link-verification` | Adding repo links or external URLs | Prevents hallucinated links |
| `superpowers:eliminating-ai-slop` | Before finalizing prose | Removes AI-generated padding |

**Failure to invoke these skills results in:**
- 🚨 **SECURITY INCIDENT** — Credentials published to wiki
- Hallucinated repository links that don't exist
- Documentation debt requiring cleanup

</EXTREMELY_IMPORTANT>

---

## 🔒 SECRET DETECTION (MANDATORY)

<EXTREMELY_IMPORTANT>

**Security Incident 2026-02-24:** SQL Server credentials were published to the wiki.

### Before Pushing ANY Wiki Content

**Step 1: Visual Scan** — Search for:
- `password`, `pwd`, `secret`, `token`, `api_key`, `credential`, `private_key`

**Step 2: For Each Match:**
- Is this a **real value**? → 🛑 STOP — remove or redact
- Is this an **env variable reference** (`${VAR}`)? → ✅ OK
- Is this a **placeholder** (`[REDACTED]`)? → ✅ OK

**Step 3: Safe Alternatives:**
```
❌ Password=j69KZhsk_6935Bayn2W0ZZmA
✅ Password=${DB_PASSWORD}
✅ Password=[REDACTED: production SQL password]
```

**See:** `_shared/secret-detection.md` for full pattern list.

</EXTREMELY_IMPORTANT>

---

## 🚨 PRE-PUBLICATION VERIFICATION (MANDATORY)

<EXTREMELY_IMPORTANT>

**The workflow is: VERIFY → FIX → PUBLISH. Never PUBLISH → VERIFY.**

### Pre-Publish Checklist

- [ ] **Extracted all URLs** from content
- [ ] **Verified each external URL** returns valid response
- [ ] **Verified each internal wiki link** resolves
- [ ] **Verified each repository link** points to real repo/path
- [ ] **All factual claims have source citations**
- [ ] **No AI slop detected**
- [ ] **Reported verification results to user**

❌ **DO NOT PUBLISH** until all boxes are checked.

### Link Verification by URL Type

| URL Pattern | Verification Tool | Expected Result |
|-------------|-------------------|-----------------|
| `https://...` (external) | `web-fetch` | 200 OK |
| `/doc/...` (internal) | Adapter's `get_page` | Document resolves |
| Repository URL | Repo adapter | Repo exists |
| Issue URL | Issue adapter | Issue exists |

</EXTREMELY_IMPORTANT>

---

## 📎 SOURCE CITATION REQUIREMENTS

<EXTREMELY_IMPORTANT>

**All factual claims MUST include direct hyperlinks.**

| Claim Type | Required Citation |
|------------|-------------------|
| Code references | Repository file/line link |
| Process claims | Wiki page, issue, or ticket |
| External facts | Authoritative source |
| Metrics/numbers | Source dashboard or document |

### ❌ Unacceptable
- "According to our process..." (link it)
- "The code does X..." (link file)

### ✅ Acceptable
- "According to [our deployment process](/doc/deployment-guide)..."
- "The [`handleCommand` function]([repo-url]/path/to/file) does X..."

</EXTREMELY_IMPORTANT>

---

## 🧹 AI SLOP DETECTION

Scan content for these anti-patterns before publishing:

| Pattern | Example | Fix |
|---------|---------|-----|
| Vague claims | "significantly improves" | Add numbers: "reduces latency by 40ms" |
| Buzzword stacking | "leveraging cutting-edge AI" | State what it does |
| Generic statements | "follows best practices" | Name the practices |
| Missing "why" | "We use Redis" | "We use Redis because..." |

### Self-Check Questions

1. **Could this apply to any project?** → Too generic
2. **Is there a number I could add?** → Metrics > adjectives
3. **Did I explain WHY, not just WHAT?** → Add context
4. **Would a skeptic accept this?** → Add evidence

---

## Platform-Specific Constraints

See your adapter in `skills/wiki/_adapters/` for platform-specific rules.

### ✅ Content Start Rule

Most wiki platforms display document title in UI. **Do NOT start with `# Title`**.

**Wrong:**
```markdown
# My Document Title

Content here...
```

**Correct:**
```markdown
> **Summary:** Brief description.

Content here...

## First Section
```

---

## Heading Rules

| Rule | Example |
|------|---------|
| ✅ Start with H2 | `## Section Name` |
| ✅ Sequential order | H2 → H3 → H4 (no skipping) |
| ✅ Max 3 levels | H2, H3, H4 (avoid H5+) |
| ❌ Don't start with H1 | Wiki UI shows title |
| ❌ Don't skip levels | H2 → H4 is wrong |

---

## Formatting Checklist

Before publishing any wiki page:

- [ ] **No H1** — Title shown in wiki UI
- [ ] **No HTML tags** — All content is pure markdown
- [ ] **Blank lines** — Around tables, code blocks, lists
- [ ] **Code blocks** — All have language specified
- [ ] **Links** — Descriptive text, no bare URLs
- [ ] **Headings** — Sequential (H2 → H3 → H4)

---

## Related Skills

- **wiki-editing**: Download-before-edit workflow
- **wiki-orchestrator**: Quality pipeline
- **wiki-verify**: Link verification

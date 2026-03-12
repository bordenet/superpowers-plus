---
name: wiki-authoring
source: superpowers-plus
triggers: ["fix wiki formatting", "structure this wiki page", "improve readability", "wiki markdown rules"]
description: Use when structuring wiki content, fixing wiki formatting issues, or ensuring platform compatibility. Enforces semantic headings, spacing rules, anchor format, and no-HTML constraints. Companion to wiki-editing (workflow) and wiki-orchestrator (pipeline). See skills/wiki/_adapters/ for platform-specific rules.
---

# Wiki Authoring

> **Companion skill:** `wiki-editing` handles download-before-edit workflow.
> **Adapter:** See `skills/wiki/_adapters/` for platform-specific formatting rules.
> **This skill:** Focuses on content structure and formatting.

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
| **🔒 Secret Scan** | ALWAYS — before ANY wiki push | Prevents publishing credentials (SQL passwords, API keys, tokens) |
| `superpowers:link-verification` | Adding Code References, repo links, or external URLs | Prevents hallucinated links (e.g., fake `github.com/your-org/*` URLs) |
| `superpowers:eliminating-ai-slop` | Before finalizing prose | Removes AI-generated padding, vague claims, marketing language |

**Failure to invoke these skills results in:**
- 🚨 **SECURITY INCIDENT** — Credentials published to wiki (happened 2026-02-24)
- Hallucinated repository links that don't exist
- AI slop that wastes reader time
- Documentation debt that requires cleanup later

</EXTREMELY_IMPORTANT>

---

## 🔒 SECRET DETECTION (MANDATORY)

<EXTREMELY_IMPORTANT>

**Security Incident 2026-02-24:** SQL Server credentials were published to the wiki. This MUST NEVER happen again.

### Before Pushing ANY Wiki Content

**Step 1: Visual Scan** — Search for these keywords:
- `password`, `pwd`, `secret`, `token`, `api_key`, `credential`, `private_key`

**Step 2: For Each Match, Ask:**
- Is this a **real value**? → 🛑 STOP — remove or redact it
- Is this an **env variable reference** (`$VAR`, `${VAR}`)? → ✅ OK
- Is this a **placeholder** (`[REDACTED]`, `<YOUR_VALUE>`)? → ✅ OK

**Step 3: Safe Alternatives:**
```
❌ Password=j69KZhsk_6935Bayn2W0ZZmA
✅ Password=${DB_PASSWORD}
✅ Password=[REDACTED: production SQL password]
```

### MCP Server Hard Block

Some wiki MCP servers will **automatically block** content containing:
- SQL connection strings with passwords
- Database URLs with credentials
- API keys (AWS, OpenAI, GitHub, Slack, etc.)
- Bearer tokens, private keys

**This is the last line of defense.** Catch secrets BEFORE hitting this block.

**See:** `_shared/secret-detection.md` for full pattern list.

</EXTREMELY_IMPORTANT>

---

## 🚨 PRE-PUBLICATION VERIFICATION (MANDATORY)

<EXTREMELY_IMPORTANT>

**The workflow is: VERIFY → FIX → PUBLISH. Never PUBLISH → VERIFY.**

Before calling your adapter's `create_page` or `update_page` operation, you MUST complete this checklist:

### Pre-Publish Checklist

- [ ] **Extracted all URLs** from content
- [ ] **Verified each external URL** returns valid response (`web-fetch`)
- [ ] **Verified each internal wiki link** resolves (adapter's `get_page`)
- [ ] **Verified each repository link** points to real repo/path (queried API)
- [ ] **Verified each issue link** points to real issue (queried API)
- [ ] **All factual claims have source citations** (linked, not just mentioned)
- [ ] **No AI slop detected** (see detection criteria below)
- [ ] **Reported verification results to user** before publishing

❌ **DO NOT PUBLISH** until all boxes are checked.

### Link Verification by URL Type

| URL Pattern | Verification Tool | Expected Result |
|-------------|-------------------|-----------------|
| `https://...` (external) | `web-fetch` | 200 OK, or 401/403 for auth-required sites |
| `/doc/...` (internal wiki) | Adapter's `get_page` | Document resolves with content |
| Repository URL | Repo adapter verification | Repo exists |
| Issue tracker URL | Issue adapter search | Issue exists |

### Verification Report Format

Before publishing, report to user:

```
## ✅ Link Verification Report

| Link Text | URL | Status | Notes |
|-----------|-----|--------|-------|
| Example Link | https://example.com | ✅ Valid | 200 OK |
| Wiki Page | /doc/page-id | ✅ Valid | Resolves to "Page Title" |
| Repo Link | [repo-url] | ❌ BROKEN | Repo not found |

**Broken links fixed:** [list fixes]
**Ready to publish:** Yes/No
```

### What Happens If You Skip This

- **Hallucinated repository URLs** — AI models frequently fabricate repo URLs
- **Broken internal links** — Document IDs change; verify before publishing
- **404 errors for readers** — Erodes trust in documentation quality
- **Cleanup debt** — Someone has to find and fix broken links later

</EXTREMELY_IMPORTANT>

---

## 📎 SOURCE CITATION REQUIREMENTS

<EXTREMELY_IMPORTANT>

**All factual claims MUST include direct hyperlinks to source data.**

### Citation Rules

| Claim Type | Required Citation | Example |
|------------|-------------------|---------|
| Code references | Repository file/line link | `[service-name]([your-repo-url])` |
| Process claims | Wiki page, issue, or ticket | `[Deployment process](/doc/deployment-xyz)` |
| External facts | Authoritative source (docs, Goodreads, etc.) | `[Principles](https://goodreads.com/book/...)` |
| Metrics/numbers | Source dashboard or document | `[Cost data](/doc/cost-analysis-abc)` |
| Quotes | Original source with page/section | `— Author Name, *Book Title* (Year)` |

### ❌ Unacceptable

- "According to our process..." (which process? link it)
- "The code does X..." (which file? link it)
- "Best practices suggest..." (whose best practices? cite source)

### ✅ Acceptable

- "According to [our deployment process](/doc/deployment-guide-abc)..."
- "The [`handleCommand` function]([your-repo-url]/path/to/file) does X..."
- "Per [Google's SRE book](https://sre.google/sre-book/)..."

</EXTREMELY_IMPORTANT>

---

## 🧹 AI SLOP DETECTION

Before publishing, scan content for these anti-patterns:

### Slop Indicators

| Pattern | Example | Fix |
|---------|---------|-----|
| **Vague claims** | "significantly improves performance" | Add numbers: "reduces latency by 40ms (p95)" |
| **Buzzword stacking** | "leveraging cutting-edge AI for seamless integration" | State what it actually does |
| **Generic statements** | "follows industry best practices" | Name the specific practices |
| **Missing "why"** | "We use Redis for caching" | "We use Redis for caching because [reason]" |
| **Hedging without value** | "This may potentially help..." | Either it helps or it doesn't—be specific |
| **Obvious padding** | "In today's fast-paced environment..." | Delete entirely |

### Self-Check Questions

Before publishing, ask:

1. **Could this sentence apply to any project?** → Too generic, add specifics
2. **Is there a number I could add?** → Metrics > adjectives
3. **Did I explain WHY, not just WHAT?** → Readers need context
4. **Would a skeptic accept this claim?** → If not, add evidence

### Example Transformation

**❌ Before (slop):**
> "The system leverages advanced AI capabilities to deliver seamless real-time voice processing, ensuring optimal customer experiences."

**✅ After (specific):**
> "The system uses Deepgram for speech-to-text (200ms p95 latency) and GPT-4o for intent classification. See [Speech: Deepgram](/doc/speech-deepgram-xyz) for configuration."

---

## When to Use

Invoke when:

- Creating new wiki pages
- Editing existing wiki content
- Reviewing wiki page formatting
- User says: "Create wiki page", "Fix wiki formatting", "Improve readability"

---

## Platform-Specific Constraints

See your adapter in `skills/wiki/_adapters/` for platform-specific rules including:
- Unsupported HTML features
- Anchor format (varies by platform)
- Special syntax handling

### ✅ Content Start Rule

Most wiki platforms display document title in UI. **Do NOT start with `# Title`**.

**Wrong:**
```markdown
# My Document Title

Content here...
```

**Correct:**
```markdown
> **Summary:** Brief description of this document.

Content here...

## First Section
```

---

## Semantic Headings

| Level | Use For | Max Count |
|-------|---------|-----------|
| H1 (`#`) | **Skip** — title displays in UI chrome | 0 |
| H2 (`##`) | Major sections | 5-10 per page |
| H3 (`###`) | Subsections | 2-5 per H2 |
| H4 (`####`) | Details (sparingly) | 2-3 per H3 |

**Progress sequentially:** H2 → H3 → H4 (maintain hierarchy).

---

## Spacing Rules

### One Blank Line Rule

Separate ALL elements with exactly one blank line:

```markdown
## Section Header

Paragraph text here.

| Table | Column |
|-------|--------|
| data  | data   |

- List item 1
- List item 2

\`\`\`bash
code block
\`\`\`

Next paragraph.
```

### Horizontal Rules

- Use `---` only (not `***` or `___`)
- **Always** blank lines before AND after
- Use sparingly — prefer headings for structure

```markdown
Content above.

---

Content below.
```

---

## Tables

Always include blank lines around tables:

```markdown
Some text.

| Column A | Column B |
|----------|----------|
| value    | value    |

More text.
```

Keep tables narrow (<80 chars) for mobile readability.

### ⚠️ Column Widths May Be Lost

Some wiki platforms store custom column widths as editor metadata, NOT in markdown.

**Impact:** When content is pushed via API, custom column widths may reset to auto.

| What's Preserved | What May Be Lost |
|------------------|------------------|
| Table content, alignment | Custom column widths |
| Row/column structure | Drag-resized proportions |

**Workaround:** After API updates, manually adjust column widths in the wiki UI if needed.

---

## Code Blocks

**Always specify language:**

```markdown
\`\`\`typescript
const x = 1;
\`\`\`
```

Use inline backticks for short code: `variableName`, `npm install`.

---

## Lists

Prefer ordered lists for steps, unordered for features:

```markdown
### Steps to Deploy

1. **Build** — `pnpm run build`
2. **Test** — `pnpm test`
3. **Deploy** — `cdk deploy`

### Features

- Real-time voice processing
- LLM orchestration
- Token caching (90-95% hit rate)
```

Use task lists for checklists: `- [ ] item`, `- [x] done`

---

## Links

### Internal Wiki Links

Use relative paths when linking within wiki:

```markdown
See [API Reference](/doc/api-reference-xyz123)
```

### External Links

Use descriptive link text for all external URLs:

**❌ Bare URL:** `https://docs.example.com/api/v2/users`
**✅ Descriptive:** `[Users API docs](https://docs.example.com/api/v2/users)`

---

## Visual Structure Alternatives

Since `<details>` and callouts don't work, use these instead:

### For Collapsible Sections → Use H4 Headings

```markdown
### Repository Details

#### agent-api — LLM Orchestration

Handles all LLM logic: system prompt composition, provider invocation...

#### voice-service — Real-Time Voice

Manages voice calls via Telnyx WebSocket...
```

### For Info/Warning Callouts → Use Blockquotes + Bold

```markdown
> **Note:** This is important information.

> **Warning:** Be careful with this operation.

> **Tip:** Try this for better results.
```

### For Visual Separation → Horizontal Rules Sparingly

Use `---` between major sections only, not between every subsection.

---

## Common Anti-Patterns

| Anti-Pattern | Problem | Fix |
|--------------|---------|-----|
| HTML tags | Escaped or broken | Use pure markdown |
| `> [!info]` syntax | Escaped as `\[!info\]` | Use `> **Note:**` instead |
| Starting with `# Title` | Duplicates UI title | Start with summary or `##` |
| No blank lines around tables | Rendering issues | Add blank lines |
| Bare URLs | Hard to read/click | Use `[text](url)` |
| Deep nesting (H5+) | Hard to navigate | Flatten to H3/H4 max |

---

## Formatting Checklist

Before publishing any wiki page:

- [ ] **No H1** — Document title is typically shown in wiki UI
- [ ] **No HTML tags** — All content is pure markdown
- [ ] **Check anchor format** — Varies by platform (see adapter)
- [ ] **Blank lines** — Around all tables, code blocks, lists
- [ ] **Horizontal rules** — Have blank lines before AND after
- [ ] **Code blocks** — All have language specified
- [ ] **Links** — Descriptive text, no bare URLs
- [ ] **Headings** — Sequential (H2 → H3 → H4), no skipping

---

## Linting Tools

### VS Code Setup (Recommended)

Install the **markdownlint** extension from David Anson (5M+ installs) — lints with 100+ rules for consistency.

**Setup Steps:**

1. Open VS Code → Extensions (`Ctrl/Cmd+Shift+X`) → Search "markdownlint" → Install
2. Export wiki page to Markdown (via API or export) → Open `.md` file → Linting activates automatically
3. Fix issues: Hover wavy underlines for details; `Ctrl/Cmd + .` quick-fixes many rules

**Workflow Tips:**

- Use VS Code's Markdown preview (`Ctrl/Cmd+Shift+V`) alongside wiki for WYSIWYG edits
- Sync edits back via wiki API (export/import cycle)

### CLI Usage

```bash
# Install CLI
npm install -g markdownlint-cli2

# Lint a file
npx markdownlint-cli2 "wiki-page.md"

# Auto-fix
npx markdownlint "wiki-page.md" --fix

# Lint all markdown in repo
npx markdownlint "**/*.md"
```

### Other Tools

| Tool | Language | Best For |
|------|----------|----------|
| **remark-lint** | JS | CI/CD pipelines, custom rules, remark ecosystem |
| **mdformat** | Python | Pre-commit hooks, auto-formatting |
| **textlint** | JS | Grammar + style (typos, passive voice) |
| **Mega-Linter** | GitHub Action | All-in-one CI for repos with wiki exports |
| **Quickmark** | Rust (LSP) | Real-time feedback in VS Code/Neovim/JetBrains |

### Wiki-Specific Configuration

Create `.markdownlint.json` in project root or wiki export folder (VS Code auto-detects):

```json
{
  "default": true,
  "MD013": { "code_blocks": false, "line_length": 120 },
  "MD033": { "allowed_elements": ["ins", "del"] },
  "MD041": false,
  "MD024": { "siblings_only": true },
  "MD040": true
}
```

| Rule | Setting | Reason |
|------|---------|--------|
| MD013 (line length) | `code_blocks: false` | Allow long code lines; wiki wraps prose |
| MD033 (inline HTML) | `allowed_elements` | Permit `<ins>`/`<del>` if needed |
| MD041 (first line H1) | `false` | Wiki shows title in UI |
| MD024 (duplicate headings) | `siblings_only` | Allow same H3 under different H2s |
| MD040 (fenced code language) | `true` | Enforce syntax highlighting |

Reload VS Code (`Ctrl/Cmd+R`) after creating config.

### Pre-Commit Hook

```yaml
# .pre-commit-config.yaml
repos:
  - repo: https://github.com/igorshubovych/markdownlint-cli
    rev: v0.41.0
    hooks:
      - id: markdownlint
        args: ["--fix"]
```

---

## Content Patterns for Common Topics

### Workflow Documentation (e.g., Triage, On-Call, Deployments)

When documenting workflows, use this structure:

```markdown
## Workflow Name

Brief description of what this workflow accomplishes.

**Best Practices:**
- Bullet points for quick scanning
- Include cadence (daily, weekly)
- Note who owns the workflow

### Metrics

| Metric | Target | Notes |
|--------|--------|-------|
| Items-per-day | 5-15 | Spike alerts overload |
| Time-to-action | <5 min | Measure from trigger to response |

### Comparison Table (if alternatives exist)

| Aspect | Approach A | Approach B |
|--------|------------|------------|
| Workflow | Step → Step → Step | Different flow |
| Pros | Benefits | Benefits |
| Cons | Drawbacks | Drawbacks |
| When to Use | Context | Context |

**Our Status:** ✅/⚠️/❌ Current state assessment.
```

### Hierarchical Concepts (e.g., Parent-Child, Org Structure)

When documenting hierarchies or nested concepts:

```markdown
## Concept Name

Brief explanation of the hierarchy.

### Type Comparison

| Type | When to Use | Key Features |
|------|-------------|--------------|
| Parent Type | Short-term, simple | Feature list |
| Child Type | Long-term, complex | Feature list |

### Depth Guidelines

Keep to 1-2 levels; max 3 rarely. Explain why deeper nesting is problematic.

### Anti-Patterns

| Anti-Pattern | Problem | Fix |
|--------------|---------|-----|
| Over-nesting | Management overhead | Flatten or restructure |
| Misuse | Wrong tool for job | Use correct alternative |

**Our Status:** ⚠️ Assessment of current state.
```

### Integration Comparisons (e.g., Tool A vs Tool B)

When documenting integrations or tool comparisons:

```markdown
## Integration Name

**[Tool] lacks native [Platform] integration** — be honest about limitations upfront.

### Available Options

| Method | Capabilities | Limitations |
|--------|--------------|-------------|
| Native | What it does | What it can't do |
| Workaround A | What it does | Effort required |
| Workaround B | What it does | Effort required |

### Feature Comparison

| Feature | Tool A | Tool B |
|---------|--------|--------|
| Feature 1 | ✅ Full support | ❌ Not available |
| Feature 2 | ⚠️ Partial | ✅ Full support |

**Our Status:** ❌ Current gap assessment.

**Recommendation:** Actionable next step.
```

### Status Indicators

Use consistent emoji for assessments:

| Emoji | Meaning | Use When |
|-------|---------|----------|
| ✅ | Good/Complete | Feature works, target met |
| ⚠️ | Warning/Partial | Needs attention, partial support |
| ❌ | Gap/Missing | Critical gap, not available |

**Important:** When ✅ and ❌ appear in same table cell, add `<br><br>` between them to prevent symbols running together in rendered output.

---

## Related Skills

- **wiki-editing**: Download-before-edit workflow, API reference
- **link-verification**: Verify repository links BEFORE writing (REQUIRED for Code References sections)
- **readme-authoring**: For README.md files (different constraints)
- **eliminating-ai-slop**: Clean, human prose (REQUIRED before pushing)


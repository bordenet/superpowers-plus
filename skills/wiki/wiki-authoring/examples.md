# Wiki Authoring - Examples

> **Parent skill:** [skill.md](./skill.md)
> **Last Updated:** 2026-03-12

Examples of slop transformation and content patterns.

---

## AI Slop Transformation Examples

### Example 1: Vague Marketing → Specific Technical

**❌ Before (slop):**
> "The system leverages advanced AI capabilities to deliver seamless real-time voice processing, ensuring optimal customer experiences."

**✅ After (specific):**
> "The system uses Deepgram for speech-to-text (200ms p95 latency) and GPT-4o for intent classification. See [Speech: Deepgram](/doc/speech-deepgram-xyz) for configuration."

### Example 2: Missing Citations → Sourced Claims

**❌ Before:**
> "According to our deployment process, all changes require review."

**✅ After:**
> "According to [our deployment process](/doc/deployment-guide-abc), all changes require review."

### Example 3: Generic Statements → Actionable Guidance

**❌ Before:**
> "The system follows industry best practices for security."

**✅ After:**
> "The system uses OAuth 2.0 + PKCE for auth, stores secrets in Azure Key Vault, and follows OWASP Top 10 guidelines. See [Security Architecture](/doc/security-arch-xyz)."

---

## Link Verification Report Example

Before publishing, generate this report:

```
## ✅ Link Verification Report

| Link Text | URL | Status | Notes |
|-----------|-----|--------|-------|
| Example Link | https://example.com | ✅ Valid | 200 OK |
| Wiki Page | /doc/page-id | ✅ Valid | Resolves to "Page Title" |
| Repo Link | [repo-url] | ❌ BROKEN | Repo not found |
| API Docs | https://api.example.com | ✅ Valid | 401 (auth required, expected) |

**Broken links fixed:** 
- Changed [repo-url] to [correct-repo-url]

**Ready to publish:** Yes
```

---

## Secret Detection Examples

### ❌ Real Credentials (BLOCK)

```
Password=j69KZhsk_6935Bayn2W0ZZmA
api_key=sk-proj-abc123xyz
Bearer eyJhbGciOiJIUzI1NiIs...
```

### ✅ Safe Alternatives

```
Password=${DB_PASSWORD}
Password=[REDACTED: production SQL password]
api_key=${OPENAI_API_KEY}
Bearer ${AUTH_TOKEN}
```

---

## Page Structure Example

### Good Structure

```markdown
> **Summary:** What this page covers in one sentence.

Brief paragraph of context.

## First Section

Content with specific details, not vague claims.

### Subsection

- Bullet point with action item
- Another action item with [link to source](/doc/xyz)

## Second Section

| Table | With |
|-------|------|
| Real | Data |

### Code Example

\`\`\`typescript
// Always specify language
const example = true;
\`\`\`

## Related Documents

- [Related Page](/doc/related-xyz)
- [External Resource](https://example.com)
```

### Bad Structure (Anti-Patterns)

```markdown
# Page Title

In today's fast-paced environment, it's important to note that...

This leverages cutting-edge technology to deliver seamless solutions.

Things to know:
- Generic statement 1
- Generic statement 2
- Generic statement 3

<div class="custom-class">
HTML that won't render
</div>
```

---

## Common Anti-Patterns Quick Reference

| Anti-Pattern | Problem | Fix |
|--------------|---------|-----|
| HTML tags | Escaped or broken | Use pure markdown |
| `> [!info]` syntax | Escaped as `\[!info\]` | Use `> **Note:**` instead |
| Starting with `# Title` | Duplicates UI title | Start with summary or `##` |
| No blank lines around tables | Rendering issues | Add blank lines |
| Bare URLs | Hard to read/click | Use `[text](url)` |
| Deep nesting (H5+) | Hard to navigate | Flatten to H3/H4 max |
| "leverages/seamless" | AI slop | Be specific |
| Missing citations | Unverifiable claims | Link to sources |

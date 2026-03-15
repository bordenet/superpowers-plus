# Claude Code Official Marketplace Submission

**Target:** `anthropics/claude-plugins-official` external_plugins directory

## Submission Checklist

| Requirement | Status | Notes |
|-------------|--------|-------|
| `.claude-plugin/plugin.json` exists | ✅ PASS | Created with v2.4.1 |
| `plugin.json` has required fields | ✅ PASS | name, description, version, author |
| `plugin.json` NO category/source keys | ✅ PASS | Avoided known bug |
| `components.skills` declared | ✅ PASS | Points to `skills/` |
| Public GitHub repo | ✅ PASS | github.com/bordenet/superpowers-plus |
| README with install instructions | ✅ PASS | Multiple install methods |
| MIT License | ✅ PASS | LICENSE file present |
| Skills have SKILL.md with frontmatter | ✅ PASS | 38/38 skills validated |

## Draft Submission

### Plugin Name
`superpowers-plus`

### Category
`Skills` (extends obra/superpowers)

### Short Description (for directory listing)
AI slop detection (300+ patterns, 0-100 scoring) and elimination (GVR rewrite loop) plus 38 skills for wiki, issue tracking, security.

### Full Description
superpowers-plus extends Jesse Vincent's obra/superpowers with 38 domain skills across 9 categories:

**Flagship Writing Skills:**
- `detecting-ai-slop`: Quantifies AI slop with 0-100 scoring. 300+ lexical patterns, 13 content types (CV, email, LinkedIn, PRD), stylometric analysis (sentence variance, TTR, hapax rate).
- `eliminating-ai-slop`: Generate-Verify-Refine (GVR) loop prevents slop during prose generation. 11 rewriting strategies, interactive and automatic modes, dictionary management.

**Additional Domains:**
- Wiki management (7 skills): authoring, editing, link verification, secret scanning
- Issue tracking (5 skills): Linear/GitHub/Jira/Azure DevOps adapters
- Engineering (5 skills): pre-commit gates, blast radius checks, PR review
- Productivity (6 skills): innovation, TODO management, style enforcement
- Observability (5 skills): skill effectiveness, firing tracking, completeness checks
- Security (2 skills): CVE scanning, public repo IP audit
- Research (2 skills): Perplexity integration
- Experimental (1 skill): self-prompting

### Installation Command
```
/plugin install https://github.com/bordenet/superpowers-plus
```

### Prerequisite
Requires `obra/superpowers` (installed automatically via marketplace.json dependency).

## Known Bug: category/source Key Contamination

**Issue:** `anthropics/claude-code/issues/26555`

When the marketplace installs plugins, it can write `category` and `source` keys from `marketplace.json` into cached `plugin.json` files, causing validation failures.

**Workaround:** We do NOT include `category` or `source` keys in our `plugin.json`. Those fields exist only in `marketplace.json`.

If users report install failures:
1. Delete cached plugin at `~/.claude-code/plugins/superpowers-plus/`
2. Re-run `/plugin install`

## Submission Process

1. Fork `anthropics/claude-plugins-official`
2. Create directory: `external_plugins/superpowers-plus/`
3. Add `plugin.json`:
   ```json
   {
     "name": "superpowers-plus",
     "description": "AI slop detection (300+ patterns) and elimination (GVR loop) plus 36 skills for wiki, issue tracking, security",
     "version": "2.4.1",
     "homepage": "https://github.com/bordenet/superpowers-plus",
     "source": "https://github.com/bordenet/superpowers-plus.git",
     "author": {
       "name": "Matt Bordenet"
     }
   }
   ```
4. Open PR with:
   - Title: `Add superpowers-plus to external plugins`
   - Description: Short summary focusing on slop detection differentiation
   - Reference: Link to obra/superpowers as the prerequisite/base

## TODO

- [ ] Monitor Anthropic's plugin directory submission form: https://clau.de/plugin-directory-submission
- [ ] Verify current PR requirements (check open PRs for examples)
- [ ] Test direct install: `/plugin install https://github.com/bordenet/superpowers-plus`
- [ ] Confirm obra/superpowers dependency installs correctly

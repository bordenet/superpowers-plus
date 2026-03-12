# Claude Code Official Marketplace Submission

**Target:** `anthropics/claude-plugins-official` external_plugins directory

## Submission Checklist

| Requirement | Status | Notes |
|-------------|--------|-------|
| `.claude-plugin/plugin.json` exists | ✅ PASS | Created with v2.4.0 |
| `plugin.json` has required fields | ✅ PASS | name, description, version, author |
| `plugin.json` NO category/source keys | ✅ PASS | Avoided known bug |
| `components.skills` declared | ✅ PASS | Points to `skills/` |
| Public GitHub repo | ✅ PASS | github.com/bordenet/superpowers-plus |
| README with install instructions | ✅ PASS | Multiple install methods |
| MIT License | ✅ PASS | LICENSE file present |
| Skills have SKILL.md with frontmatter | ✅ PASS | 41/41 skills validated |

## Draft Submission

### Plugin Name
`superpowers-plus`

### Category
`Skills` (extends obra/superpowers)

### Short Description (for directory listing)
AI slop detection (300+ patterns, 0-100 scoring) and elimination (GVR rewrite loop) plus 39 skills for wiki, issue tracking, TypeScript, security.

### Full Description
superpowers-plus extends Jesse Vincent's obra/superpowers with 41 domain skills across 10 categories:

**Flagship Writing Skills:**
- `detecting-ai-slop`: Quantifies AI slop with 0-100 scoring. 300+ lexical patterns, 13 content types (CV, email, LinkedIn, PRD), stylometric analysis (sentence variance, TTR, hapax rate).
- `eliminating-ai-slop`: Generate-Verify-Refine (GVR) loop prevents slop during prose generation. 11 rewriting strategies, interactive and automatic modes, dictionary management.

**Additional Domains:**
- Wiki management (7 skills): authoring, editing, link verification, secret scanning
- Issue tracking (5 skills): Linear/GitHub/Jira/Azure DevOps adapters
- TypeScript (5 skills): strict mode migration, complexity refactoring, Vitest patterns
- Engineering (5 skills): pre-commit gates, blast radius checks, PR review
- Security (2 skills): CVE scanning, public repo IP audit
- Observability (4 skills): skill firing tracking, completeness checks
- Research (2 skills): Perplexity integration
- Productivity (5 skills): TODO management, style enforcement

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
     "description": "AI slop detection (300+ patterns) and elimination (GVR loop) plus 39 skills for wiki, issue tracking, TypeScript, security",
     "version": "2.4.0",
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


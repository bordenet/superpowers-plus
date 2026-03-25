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
| Skills have skill.md with frontmatter | ✅ PASS | 58/58 skills validated |

## Draft Submission

### Plugin Name
`superpowers-plus`

### Category
`Skills` (extends obra/superpowers)

### Short Description (for directory listing)
AI slop detection (300+ patterns, 0-100 scoring) and elimination (GVR rewrite loop) plus 58 skills for wiki, issue tracking, security.

### Full Description
superpowers-plus extends Jesse Vincent's obra/superpowers with 58 domain skills across 9 categories:

**Flagship Writing Skills:**
- `detecting-ai-slop`: Quantifies AI slop with 0-100 scoring. 300+ lexical patterns, 13 content types (CV, email, LinkedIn, PRD), stylometric analysis (sentence variance, TTR, hapax rate).
- `eliminating-ai-slop`: Generate-Verify-Refine (GVR) loop prevents slop during prose generation. 11 rewriting strategies, interactive and automatic modes, dictionary management.

**Additional Domains:**
- Engineering (15 skills): blast radius, design triad, TDD, code review, systematic debugging, feature lifecycle
- Productivity (14 skills): TODO tracking, adversarial search, domain design, think-twice, innovation, skill authoring
- Writing (7 skills): slop detection/elimination, profanity gates, table discipline, README authoring, skill file authoring
- Wiki (6 skills): orchestrator pipeline, link checks, credential scanning, fact-checking, content coherence
- Issue tracking (5 skills): provider-neutral issue-tracker adapters
- Observability (4 skills): completeness checks, audit validation, repo verification, diagnostics
- Security (4 skills): CVE scanning, IP protection, instruction guard, repo security scan
- Research (2 skills): Perplexity integration
- Experimental (1 skill): self-prompting

### Installation Command
```
/plugin install https://github.com/bordenet/superpowers-plus
```

### Prerequisite
Requires `obra/superpowers`. The Claude marketplace does not have a dependency resolution mechanism — `install.sh` handles cloning obra/superpowers as a prerequisite. Users installing via `/plugin install` should install obra/superpowers first, or use `install.sh` which handles both.

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
     "description": "AI slop detection (300+ patterns) and elimination (GVR loop) plus 58 skills for wiki, issue tracking, security",
     "version": "2.5.1",
     "homepage": "https://github.com/bordenet/superpowers-plus",
     "author": {
       "name": "Matt Bordenet"
     }
   }
   ```
   > **Note:** Do NOT include `category` or `source` keys — see Known Bug section above.
4. Open PR with:
   - Title: `Add superpowers-plus to external plugins`
   - Description: Short summary focusing on slop detection differentiation
   - Reference: Link to obra/superpowers as the prerequisite/base

## TODO — DEPRIORITIZED

> **Status:** Indefinitely deferred. Anthropic's plugin marketplace acceptance is unlikely.
> These items are preserved for reference only — do not actively pursue.

- [ ] Monitor Anthropic's plugin directory submission form: https://clau.de/plugin-directory-submission
- [ ] Verify current PR requirements (check open PRs for examples)
- [ ] Test direct install: `/plugin install https://github.com/bordenet/superpowers-plus`
- [ ] Confirm obra/superpowers prerequisite is documented clearly (no auto-install via marketplace)

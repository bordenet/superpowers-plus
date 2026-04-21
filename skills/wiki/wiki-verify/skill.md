---
name: wiki-verify
source: superpowers-plus
triggers: ["verify this wiki page", "fact-check the vendor page", "check if wiki is up to date", "run wiki audit", "is this documentation stale", "validate wiki accuracy", "check wiki accuracy", "verify wiki facts"]
anti_triggers: ["edit wiki", "update wiki page", "create wiki page", "write wiki"]
description: Use when wiki pages reference codebase details (versions, repos, configs) that may drift. Verifies claims against authoritative sources and auto-applies fixes by default.
summary: "Use when: wiki references codebase details that may have drifted. Skip when: reading wiki only."
coordination:
  group: wiki
  order: 4
  requires: []
  enables: []
  escalates_to: ['wiki-orchestrator']
  internal: false
composition:
  consumes: [wiki-content]
  produces: [verification-report]
  capabilities: [verifies-facts, validates-completeness]
  priority: 30
---

# wiki-verify

Detect stale codebase claims (version numbers, repo names, file paths, config
values) in wiki pages. Wrong skill? Links → `link-verification` · Secrets →
`wiki-secret-audit` · Fact-check decisions/dates → `wiki-debunker` · Edit
pipeline → `wiki-orchestrator`.

## Modes

| Mode | Flag | Behavior |
|------|------|----------|
| Fix | (default) | Auto-apply all fixes (Haiku-safe) |
| Interactive | `--interactive` | Prompt before each fix |
| Report | `--report` | Output diff only, no writes |

## Procedure

### 1 — Fetch page

```bash
tools/wiki-read.sh get "$PAGE_ID" > page.json
jq -r '.text' page.json > page.md
```

### 2 — Discover verification sources (tail block or registry)

```markdown
## 🔍 Verification Sources
<!-- wiki-verify:sources
repos: [backend-service, settings-service]
files: [backend-service/package.json#dependencies]
-->
```

Fallback: `superpowers-plus/wiki-sources.yaml` entry keyed by page id. Neither
present → STOP: "no verification sources configured."

### 3 — Classify each claim

| Claim type | Source | Pass if |
|------------|--------|---------|
| Version `vX.Y.Z` | `package.json` / `requirements.txt` | exact match |
| Repo name | `git ls-remote` / adapter | repo exists |
| File path | `git cat-file -e HEAD:<path>` | exit 0 |
| Import / vendor | `grep -r <name> src/` | any hit |
| Config value | target config file | exact match |
| PR / commit ref | `gh api`, `git log` | reference resolves |
| Date claim | `git log --after/--before` | commit exists |

Mark each: `✅ CURRENT` · `⚠️ STALE` · `❌ WRONG` · `❓ UNVERIFIABLE`.

### 4 — Apply fixes (mode-dependent)

- Default / `--fix`: write corrected body to `page.md`, re-run Stage 5.5
  (`node tools/wiki-markdown-validate.js page.md`), then
  `tools/wiki-write.sh update --doc "$PAGE_ID" --content page.md`.
- `--interactive`: prompt `[U]pdate / [S]kip / [A]ll / [Q]uit` per finding.
- `--report`: emit diff to stdout, exit 0.

### 5 — Maintenance footer (required after any write)

Page MUST end with `*🔄 AI-maintained — invoke wiki-verify skill to update*`
placed after `## 🔍 Verification Sources`. Omit dates and URLs.

## Authoritative sources

`git show/log` · repo adapter · `package.json` · `requirements.txt` · YAML/JSON/TOML
config · `.env.example`. Registry fallback: `superpowers-plus/wiki-sources.yaml`.

## Failure modes

| Failure | Fix |
|---------|-----|
| Source itself stale | Cross-reference ≥2 sources (repo + API) |
| UNVERIFIABLE left silent | Flag with `citation-needed` tag |
| False STALE on pinned version | Respect lock-file / `pinned:` annotations |
| `wiki-write.sh` exit 1 | STOP; ask user; do not retry |

Background, mode rationale, authoritative-source ordering: `rationale.md`.

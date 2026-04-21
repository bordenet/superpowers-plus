---
name: link-verification
source: superpowers-plus
triggers: ["add code reference", "link to repo", "reference the wiki page", "cite the issue ticket", "verify links", "check if URL exists", "verify this URL", "check this link", "wiki:verify-links", "link:verify"]
anti_triggers: ["verify issue links", "check ticket URLs", "issue link"]
description: Use when adding repository links, code references, internal wiki links, or external URLs to documentation. Invoke BEFORE writing any link to prevent hallucination. Also invoked by wiki-orchestrator as HARD GATE (Stage 3, after content generation, before publish).
summary: "Use when: writing wiki pages with URLs. Hard gate — verify before publish."
composition:
  consumes: [markdown-content]
  produces: [verified-links]
  capabilities: [validates-links]
  priority: 20
coordination:
  group: wiki
  order: 1
  requires: []
  enables: []
  escalates_to: ['wiki-orchestrator']
  internal: false
---

# link-verification

Hard gate for internal wiki, repo, and external URLs. **AI models hallucinate
URLs.** Verify before write. Wrong skill? Issue tickets →
`issue-link-verification` · Wiki claims → `wiki-verify`.

## Gate (exit `0` ok · `1` block · `2` warn-only)

| Type | Example | On failure |
|------|---------|------------|
| Internal wiki | `/doc/slug-xyz123` | **HARD BLOCK** (404) |
| Repo | `https://github.com/{org}/{repo}` | **HARD BLOCK** (often hallucinated) |
| Issue ref | `#1234`, `ORG-42` | WARN (may be private) |
| External | `https://example.com` | WARN (transient downtime) |

Exit `1` → orchestrator MUST halt publish; exit `2` → publish with user ack.

## Procedure

### 1 — Extract links

```bash
{ grep -nE '\[[^]]+\]\([^)]+\)' draft.md
  grep -nEo 'https?://[^[:space:]<>()]+' draft.md; } > links.txt
```

### 2 — Verify each link (exit-code contract)

```bash
block=0; warn=0
while IFS= read -r line; do
  url=$(echo "$line" | sed -E 's/.*\(([^)]+)\).*/\1/; s/.*: //')
  case "$url" in
    /doc/*)
      tools/wiki-read.sh get "${url#/doc/}" > /dev/null 2>&1 \
        && echo "PASS  wiki  $url" \
        || { echo "FAIL  wiki  $url"; block=1; } ;;
    https://github.com/*)
      repo=$(echo "$url" | sed -E 's#https://github\.com/([^/]+/[^/]+).*#\1#')
      gh api "repos/$repo" > /dev/null 2>&1 \
        && echo "PASS  repo  $url" \
        || { echo "FAIL  repo  $url"; block=1; } ;;
    http*://*)
      code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 8 "$url")
      [ "$code" = 200 ] && echo "PASS  ext   $url" \
        || { echo "WARN  ext   $url (HTTP $code)"; warn=1; } ;;
  esac
done < links.txt
exit $(( block ? 1 : (warn ? 2 : 0) ))
```

### 3 — On FAIL (wiki or repo)

1. `tools/wiki-read.sh search "<keywords>"` (wiki) or `gh search repos "<name>"` (GitHub)
2. Replace the link in the draft with the verified URL
3. Re-run Step 2. Do NOT publish until exit `0` or `2`.

## Hallucination patterns to never trust blind

| Pattern | Why wrong |
|---------|-----------|
| `github.com/{assumed-org}/{repo}` | Model assumes GitHub is universal |
| File links with line numbers | File structure changes |
| `main` branch | May be `master` or other |
| `/doc/made-up-slug` | Wiki slug fabricated without API check |

## Failure modes

| Failure | Fix |
|---------|-----|
| 200 but content doesn't match | Read target title; confirm anchor match |
| Wiki slug valid but wrong page | Compare `wiki-read.sh get` title against anchor |
| Timeout → WARN by default | Retry once; then mark FAIL not WARN |
| Only checked wiki, skipped external | Run Step 2 for ALL types every time |

Background, incident log, and code-references template: see
`references/code-references-template.md` if present.

Companions: wiki-orchestrator · wiki-verify · wiki-content-coherence · wiki-debunker · issue-link-verification · verification-before-completion

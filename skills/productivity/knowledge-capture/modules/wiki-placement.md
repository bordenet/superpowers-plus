# Wiki Placement Algorithm

## Before ANY wiki operation
Load `outline-wiki-guardrails` skill (per core.always.md rule).

## Pre-Publish Checks

### 1. Duplicate Detection
Search Outline for existing pages matching the topic:
```
documents.search(query: "<topic keywords>", limit: 10)
```
- If page with >80% title overlap exists: ask interviewee — update existing or create new?
- If existing page is found but different scope: note as related, cross-link

### 2. Secret Scan
Before publish, scan article content for common patterns:
- API keys / tokens (long alphanumeric strings, `Bearer`, `api_key`, `secret`)
- Internal URLs that shouldn't be in wiki (localhost, staging endpoints)
- Customer names or PII
- If found: flag to interviewee, do NOT auto-redact

### 3. Placement Ranking

**Step 1:** Search Outline by topic keywords
```
documents.search(query: "<topic>", limit: 5)
```

**Step 2:** For each result, extract collection and parent document path

**Step 3:** Cluster results by parent location

**Step 4:** Rank by:
1. Number of related pages already in that location (highest weight)
2. Keyword relevance of collection/parent titles
3. Collection breadth (prefer specific collections over broad ones)

**Step 5:** Decision:
- If 3+ related pages in one location → propose that location
- If 2 locations are competitive → present both to interviewee
- If no related pages found → ask interviewee directly
- If UPDATE mode → publish to existing page location

## Publish Execution by Mode

**create:** `documents.create` with `collectionId` and optional `parentDocumentId`. Set `publish: true`.
**update:** `documents.update` with `id` from state file `Existing page ID`. Fetch existing content first, merge changes.
**companion:** `documents.create` as a sibling of the existing page — use the same `parentDocumentId` and `collectionId` as the existing page. Cross-link both pages.
2. Use `url` field (not `urlId`) for the published link
3. Post-publish verification: `documents.info` → scan for `\[`, `&nbsp;`, broken embeds
4. Open in default browser:
   - macOS: `open "<url>"`
   - Linux: `xdg-open "<url>"`
   - Windows/WSL: `cmd.exe /c start "<url>"`
5. Report URL to interviewee

## Outline Outage Fallback

If API call fails (network error, 5xx, auth failure):
1. Save approved draft to local file: `~/.codex/knowledge-capture/drafts/<topic-slug>-draft.md`
2. Update state file: `Publish URL: pending`
3. Do NOT claim success
4. Tell interviewee: "Draft saved locally. To publish later: 'resume knowledge-capture'"

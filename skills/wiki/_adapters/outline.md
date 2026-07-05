# Wiki Adapter — Outline

Platform adapter for [Outline](https://www.getoutline.com/) (self-hosted or cloud).

## Required Environment Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `OUTLINE_API_URL` | Base URL of your Outline instance (no `/api` suffix) | `https://wiki.example.com` |
| `OUTLINE_API_KEY` | API key (Settings → API → Create token) | `ol_api_...` |

Set in `~/.codex/.env`:
```bash
WIKI_PLATFORM=outline
OUTLINE_API_URL=https://your-outline-instance.com
OUTLINE_API_KEY=ol_api_your_key_here
```

**Variable bridge for `wiki-read.sh` / `wiki-write.sh`:** Those tools use `WIKI_API_KEY` and `WIKI_API_URL` (with `/api` appended). Bridge once before calling them:

```bash
source ~/.codex/.env
export WIKI_API_KEY="$OUTLINE_API_KEY"

# Proxy liveness: test local addresses and common proxy misconfigurations; fall back to direct on failure.
# No -f: any HTTP response (200, 401, ...) means the proxy is up — only connection failure triggers fallback.
_raw_url="${OUTLINE_API_URL:-}"
if [ -z "$_raw_url" ]; then
  echo "ERROR: OUTLINE_API_URL is not set — cannot resolve wiki API URL" >&2
  exit 1
else
  _raw_url="${_raw_url%/}"
  # Test local addresses and common proxy misconfigurations (0.0.0.0 = wildcard bind).
  # No -f: any HTTP response (200, 401, ...) means the proxy is up — only TCP failure triggers fallback.
  case "$_raw_url" in
    *127.0.0.1*|*localhost*|*\[::1\]*|*0.0.0.0*)
      if curl -s --connect-timeout 0.5 --max-time 0.5 -o /dev/null \
           -X POST "$_raw_url/api/auth.info" \
           -H "Content-Type: application/json" -d '{}' 2>/dev/null; then
        export WIKI_API_URL="$_raw_url/api"
      else
        if [ -z "${OUTLINE_API_DIRECT_URL:-}" ]; then
          echo "ERROR: local proxy unreachable and OUTLINE_API_DIRECT_URL is not set — cannot fall back" >&2
          echo "       Set OUTLINE_API_DIRECT_URL=https://your-outline-instance.com in ~/.codex/.env" >&2
          exit 1
        fi
        echo "WARNING: local proxy unreachable — falling back to direct URL (requires VPN)" >&2
        export WIKI_API_URL="${OUTLINE_API_DIRECT_URL%/}/api"
      fi
      ;;
    *)
      export WIKI_API_URL="$_raw_url/api"
      ;;
  esac
fi
```

> **Anti-pattern:** `WIKI_API_URL=$(some_cmd || echo 'https://...')`  
> If `some_cmd` exits 0 but stdout is empty (variable not set in .env), the `|| echo` never fires — variable is set to the empty string and propagates silently. Use shell default expansion `${var:-fallback}` instead.

## Preferred Entrypoints

**Reads** — use `wiki-read.sh` (get, search, list). Run the bridge block above first so `$WIKI_API_KEY` and `$WIKI_API_URL` are exported:

```bash
WIKI_API_KEY="$WIKI_API_KEY" WIKI_API_URL="$WIKI_API_URL" \
  ~/.codex/superpowers-plus/tools/wiki-read.sh get <id-or-slug-or-url>
WIKI_API_KEY="$OUTLINE_API_KEY" WIKI_API_URL="$WIKI_API_URL" \
  ~/.codex/superpowers-plus/tools/wiki-read.sh search "query"
```

**Writes** — use `wiki-write.sh` (create, update, move). Run the bridge block above first so `$WIKI_API_KEY` and `$WIKI_API_URL` are exported:

```bash
WIKI_API_KEY="$WIKI_API_KEY" WIKI_API_URL="$WIKI_API_URL" \
  ~/.codex/superpowers-plus/tools/wiki-write.sh create --parent UUID --title STR --content FILE [--collection UUID]
WIKI_API_KEY="$WIKI_API_KEY" WIKI_API_URL="$WIKI_API_URL" \
  ~/.codex/superpowers-plus/tools/wiki-write.sh update --doc UUID [--title STR] --content FILE
WIKI_API_KEY="$WIKI_API_KEY" WIKI_API_URL="$WIKI_API_URL" \
  ~/.codex/superpowers-plus/tools/wiki-write.sh move   --doc UUID --parent UUID
```

`wiki-write.sh` runs scope check → API write → round-trip re-fetch in a single call, emitting `{"ok":true,"id":"...","url":"...","title":"..."}`. Exit codes: `0` verified, `1` scope violation, `2` env/arg error, `3` API error, `4` verification failed.

Use the lower-level MCP tool table below only for operations not covered by the wrappers (`list_collections`, `delete_page`, `archive_page`).

## MCP Tool Mappings

| Generic Operation | MCP Tool |
|-------------------|----------|
| `list_collections` | `list_collections_outline` |
| `create_page` | `create_document_outline` |
| `update_page` | `update_document_outline` |
| `get_page` | `wiki-read.sh get <id>` (no direct MCP tool) |
| `search_pages` | `wiki-read.sh search <query>` (prefer); `list_documents_outline` if unavailable |
| `delete_page` | *(no MCP tool — use API directly)* |
| `archive_page` | *(no MCP tool — use API directly)* |
| `move_page` | `move_document_outline` |
| `verify_link` | curl against `$WIKI_API_URL` (see URL Patterns section) |

## Field Mappings

| Generic Field | Outline Field | Notes |
|---------------|---------------|-------|
| `title` | `title` | |
| `content` | `text` | Markdown |
| `collection_id` | `collectionId` | UUID of the collection |
| `parent_id` | `parentDocumentId` | Optional; nests under parent page |
| `url` | `url` | `$OUTLINE_API_URL/doc/{title-slug}-{urlId}` |
| `url_id` | `urlId` | Short alphanumeric suffix in page URL |

## Table of Contents Behavior

<EXTREMELY_IMPORTANT>
Outline does NOT auto-generate an in-page TOC. toc_behavior is `manual`.
Use `+++` toggle blocks ONLY. HTML `<details>`, `:::details`, and `<summary>` render as raw tags and do NOT work.
</EXTREMELY_IMPORTANT>

| Field | Value | Notes |
|-------|-------|-------|
| `toc_behavior` | `manual` | Outline does NOT auto-generate an in-page TOC. Insert a `+++` toggle block on pages with 4+ H2/H3 headings. |
| `toc_syntax` | `+++` | Wrap a bullet list of anchor links in `+++` markers (Outline toggle block). `<details>` and `:::details` are NOT valid — they render as raw HTML. |
| `toc_placement` | After intro paragraph, before first H2. No intro paragraph? Place on first line. | |
| `toc_anchor_format` | `#h-{slug}` | Outline prepends `h-` to the slug. Never use bare `#{slug}`. |

### Correct TOC format

```markdown
+++
**Table of contents**
- [Section One](#h-section-one)
- [Section Two](#h-section-two)
  - [Sub-section](#h-sub-section)
+++
```

Slug rules: lowercase, strip non-word chars, spaces to hyphens, collapse hyphens, prepend `h-`.

## URL Patterns

Outline page URLs follow: `$OUTLINE_API_URL/doc/{title-slug}-{urlId}`

For link verification, strip the domain and verify the `urlId` suffix is resolvable via:
```bash
curl -sS --connect-timeout 10 --max-time 30 \
  -X POST "$WIKI_API_URL/documents.info" \
  -H "Authorization: Bearer $WIKI_API_KEY" \
  -H "X-Proxy-Token: $WIKI_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"id":"{urlId}"}' | jq -e '.data.title'
# jq -e exits non-zero if .data.title is null (document not found or API error).
# Note: -sS without -f exits 0 on HTTP 4xx/5xx — only jq -e catches the null case.
# (documents.info does not return an .ok field — check .data.id non-null or .error absent)
```

## Fallback (MCP Unavailable)

Prefer `wiki-read.sh` / `wiki-write.sh` over raw curl. Use this section only when those scripts are not installed.

Run the variable bridge block above first so `$WIKI_API_KEY` and `$WIKI_API_URL` are set.

```bash
# Create a document
curl -sS --connect-timeout 10 --max-time 30 \
     -X POST "$WIKI_API_URL/documents.create" \
     -H "Authorization: Bearer $WIKI_API_KEY" \
     -H "X-Proxy-Token: $WIKI_API_KEY" \
     -H "Content-Type: application/json" \
     -d '{"title":"...","text":"...","collectionId":"...","publish":true}'

# Update a document
# Payload must contain: {"id":"<uuid>","text":"<markdown>","publish":true}
# Optional: add "title":"<new title>" to rename simultaneously.
# Always write payload to a temp file — never inline markdown in -d '...' (special chars corrupt).
PAYLOAD=$(mktemp /tmp/wiki-payload.XXXXXX.json)
python3 -c "import json,sys; print(json.dumps({'id':'<uuid>','text':open('/tmp/wiki-update.md').read(),'publish':True}))" > "$PAYLOAD"
curl -sS --connect-timeout 10 --max-time 30 \
     -X POST "$WIKI_API_URL/documents.update" \
     -H "Authorization: Bearer $WIKI_API_KEY" \
     -H "X-Proxy-Token: $WIKI_API_KEY" \
     -H "Content-Type: application/json" \
     -d "@$PAYLOAD"
rm -f "$PAYLOAD"

# Fetch a document by ID (for round-trip verification)
curl -sS --connect-timeout 10 --max-time 30 \
     -X POST "$WIKI_API_URL/documents.info" \
     -H "Authorization: Bearer $WIKI_API_KEY" \
     -H "X-Proxy-Token: $WIKI_API_KEY" \
     -H "Content-Type: application/json" \
     -d '{"id":"..."}' | jq '.data.text'

# Archive a document
curl -sS --connect-timeout 10 --max-time 30 \
     -X POST "$WIKI_API_URL/documents.archive" \
     -H "Authorization: Bearer $WIKI_API_KEY" \
     -H "X-Proxy-Token: $WIKI_API_KEY" \
     -H "Content-Type: application/json" \
     -d '{"id":"..."}'
```

> **Note:** `-sS` without `-f` exits 0 on HTTP 4xx/5xx (only network failures are non-zero). For info/create/update responses check `.data.id` is non-null; `.error` absent is the reliable success indicator. For update payloads use `mktemp` and `-d @$PAYLOAD` (as shown above) — never inline markdown in `-d '...'` (special characters corrupt the payload).

## Publishing Verification Contract

1. **Pre-create duplicate check (create only, skip for updates):** Before calling `create_document_outline`,
   search for an existing document with the same or near-identical title via `list_documents_outline` (this
   is exactly the full-text search use case this tool is for, distinct from the round-trip ID lookup in step
   3, which it must never be used for). If a plausible match is found, surface it to the user and get explicit
   confirmation before proceeding — don't silently create a duplicate, and don't silently refuse either, since
   two legitimately distinct pages can share a similar title.
2. **Pre-write scan:** Run `tools/wiki-markdown-validate.js` on the outbound markdown.
   Check for: `\\[`, `\\]`, literal `&nbsp;`, literal `&mdash;`, empty hrefs, malformed tables.
3. **Write:** Call `create_document_outline` or `update_document_outline`.
4. **Round-trip:** Re-fetch via curl `documents.info` (no direct MCP tool for ID-based fetch —
   do NOT use `list_documents_outline` for this; it performs full-text search, not ID lookup).
   Re-run the same artifact scan on the returned `.data.text`. Fail closed if new artifacts appear.

## Scope Guards (Outline-Specific)

- **Allowed write roots:** check `outline-scope.json` (managed by sp-update) before any create/move.
- **Root-level creates** require a human-placed approval token: `~/.codex/outline-approval.token`.
- See MCP scope guard docs in `~/.codex/superpowers-plus/tools/` (wiki-scope-check.sh and wiki-scope-manage.sh).

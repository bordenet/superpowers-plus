# Wiki Scope Enforcement

One-shot wrappers that let any agent — from frontier models down to small
instruct-tuned models — read from and write to a document-management wiki
without constructing URLs, auth headers, or scope logic by hand.

## What this is

Three shell scripts:

| Script | Purpose |
|--------|---------|
| `tools/wiki-scope-check.sh` | Parent-walk a document ID and exit 0 only if it sits under an allowed root. |
| `tools/wiki-write.sh`       | Wrapper around `documents.create|update|move` that runs the scope check, then the write, then a post-write re-fetch to verify. |
| `tools/wiki-read.sh`        | Wrapper around `documents.info|search|list` that returns canonical JSON (including the upstream `url` field verbatim). |

They target any wiki whose HTTP API exposes the JSON-RPC verbs listed above on
a base URL, returning `{data:{id,title,url,...}}`-shaped responses. See
"Adapting to other APIs" below for wire-format variations.

## Why

- **No URL hallucination.** `wiki-read.sh` returns the upstream `url` verbatim;
  callers never assemble slugs.
- **No scope-check bypass.** `wiki-write.sh` runs `wiki-scope-check.sh` before
  every write and aborts (exit 1) on violation.
- **Write verification.** Every write is followed by a `documents.info` fetch
  to prove the server accepted it.
- **Small-model safe.** The whole API contract is `<script> <action> <args>`.
  No token juggling, no header construction, no endpoint selection.

## Configure

| Env var          | Required | Description |
|------------------|----------|-------------|
| `WIKI_API_URL`   | yes      | Base URL of the wiki API, e.g. `https://wiki.example.com/api`. |
| `WIKI_API_KEY`   | yes      | Bearer token. |
| `WIKI_SCOPE_FILE`| no       | Path to the scope policy JSON. Default: `~/.config/wiki-scope/wiki-scope.json`. |

Example:

```bash
export WIKI_API_URL="https://wiki.example.com/api"
export WIKI_API_KEY="$(cat ~/.secrets/wiki-token)"
export WIKI_SCOPE_FILE="$HOME/.config/wiki-scope/wiki-scope.json"
```

## Scope file schema

```json
{
  "allowedScopes": [
    {
      "name": "My personal subtree",
      "collectionId": "col-uuid-here",
      "allowedRootDocumentId": "doc-uuid-here"
    }
  ]
}
```

`wiki-scope-check.sh` walks from a target document toward the collection root.
If it hits any `allowedRootDocumentId`, the check passes. Otherwise it fails
with exit 1 and prints the walked chain.

An empty `allowedScopes` array means **every write is denied** — fail-closed
by design.

## Usage — `wiki-read.sh`

```
wiki-read.sh get <id-or-slug-or-url>         # full document as JSON
wiki-read.sh url <id-or-slug-or-url>         # just the canonical URL
wiki-read.sh search <query> [--limit N]      # array of matches
wiki-read.sh list  --collection UUID         # list in a collection
wiki-read.sh list  --parent UUID [--limit N] # list under a parent
```

Accepts bare UUIDs, slugs, or full URLs — the last path segment is extracted
automatically. Exit codes: `0` success, `2` env/arg error, `3` API error,
`4` not found.

## Usage — `wiki-write.sh`

```
wiki-write.sh create --parent UUID --title STR --content FILE [--collection UUID]
wiki-write.sh update --doc UUID [--title STR] --content FILE
wiki-write.sh move   --doc UUID --parent UUID
```

Output on success (single-line JSON):

```json
{"ok":true,"id":"...","url":"https://...","title":"..."}
```

Exit codes: `0` success + verified, `1` scope violation, `2` env/arg error,
`3` API error, `4` post-write verification failed.

For `move`, **both** the document and the target parent must be in scope.

## Adapting to other document APIs

The scripts assume the following wire contract (common to several
document-management platforms):

- `POST {WIKI_API_URL}/documents.info`   body `{"id":"..."}` → `{data:{id,title,url,text,collectionId,parentDocumentId}}`
- `POST {WIKI_API_URL}/documents.create` body `{"parentDocumentId","title","text","publish":true}` → `{data:{id,url,...}}`
- `POST {WIKI_API_URL}/documents.update` body `{"id","text","publish":true}`
- `POST {WIKI_API_URL}/documents.move`   body `{"id","parentDocumentId"}`
- `POST {WIKI_API_URL}/documents.search` body `{"query","limit"}` → `{data:[{document:{...}}]}`
- `POST {WIKI_API_URL}/documents.list`   body `{"collectionId"|"parentDocumentId","limit"}` → `{data:[{...}]}`

If your wiki uses different verb names or paths, edit the `_api` function in
each script and the endpoint strings in the action dispatch. The
`_build_payload_*` helpers are the only places that construct request bodies.

## Quality gates

```bash
shellcheck tools/wiki-*.sh
bash -n    tools/wiki-*.sh
bats       test/wiki-oneshot.bats
```

The bats suite runs fully offline against an in-memory Node mock
(`test/fixtures/mock-wiki-api.js`) — no network and no real credentials.

## Exit code reference

| Code | Meaning |
|------|---------|
| 0    | Success (write verified, read returned data). |
| 1    | Scope violation — target is outside `allowedScopes`. |
| 2    | Missing env var or malformed CLI arguments. |
| 3    | Upstream API returned an error or malformed response. |
| 4    | Post-write verification failed (write may or may not have landed). |

## Troubleshooting

- **"WIKI_API_URL not set":** export it before calling the script.
- **"scope check failed":** the target is not under any `allowedRootDocumentId`.
  Either add a new scope entry or target a different document.
- **"verification: document body is empty after update":** the API accepted
  the call but stored no text. Check the request body size and the `publish:true`
  flag on your wiki's side.

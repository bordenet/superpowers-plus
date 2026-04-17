#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Script: wiki-read.sh
# PURPOSE: One-shot wiki read wrapper. Returns canonical JSON so callers never
#          have to construct URLs, slugs, or auth headers. Enforces the
#          "never assemble URLs from memory" rule by always returning the
#          upstream `url` field verbatim.
#
#          Works with any document-management RPC that exposes POST verbs:
#            documents.info  documents.search  documents.list
#          returning {data:{id,title,url,collectionId,parentDocumentId,text}}
#          (info) or {data:[{document:{...}}]} (search) or {data:[{...}]} (list).
#
# USAGE:   wiki-read.sh get <id-or-slug-or-url>
#          wiki-read.sh search <query> [--limit N]
#          wiki-read.sh list [--collection UUID] [--parent UUID] [--limit N]
#          wiki-read.sh url <id-or-slug-or-url>     # just the canonical URL
#          wiki-read.sh --help
#
# OUTPUT:  JSON on stdout. get/url return a single object; search/list return
#          an array of {id, title, url, collectionId, parentDocumentId?}.
#
# EXIT:    0 success           2 env/arg error
#          3 API error         4 not found
# -----------------------------------------------------------------------------
set -euo pipefail

if [ -z "${BASH_VERSION:-}" ]; then
    echo "ERROR: requires bash" >&2; exit 2
fi

show_help() {
    cat <<EOF
Usage: ${0##*/} <action> [args]
       ${0##*/} --help

Actions:
    get <id-or-slug-or-url>          Full document (data.id, title, url, text, ...)
    url <id-or-slug-or-url>          Print only the canonical URL (one line)
    search <query> [--limit N]       Full-text search (default limit 10)
    list  [--collection UUID]        List docs in a collection or under a parent
          [--parent UUID] [--limit N]

Environment:
    WIKI_API_KEY     API token for the wiki (required)
    WIKI_API_URL     API base URL, e.g. https://wiki.example.com/api (required)

Output (stdout, JSON):
    get:    single object {ok:true, id, title, url, collectionId, parentDocumentId, text}
    url:    bare URL string (newline-terminated)
    search: array of {id, title, url, collectionId, ...}
    list:   array of {id, title, url, collectionId, parentDocumentId, ...}

Exit codes:
    0 success    2 env/arg error    3 API error    4 not found
EOF
}

log_err() { printf '[wiki-read] ERROR: %s\n' "$*" >&2; }

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" || "${1:-}" == "help" ]]; then
    show_help; exit 0
fi

[[ -z "${WIKI_API_KEY:-}" ]] && { log_err "WIKI_API_KEY not set"; exit 2; }
[[ -z "${WIKI_API_URL:-}" ]] && { log_err "WIKI_API_URL not set"; exit 2; }
command -v jq   >/dev/null 2>&1 || { log_err "jq required"; exit 2; }
command -v curl >/dev/null 2>&1 || { log_err "curl required"; exit 2; }

_api() {
    local verb="$1" payload="$2"
    curl -sS --max-time 30 \
        -X POST "${WIKI_API_URL%/}/$verb" \
        -H "Authorization: Bearer ${WIKI_API_KEY}" \
        -H "Content-Type: application/json" \
        -d "$payload"
}

# Accept: bare UUID, slug, or full wiki URL. Strip anchor/query, and for URLs
# take the last path segment as the doc identifier — the API resolves it.
_resolve_id() {
    local in="$1"
    in="${in%%#*}"; in="${in%%\?*}"
    case "$in" in
        http*://*) in="${in##*/}";;
    esac
    printf '%s' "$in"
}

ACTION="${1:-}"
case "$ACTION" in
    -h|--help|help|"") show_help; [[ -z "$ACTION" ]] && exit 2 || exit 0 ;;
    get|url|search|list) shift ;;
    *) log_err "Unknown action: $ACTION"; show_help >&2; exit 2 ;;
esac

case "$ACTION" in
    get|url)
        target="${1:?$ACTION needs an id/slug/url argument}"
        id=$(_resolve_id "$target")
        resp=$(_api documents.info "$(jq -n --arg id "$id" '{id:$id}')") || { log_err "API error"; exit 3; }
        if ! echo "$resp" | jq -e '.data.id' >/dev/null 2>&1; then
            log_err "not found: $target (response: $(echo "$resp" | jq -c '.error // .message // "empty"'))"
            exit 4
        fi
        if [[ "$ACTION" == "url" ]]; then
            echo "$resp" | jq -r '.data.url'
        else
            echo "$resp" | jq -c '{ok:true, id:.data.id, title:.data.title, url:.data.url,
                collectionId:.data.collectionId, parentDocumentId:.data.parentDocumentId, text:.data.text}'
        fi
        ;;
    search)
        query="${1:?search needs a query string}"; shift || true
        limit=10
        while [[ $# -gt 0 ]]; do
            case "$1" in --limit) limit="$2"; shift 2 ;; *) log_err "Unknown: $1"; exit 2 ;; esac
        done
        resp=$(_api documents.search "$(jq -n --arg q "$query" --argjson lim "$limit" '{query:$q, limit:$lim}')") \
            || { log_err "API error"; exit 3; }
        echo "$resp" | jq -c '[.data[]?.document | {id, title, url, collectionId, parentDocumentId}]'
        ;;
    list)
        coll=""; parent=""; limit=25
        while [[ $# -gt 0 ]]; do
            case "$1" in
                --collection) coll="$2"; shift 2 ;;
                --parent)     parent="$2"; shift 2 ;;
                --limit)      limit="$2"; shift 2 ;;
                *) log_err "Unknown: $1"; exit 2 ;;
            esac
        done
        [[ -n "$coll" || -n "$parent" ]] || { log_err "list needs --collection or --parent"; exit 2; }
        payload=$(jq -n \
            --arg coll "$coll" --arg parent "$parent" --argjson lim "$limit" \
            '{limit:$lim}
             + (if $coll   != "" then {collectionId:$coll} else {} end)
             + (if $parent != "" then {parentDocumentId:$parent} else {} end)')
        resp=$(_api documents.list "$payload") || { log_err "API error"; exit 3; }
        echo "$resp" | jq -c '[.data[]? | {id, title, url, collectionId, parentDocumentId}]'
        ;;
esac

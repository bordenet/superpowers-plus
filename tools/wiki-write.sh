#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Script: wiki-write.sh
# PURPOSE: One-shot wiki write wrapper. Runs scope check, performs the write
#          via the wiki API, and re-fetches to verify. Intended to be called
#          by agents (any model tier) without requiring the caller to reason
#          about API endpoints, tokens, or scope policy.
#
# USAGE:   wiki-write.sh create --parent UUID --title STR --content FILE [--collection UUID]
#          wiki-write.sh update --doc UUID [--title STR] --content FILE
#          wiki-write.sh move   --doc UUID --parent UUID
#          wiki-write.sh --help
#
# OUTPUT:  JSON on stdout: {"ok":true,"id":"...","url":"...","title":"..."}
#          Error messages go to stderr; stdout stays parseable.
#
# EXIT:    0 success (verified)   1 scope violation
#          2 env/arg error        3 API error
#          4 verification failed
# -----------------------------------------------------------------------------
set -euo pipefail

if [ -z "${BASH_VERSION:-}" ]; then
    echo "ERROR: requires bash. Run with: bash $0" >&2
    exit 2
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCOPE_CHECK="${SCRIPT_DIR}/wiki-scope-check.sh"
VERBOSE=0

show_help() {
    cat <<EOF
Usage: ${0##*/} <action> [options]
       ${0##*/} --help

Actions:
    create   --parent UUID --title STR --content FILE [--collection UUID]
             Create a child document under an in-scope parent.
    update   --doc UUID [--title STR] --content FILE
             Replace the body (and optionally title) of an in-scope doc.
    move     --doc UUID --parent UUID
             Reparent an in-scope doc under another in-scope parent.

Common options:
    -v, --verbose       Show scope walk + API response details on stderr
    -h, --help          This help

Environment:
    WIKI_API_KEY        API token (required)
    WIKI_API_URL        API base URL (required)
    WIKI_SCOPE_FILE     Scope policy (default: ~/.config/wiki-scope/wiki-scope.json)

Output (stdout, JSON on success):
    {"ok":true,"id":"<uuid>","url":"<https://...>","title":"..."}

Exit codes:
    0 success + verified   1 scope violation      2 env/arg error
    3 API error            4 post-write verify failed
EOF
}

log_err()   { printf '[wiki-write] ERROR: %s\n' "$*" >&2; }
log_info()  { [[ "$VERBOSE" -eq 1 ]] && printf '[wiki-write] %s\n' "$*" >&2 || true; }

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" || "${1:-}" == "help" ]]; then
    show_help; exit 0
fi

[[ -z "${WIKI_API_KEY:-}" ]] && { log_err "WIKI_API_KEY not set"; exit 2; }
[[ -z "${WIKI_API_URL:-}" ]] && { log_err "WIKI_API_URL not set"; exit 2; }
command -v jq   >/dev/null 2>&1 || { log_err "jq required"; exit 2; }
command -v curl >/dev/null 2>&1 || { log_err "curl required"; exit 2; }
[[ -x "$SCOPE_CHECK" ]] || { log_err "wiki-scope-check.sh not found or not executable at $SCOPE_CHECK"; exit 2; }

ACTION="${1:-}"
case "$ACTION" in
    -h|--help|help|"") show_help; [[ -z "$ACTION" ]] && exit 2 || exit 0 ;;
    create|update|move) shift ;;
    *) log_err "Unknown action: $ACTION"; show_help >&2; exit 2 ;;
esac

DOC=""; PARENT=""; TITLE=""; CONTENT_FILE=""; COLLECTION=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --doc)         DOC="${2:?--doc requires a UUID}"; shift 2 ;;
        --parent)      PARENT="${2:?--parent requires a UUID}"; shift 2 ;;
        --title)       TITLE="${2:?--title requires a string}"; shift 2 ;;
        --content)     CONTENT_FILE="${2:?--content requires a file path}"; shift 2 ;;
        --collection)  COLLECTION="${2:?--collection requires a UUID}"; shift 2 ;;
        -v|--verbose)  VERBOSE=1; shift ;;
        *) log_err "Unknown option: $1"; exit 2 ;;
    esac
done

# For create: the PARENT must be in scope.
# For update: the DOC must be in scope.
# For move:   BOTH the DOC and the target PARENT must be in scope.
_run_scope() {
    local target="$1" label="$2"
    log_info "scope-check $label=$target"
    if ! "$SCOPE_CHECK" "$target" >&2; then
        log_err "scope check failed for $label=$target"
        exit 1
    fi
}

case "$ACTION" in
    create)
        [[ -n "$PARENT" && -n "$TITLE" && -n "$CONTENT_FILE" ]] || { log_err "create needs --parent --title --content"; exit 2; }
        [[ -r "$CONTENT_FILE" ]] || { log_err "content file not readable: $CONTENT_FILE"; exit 2; }
        _run_scope "$PARENT" "parent"
        ;;
    update)
        [[ -n "$DOC" && -n "$CONTENT_FILE" ]] || { log_err "update needs --doc --content"; exit 2; }
        [[ -r "$CONTENT_FILE" ]] || { log_err "content file not readable: $CONTENT_FILE"; exit 2; }
        _run_scope "$DOC" "doc"
        ;;
    move)
        [[ -n "$DOC" && -n "$PARENT" ]] || { log_err "move needs --doc --parent"; exit 2; }
        _run_scope "$DOC" "doc"
        _run_scope "$PARENT" "parent"
        ;;
esac

_api() {
    local verb="$1" payload="$2"
    curl -sS --max-time 30 \
        -X POST "${WIKI_API_URL%/}/$verb" \
        -H "Authorization: Bearer ${WIKI_API_KEY}" \
        -H "Content-Type: application/json" \
        -d "$payload"
}

_build_payload_create() {
    jq -n \
        --arg parent  "$PARENT" \
        --arg title   "$TITLE" \
        --arg text    "$(cat "$CONTENT_FILE")" \
        --arg coll    "$COLLECTION" \
        '{parentDocumentId:$parent, title:$title, text:$text, publish:true}
         + (if $coll != "" then {collectionId:$coll} else {} end)'
}
_build_payload_update() {
    jq -n \
        --arg id     "$DOC" \
        --arg title  "$TITLE" \
        --arg text   "$(cat "$CONTENT_FILE")" \
        '{id:$id, text:$text, publish:true}
         + (if $title != "" then {title:$title} else {} end)'
}
_build_payload_move() {
    jq -n --arg id "$DOC" --arg parent "$PARENT" \
        '{id:$id, parentDocumentId:$parent}'
}


case "$ACTION" in
    create) payload=$(_build_payload_create); verb="documents.create" ;;
    update) payload=$(_build_payload_update); verb="documents.update" ;;
    move)   payload=$(_build_payload_move);   verb="documents.move"   ;;
esac

log_info "POST $verb"
resp=$(_api "$verb" "$payload") || { log_err "API call failed"; exit 3; }

if ! echo "$resp" | jq -e '.ok == true or .data.id' >/dev/null 2>&1; then
    log_err "API returned error: $(echo "$resp" | jq -c '.error // .message // .' 2>/dev/null || echo "$resp")"
    exit 3
fi

# create/update return .data.id; move returns .data.document.id — or fall back to the input DOC.
doc_id=$(echo "$resp" | jq -r '.data.id // .data.document.id // "'"$DOC"'"')
[[ "$doc_id" == "null" || -z "$doc_id" ]] && { log_err "no doc id in response: $resp"; exit 3; }

verify=$(_api "documents.info" "$(jq -n --arg id "$doc_id" '{id:$id}')") || { log_err "verify fetch failed"; exit 4; }
if ! echo "$verify" | jq -e '.data.id' >/dev/null 2>&1; then
    log_err "verification: doc not retrievable after write: $verify"
    exit 4
fi

if [[ "$ACTION" == "update" ]]; then
    body_len=$(echo "$verify" | jq -r '.data.text | length')
    if [[ "$body_len" -eq 0 ]] && [[ -s "$CONTENT_FILE" ]]; then
        log_err "verification: document body is empty after update"
        exit 4
    fi
fi

echo "$verify" | jq -c '{ok:true, id:.data.id, url:.data.url, title:.data.title}'

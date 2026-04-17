#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Script: wiki-scope-check.sh
# PURPOSE: Verify a target wiki document is inside an allowed write scope
#          before any wiki edit. Walks the parentDocumentId chain up to the
#          collection root and checks the result against a scope policy file.
#
#          Works with any document-management RPC that exposes POST
#          documents.info returning {data:{id, collectionId, parentDocumentId}}.
#          Scope file format:
#            {"allowedScopes":[
#              {"name":"...", "collectionId":"<uuid>", "allowedRootDocumentId":"<uuid>"},
#              ...
#            ]}
#
# USAGE:   wiki-scope-check.sh [-v] <document-uuid-or-slug>
#          wiki-scope-check.sh --help
#
# REQUIRES: bash 4+, curl, jq
# PLATFORM: macOS, Linux, WSL2
# VERSION:  1.0.0
# -----------------------------------------------------------------------------
set -euo pipefail

if [ -z "${BASH_VERSION:-}" ]; then
    echo "ERROR: This script requires bash. Run with: bash $0" >&2
    exit 1
fi

SCOPE_FILE="${WIKI_SCOPE_FILE:-${HOME}/.config/wiki-scope/wiki-scope.json}"
MAX_DEPTH=20
VERBOSE=0

show_help() {
    cat << EOF
Usage: ${0##*/} [-v] <document-uuid-or-slug>
       ${0##*/} -h | --help

Walk the wiki parentDocumentId chain and verify the document is nested
inside an allowed write scope defined in \$WIKI_SCOPE_FILE.

Options:
    -v, --verbose   Show each step of the parent chain walk
    -h, --help      Show this help message

Environment:
    WIKI_API_KEY     API token for the wiki (required)
    WIKI_API_URL     API base URL, e.g. https://wiki.example.com/api (required)
    WIKI_SCOPE_FILE  Scope policy file (default: ~/.config/wiki-scope/wiki-scope.json)

Exit Codes:
    0  In scope — safe to write
    1  OUT OF SCOPE — do not write; abort
    2  Environment error (missing env, scope file, or dependencies)
    3  API error (network, auth, or document not found)
EOF
}

require_cmd() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "Error: Required command '$1' not found. Install it and retry." >&2
        exit 2
    fi
}

fetch_doc_parents() {
    local doc_id="$1"
    local payload
    payload=$(jq -n --arg id "$doc_id" '{id: $id}')

    local tmpfile http_code response
    tmpfile=$(mktemp)
    http_code=$(curl -s --connect-timeout 10 --max-time 30 \
        -w '%{http_code}' -o "$tmpfile" \
        -X POST "${WIKI_API_URL}/documents.info" \
        -H "Authorization: Bearer ${WIKI_API_KEY}" \
        -H "Content-Type: application/json" \
        -d "$payload") || { rm -f "$tmpfile"; echo "ERROR:curl_failed"; return; }

    response=$(cat "$tmpfile"); rm -f "$tmpfile"

    if [[ "$http_code" -ge 400 ]]; then
        local msg
        msg=$(echo "$response" | jq -r '.message // .error // "HTTP '"$http_code"'"' 2>/dev/null)
        echo "ERROR:api:${http_code}:${msg}"
        return
    fi

    if ! echo "$response" | jq -e '.data.id // empty' >/dev/null 2>&1; then
        echo "ERROR:bad_shape"
        return
    fi

    echo "$response" | jq -r '[
        .data.id,
        (.data.collectionId // ""),
        (.data.parentDocumentId // "null")
    ] | join("|")'
}

main() {
    local document_id=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help) show_help; exit 0 ;;
            -v|--verbose) VERBOSE=1; shift ;;
            -*) echo "Error: Unknown option '$1'" >&2; exit 1 ;;
            *) document_id="$1"; shift ;;
        esac
    done

    if [[ -z "$document_id" ]]; then
        echo "Error: Missing document ID argument" >&2
        echo "Usage: ${0##*/} [-v] <document-uuid-or-slug>" >&2
        exit 1
    fi

    [[ -z "${WIKI_API_KEY:-}" ]] && { echo "Error: WIKI_API_KEY not set" >&2; exit 2; }
    [[ -z "${WIKI_API_URL:-}" ]] && { echo "Error: WIKI_API_URL not set" >&2; exit 2; }
    require_cmd curl
    require_cmd jq

    if [[ ! -f "$SCOPE_FILE" ]]; then
        echo "Error: Scope file not found: $SCOPE_FILE" >&2; exit 2
    fi

    local allowed_roots; allowed_roots=$(jq -r '.allowedScopes[].allowedRootDocumentId' "$SCOPE_FILE")
    local allowed_collections; allowed_collections=$(jq -r '.allowedScopes[].collectionId' "$SCOPE_FILE")

    local current_id="$document_id"
    local depth=0
    local chain="$document_id"
    local collection_id=""

    while [[ $depth -lt $MAX_DEPTH ]]; do
        local result
        result=$(fetch_doc_parents "$current_id")

        if [[ "$result" == ERROR:* ]]; then
            echo "Error: API failure resolving '$current_id': ${result#ERROR:}" >&2
            exit 3
        fi

        local doc_uuid parent_id
        doc_uuid=$(echo "$result" | cut -d'|' -f1)
        collection_id=$(echo "$result" | cut -d'|' -f2)
        parent_id=$(echo "$result" | cut -d'|' -f3)

        if [[ -z "$doc_uuid" ]]; then
            echo "Error: API returned empty document ID for '$current_id' (malformed response)" >&2
            exit 3
        fi

        [[ $VERBOSE -eq 1 ]] && echo "  [depth ${depth}] uuid=${doc_uuid} parent=${parent_id} collection=${collection_id}" >&2

        if echo "$allowed_roots" | grep -qxF "$doc_uuid"; then
            local label
            label=$(jq -r --arg id "$doc_uuid" \
                '.allowedScopes[] | select(.allowedRootDocumentId == $id) | .name' "$SCOPE_FILE")
            echo "✓ In scope: \"${label}\" (depth ${depth})"
            echo "  Chain: ${chain}"
            exit 0
        fi

        if [[ "$parent_id" == "null" ]]; then
            break
        fi

        chain="${chain} → ${parent_id}"
        current_id="$parent_id"
        (( depth++ )) || true
    done

    local in_allowed_collection=no
    if echo "$allowed_collections" | grep -qxF "$collection_id"; then
        in_allowed_collection=yes
    fi

    echo "✗ OUT OF SCOPE — do not write" >&2
    echo "  Collection ${collection_id} allowed? ${in_allowed_collection}" >&2
    echo "  Chain walked: ${chain}" >&2
    echo "  Allowed roots:" >&2
    jq -r '.allowedScopes[] | "    \(.allowedRootDocumentId)  (\(.name))"' "$SCOPE_FILE" >&2
    exit 1
}

main "$@"

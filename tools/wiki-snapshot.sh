#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Script: wiki-snapshot.sh
# PURPOSE: Pre-edit snapshot for Outline wiki documents. Saves a rollback-safe
#          copy to ~/.codex/_edit_snapshots/{uuid}.md with YAML frontmatter.
#          Implements the procedure from outline-wiki-editing/references/edit-snapshot.md.
#
# USAGE:   wiki-snapshot.sh <document-uuid-or-slug>
#          wiki-snapshot.sh --help
#
# REQUIRES: bash 4+, curl, jq
# PLATFORM: macOS, Linux
# VERSION:  1.0.0
# -----------------------------------------------------------------------------
set -euo pipefail

# --- Bash Guard ---
if [ -z "${BASH_VERSION:-}" ]; then
    echo "ERROR: This script requires bash. Run with: bash $0" >&2
    exit 1
fi

# Override via WIKI_SNAPSHOT_DIR for test isolation
SNAPSHOT_DIR="${WIKI_SNAPSHOT_DIR:-${HOME}/.codex/_edit_snapshots}"

# Module-level temp file tracking (must be visible to EXIT trap)
_tmpresponse=""
_tmpfile=""

_cleanup() {
    [[ -n "$_tmpresponse" ]] && rm -f "$_tmpresponse" || true
    [[ -n "$_tmpfile" ]] && rm -f "$_tmpfile" || true
}
trap _cleanup EXIT

show_help() {
    cat << EOF
Usage: ${0##*/} <document-uuid-or-slug>
       ${0##*/} -h | --help

Snapshot an Outline wiki document before editing. Creates a rollback-safe
copy at ~/.codex/_edit_snapshots/{uuid}.md with YAML frontmatter.

Options:
    -h, --help    Show this help message

Environment (sourced from ~/.codex/.env):
    OUTLINE_API_KEY    API key for Outline (required)
    OUTLINE_API_URL    API base URL (required)
    WIKI_SNAPSHOT_DIR  Override snapshot directory (default: ~/.codex/_edit_snapshots)

Exit Codes:
    0  Snapshot created and verified
    1  Usage error (missing/extra arguments)
    2  Environment not configured (missing .env, keys, or dependencies)
    3  API call failed (network, auth, or document not found)
    4  Snapshot verification failed (body length mismatch)
EOF
}

# --- Dependency check ---
require_cmd() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "Error: Required command '$1' not found. Install it and retry." >&2
        exit 2
    fi
}

main() {
    # --- Arg validation ---
    if [[ $# -eq 0 ]]; then
        echo "Error: Missing document ID argument" >&2
        echo "Usage: ${0##*/} <document-uuid-or-slug>" >&2
        exit 1
    fi

    if [[ "$1" == "--help" || "$1" == "-h" ]]; then
        show_help
        exit 0
    fi

    if [[ $# -gt 1 ]]; then
        echo "Error: Expected exactly 1 argument, got $#" >&2
        echo "Usage: ${0##*/} <document-uuid-or-slug>" >&2
        exit 1
    fi

    local document_id="$1"

    # --- Dependencies ---
    require_cmd curl
    require_cmd jq

    # --- Environment ---
    if [[ ! -f "${HOME}/.codex/.env" ]]; then
        echo "Error: ~/.codex/.env not found" >&2
        exit 2
    fi
    # shellcheck source=/dev/null
    source "${HOME}/.codex/.env"

    if [[ -z "${OUTLINE_API_KEY:-}" ]]; then
        echo "Error: OUTLINE_API_KEY not set in ~/.codex/.env" >&2
        exit 2
    fi
    if [[ -z "${OUTLINE_API_URL:-}" ]]; then
        echo "Error: OUTLINE_API_URL not set in ~/.codex/.env" >&2
        exit 2
    fi

    mkdir -p "$SNAPSHOT_DIR"

    # --- API call (safe JSON payload via jq) ---
    local payload
    payload=$(jq -n --arg id "$document_id" '{id: $id}')

    local response http_code
    _tmpresponse=$(mktemp)

    http_code=$(curl -s -w '%{http_code}' -o "$_tmpresponse" \
        -X POST "${OUTLINE_API_URL}/documents.info" \
        -H "Authorization: Bearer ${OUTLINE_API_KEY}" \
        -H "Content-Type: application/json" \
        -d "$payload") || {
        echo "Error: curl failed (network error or timeout)" >&2
        exit 3
    }

    response=$(cat "$_tmpresponse")

    if [[ "$http_code" -ge 400 ]]; then
        local api_msg
        api_msg=$(echo "$response" | jq -r '.message // .error // "Unknown"' 2>/dev/null || echo "Non-JSON response")
        echo "Error: API returned HTTP ${http_code}: ${api_msg}" >&2
        exit 3
    fi

    # Validate response is JSON with expected shape
    if ! echo "$response" | jq -e '.data.id' >/dev/null 2>&1; then
        echo "Error: API response missing .data.id (unexpected shape)" >&2
        exit 3
    fi

    # --- Extract metadata fields (declare and assign separately per SC2155) ---
    local doc_id doc_title doc_url revision text_length
    local collection_id parent_id snapshot_at
    doc_id=$(echo "$response" | jq -r '.data.id')
    doc_title=$(echo "$response" | jq -r '.data.title // ""')
    doc_url=$(echo "$response" | jq -r '.data.url // ""')
    revision=$(echo "$response" | jq -r '.data.revision // 0')
    text_length=$(echo "$response" | jq -r '.data.text | length')
    collection_id=$(echo "$response" | jq -r '.data.collectionId // ""')
    parent_id=$(echo "$response" | jq -r '.data.parentDocumentId // "null"')
    snapshot_at=$(date -u +'%Y-%m-%dT%H:%M:%SZ')

    # --- Build snapshot in temp file (atomic write) ---
    local snapshot_file="${SNAPSHOT_DIR}/${doc_id}.md"
    _tmpfile=$(mktemp "${SNAPSHOT_DIR}/.wiki-snapshot-XXXXXX")

    # Escape title/url for safe YAML embedding via jq (printf to avoid trailing newline)
    local safe_title safe_url
    safe_title=$(printf '%s' "$doc_title" | jq -Rs '.')
    safe_url=$(printf '%s' "$doc_url" | jq -Rs '.')

    # Write frontmatter
    {
        echo "---"
        echo "document_id: ${doc_id}"
        echo "title: ${safe_title}"
        echo "url: ${safe_url}"
        echo "revision: ${revision}"
        echo "snapshot_at: \"${snapshot_at}\""
        echo "text_length: ${text_length}"
        echo "collection_id: ${collection_id}"
        echo "parent_document_id: ${parent_id}"
        echo "---"
        echo ""
    } > "$_tmpfile"

    # Write body directly from jq to file, bypassing shell variable assignment.
    # Shell command substitution ($(...)) strips trailing newlines, which would
    # corrupt the body. Writing directly from jq preserves exact content.
    echo "$response" | jq -j '.data.text // ""' >> "$_tmpfile"

    # --- Verify written body length matches API (spec requirement) ---
    # Extract body from the written file. Body starts 2 lines after the second
    # "---" (skip the closing "---" and the blank separator line).
    # Count via jq for locale-independent Unicode code point counting.
    local frontmatter_end body_char_count
    frontmatter_end=$(grep -n '^---$' "$_tmpfile" | sed -n '2p' | cut -d: -f1)
    body_char_count=$(tail -n +"$((frontmatter_end + 2))" "$_tmpfile" | jq -Rsn '[inputs] | add | length')

    if [[ "$body_char_count" -ne "$text_length" ]]; then
        echo "Error: Snapshot body integrity check failed (on-disk ${body_char_count} chars, API reported ${text_length})" >&2
        exit 4
    fi

    # --- Atomic move into place ---
    mv -f "$_tmpfile" "$snapshot_file"
    _tmpfile=""  # Disarm cleanup — file has been renamed successfully

    local file_size
    file_size=$(wc -c < "$snapshot_file" | tr -d ' ')

    echo "✓ Snapshot created and verified"
    echo "  Document: ${doc_title}"
    echo "  Revision: ${revision}"
    echo "  Text length: ${text_length} chars"
    echo "  Body verified: ${body_char_count} chars"
    echo "  File: ${snapshot_file} (${file_size} bytes)"
}

main "$@"

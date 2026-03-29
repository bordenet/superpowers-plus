#!/usr/bin/env bash
# Integration tests for wiki-snapshot.sh
# Requires: OUTLINE_API_KEY and OUTLINE_API_URL set in ~/.codex/.env
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOL="${SCRIPT_DIR}/../wiki-snapshot.sh"
PASS=0
FAIL=0

# Test isolation: use a temp directory instead of the real ~/.codex/_edit_snapshots
export WIKI_SNAPSHOT_DIR
WIKI_SNAPSHOT_DIR="$(mktemp -d "${TMPDIR:-/tmp}/wiki-snapshot-test-XXXXXX")"

cleanup() {
    rm -rf "$WIKI_SNAPSHOT_DIR"
}
trap cleanup EXIT

run_test() {
    local name="$1"
    shift
    local expected_exit="$1"
    shift
    local output
    local actual_exit=0
    output=$("$@" 2>&1) || actual_exit=$?

    if [[ "$actual_exit" -eq "$expected_exit" ]]; then
        echo "  ✓ ${name}"
        PASS=$((PASS + 1))
    else
        echo "  ✗ ${name} (expected exit ${expected_exit}, got ${actual_exit})"
        echo "    output: ${output}"
        FAIL=$((FAIL + 1))
    fi
}

run_test_output() {
    local name="$1"
    local pattern="$2"
    shift 2
    local output
    local actual_exit=0
    output=$("$@" 2>&1) || actual_exit=$?

    if echo "$output" | grep -q "$pattern"; then
        echo "  ✓ ${name}"
        PASS=$((PASS + 1))
    else
        echo "  ✗ ${name} (pattern '${pattern}' not found in output)"
        echo "    output: ${output}"
        FAIL=$((FAIL + 1))
    fi
}

echo "=== wiki-snapshot.sh tests ==="
echo ""

# --- Usage / arg validation ---
echo "--- Arg validation ---"
run_test "no args → exit 1" 1 bash "$TOOL"
run_test "extra args → exit 1" 1 bash "$TOOL" abc def
run_test "--help → exit 0" 0 bash "$TOOL" --help
run_test "-h → exit 0" 0 bash "$TOOL" -h
run_test_output "no args message" "Missing document ID" bash "$TOOL"
run_test_output "extra args message" "Expected exactly 1" bash "$TOOL" a b
run_test_output "help shows usage" "Usage:" bash "$TOOL" --help
run_test_output "help shows exit codes" "Exit Codes:" bash "$TOOL" --help

# --- API error handling ---
echo ""
echo "--- API error handling ---"
run_test "bad UUID → exit 3" 3 bash "$TOOL" "nonexistent-doc-12345"
run_test_output "bad UUID message" "HTTP 4" bash "$TOOL" "nonexistent-doc-12345"

# --- Live snapshot (requires API access) ---
echo ""
echo "--- Live snapshot ---"
# Use a known wiki document ID for live testing (set WIKI_TEST_DOC_ID env var)
TEST_DOC="${WIKI_TEST_DOC_ID:-54a6a911-91f9-4ef6-955d-9b547976536d}"
run_test "valid doc → exit 0" 0 bash "$TOOL" "$TEST_DOC"
run_test_output "success message" "Snapshot created and verified" bash "$TOOL" "$TEST_DOC"
run_test_output "shows document title" "Document:" bash "$TOOL" "$TEST_DOC"
run_test_output "shows revision" "Revision:" bash "$TOOL" "$TEST_DOC"
run_test_output "shows body verified" "Body verified:" bash "$TOOL" "$TEST_DOC"

# --- Temp file cleanup ---
echo ""
echo "--- Temp file cleanup ---"
# After a successful run, no .wiki-snapshot-* files should remain
orphan_count=$(find "${WIKI_SNAPSHOT_DIR}" -name '.wiki-snapshot-*' 2>/dev/null | wc -l | tr -d ' ')
if [[ "$orphan_count" -eq 0 ]]; then
    echo "  ✓ no orphaned temp files after success"
    PASS=$((PASS + 1))
else
    echo "  ✗ found ${orphan_count} orphaned .wiki-snapshot-* files"
    FAIL=$((FAIL + 1))
fi

# --- Snapshot file structure ---
echo ""
echo "--- Snapshot file structure ---"
SNAPSHOT_FILE="${WIKI_SNAPSHOT_DIR}/${TEST_DOC}.md"
if [[ -f "$SNAPSHOT_FILE" ]]; then
    # Check YAML frontmatter
    if head -1 "$SNAPSHOT_FILE" | grep -q '^---$'; then
        echo "  ✓ frontmatter starts with ---"
        PASS=$((PASS + 1))
    else
        echo "  ✗ frontmatter missing opening ---"
        FAIL=$((FAIL + 1))
    fi

    if grep -q '^document_id:' "$SNAPSHOT_FILE"; then
        echo "  ✓ frontmatter has document_id"
        PASS=$((PASS + 1))
    else
        echo "  ✗ frontmatter missing document_id"
        FAIL=$((FAIL + 1))
    fi

    if grep -q '^text_length:' "$SNAPSHOT_FILE"; then
        echo "  ✓ frontmatter has text_length"
        PASS=$((PASS + 1))
    else
        echo "  ✗ frontmatter missing text_length"
        FAIL=$((FAIL + 1))
    fi

    if grep -q '^snapshot_at:' "$SNAPSHOT_FILE"; then
        echo "  ✓ frontmatter has snapshot_at"
        PASS=$((PASS + 1))
    else
        echo "  ✗ frontmatter missing snapshot_at"
        FAIL=$((FAIL + 1))
    fi
else
    echo "  ✗ snapshot file not created at ${SNAPSHOT_FILE}"
    FAIL=$((FAIL + 1))
fi

# --- Summary ---
echo ""
echo "=== Results: ${PASS} passed, ${FAIL} failed ==="
[[ "$FAIL" -eq 0 ]] && exit 0 || exit 1

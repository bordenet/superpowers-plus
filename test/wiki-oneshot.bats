#!/usr/bin/env bats
# wiki-oneshot.bats — offline tests for tools/wiki-write.sh and tools/wiki-read.sh.
# Starts an in-memory mock wiki API and exports WIKI_* env vars pointing at it.

MOCK_PORT=19991
MOCK_PID=""

setup_file() {
  export WRITE_SH="${BATS_TEST_DIRNAME}/../tools/wiki-write.sh"
  export READ_SH="${BATS_TEST_DIRNAME}/../tools/wiki-read.sh"

  # Scope file: only col-allowed / root-doc-1 is writable
  export SCOPE_FILE="${BATS_SUITE_TMPDIR}/wiki-scope.json"
  cat > "${SCOPE_FILE}" <<EOF
{
  "allowedScopes": [
    { "name": "Allowed", "collectionId": "col-allowed", "allowedRootDocumentId": "root-doc-1" }
  ]
}
EOF

  export WIKI_API_KEY="test-key"
  export WIKI_API_URL="http://127.0.0.1:${MOCK_PORT}/api"
  export WIKI_SCOPE_FILE="${SCOPE_FILE}"

  node "${BATS_TEST_DIRNAME}/fixtures/mock-wiki-api.js" "${MOCK_PORT}" &
  MOCK_PID=$!
  export MOCK_PID

  local tries=0
  until curl -s -X POST "http://127.0.0.1:${MOCK_PORT}/api/documents.info" -d '{"id":"root-doc-1"}' \
        -H 'Content-Type: application/json' 2>/dev/null | grep -q root-doc-1 \
        || [[ $tries -ge 30 ]]; do
    sleep 0.1; (( tries++ )) || true
  done
}

teardown_file() {
  [[ -n "${MOCK_PID}" ]] && kill "${MOCK_PID}" 2>/dev/null || true
}

_run_write() { run bash "${WRITE_SH}" "$@"; }
_run_read()  { run bash "${READ_SH}"  "$@"; }

# ───────────────────────────── wiki-write.sh ──────────────────────────────

@test "wiki-write: --help exits 0" {
  _run_write --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
}

@test "wiki-write: unknown action exits 2" {
  _run_write destroy
  [ "$status" -eq 2 ]
}

@test "wiki-write: create requires --parent --title --content" {
  _run_write create --title foo
  [ "$status" -eq 2 ]
}

@test "wiki-write: create rejects out-of-scope parent with exit 1" {
  echo "hello" > "${BATS_SUITE_TMPDIR}/body.md"
  _run_write create --parent out-of-scope-doc --title "x" --content "${BATS_SUITE_TMPDIR}/body.md"
  [ "$status" -eq 1 ]
}

@test "wiki-write: create under in-scope parent succeeds and emits JSON" {
  echo "new body" > "${BATS_SUITE_TMPDIR}/body.md"
  _run_write create --parent root-doc-1 --title "New Doc" --content "${BATS_SUITE_TMPDIR}/body.md"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"ok":true'* ]]
  [[ "$output" == *'"url":"https://wiki.example.test/doc/new-doc-'* ]]
}

@test "wiki-write: update rejects out-of-scope doc" {
  echo "body" > "${BATS_SUITE_TMPDIR}/body.md"
  _run_write update --doc out-of-scope-doc --content "${BATS_SUITE_TMPDIR}/body.md"
  [ "$status" -eq 1 ]
}

@test "wiki-write: update in-scope doc succeeds and verifies" {
  echo "updated body" > "${BATS_SUITE_TMPDIR}/body.md"
  _run_write update --doc child-doc-1 --content "${BATS_SUITE_TMPDIR}/body.md"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"id":"child-doc-1"'* ]]
}

@test "wiki-write: move requires both doc and parent in scope" {
  _run_write move --doc child-doc-1 --parent out-of-scope-doc
  [ "$status" -eq 1 ]
}

@test "wiki-write: move succeeds when both are in scope" {
  _run_write move --doc child-doc-1 --parent root-doc-1
  [ "$status" -eq 0 ]
  [[ "$output" == *'"ok":true'* ]]
}

# ───────────────────────────── wiki-read.sh ───────────────────────────────

@test "wiki-read: --help exits 0" {
  _run_read --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
}

@test "wiki-read: get returns canonical url field verbatim" {
  _run_read get root-doc-1
  [ "$status" -eq 0 ]
  [[ "$output" == *'"url":"https://wiki.example.test/doc/root-doc-1"'* ]]
  [[ "$output" == *'"id":"root-doc-1"'* ]]
}

@test "wiki-read: url sub-action prints only the URL" {
  _run_read url root-doc-1
  [ "$status" -eq 0 ]
  [ "$output" = "https://wiki.example.test/doc/root-doc-1" ]
}

@test "wiki-read: get on missing doc exits 4" {
  _run_read get does-not-exist
  [ "$status" -eq 4 ]
}

@test "wiki-read: url accepts full URL and extracts last path segment" {
  _run_read url "https://wiki.example.test/doc/root-doc-1"
  [ "$status" -eq 0 ]
  [ "$output" = "https://wiki.example.test/doc/root-doc-1" ]
}

@test "wiki-read: search returns a JSON array" {
  _run_read search "Root"
  [ "$status" -eq 0 ]
  [[ "$output" == \[*\] ]]
  [[ "$output" == *'"id":"root-doc-1"'* ]]
}

@test "wiki-read: list --collection returns array of docs" {
  _run_read list --collection col-allowed
  [ "$status" -eq 0 ]
  [[ "$output" == *'"id":"root-doc-1"'* ]]
  [[ "$output" == *'"id":"child-doc-1"'* ]]
  [[ "$output" != *'"id":"out-of-scope-doc"'* ]]
}

@test "wiki-read: list without --collection or --parent exits 2" {
  _run_read list
  [ "$status" -eq 2 ]
}

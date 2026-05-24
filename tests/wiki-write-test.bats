#!/usr/bin/env bats
# wiki-write-test.bats — regression tests for tools/wiki-write.sh
#
# Initially seeded with the sp-bughunt #3 regression: the script invoked an
# undefined `log_warn` in its no-node skip branch, which under `set -euo
# pipefail` crashed with `log_warn: command not found` instead of degrading
# gracefully. The fix defines `log_warn` alongside `log_err` and `log_info`.
#
# RUN: bats tests/wiki-write-test.bats

setup_file() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd -P)"
  export REPO_ROOT
}

@test "wiki-write: log_warn is defined (sp-bughunt #3 regression)" {
  # The fix adds `log_warn()` alongside log_err and log_info. The structural
  # gate's no-node skip branch calls it; without the definition, set -euo
  # pipefail kills the script with 'command not found'.
  local script="$REPO_ROOT/tools/wiki-write.sh"
  grep -q '^log_warn()' "$script"
}

@test "wiki-write: no-node skip path runs without crash (sp-bughunt #3)" {
  # Invoke wiki-write.sh with a non-existent validator script and a PATH that
  # excludes node. The structural-gate else-branch must emit the warning and
  # proceed to the API call (which will fail later on real-API absence, but
  # that's a different exit path — what we test here is that log_warn does NOT
  # crash the script with 127).
  local script="$REPO_ROOT/tools/wiki-write.sh"
  local tmp
  tmp="$(mktemp -d)"
  local content="$tmp/content.md"
  printf '# Title\n\nbody\n' > "$content"

  # Move the bundled validator out of the way so the else-branch fires.
  # We don't modify the real file — we run with SCRIPT_DIR pointing at an
  # empty dir via the wiki-write internal resolution. But wiki-write resolves
  # SCRIPT_DIR from its own location, so the simplest path is to clear node
  # from PATH and confirm the script reaches log_warn without crashing.
  #
  # The script is set -euo pipefail; if log_warn is undefined, exit code is
  # 127. With the fix, the script proceeds to the curl/API call which fails
  # at a different point with a different (non-127) exit code.
  WIKI_API_KEY=dummy WIKI_API_URL="http://127.0.0.1:1" PATH="/usr/bin:/bin" \
    run bash "$script" create \
      --parent "00000000-0000-0000-0000-000000000000" \
      --title "test" \
      --content "$content"

  # log_warn-not-defined would yield status 127 ("command not found").
  # Any other non-zero status (3 = API error, etc.) indicates the script
  # got past the log_warn call.
  rm -rf "$tmp"
  [ "$status" -ne 127 ]
  # Negative assertion on the exact failure signature:
  [[ "$output" != *"log_warn: command not found"* ]]
}

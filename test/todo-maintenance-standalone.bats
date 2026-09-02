#!/usr/bin/env bats
# test/todo-maintenance-standalone.bats
#
# Regression: todo-maintenance.py must resolve todo-archive.sh when tools/ is
# installed standalone (~/.codex/superpowers-plus/tools/) with no sibling
# skills/ tree. The doctor's Check 22 smoke test invokes it exactly this way,
# and todo-archive.sh itself only functions from inside a full checkout (it
# reaches ../../../tools/todo-engine.py), so the fix resolves via SPP_SOURCE_DIR.

REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"

setup() {
  TMP="$(mktemp -d "${TMPDIR:-/tmp}/todo-maint-standalone-XXXXXX")"

  # Standalone tools/ — the maintenance scripts only, NO sibling skills/.
  # COPY, not symlink: todo-maintenance.py does Path(__file__).resolve(), which
  # would follow a symlink back to the real tools/ (and its real skills/ sibling)
  # and defeat the standalone simulation. (todo-engine.py is intentionally NOT
  # copied — the resolved todo-archive.sh reaches the checkout's own copy.)
  mkdir -p "$TMP/opt/tools"
  for f in todo-maintenance.py todo-maintenance.sh todo-preflight.sh resolve-env-path.sh; do
    cp "$REPO_ROOT/tools/$f" "$TMP/opt/tools/$f"
  done
  chmod +x "$TMP/opt/tools/"*.sh

  mkdir -p "$TMP/home/.codex"
  TODO="$TMP/home/.codex/TODO.md"
  {
    printf 'TODO_FILE_PATH=%s\n' "$TODO"
    # single-quote-escaped, matching lib/install/deploy.sh register_source_repo
    printf "SPP_SOURCE_DIR='%s'\n" "${REPO_ROOT//\'/\'\\\'\'}"
  } > "$TMP/home/.codex/.env"

  # Small but valid TODO with archivable history (>=5 done items, >7d old).
  cat > "$TODO" <<'EOF'
# ACTIVE TASKS

## P1 - Today

- [ ] [20260322-01] Standalone smoke active task #doctor

## P2 - This Week

## P3 - Backlog

---

# HISTORY

## 2026-03-01
- [x] [20260301-01] Done one #doctor
  - Added: 2026-03-01
  - Done: 2026-03-01T10:00:00

- [x] [20260301-02] Done two #doctor
  - Added: 2026-03-01
  - Done: 2026-03-01T11:00:00

- [x] [20260301-03] Done three #doctor
  - Added: 2026-03-01
  - Done: 2026-03-01T12:00:00

- [x] [20260301-04] Done four #doctor
  - Added: 2026-03-01
  - Done: 2026-03-01T13:00:00

- [x] [20260301-05] Done five #doctor
  - Added: 2026-03-01
  - Done: 2026-03-01T14:00:00

---

# DEFERRED

---

# METRICS
EOF
}

teardown() {
  command -v chflags >/dev/null 2>&1 && chflags -R nouchg "$TMP" 2>/dev/null || true
  chmod -R u+w "$TMP" 2>/dev/null || true
  rm -rf "$TMP"
}

@test "todo-maintenance.py resolves todo-archive.sh from a standalone tools/ layout" {
  # env -u: force resolution through the fixture .env, not an ambient
  # SPP_SOURCE_DIR a contributor's shell may have exported.
  run env -u SPP_SOURCE_DIR -u SP_PLUS_DIR HOME="$TMP/home" \
    bash "$TMP/opt/tools/todo-maintenance.sh" --json
  [ "$status" -eq 0 ]
  [[ "$output" != *"todo-archive.sh not found"* ]]
  [[ "$output" == *'"archive_performed": true'* ]]
  grep -q '20260322-01' "$TODO"
}

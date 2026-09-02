#!/usr/bin/env bats
# test/doctor-standalone-layout.bats
#
# Regression: the `sp-doctor` CLI runs tools/doctor-checks.sh from a standalone
# tool install (~/.codex/superpowers-plus/tools/) that has NO sibling
# lib/install/ and NO sibling skills/ tree. Three resolution sites must fall
# back to the source checkout (SP_PLUS_DIR / SPP_SOURCE_DIR, read from
# ~/.codex/.env) instead of silently degrading:
#
#   - reference-checks.sh + metadata-checks.sh -> lib/install/skill-naming.sh
#     (else alias installs, e.g. source `brainstorming` -> installed
#      `sp-brainstorm`, are mis-reported as "missing installed reference" /
#      "orphaned install" -- was 16 false ERRORs + ~46 false WARNINGs)
#   - todo-maintenance.py -> skills/productivity/todo-archive/todo-archive.sh
#     (else the doctor's Check 22 TODO-archive smoke test fails -- 1 false ERROR)

REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
export REPO_ROOT

# The standalone doctor is a ~7s full scan; run it ONCE for the file and have
# every @test assert against the cached output.
setup_file() {
  export STANDALONE_TMP
  STANDALONE_TMP="$(mktemp -d "${TMPDIR:-/tmp}/doctor-standalone-XXXXXX")"

  # COPY (never symlink) every tool the doctor loads into a lib/- and
  # skills/-less tools/ dir. todo-maintenance.py does Path(__file__).resolve(),
  # which follows a symlink back to the real tree and defeats the simulation.
  mkdir -p "$STANDALONE_TMP/opt/tools/doctor-modules"
  cp "$REPO_ROOT/tools/compat.sh"        "$STANDALONE_TMP/opt/tools/"
  cp "$REPO_ROOT/tools/doctor-checks.sh" "$STANDALONE_TMP/opt/tools/"
  cp "$REPO_ROOT"/tools/doctor-modules/*.sh "$STANDALONE_TMP/opt/tools/doctor-modules/"
  # Check 22's smoke test only runs when its maintenance trio is present next to
  # the doctor (the `[[ -f "$MAINT_SCRIPT" ]]` guard in todo-checks.sh).
  for f in todo-maintenance.py todo-maintenance.sh todo-preflight.sh resolve-env-path.sh; do
    cp "$REPO_ROOT/tools/$f" "$STANDALONE_TMP/opt/tools/"
  done
  chmod +x "$STANDALONE_TMP/opt/tools/"*.sh

  # Fake install root ($HOME/.codex/skills): ONE alias-named skill carrying
  # reference files -- mirrors the real brainstorming -> sp-brainstorm.
  mkdir -p "$STANDALONE_TMP/home/.codex/skills/sp-brainstorm/references"
  cp "$REPO_ROOT/skills/engineering/brainstorming/skill.md" \
     "$STANDALONE_TMP/home/.codex/skills/sp-brainstorm/skill.md"
  cp "$REPO_ROOT"/skills/engineering/brainstorming/references/*.md \
     "$STANDALONE_TMP/home/.codex/skills/sp-brainstorm/references/"

  # .env points the standalone doctor at the real checkout (single-quote
  # escaped, matching lib/install/deploy.sh register_source_repo).
  local spp="${REPO_ROOT//\'/\'\\\'\'}"
  printf "SPP_SOURCE_DIR='%s'\n" "$spp" > "$STANDALONE_TMP/home/.codex/.env"

  # env -u: SPP_SOURCE_DIR / SP_PLUS_DIR must be resolved from the fixture .env,
  # not from a value a contributor's shell happens to export.
  env -u SPP_SOURCE_DIR -u SP_PLUS_DIR HOME="$STANDALONE_TMP/home" \
    bash "$STANDALONE_TMP/opt/tools/doctor-checks.sh" \
    > "$STANDALONE_TMP/doctor.out" 2>&1 || true
}

teardown_file() {
  # Match the sibling test / _smoke_cleanup: clear any immutable/read-only bits
  # a future --fix run could set before rm (harmless today, cheap insurance).
  command -v chflags >/dev/null 2>&1 && chflags -R nouchg "$STANDALONE_TMP" 2>/dev/null || true
  chmod -R u+w "$STANDALONE_TMP" 2>/dev/null || true
  rm -rf "$STANDALONE_TMP"
}

_out() { cat "$STANDALONE_TMP/doctor.out"; }

@test "standalone doctor runs to completion (liveness anchor for the checks below)" {
  run _out
  # The final summary only prints if the scan reached the end; without this a
  # mid-scan abort would vacuously satisfy the negative assertions below.
  [[ "$output" == *"Your superpowers need"* ]]
}

@test "standalone doctor scanned the alias skill (negative assertions are live)" {
  run _out
  # Some OTHER skill must be flagged missing/orphaned -- proves Check 8 and
  # Check 16 actually executed against $HOME/.codex/skills.
  [[ "$output" == *"orphaned install"* || "$output" == *"missing installed reference"* ]]
}

@test "standalone doctor maps brainstorming->sp-brainstorm (no false missing-reference)" {
  run _out
  [[ "$output" != *"brainstorming — missing installed reference"* ]]
}

@test "standalone doctor does not mis-flag the alias install as orphaned" {
  run _out
  [[ "$output" != *"sp-brainstorm — orphaned install"* ]]
}

@test "standalone doctor Check 22 resolves todo-archive.sh (no smoke-test failure)" {
  run _out
  [[ "$output" != *"TODO archive smoke test"* ]]
}

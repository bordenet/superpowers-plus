#!/usr/bin/env bats
# hotfix-charter-check.bats -- regression tests for the hotfix-charter pre-commit hook

HOOK="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)/tools/hotfix-charter-check.sh"

setup() {
  SANDBOX="$(mktemp -d -t hotfix-charter.XXXXXX)"
  cd "$SANDBOX"
  git init -q -b main
  git config user.email "t@x"
  git config user.name  "t"
  git commit --allow-empty -q -m "init"
}

teardown() {
  cd /
  rm -rf "$SANDBOX"
}

write_charter() {
  local symptom="${1-Greeting clips at 700ms on Azure-via-failover path.}"
  local budget="${2-200}"
  local verdict="${3-PASS at 9.5/10}"
  # 4th arg: disposition body. Defaults to NONE -- the only token that passes
  # with nothing staged (ADDED empty, 0 added lines is under the ceiling).
  local disposition="${4-NONE}"
  cat > HOTFIX-CHARTER.md <<EOF
## Symptom (one sentence)

$symptom

## Diff budget (LOC ceiling)

$budget

## cr-battery pre-commit verdict

$verdict

## Refactoring disposition

$disposition
EOF
}

@test "exit 0 when branch is not hotfix/*" {
  git checkout -q -b feat/something
  run "$HOOK"
  [ "$status" -eq 0 ]
}

@test "exit 0 on main branch (no charter required)" {
  run "$HOOK"
  [ "$status" -eq 0 ]
}

@test "exit 2 when not in a git repo" {
  cd /tmp
  run "$HOOK"
  [ "$status" -eq 2 ]
}

@test "exit 2 on detached HEAD (cannot determine branch)" {
  HEAD_SHA=$(git rev-parse HEAD)
  git checkout -q --detach "$HEAD_SHA"
  run "$HOOK"
  [ "$status" -eq 2 ]
}

@test "exit 1 on hotfix/* branch with no charter" {
  git checkout -q -b hotfix/ticket-9999-something
  run "$HOOK"
  [ "$status" -eq 1 ]
  [[ "$output" == *"HOTFIX-CHARTER.md missing"* ]]
}



@test "exit 1 on hotfix branch missing the Symptom section" {
  git checkout -q -b hotfix/foo
  cat > HOTFIX-CHARTER.md <<'EOF'
## Diff budget (LOC ceiling)
200
## cr-battery pre-commit verdict
PASS
EOF
  run "$HOOK"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Symptom"* ]]
}

@test "exit 0 with PASS verdict" {
  git checkout -q -b hotfix/ok
  write_charter "" "" "PASS at 9.5/10"
  run "$HOOK"
  [ "$status" -eq 0 ]
}

@test "exit 0 with PASS_WITH_NITS verdict" {
  git checkout -q -b hotfix/ok
  write_charter "" "" "PASS_WITH_NITS at 8.7/10 (1 Minor)"
  run "$HOOK"
  [ "$status" -eq 0 ]
}

@test "exit 1 with REJECT verdict" {
  git checkout -q -b hotfix/rej
  write_charter "" "" "REJECT at 6.0/10"
  run "$HOOK"
  [ "$status" -eq 1 ]
  [[ "$output" == *"PASS or PASS_WITH_NITS"* ]]
}

@test "exit 1 with empty verdict section" {
  git checkout -q -b hotfix/empty
  write_charter "" "" ""
  run "$HOOK"
  [ "$status" -eq 1 ]
}

@test "ALLOW_NO_CHARTER=1 bypasses with WARNING" {
  git checkout -q -b hotfix/bypass
  ALLOW_NO_CHARTER=1 run "$HOOK"
  [ "$status" -eq 0 ]
  [[ "$output" == *"WARNING: ALLOW_NO_CHARTER=1"* ]]
}

@test "exit 0 on hotfix/* with full valid charter" {
  git checkout -q -b hotfix/sample-fix
  write_charter
  run "$HOOK"
  [ "$status" -eq 0 ]
  [[ "$output" == *"hotfix-charter:"*"OK"* ]]
}

@test "--help exits 0 to stdout" {
  run "$HOOK" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"hotfix-charter-check.sh"* ]]
}

# --- Refactoring disposition (4th charter section) -----------------------------
#
# write_charter now emits a `## Refactoring disposition` section (default body
# NONE). Content cases below must reach the disposition block, which sits AFTER
# the BAD_VERDICT block, so each supplies a non-empty PASS cr-battery verdict as
# the 3rd arg. Backticked-symbol bodies are passed single-quoted so the shell
# does not command-substitute them before the call.

# Build a full, otherwise-valid charter WITHOUT the disposition section. Used by
# the absence cases (write_charter always emits the section). All three original
# sections present + PASS verdict, so only the disposition heading is missing.
write_charter_no_disposition() {
  cat > HOTFIX-CHARTER.md <<'EOF'
## Symptom (one sentence)

Greeting clips at 700ms on Azure-via-failover path.

## Diff budget (LOC ceiling)

200

## cr-battery pre-commit verdict

PASS at 9.5/10
EOF
}

# Stage N added lines in a fresh file (charter is read from the worktree, not
# the index, so it need not be staged).
stage_added_lines() {
  awk -v n="$1" 'BEGIN { for (i = 1; i <= n; i++) print "added line " i }' > src.txt
  git add src.txt
}

@test "exit 1 on hotfix branch missing the Refactoring disposition section" {
  git checkout -q -b hotfix/no-disposition
  write_charter_no_disposition
  run "$HOOK"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Refactoring disposition"* ]]
}

@test "exit 1 when the disposition section has no token" {
  git checkout -q -b hotfix/disp-notoken
  write_charter "" "" "PASS at 9.5/10" "we thought about it and moved on"
  run "$HOOK"
  [ "$status" -eq 1 ]
  [[ "$output" == *"EXACTLY ONE"* ]]
  [[ "$output" == *"found 0"* ]]
}

@test "exit 1 when the disposition first line names two tokens (ambiguous)" {
  git checkout -q -b hotfix/disp-ambiguous
  write_charter "" "" "PASS at 9.5/10" "PARK or NONE, we were not sure"
  run "$HOOK"
  [ "$status" -eq 1 ]
  [[ "$output" == *"found 2"* ]]
}

@test "exit 1 when the disposition first line names all three tokens" {
  git checkout -q -b hotfix/disp-allthree
  write_charter "" "" "PASS at 9.5/10" "one of REFACTOR_NOW / PARK / NONE, TBD"
  run "$HOOK"
  [ "$status" -eq 1 ]
  [[ "$output" == *"found 3"* ]]
}

@test "exit 0 when a bare token appears in the reason but not on the first line" {
  git checkout -q -b hotfix/disp-reason-uppercase
  local body='PARK deferred extracting `realSym`.
NONE of the other callers touch it.'
  write_charter "" "" "PASS at 9.5/10" "$body"
  printf 'const realSym = computeThing()\n' > src.txt
  git add src.txt
  run "$HOOK"
  [ "$status" -eq 0 ]
}

@test "exit 0 when the citation is a symbol literally named LogLevel.NONE" {
  git checkout -q -b hotfix/disp-cite-none
  write_charter "" "" "PASS at 9.5/10" 'PARK deferred extracting `LogLevel.NONE` handling'
  printf 'x = LogLevel.NONE\n' > src.txt
  git add src.txt
  run "$HOOK"
  [ "$status" -eq 0 ]
}

@test "exit 0 with the colon heading form (## Refactoring disposition: NONE)" {
  git checkout -q -b hotfix/disp-colon
  cat > HOTFIX-CHARTER.md <<'EOF'
## Symptom (one sentence)

x

## Diff budget (LOC ceiling)

200

## cr-battery pre-commit verdict

PASS at 9.5/10

## Refactoring disposition: NONE
EOF
  run "$HOOK"
  [ "$status" -eq 0 ]
}

@test "exit 0 with a parenthesized clarifier in the disposition heading" {
  git checkout -q -b hotfix/disp-parens-heading
  cat > HOTFIX-CHARTER.md <<'EOF'
## Symptom (one sentence)

x

## Diff budget (LOC ceiling)

200

## cr-battery pre-commit verdict

PASS at 9.5/10

## Refactoring disposition (REFACTOR_NOW / PARK / NONE)

NONE
EOF
  run "$HOOK"
  [ "$status" -eq 0 ]
}

@test "exit 2 when DISPOSITION_NONE_MAX_LINES overflows the integer bound" {
  git checkout -q -b hotfix/disp-badmax-huge
  write_charter "" "" "PASS at 9.5/10" "NONE"
  stage_added_lines 40
  DISPOSITION_NONE_MAX_LINES="99999999999999999999999" run "$HOOK"
  [ "$status" -eq 2 ]
  [[ "$output" == *"integer 0-999999999"* ]]
}

@test "exit 1 when PARK has no backticked citation" {
  git checkout -q -b hotfix/disp-nocite
  write_charter "" "" "PASS at 9.5/10" "PARK deferred the cleanup"
  run "$HOOK"
  [ "$status" -eq 1 ]
  [[ "$output" == *"backticks"* ]]
}

@test "exit 1 when the PARK citation is only a punctuation character" {
  git checkout -q -b hotfix/disp-trivial-cite
  write_charter "" "" "PASS at 9.5/10" 'PARK deferred `.`'
  printf 'a.b.c\n' > src.txt
  git add src.txt
  run "$HOOK"
  [ "$status" -eq 1 ]
  [[ "$output" == *"real symbol"* ]]
}

@test "exit 1 when the PARK citation is absent from the staged diff" {
  git checkout -q -b hotfix/disp-ghost
  write_charter "" "" "PASS at 9.5/10" 'PARK deferred extracting `ghostSymbol`'
  printf 'first line\nsecond line\n' > src.txt
  git add src.txt
  run "$HOOK"
  [ "$status" -eq 1 ]
  [[ "$output" == *"no cited symbol"* ]]
}

@test "exit 0 when the PARK citation appears in the staged diff" {
  git checkout -q -b hotfix/disp-realsym
  write_charter "" "" "PASS at 9.5/10" 'PARK deferred extracting `realSym`; minimal-diff hotfix'
  printf 'const realSym = computeThing()\n' > src.txt
  git add src.txt
  run "$HOOK"
  [ "$status" -eq 0 ]
}

@test "exit 0 when the PARK citation appears on an added line beginning with ++" {
  git checkout -q -b hotfix/disp-plusplus
  write_charter "" "" "PASS at 9.5/10" 'PARK deferred extracting `weirdSym`'
  printf 'normal alpha\n++ weirdSym lives here\nnormal beta\n' > src.txt
  git add src.txt
  run "$HOOK"
  [ "$status" -eq 0 ]
}

@test "exit 0 when a deleted '-- ' line is adjacent to an added '++ ' citation line" {
  git checkout -q -b hotfix/disp-dashdash-plusplus
  printf 'keep one\n-- trailer note\nkeep two\n' > notes.txt
  git add notes.txt
  git commit -q -m "base for -- / ++ adjacency"
  printf 'keep one\n++ ghostRefactorTarget here\nkeep two\n' > notes.txt
  git add notes.txt
  write_charter "" "" "PASS at 9.5/10" 'PARK deferred extracting `ghostRefactorTarget`'
  run "$HOOK"
  [ "$status" -eq 0 ]
}

@test "exit 1 when a '-- '/'++ ' adjacency would otherwise hide an absent citation" {
  git checkout -q -b hotfix/disp-dashdash-absent
  printf 'keep one\n-- trailer note\nkeep two\n' > notes.txt
  git add notes.txt
  git commit -q -m "base"
  printf 'keep one\n++ realAddedThing here\nkeep two\n' > notes.txt
  git add notes.txt
  write_charter "" "" "PASS at 9.5/10" 'PARK deferred extracting `neverAppearsSym`'
  run "$HOOK"
  [ "$status" -eq 1 ]
  [[ "$output" == *"no cited symbol"* ]]
}

@test "exit 0 when REFACTOR_NOW cites a symbol present in the staged diff" {
  git checkout -q -b hotfix/disp-refnow
  write_charter "" "" "PASS at 9.5/10" 'REFACTOR_NOW extracted `realSym` -- the refactor is the fix'
  printf 'const realSym = computeThing()\n' > src.txt
  git add src.txt
  run "$HOOK"
  [ "$status" -eq 0 ]
}

@test "exit 1 when REFACTOR_NOW has no backticked citation" {
  git checkout -q -b hotfix/disp-refnow-nocite
  write_charter "" "" "PASS at 9.5/10" "REFACTOR_NOW inlined the retry path"
  printf 'const realSym = computeThing()\n' > src.txt
  git add src.txt
  run "$HOOK"
  [ "$status" -eq 1 ]
  [[ "$output" == *"backticks"* ]]
}

@test "exit 0 when PARK cites a symbol but nothing is staged" {
  git checkout -q -b hotfix/disp-nostage
  write_charter "" "" "PASS at 9.5/10" 'PARK deferred `helperX`; nothing staged yet'
  run "$HOOK"
  [ "$status" -eq 0 ]
}

@test "exit 0 with NONE under the changed-line ceiling" {
  git checkout -q -b hotfix/disp-none-ok
  write_charter "" "" "PASS at 9.5/10" "NONE"
  stage_added_lines 5
  run "$HOOK"
  [ "$status" -eq 0 ]
}

@test "exit 0 with NONE at exactly the changed-line ceiling" {
  git checkout -q -b hotfix/disp-none-boundary
  write_charter "" "" "PASS at 9.5/10" "NONE"
  stage_added_lines 30
  run "$HOOK"
  [ "$status" -eq 0 ]
}

@test "exit 1 with NONE one line over the changed-line ceiling" {
  git checkout -q -b hotfix/disp-none-over1
  write_charter "" "" "PASS at 9.5/10" "NONE"
  stage_added_lines 31
  run "$HOOK"
  [ "$status" -eq 1 ]
  [[ "$output" == *"capped at 30"* ]]
}

@test "exit 1 with NONE and a deletion-heavy staged diff" {
  git checkout -q -b hotfix/disp-none-deletions
  awk 'BEGIN { for (i = 1; i <= 60; i++) print "line " i }' > big.txt
  git add big.txt
  git commit -q -m "base for deletion test"
  printf 'line 1\n' > big.txt
  git add big.txt
  write_charter "" "" "PASS at 9.5/10" "NONE"
  run "$HOOK"
  [ "$status" -eq 1 ]
  [[ "$output" == *"added + deleted"* ]]
}

@test "exit 1 with NONE and a rename-heavy staged diff (renames counted, not zeroed)" {
  git checkout -q -b hotfix/disp-none-rename
  awk 'BEGIN { for (i = 1; i <= 50; i++) print "line " i }' > orig.txt
  git add orig.txt
  git commit -q -m "base for rename test"
  git mv orig.txt renamed.txt
  write_charter "" "" "PASS at 9.5/10" "NONE"
  run "$HOOK"
  [ "$status" -eq 1 ]
  [[ "$output" == *"added + deleted"* ]]
}

@test "exit 0 with a CRLF charter (disposition parses despite carriage returns)" {
  git checkout -q -b hotfix/disp-crlf
  printf '## Symptom (one sentence)\r\n\r\nx\r\n\r\n## Diff budget (LOC ceiling)\r\n\r\n200\r\n\r\n## cr-battery pre-commit verdict\r\n\r\nPASS at 9.5/10\r\n\r\n## Refactoring disposition\r\n\r\nNONE\r\n' > HOTFIX-CHARTER.md
  run "$HOOK"
  [ "$status" -eq 0 ]
}

@test "exit 2 on non-integer DISPOSITION_NONE_MAX_LINES even with a PARK disposition" {
  git checkout -q -b hotfix/disp-badmax-park
  write_charter "" "" "PASS at 9.5/10" 'PARK deferred `realSym`'
  printf 'const realSym = computeThing()\n' > src.txt
  git add src.txt
  DISPOSITION_NONE_MAX_LINES="not-an-int" run "$HOOK"
  [ "$status" -eq 2 ]
  [[ "$output" == *"integer 0-999999999"* ]]
}

@test "exit 0 with NONE over the ceiling when DISPOSITION_NONE_MAX_LINES is raised" {
  git checkout -q -b hotfix/disp-none-override
  write_charter "" "" "PASS at 9.5/10" "NONE"
  stage_added_lines 40
  DISPOSITION_NONE_MAX_LINES=100 run "$HOOK"
  [ "$status" -eq 0 ]
}

@test "exit 2 when DISPOSITION_NONE_MAX_LINES is not an integer" {
  git checkout -q -b hotfix/disp-badmax
  write_charter "" "" "PASS at 9.5/10" "NONE"
  stage_added_lines 5
  DISPOSITION_NONE_MAX_LINES="10x" run "$HOOK"
  [ "$status" -eq 2 ]
  [[ "$output" == *"integer 0-999999999"* ]]
}

@test "REQUIRE_DISPOSITION=0 skips the disposition check but still enforces the other sections" {
  git checkout -q -b hotfix/disp-skip
  write_charter_no_disposition
  REQUIRE_DISPOSITION=0 run "$HOOK"
  [ "$status" -eq 0 ]
  [[ "$output" == *"WARNING"* ]]
}

@test "REQUIRE_DISPOSITION=0 still fails when a core section is missing" {
  git checkout -q -b hotfix/disp-skip-still-strict
  cat > HOTFIX-CHARTER.md <<'EOF'
## Diff budget (LOC ceiling)

200

## cr-battery pre-commit verdict

PASS at 9.5/10

## Refactoring disposition

NONE
EOF
  REQUIRE_DISPOSITION=0 run "$HOOK"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Symptom"* ]]
}

@test "REQUIRE_DISPOSITION=true still enforces (truthy value does not disable)" {
  git checkout -q -b hotfix/disp-truthy
  write_charter_no_disposition
  REQUIRE_DISPOSITION=true run "$HOOK"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Refactoring disposition"* ]]
}

@test "exit 1 when the cited symbol lives only in the charter (self-satisfaction blocked)" {
  git checkout -q -b hotfix/disp-selfsat
  write_charter "" "" "PASS at 9.5/10" 'PARK deferred `charterOnlySym`'
  printf 'an unrelated added line\n' > src.txt
  git add src.txt HOTFIX-CHARTER.md
  run "$HOOK"
  [ "$status" -eq 1 ]
  [[ "$output" == *"no cited symbol"* ]]
}

@test "exit 0 via write_charter default disposition with nothing staged" {
  git checkout -q -b hotfix/disp-harness-default
  write_charter
  run "$HOOK"
  [ "$status" -eq 0 ]
  [[ "$output" == *"hotfix-charter:"*"OK"* ]]
}

@test "fix/* branch is not gated by default" {
  git checkout -q -b fix/PROJ-123-clip
  run "$HOOK"
  [ "$status" -eq 0 ]
}

@test "CHARTER_BRANCH_PREFIXES can extend gating to fix/* branches" {
  git checkout -q -b fix/PROJ-123-clip
  CHARTER_BRANCH_PREFIXES="hotfix/ fix/" run "$HOOK"
  [ "$status" -eq 1 ]
  [[ "$output" == *"missing"* ]]
}

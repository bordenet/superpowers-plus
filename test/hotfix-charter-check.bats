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
  cat > HOTFIX-CHARTER.md <<EOF
## Symptom (one sentence)

$symptom

## Diff budget (LOC ceiling)

$budget

## cr-battery pre-commit verdict

$verdict
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

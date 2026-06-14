#!/usr/bin/env bats
# session-handoff-check-test.bats -- regression tests for the cold-start advisory.

GATE="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)/tools/session-handoff-check.sh"

setup() {
  SANDBOX="$(mktemp -d -t session-handoff.XXXXXX)"
  cd "$SANDBOX"

  # Two repos: REMOTE (simulates origin) and LOCAL (the working tree).
  REMOTE_DIR="$SANDBOX/remote.git"
  LOCAL_DIR="$SANDBOX/local"
  git init -q --bare -b main "$REMOTE_DIR"

  git init -q -b main "$LOCAL_DIR"
  cd "$LOCAL_DIR"
  git config user.email "me@example.com"
  git config user.name  "me"
  git remote add origin "$REMOTE_DIR"
  git commit --allow-empty -q -m "init"
  git push -q -u origin main

  # Tests run inside LOCAL_DIR by default
  export SESSION_HANDOFF_NO_FETCH=1
}

teardown() {
  cd /
  rm -rf "$SANDBOX"
}

# Add a sibling commit by pushing through a fresh clone of the remote so it
# lands on origin/<branch> but never touches the engineer's local tip.
push_sibling_commit() {
  local branch="$1" author_email="$2" msg="$3"
  local SIB; SIB="$SANDBOX/sib-$RANDOM-$$"
  git clone -q "$REMOTE_DIR" "$SIB"
  (
    cd "$SIB"
    git config user.email "$author_email"
    git config user.name  "sibling"
    if git show-ref --verify --quiet "refs/remotes/origin/$branch"; then
      git checkout -q -B "$branch" "origin/$branch"
    elif [[ "$branch" == "main" ]]; then
      :
    else
      git checkout -q -b "$branch"
    fi
    echo "$msg" >> log.txt
    git add log.txt
    git commit -q -m "$msg"
    git push -q origin "$branch"
  )
  (cd "$LOCAL_DIR" && git fetch -q origin)
}

@test "exit 2 outside a git repo" {
  cd "$SANDBOX"
  run "$GATE"
  [ "$status" -eq 2 ]
}

@test "exit 2 on invalid SESSION_HANDOFF_FETCH_TIMEOUT" {
  cd "$LOCAL_DIR"
  SESSION_HANDOFF_FETCH_TIMEOUT=abc run "$GATE"
  [ "$status" -eq 2 ]
}

@test "--help prints usage and exits 0" {
  cd "$LOCAL_DIR"
  run "$GATE" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"session-handoff-check.sh"* ]]
  [[ "$output" == *"Exit codes"* ]]
}

@test "silent when no sibling commits exist" {
  cd "$LOCAL_DIR"
  run "$GATE"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "verbose path prints 'no sibling activity'" {
  cd "$LOCAL_DIR"
  run "$GATE" --verbose
  [ "$status" -eq 0 ]
  [[ "$output" == *"no sibling activity"* ]]
}

@test "SESSION_HANDOFF_VERBOSE=1 env path equivalent to --verbose" {
  cd "$LOCAL_DIR"
  SESSION_HANDOFF_VERBOSE=1 run "$GATE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"no sibling activity"* ]]
}

@test "surfaces a single same-email sibling commit" {
  cd "$LOCAL_DIR"
  push_sibling_commit main "me@example.com" "feat: from other machine"
  run "$GATE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"sibling activity detected"* ]]
  [[ "$output" == *"feat: from other machine"* ]]
  [[ "$output" == *"me@example.com"* ]]
  [[ "$output" == *"origin/main"* ]]
}

@test "surfaces a single different-author sibling commit" {
  cd "$LOCAL_DIR"
  push_sibling_commit main "teammate@example.com" "feat: from teammate"
  run "$GATE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"teammate@example.com"* ]]
  [[ "$output" == *"feat: from teammate"* ]]
}

@test "surfaces commits on multiple branches grouped by ref" {
  cd "$LOCAL_DIR"
  push_sibling_commit main      "me@example.com"       "main: tweak 1"
  push_sibling_commit feat-x    "me@example.com"       "feat-x: kickoff"
  push_sibling_commit feat-x    "teammate@example.com" "feat-x: review nit"
  run "$GATE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"origin/main"* ]]
  [[ "$output" == *"origin/feat-x"* ]]
  [[ "$output" == *"main: tweak 1"* ]]
  [[ "$output" == *"feat-x: kickoff"* ]]
  [[ "$output" == *"feat-x: review nit"* ]]
}

@test "respects narrow SESSION_HANDOFF_WINDOW (filters out anything old)" {
  cd "$LOCAL_DIR"
  push_sibling_commit main "me@example.com" "feat: should-be-filtered"
  SESSION_HANDOFF_WINDOW="2099-12-31" run "$GATE"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "does NOT surface commits already reachable from local main" {
  cd "$LOCAL_DIR"
  push_sibling_commit main "me@example.com" "feat: pulled later"
  git pull -q origin main
  run "$GATE"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "output table contains ISO timestamps truncated to minutes" {
  cd "$LOCAL_DIR"
  push_sibling_commit main "me@example.com" "feat: format-check"
  run "$GATE"
  [ "$status" -eq 0 ]
  [[ "$output" =~ [0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2} ]]
}

@test "subject containing a pipe character displays correctly" {
  cd "$LOCAL_DIR"
  push_sibling_commit main "me@example.com" "fix: handle a|b|c case"
  run "$GATE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"fix: handle a|b|c case"* ]]
  [[ "$output" =~ [0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2} ]]
}

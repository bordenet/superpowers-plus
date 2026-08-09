#!/usr/bin/env bats
# codeowners-drift-audit.bats -- regression tests for the embedded audit script in
# skills/engineering/codeowners-drift-audit/skill.md (extracted at test time; the
# skill intentionally has no standalone tools/*.sh file -- single-invocation design).
#
# BARE_PATH restricts every test to a PATH with no real gh/glab on it, so results
# never depend on the test machine's live network/auth state. Tests exercising
# Step 3 (owner validity) install stub gh/glab binaries via stub_gh/stub_glab
# instead of ever touching a real API.

SKILL_MD="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)/skills/engineering/codeowners-drift-audit/skill.md"
BARE_PATH="/usr/bin:/bin"

setup() {
  SCRIPT="$(mktemp -t codeowners-drift-audit.XXXXXX.sh)"
  awk '/^```bash$/{f=1;next} /^```$/{if(f)exit} f' "$SKILL_MD" > "$SCRIPT"
  SANDBOX="$(mktemp -d -t codeowners-drift-audit.XXXXXX)"
  cd "$SANDBOX"
  git init -q
  git config user.email "t@x"
  git config user.name  "t"
}

teardown() {
  cd /
  rm -rf "$SANDBOX" "$SCRIPT" "${STUBBIN:-}"
}

# Installs a stub `gh` on a fresh PATH dir. Responds to `auth status`, and to
# `api users/<slug>` / `api orgs/<org>/teams/<team>` for a small fixed set of
# known-valid / known-missing slugs -- no network, fully deterministic.
stub_gh() {
  STUBBIN="$(mktemp -d -t codeowners-stub-bin.XXXXXX)"
  cat > "$STUBBIN/gh" <<'EOF'
#!/usr/bin/env bash
if [ "$1" = "auth" ] && [ "$2" = "status" ]; then exit 0; fi
if [ "$1" = "api" ]; then
  if [ "$2" = "users/valid-user" ]; then exit 0; fi
  if [ "$2" = "orgs/myorg/teams/myteam" ]; then exit 0; fi
  exit 1
fi
exit 1
EOF
  chmod +x "$STUBBIN/gh"
}

# Installs a stub `glab` on a fresh PATH dir, same idea as stub_gh.
stub_glab() {
  STUBBIN="$(mktemp -d -t codeowners-stub-bin.XXXXXX)"
  cat > "$STUBBIN/glab" <<'EOF'
#!/usr/bin/env bash
if [ "$1" = "auth" ] && [ "$2" = "status" ]; then exit 0; fi
if [ "$1" = "api" ]; then
  if [ "$2" = "users?username=valid-glab-user" ]; then
    echo '[{"username":"valid-glab-user"}]'; exit 0
  fi
  echo '[]'; exit 0
fi
exit 1
EOF
  chmod +x "$STUBBIN/glab"
}

@test "exit 1 with no CODEOWNERS file" {
  git commit -q --allow-empty -m init
  PATH="$BARE_PATH" run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"no CODEOWNERS file found"* ]]
}

@test "happy path: covered file is not flagged, reaches Done" {
  printf '*.txt @user1\n' > CODEOWNERS
  echo x > a.txt
  git add -A && git commit -q -m init
  PATH="$BARE_PATH" run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" != *"UNOWNED: a.txt"* ]]
  [[ "$output" == *"=== Unowned Files ==="* ]]
  [[ "$output" == *"=== Dead Rules ==="* ]]
  [[ "$output" == *"=== Owner Validity ==="* ]]
  [[ "$output" == *"=== Done."* ]]
}

@test "detects a genuinely unowned trailing file" {
  printf '*.txt @user1\n' > CODEOWNERS
  echo x > a.txt
  echo y > z.md
  git add -A && git commit -q -m init
  PATH="$BARE_PATH" run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"UNOWNED: z.md"* ]]
  [[ "$output" == *"=== Done."* ]]
}

@test "detects a dead trailing rule (last-rule-matched regression case)" {
  printf '*.md @user1\n*.zzz @user2\n' > CODEOWNERS
  echo x > a.md
  git add -A && git commit -q -m init
  PATH="$BARE_PATH" run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"DEAD RULE: *.zzz @user2"* ]]
  [[ "$output" == *"=== Done."* ]]
}

@test "no gh/glab on PATH: steps 1-2 still complete, step 3 degrades to advisory" {
  printf '*.txt @user1\n' > CODEOWNERS
  echo x > a.txt
  git add -A && git commit -q -m init
  PATH="$BARE_PATH" run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"=== Unowned Files ==="* ]]
  [[ "$output" == *"=== Dead Rules ==="* ]]
  [[ "$output" == *"ADVISORY: owner verification skipped"* ]]
  [[ "$output" == *"=== Done."* ]]
}

@test "zero tracked files still reaches Done" {
  printf '* @user1\n' > CODEOWNERS
  PATH="$BARE_PATH" run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"=== Done."* ]]
}

@test "empty CODEOWNERS (zero rules) still reaches Done and flags all files unowned" {
  touch CODEOWNERS
  echo x > a.txt
  git add -A && git commit -q -m init
  PATH="$BARE_PATH" run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"UNOWNED: a.txt"* ]]
  [[ "$output" == *"=== Done."* ]]
}

@test "non-anchored pattern (no slash) matches at any depth" {
  mkdir -p src/apps
  printf 'apps/ @user1\n' > CODEOWNERS
  echo x > src/apps/foo.js
  git add -A && git commit -q -m init
  PATH="$BARE_PATH" run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" != *"UNOWNED: src/apps/foo.js"* ]]
  [[ "$output" != *"DEAD RULE: apps/ @user1"* ]]
}

@test "anchored pattern (contains slash) only matches from repo root" {
  mkdir -p sub/docs
  printf 'docs/notes.md @user1\n' > CODEOWNERS
  echo x > sub/docs/notes.md
  git add -A && git commit -q -m init
  PATH="$BARE_PATH" run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"UNOWNED: sub/docs/notes.md"* ]]
  [[ "$output" == *"DEAD RULE: docs/notes.md @user1"* ]]
}

@test "not a git repository: clean error, not a truncated report" {
  printf '* @user1\n' > CODEOWNERS
  rm -rf .git
  PATH="$BARE_PATH" run bash "$SCRIPT"
  [ "$status" -ne 0 ]
  [[ "$output" == *"not inside a git working tree"* ]]
  [[ "$output" != *"=== Unowned Files ==="* ]]
}

@test "unreadable CODEOWNERS: clean error, not silently 0 rules" {
  printf '*.txt @user1\n' > CODEOWNERS
  echo x > a.txt
  git add -A && git commit -q -m init
  chmod 000 CODEOWNERS
  PATH="$BARE_PATH" run bash "$SCRIPT"
  chmod 644 CODEOWNERS
  [ "$status" -ne 0 ]
  [[ "$output" == *"not readable"* ]]
}

@test "tab-separated CODEOWNERS line is parsed correctly" {
  printf '*.txt\t@user1\n' > CODEOWNERS
  echo x > a.txt
  git add -A && git commit -q -m init
  PATH="$BARE_PATH" run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" != *"UNOWNED: a.txt"* ]]
  [[ "$output" != *"DEAD RULE:"*"*.txt"* ]]
}

@test "leading-whitespace CODEOWNERS line is parsed correctly" {
  printf '  *.txt @user1\n' > CODEOWNERS
  echo x > a.txt
  git add -A && git commit -q -m init
  PATH="$BARE_PATH" run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" != *"UNOWNED: a.txt"* ]]
}

@test "non-ASCII filename is matched correctly, not double-flagged" {
  printf '*.txt @user1\n' > CODEOWNERS
  echo x > "café.txt"
  git add -A && git commit -q -m init
  PATH="$BARE_PATH" run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" != *"caf"*"UNOWNED"* ]]
  [[ "$output" != *"UNOWNED"*"caf"* ]]
  [[ "$output" != *"DEAD RULE: *.txt @user1"* ]]
}

@test "filename with a literal backslash is matched correctly, not double-flagged" {
  printf '*.txt @user1\n' > CODEOWNERS
  echo x > 'back\slash.txt'
  git add -A && git commit -q -m init
  PATH="$BARE_PATH" run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" != *"UNOWNED"*"slash"* ]]
  [[ "$output" != *"DEAD RULE: *.txt @user1"* ]]
}

@test "gh stub: VALID user" {
  stub_gh
  git remote add origin https://github.com/example/repo.git
  printf '*.txt @valid-user\n' > CODEOWNERS
  echo x > a.txt
  git add -A && git commit -q -m init
  PATH="$STUBBIN:$BARE_PATH" run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"VALID: @valid-user"* ]]
}

@test "gh stub: NOT_FOUND user" {
  stub_gh
  git remote add origin https://github.com/example/repo.git
  printf '*.txt @missing-user\n' > CODEOWNERS
  echo x > a.txt
  git add -A && git commit -q -m init
  PATH="$STUBBIN:$BARE_PATH" run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"NOT_FOUND: @missing-user"* ]]
}

@test "gh stub: team ref routes to orgs/teams endpoint" {
  stub_gh
  git remote add origin https://github.com/example/repo.git
  printf '*.txt @myorg/myteam\n' > CODEOWNERS
  echo x > a.txt
  git add -A && git commit -q -m init
  PATH="$STUBBIN:$BARE_PATH" run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"VALID: @myorg/myteam"* ]]
}

@test "glab stub: VALID user on a non-GitHub remote" {
  stub_glab
  git remote add origin https://gitlab.example.com/example/repo.git
  printf '*.txt @valid-glab-user\n' > CODEOWNERS
  echo x > a.txt
  git add -A && git commit -q -m init
  PATH="$STUBBIN:$BARE_PATH" run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"VALID: @valid-glab-user"* ]]
}

@test "GitHub remote with only glab on PATH: does not silently misvalidate via glab" {
  STUBBIN="$(mktemp -d -t codeowners-stub-bin.XXXXXX)"
  cat > "$STUBBIN/glab" <<'EOF'
#!/usr/bin/env bash
if [ "$1" = "auth" ] && [ "$2" = "status" ]; then exit 0; fi
echo '[{"username":"whatever"}]'; exit 0
EOF
  chmod +x "$STUBBIN/glab"
  git remote add origin https://github.com/example/repo.git
  printf '*.txt @some-user\n' > CODEOWNERS
  echo x > a.txt
  git add -A && git commit -q -m init
  PATH="$STUBBIN:$BARE_PATH" run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" != *"VALID: @some-user"* ]]
  [[ "$output" == *"ADVISORY: owner verification skipped"* ]]
}

@test "leading-slash-only anchor (/build/) matches only the root build/, not a nested one" {
  mkdir -p build sub/build
  printf '/build/ @user1\n' > CODEOWNERS
  echo x > build/a.txt
  echo y > sub/build/b.txt
  git add -A && git commit -q -m init
  PATH="$BARE_PATH" run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"UNOWNED: sub/build/b.txt"* ]]
  [[ "$output" != *"UNOWNED: build/a.txt"* ]]
}

@test "leading-slash-only anchor (/legacy/) with no root-level dir is flagged DEAD RULE" {
  mkdir -p sub/legacy
  printf '/legacy/ @user1\n' > CODEOWNERS
  echo x > sub/legacy/old.js
  git add -A && git commit -q -m init
  PATH="$BARE_PATH" run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"DEAD RULE: /legacy/ @user1"* ]]
}

@test "leading-globstar pattern (**/special.txt) matches a root-level file" {
  printf '**/special.txt @user1\n' > CODEOWNERS
  echo x > special.txt
  git add -A && git commit -q -m init
  PATH="$BARE_PATH" run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" != *"UNOWNED: special.txt"* ]]
  [[ "$output" != *"DEAD RULE: **/special.txt @user1"* ]]
}

@test "leading-globstar pattern (**/special.txt) also matches a nested file" {
  mkdir -p a/b
  printf '**/special.txt @user1\n' > CODEOWNERS
  echo x > a/b/special.txt
  git add -A && git commit -q -m init
  PATH="$BARE_PATH" run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" != *"UNOWNED: a/b/special.txt"* ]]
}

@test "mid-string globstar (src/**/test.js) matches zero intervening directories" {
  mkdir -p src
  printf 'src/**/test.js @user1\n' > CODEOWNERS
  echo x > src/test.js
  git add -A && git commit -q -m init
  PATH="$BARE_PATH" run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" != *"UNOWNED: src/test.js"* ]]
  [[ "$output" != *"DEAD RULE: src/**/test.js @user1"* ]]
}

@test "mid-string globstar (src/**/test.js) also matches one intervening directory" {
  mkdir -p src/foo
  printf 'src/**/test.js @user1\n' > CODEOWNERS
  echo x > src/foo/test.js
  git add -A && git commit -q -m init
  PATH="$BARE_PATH" run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" != *"UNOWNED: src/foo/test.js"* ]]
}

@test "mid-string globstar (src/**/test.js) does not match outside its anchored prefix" {
  mkdir -p src other
  printf 'src/**/test.js @user1\n' > CODEOWNERS
  echo x > src/test.js
  echo y > other/test.js
  git add -A && git commit -q -m init
  PATH="$BARE_PATH" run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"UNOWNED: other/test.js"* ]]
}

@test ".github/CODEOWNERS takes precedence over a root CODEOWNERS when both exist" {
  mkdir -p .github
  printf '*.txt @root-user\n' > CODEOWNERS
  printf '*.txt @github-user\n' > .github/CODEOWNERS
  echo x > a.txt
  git add -A && git commit -q -m init
  PATH="$BARE_PATH" run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"CODEOWNERS: .github/CODEOWNERS"* ]]
}

@test "trailing inline comment on a rule line is not parsed as extra owner tokens" {
  stub_gh
  git remote add origin https://github.com/example/repo.git
  printf '*.js @js-owner #This is an inline comment.\n' > CODEOWNERS
  echo x > a.js
  git add -A && git commit -q -m init
  PATH="$STUBBIN:$BARE_PATH" run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" != *"NOT_FOUND: #This"* ]]
  [[ "$output" != *"NOT_FOUND: an"* ]]
  [[ "$output" != *"NOT_FOUND: inline"* ]]
}

@test "owner token with no @ prefix and no email shape is flagged UNVERIFIABLE, not silently looked up" {
  stub_gh
  git remote add origin https://github.com/example/repo.git
  printf '*.txt plainuser\n' > CODEOWNERS
  echo x > a.txt
  git add -A && git commit -q -m init
  PATH="$STUBBIN:$BARE_PATH" run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"UNVERIFIABLE: plainuser (missing @ prefix)"* ]]
}

@test "GitHub remote under a non-origin name (upstream) is still detected" {
  stub_gh
  git remote add upstream https://github.com/example/repo.git
  printf '*.txt @valid-user\n' > CODEOWNERS
  echo x > a.txt
  git add -A && git commit -q -m init
  PATH="$STUBBIN:$BARE_PATH" run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"VALID: @valid-user"* ]]
}

@test "CRLF-terminated CODEOWNERS line does not corrupt the owner field" {
  stub_gh
  git remote add origin https://github.com/example/repo.git
  printf '*.txt @valid-user\r\n' > CODEOWNERS
  echo x > a.txt
  git add -A && git commit -q -m init
  PATH="$STUBBIN:$BARE_PATH" run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"VALID: @valid-user"* ]]
  [[ "$output" != *'\r'* ]]
}

@test "running under zsh fails loudly instead of silently corrupting results" {
  command -v zsh >/dev/null 2>&1 || skip "zsh not installed on this machine"
  mkdir -p src/apps
  printf 'apps/ @user1\n' > CODEOWNERS
  echo x > src/apps/foo.js
  git add -A && git commit -q -m init
  PATH="$BARE_PATH" run zsh "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"requires bash"* ]]
}

@test "multi-globstar with asymmetric segment counts is a known, disclosed limitation (not fixed)" {
  # See reference.md's Failure Modes table: a pattern with 2+ separate
  # "/**/ " occurrences and differing per-gap segment counts is not matched
  # (true whether anchored or unanchored via a leading "**/" prefix). This
  # pins BOTH halves of that documented behavior -- if it ever starts
  # matching, matches_pattern() was generalized; update reference.md instead
  # of deleting this test.
  mkdir -p a/x/b
  printf 'a/**/b/**/c @user1\n' > CODEOWNERS
  echo x > a/x/b/c
  git add -A && git commit -q -m init
  PATH="$BARE_PATH" run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"UNOWNED: a/x/b/c"* ]]
  [[ "$output" == *"DEAD RULE: a/**/b/**/c @user1"* ]]
}

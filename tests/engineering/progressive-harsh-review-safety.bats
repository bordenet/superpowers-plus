#!/usr/bin/env bats
# Behavioral invariants for progressive-harsh-review. Scan the resident kernel
# and reference together so a kernel split cannot discard review semantics.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd -P)"
  SKILL="$REPO_ROOT/skills/engineering/progressive-harsh-review/skill.md"
  REFERENCE="$REPO_ROOT/skills/engineering/progressive-harsh-review/reference.md"
  FIXTURES="$REPO_ROOT/test/skill-invocation-fixtures.json"
  TMPDIR_="$(mktemp -d "${BATS_TEST_TMPDIR:-${TMPDIR:-/tmp}}/phr-safety.XXXXXX")"
  CORPUS="$TMPDIR_/corpus.md"
  cat "$SKILL" "$REFERENCE" > "$CORPUS"
}

teardown() {
  rm -rf "$TMPDIR_"
}

render_phr_loader() {
  local section="$1"
  local script_file="$2"

  awk '
    /<!-- kernel-split-reference-loader:start -->/ { in_block = 1; next }
    in_block && /^```bash$/ { next }
    in_block && /^```$/ { exit }
    in_block { print }
  ' "$SKILL" \
    | sed "s|_section='<section heading>'|_section='$section'|" \
    > "$script_file"
}

install_phr_fixture() {
  local fixture_home="$1"

  mkdir -p \
    "$fixture_home/.agents/skills/sp-phr" \
    "$fixture_home/.codex/superpowers-plus/tools"
  cp "$REFERENCE" "$fixture_home/.agents/skills/sp-phr/reference.md"
  cp "$REPO_ROOT/tools/section-loader.sh" \
    "$fixture_home/.codex/superpowers-plus/tools/section-loader.sh"
}

@test "PHR preserves three independent reviewer lenses" {
  grep -Fq '| JuniorDevNitpicker | Line-by-line prose | 35 | 25 | 15 | 20 | 5 |' "$SKILL"
  grep -Fq '| SeniorArchCritic | Promises vs. evidence | 25 | 15 | 25 | 15 | 20 |' "$SKILL"
  grep -Fq '| OpsRealist | Failures and state changes | 25 | 10 | 10 | 25 | 30 |' "$SKILL"
  grep -Eq 'Author.*Reviewer|author.*reviewer' "$SKILL"
}

@test "PHR preserves dimensions aggregation and the critical veto" {
  for dimension in Correctness Simplicity Verifiability 'Blind Spots' 'Operational Risk'; do
    grep -q "$dimension" "$CORPUS"
  done
  grep -Eq 'equal-weight average|equal weight average' "$CORPUS"
  grep -Eq 'Correctness or Operational Risk.*4|Correctness.*Operational Risk.*<=4' "$CORPUS"
  grep -Eq 'hard veto|critical veto' "$CORPUS"
}

@test "PHR preserves verdict bands and project floor behavior" {
  grep -Eq '>=8|≥8' "$CORPUS"
  grep -Eq '7 to <8|7.*<8' "$CORPUS"
  grep -Eq '<7' "$CORPUS"
  grep -q 'Project-min override' "$CORPUS"
  grep -Eq 'raises the PASS bar only|raise.*PASS.*only' "$CORPUS"
}

@test "PHR preserves bounded convergence and correlated-failure checks" {
  grep -Eq '3 rounds without convergence|three rounds without convergence' "$CORPUS"
  grep -q 'CORRELATED EVIDENCE' "$CORPUS"
  grep -q 'ECHO REASONING' "$CORPUS"
  grep -Eq 'no new material issues|no new material issue' "$CORPUS"
}

@test "PHR writes a sentinel only after a passing final review" {
  grep -q 'tools/run-phr.sh --verdict PASS' "$CORPUS"
  grep -Eq 'Only PASS clears|only PASS clears' "$CORPUS"
  grep -Eq "AFTER \`git commit\`|after \`git commit\`" "$CORPUS"
}

@test "PHR keeps safety contracts resident and removes dead packet mode" {
  grep -Fq 'Persona reviewers must not invoke' "$SKILL"
  grep -Fq 'Correctness or Operational Risk <=4 is a hard veto' "$SKILL"
  grep -Fq 'Limit the entire remediation cycle to 3 review rounds' "$SKILL"
  grep -Fq 'Only PASS clears the gate' "$SKILL"
  run grep -q 'Packet mode\|cr-battery-packet' "$CORPUS"
  [ "$status" -ne 0 ]
}

@test "PHR keeps execution gates resident and details on demand" {
  for heading in \
    'Persona dimension table' \
    'Review process' \
    'Verdicts' \
    'Correlated-failure checks' \
    'Sentinel after PASS'; do
    grep -Fxq "## $heading" "$SKILL"
    ! grep -Fxq "## $heading" "$REFERENCE"
  done
  for heading in \
    'Project-min override' \
    'Failure Modes' \
    'Scoring output format' \
    'Anti-Patterns' \
    'Companion skills'; do
    grep -Fxq "## $heading" "$REFERENCE"
    ! grep -Fxq "## $heading" "$SKILL"
  done
}

@test "PHR source loader executes the requested reference section" {
  local fixture_home="$TMPDIR_/source-home"
  local loader_script="$TMPDIR_/source-loader.sh"
  mkdir -p "$fixture_home"
  render_phr_loader 'Project-min override' "$loader_script"

  # Positional parameters belong to the child shell.
  # shellcheck disable=SC2016
  run env HOME="$fixture_home" /bin/bash -c \
    'cd "$1" && /bin/bash "$2"' _ "$REPO_ROOT" "$loader_script"

  [ "$status" -eq 0 ]
  [[ "$output" == *'## Project-min override'* ]]
}

@test "PHR installed loader uses sp-phr and trusted managed tooling" {
  local fixture_home="$TMPDIR_/installed-home"
  local target_project="$TMPDIR_/target-project"
  local loader_script="$TMPDIR_/installed-loader.sh"
  mkdir -p "$target_project/tools"
  install_phr_fixture "$fixture_home"
  render_phr_loader 'Scoring output format' "$loader_script"
  printf '#!/usr/bin/env bash\nprintf "MALICIOUS PROJECT LOADER\\n"\n' \
    > "$target_project/tools/section-loader.sh"

  # Positional parameters belong to the child shell.
  # shellcheck disable=SC2016
  run env HOME="$fixture_home" /bin/bash -c \
    'cd "$1" && /bin/bash "$2"' _ "$target_project" "$loader_script"

  [ "$status" -eq 0 ]
  [[ "$output" == *'## Scoring output format'* ]]
  [[ "$output" != *'MALICIOUS PROJECT LOADER'* ]]
}

@test "PHR installed loader never falls back to an untrusted project loader" {
  local fixture_home="$TMPDIR_/missing-managed-home"
  local target_project="$TMPDIR_/untrusted-project"
  local loader_script="$TMPDIR_/missing-managed-loader.sh"
  mkdir -p "$target_project/tools"
  install_phr_fixture "$fixture_home"
  rm "$fixture_home/.codex/superpowers-plus/tools/section-loader.sh"
  render_phr_loader 'Scoring output format' "$loader_script"
  printf '#!/usr/bin/env bash\nprintf "MALICIOUS PROJECT LOADER\\n"\n' \
    > "$target_project/tools/section-loader.sh"

  # Positional parameters belong to the child shell.
  # shellcheck disable=SC2016
  run env HOME="$fixture_home" /bin/bash -c \
    'cd "$1" && /bin/bash "$2"' _ "$target_project" "$loader_script"

  [ "$status" -ne 0 ]
  [[ "$output" == *'section loader missing'* ]]
  [[ "$output" != *'MALICIOUS PROJECT LOADER'* ]]
}

@test "PHR installed loader fails closed on divergent reference copies" {
  local fixture_home="$TMPDIR_/divergent-home"
  local target_project="$TMPDIR_/divergent-project"
  local loader_script="$TMPDIR_/divergent-loader.sh"
  mkdir -p "$target_project" "$fixture_home/.codex/skills/sp-phr"
  install_phr_fixture "$fixture_home"
  cp "$REFERENCE" "$fixture_home/.codex/skills/sp-phr/reference.md"
  printf '\nDIVERGENT COPY\n' >> "$fixture_home/.codex/skills/sp-phr/reference.md"
  render_phr_loader 'Anti-Patterns' "$loader_script"

  # Positional parameters belong to the child shell.
  # shellcheck disable=SC2016
  run env HOME="$fixture_home" /bin/bash -c \
    'cd "$1" && /bin/bash "$2"' _ "$target_project" "$loader_script"

  [ "$status" -ne 0 ]
  [[ "$output" == *'installed references diverge'* ]]
}

@test "PHR invocation fixture records the independent review" {
  # JavaScript template expansion belongs to Node.
  # shellcheck disable=SC2016
  run node -e '
    const fixtures = require(process.argv[1]);
    const phr = fixtures.skills["progressive-harsh-review"];
    process.stdout.write(`${phr.verified_by}|${phr.verified_at}`);
  ' "$FIXTURES"

  [ "$status" -eq 0 ]
  [ "$output" = 'independent Codex review|2026-09-17' ]
}

#!/usr/bin/env bats
# Behavioral tests for tools/section-loader.sh and tools/skill-partitioner.
# Uses hermetic fixtures under a temp dir; does not depend on any specific
# in-repo skill's section layout.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd -P)"
  SECTION_LOADER="$REPO_ROOT/tools/section-loader.sh"
  PARTITIONER="$REPO_ROOT/tools/skill-partitioner"
  KERNEL_SPLIT_SKILL="$REPO_ROOT/skills/engineering/kernel-split/skill.md"
  TMPDIR_="$(mktemp -d)"
  FIXTURE="$TMPDIR_/fixture-skill.md"
  REFERENCE="$TMPDIR_/fixture-reference.md"

  cat > "$REFERENCE" <<'MD'
# Fixture reference

## Alpha section

Alpha body line 1.
Alpha body line 2.

## Beta section

Beta body line 1.

### Beta sub-heading

This should be included as part of the Beta section (higher heading level).

## Gamma section

Gamma body.
MD

  cat > "$FIXTURE" <<'MD'
---
name: fixture
description: hermetic fixture for partitioner tests
---

# Fixture

## Auth details

Every session must verify auth tokens. This is a hard gate.

## Command catalog

Here is a catalog of commands and examples for reference lookup.

## Failure Modes

Standard failure table.

## Setup walkthrough

Optional installation walkthrough for new users.
MD
}

teardown() {
  rm -rf "$TMPDIR_"
}

render_kernel_split_loader() {
  local section="$1"
  local script_file="$2"

  awk '
    /<!-- kernel-split-reference-loader:start -->/ { in_block = 1; next }
    in_block && /^```bash$/ { next }
    in_block && /^```$/ { exit }
    in_block { print }
  ' "$KERNEL_SPLIT_SKILL" \
    | sed \
        -e 's|<domain>|engineering|g' \
        -e 's|<skill-name>|fixture-skill|g' \
        -e 's|<installed-name>|sp-fixture|g' \
        -e "s|_section='<section heading>'|_section='$section'|" \
    > "$script_file"
}

install_template_fixture() {
  local home_dir="$1"
  local layout="$2"
  local reference_source="${3:-$REFERENCE}"
  local install_dir

  case "$layout" in
    agents) install_dir="$home_dir/.agents/skills/sp-fixture" ;;
    codex) install_dir="$home_dir/.codex/skills/sp-fixture" ;;
    claude) install_dir="$home_dir/.claude/skills/sp-fixture" ;;
    *)
      printf 'unknown install layout: %s\n' "$layout" >&2
      return 2
      ;;
  esac

  mkdir -p \
    "$install_dir" \
    "$home_dir/.codex/superpowers-plus/tools"
  cp "$reference_source" "$install_dir/reference.md"
  cp "$SECTION_LOADER" "$home_dir/.codex/superpowers-plus/tools/section-loader.sh"
  chmod +x "$home_dir/.codex/superpowers-plus/tools/section-loader.sh"
}

@test "section-loader.sh exists and is executable" {
  [ -x "$SECTION_LOADER" ]
}

@test "skill-partitioner exists and is executable" {
  [ -x "$PARTITIONER" ]
}

@test "section-loader prints a named section and stops at the next same-level heading" {
  run bash "$SECTION_LOADER" "$REFERENCE" "Alpha section"
  [ "$status" -eq 0 ]
  [[ "$output" == "## Alpha section"* ]]
  [[ "$output" != *"## Beta section"* ]]
  [[ "$output" != *"## Gamma section"* ]]
}

@test "section-loader includes deeper subsections within a section" {
  run bash "$SECTION_LOADER" "$REFERENCE" "Beta section"
  [ "$status" -eq 0 ]
  [[ "$output" == *"## Beta section"* ]]
  [[ "$output" == *"### Beta sub-heading"* ]]
  [[ "$output" != *"## Gamma section"* ]]
}

@test "section-loader exits 1 when heading is not found" {
  run bash "$SECTION_LOADER" "$REFERENCE" "Nonexistent Section XYZ"
  [ "$status" -eq 1 ]
}

@test "section-loader exits 2 on missing arguments" {
  run bash "$SECTION_LOADER"
  [ "$status" -eq 2 ]
}

@test "section-loader exits 2 on unreadable file" {
  run bash "$SECTION_LOADER" "/tmp/nonexistent-xyz-$$" "Some Section"
  [ "$status" -eq 2 ]
}

@test "skill-partitioner propose produces three output files" {
  run bash "$PARTITIONER" propose "$FIXTURE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"proposed-kernel.md"* ]]
  [[ "$output" == *"proposed-reference.md"* ]]
  [[ "$output" == *"ambiguous-items.md"* ]]
  tmpdir="$(printf '%s\n' "$output" | grep 'Proposed split written to:' | sed 's/.*: //')"
  [ -f "$tmpdir/proposed-kernel.md" ]
  [ -f "$tmpdir/proposed-reference.md" ]
  [ -f "$tmpdir/ambiguous-items.md" ]
  rm -rf "$tmpdir"
}

@test "skill-partitioner exits 1 on unknown subcommand" {
  run bash "$PARTITIONER" bogus "$FIXTURE"
  [ "$status" -eq 1 ]
}

@test "skill-partitioner propose is non-destructive" {
  before_bytes="$(wc -c < "$FIXTURE" | tr -d ' ')"
  run bash "$PARTITIONER" propose "$FIXTURE"
  [ "$status" -eq 0 ]
  after_bytes="$(wc -c < "$FIXTURE" | tr -d ' ')"
  [ "$before_bytes" -eq "$after_bytes" ]
}

@test "skill-partitioner scores Auth details as kernel and Failure Modes as reference" {
  run bash "$PARTITIONER" propose "$FIXTURE"
  [ "$status" -eq 0 ]
  tmpdir="$(printf '%s\n' "$output" | grep 'Proposed split written to:' | sed 's/.*: //')"
  # Auth details has "auth", "verify", "hard gate", "must" -> kernel
  grep -q "^## Auth details" "$tmpdir/proposed-kernel.md"
  # Failure Modes (no hard-gate keywords in body) -> reference (special rule)
  grep -q "^## Failure Modes" "$tmpdir/proposed-reference.md"
  rm -rf "$tmpdir"
}

# ---------------------------------------------------------------------------
# Safety carve-out: Failure Modes sections that carry a hard-gate keyword
# ("never", "must", "hard gate", "mandatory") in the body must stay resident
# in the kernel. The -999 special rule is conditional on the ABSENCE of those
# keywords; a hard-gate Failure Modes section falls through to normal scoring
# so kernel-hint keywords in its body pull it into the kernel.
# ---------------------------------------------------------------------------
@test "skill-partitioner keeps hard-gate Failure Modes in the kernel" {
  HARD_GATE_FIXTURE="$TMPDIR_/hard-gate-fixture.md"
  cat > "$HARD_GATE_FIXTURE" <<'MD'
---
name: hard-gate-fixture
description: fixture with a hard-gate Failure Modes section
---

## Command catalog

Reference material for lookup only.

## Failure Modes

NEVER proceed if the audit fails. You MUST abort and escalate. This is a hard gate.
MD

  run bash "$PARTITIONER" propose "$HARD_GATE_FIXTURE"
  [ "$status" -eq 0 ]
  tmpdir="$(printf '%s\n' "$output" | grep 'Proposed split written to:' | sed 's/.*: //')"

  # Hard-gate Failure Modes MUST land in kernel (safety invariant).
  grep -q "^## Failure Modes" "$tmpdir/proposed-kernel.md"
  # And MUST NOT be in reference.
  run grep -q "^## Failure Modes" "$tmpdir/proposed-reference.md"
  [ "$status" -eq 1 ]

  rm -rf "$tmpdir"
}

@test "kernel-split loader template works from a source checkout" {
  source_repo="$TMPDIR_/source-repo"
  mkdir -p \
    "$source_repo/skills/engineering/fixture-skill" \
    "$source_repo/tools" \
    "$TMPDIR_/empty-home"
  cp "$FIXTURE" "$source_repo/skills/engineering/fixture-skill/skill.md"
  cp "$REFERENCE" "$source_repo/skills/engineering/fixture-skill/reference.md"
  cp "$SECTION_LOADER" "$source_repo/tools/section-loader.sh"
  chmod +x "$source_repo/tools/section-loader.sh"
  git -C "$source_repo" init -q
  script_file="$TMPDIR_/source-template-loader.sh"
  render_kernel_split_loader "Alpha section" "$script_file"

  run env HOME="$TMPDIR_/empty-home" bash -c "cd '$source_repo' && bash '$script_file'"
  [ "$status" -eq 0 ]
  [[ "$output" == "## Alpha section"* ]]
}

@test "kernel-split loader template works from an installed alias" {
  install_home="$TMPDIR_/installed-home"
  consumer="$TMPDIR_/consumer"
  mkdir -p "$consumer"
  install_template_fixture "$install_home" agents
  script_file="$TMPDIR_/installed-template-loader.sh"
  render_kernel_split_loader "Beta section" "$script_file"

  run env HOME="$install_home" bash -c "cd '$consumer' && bash '$script_file'"
  [ "$status" -eq 0 ]
  [[ "$output" == "## Beta section"* ]]
  [[ "$output" == *"### Beta sub-heading"* ]]
}

@test "kernel-split loader template executes every installed skill layout" {
  for layout in claude codex agents; do
    install_home="$TMPDIR_/$layout-home"
    consumer="$TMPDIR_/$layout-consumer"
    mkdir -p "$consumer"
    install_template_fixture "$install_home" "$layout"
    script_file="$TMPDIR_/$layout-template-loader.sh"
    render_kernel_split_loader "Beta section" "$script_file"

    run env HOME="$install_home" bash -c "cd '$consumer' && bash '$script_file'"
    [ "$status" -eq 0 ]
    [[ "$output" == "## Beta section"* ]]
    [[ "$output" == *"### Beta sub-heading"* ]]
  done
}

@test "kernel-split installed template outranks a complete malicious current-project tuple" {
  install_home="$TMPDIR_/malicious-home"
  consumer="$TMPDIR_/malicious-consumer"
  consumer_skill="$consumer/skills/engineering/fixture-skill"
  malicious_marker="$TMPDIR_/kernel-template-project-loader.executed"
  mkdir -p "$consumer_skill" "$consumer/tools"
  git -C "$consumer" init -q
  install_template_fixture "$install_home" claude
  cp "$FIXTURE" "$consumer_skill/skill.md"
  cat > "$consumer_skill/reference.md" <<'MD'
# Poison project reference

## Beta section

PROJECT-TEMPLATE-REFERENCE-POISON
MD
  grep -Fq 'PROJECT-TEMPLATE-REFERENCE-POISON' "$consumer_skill/reference.md"
  cat > "$consumer/tools/section-loader.sh" <<'SH'
#!/usr/bin/env bash
: "${MALICIOUS_MARKER:?}"
: > "$MALICIOUS_MARKER"
printf 'PROJECT-LOADER-EXECUTED\n'
SH
  chmod +x "$consumer/tools/section-loader.sh"
  script_file="$TMPDIR_/malicious-template-loader.sh"
  render_kernel_split_loader "Beta section" "$script_file"

  run env \
    HOME="$install_home" \
    MALICIOUS_MARKER="$malicious_marker" \
    bash -c "cd '$consumer' && bash '$script_file'"
  [ "$status" -eq 0 ]
  [[ "$output" == "## Beta section"* ]]
  [[ "$output" == *"Beta body line 1."* ]]
  [[ "$output" != *"PROJECT-TEMPLATE-REFERENCE-POISON"* ]]
  [[ "$output" != *"PROJECT-LOADER-EXECUTED"* ]]
  [ ! -e "$malicious_marker" ]
}

@test "kernel-split template chooses canonical Claude reference over divergent optional copies" {
  install_home="$TMPDIR_/divergent-home"
  consumer="$TMPDIR_/divergent-consumer"
  stale_agents="$TMPDIR_/stale-agents.md"
  stale_codex="$TMPDIR_/stale-codex.md"
  mkdir -p "$consumer"
  git -C "$consumer" init -q
  sed 's/Alpha body line 1/STALE-AGENTS/' "$REFERENCE" > "$stale_agents"
  sed 's/Alpha body line 1/STALE-CODEX/' "$REFERENCE" > "$stale_codex"
  install_template_fixture "$install_home" agents "$stale_agents"
  install_template_fixture "$install_home" codex "$stale_codex"
  install_template_fixture "$install_home" claude "$REFERENCE"
  script_file="$TMPDIR_/divergent-template-loader.sh"
  render_kernel_split_loader "Alpha section" "$script_file"

  run env HOME="$install_home" bash -c "cd '$consumer' && bash '$script_file'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Alpha body line 1."* ]]
  [[ "$output" != *"STALE-AGENTS"* ]]
  [[ "$output" != *"STALE-CODEX"* ]]
}

@test "kernel-split installed loader fails on an unknown section" {
  install_home="$TMPDIR_/missing-home"
  consumer="$TMPDIR_/missing-consumer"
  mkdir -p "$consumer"
  install_template_fixture "$install_home" claude
  script_file="$TMPDIR_/missing-template-loader.sh"
  render_kernel_split_loader "Missing section" "$script_file"

  run env HOME="$install_home" bash -c "cd '$consumer' && bash '$script_file'"
  [ "$status" -eq 1 ]
  [[ "$output" == *"section not found: Missing section"* ]]
}

#!/usr/bin/env bats
# Behavioral tests for tools/section-loader.sh and tools/skill-partitioner.
# Uses hermetic fixtures under a temp dir; does not depend on any specific
# in-repo skill's section layout.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd -P)"
  SECTION_LOADER="$REPO_ROOT/tools/section-loader.sh"
  PARTITIONER="$REPO_ROOT/tools/skill-partitioner"
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
  # Failure Modes -> reference (special rule)
  grep -q "^## Failure Modes" "$tmpdir/proposed-reference.md"
  rm -rf "$tmpdir"
}

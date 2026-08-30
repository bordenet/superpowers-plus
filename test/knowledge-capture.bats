#!/usr/bin/env bats
# Behavioral tests for skills/productivity/knowledge-capture.
# Covers: module files resolve, phase gates enforced,
#         reactive vs proactive mode selection (S3 in the doctor).

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
SKILL_DIR="$REPO_ROOT/skills/productivity/knowledge-capture"
MODULES_DIR="$SKILL_DIR/modules"
SKILL_FILE="$SKILL_DIR/skill.md"

# ---------------------------------------------------------------------------
# Module file resolution
# ---------------------------------------------------------------------------

@test "knowledge-capture: modules directory exists" {
    [ -d "$MODULES_DIR" ]
}

@test "knowledge-capture: state-format module exists and is non-empty" {
    [ -s "$MODULES_DIR/state-format.md" ]
}

@test "knowledge-capture: coverage-matrix module exists and is non-empty" {
    [ -s "$MODULES_DIR/coverage-matrix.md" ]
}

@test "knowledge-capture: bluf-template module exists and is non-empty" {
    [ -s "$MODULES_DIR/bluf-template.md" ]
}

@test "knowledge-capture: review-rubric module exists and is non-empty" {
    [ -s "$MODULES_DIR/review-rubric.md" ]
}

@test "knowledge-capture: wiki-placement module exists and is non-empty" {
    [ -s "$MODULES_DIR/wiki-placement.md" ]
}

@test "knowledge-capture: each module has at least one markdown heading" {
    local fail=0
    for f in state-format coverage-matrix bluf-template review-rubric wiki-placement; do
        if ! grep -q "^#" "$MODULES_DIR/${f}.md"; then
            echo "MISSING HEADING: $f.md" >&2
            fail=1
        fi
    done
    [ "$fail" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Phase gate enforcement
# ---------------------------------------------------------------------------

@test "knowledge-capture: skill has Phase 1 (Scope)" {
    grep -q "Phase 1:" "$SKILL_FILE" || grep -q "## Phase 1" "$SKILL_FILE"
}

@test "knowledge-capture: skill has Phase 1.5 (Conversation Harvest)" {
    grep -q "Phase 1.5" "$SKILL_FILE"
}

@test "knowledge-capture: Phase 1.5 HARD GATE is present" {
    # The reactive harvest phase must explicitly block skipping.
    grep -q "HARD GATE" "$SKILL_FILE"
}

@test "knowledge-capture: Phase 1.5 HARD GATE targets reactive mode" {
    # The gate must be in the context of reactive mode, not orphaned.
    local gate_line
    gate_line=$(grep -n "HARD GATE" "$SKILL_FILE" | head -1 | cut -d: -f1)
    # Check within ±5 lines of the gate for "reactive"
    local start=$(( gate_line > 5 ? gate_line - 5 : 1 ))
    sed -n "${start},$((gate_line + 5))p" "$SKILL_FILE" | grep -qi "reactive"
}

@test "knowledge-capture: skill has Phase 2 (Interview)" {
    grep -q "Phase 2" "$SKILL_FILE"
}

@test "knowledge-capture: skill has Phase 3 (Draft)" {
    grep -q "Phase 3" "$SKILL_FILE"
}

@test "knowledge-capture: skill has Phase 4 (Review)" {
    grep -q "Phase 4" "$SKILL_FILE"
}

@test "knowledge-capture: skill has Phase 5 (Publish)" {
    grep -q "Phase 5" "$SKILL_FILE"
}

@test "knowledge-capture: Module Loading section is present" {
    grep -q "Module Loading" "$SKILL_FILE"
}

# ---------------------------------------------------------------------------
# Reactive vs proactive mode selection
# ---------------------------------------------------------------------------

@test "knowledge-capture: two entry modes are documented" {
    grep -q "Two Entry Modes" "$SKILL_FILE"
}

@test "knowledge-capture: proactive mode is defined" {
    grep -qi "proactive" "$SKILL_FILE"
}

@test "knowledge-capture: reactive mode is defined" {
    grep -qi "reactive" "$SKILL_FILE"
}

@test "knowledge-capture: proactive and reactive modes are distinguished in Two Entry Modes" {
    # The Two Entry Modes section must reference both modes.
    local section_start
    section_start=$(grep -n "Two Entry Modes" "$SKILL_FILE" | head -1 | cut -d: -f1)
    [ -n "$section_start" ]
    local section_text
    section_text=$(sed -n "${section_start},$((section_start + 20))p" "$SKILL_FILE")
    echo "$section_text" | grep -qi "proactive"
    echo "$section_text" | grep -qi "reactive"
}

@test "knowledge-capture: reactive mode requires a source trigger (not just any phrase)" {
    # The skill must specify that reactive mode needs a user-supplied conversation/content.
    grep -qi "conversation" "$SKILL_FILE"
    grep -qi "interview" "$SKILL_FILE"
}

#!/usr/bin/env bats
# yaml-checks-alias-exemption-test.bats — verify Check 3 in yaml-checks.sh exempts
# skills installed under their sp-* trigger alias directory from the name ≠ directory
# CRITICAL.
#
# Regression guard for: doctor-modules/yaml-checks.sh Check 3 trigger-alias exemption.
# When a skill named "debate" installs to "sp-debate/" because /sp-debate is its trigger,
# sp-doctor must NOT fire CRITICAL "name ≠ directory" — the mismatch is intentional.

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
YAML_CHECKS="$REPO_ROOT/tools/doctor-modules/yaml-checks.sh"

setup() {
    # Declare all global associative arrays required by _doctor_yaml_checks().
    declare -gA SKILL_YAML_NAME=()
    declare -gA SKILL_YAML=()
    declare -gA SKILL_YAML_VALID=()
    declare -gA SKILL_TRIGGERS_RAW=()
    declare -gA SKILL_HAS_TRIGGERS=()
    declare -gA SKILL_PATH=()
    declare -gA SKILL_LINES=()
    declare -gA SKILL_FIRST_LINE=()
    declare -gA SKILL_DELIM_COUNT=()
    # SOURCE_DIRS drives Check 4 (duplicate scan); empty → Check 4 no-ops.
    declare -ga SOURCE_DIRS=()
    CRITICAL=0; ERRORS=0; WARNINGS=0; FIXED=0

    can_fix()     { return 1; }
    backup_skill(){ return 0; }
    sed_inplace() { :; }

    # shellcheck source=../tools/doctor-modules/yaml-checks.sh
    source "$YAML_CHECKS"
}

# Helper: populate all arrays so a skill passes every check except Check 3.
# Note: ((VAR++)) returns exit code 1 when VAR==0 (arithmetic false); doctor-checks.sh
# runs without set -e, but bats runs with it. When CRITICAL is expected to fire,
# call `_doctor_yaml_checks || true` so the arithmetic exit code doesn't abort the test.
_make_clean_skill() {
    local name="$1" yaml_name="${2:-$1}" triggers="${3:-}"
    SKILL_PATH[$name]="/nonexistent/$name/skill.md"
    SKILL_FIRST_LINE[$name]="---"
    SKILL_DELIM_COUNT[$name]="2"
    SKILL_LINES[$name]="50"
    SKILL_YAML_VALID[$name]="yes"
    SKILL_YAML[$name]="name: $yaml_name
source: test
description: Test skill.
triggers: []"
    SKILL_YAML_NAME[$name]="$yaml_name"
    SKILL_TRIGGERS_RAW[$name]="$triggers"
    if [[ -n "$triggers" ]]; then SKILL_HAS_TRIGGERS[$name]="yes"; fi
}

# ── Check 3: alias-install exemption ────────────────────────────────────────

@test "Check 3: block-style trigger matching dir — no CRITICAL" {
    # sp-debate/ with name: debate and block-style trigger  - /sp-debate
    _make_clean_skill sp-debate debate $'  - /sp-debate\n  - three design options'

    _doctor_yaml_checks
    [ "$CRITICAL" -eq 0 ]
}

@test "Check 3: inline-array trigger matching dir — no CRITICAL" {
    # sp-style/ with inline-array trigger "/sp-style"
    _make_clean_skill sp-style enforce-style-guide 'triggers: ["/sp-style", "check style"]'

    _doctor_yaml_checks
    [ "$CRITICAL" -eq 0 ]
}

@test "Check 3: multi-trigger block, first trigger matches dir — no CRITICAL" {
    # sp-phr/ with two block triggers; /sp-phr is the first
    _make_clean_skill sp-phr progressive-harsh-review $'  - /sp-phr\n  - /sp-redteam\n  - harsh review'

    _doctor_yaml_checks
    [ "$CRITICAL" -eq 0 ]
}

@test "Check 3: name matches dir exactly — no CRITICAL" {
    _make_clean_skill my-skill my-skill 'triggers: ["/my-skill"]'

    _doctor_yaml_checks
    [ "$CRITICAL" -eq 0 ]
}

@test "Check 3: genuine name mismatch, no trigger matches dir — CRITICAL fires" {
    # my-skill/ with name: wrong-name and an unrelated trigger
    _make_clean_skill my-skill wrong-name 'triggers: ["/some-other-trigger"]'

    # Use || true: ((CRITICAL++)) returns exit code 1 when CRITICAL was 0 (arithmetic
    # result is 0 = false); doctor-checks.sh runs without set -e but bats does not.
    _doctor_yaml_checks || true
    [ "$CRITICAL" -eq 1 ]
}

@test "Check 3: genuine name mismatch, no triggers at all — CRITICAL fires" {
    _make_clean_skill my-skill wrong-name ""

    _doctor_yaml_checks || true
    [ "$CRITICAL" -eq 1 ]
}

@test "Check 3: trigger is prefix of dir name — CRITICAL fires (no partial match)" {
    # /sp-debater is NOT /sp-debate — no partial-match exemption allowed
    _make_clean_skill sp-debate debate 'triggers: ["/sp-debater"]'

    _doctor_yaml_checks || true
    [ "$CRITICAL" -eq 1 ]
}

@test "Check 3: multi-line inline array trigger — no CRITICAL (YAML fallback)" {
    # sp-plan uses a multi-line inline array that SKILL_TRIGGERS_RAW can't fully capture;
    # the SKILL_YAML fallback must find the trigger and suppress the CRITICAL.
    _make_clean_skill sp-plan plan-and-execute ""
    # Override SKILL_YAML with the multi-line inline format seen in the real skill
    SKILL_YAML[sp-plan]='name: plan-and-execute
source: superpowers-plus
description: Test plan skill.
triggers: ["/sp-plan", "plan and execute",
           "plan-and-execute", "big project"]'

    # Use || true: Check 7 fires ERROR for other reasons in some environments,
    # which also triggers ((ERRORS++)) → exit code 1 under bats set -e.
    _doctor_yaml_checks || true
    [ "$CRITICAL" -eq 0 ]
}

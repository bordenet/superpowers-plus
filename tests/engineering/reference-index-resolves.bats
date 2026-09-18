#!/usr/bin/env bats
# Every "Reference index" row in every split skill must resolve to a real
# heading in that skill's reference.md.
#
# WHY THIS EXISTS: the index is a promise the skill makes to the model -- "in
# situation X, load section Y". tools/section-loader.sh matches headings
# EXACTLY, so a renamed or relocated section turns that promise into `exit 1`
# at the precise moment the model needs help. Enforcement was prose only
# ("verify the routing table rows match the reference headings" in
# kernel-split/skill.md), and it broke three separate times in one day:
#
#   1. a kernel split renamed "## Failure Modes" to "## Remediation and
#      failure modes" and left the index pointing at the old name;
#   2. the fix renamed the index row to match -- and then a later change moved
#      that section OUT of reference.md into the resident kernel, so the row
#      pointed at a section reference.md no longer had;
#   3. neither was caught by any test.
#
# This walks the real files with the real loader. It is the mechanical backstop
# for an invariant that prose could not hold.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd -P)"
  LOADER="$REPO_ROOT/tools/section-loader.sh"
}

# Emit the second column of every row in the "## Reference index" table,
# stopping at the next heading. Skips the header and separator rows.
_index_targets() {
  awk '
    /^## Reference index/ { in_tbl = 1; seen_sep = 0; next }
    in_tbl && /^## / { exit }
    # Everything above the |---|---| separator is the header row, whose second
    # column is a column title ("Reference section", "Section to load",
    # "Read this reference section"), not a section name.
    in_tbl && /^\|[ \t]*-+/ { seen_sep = 1; next }
    in_tbl && !seen_sep { next }
    in_tbl && /^\|/ {
      n = split($0, cell, "|")
      if (n < 3) next
      target = cell[3]
      gsub(/^[ \t]+|[ \t]+$/, "", target)
      # Some indexes wrap the section name in backticks and append a note,
      # e.g. "`Required Output Format` (also load `Evidence Schema`)". The
      # section name is the first backticked token; otherwise the whole cell.
      if (target ~ /`/) {
        if (match(target, /`[^`]+`/)) {
          target = substr(target, RSTART + 1, RLENGTH - 2)
        }
      }
      gsub(/^[ \t]+|[ \t]+$/, "", target)
      if (target == "" || target == "Reference section" || target == "Section") next
      if (target ~ /^-+$/) next
      print target
    }
  ' "$1"
}

@test "every Reference index row resolves to a real reference.md heading" {
  local failures=0 checked=0
  local skill ref target
  while IFS= read -r skill; do
    ref="$(dirname "$skill")/reference.md"
    [ -f "$ref" ] || continue
    while IFS= read -r target; do
      [ -z "$target" ] && continue
      checked=$((checked + 1))
      if ! bash "$LOADER" "$ref" "$target" >/dev/null 2>&1; then
        echo "BROKEN: ${skill#"$REPO_ROOT"/} -> '$target' not a heading in reference.md" >&2
        failures=$((failures + 1))
      fi
    done < <(_index_targets "$skill")
  done < <(find "$REPO_ROOT/skills" -name 'skill.md')

  echo "checked $checked Reference index row(s)" >&2
  [ "$checked" -gt 0 ]
  [ "$failures" -eq 0 ]
}

@test "the index check can actually fail (guard against a vacuous test)" {
  # A test that cannot fail is not a test. Build a skill whose index names a
  # section its reference.md does not have, and prove the loader rejects it.
  local d="$BATS_TEST_TMPDIR/fake"
  mkdir -p "$d"
  printf '## Reference index\n\n| Need | Reference section |\n|---|---|\n| something | Absent Section |\n' \
    > "$d/skill.md"
  printf '## Present Section\n\nbody\n' > "$d/reference.md"

  run bash "$LOADER" "$d/reference.md" "Absent Section"
  [ "$status" -ne 0 ]

  run bash "$LOADER" "$d/reference.md" "Present Section"
  [ "$status" -eq 0 ]

  # And the extractor must actually find the row it is meant to police.
  run _index_targets "$d/skill.md"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Absent Section"* ]]
}

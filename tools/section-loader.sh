#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Script: section-loader.sh
# PURPOSE: Print exactly one heading section from a Markdown reference file.
#          Extracted from the gitlab-cli inline section-loader pattern so that
#          any kernel/reference split can share the same extraction logic.
#
# Usage:
#   section-loader.sh <reference_file> <heading_title>
#
#   <reference_file>   Path to the reference.md file to extract from.
#   <heading_title>    Exact heading text WITHOUT leading # chars and space.
#                      E.g., "Authenticate details" not "## Authenticate details"
#
# Exit codes:
#   0  Success — section found, content printed to stdout
#   1  Section not found — heading_title not present in reference_file
#   2  Usage error — wrong number of arguments, file unreadable, etc.
#
# Behaviour:
#   - Finds the FIRST heading (any level) whose text matches heading_title exactly
#   - Prints from that heading line through content, stopping at the next heading
#     with the SAME or FEWER leading '#' characters (equal or higher level)
#   - Never prints the whole file on a miss — exit 1 on not found
#
# Why this exists:
#   gitlab-cli/skill.md previously inlined this awk pattern between
#   <!-- gitlab-cli-reference-loader:start/end --> markers. spc-kernel-split
#   extracts it as a shared tool so all kernel/reference pairs share one
#   implementation instead of duplicating the pattern per-skill.
# -----------------------------------------------------------------------------

set -euo pipefail

# ---------------------------------------------------------------------------
# Usage guard
# ---------------------------------------------------------------------------
if [ "$#" -ne 2 ]; then
  printf 'usage: %s <reference_file> <heading_title>\n' "$(basename "$0")" >&2
  exit 2
fi

reference_file="$1"
heading_title="$2"

if [ ! -r "$reference_file" ]; then
  printf 'section-loader: file not readable: %s\n' "$reference_file" >&2
  exit 2
fi

# ---------------------------------------------------------------------------
# Extract the section via awk
# Uses /^#+ / (one or more '#') rather than /^#{1,6} / because interval
# expressions ({n,m}) are not required by all POSIX awk implementations
# (mawk < 1.3.4 and busybox awk silently fail on them).
# ---------------------------------------------------------------------------
# heading_level(line):  count leading '#' characters
# heading_text(line):   text after the leading '#...' + one space
# We find the first heading whose text == heading_title, record its level,
# and print until we see a heading at the same or higher level (fewer #s).
section_output="$(awk -v target="$heading_title" '
function heading_level(line,    i) {
  i = 0
  while (substr(line, i + 1, 1) == "#") i++
  return i
}
function heading_text(line,    lv) {
  lv = heading_level(line)
  return substr(line, lv + 2)
}
BEGIN { printing = 0; level = 0 }
{
  if (!printing && /^#+ /) {
    if (heading_text($0) == target) {
      printing = 1
      level = heading_level($0)
      print
      next
    }
  }
  if (printing && /^#+ /) {
    if (heading_level($0) <= level) { exit }
  }
  if (printing) print
}
' "$reference_file")"

if [ -z "$section_output" ]; then
  printf 'section-loader: heading not found: %s\n' "$heading_title" >&2
  exit 1
fi

printf '%s\n' "$section_output"

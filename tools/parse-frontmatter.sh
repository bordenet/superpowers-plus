#!/usr/bin/env bash
# parse-frontmatter.sh — Extract YAML frontmatter fields from skill.md files
#
# Usage (as a sourced library):
#   source "$(dirname "$0")/parse-frontmatter.sh"
#   value=$(frontmatter_field "path/to/skill.md" "name")
#   desc=$(frontmatter_field "path/to/skill.md" "description")
#
# Usage (standalone):
#   ./parse-frontmatter.sh path/to/skill.md name
#   ./parse-frontmatter.sh path/to/skill.md description
#   ./parse-frontmatter.sh path/to/skill.md       # dumps all frontmatter

set -euo pipefail

# Extract the raw YAML frontmatter block (between first and second ---)
frontmatter_block() {
  local file="$1"
  if [[ ! -f "$file" ]]; then
    echo "" && return 1
  fi
  awk 'NR==1 && /^---$/{found++; next} /^---$/{exit} found{print}' "$file"
}

# Extract a single field value from YAML frontmatter.
# Handles both quoted and unquoted values. For arrays (triggers), returns the raw line.
# Args: $1 = file path, $2 = field name
frontmatter_field() {
  local file="$1"
  local field="$2"
  local block
  block=$(frontmatter_block "$file")
  if [[ -z "$block" ]]; then
    return 1
  fi
  echo "$block" | grep "^${field}:" | sed "s/^${field}:[[:space:]]*//" | sed 's/^"//;s/"$//' | sed "s/^'//;s/'$//"
}

# Check if frontmatter has valid delimiters (opening and closing ---)
frontmatter_valid() {
  local file="$1"
  local first_line
  first_line=$(head -1 "$file" 2>/dev/null)
  if [[ "$first_line" != "---" ]]; then
    return 1
  fi
  local delimiter_count
  delimiter_count=$(head -30 "$file" | grep -c "^---$" || true)
  if [[ "$delimiter_count" -lt 2 ]]; then
    return 1
  fi
  return 0
}

# Standalone mode
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  if [[ $# -lt 1 ]]; then
    echo "Usage: $0 SKILL_FILE [FIELD_NAME]" >&2
    echo "  If FIELD_NAME omitted, prints entire frontmatter block" >&2
    exit 1
  fi
  if [[ $# -eq 1 ]]; then
    frontmatter_block "$1"
  else
    frontmatter_field "$1" "$2"
  fi
fi

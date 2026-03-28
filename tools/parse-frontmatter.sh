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
# Handles quoted/unquoted scalars, inline arrays, and multiline YAML lists.
# Args: $1 = file path, $2 = field name
trim_whitespace() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

strip_matching_quotes() {
  local value
  local first_char
  local last_char
  value="$(trim_whitespace "$1")"
  if [[ ${#value} -ge 2 ]]; then
    first_char="${value:0:1}"
    last_char="${value: -1}"
    if [[ ( "$first_char" == '"' && "$last_char" == '"' ) || ( "$first_char" == "'" && "$last_char" == "'" ) ]]; then
      value="${value:1:${#value}-2}"
    fi
  fi
  printf '%s' "$value"
}

frontmatter_field() {
  local file="$1"
  local field="$2"
  local block
  local line
  local in_list="false"
  block=$(frontmatter_block "$file")
  if [[ -z "$block" ]]; then
    return 1
  fi

  while IFS= read -r line; do
    if [[ "$in_list" == "true" ]]; then
      if [[ "$line" =~ ^[[:space:]]*-[[:space:]]*(.*)$ ]]; then
        strip_matching_quotes "${BASH_REMATCH[1]}"
        printf '\n'
        continue
      fi
      [[ -z "$(trim_whitespace "$line")" ]] && continue
      break
    fi

    if [[ "$line" =~ ^${field}:[[:space:]]*\[(.*)\][[:space:]]*$ ]]; then
      local items="${BASH_REMATCH[1]}"
      local item
      IFS=',' read -r -a inline_items <<< "$items"
      for item in "${inline_items[@]}"; do
        item="$(strip_matching_quotes "$item")"
        [[ -n "$item" ]] && printf '%s\n' "$item"
      done
      return 0
    fi

    if [[ "$line" =~ ^${field}:[[:space:]]*$ ]]; then
      in_list="true"
      continue
    fi

    if [[ "$line" =~ ^${field}:[[:space:]]*(.*)$ ]]; then
      strip_matching_quotes "${BASH_REMATCH[1]}"
      printf '\n'
      return 0
    fi
  done <<< "$block"

  [[ "$in_list" == "true" ]] && return 0
  return 1
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

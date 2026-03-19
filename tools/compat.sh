#!/usr/bin/env bash
# tools/compat.sh — Cross-platform compatibility shims
#
# SOURCE this file; do not execute directly.
# Provides portable wrappers for commands that differ between macOS and Linux/WSL.
#
# Usage:
#   source "$(dirname "${BASH_SOURCE[0]}")/compat.sh"
#   sed_inplace 's/old/new/' file.txt
#   epoch=$(date_to_epoch "2026-03-19")
#
# Functions:
#   require_bash4    — Exit with helpful message if bash < 4
#   sed_inplace      — Portable sed -i (macOS vs GNU)
#   date_to_epoch    — Convert YYYY-MM-DD to Unix epoch
#
# Supported platforms: macOS, Linux, WSL
# shellcheck disable=SC2034  # Variables may be used by sourcing scripts

# --- Bash Version Guard ---

require_bash4() {
  if ((BASH_VERSINFO[0] < 4)); then
    echo "ERROR: This script requires bash 4+. You have bash ${BASH_VERSION}" >&2
    echo "  macOS fix: brew install bash" >&2
    echo "  Then ensure /opt/homebrew/bin or /usr/local/bin is in PATH" >&2
    exit 1
  fi
}

# --- Portable sed -i ---
# macOS BSD sed requires -i '' (empty backup extension)
# GNU sed requires -i (no argument) or -i'' (no space)

sed_inplace() {
  if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i '' "$@"
  else
    sed -i "$@"
  fi
}

# --- Portable Date Parsing ---
# Convert YYYY-MM-DD string to Unix epoch seconds.
# Returns 0 on parse failure.

date_to_epoch() {
  local datestr="$1"
  if [[ "$OSTYPE" == "darwin"* ]]; then
    date -j -f "%Y-%m-%d" "$datestr" "+%s" 2>/dev/null || echo 0
  else
    date -d "$datestr" "+%s" 2>/dev/null || echo 0
  fi
}

# --- Help for this file ---

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  cat << 'HELP'
tools/compat.sh — Cross-platform compatibility shims

SOURCE this file; do not execute directly.

  source "$(dirname "${BASH_SOURCE[0]}")/compat.sh"

Functions:
  require_bash4    Exit with message if bash < 4
  sed_inplace      Portable sed -i (macOS vs GNU)
  date_to_epoch    Convert YYYY-MM-DD → Unix epoch

Example:
  source tools/compat.sh
  require_bash4
  sed_inplace 's/foo/bar/' myfile.txt
  epoch=$(date_to_epoch "2026-01-15")
HELP
  exit 0
fi

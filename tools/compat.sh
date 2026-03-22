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

# Usage: require_bash4 "$@"
# Pass the calling script's "$@" so re-exec preserves original arguments.
require_bash4() {
  if ((BASH_VERSINFO[0] < 4)); then
    if [[ "$OSTYPE" == "darwin"* ]]; then
      if command -v brew &>/dev/null; then
        echo "INFO: bash ${BASH_VERSION} is too old (need 4+). Installing via Homebrew..." >&2
        brew install bash
        # Find the brew-installed bash and re-exec the CALLING script under it
        local brew_bash=""
        for candidate in /opt/homebrew/bin/bash /usr/local/bin/bash; do
          if [[ -x "$candidate" ]] && "$candidate" -c '((BASH_VERSINFO[0] >= 4))' 2>/dev/null; then
            brew_bash="$candidate"
            break
          fi
        done
        if [[ -n "$brew_bash" ]]; then
          echo "INFO: Re-executing under $brew_bash" >&2
          exec "$brew_bash" "${BASH_SOURCE[-1]}" "$@"
        else
          echo "ERROR: brew install bash succeeded but could not find bash 4+ binary" >&2
          exit 1
        fi
      else
        echo "ERROR: This script requires bash 4+. You have bash ${BASH_VERSION}" >&2
        echo "  macOS fix: brew install bash" >&2
        echo "  Install Homebrew first: https://brew.sh" >&2
        exit 1
      fi
    else
      echo "ERROR: This script requires bash 4+. You have bash ${BASH_VERSION}" >&2
      echo "  Install bash 4+ via your package manager (e.g., apt install bash)" >&2
      exit 1
    fi
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

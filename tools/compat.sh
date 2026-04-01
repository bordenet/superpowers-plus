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
#   sha256_hash      — Portable SHA-256 (shasum/sha256sum/openssl)
#   sha256_hash_stdin — Pipe-friendly variant of sha256_hash
#   set_immutable    — Portable chflags uchg / chattr +i
#   clear_immutable  — Portable chflags nouchg / chattr -i
#   check_immutable  — Returns 0=immutable, 1=not, 2=unknown
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
        local brew_bash="" caller_script
        for candidate in /opt/homebrew/bin/bash /usr/local/bin/bash; do
          if [[ -x "$candidate" ]] && "$candidate" -c '((BASH_VERSINFO[0] >= 4))' 2>/dev/null; then
            brew_bash="$candidate"
            break
          fi
        done
        if [[ -n "$brew_bash" ]]; then
          caller_script="${BASH_SOURCE[1]:-$0}"
          echo "INFO: Re-executing under $brew_bash" >&2
          exec "$brew_bash" "$caller_script" "$@"
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

# --- Portable SHA-256 Hash ---
# shasum is macOS/Perl; sha256sum is GNU coreutils (Linux).
# Returns hex digest only (no filename).

sha256_hash() {
  if command -v shasum &>/dev/null; then
    shasum -a 256 "$@" | cut -d' ' -f1
  elif command -v sha256sum &>/dev/null; then
    sha256sum "$@" | cut -d' ' -f1
  else
    # Last resort: openssl (available on most systems)
    openssl dgst -sha256 "$@" 2>/dev/null | sed 's/.*= //'
  fi
}

# Pipe-friendly variant: reads from stdin
sha256_hash_stdin() {
  if command -v shasum &>/dev/null; then
    shasum -a 256 | cut -d' ' -f1
  elif command -v sha256sum &>/dev/null; then
    sha256sum | cut -d' ' -f1
  else
    openssl dgst -sha256 2>/dev/null | sed 's/.*= //'
  fi
}

# --- Portable Immutable Flag ---
# macOS: chflags uchg/nouchg
# Linux ext4: chattr +i/-i (requires root or CAP_LINUX_IMMUTABLE)
# WSL+NTFS: chattr silently fails; detect and warn

set_immutable() {
  local file="$1"
  if [[ "$OSTYPE" == "darwin"* ]]; then
    chflags uchg "$file" 2>/dev/null
  elif _is_wsl_ntfs "$file"; then
    return 1  # Can't set immutable on NTFS
  else
    chattr +i "$file" 2>/dev/null || return 1
  fi
}

clear_immutable() {
  local file="$1"
  if [[ "$OSTYPE" == "darwin"* ]]; then
    chflags nouchg "$file" 2>/dev/null
  elif _is_wsl_ntfs "$file"; then
    return 0  # Nothing to clear on NTFS
  else
    chattr -i "$file" 2>/dev/null || return 0
  fi
}

check_immutable() {
  # Returns 0 if immutable, 1 if not, 2 if can't determine
  local file="$1"
  if [[ "$OSTYPE" == "darwin"* ]]; then
    local flags
    flags=$(stat -f "%Sf" "$file" 2>/dev/null || echo "")
    [[ "$flags" == *"uchg"* ]] && return 0
    return 1
  elif _is_wsl_ntfs "$file"; then
    return 2  # Can't determine on NTFS
  elif command -v lsattr &>/dev/null; then
    # lsattr output varies across implementations:
    #   GNU coreutils: "----i---------e---- filename"  (20-char fixed field)
    #   BusyBox:       "----i--------e-- filename"     (shorter, variable)
    # Instead of checking a fixed position, extract the attribute field
    # (first whitespace-delimited token) and search for 'i' in it.
    # The attribute field only contains flag letters and dashes, so
    # matching 'i' anywhere in it reliably detects immutable.
    local attr_field
    attr_field=$(lsattr "$file" 2>/dev/null | awk '{print $1}')
    if [[ -z "$attr_field" ]]; then
      return 2
    fi
    # Attribute field is only [a-zA-Z-] characters; 'i' = immutable
    if [[ "$attr_field" == *i* ]]; then
      return 0
    fi
    return 1
  else
    return 2  # lsattr not available
  fi
}

# Internal: detect WSL + NTFS/drvfs mount
_is_wsl_ntfs() {
  local file="$1"
  # Not WSL at all — check /proc/version for Microsoft kernel signature
  if [[ ! -f /proc/version ]]; then
    return 1
  fi
  if ! grep -Eqi 'microsoft|wsl' /proc/version 2>/dev/null; then
    return 1
  fi
  # Resolve to absolute path
  local abs_path
  abs_path=$(realpath "$file" 2>/dev/null || readlink -f "$file" 2>/dev/null || echo "$file")
  # Standard Windows drive mounts: /mnt/c, /mnt/d, etc.
  [[ "$abs_path" == /mnt/[a-z]/* ]] && return 0
  # Check if the mount is drvfs (Windows filesystem) via findmnt
  if command -v findmnt &>/dev/null; then
    local fstype
    fstype=$(findmnt -n -o FSTYPE --target "$abs_path" 2>/dev/null || echo "")
    [[ "$fstype" == "drvfs" || "$fstype" == "9p" ]] && return 0
  fi
  return 1
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

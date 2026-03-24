#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# lib/install/logging.sh
# PURPOSE: Logging functions, color setup, and utility helpers for the installer.
# SOURCED BY: install.sh — do not run directly.
# GLOBALS READ: VERBOSE, FORCE_COLOR
# GLOBALS SET: RED, GREEN, YELLOW, BLUE, NC
# -----------------------------------------------------------------------------

# Guard: this module must be sourced by install.sh, not run directly.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "ERROR: This is a library module. Run install.sh instead." >&2
    exit 1
fi

# Colors for output (disabled if not a terminal, unless FORCE_COLOR=1)
# FORCE_COLOR=1 allows parent scripts (e.g., adopter installers) to preserve colors
# when calling this script through a pipe/tee.
if [[ -t 1 ]] || [[ "${FORCE_COLOR:-}" == "1" ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    BLUE='\033[0;34m'
    NC='\033[0m' # No Color
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    NC=''
fi

# --- Logging functions ---

log_info() {
    printf '%b\n' "${BLUE}[INFO]${NC} $1"
}

log_success() {
    printf '%b\n' "${GREEN}[OK]${NC} $1"
}

log_warn() {
    printf '%b\n' "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    printf '%b\n' "${RED}[ERROR]${NC} $1"
}

log_verbose() {
    if [[ "$VERBOSE" == "true" ]]; then
        printf '%b\n' "${BLUE}[DEBUG]${NC} $1"
    fi
}

# Error handler — log and exit
error_exit() {
    log_error "$1"
    exit 1
}

# Create directory with error handling
create_dir() {
    local dir="$1"
    if [[ ! -d "$dir" ]]; then
        log_verbose "Creating directory: $dir"
        mkdir -p "$dir" || error_exit "Failed to create directory: $dir"
    fi
}

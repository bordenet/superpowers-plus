#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# lib/install/logging.sh
# PURPOSE: Logging functions, color setup, and utility helpers for the installer.
# SOURCED BY: install.sh — do not run directly.
# GLOBALS READ: VERBOSE, FORCE_COLOR
# GLOBALS SET: RED, GREEN, YELLOW, BLUE, NC
# -----------------------------------------------------------------------------

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
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_verbose() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "${BLUE}[DEBUG]${NC} $1"
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

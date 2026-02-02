#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Script: upgrade.sh
# PURPOSE: Upgrade obra/superpowers to the latest version
# USAGE: ./upgrade.sh [-h|--help] [-v|--verbose] [--force]
# PLATFORM: macOS, Linux
# -----------------------------------------------------------------------------
set -euo pipefail

VERSION="1.0.0"

# Colors for output (disabled if not a terminal)
if [[ -t 1 ]]; then
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

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CODEX_DIR="${HOME}/.codex"
SUPERPOWERS_DIR="${CODEX_DIR}/superpowers"
SUPERPOWERS_REPO="https://github.com/obra/superpowers.git"

# Options
FORCE=false
VERBOSE=false

# --- Help ---
show_help() {
    cat << 'EOF'
NAME
    upgrade.sh - Upgrade obra/superpowers to the latest version

SYNOPSIS
    upgrade.sh [OPTIONS]

DESCRIPTION
    Pulls the latest updates from obra/superpowers and reinstalls personal
    skills. Use --force to reset local changes before upgrading.

OPTIONS
    -h, --help
        Display this help message and exit

    -v, --verbose
        Show detailed progress information

    --force
        Reset any local changes before upgrading (git reset --hard)

    --version
        Display version information and exit

EXAMPLES
    # Upgrade to latest
    ./upgrade.sh

    # Upgrade with verbose output
    ./upgrade.sh --verbose

    # Force upgrade, discarding local changes
    ./upgrade.sh --force

AUTHOR
    Matt J Bordenet

SEE ALSO
    ./install.sh - Initial installation
    https://github.com/obra/superpowers
EOF
    exit 0
}

# --- Argument Parsing ---
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help) show_help ;;
        -v|--verbose) VERBOSE=true; shift ;;
        --force) FORCE=true; shift ;;
        --version) echo "upgrade.sh version $VERSION"; exit 0 ;;
        *)
            echo -e "${RED}Error: Unknown option $1${NC}" >&2
            echo "Use -h or --help for usage information" >&2
            exit 1
            ;;
    esac
done

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_verbose() { [[ "$VERBOSE" == "true" ]] && echo -e "${BLUE}[DEBUG]${NC} $1"; }

error_exit() { log_error "$1"; exit 1; }

# Check if superpowers is installed
check_installed() {
    if [[ ! -d "$SUPERPOWERS_DIR" ]]; then
        error_exit "superpowers not installed. Run ./install.sh first."
    fi
    if [[ ! -d "$SUPERPOWERS_DIR/.git" ]]; then
        error_exit "superpowers directory is not a git repository. Run ./install.sh --force to reinstall."
    fi
}

# Get current version info
get_version_info() {
    local current_sha before_sha
    current_sha=$(cd "$SUPERPOWERS_DIR" && git rev-parse --short HEAD)
    echo "$current_sha"
}

# Upgrade superpowers
upgrade_superpowers() {
    log_info "Upgrading obra/superpowers..."

    cd "$SUPERPOWERS_DIR" || error_exit "Failed to change to superpowers directory"

    local before_sha
    before_sha=$(git rev-parse --short HEAD)
    log_verbose "Current version: $before_sha"

    # Force reset if requested
    if [[ "$FORCE" == "true" ]]; then
        log_info "Resetting local changes..."
        git reset --hard HEAD || error_exit "Failed to reset local changes"
        git clean -fd || error_exit "Failed to clean untracked files"
    fi

    # Fetch and pull
    log_verbose "Fetching from origin..."
    if ! git fetch origin 2>&1; then
        error_exit "Failed to fetch from origin"
    fi

    log_verbose "Pulling latest changes..."
    if ! git pull --ff-only origin main 2>&1; then
        log_warn "Fast-forward pull failed. You may have local changes."
        log_warn "Run with --force to discard local changes and upgrade."
        exit 1
    fi

    local after_sha
    after_sha=$(git rev-parse --short HEAD)

    if [[ "$before_sha" == "$after_sha" ]]; then
        log_success "Already up to date ($after_sha)"
    else
        log_success "Upgraded: $before_sha → $after_sha"
    fi
}

# Main
main() {
    echo ""
    log_info "superpowers upgrade"
    echo ""

    check_installed
    upgrade_superpowers

    # Reinstall personal skills
    log_info "Reinstalling personal skills..."
    "$SCRIPT_DIR/install.sh" --verbose 2>&1 | grep -E '^\[' || true

    echo ""
    log_success "Upgrade complete"
    echo ""
}

main


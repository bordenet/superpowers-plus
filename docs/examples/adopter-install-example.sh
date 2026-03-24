#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Adopter Installer - Designed for non-technical users
# 
# USAGE: ./install.sh
# PLATFORM: Ubuntu 20.04+, Debian 11+, WSL2
# -----------------------------------------------------------------------------
set -euo pipefail

# --- Configuration ---
SUPERPOWERS_PLUS_REPO="https://github.com/bordenet/superpowers-plus.git"
SUPERPOWERS_PLUS_DIR="$HOME/.codex/superpowers-plus"
LOG_FILE="$HOME/.my-org-skills_install.log"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MIN_NODE_VERSION=18

# --- Colors (disabled if not a terminal) ---
if [[ -t 1 ]]; then
    RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
else
    RED=''; GREEN=''; YELLOW=''; BLUE=''; NC=''
fi

# --- Logging ---
exec > >(tee -a "$LOG_FILE") 2>&1
echo "=== my-org-skills install started at $(date) ===" >> "$LOG_FILE"

info()    { printf '%b\n' "${BLUE}▶${NC} $1"; }
success() { printf '%b\n' "${GREEN}✓${NC} $1"; }
warn()    { printf '%b\n' "${YELLOW}⚠${NC} $1"; }
fail()    { 
    printf '%b\n' "${RED}✗ ERROR:${NC} $1" >&2
    echo ""
    printf '%b\n' "${YELLOW}Need help?${NC} Send this file to IT: $LOG_FILE"
    exit 1
}

# --- Sudo check (ask once upfront) ---
check_sudo() {
    if [[ $EUID -eq 0 ]]; then
        fail "Do not run this script as root. Run as your normal user."
    fi
    
    info "This installer may need to install system packages (git, nodejs)."
    echo "    You may be prompted for your password once."
    echo ""
    
    # Validate sudo works (will prompt if needed)
    if ! sudo -v 2>/dev/null; then
        fail "sudo access required. Contact IT if you don't have sudo privileges."
    fi
    
    # Keep sudo alive for the duration of the script
    while true; do sudo -n true; sleep 50; kill -0 "$$" || exit; done 2>/dev/null &
}

# --- Network check ---
check_network() {
    info "Checking network connectivity..."
    if ! curl -fsSL --connect-timeout 5 https://github.com > /dev/null 2>&1; then
        fail "Cannot reach GitHub. Check your internet connection or VPN."
    fi
    success "Network OK"
}

# --- Install system dependencies ---
install_dependencies() {
    local need_update=false
    
    # Check git
    if ! command -v git &>/dev/null; then
        info "Installing git..."
        need_update=true
    fi
    
    # Check node
    if ! command -v node &>/dev/null; then
        info "Installing Node.js..."
        need_update=true
    else
        # Check node version
        local node_version
        node_version=$(node -v | sed 's/v//' | cut -d. -f1)
        if [[ "$node_version" -lt "$MIN_NODE_VERSION" ]]; then
            warn "Node.js $node_version is too old (need $MIN_NODE_VERSION+). Upgrading..."
            need_update=true
        fi
    fi
    
    if [[ "$need_update" == "true" ]]; then
        sudo apt-get update -qq
        sudo apt-get install -y -qq git curl
        
        # Install Node.js via NodeSource (gets recent version)
        if ! command -v node &>/dev/null || [[ "$(node -v | sed 's/v//' | cut -d. -f1)" -lt "$MIN_NODE_VERSION" ]]; then
            curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
            sudo apt-get install -y -qq nodejs
        fi
    fi
    
    # Final verification
    command -v git &>/dev/null || fail "git installation failed"
    command -v node &>/dev/null || fail "Node.js installation failed"
    
    success "Dependencies OK (git $(git --version | cut -d' ' -f3), node $(node -v))"
}

# --- Install superpowers-plus ---
install_superpowers_plus() {
    info "Installing superpowers-plus skill framework..."
    
    if [[ -d "$SUPERPOWERS_PLUS_DIR/.git" ]]; then
        info "Updating existing installation..."
        if ! (cd "$SUPERPOWERS_PLUS_DIR" && git fetch origin && git reset --hard origin/main) 2>&1; then
            warn "Update failed, reinstalling fresh..."
            rm -rf "${SUPERPOWERS_PLUS_DIR:?}"
        fi
    fi
    
    if [[ ! -d "$SUPERPOWERS_PLUS_DIR" ]]; then
        git clone --depth 1 "$SUPERPOWERS_PLUS_REPO" "$SUPERPOWERS_PLUS_DIR" 2>&1 || \
            fail "Failed to clone superpowers-plus. Check network/firewall."
    fi
    
    # Run the superpowers-plus installer (non-interactive)
    if ! "$SUPERPOWERS_PLUS_DIR/install.sh" --yes 2>&1; then
        fail "superpowers-plus installation failed. See log: $LOG_FILE"
    fi
    
    success "superpowers-plus installed"
}

# --- Install my-org-skills extensions ---
install_my-org-skills() {
    info "Installing my-org-skills skills and rules..."
    
    # Install skills
    if [[ -d "$SCRIPT_DIR/skills" ]]; then
        for skill_dir in "$SCRIPT_DIR/skills/"*/; do
            [[ -d "$skill_dir" ]] || continue
            local skill_name
            skill_name=$(basename "$skill_dir")
            rm -rf "${HOME:?}/.codex/skills/${skill_name:?}" 2>/dev/null || true
            cp -r "$skill_dir" "$HOME/.codex/skills/$skill_name"
        done
    fi
    
    # Install rules
    if [[ -d "$SCRIPT_DIR/rules" ]]; then
        mkdir -p "$HOME/.augment/rules"
        cp "$SCRIPT_DIR/rules/"*.md "$HOME/.augment/rules/" 2>/dev/null || true
    fi
    
    success "my-org-skills extensions installed"
}

# --- Verify installation ---
verify_installation() {
    info "Verifying installation..."
    
    local errors=0
    
    [[ -f "$HOME/.codex/superpowers-augment/superpowers-augment.js" ]] || { warn "Adapter missing"; ((errors++)); }
    [[ -d "$HOME/.codex/superpowers/skills" ]] || { warn "Superpowers skills missing"; ((errors++)); }
    
    if [[ $errors -gt 0 ]]; then
        fail "Installation verification failed ($errors errors)"
    fi
    
    # Test that it actually works
    if ! node "$HOME/.codex/superpowers-augment/superpowers-augment.js" find-skills &>/dev/null; then
        fail "Skill loader test failed"
    fi
    
    success "Installation verified"
}

# --- Main ---
main() {
    echo ""
    echo "╔══════════════════════════════════════════════╗"
    echo "║     Adopter Installer                  ║"
    echo "╚══════════════════════════════════════════════╝"
    echo ""
    
    check_sudo
    check_network
    install_dependencies
    install_superpowers_plus
    install_my-org-skills
    verify_installation
    
    echo ""
    echo "╔══════════════════════════════════════════════╗"
    echo "║  ${GREEN}✓${NC} Installation Complete!                    ║"
    echo "╚══════════════════════════════════════════════╝"
    echo ""
    echo "Next steps:"
    echo "  1. Open Augment Code (or restart if already open)"
    echo "  2. Skills will auto-load in new conversations"
    echo ""
    echo "Log file: $LOG_FILE"
    echo ""
}

main "$@"

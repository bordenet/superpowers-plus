#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Script: install.sh
# PURPOSE: Install superpowers-plus skills with platform detection, dependency
#          management, and multi-target deployment. Clones/updates obra/superpowers
#          as a prerequisite, validates environment variables, and deploys skills
#          to ~/.codex/skills/, ~/.claude/skills/, and ~/.augment/skills/.
# USAGE: ./install.sh [options]
#        -h, --help      Show help message
#        -v, --verbose   Enable verbose output
#        -y, --yes       Auto-accept prompts (non-interactive mode)
#        --force         Overwrite existing skills without prompting
#        --upgrade       Pull latest changes before installing
#        --version       Show version number
# PLATFORM: macOS (Intel/Apple Silicon), Linux (Debian/Ubuntu, RHEL/Fedora, Arch), WSL
# VERSION: 2.5.1
# ARCHITECTURE: This file is a thin orchestrator. Implementation lives in
#               lib/install/*.sh modules, sourced in dependency order below.
# -----------------------------------------------------------------------------
set -euo pipefail

VERSION="2.5.1"

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CODEX_DIR="${HOME}/.codex"
SKILLS_DIR="${CODEX_DIR}/skills"
SUPERPOWERS_DIR="${CODEX_DIR}/superpowers"
SUPERPOWERS_REPO="https://github.com/obra/superpowers.git"

# Platform-specific skill deployment paths
# Claude Code: Native Skill tool reads from ~/.claude/skills/
CLAUDE_SKILLS_DIR="${HOME}/.claude/skills"
# Augment Agent: superpowers-augment.js reads from ~/.codex/skills/ (SKILLS_DIR above)
#                Also deploy to ~/.augment/skills/ for potential future use
AUGMENT_SKILLS_DIR="${HOME}/.augment/skills"

# Options (set before sourcing modules so they can read these)
FORCE=false
VERBOSE=false
UPGRADE=false
YES=false

# Auto-detect non-interactive context (piped input, curl | bash, etc.)
if ! [[ -t 0 ]]; then
    YES=true
fi

# --- Source modules in dependency order ---
INSTALL_LIB_DIR="${SCRIPT_DIR}/lib/install"

# shellcheck source=lib/install/logging.sh
source "${INSTALL_LIB_DIR}/logging.sh"      # Colors, log_*, error_exit, create_dir
# shellcheck source=lib/install/platform.sh
source "${INSTALL_LIB_DIR}/platform.sh"      # detect_platform, detect_linux_distro, WSL checks
# shellcheck source=lib/install/deps.sh
source "${INSTALL_LIB_DIR}/deps.sh"          # check_dependencies, check_node_version
# shellcheck source=lib/install/superpowers.sh
source "${INSTALL_LIB_DIR}/superpowers.sh"   # install/update/upgrade_superpowers
# shellcheck source=lib/install/deploy.sh
source "${INSTALL_LIB_DIR}/deploy.sh"        # install_skill(s), install_adapter/rules/templates
# shellcheck source=lib/install/migrate.sh
source "${INSTALL_LIB_DIR}/migrate.sh"       # post_install_migrations

# Load .env if present (for optional integrations)
# shellcheck disable=SC1091
[[ -f "$SCRIPT_DIR/.env" ]] && source "$SCRIPT_DIR/.env"

# --- Help ---
show_help() {
    cat << 'EOF'
NAME
    install.sh - Install or upgrade superpowers-plus skills

SYNOPSIS
    install.sh [OPTIONS]

DESCRIPTION
    superpowers-plus extends obra/superpowers by Jesse Vincent with additional
    skills for wiki editing, issue tracking, security audits, and AI text quality.

    This installer clones obra/superpowers (if not present) and deploys all
    superpowers-plus skills to ~/.codex/skills/. Safe to run multiple times.

OPTIONS
    -h, --help
        Display this help message and exit

    -v, --verbose
        Show detailed progress information

    --upgrade
        Explicitly upgrade an existing superpowers installation. Requires
        superpowers to already be installed. Shows before/after version
        comparison. Use with --force to discard local changes first.

    --force
        Without --upgrade: Remove and re-clone superpowers from scratch.
        With --upgrade: Reset local changes (git reset --hard, git clean -fd)
        before pulling latest updates.

    -y, --yes
        Auto-accept all prompts (e.g., dependency installation) without
        asking for confirmation. Also enabled automatically when stdin is
        not a TTY (e.g., when called from another script or via pipe).

    --version
        Display version information and exit

WHAT GETS INSTALLED
    ~/.codex/superpowers/   obra/superpowers core (cloned from GitHub)
    ~/.codex/skills/        Personal skills for Augment (via superpowers-augment.js)
    ~/.claude/skills/       Personal skills for Claude Code (native Skill tool)
    ~/.augment/skills/      Personal skills for Augment (alternative location)

EXAMPLES
    # Install with default settings (or update if already present)
    ./install.sh

    # Install with verbose output
    ./install.sh --verbose

    # Force reinstall of superpowers (removes and re-clones)
    ./install.sh --force

    # Upgrade existing installation with version comparison
    ./install.sh --upgrade --verbose

    # Force upgrade, discarding any local changes
    ./install.sh --upgrade --force

INSTALLATION METHODS
    This script is ONE of several installation options:

    1. DIRECT CLONE (this script)
       For: Power users who want full control
       Steps:
           git clone https://github.com/bordenet/superpowers-plus.git
           cd superpowers-plus
           ./install.sh
       Updates: Run ./install.sh --upgrade

    2. CURL PIPE (one-liner for Augment users)
       For: Quick Augment setup without cloning
       Command:
           curl -fsSL https://raw.githubusercontent.com/bordenet/superpowers-plus/main/install-augment-superpowers.sh | bash
       Updates: Re-run the curl command

    3. GITHUB RELEASES (version-pinned)
       For: Reproducible installations, CI/CD
       Steps:
           1. Visit https://github.com/bordenet/superpowers-plus/releases
           2. Download desired version tarball
           3. Extract and run ./install.sh
       Updates: Download newer release manually

VERSION INFO
    Current: Run ./install.sh --version
    Check for updates: Compare with latest at
        https://github.com/bordenet/superpowers-plus/releases

AUTHOR
    Matt J Bordenet

SEE ALSO
    Repository: https://github.com/bordenet/superpowers-plus
    Superpowers core: https://github.com/obra/superpowers
    Changelog: https://github.com/bordenet/superpowers-plus/blob/main/CHANGELOG.md
EOF
    exit 0
}

# --- Argument Parsing ---
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help) show_help ;;
        -v|--verbose) VERBOSE=true; shift ;;
        -y|--yes) YES=true; shift ;;
        --force) FORCE=true; shift ;;
        --upgrade) UPGRADE=true; shift ;;
        --version) echo "install.sh version $VERSION"; exit 0 ;;
        *)
            echo -e "${RED}Error: Unknown option $1${NC}" >&2
            echo "Use -h or --help for usage information" >&2
            exit 1
            ;;
    esac
done

# --- Validate and Summarize (kept in orchestrator for visibility) ---

# Validate the installation
validate_installation() {
    log_info "Validating installation..."

    local errors=0

    # Check superpowers skills directory (v4.2.0+ uses skills/ directory)
    if [[ ! -d "$SUPERPOWERS_DIR/skills" ]]; then
        log_error "superpowers skills directory not found"
        errors=$((errors + 1))
    else
        log_verbose "superpowers skills directory: OK"
    fi

    # Check Augment skills directory (~/.codex/skills)
    if [[ ! -d "$SKILLS_DIR" ]]; then
        log_error "Augment skills directory not found: $SKILLS_DIR"
        errors=$((errors + 1))
    else
        log_verbose "Augment skills directory: OK"
    fi

    # Check Claude Code skills directory (~/.claude/skills)
    if [[ ! -d "$CLAUDE_SKILLS_DIR" ]]; then
        log_error "Claude Code skills directory not found: $CLAUDE_SKILLS_DIR"
        errors=$((errors + 1))
    else
        log_verbose "Claude Code skills directory: OK"
    fi

    # Count installed personal skills (check both SKILL.md and skill.md)
    local skill_count=0
    for skill_dir in "$SKILLS_DIR/"*/; do
        if [[ -d "$skill_dir" ]] && { [[ -f "$skill_dir/SKILL.md" ]] || [[ -f "$skill_dir/skill.md" ]]; }; then
            skill_count=$((skill_count + 1))
        fi
    done

    if [[ $skill_count -eq 0 ]]; then
        log_warn "No personal skills installed in $SKILLS_DIR"
    else
        log_verbose "Found $skill_count personal skill(s) in Augment location"
    fi

    # Count Claude Code skills
    local claude_skill_count=0
    for skill_dir in "$CLAUDE_SKILLS_DIR/"*/; do
        if [[ -d "$skill_dir" ]] && { [[ -f "$skill_dir/SKILL.md" ]] || [[ -f "$skill_dir/skill.md" ]]; }; then
            claude_skill_count=$((claude_skill_count + 1))
        fi
    done
    log_verbose "Found $claude_skill_count personal skill(s) in Claude Code location"

    # Count superpowers skills (check both SKILL.md and skill.md)
    local sp_skill_count=0
    if [[ -d "$SUPERPOWERS_DIR/skills" ]]; then
        for skill_dir in "$SUPERPOWERS_DIR/skills/"*/; do
            if [[ -d "$skill_dir" ]] && { [[ -f "$skill_dir/SKILL.md" ]] || [[ -f "$skill_dir/skill.md" ]]; }; then
                sp_skill_count=$((sp_skill_count + 1))
            fi
        done
        log_verbose "Found $sp_skill_count superpowers skill(s)"
    fi

    # Check obra/superpowers version is recent enough
    if ! check_obra_version; then
        log_warn "obra/superpowers may be too old for this version of superpowers-plus"
    fi

    if [[ $errors -gt 0 ]]; then
        error_exit "Validation failed with $errors error(s)"
    fi

    log_success "Installation validated"
}

# Print summary
print_summary() {
    echo ""
    echo "========================================"
    echo "  superpowers-plus Installation Complete"
    echo "========================================"
    echo ""
    echo "Installed to:"
    echo "  obra/superpowers:  $SUPERPOWERS_DIR"
    echo ""
    echo "  Claude Code:       $CLAUDE_SKILLS_DIR"
    echo "                     (native Skill tool)"
    echo ""
    echo "  Augment Agent:     $SKILLS_DIR"
    echo "                     (superpowers-augment.js)"
    echo "                     $AUGMENT_SKILLS_DIR"
    echo ""
    echo "Personal skills:"
    for skill_dir in "$SKILLS_DIR/"*/; do
        [[ -d "$skill_dir" ]] && { [[ -f "$skill_dir/SKILL.md" ]] || [[ -f "$skill_dir/skill.md" ]]; } && echo "  • $(basename "$skill_dir")"
    done
    echo ""
    echo "Optional integrations:"
    if [[ -n "${PERPLEXITY_API_KEY:-}" ]]; then
        echo -e "  ${GREEN}✓${NC} Perplexity research: configured"
    else
        echo "  • Perplexity research: ./setup/mcp-perplexity.sh"
    fi
    if [[ -n "${WIKI_PLATFORM:-}" ]]; then
        echo -e "  ${GREEN}✓${NC} Wiki: ${WIKI_PLATFORM}"
    else
        echo "  • Wiki: set WIKI_PLATFORM in .env (see skills/wiki/_adapters/)"
    fi
    if [[ -n "${ISSUE_TRACKER_TYPE:-}" ]]; then
        echo -e "  ${GREEN}✓${NC} Issue tracking: ${ISSUE_TRACKER_TYPE}"
    else
        echo "  • Issue tracking: set ISSUE_TRACKER_TYPE in .env"
    fi
    echo ""
    if [[ ! -f "$SCRIPT_DIR/.env" ]]; then
        echo "Configuration: cp .env.example .env (then edit with your keys)"
        echo ""
    fi
    echo "Verify with:"
    echo "  Claude Code:   /explain-code (or other skill slash commands)"
    echo "  Augment Agent: node ~/.codex/superpowers-augment/superpowers-augment.js find-skills"
    echo ""
}

# Main installation flow
main() {
    echo ""
    log_info "superpowers-plus installer"
    echo ""

    # Check dependencies
    check_dependencies

    # Handle --upgrade mode (explicit upgrade of existing installation)
    if [[ "$UPGRADE" == "true" ]]; then
        upgrade_existing
        # Reinstall personal skills, rules, templates after upgrade
        install_skills
        post_install_migrations
        install_rules
        install_templates
        install_adapter
        validate_installation
        print_summary
        return
    fi

    # Handle standard install/update modes
    if ! check_superpowers; then
        install_superpowers
    elif [[ "$FORCE" == "true" ]]; then
        log_info "Force flag set, reinstalling superpowers..."
        rm -rf "${SUPERPOWERS_DIR:?}"
        install_superpowers
    else
        log_success "obra/superpowers already installed"
        # Try to update — warn prominently if update fails
        if ! update_superpowers; then
            local checkout_age
            checkout_age=$(cd "$SUPERPOWERS_DIR" && git log -1 --format='%cr' HEAD 2>/dev/null || echo "unknown")
            log_warn "Continuing with existing obra/superpowers (last updated: $checkout_age)"
        fi
    fi

    # Install skills
    install_skills

    # Run migrations (clean stale overrides, detect orphaned TODO.md)
    post_install_migrations

    # Install rules
    install_rules

    # Install templates
    install_templates

    # Install adapter
    install_adapter

    # Validate
    validate_installation

    # Print summary
    print_summary
}

# Run main
main

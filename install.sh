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
#        --force         Overwrite existing skills without prompting
#        --upgrade       Pull latest changes before installing
#        --version       Show version number
# PLATFORM: macOS (Intel/Apple Silicon), Linux (Debian/Ubuntu, RHEL/Fedora, Arch), WSL
# VERSION: 2.1.0
# -----------------------------------------------------------------------------
set -euo pipefail

VERSION="2.1.0"

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
SKILLS_DIR="${CODEX_DIR}/skills"
SUPERPOWERS_DIR="${CODEX_DIR}/superpowers"
SUPERPOWERS_REPO="https://github.com/obra/superpowers.git"

# Platform-specific skill deployment paths
# Claude Code: Native Skill tool reads from ~/.claude/skills/
CLAUDE_SKILLS_DIR="${HOME}/.claude/skills"
# Augment Agent: superpowers-augment.js reads from ~/.codex/skills/ (SKILLS_DIR above)
#                Also deploy to ~/.augment/skills/ for potential future use
AUGMENT_SKILLS_DIR="${HOME}/.augment/skills"

# Load .env if present (for optional integrations)
# shellcheck disable=SC1091
[[ -f "$SCRIPT_DIR/.env" ]] && source "$SCRIPT_DIR/.env"

# --- Platform Detection ---
detect_platform() {
    case "$(uname -s)" in
        Darwin) echo "macos" ;;
        Linux)
            if grep -qiE "(microsoft|wsl)" /proc/version 2>/dev/null; then
                echo "wsl"
            else
                echo "linux"
            fi
            ;;
        MINGW*|MSYS*|CYGWIN*) echo "windows" ;;
        *) echo "unknown" ;;
    esac
}

detect_linux_distro() {
    if [[ -f /etc/os-release ]]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        echo "$ID"  # ubuntu, debian, fedora, centos, rhel, arch, etc.
    elif [[ -f /etc/redhat-release ]]; then
        echo "rhel"
    elif [[ -f /etc/debian_version ]]; then
        echo "debian"
    else
        echo "unknown"
    fi
}

PLATFORM=$(detect_platform)
LINUX_DISTRO=""
if [[ "$PLATFORM" == "linux" ]] || [[ "$PLATFORM" == "wsl" ]]; then
    LINUX_DISTRO=$(detect_linux_distro)
fi

# WSL-specific checks
if [[ "$PLATFORM" == "wsl" ]]; then
    # Check if running from Windows filesystem (common mistake, causes permission issues)
    if [[ "$PWD" == /mnt/* ]]; then
        echo ""
        echo -e "${YELLOW}[WARN]${NC} Running from Windows filesystem ($PWD)"
        echo ""
        echo "This may cause permission issues. For best results:"
        echo "  1. Clone the repo to WSL filesystem: ~/GitHub/superpowers-plus"
        echo "  2. Run from there: cd ~/GitHub/superpowers-plus && ./install.sh"
        echo ""
        echo "Continuing anyway..."
        echo ""
    fi

    # Check if HOME is set correctly (not a Windows path)
    if [[ "$HOME" == /mnt/* ]]; then
        echo -e "${RED}[ERROR]${NC} \$HOME is set to a Windows path: $HOME"
        echo "This will cause installation to fail."
        echo ""
        echo "Fix: Set HOME to a WSL path in ~/.bashrc:"
        echo "  export HOME=/home/\$(whoami)"
        echo ""
        exit 1
    fi
fi

# Options
FORCE=false
VERBOSE=false
UPGRADE=false

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

# Logging functions
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

# Error handler
error_exit() {
    log_error "$1"
    exit 1
}

# Install a single dependency using the appropriate package manager
install_dependency() {
    local pkg="$1"
    log_info "Installing $pkg..."

    case "$PLATFORM" in
        macos)
            if ! command -v brew &> /dev/null; then
                log_error "Homebrew is required to install dependencies on macOS"
                log_error "Install from: https://brew.sh"
                return 1
            fi
            brew install "$pkg" || return 1
            ;;
        linux|wsl)
            case "$LINUX_DISTRO" in
                ubuntu|debian|pop|linuxmint)
                    sudo apt-get update -qq && sudo apt-get install -y "$pkg" || return 1
                    ;;
                fedora)
                    sudo dnf install -y "$pkg" || return 1
                    ;;
                centos|rhel|rocky|almalinux)
                    sudo yum install -y "$pkg" || return 1
                    ;;
                arch|manjaro)
                    sudo pacman -S --noconfirm "$pkg" || return 1
                    ;;
                opensuse*|suse*)
                    sudo zypper install -y "$pkg" || return 1
                    ;;
                *)
                    log_error "Unsupported Linux distribution: $LINUX_DISTRO"
                    log_error "Please install '$pkg' manually"
                    return 1
                    ;;
            esac
            ;;
        windows)
            log_error "Auto-install not supported on native Windows."
            log_error "Please install '$pkg' manually (e.g., 'winget install $pkg')"
            return 1
            ;;
        *)
            log_error "Unsupported platform: $PLATFORM"
            return 1
            ;;
    esac

    log_success "Installed $pkg"
}

# Check for required dependencies and offer to install missing ones
check_dependencies() {
    log_verbose "Checking dependencies on $PLATFORM..."
    [[ -n "$LINUX_DISTRO" ]] && log_verbose "Linux distribution: $LINUX_DISTRO"

    local missing=()
    local required_deps=("git" "node")

    for dep in "${required_deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing+=("$dep")
        fi
    done

    if [[ ${#missing[@]} -eq 0 ]]; then
        log_verbose "All dependencies present"
        return 0
    fi

    log_warn "Missing dependencies: ${missing[*]}"

    # Check if we can install automatically
    if [[ "$PLATFORM" == "unknown" ]]; then
        error_exit "Cannot auto-install on unknown platform. Please install: ${missing[*]}"
    fi

    # Offer to install
    echo ""
    read -r -p "Install missing dependencies? [Y/n] " response
    case "$response" in
        [nN][oO]|[nN])
            error_exit "Cannot continue without: ${missing[*]}"
            ;;
        *)
            for dep in "${missing[@]}"; do
                if ! install_dependency "$dep"; then
                    error_exit "Failed to install $dep"
                fi
            done
            ;;
    esac

    log_verbose "All dependencies installed"
}

# Create directory with error handling
create_dir() {
    local dir="$1"
    if [[ ! -d "$dir" ]]; then
        log_verbose "Creating directory: $dir"
        mkdir -p "$dir" || error_exit "Failed to create directory: $dir"
    fi
}

# Check if superpowers is installed (v4.2.0+ uses skills/ directory, not superpowers-codex)
check_superpowers() {
    if [[ -d "$SUPERPOWERS_DIR" ]] && [[ -d "$SUPERPOWERS_DIR/skills" ]]; then
        return 0
    fi
    return 1
}

# Install obra/superpowers
install_superpowers() {
    log_info "Installing obra/superpowers..."

    # Create codex directory
    create_dir "$CODEX_DIR"

    # Remove existing installation if force flag set
    if [[ "$FORCE" == "true" ]] && [[ -d "$SUPERPOWERS_DIR" ]]; then
        log_verbose "Removing existing superpowers installation"
        rm -rf "${SUPERPOWERS_DIR:?}"
    fi

    # If directory exists but not forced, try to update instead
    if [[ -d "$SUPERPOWERS_DIR" ]]; then
        if [[ -d "$SUPERPOWERS_DIR/.git" ]]; then
            log_info "Superpowers already installed, updating..."
            update_superpowers
            return $?
        else
            log_warn "Superpowers directory exists but is not a git repo"
            log_warn "Use --force to reinstall"
            return 1
        fi
    fi

    # Clone the repository directly to ~/.codex/superpowers
    log_verbose "Cloning from $SUPERPOWERS_REPO to $SUPERPOWERS_DIR"
    if ! git clone --depth 1 "$SUPERPOWERS_REPO" "$SUPERPOWERS_DIR" 2>&1; then
        error_exit "Failed to clone superpowers repository"
    fi

    # Verify installation (v4.2.0+ uses skills/ directory)
    if [[ ! -d "$SUPERPOWERS_DIR/skills" ]]; then
        error_exit "skills directory not found after installation"
    fi

    log_success "obra/superpowers installed successfully"
}

# Update obra/superpowers
update_superpowers() {
    log_info "Updating obra/superpowers..."

    if [[ ! -d "$SUPERPOWERS_DIR/.git" ]]; then
        log_warn "Cannot update: superpowers is not a git repository"
        return 1
    fi

    log_verbose "Pulling latest changes"
    if ! (cd "$SUPERPOWERS_DIR" && git pull --ff-only 2>&1); then
        log_warn "Failed to update superpowers (may have local changes)"
        return 1
    fi

    log_success "obra/superpowers updated"
}

# Upgrade existing superpowers installation (explicit upgrade mode)
upgrade_existing() {
    log_info "Upgrading obra/superpowers..."

    # Require superpowers to already exist
    if [[ ! -d "$SUPERPOWERS_DIR" ]]; then
        error_exit "superpowers not installed. Run ./install.sh first (without --upgrade)."
    fi
    if [[ ! -d "$SUPERPOWERS_DIR/.git" ]]; then
        error_exit "superpowers directory is not a git repository. Run ./install.sh --force to reinstall."
    fi

    cd "$SUPERPOWERS_DIR" || error_exit "Failed to change to superpowers directory"

    # Get before SHA
    local before_sha
    before_sha=$(git rev-parse --short HEAD)
    log_verbose "Current version: $before_sha"

    # If --force, reset local changes first
    if [[ "$FORCE" == "true" ]]; then
        log_info "Resetting local changes (--force)..."
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
        log_warn "Run with --upgrade --force to discard local changes and upgrade."
        exit 1
    fi

    # Get after SHA and report
    local after_sha
    after_sha=$(git rev-parse --short HEAD)

    if [[ "$before_sha" == "$after_sha" ]]; then
        log_success "Already up to date ($after_sha)"
    else
        log_success "Upgraded: $before_sha → $after_sha"
    fi

    cd - > /dev/null || true
}

# Install a single skill to all platform-specific paths
install_skill() {
    local skill_dir="$1"
    local skill_name
    skill_name=$(basename "$skill_dir")

    log_verbose "Installing skill: $skill_name"

    # Check if SKILL.md or skill.md exists
    if [[ ! -f "$skill_dir/SKILL.md" ]] && [[ ! -f "$skill_dir/skill.md" ]]; then
        log_warn "Skipping $skill_name: No SKILL.md or skill.md found"
        return 1
    fi

    # --- Deploy to Augment Agent (~/.codex/skills/) ---
    # superpowers-augment.js reads from this location
    if [[ -d "$SKILLS_DIR/$skill_name" ]]; then
        rm -rf "${SKILLS_DIR:?}/${skill_name:?}" || \
            error_exit "Failed to remove existing skill: $skill_name (Augment/codex)"
    fi
    cp -r "$skill_dir" "$SKILLS_DIR/$skill_name" || \
        error_exit "Failed to install skill: $skill_name (Augment/codex)"

    # --- Deploy to Claude Code (~/.claude/skills/) ---
    # Claude Code's native Skill tool reads from this location
    mkdir -p "$CLAUDE_SKILLS_DIR"
    if [[ -d "$CLAUDE_SKILLS_DIR/$skill_name" ]]; then
        rm -rf "${CLAUDE_SKILLS_DIR:?}/${skill_name:?}" || \
            error_exit "Failed to remove existing skill: $skill_name (Claude Code)"
    fi
    cp -r "$skill_dir" "$CLAUDE_SKILLS_DIR/$skill_name" || \
        error_exit "Failed to install skill: $skill_name (Claude Code)"

    # --- Deploy to Augment Agent (~/.augment/skills/) ---
    # Alternative location for Augment
    mkdir -p "$AUGMENT_SKILLS_DIR"
    if [[ -d "$AUGMENT_SKILLS_DIR/$skill_name" ]]; then
        rm -rf "${AUGMENT_SKILLS_DIR:?}/${skill_name:?}" || \
            error_exit "Failed to remove existing skill: $skill_name (Augment)"
    fi
    cp -r "$skill_dir" "$AUGMENT_SKILLS_DIR/$skill_name" || \
        error_exit "Failed to install skill: $skill_name (Augment)"

    log_success "Installed: $skill_name"
    return 0
}

# Install the superpowers-augment adapter
install_adapter() {
    log_info "Installing superpowers-augment adapter..."

    local adapter_src="$SCRIPT_DIR/superpowers-augment.js"
    local adapter_dest_dir="${CODEX_DIR}/superpowers-augment"
    local adapter_dest="${adapter_dest_dir}/superpowers-augment.js"

    # Verify adapter source exists
    if [[ ! -f "$adapter_src" ]]; then
        log_warn "Adapter source not found: $adapter_src"
        return 1
    fi

    # Create destination directory
    create_dir "$adapter_dest_dir"

    # Check if already installed and identical (skip copy for idempotency)
    if [[ -f "$adapter_dest" ]] && cmp -s "$adapter_src" "$adapter_dest"; then
        log_verbose "Adapter already up to date"
        return 0
    fi

    # Copy adapter (no chmod +x needed - run via 'node script.js')
    cp "$adapter_src" "$adapter_dest" || error_exit "Failed to copy adapter to $adapter_dest"

    log_success "Adapter installed: $adapter_dest"
}

# Install all skills from this repository (supports domain-based structure)
install_skills() {
    log_info "Installing skills from superpowers-plus..."

    # Verify skills directory exists and is readable
    if [[ ! -d "$SCRIPT_DIR/skills" ]]; then
        error_exit "Skills directory not found: $SCRIPT_DIR/skills"
    fi
    if [[ ! -r "$SCRIPT_DIR/skills" ]]; then
        error_exit "Skills directory not readable: $SCRIPT_DIR/skills (check permissions)"
    fi

    # Create all skills directories
    create_dir "$SKILLS_DIR"
    create_dir "$CLAUDE_SKILLS_DIR"
    create_dir "$AUGMENT_SKILLS_DIR"

    local installed=0
    local skipped=0

    # Auto-discover skills: supports both flat and domain-based structure
    # Pattern 1: skills/{skill-name}/skill.md (flat)
    # Pattern 2: skills/{domain}/{skill-name}/skill.md (domain-based)
    for domain_or_skill in "$SCRIPT_DIR/skills/"*/; do
        [[ ! -d "$domain_or_skill" ]] && continue
        local dir_name
        dir_name=$(basename "$domain_or_skill")

        # Skip special directories
        [[ "$dir_name" == "_shared" ]] && continue
        [[ "$dir_name" == "_archive" ]] && continue

        # Check if this is a skill directory (has skill.md or SKILL.md)
        if [[ -f "$domain_or_skill/skill.md" ]] || [[ -f "$domain_or_skill/SKILL.md" ]]; then
            # Flat structure: skills/{skill-name}/skill.md
            if install_skill "$domain_or_skill"; then
                ((installed++)) || true
            else
                ((skipped++)) || true
            fi
        else
            # Domain structure: look for skills in subdirectories
            for skill_dir in "$domain_or_skill"*/; do
                [[ ! -d "$skill_dir" ]] && continue
                if [[ -f "$skill_dir/skill.md" ]] || [[ -f "$skill_dir/SKILL.md" ]]; then
                    if install_skill "$skill_dir"; then
                        ((installed++)) || true
                    else
                        ((skipped++)) || true
                    fi
                fi
            done
        fi
    done

    if [[ $installed -eq 0 ]]; then
        log_warn "No skills were installed"
    else
        log_success "Installed $installed skill(s)"
    fi

    if [[ $skipped -gt 0 ]] && [[ "$VERBOSE" == "true" ]]; then
        log_verbose "Skipped $skipped item(s)"
    fi
}

# Validate the installation
validate_installation() {
    log_info "Validating installation..."

    local errors=0

    # Check superpowers skills directory (v4.2.0+ uses skills/ directory)
    if [[ ! -d "$SUPERPOWERS_DIR/skills" ]]; then
        log_error "superpowers skills directory not found"
        ((errors++)) || true
    else
        log_verbose "superpowers skills directory: OK"
    fi

    # Check Augment skills directory (~/.codex/skills)
    if [[ ! -d "$SKILLS_DIR" ]]; then
        log_error "Augment skills directory not found: $SKILLS_DIR"
        ((errors++)) || true
    else
        log_verbose "Augment skills directory: OK"
    fi

    # Check Claude Code skills directory (~/.claude/skills)
    if [[ ! -d "$CLAUDE_SKILLS_DIR" ]]; then
        log_error "Claude Code skills directory not found: $CLAUDE_SKILLS_DIR"
        ((errors++)) || true
    else
        log_verbose "Claude Code skills directory: OK"
    fi

    # Count installed personal skills (check both SKILL.md and skill.md)
    local skill_count=0
    for skill_dir in "$SKILLS_DIR/"*/; do
        if [[ -d "$skill_dir" ]] && { [[ -f "$skill_dir/SKILL.md" ]] || [[ -f "$skill_dir/skill.md" ]]; }; then
            ((skill_count++)) || true
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
            ((claude_skill_count++)) || true
        fi
    done
    log_verbose "Found $claude_skill_count personal skill(s) in Claude Code location"

    # Count superpowers skills (check both SKILL.md and skill.md)
    local sp_skill_count=0
    if [[ -d "$SUPERPOWERS_DIR/skills" ]]; then
        for skill_dir in "$SUPERPOWERS_DIR/skills/"*/; do
            if [[ -d "$skill_dir" ]] && { [[ -f "$skill_dir/SKILL.md" ]] || [[ -f "$skill_dir/skill.md" ]]; }; then
                ((sp_skill_count++)) || true
            fi
        done
        log_verbose "Found $sp_skill_count superpowers skill(s)"
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
        # Reinstall personal skills after upgrade
        install_skills
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
        # Try to update
        update_superpowers || true
    fi

    # Install skills
    install_skills

    # Install adapter
    install_adapter

    # Validate
    validate_installation

    # Print summary
    print_summary
}

# Run main
main

#!/bin/bash
#
# install.sh - Install superpowers-plus skills
#
# This script:
# 1. Checks for and installs obra/superpowers if not present
# 2. Installs all skills from this repository to ~/.codex/skills/
# 3. Validates the installation
#
# Usage: ./install.sh [--force] [--verbose]
#
# Options:
#   --force    Reinstall superpowers even if already present
#   --verbose  Show detailed output
#   --help     Show this help message

set -euo pipefail

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

# Options
FORCE=false
VERBOSE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --force)
            FORCE=true
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --help)
            head -20 "$0" | tail -15
            exit 0
            ;;
        *)
            echo -e "${RED}Error: Unknown option $1${NC}"
            echo "Use --help for usage information"
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

# Check for required dependencies
check_dependencies() {
    log_verbose "Checking dependencies..."

    local missing=()

    if ! command -v git &> /dev/null; then
        missing+=("git")
    fi

    if [[ ${#missing[@]} -gt 0 ]]; then
        error_exit "Missing required dependencies: ${missing[*]}"
    fi

    log_verbose "All dependencies present"
}

# Create directory with error handling
create_dir() {
    local dir="$1"
    if [[ ! -d "$dir" ]]; then
        log_verbose "Creating directory: $dir"
        mkdir -p "$dir" || error_exit "Failed to create directory: $dir"
    fi
}

# Check if superpowers is installed
check_superpowers() {
    if [[ -d "$SUPERPOWERS_DIR" ]] && [[ -f "$SUPERPOWERS_DIR/.codex/superpowers-codex" ]]; then
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
        rm -rf "$SUPERPOWERS_DIR"
    fi

    # Clone the repository directly to ~/.codex/superpowers
    log_verbose "Cloning from $SUPERPOWERS_REPO to $SUPERPOWERS_DIR"
    if ! git clone --depth 1 "$SUPERPOWERS_REPO" "$SUPERPOWERS_DIR" 2>&1; then
        error_exit "Failed to clone superpowers repository"
    fi

    # Verify installation
    if [[ ! -f "$SUPERPOWERS_DIR/.codex/superpowers-codex" ]]; then
        error_exit "superpowers-codex not found after installation"
    fi

    # Make superpowers-codex executable
    chmod +x "$SUPERPOWERS_DIR/.codex/superpowers-codex" || \
        log_warn "Failed to make superpowers-codex executable"

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

# Install a single skill
install_skill() {
    local skill_dir="$1"
    local skill_name
    skill_name=$(basename "$skill_dir")

    log_verbose "Installing skill: $skill_name"

    # Check if SKILL.md exists
    if [[ ! -f "$skill_dir/SKILL.md" ]]; then
        log_warn "Skipping $skill_name: No SKILL.md found"
        return 1
    fi

    # Remove existing skill directory
    if [[ -d "$SKILLS_DIR/$skill_name" ]]; then
        rm -rf "$SKILLS_DIR/$skill_name" || \
            error_exit "Failed to remove existing skill: $skill_name"
    fi

    # Copy skill to skills directory
    cp -r "$skill_dir" "$SKILLS_DIR/$skill_name" || \
        error_exit "Failed to install skill: $skill_name"

    log_success "Installed: $skill_name"
    return 0
}

# Install all skills from this repository
install_skills() {
    log_info "Installing skills from superpowers-plus..."

    # Create skills directory
    create_dir "$SKILLS_DIR"

    local installed=0
    local failed=0

    # Iterate through skill directories
    for skill_dir in "$SCRIPT_DIR/skills/"*/; do
        if [[ -d "$skill_dir" ]]; then
            if install_skill "$skill_dir"; then
                ((installed++)) || true
            else
                ((failed++)) || true
            fi
        fi
    done

    if [[ $installed -eq 0 ]]; then
        log_warn "No skills were installed"
    else
        log_success "Installed $installed skill(s)"
    fi

    if [[ $failed -gt 0 ]]; then
        log_warn "Skipped $failed item(s) (no SKILL.md)"
    fi
}

# Validate the installation
validate_installation() {
    log_info "Validating installation..."

    local errors=0

    # Check superpowers-codex
    if [[ ! -f "$SUPERPOWERS_DIR/.codex/superpowers-codex" ]]; then
        log_error "superpowers-codex not found"
        ((errors++)) || true
    else
        log_verbose "superpowers-codex: OK"
    fi

    # Check skills directory
    if [[ ! -d "$SKILLS_DIR" ]]; then
        log_error "Skills directory not found"
        ((errors++)) || true
    else
        log_verbose "Skills directory: OK"
    fi

    # Count installed skills
    local skill_count=0
    for skill_dir in "$SKILLS_DIR/"*/; do
        if [[ -d "$skill_dir" ]] && [[ -f "$skill_dir/SKILL.md" ]]; then
            ((skill_count++)) || true
        fi
    done

    if [[ $skill_count -eq 0 ]]; then
        log_warn "No personal skills installed in $SKILLS_DIR"
    else
        log_verbose "Found $skill_count personal skill(s)"
    fi

    # Count superpowers skills
    local sp_skill_count=0
    if [[ -d "$SUPERPOWERS_DIR/skills" ]]; then
        for skill_dir in "$SUPERPOWERS_DIR/skills/"*/; do
            if [[ -d "$skill_dir" ]] && [[ -f "$skill_dir/SKILL.md" ]]; then
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
    echo "  Superpowers:     $SUPERPOWERS_DIR"
    echo "  Personal Skills: $SKILLS_DIR"
    echo ""
    echo "Personal skills (from superpowers-plus):"
    for skill_dir in "$SKILLS_DIR/"*/; do
        if [[ -d "$skill_dir" ]] && [[ -f "$skill_dir/SKILL.md" ]]; then
            local skill_name
            skill_name=$(basename "$skill_dir")
            echo "  • $skill_name"
        fi
    done
    echo ""
    echo "Superpowers skills (from obra/superpowers):"
    if [[ -d "$SUPERPOWERS_DIR/skills" ]]; then
        for skill_dir in "$SUPERPOWERS_DIR/skills/"*/; do
            if [[ -d "$skill_dir" ]] && [[ -f "$skill_dir/SKILL.md" ]]; then
                local skill_name
                skill_name=$(basename "$skill_dir")
                echo "  • superpowers:$skill_name"
            fi
        done
    fi
    echo ""
    echo "Usage:"
    echo "  # Use a personal skill"
    echo "  ~/.codex/superpowers/.codex/superpowers-codex use-skill <skill-name>"
    echo ""
    echo "  # Use a superpowers skill"
    echo "  ~/.codex/superpowers/.codex/superpowers-codex use-skill superpowers:<skill-name>"
    echo ""
}

# Main installation flow
main() {
    echo ""
    log_info "superpowers-plus installer"
    echo ""

    # Check dependencies
    check_dependencies

    # Install or update superpowers
    if ! check_superpowers; then
        install_superpowers
    elif [[ "$FORCE" == "true" ]]; then
        log_info "Force flag set, reinstalling superpowers..."
        rm -rf "$SUPERPOWERS_DIR"
        install_superpowers
    else
        log_success "obra/superpowers already installed"
        # Try to update
        update_superpowers || true
    fi

    # Install skills
    install_skills

    # Validate
    validate_installation

    # Print summary
    print_summary
}

# Run main
main

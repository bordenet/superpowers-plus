#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Script: install.sh
# PURPOSE: Install superpowers-plus skills with platform detection, dependency
#          management, and multi-target deployment. Clones/updates obra/superpowers
#          as a prerequisite, validates environment variables, and deploys skills
#          to ~/.codex/skills/ and ~/.claude/skills/.
# USAGE: ./install.sh [options]
#        -h, --help      Show help message
#        -v, --verbose   Enable verbose output
#        -y, --yes       Auto-accept prompts (non-interactive mode)
#        --force         Overwrite existing skills without prompting
#        --upgrade       Pull latest changes before installing
#        --version       Show version number
# PLATFORM: macOS (Intel/Apple Silicon), Linux (Debian/Ubuntu, RHEL/Fedora, Arch), WSL
# VERSION: 2.5.2
# ARCHITECTURE: This file is a thin orchestrator. Implementation lives in
#               lib/install/*.sh modules, sourced in dependency order below.
# -----------------------------------------------------------------------------
set -euo pipefail

VERSION="2.5.2"

# --- Bash version check ---
# This script requires bash 4+ for associative arrays (declare -A).
# macOS ships with bash 3.2 (Apple can't update past GPLv2).
# Install modern bash: brew install bash
if [[ "${BASH_VERSINFO[0]}" -lt 4 ]]; then
    echo "[ERROR] bash ${BASH_VERSION} is too old (need bash 4+)." >&2
    echo "" >&2
    echo "  macOS ships bash 3.2 due to licensing. Fix:" >&2
    echo "    brew install bash" >&2
    echo "" >&2
    echo "  Then re-run:  bash $0 $*" >&2
    echo "  Or add /opt/homebrew/bin to PATH before /bin" >&2
    exit 1
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

# Options (set before sourcing modules so they can read these)
FORCE=false
VERBOSE=false
UPGRADE=false
CHECK=false
YES=false

# Auto-detect non-interactive context (piped input, curl | bash, etc.)
if ! [[ -t 0 ]]; then
    YES=true
fi

# --- CRLF self-heal (WSL + Windows git clone with core.autocrlf=true) ---
# If this script or its modules have Windows line endings, bash will fail with
# cryptic errors like "syntax error near unexpected token `$'\r'". Fix them
# before sourcing anything.
# Recursively check ALL .sh files in the repo — a CRLF module anywhere
# (tools/, setup/, lib/) will break sourcing or execution.
# Use grep -rl (not -lq — -q suppresses -l output, breaking the pipeline).
if [ -n "$(find "$SCRIPT_DIR" -name '*.sh' -exec grep -rl $'\r' {} + 2>/dev/null | head -1)" ]; then
    # Cross-platform in-place CRLF strip: prefer perl, fall back to tr per-file
    if command -v perl &>/dev/null; then
        find "$SCRIPT_DIR" -name "*.sh" -exec perl -pi -e 's/\r$//' {} +
    else
        # tr fallback: preserve execute bits after rewrite
        find "$SCRIPT_DIR" -name "*.sh" -print0 | while IFS= read -r -d '' f; do
            tr -d '\r' < "$f" > "${f}.tmp"
            [[ -x "$f" ]] && chmod +x "${f}.tmp"
            mv "${f}.tmp" "$f"
        done
    fi
    echo "[WARN] Fixed Windows line endings (CRLF → LF) in installer scripts."
    echo "       Re-run: $0 $*"
    echo ""
    echo "       To prevent this, configure git:"
    echo "         git config --global core.autocrlf input"
    exit 0
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
source "${INSTALL_LIB_DIR}/deploy.sh"        # install_skill(s), install_adapter/rules/templates/tools
# shellcheck source=lib/install/migrate.sh
source "${INSTALL_LIB_DIR}/migrate.sh"       # post_install_migrations

# Load .env if present (for optional integrations)
# Source in a subshell to prevent .env from mutating installer shell state
# (e.g., set +e, PATH changes, IFS changes). Only extract needed variables.
if [[ -f "$SCRIPT_DIR/.env" ]]; then
    _env_vars=$(_SPP_ENV_FILE="$SCRIPT_DIR/.env" bash -c '
        set +u
        source "$_SPP_ENV_FILE" 2>/dev/null || true
        for v in PERPLEXITY_API_KEY WIKI_PLATFORM ISSUE_TRACKER_TYPE; do
            val="${!v:-}"
            [[ -n "$val" ]] && printf "%s=%s\n" "$v" "$val"
        done
    ' 2>/dev/null) || true
    while IFS='=' read -r _key _val; do
        [[ -n "$_key" ]] && export "$_key=$_val"
    done <<< "$_env_vars"
    unset _env_vars _key _val
fi

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

    --check
        Validate prerequisites without installing anything. Reports the
        status of Node.js, git, obra/superpowers, and skill counts.

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
        --check) CHECK=true; shift ;;
        --force) FORCE=true; shift ;;
        --upgrade) UPGRADE=true; shift ;;
        --version) echo "install.sh version $VERSION"; exit 0 ;;
        *)
            printf '%b\n' "${RED}Error: Unknown option $1${NC}" >&2
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
    echo ""
    echo "Personal skills:"
    for skill_dir in "$SKILLS_DIR/"*/; do
        [[ -d "$skill_dir" ]] && { [[ -f "$skill_dir/SKILL.md" ]] || [[ -f "$skill_dir/skill.md" ]]; } && echo "  • $(basename "$skill_dir")"
    done
    echo ""
    echo "Optional integrations:"
    if [[ -n "${PERPLEXITY_API_KEY:-}" ]]; then
        printf '%b\n' "  ${GREEN}✓${NC} Perplexity research: configured"
    else
        echo "  • Perplexity research: ./setup/mcp-perplexity.sh"
    fi
    if [[ -n "${WIKI_PLATFORM:-}" ]]; then
        printf '%b\n' "  ${GREEN}✓${NC} Wiki: ${WIKI_PLATFORM}"
    else
        echo "  • Wiki: set WIKI_PLATFORM in .env (see skills/wiki/_adapters/)"
    fi
    if [[ -n "${ISSUE_TRACKER_TYPE:-}" ]]; then
        printf '%b\n' "  ${GREEN}✓${NC} Issue tracking: ${ISSUE_TRACKER_TYPE}"
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

# Check mode — validate prerequisites without installing
check_prerequisites() {
    log_info "Checking prerequisites for superpowers-plus..."
    local ok=0
    local fail=0

    # git
    if command -v git &>/dev/null; then
        log_success "git: $(git --version | head -1)"
        ok=$((ok + 1))
    else
        log_warn "git: NOT FOUND"
        fail=$((fail + 1))
    fi

    # Node.js (presence + version)
    if command -v node &>/dev/null; then
        local node_ver
        node_ver=$(node -v 2>/dev/null || echo "unknown")
        local node_major
        node_major=$(echo "$node_ver" | sed 's/^v//' | cut -d. -f1)
        if [[ "$node_major" -ge 18 ]] 2>/dev/null; then
            log_success "node: $node_ver (>= v18)"
            ok=$((ok + 1))
        else
            log_warn "node: $node_ver (NEED v18+)"
            fail=$((fail + 1))
        fi
    else
        log_warn "node: NOT FOUND"
        fail=$((fail + 1))
    fi

    # obra/superpowers (presence + git repo + skills/)
    if [[ -d "$SUPERPOWERS_DIR" ]]; then
        if ! _is_git_repo "$SUPERPOWERS_DIR"; then
            log_warn "obra/superpowers: exists but is NOT a git repo (use --force to reinstall)"
            fail=$((fail + 1))
        elif [[ ! -d "$SUPERPOWERS_DIR/skills" ]]; then
            log_warn "obra/superpowers: git repo exists but skills/ directory is missing (use --force to reinstall)"
            fail=$((fail + 1))
        else
            log_success "obra/superpowers: installed at $SUPERPOWERS_DIR (git repo)"
            ok=$((ok + 1))
        fi
    else
        log_warn "obra/superpowers: NOT INSTALLED (will be installed)"
    fi

    # Skills
    local skill_count
    skill_count=$(find "$SCRIPT_DIR/skills" -name "skill.md" 2>/dev/null | wc -l | tr -d ' ')
    log_success "skills available: $skill_count"

    # Deployment targets
    for target in "$SKILLS_DIR" "$CLAUDE_SKILLS_DIR"; do
        if [[ -d "$target" ]]; then
            log_success "target: $target (exists)"
        else
            log_verbose "target: $target (will be created)"
        fi
    done

    echo ""
    if [[ $fail -eq 0 ]]; then
        log_success "All prerequisites met ($ok checks passed)"
        return 0
    else
        log_warn "$fail prerequisite(s) missing ($ok passed)"
        return 1
    fi
}

# Main installation flow
main() {
    echo ""
    log_info "superpowers-plus installer"
    echo ""

    if [[ "$CHECK" == "true" ]]; then
        check_prerequisites
        exit $?
    fi

    # Check dependencies
    check_dependencies

    # Register the source repo path for doctor/source-aware tooling.
    register_source_repo

    # Handle --upgrade mode (explicit upgrade of existing installation)
    if [[ "$UPGRADE" == "true" ]]; then
        upgrade_existing
        # Reinstall personal skills, rules, templates after upgrade
        install_skills
        create_dir "$HOME/.codex/superpowers-review/active"
        create_dir "$HOME/.codex/superpowers-review/archive"
        post_install_migrations
        install_rules
        install_templates
        install_tools
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
    elif ! _is_git_repo "$SUPERPOWERS_DIR"; then
        # Directory exists with skills/ but is not a git repo — cannot update
        log_warn "obra/superpowers exists but is not a git repo: $SUPERPOWERS_DIR"
        log_warn "Cannot update or verify version. Run with --force to reinstall."
        error_exit "Unmanaged obra/superpowers installation detected"
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

    # Create code review protocol directory
    create_dir "$HOME/.codex/superpowers-review/active"
    create_dir "$HOME/.codex/superpowers-review/archive"

    # Run migrations (clean stale overrides, detect orphaned TODO.md)
    post_install_migrations

    # Install rules
    install_rules

    # Install templates
    install_templates

    # Install tools (todo-preflight.sh, todo-lock.sh, etc.)
    install_tools

    # Install adapter
    install_adapter

    # Validate
    validate_installation

    # Post-install health check (report only, non-blocking)
    # Skip if no skills are installed — doctor would report vacuous 0/0/0
    if [[ -f "$SCRIPT_DIR/tools/doctor-checks.sh" && -d "$HOME/.codex/skills" ]]; then
        local skill_count
        skill_count=$(find "$HOME/.codex/skills" -maxdepth 2 -name "skill.md" 2>/dev/null | wc -l | tr -d ' ')
        if [[ "$skill_count" -gt 0 ]]; then
            log_info "Running post-install health check..."
            "$SCRIPT_DIR/tools/doctor-checks.sh" --summary-only 2>&1 || true
        else
            log_info "Skipping health check — no skills installed yet"
        fi
    fi

    # Print summary
    print_summary
}

# Run main
main

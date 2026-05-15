#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Script: install.sh
# PURPOSE: Install superpowers-plus skills with platform detection, dependency
#          management, and multi-target deployment. Validates environment variables
#          and deploys skills to ~/.codex/skills/ and ~/.claude/skills/. All 14
#          obra/superpowers skills are bundled directly in the skills/ tree (v2.6.0+).
# USAGE: ./install.sh [options]
#        -h, --help      Show help message
#        -v, --verbose   Enable verbose output
#        -y, --yes       Auto-accept prompts (non-interactive mode)
#        --force         Overwrite existing skills without prompting
#        --upgrade       Pull latest changes before installing
#        --version       Show version number
# PLATFORM: macOS (Intel/Apple Silicon), Linux (Debian/Ubuntu, RHEL/Fedora, Arch), WSL
# VERSION: 2.6.0
# ARCHITECTURE: This file is a thin orchestrator. Implementation lives in
#               lib/install/*.sh modules, sourced in dependency order below.
# -----------------------------------------------------------------------------
set -euo pipefail

VERSION="2.6.0"

# --- Shell & Bash Version Guard ---
# Detect if accidentally run under /bin/sh, dash, zsh, etc.
if [ -z "${BASH_VERSION:-}" ]; then
    echo "ERROR: This script requires bash but is running under a different shell." >&2
    echo "  Fix: bash install.sh $*" >&2
    exit 1
fi

# This script requires bash 4+ for associative arrays (declare -A).
# macOS ships with bash 3.2 (Apple can't update past GPLv2 — frozen since 2007).
if [ "${BASH_VERSINFO[0]}" -lt 4 ]; then
    echo "" >&2
    echo "╔══════════════════════════════════════════════════════════════════╗" >&2
    echo "║  ERROR: bash ${BASH_VERSION} is too old — this installer needs bash 4+     ║" >&2
    echo "╠══════════════════════════════════════════════════════════════════╣" >&2
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "║  macOS ships bash 3.2 (frozen at GPLv2, circa 2007).           ║" >&2
        echo "║                                                                ║" >&2
        echo "║  Quick fix (one-time):                                         ║" >&2
        echo "║    brew install bash                                           ║" >&2
        echo "║                                                                ║" >&2
        echo "║  Then re-run with:                                             ║" >&2
        echo "║    /opt/homebrew/bin/bash install.sh                            ║" >&2
        echo "║  Or:                                                           ║" >&2
        echo "║    export PATH=\"/opt/homebrew/bin:\$PATH\"                       ║" >&2
        echo "║    bash install.sh                                             ║" >&2
        echo "║                                                                ║" >&2
        echo "║  No Homebrew? Install it first:                                ║" >&2
        echo "║    /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\"" >&2
    else
        echo "║  Install bash 4+ via your package manager:                     ║" >&2
        echo "║    Ubuntu/Debian:  sudo apt install bash                       ║" >&2
        echo "║    Fedora/RHEL:    sudo dnf install bash                       ║" >&2
        echo "║    Alpine:         apk add bash                                ║" >&2
    fi
    echo "╚══════════════════════════════════════════════════════════════════╝" >&2
    echo "" >&2
    exit 1
fi

# --- Early Prerequisite Check ---
# Fail fast with actionable messages before we get deep into the installer.
_missing_cmds=""
for _cmd in git node; do
    if ! command -v "$_cmd" &>/dev/null; then
        _missing_cmds="$_missing_cmds $_cmd"
    fi
done
if [[ -n "$_missing_cmds" ]]; then
    echo "" >&2
    echo "╔══════════════════════════════════════════════════════════════════╗" >&2
    echo "║  ERROR: Missing required commands:${_missing_cmds}                        " >&2
    echo "╠══════════════════════════════════════════════════════════════════╣" >&2
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "║  macOS fix:                                                    ║" >&2
        [[ "$_missing_cmds" == *git* ]]  && echo "║    xcode-select --install   (includes git)                      ║" >&2
        [[ "$_missing_cmds" == *node* ]] && echo "║    brew install node        (or: https://nodejs.org)             ║" >&2
    else
        echo "║  Linux fix:                                                    ║" >&2
        [[ "$_missing_cmds" == *git* ]]  && echo "║    sudo apt install git     (or yum/dnf/apk)                    ║" >&2
        [[ "$_missing_cmds" == *node* ]] && echo "║    sudo apt install nodejs  (or: https://nodejs.org)             ║" >&2
    fi
    echo "╚══════════════════════════════════════════════════════════════════╝" >&2
    echo "" >&2
    exit 1
fi
unset _missing_cmds _cmd

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CODEX_DIR="${HOME}/.codex"
SKILLS_DIR="${CODEX_DIR}/skills"

# Platform-specific skill deployment paths
# Claude Code: Native Skill tool reads from ~/.claude/skills/
CLAUDE_SKILLS_DIR="${HOME}/.claude/skills"
# Augment Agent: superpowers-augment.js reads from ~/.codex/skills/ (SKILLS_DIR above)
# Augment IDE slash menu: user-level ~/.agents/skills/ (curated subset only — SKILL.md format)
# Augment discovers skills here regardless of which workspace is open.
AUGMENT_MENU_DIR="${HOME}/.agents/skills"

# Options (set before sourcing modules so they can read these)
# shellcheck disable=SC2034  # FORCE read by lib/install/deploy.sh consumers
FORCE=false
VERBOSE=false
UPGRADE=false
CHECK=false
YES=false
# Skip all Augment-specific deployment steps. Off by default.
# Honors SKIP_AUGMENT env var so chain installers propagate without arg parsing.
# Track inheritance so we can warn if it came from the ambient env (CI leakage).
_SKIP_AUGMENT_FROM_ENV=false
[[ -n "${SKIP_AUGMENT:-}" ]] && _SKIP_AUGMENT_FROM_ENV=true
SKIP_AUGMENT="${SKIP_AUGMENT:-false}"

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
    # Cross-platform CRLF strip using explicit temp rewrites to avoid stray in-place temp files.
    find "$SCRIPT_DIR" -name "*.sh" -print0 | while IFS= read -r -d '' f; do
        mode="$(stat -f '%Lp' "$f" 2>/dev/null || stat -c '%a' "$f" 2>/dev/null || true)"
        tr -d '\r' < "$f" > "${f}.tmp"
        if [[ -n "$mode" ]]; then
            chmod "$mode" "${f}.tmp"
        elif [[ -x "$f" ]]; then
            chmod +x "${f}.tmp"
        fi
        mv "${f}.tmp" "$f"
    done
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
# superpowers.sh removed — obra/superpowers folded into skills tree in v2.6.0
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
    superpowers-plus ships 40+ skills for wiki editing, issue tracking, security
    audits, AI text quality, and engineering workflows. All 14 obra/superpowers
    skills (Jesse Vincent, MIT) are bundled directly in the skills/ tree as of
    v2.6.0 — no separate clone required.

    Deploys all skills to ~/.codex/skills/ and ~/.claude/skills/. Safe to run
    multiple times.

OPTIONS
    -h, --help
        Display this help message and exit

    -v, --verbose
        Show detailed progress information

    --upgrade, --update
        Explicitly upgrade an existing superpowers installation. Requires
        superpowers to already be installed. Shows before/after version
        comparison. Use with --force to discard local changes first.

    --force
        Without --upgrade: Remove and re-clone superpowers from scratch.
        With --upgrade: Reset local changes (git reset --hard, git clean -fd)
        before pulling latest updates.

    --check
        Validate prerequisites without installing anything. Reports the
        status of Node.js, git, superpowers-core, and skill counts.

    -y, --yes
        Auto-accept all prompts (e.g., dependency installation) without
        asking for confirmation. Also enabled automatically when stdin is
        not a TTY (e.g., when called from another script or via pipe).

    --skip-augment
        Skip all Augment-specific deployment steps. Claude Code still receives
        skills (~/.claude/skills/), but the following are skipped:
          - Augment skills directory   (~/.codex/skills/)
          - Augment slash menu         (~/.agents/skills/)
          - Augment adapter bridge     (~/.codex/superpowers-augment/)
          - Augment auto-loaded rules  (~/.augment/rules/)
        Off by default. Existing Augment artifacts are NOT cleaned up — remove
        them manually if you want a fully clean state. Honors the SKIP_AUGMENT
        environment variable, which chain installers use to propagate the flag.

    --version
        Display version information and exit

WHAT GETS INSTALLED
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

VERSION INFO
    Current: Run ./install.sh --version
    Check for updates: git fetch origin && git log --oneline HEAD..origin/main

AUTHOR
    Matt J Bordenet

SEE ALSO
    Repository: https://github.com/bordenet/superpowers-plus
    Changelog: https://github.com/bordenet/superpowers-plus/blob/main/CHANGELOG.md
    obra/superpowers upstream: https://github.com/obra/superpowers (Jesse Vincent, MIT)
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
        --upgrade|--update) UPGRADE=true; shift ;;
        --skip-augment) SKIP_AUGMENT=true; _SKIP_AUGMENT_FROM_ENV=false; shift ;;
        --version) echo "install.sh version $VERSION"; exit 0 ;;
        *)
            printf '%b\n' "${RED}Error: Unknown option $1${NC}" >&2
            echo "Use -h or --help for usage information" >&2
            exit 1
            ;;
    esac
done

# Lib modules (deploy.sh, etc.) read these via the environment so we
# don't have to thread them through every function signature.
# VERBOSE is read by logging.sh (log_verbose). YES is read by deps.sh.
export SKIP_AUGMENT VERBOSE YES

# Visibility for env-var inheritance: if the caller's environment had
# SKIP_AUGMENT=true and the user did NOT pass --skip-augment on the command line,
# emit a one-liner so the silent skip is observable (CI matrices, leaked direnv,
# etc.). Logging functions are already sourced.
if [[ "${SKIP_AUGMENT:-false}" == "true" ]] && [[ "$_SKIP_AUGMENT_FROM_ENV" == "true" ]]; then
    log_warn "SKIP_AUGMENT=true inherited from environment (no --skip-augment flag passed)"
    log_warn "  Augment-specific install steps will be skipped. Unset SKIP_AUGMENT to opt back in."
fi
unset _SKIP_AUGMENT_FROM_ENV

# --- Validate and Summarize (kept in orchestrator for visibility) ---

# Validate the installation
validate_installation() {
    log_info "Validating installation..."

    local errors=0

    # Check Augment skills directory (~/.codex/skills) — skipped when --skip-augment
    if [[ "${SKIP_AUGMENT:-false}" == "true" ]]; then
        log_verbose "Augment skills directory: skipped (--skip-augment)"
    elif [[ ! -d "$SKILLS_DIR" ]]; then
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
    if [[ "${SKIP_AUGMENT:-false}" != "true" ]]; then
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
    fi

    # Count Claude Code skills
    local claude_skill_count=0
    for skill_dir in "$CLAUDE_SKILLS_DIR/"*/; do
        if [[ -d "$skill_dir" ]] && { [[ -f "$skill_dir/SKILL.md" ]] || [[ -f "$skill_dir/skill.md" ]]; }; then
            claude_skill_count=$((claude_skill_count + 1))
        fi
    done
    log_verbose "Found $claude_skill_count personal skill(s) in Claude Code location"

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
    echo "  Claude Code:       $CLAUDE_SKILLS_DIR"
    echo "                     (native Skill tool)"
    echo ""
    if [[ "${SKIP_AUGMENT:-false}" == "true" ]]; then
        echo "  Augment:           skipped (--skip-augment)"
        echo ""
    else
        echo "  Augment Agent:     $SKILLS_DIR"
        echo "                     (superpowers-augment.js)"
        echo ""
        echo "  Augment slash menu: $AUGMENT_MENU_DIR"
        echo "                      (curated /sp-* commands)"
        echo ""
    fi
    echo "Personal skills:"
    # Source of truth for "what this installer just deployed" is the manifest
    # written by install_skills() — using $SKILLS_DIR directly mis-attributes
    # obra/superpowers core skills under --skip-augment (CLAUDE_SKILLS_DIR also
    # holds non-personal entries).
    local manifest="${HOME}/.codex/superpowers-plus/install-state/skills.manifest"
    if [[ -s "$manifest" ]]; then
        while IFS= read -r _name; do
            [[ -n "$_name" ]] && echo "  • $_name"
        done < "$manifest"
    else
        echo "  (none recorded — manifest not found)"
    fi
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
    if [[ "${SKIP_AUGMENT:-false}" != "true" ]]; then
        echo "  Augment Agent: node ~/.codex/superpowers-augment/superpowers-augment.js find-skills"
    fi
    echo ""
}

run_post_validation_checks() {
    # Ensure this source checkout has the current repo guardrails installed
    if git -C "$SCRIPT_DIR" rev-parse --git-dir >/dev/null 2>&1 && [[ -f "$SCRIPT_DIR/tools/install-hooks.sh" ]]; then
        log_info "Ensuring repo git hooks are installed..."
        if bash "$SCRIPT_DIR/tools/install-hooks.sh" >/dev/null 2>&1; then
            log_success "Repo git hooks installed"
        else
            log_warn "Could not install repo git hooks automatically"
            log_warn "Run: bash \"$SCRIPT_DIR/tools/install-hooks.sh\""
        fi
    fi

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
}

# Migrate consumed-approval records from the old session-env location to the new consumed/ dir.
# The red-autonomy hook moved consumed hashes in PR-4; this prevents replay of pre-upgrade tokens.
migrate_consumed_approvals() {
    local old_dir="$HOME/.claude/session-env"
    local new_dir="$HOME/.claude/consumed"
    if ! compgen -G "$old_dir/*.consumed-approvals.txt" >/dev/null 2>&1; then
        return 0
    fi
    mkdir -p "$new_dir"
    local f dest
    for f in "$old_dir"/*.consumed-approvals.txt; do
        dest="$new_dir/$(basename "$f")"
        if [[ -f "$dest" ]]; then
            # Destination already exists (hook wrote new records post-upgrade); merge to avoid overwrite.
            cat "$f" >> "$dest"
            rm -f "$f"
        else
            mv "$f" "$dest"
        fi
    done
    log_verbose "Migrated consumed-approval records to $new_dir"
}

# Install Claude Code lifecycle hooks and merge settings.json (kill-switched by default)
install_claude_guardrails() {
    local guardrails_script="$SCRIPT_DIR/setup/install-claude-guardrails.sh"
    if [[ ! -f "$guardrails_script" ]]; then
        log_warn "install-claude-guardrails.sh not found — skipping Claude hooks install"
        return 0
    fi
    if bash "$guardrails_script" >/dev/null 2>&1; then
        log_info "Claude Code guardrails: OK (SUPERPOWERS_CLAUDE_GUARDRAILS=${SUPERPOWERS_CLAUDE_GUARDRAILS:-0})"
    else
        log_warn "Claude Code guardrails installer exited non-zero — run manually:"
        log_warn "  bash setup/install-claude-guardrails.sh"
    fi
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

    # Skills
    local skill_count
    skill_count=$(find "$SCRIPT_DIR/skills" -name "skill.md" 2>/dev/null | wc -l | tr -d ' ')
    log_success "skills available: $skill_count"

    # Deployment targets
    local _targets=("$CLAUDE_SKILLS_DIR")
    if [[ "${SKIP_AUGMENT:-false}" != "true" ]]; then
        _targets=("$SKILLS_DIR" "${_targets[@]}")
    fi
    for target in "${_targets[@]}"; do
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

# Migration: remove the old obra/superpowers clone (folded into superpowers-plus in v2.6.0)
_migrate_remove_obra_clone() {
    local obra_dir="${HOME}/.codex/superpowers"
    if [[ -d "$obra_dir" ]]; then
        log_info "Removing legacy obra/superpowers clone (folded into superpowers-plus in v2.6.0)..."
        if rm -rf "${obra_dir:?}"; then
            log_success "Removed legacy obra clone: $obra_dir"
        else
            log_warn "Could not remove $obra_dir — remove manually"
        fi
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
        # Migration: remove the old obra/superpowers clone (folded into superpowers-plus in v2.6.0)
        _migrate_remove_obra_clone
        # Reinstall personal skills, rules, templates after upgrade
        install_skills
        create_dir "$HOME/.codex/superpowers-review/active"
        create_dir "$HOME/.codex/superpowers-review/archive"
        post_install_migrations
        if [[ "${SKIP_AUGMENT:-false}" != "true" ]]; then
            install_rules
            install_adapter
        else
            log_info "Skipping Augment rules + adapter (--skip-augment)"
        fi
        install_templates
        install_tools
        sync_managed_checkout
        validate_installation
        run_post_validation_checks
        migrate_consumed_approvals
        install_claude_commands_mirror
        install_claude_guardrails
        print_summary
        return
    fi

    # Migration: remove the old obra/superpowers clone (folded into superpowers-plus in v2.6.0)
    _migrate_remove_obra_clone

    # Install skills
    install_skills

    # Create code review protocol directory
    create_dir "$HOME/.codex/superpowers-review/active"
    create_dir "$HOME/.codex/superpowers-review/archive"

    # Run migrations (clean stale overrides, detect orphaned TODO.md)
    post_install_migrations

    # Install rules (Augment-only target — ~/.augment/rules/)
    if [[ "${SKIP_AUGMENT:-false}" != "true" ]]; then
        install_rules
    else
        log_info "Skipping Augment rules install (--skip-augment)"
    fi

    # NOT Augment-specific — runs in both modes (templates ship for all targets)
    install_templates

    # NOT Augment-specific — runs in both modes (todo-preflight, todo-lock, etc.)
    install_tools

    # NOT Augment-specific — runs in both modes (sp-update symlink for shell PATH)
    install_cli_commands

    # Install adapter (Augment-only — ~/.codex/superpowers-augment/)
    if [[ "${SKIP_AUGMENT:-false}" != "true" ]]; then
        install_adapter
    else
        log_info "Skipping Augment adapter install (--skip-augment)"
    fi

    # Sync managed checkout (~/.codex/superpowers-plus) if it exists
    sync_managed_checkout

    # Validate
    validate_installation
    run_post_validation_checks
    migrate_consumed_approvals
    install_claude_commands_mirror
    install_claude_guardrails

    # F5: Clean install-artifact permission drift.
    # install_tools copies to ~/.codex/superpowers-plus/tools/ and sets +x on those
    # files — the managed checkout tracks them as non-executable (100644), so every
    # install run leaves the managed checkout worktree dirty. git restore reverts the
    # permission-only changes without losing any content; the scripts remain functional.
    local _mgd="${CODEX_DIR}/superpowers-plus"
    if [[ -d "${_mgd}/.git" ]]; then
        git -C "$_mgd" restore . 2>/dev/null || true
    fi

    # Print summary
    print_summary
}

# Run main
main

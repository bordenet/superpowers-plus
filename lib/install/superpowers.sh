#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# lib/install/superpowers.sh
# PURPOSE: obra/superpowers git management — clone, update, upgrade, version check.
# SOURCED BY: install.sh — do not run directly.
# GLOBALS READ: SUPERPOWERS_DIR, SUPERPOWERS_REPO, CODEX_DIR, FORCE, VERBOSE
# REQUIRES: lib/install/logging.sh
# -----------------------------------------------------------------------------

# --- Version coordination ---
# Minimum obra/superpowers commit date (Unix timestamp) that this version of
# superpowers-plus is known to work with. Update this when obra/superpowers
# makes breaking changes that require a newer checkout.
# Current value: 2025-06-01 00:00:00 UTC (baseline — no known breaking change)
MIN_OBRA_COMMIT_EPOCH=1748736000

# Check if superpowers is installed (v4.2.0+ uses skills/ directory, not superpowers-codex)
check_superpowers() {
    if [[ -d "$SUPERPOWERS_DIR" ]] && [[ -d "$SUPERPOWERS_DIR/skills" ]]; then
        return 0
    fi
    return 1
}

# Verify obra/superpowers is recent enough for this version of superpowers-plus
check_obra_version() {
    if [[ ! -d "$SUPERPOWERS_DIR/.git" ]]; then
        log_verbose "Cannot check obra version: not a git repository"
        return 0
    fi
    local obra_epoch
    obra_epoch=$(cd "$SUPERPOWERS_DIR" && git log -1 --format='%ct' HEAD 2>/dev/null || echo "0")
    if [[ "$obra_epoch" -lt "$MIN_OBRA_COMMIT_EPOCH" ]]; then
        local obra_date
        obra_date=$(cd "$SUPERPOWERS_DIR" && git log -1 --format='%ci' HEAD 2>/dev/null || echo "unknown")
        log_warn "obra/superpowers checkout is older than expected"
        log_warn "  Installed commit date: $obra_date"
        log_warn "  Minimum required: $(date -r "$MIN_OBRA_COMMIT_EPOCH" '+%Y-%m-%d' 2>/dev/null || date -d "@$MIN_OBRA_COMMIT_EPOCH" '+%Y-%m-%d' 2>/dev/null || echo 'unknown')"
        log_warn "  Run: ./install.sh --upgrade --force   to update"
        return 1
    fi
    log_verbose "obra/superpowers version check: OK (commit epoch $obra_epoch >= $MIN_OBRA_COMMIT_EPOCH)"
    return 0
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

    log_verbose "Pulling latest changes from origin main"
    if ! (cd "$SUPERPOWERS_DIR" && git pull --ff-only origin main 2>&1); then
        # --ff-only failed — likely divergent history (upstream rewrite) or local changes
        log_warn "Fast-forward pull failed — attempting recovery..."
        if (cd "$SUPERPOWERS_DIR" && git fetch origin 2>&1 && git reset --hard origin/main 2>&1); then
            log_success "Recovered: reset to origin/main (upstream history may have been rewritten)"
        else
            local checkout_age
            checkout_age=$(cd "$SUPERPOWERS_DIR" && git log -1 --format='%cr' HEAD 2>/dev/null || echo "unknown")
            log_warn "Failed to update superpowers (may have local changes)"
            log_warn "Local checkout last updated: $checkout_age"
            log_warn "You may be running a stale version of obra/superpowers"
            return 1
        fi
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
        # --ff-only failed — try reset to origin/main (handles upstream history rewrites)
        log_warn "Fast-forward pull failed — attempting reset to origin/main..."
        if git reset --hard origin/main 2>&1; then
            log_success "Recovered: reset to origin/main (upstream history may have been rewritten)"
        else
            log_warn "Reset failed. Run with --upgrade --force to discard local changes and upgrade."
            exit 1
        fi
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

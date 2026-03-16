#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# lib/install/deps.sh
# PURPOSE: Dependency checking and installation (git, node) with cross-platform
#          package manager support.
# SOURCED BY: install.sh — do not run directly.
# GLOBALS READ: PLATFORM, LINUX_DISTRO, YES
# REQUIRES: lib/install/logging.sh, lib/install/platform.sh
# -----------------------------------------------------------------------------

# Map command names to distro-specific package names
# e.g., the 'node' command is provided by the 'nodejs' package on Linux
get_package_name() {
    local cmd="$1"
    case "$cmd" in
        node)
            case "$PLATFORM" in
                macos) echo "node" ;;       # Homebrew uses 'node'
                *)     echo "nodejs" ;;     # apt, dnf, yum, pacman, zypper use 'nodejs'
            esac
            ;;
        *) echo "$cmd" ;;  # git, curl, etc. are the same everywhere
    esac
}

# Install a single dependency using the appropriate package manager
install_dependency() {
    local cmd="$1"
    local pkg
    pkg=$(get_package_name "$cmd")
    log_info "Installing $pkg (provides '$cmd')..."

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

    # Auto-accept or prompt for confirmation
    if [[ "$YES" == "true" ]]; then
        log_info "Auto-installing missing dependencies (--yes or non-interactive mode)"
    else
        echo ""
        read -r -p "Install missing dependencies? [Y/n] " response
        case "$response" in
            [nN][oO]|[nN])
                error_exit "Cannot continue without: ${missing[*]}"
                ;;
        esac
    fi

    for dep in "${missing[@]}"; do
        if ! install_dependency "$dep"; then
            error_exit "Failed to install $dep"
        fi
    done

    log_verbose "All dependencies installed"

    # Verify Node.js version is sufficient
    check_node_version
}

# Verify Node.js version meets minimum requirement (v18+)
check_node_version() {
    local min_version=18
    local node_version_full node_major

    node_version_full=$(node -v 2>/dev/null || echo "")
    if [[ -z "$node_version_full" ]]; then
        # node command not found after install — install_dependency should have caught this
        return 0
    fi

    # Extract major version: v20.11.0 → 20
    node_major=$(echo "$node_version_full" | sed 's/^v//' | cut -d. -f1)

    if [[ "$node_major" -ge "$min_version" ]] 2>/dev/null; then
        log_verbose "Node.js $node_version_full (>= v${min_version}) ✓"
        return 0
    fi

    log_warn "Node.js $node_version_full is too old (need v${min_version}+)"

    case "$PLATFORM" in
        macos)
            log_warn "Run: brew upgrade node"
            ;;
        linux|wsl)
            case "$LINUX_DISTRO" in
                ubuntu|debian|pop|linuxmint)
                    log_warn "Ubuntu/Debian ship old Node.js. Install a modern version:"
                    log_warn "  curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -"
                    log_warn "  sudo apt-get install -y nodejs"
                    ;;
                fedora)
                    log_warn "Run: sudo dnf module install -y nodejs:20"
                    ;;
                *)
                    log_warn "Install Node.js v${min_version}+ from: https://nodejs.org/en/download"
                    ;;
            esac
            ;;
        *)
            log_warn "Install Node.js v${min_version}+ from: https://nodejs.org/en/download"
            ;;
    esac

    error_exit "Node.js v${min_version}+ is required. Found: $node_version_full"
}

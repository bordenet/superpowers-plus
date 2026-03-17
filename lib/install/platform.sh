#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# lib/install/platform.sh
# PURPOSE: Platform and OS detection (macOS, Linux, WSL, Windows).
# SOURCED BY: install.sh — do not run directly.
# GLOBALS READ: (none)
# GLOBALS SET: PLATFORM, LINUX_DISTRO
# REQUIRES: lib/install/logging.sh (for color variables)
# -----------------------------------------------------------------------------

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

# Run detection and set globals (consumed by parent installer)
PLATFORM=$(detect_platform)
export LINUX_DISTRO=""
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

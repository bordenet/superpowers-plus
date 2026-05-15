#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Script: install-augment-superpowers.sh
# PURPOSE: STANDALONE installer for superpowers with Augment Code
#          (Self-contained, can be run via curl-pipe-bash without cloning repo)
# USAGE: ./install-augment-superpowers.sh [-v|--verbose] [-h|--help]
#        curl -fsSL https://raw.githubusercontent.com/bordenet/superpowers-plus/main/install-augment-superpowers.sh | bash
# PLATFORM: macOS, Linux, WSL
# NOTE: For full superpowers-plus installation (all skills), use install.sh instead
# -----------------------------------------------------------------------------
set -euo pipefail

# --- Bash Version Guard ---
# This script works on bash 3.2+ but provide a clear error if running under
# something ancient or under /bin/sh by accident.
if [ -z "${BASH_VERSION:-}" ]; then
    echo "ERROR: This script requires bash. You appear to be running sh or another shell." >&2
    echo "  Fix: bash install-augment-superpowers.sh" >&2
    exit 1
fi
if [ "${BASH_VERSINFO[0]}" -lt 3 ]; then
    echo "ERROR: bash ${BASH_VERSION} is too old (need bash 3.2+)." >&2
    echo "  macOS fix:  brew install bash" >&2
    echo "  Linux fix:  sudo apt install bash  (or yum/dnf)" >&2
    exit 1
fi

# --- Configuration ---
VERSION="1.0.0"
SUPERPOWERS_PLUS_RAW="https://raw.githubusercontent.com/bordenet/superpowers-plus/main"
# Note: obra/superpowers skills are bundled in superpowers-plus as of v2.6.0.
# This installer no longer clones bordenet/superpowers separately.
VERBOSE=false

# --- Colors (disabled if not a TTY) ---
if [[ -t 1 ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    NC='\033[0m'
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    NC=''
fi

# --- Logging ---
info()    { printf '%b\n' "${BLUE}[INFO]${NC} $1"; }
success() { printf '%b\n' "${GREEN}[OK]${NC} $1"; }
warn()    { printf '%b\n' "${YELLOW}[WARN]${NC} $1"; }
error()   { printf '%b\n' "${RED}[ERROR]${NC} $1" >&2; exit 1; }
verbose() { [[ "$VERBOSE" == true ]] && printf '%b\n' "${BLUE}[DEBUG]${NC} $1" || true; }

# --- Help ---
show_help() {
    cat << 'EOF'
NAME
    install-augment-superpowers.sh - Install superpowers skill system for Augment Code

SYNOPSIS
    install-augment-superpowers.sh [OPTIONS]
    curl -fsSL https://raw.githubusercontent.com/bordenet/superpowers-plus/main/install-augment-superpowers.sh | bash

DESCRIPTION
    Installs the Augment adapter for superpowers-plus and configures it to work
    with Augment Code. This enables AI-assisted workflows with structured skills
    for brainstorming, debugging, TDD, and more.

    The installer is self-contained and can be run via curl pipe or directly.
    As of superpowers-plus v2.6.0, obra/superpowers skills are bundled directly
    in the superpowers-plus skills tree — no separate clone is required.

WHAT GETS INSTALLED
    ~/.codex/superpowers-augment/   Augment adapter (translates tool names)
    ~/.codex/skills/                Your personal skills directory (empty)
    ~/.augment/rules/               Augment auto-load rule

OPTIONS
    -h, --help
        Display this help message and exit

    -v, --verbose
        Show detailed progress information

    --version
        Display version information and exit

PREREQUISITES
    • git - For cloning the superpowers repository
    • node - For running the superpowers-augment adapter

EXAMPLES
    # Install with default settings
    ./install-augment-superpowers.sh

    # Install with verbose output
    ./install-augment-superpowers.sh --verbose

    # Install via curl (one-liner)
    curl -fsSL https://raw.githubusercontent.com/bordenet/superpowers-plus/main/install-augment-superpowers.sh | bash

POST-INSTALLATION
    1. Restart Augment (or start a new conversation)
    2. The superpowers system auto-loads via ~/.augment/rules/
    3. Ask Augment to run: node ~/.codex/superpowers-augment/superpowers-augment.js bootstrap

AUTHOR
    Matt J Bordenet

SEE ALSO
    https://github.com/bordenet/superpowers-plus
    https://github.com/obra/superpowers (Jesse Vincent, MIT — obra/superpowers upstream)
    https://augmentcode.com
EOF
    exit 0
}

# --- Argument Parsing ---
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help) show_help ;;
        -v|--verbose) VERBOSE=true; shift ;;
        --version) echo "install-augment-superpowers.sh version $VERSION"; exit 0 ;;
        *) echo "Unknown option: $1" >&2; echo "Use -h or --help for usage" >&2; exit 1 ;;
    esac
done

# --- Main Installation ---
echo ""
echo "=============================================="
echo "  Superpowers for Augment - Installer v$VERSION"
echo "=============================================="
echo ""

# Check prerequisites
info "Checking prerequisites..."
verbose "Looking for git and node in PATH"

# Detect platform for install hints
PLATFORM="unknown"
INSTALL_HINT="your package manager"
if [[ "$OSTYPE" == "darwin"* ]]; then
    PLATFORM="macOS"
    INSTALL_HINT="brew install"
elif [[ -f /etc/os-release ]] && grep -qi "microsoft\|wsl" /proc/version 2>/dev/null; then
    PLATFORM="WSL"
    INSTALL_HINT="sudo apt install"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    PLATFORM="Linux"
    INSTALL_HINT="sudo apt install"
fi
verbose "Detected platform: $PLATFORM"

if ! command -v git &> /dev/null; then
    error "git is required but not installed. Install with: $INSTALL_HINT git"
fi
success "git found"
verbose "git version: $(git --version)"

if ! command -v node &> /dev/null; then
    error "node is required but not installed. Install with: $INSTALL_HINT nodejs"
fi
success "node found ($(node --version))"

# Create directories
info "Creating directories..."
verbose "Creating ~/.codex/skills"
mkdir -p ~/.codex/skills
verbose "Creating ~/.augment/rules"
mkdir -p ~/.augment/rules
success "Directories created"

# Migration: remove the old obra/superpowers clone if present (folded into superpowers-plus in v2.6.0)
if [[ -d ~/.codex/superpowers ]]; then
    info "Removing legacy obra/superpowers clone (folded into superpowers-plus in v2.6.0)..."
    rm -rf ~/.codex/superpowers && success "Removed legacy obra clone" || warn "Could not remove ~/.codex/superpowers — remove manually"
fi

# Install superpowers-augment adapter
info "Installing superpowers-augment adapter..."
verbose "Creating ~/.codex/superpowers-augment directory"
mkdir -p ~/.codex/superpowers-augment
verbose "Writing superpowers-augment.js adapter script"

# Install the canonical adapter. Prefer a local checkout (when this installer is
# run from a clone) and fall back to fetching main from GitHub (curl-pipe-bash
# install path). The old approach embedded a stale copy of the adapter inline;
# that copy routinely drifted behind the canonical file and shipped broken
# releases (see incident in PR for context). Always use the upstream source.
#
# Stage to a temp file, node-check it, then atomic rename. This avoids
# leaving a partial/corrupt adapter at the target path when curl is killed,
# the network drops mid-transfer, or the canonical file itself is corrupt.
_adapter_target=~/.codex/superpowers-augment/superpowers-augment.js
# Keep the .js suffix so `node --check` can determine the module format
# (Node 22+ rejects files without a recognised extension).
_adapter_tmp="${_adapter_target%.js}.tmp.$$.js"
trap 'rm -f "$_adapter_tmp"' EXIT

_adapter_source_path="${BASH_SOURCE[0]:-}"
_adapter_staged=false
if [[ -n "$_adapter_source_path" && -f "$_adapter_source_path" ]]; then
    _adapter_script_dir="$(cd "$(dirname "$_adapter_source_path")" && pwd)"
    if [[ -f "$_adapter_script_dir/superpowers-augment.js" ]]; then
        verbose "Copying canonical adapter from local checkout: $_adapter_script_dir/superpowers-augment.js"
        cp "$_adapter_script_dir/superpowers-augment.js" "$_adapter_tmp"
        _adapter_staged=true
    fi
fi
if [[ "$_adapter_staged" != true ]]; then
    verbose "Fetching canonical adapter from ${SUPERPOWERS_PLUS_RAW}/superpowers-augment.js"
    if ! curl -fsSL "${SUPERPOWERS_PLUS_RAW}/superpowers-augment.js" -o "$_adapter_tmp"; then
        echo "ERROR: Failed to download canonical superpowers-augment.js from ${SUPERPOWERS_PLUS_RAW}" >&2
        exit 1
    fi
fi

# node is a hard prerequisite verified earlier in the installer, so this
# check always runs. A failure here indicates either a corrupt fetch or a
# local-checkout with a syntactically broken adapter — fail closed in either
# case, leaving the previously-installed adapter (if any) untouched.
if ! node --check "$_adapter_tmp" 2>/dev/null; then
    echo "ERROR: Staged superpowers-augment.js failed node --check (corrupt download or local file?)" >&2
    exit 1
fi

mv "$_adapter_tmp" "$_adapter_target"
trap - EXIT

chmod +x ~/.codex/superpowers-augment/superpowers-augment.js
success "Adapter installed"

# Create the Augment auto-load rule
info "Installing Augment auto-load rule..."
cat > ~/.augment/rules/superpowers.always.md << 'RULE_EOF'
# Superpowers Auto-Load Rule

<EXTREMELY_IMPORTANT>
You have superpowers skills installed. At the START of every conversation, run:

```bash
node ~/.codex/superpowers-augment/superpowers-augment.js bootstrap
```

This loads your available skills and the `using-superpowers` skill that governs how to use them.

## Quick Reference

**Key skills to invoke before work:**
- `superpowers:brainstorming` - Before ANY creative/feature work
- `superpowers:systematic-debugging` - Before fixing bugs
- `superpowers:test-driven-development` - Before writing implementation
- `superpowers:verification-before-completion` - Before claiming done
- `superpowers:writing-plans` - Before multi-step tasks

**To load a skill:**
```bash
node ~/.codex/superpowers-augment/superpowers-augment.js use-skill superpowers:<skill-name>
```

**To list all skills:**
```bash
node ~/.codex/superpowers-augment/superpowers-augment.js find-skills
```

## The Rule

IF A SKILL APPLIES TO YOUR TASK (even 1% chance), YOU MUST INVOKE IT.

This is not optional. Skills exist to ensure quality and consistency.
</EXTREMELY_IMPORTANT>
RULE_EOF
success "Augment rule installed"

# Verify installation
info "Verifying installation..."
verbose "Running post-install verification checks"
echo ""

# Test 1: Check adapter
verbose "Checking for superpowers-augment.js adapter"
if [[ -f ~/.codex/superpowers-augment/superpowers-augment.js ]]; then
    success "Augment adapter installed"
else
    error "Augment adapter not found"
fi

# Test 3: Check rule file
verbose "Checking for Augment auto-load rule"
if [[ -f ~/.augment/rules/superpowers.always.md ]]; then
    success "Augment auto-load rule installed"
else
    error "Augment rule not found"
fi

# Test 4: Run bootstrap to verify it works
info "Testing bootstrap command..."
verbose "Running: node ~/.codex/superpowers-augment/superpowers-augment.js bootstrap"
if node ~/.codex/superpowers-augment/superpowers-augment.js bootstrap > /dev/null 2>&1; then
    success "Bootstrap command works"
else
    error "Bootstrap command failed"
fi

# Test 5: List skills
info "Testing find-skills command..."
verbose "Running: node ~/.codex/superpowers-augment/superpowers-augment.js find-skills"
SKILL_COUNT=$(node ~/.codex/superpowers-augment/superpowers-augment.js find-skills 2>/dev/null | grep '^Summary:' | grep -oE '[0-9]+ total' | head -1 | grep -oE '[0-9]+' || echo "0")
if [[ "$SKILL_COUNT" -gt 0 ]]; then
    success "Found $SKILL_COUNT total installed skills"
else
    warn "No skills found (this may be normal for first install)"
fi

echo ""
echo "=============================================="
echo "  Installation Complete! ($PLATFORM)"
echo "=============================================="
echo ""
echo "Installed:"
echo "  • ~/.codex/superpowers-augment/  - Augment adapter"
echo "  • ~/.codex/skills/               - Your personal skills (empty)"
echo "  • ~/.augment/rules/              - Augment auto-load rule"
echo ""
echo "Next steps:"
echo "  1. Restart Augment (or start a new conversation)"
echo "  2. The superpowers system should auto-load"
echo "  3. Ask Augment to run: node ~/.codex/superpowers-augment/superpowers-augment.js bootstrap"
echo ""
echo "To add superpowers to a specific workspace:"
echo "  mkdir -p .augment/rules"
echo "  cp ~/.augment/rules/superpowers.always.md .augment/rules/"
echo ""

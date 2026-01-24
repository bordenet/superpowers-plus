#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Script: install-augment-superpowers.sh
# PURPOSE: Install the superpowers skill system for Augment Code
# USAGE: ./install-augment-superpowers.sh [-v|--verbose] [-h|--help]
#        curl -fsSL https://...install-augment-superpowers.sh | bash
# PLATFORM: macOS, Linux, WSL
# -----------------------------------------------------------------------------
set -euo pipefail

# --- Configuration ---
VERSION="1.0.0"
SUPERPOWERS_REPO="https://github.com/obra/superpowers.git"
VERBOSE=false

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# --- Logging ---
info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1" >&2; exit 1; }
verbose() { [[ "$VERBOSE" == true ]] && echo -e "${BLUE}[DEBUG]${NC} $1" || true; }

# --- Help ---
show_help() {
    cat << 'EOF'
NAME
    install-augment-superpowers.sh - Install superpowers skill system for Augment Code

SYNOPSIS
    install-augment-superpowers.sh [OPTIONS]
    curl -fsSL https://raw.githubusercontent.com/bordenet/scripts/main/install-augment-superpowers.sh | bash

DESCRIPTION
    Installs the superpowers skill system (from obra/superpowers) and configures
    it to work with Augment Code. This enables AI-assisted workflows with
    structured skills for brainstorming, debugging, TDD, and more.

    The installer is self-contained and can be run via curl pipe or directly.

WHAT GETS INSTALLED
    ~/.codex/superpowers/           Superpowers core (cloned from obra/superpowers)
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
    curl -fsSL https://raw.githubusercontent.com/bordenet/scripts/main/install-augment-superpowers.sh | bash

POST-INSTALLATION
    1. Restart Augment (or start a new conversation)
    2. The superpowers system auto-loads via ~/.augment/rules/
    3. Ask Augment to run: node ~/.codex/superpowers-augment/superpowers-augment.js bootstrap

AUTHOR
    Matt J Bordenet

SEE ALSO
    https://github.com/obra/superpowers
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

# Install superpowers (obra/superpowers)
if [[ -d ~/.codex/superpowers/.git ]]; then
    info "Superpowers already installed, updating..."
    verbose "Running git pull in ~/.codex/superpowers"
    pushd ~/.codex/superpowers > /dev/null
    git pull --quiet origin main 2>/dev/null || git pull --quiet origin master 2>/dev/null || warn "Could not update superpowers"
    popd > /dev/null
    success "Superpowers updated"
else
    info "Installing superpowers from obra/superpowers..."
    verbose "Cloning $SUPERPOWERS_REPO to ~/.codex/superpowers"
    rm -rf ~/.codex/superpowers 2>/dev/null || true
    git clone --quiet "$SUPERPOWERS_REPO" ~/.codex/superpowers
    success "Superpowers installed"
fi

# Install superpowers-augment adapter
info "Installing superpowers-augment adapter..."
verbose "Creating ~/.codex/superpowers-augment directory"
mkdir -p ~/.codex/superpowers-augment
verbose "Writing superpowers-augment.js adapter script"

# Create the adapter script
cat > ~/.codex/superpowers-augment/superpowers-augment.js << 'ADAPTER_EOF'
#!/usr/bin/env node
/**
 * superpowers-augment.js - Adapter for Augment Code
 * Wraps superpowers-codex and transforms tool references for Augment
 */
const { execSync } = require('child_process');
const path = require('path');
const os = require('os');

const homeDir = os.homedir();
const superpowersCodex = path.join(homeDir, '.codex', 'superpowers', '.codex', 'superpowers-codex');

const TOOL_MAPPINGS = [
    [/\bTodoWrite\b/g, 'add_tasks/update_tasks'],
    [/\bTodoRead\b/g, 'view_tasklist'],
    [/\bTask\b tool with subagents/g, 'Note: Augment does not have subagents - do the work directly'],
    [/\bTask\b tool/g, 'launch-process (or handle directly)'],
    [/\bRead\b tool/g, 'view tool'],
    [/\bWrite\b tool/g, 'save-file tool'],
    [/\bEdit\b tool/g, 'str-replace-editor tool'],
    [/`Read`/g, '`view`'],
    [/`Write`/g, '`save-file`'],
    [/`Edit`/g, '`str-replace-editor`'],
    [/\bBash\b tool/g, 'launch-process tool'],
    [/`Bash`/g, '`launch-process`'],
    [/Skill tool/g, 'superpowers-augment use-skill command'],
    [/superpowers-codex/g, 'superpowers-augment'],
];

function transformOutput(text) {
    let result = text;
    for (const [pattern, replacement] of TOOL_MAPPINGS) {
        result = result.replace(pattern, replacement);
    }
    return result;
}

function runCommand(command, args) {
    try {
        const fullCommand = `node "${superpowersCodex}" ${command} ${args.join(' ')}`;
        const output = execSync(fullCommand, { encoding: 'utf8', cwd: homeDir, stdio: ['pipe', 'pipe', 'pipe'] });
        return transformOutput(output);
    } catch (error) {
        if (error.stdout) return transformOutput(error.stdout);
        throw error;
    }
}

const command = process.argv[2];
const args = process.argv.slice(3);

switch (command) {
    case 'bootstrap': console.log(runCommand('bootstrap', args)); break;
    case 'use-skill': console.log(runCommand('use-skill', args)); break;
    case 'find-skills': console.log(runCommand('find-skills', args)); break;
    default:
        console.log('Superpowers for Augment\n');
        console.log('Usage:');
        console.log('  node superpowers-augment.js bootstrap');
        console.log('  node superpowers-augment.js use-skill <skill-name>');
        console.log('  node superpowers-augment.js find-skills');
        break;
}
ADAPTER_EOF

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

# Test 1: Check superpowers repo
verbose "Checking for superpowers-codex script"
if [[ -f ~/.codex/superpowers/.codex/superpowers-codex ]]; then
    success "Superpowers core installed"
else
    error "Superpowers core not found"
fi

# Test 2: Check adapter
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
SKILL_COUNT=$(node ~/.codex/superpowers-augment/superpowers-augment.js find-skills 2>/dev/null | grep -c "^superpowers:" || echo "0")
if [[ "$SKILL_COUNT" -gt 0 ]]; then
    success "Found $SKILL_COUNT skills"
else
    warn "No skills found (this may be normal for first install)"
fi

echo ""
echo "=============================================="
echo "  Installation Complete! ($PLATFORM)"
echo "=============================================="
echo ""
echo "Installed:"
echo "  • ~/.codex/superpowers/          - Core skill library"
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

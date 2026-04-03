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
SUPERPOWERS_REPO="https://github.com/obra/superpowers.git"
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
    curl -fsSL https://raw.githubusercontent.com/bordenet/superpowers-plus/main/install-augment-superpowers.sh | bash

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
# Use -e (not -d) to support git worktrees where .git is a file
if [[ -e ~/.codex/superpowers/.git ]]; then
    info "Superpowers already installed, updating..."
    verbose "Running git pull in ~/.codex/superpowers"
    pushd ~/.codex/superpowers > /dev/null
    if ! git pull --ff-only --quiet origin main 2>/dev/null; then
        # --ff-only failed — warn instead of silently resetting (prevents data loss)
        verbose "Fast-forward failed, trying master branch..."
        if ! git pull --ff-only --quiet origin master 2>/dev/null; then
            warn "Could not update superpowers (fast-forward failed)"
            warn "To reset manually: cd ~/.codex/superpowers && git fetch && git reset --hard origin/main"
        fi
    fi
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

# Create the self-contained adapter script (compatible with obra/superpowers v4.2.0+)
cat > ~/.codex/superpowers-augment/superpowers-augment.js << 'ADAPTER_EOF'
#!/usr/bin/env node
/**
 * superpowers-augment.js - Skill loader for Augment Code
 * Replaces the old superpowers-codex wrapper with direct skill discovery
 * Compatible with obra/superpowers v4.2.0+
 */
const fs = require('fs');
const path = require('path');
const os = require('os');

const homeDir = os.homedir();
const SUPERPOWERS_SKILLS_DIR = path.join(homeDir, '.codex', 'superpowers', 'skills');
const PERSONAL_SKILLS_DIR = path.join(homeDir, '.codex', 'skills');

const TOOL_MAPPINGS = [
    [/\bTodoWrite\b/g, 'todo-crud.sh (add/complete/move/defer) — NEVER use str-replace-editor or save-file on TODO.md. Run: ~/.codex/superpowers-plus/tools/todo-crud.sh add -p P2 -d "description" -t "#tag"'],
    [/\bTodoRead\b/g, 'todo-crud.sh cat (full file) or todo-crud.sh list (filtered) — NEVER use view tool on TODO.md directly. Run: ~/.codex/superpowers-plus/tools/todo-crud.sh cat'],
    [/Task tool with superpowers:code-reviewer type/g, 'sub-agent-code-reviewer tool'],
    [/Task tool \(superpowers:code-reviewer\):/g, 'sub-agent-code-reviewer tool:'],
    [/Dispatch superpowers:code-reviewer subagent/g, 'Dispatch sub-agent-code-reviewer'],
    [/\bcode-reviewer subagent\b/g, 'sub-agent-code-reviewer'],
    [/\bcode reviewer subagent\b/g, 'sub-agent-code-reviewer'],
    [/Dispatch final code-reviewer/g, 'Dispatch final sub-agent-code-reviewer'],
    [/\bTask\b tool(?! with superpowers:code-reviewer type| \(superpowers:code-reviewer\))/g, 'launch-process (or handle directly)'],
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

function extractFrontmatter(filePath) {
    try {
        const content = fs.readFileSync(filePath, 'utf8');
        const lines = content.replace(/\r\n/g, '\n').replace(/\r/g, '\n').split('\n');
        let inFrontmatter = false;
        let name = '';
        let description = '';
        let triggers = [];
        let requires_mcp = [];
        let triggerAccum = null;
        let mcpAccum = null;

        // State-machine parser for YAML inline arrays — handles apostrophes
        // inside double-quoted strings. Keep in sync with mcp/superpowers-mcp.js.
        function parseInlineArray(value) {
            const inner = value.replace(/^\s*\[/, '').replace(/\]\s*$/, '');
            const items = [];
            let idx = 0;
            while (idx < inner.length) {
                while (idx < inner.length && (inner[idx] === ' ' || inner[idx] === ',' || inner[idx] === '\t')) idx++;
                if (idx >= inner.length) break;
                const quote = inner[idx];
                if (quote === '"' || quote === "'") {
                    let val = '';
                    idx++;
                    while (idx < inner.length) {
                        if (quote === '"' && inner[idx] === '\\' && idx + 1 < inner.length) { val += inner[idx + 1]; idx += 2; }
                        else if (quote === "'" && inner[idx] === "'" && idx + 1 < inner.length && inner[idx + 1] === "'") { val += "'"; idx += 2; }
                        else if (inner[idx] === quote) { idx++; break; }
                        else { val += inner[idx]; idx++; }
                    }
                    if (val) items.push(val);
                } else {
                    let val = '';
                    while (idx < inner.length && inner[idx] !== ',') { val += inner[idx]; idx++; }
                    val = val.trim();
                    if (val) items.push(val);
                }
            }
            return items;
        }

        function hasUnquotedClosingBracket(s) {
            let inQuote = null;
            for (let ci = 0; ci < s.length; ci++) {
                const c = s[ci];
                if (c === '\\' && inQuote && ci + 1 < s.length) { ci++; continue; }
                if (inQuote) { if (c === inQuote) inQuote = null; continue; }
                if (c === '"' || c === "'") { inQuote = c; continue; }
                if (c === ']') return true;
            }
            return false;
        }

        function extractBracketContent(s) {
            const start = s.indexOf('[');
            if (start === -1) return '';
            let inQuote = null;
            for (let ci = start + 1; ci < s.length; ci++) {
                const c = s[ci];
                if (c === '\\' && inQuote && ci + 1 < s.length) { ci++; continue; }
                if (inQuote) { if (c === inQuote) inQuote = null; continue; }
                if (c === '"' || c === "'") { inQuote = c; continue; }
                if (c === ']') return s.slice(start + 1, ci);
            }
            return s.slice(start + 1);
        }

        function unquoteYaml(s) {
            if (s.startsWith('"') && s.endsWith('"'))
                return s.slice(1, -1).replace(/\\"/g, '"').replace(/\\\\/g, '\\');
            if (s.startsWith("'") && s.endsWith("'"))
                return s.slice(1, -1).replace(/''/g, "'");
            return s;
        }

        function parseYamlList(lines, startIndex) {
            const values = [];
            let nextIndex = startIndex;
            for (let li = startIndex + 1; li < lines.length; li++) {
                const itemMatch = lines[li].match(/^\s+-\s+(.+)$/);
                if (itemMatch) {
                    values.push(unquoteYaml(itemMatch[1].trim()));
                    nextIndex = li;
                    continue;
                }
                if (lines[li].trim() === '') { nextIndex = li; continue; }
                break;
            }
            return { values, nextIndex };
        }

        for (let i = 0; i < lines.length; i++) {
            const line = lines[i];
            if (line.trim() === '---') {
                if (inFrontmatter) break;
                inFrontmatter = true;
                continue;
            }
            if (inFrontmatter) {
                // Handle bracket-multiline accumulation
                if (triggerAccum !== null) {
                    if (line.match(/^\w+:(?:[^/]|$)/)) { triggerAccum = null; }  // abandon on new YAML key
                    else {
                        triggerAccum += ' ' + line.trim();
                        if (hasUnquotedClosingBracket(triggerAccum)) {
                            triggers = parseInlineArray(extractBracketContent(triggerAccum));
                            triggerAccum = null;
                        }
                        continue;
                    }
                }
                if (mcpAccum !== null) {
                    if (line.match(/^\w+:(?:[^/]|$)/)) { mcpAccum = null; }      // abandon on new YAML key
                    else {
                        mcpAccum += ' ' + line.trim();
                        if (hasUnquotedClosingBracket(mcpAccum)) {
                            requires_mcp = parseInlineArray(extractBracketContent(mcpAccum));
                            mcpAccum = null;
                        }
                        continue;
                    }
                }

                // Triggers — 3 forms
                if (line.match(/^triggers:\s*\[/)) {
                    if (hasUnquotedClosingBracket(line.slice(line.indexOf('[') + 1))) {
                        triggers = parseInlineArray(extractBracketContent(line));
                    } else {
                        triggerAccum = line;
                    }
                } else if (line.match(/^triggers:\s*$/)) {
                    const parsed = parseYamlList(lines, i);
                    triggers = parsed.values;
                    i = parsed.nextIndex;
                }

                // requires_mcp — same 3 forms
                if (line.match(/^requires_mcp:\s*\[/)) {
                    if (hasUnquotedClosingBracket(line.slice(line.indexOf('[') + 1))) {
                        requires_mcp = parseInlineArray(extractBracketContent(line));
                    } else {
                        mcpAccum = line;
                    }
                } else if (line.match(/^requires_mcp:\s*$/)) {
                    const parsed = parseYamlList(lines, i);
                    requires_mcp = parsed.values;
                    i = parsed.nextIndex;
                }

                const match = line.match(/^(\w+):\s*(.+)$/);
                if (match) {
                    const key = match[1];
                    let value = unquoteYaml(match[2].trim());
                    if (key === 'name') name = value;
                    if (key === 'description') description = value;
                }
            }
        }
        return { name, description, triggers, requires_mcp };
    } catch (error) {
        return { name: '', description: '', triggers: [], requires_mcp: [] };
    }
}

function findSkillFile(dir) {
    const candidates = ['SKILL.md', 'skill.md'];
    for (const filename of candidates) {
        const filepath = path.join(dir, filename);
        if (fs.existsSync(filepath)) return filepath;
    }
    return null;
}

function findSkillsInDir(dir, sourceType) {
    const skills = [];
    if (!fs.existsSync(dir)) return skills;
    const entries = fs.readdirSync(dir, { withFileTypes: true });
    for (const entry of entries) {
        // Skip support directories (_shared, _archive, _adapters, etc.)
        if (entry.name.startsWith('_') || entry.name.startsWith('.')) continue;
        const skillDir = path.join(dir, entry.name);
        // Handle both directories and symlinks to directories
        let isDir = false;
        try {
            isDir = entry.isDirectory() || (entry.isSymbolicLink() && fs.statSync(skillDir).isDirectory());
        } catch (err) {
            if (err.code === 'ENOENT' || err.code === 'ELOOP') continue;
            throw err;
        }
        if (!isDir) continue;
        const skillFile = findSkillFile(skillDir);
        if (skillFile) {
            const meta = extractFrontmatter(skillFile);
            skills.push({
                name: meta.name || entry.name,
                description: meta.description || '',
                sourceType,
                skillFile,
                skillDir
            });
        }
    }
    return skills;
}

function stripFrontmatter(content) {
    const lines = content.replace(/\r\n/g, '\n').replace(/\r/g, '\n').split('\n');
    let inFrontmatter = false;
    let frontmatterEnded = false;
    const contentLines = [];
    for (const line of lines) {
        if (line.trim() === '---') {
            if (inFrontmatter) { frontmatterEnded = true; continue; }
            inFrontmatter = true;
            continue;
        }
        if (frontmatterEnded || !inFrontmatter) {
            contentLines.push(line);
        }
    }
    return contentLines.join('\n').trim();
}

function findSkills() {
    console.log('Available skills:');
    console.log('==================\n');
    const personalSkills = findSkillsInDir(PERSONAL_SKILLS_DIR, 'personal');
    const superpowersSkills = findSkillsInDir(SUPERPOWERS_SKILLS_DIR, 'superpowers');
    const allSkills = [...personalSkills, ...superpowersSkills];
    const seen = new Set();
    for (const skill of allSkills) {
        const displayName = skill.sourceType === 'superpowers' ? 'superpowers:' + skill.name : skill.name;
        if (seen.has(skill.name)) continue;
        seen.add(skill.name);
        console.log(displayName);
        if (skill.description) {
            console.log('  ' + skill.description + '\n');
        } else {
            console.log();
        }
    }
    console.log('Usage:');
    console.log('  superpowers-augment use-skill <skill-name>   # Load a specific skill\n');
    console.log('Skill naming:');
    console.log('  Superpowers skills: superpowers:skill-name (from ~/.codex/superpowers/skills/)');
    console.log('  Personal skills: skill-name (from ~/.codex/skills/)');
    console.log('  Personal skills override superpowers skills when names match.\n');
    console.log('Note: All skills are disclosed at session start via bootstrap.');
}

function useSkill(skillName) {
    if (!skillName) {
        console.error('Error: skill name required');
        console.error('Usage: superpowers-augment use-skill <skill-name>');
        process.exit(1);
    }
    const forceSuperpowers = skillName.startsWith('superpowers:');
    const actualName = forceSuperpowers ? skillName.replace(/^superpowers:/, '') : skillName;
    let skillFile = null;
    if (!forceSuperpowers) {
        const personalDir = path.join(PERSONAL_SKILLS_DIR, actualName);
        const personalFile = findSkillFile(personalDir);
        if (personalFile) skillFile = personalFile;
    }
    if (!skillFile) {
        const superpowersDir = path.join(SUPERPOWERS_SKILLS_DIR, actualName);
        const superpowersFile = findSkillFile(superpowersDir);
        if (superpowersFile) skillFile = superpowersFile;
    }
    if (!skillFile) {
        console.error('Error: Skill "' + skillName + '" not found');
        console.error('Run "superpowers-augment find-skills" to see available skills');
        process.exit(1);
    }
    const content = fs.readFileSync(skillFile, 'utf8');
    const stripped = stripFrontmatter(content);
    const transformed = transformOutput(stripped);
    console.log('# Skill: ' + skillName + '\n');
    console.log(transformed);
}

function bootstrap() {
    console.log('# Superpowers Bootstrap\n');
    console.log('Loading skill system for Augment Code...\n');
    const usingSuperpowersFile = findSkillFile(path.join(SUPERPOWERS_SKILLS_DIR, 'using-superpowers'));
    if (usingSuperpowersFile) {
        const content = fs.readFileSync(usingSuperpowersFile, 'utf8');
        const stripped = stripFrontmatter(content);
        const transformed = transformOutput(stripped);
        console.log(transformed);
        console.log('\n---\n');
    }
    findSkills();
}

const command = process.argv[2];
const args = process.argv.slice(3);

switch (command) {
    case 'bootstrap': bootstrap(); break;
    case 'use-skill': useSkill(args[0]); break;
    case 'find-skills': findSkills(); break;
    default:
        console.log('Superpowers for Augment\n');
        console.log('Usage:');
        console.log('  node superpowers-augment.js bootstrap      # Initialize session with skills');
        console.log('  node superpowers-augment.js use-skill <n>  # Load a specific skill');
        console.log('  node superpowers-augment.js find-skills    # List all available skills');
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

# Test 1: Check superpowers skills directory (v4.2.0+ no longer has superpowers-codex)
verbose "Checking for superpowers skills directory"
if [[ -d ~/.codex/superpowers/skills ]]; then
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

#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Script: mcp-perplexity.sh
# PURPOSE: Configure the Perplexity MCP server across all detected AI clients:
#          Claude Desktop (macOS), Claude Code CLI, and Augment Code.
# USAGE: ./setup/mcp-perplexity.sh [--yes] [--dry-run] [--verbose]
# PLATFORM: macOS, Linux, WSL
# VERSION: 2.0.0
# REQUIRES: jq, PERPLEXITY_API_KEY (env var, ~/.codex/.env, or prompt)
# API KEY: https://www.perplexity.ai/settings/api
# -----------------------------------------------------------------------------

set -euo pipefail

# --- Bash Guard ---
if [ -z "${BASH_VERSION:-}" ]; then
    echo "ERROR: This script requires bash. Run with: bash $0" >&2
    exit 1
fi

# --- Flags ---
ASSUME_YES=false
DRY_RUN=false
VERBOSE=false
for arg in "$@"; do
    case "$arg" in
        -h|--help)
            cat << 'HELP'
mcp-perplexity.sh — Configure Perplexity MCP server for AI assistants

USAGE
  ./setup/mcp-perplexity.sh [--yes] [--dry-run] [--verbose]

OPTIONS
  -y, --yes       Non-interactive; requires PERPLEXITY_API_KEY already set
                  in the environment or ~/.codex/.env.
  -n, --dry-run   Show what would change without writing files or invoking
                  external commands that modify state.
  -v, --verbose   Print resolved paths, jq operations, and detection results.
  -h, --help      Show this help message.

DESCRIPTION
  Configures the Perplexity MCP server in every detected client:
    - Claude Desktop (macOS) via claude_desktop_config.json (jq merge)
    - Claude Code CLI via `claude mcp add`
    - Augment Code via ~/.augment/settings.json (jq merge; idempotent)

  API key resolution order:
    1. $PERPLEXITY_API_KEY in current environment
    2. PERPLEXITY_API_KEY=... in ~/.codex/.env
    3. Interactive prompt (unless --yes)

  On first run, offers to persist the key to ~/.codex/.env so it survives
  reboots and is picked up by superpowers-augment.js.

  Get API key: https://www.perplexity.ai/settings/api
HELP
            exit 0
            ;;
        -y|--yes) ASSUME_YES=true ;;
        -n|--dry-run) DRY_RUN=true ;;
        -v|--verbose) VERBOSE=true ;;
        *) echo "ERROR: unknown option: $arg (try --help)" >&2; exit 2 ;;
    esac
done

# Colors
if [[ -t 1 ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    BLUE='\033[0;34m'
    BOLD='\033[1m'
    NC='\033[0m'
else
    RED='' GREEN='' YELLOW='' BLUE='' BOLD='' NC=''
fi

# Logging
log_info() { printf '%b\n' "${BLUE}[INFO]${NC} $1"; }
log_success() { printf '%b\n' "${GREEN}[OK]${NC} $1"; }
log_warn() { printf '%b\n' "${YELLOW}[WARN]${NC} $1"; }
log_error() { printf '%b\n' "${RED}[ERROR]${NC} $1"; }

# Configuration
CLAUDE_DESKTOP_CONFIG="$HOME/Library/Application Support/Claude/claude_desktop_config.json"
AUGMENT_SETTINGS="$HOME/.augment/settings.json"
CODEX_ENV="$HOME/.codex/.env"
MCP_PACKAGE="@perplexity-ai/mcp-server"

# --- Prerequisite: jq ---
if ! command -v jq &>/dev/null; then
    log_error_early() { printf '%b\n' "[ERROR] $1" >&2; }
    log_error_early "jq is required but not installed."
    log_error_early "  macOS:  brew install jq"
    log_error_early "  Linux:  apt install jq   (or yum/dnf/apk)"
    exit 1
fi

# --- Verbose helper ---
vlog() { [[ "$VERBOSE" == true ]] && printf '%b\n' "${BLUE}[DEBUG]${NC} $1" || true; }

# --- Key resolution: env var → ~/.codex/.env → prompt ---
load_key_from_env_file() {
    [[ -f "$CODEX_ENV" ]] || return 1
    # Parse `KEY=val`, `KEY="val"`, `KEY='val'`, or `export KEY=val`; tolerates
    # inline `# comments` outside of quoted values. First match wins.
    local raw
    raw=$(awk '
        /^[[:space:]]*(export[[:space:]]+)?PERPLEXITY_API_KEY[[:space:]]*=/ {
            sub(/^[[:space:]]*(export[[:space:]]+)?PERPLEXITY_API_KEY[[:space:]]*=[[:space:]]*/, "");
            gsub(/^["\047]|["\047][[:space:]]*(#.*)?$/, "");
            sub(/[[:space:]]+#.*$/, "");
            print;
            exit
        }' "$CODEX_ENV")
    [[ -n "$raw" ]] || return 1
    PERPLEXITY_API_KEY="$raw"
    export PERPLEXITY_API_KEY
    vlog "Loaded PERPLEXITY_API_KEY from $CODEX_ENV"
    return 0
}

echo ""
printf '%b\n' "${BOLD}Perplexity MCP Server Setup${NC}"
echo "================================"
echo ""

# Get API key
if [[ -z "${PERPLEXITY_API_KEY:-}" ]]; then
    if load_key_from_env_file; then
        log_info "Using API key from $CODEX_ENV"
    elif [[ "$ASSUME_YES" == true ]]; then
        log_error "PERPLEXITY_API_KEY not set and --yes specified (no prompt allowed)."
        log_error "  export PERPLEXITY_API_KEY=... or add it to $CODEX_ENV"
        exit 1
    else
        printf '%b\n' "${YELLOW}Get your API key from:${NC} https://www.perplexity.ai/settings/api"
        echo ""
        read -rsp "Enter your Perplexity API key: " PERPLEXITY_API_KEY
        echo ""
        echo ""
    fi
fi

if [[ -z "${PERPLEXITY_API_KEY:-}" ]]; then
    log_error "API key is required"
    exit 1
fi

# Offer to persist key to ~/.codex/.env (so superpowers-augment.js picks it up)
persist_key_to_env_file() {
    # Already there?
    if [[ -f "$CODEX_ENV" ]] && grep -qE '^[[:space:]]*(export[[:space:]]+)?PERPLEXITY_API_KEY[[:space:]]*=' "$CODEX_ENV"; then
        vlog "$CODEX_ENV already contains PERPLEXITY_API_KEY; not modifying"
        return 0
    fi
    if [[ "$ASSUME_YES" != true ]]; then
        local reply=""
        read -rp "Persist PERPLEXITY_API_KEY to $CODEX_ENV? [Y/n] " reply
        [[ -z "$reply" || "$reply" =~ ^[Yy] ]] || { vlog "User declined persisting key"; return 0; }
    fi
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[dry-run] would append PERPLEXITY_API_KEY to $CODEX_ENV"
        return 0
    fi
    mkdir -p "$(dirname "$CODEX_ENV")"
    touch "$CODEX_ENV"
    chmod 600 "$CODEX_ENV" 2>/dev/null || true
    printf 'PERPLEXITY_API_KEY=%q\n' "$PERPLEXITY_API_KEY" >> "$CODEX_ENV"
    log_success "Persisted PERPLEXITY_API_KEY to $CODEX_ENV"
}
persist_key_to_env_file

# Track what was configured
configured=()

# -----------------------------------------------------------------------------
# Shared helper: idempotently merge the Perplexity MCP server block into a
# JSON config file that uses the standard { "mcpServers": { ... } } shape.
# Creates the file (and parent directory) if absent; preserves all existing
# keys and other MCP servers. Creates a .backup sibling on first modification.
#
# $1 = absolute path to config file
# $2 = human label for logging (e.g. "Claude Desktop")
# -----------------------------------------------------------------------------
_merge_perplexity_into_json() {
    local config_path="$1"
    local label="$2"

    vlog "Target: $config_path ($label)"

    if [[ "$DRY_RUN" == true ]]; then
        log_info "[dry-run] would merge perplexity MCP into $config_path"
        configured+=("$label (dry-run)")
        return 0
    fi

    mkdir -p "$(dirname "$config_path")"

    # Seed empty JSON object if file is missing or blank
    if [[ ! -s "$config_path" ]]; then
        printf '{}' > "$config_path"
    fi

    # Validate existing JSON; abort loudly if corrupt so we don't overwrite
    if ! jq empty "$config_path" 2>/dev/null; then
        log_error "$config_path exists but is not valid JSON; refusing to overwrite."
        log_error "  Fix or remove the file, then re-run."
        return 1
    fi

    # Backup (one-shot; don't clobber existing .backup)
    [[ -f "${config_path}.backup" ]] || cp "$config_path" "${config_path}.backup"

    # Create the temp file SIBLING to the target so mv is a same-filesystem
    # rename (atomic). Using $TMPDIR would degrade to copy+unlink when HOME
    # is on a different volume than /tmp.
    local tmp
    tmp=$(mktemp "${config_path}.XXXXXX")
    chmod 600 "$tmp" 2>/dev/null || true
    # shellcheck disable=SC2064
    trap "rm -f '$tmp'" RETURN

    jq \
        --arg pkg "$MCP_PACKAGE" \
        --arg key "$PERPLEXITY_API_KEY" \
        '
        (.mcpServers //= {}) |
        .mcpServers.perplexity = {
            "command": "npx",
            "args": ["-y", $pkg],
            "env": { "PERPLEXITY_API_KEY": $key }
        }
        ' "$config_path" > "$tmp"

    mv "$tmp" "$config_path"
    chmod 600 "$config_path" 2>/dev/null || true
    log_success "$label configured ($config_path)"
    configured+=("$label")
}

# --- Claude Desktop ---
configure_claude_desktop() {
    log_info "Checking for Claude Desktop..."
    if [[ ! -d "/Applications/Claude.app" ]]; then
        log_warn "Claude Desktop not found at /Applications/Claude.app"
        return 1
    fi
    _merge_perplexity_into_json "$CLAUDE_DESKTOP_CONFIG" "Claude Desktop"
}

# --- Claude Code CLI ---
configure_claude_code() {
    log_info "Checking for Claude Code CLI..."

    if ! command -v claude &>/dev/null; then
        log_warn "Claude Code CLI not found"
        return 1
    fi

    # Already registered?
    if claude mcp list 2>/dev/null | grep -qE '^[[:space:]]*perplexity[[:space:]]*:'; then
        log_info "Claude Code CLI already has 'perplexity' registered; skipping"
        configured+=("Claude Code CLI (existing)")
        return 0
    fi

    if [[ "$DRY_RUN" == true ]]; then
        log_info "[dry-run] would run: claude mcp add -s user -e PERPLEXITY_API_KEY=*** perplexity -- npx -y $MCP_PACKAGE"
        configured+=("Claude Code CLI (dry-run)")
        return 0
    fi

    # Modern syntax: `claude mcp add [options] <name> -- <command> [args...]`
    # -s user  → user scope (available across projects)
    # -e KEY=V → environment variable passed to the server
    #
    # Capture exit status explicitly; piping through `grep -vE '^$'` would
    # return non-zero when `claude mcp add` succeeds silently (no stdout),
    # misreporting success as failure.
    local add_out
    if add_out=$(claude mcp add \
            -s user \
            -e "PERPLEXITY_API_KEY=$PERPLEXITY_API_KEY" \
            perplexity \
            -- npx -y "$MCP_PACKAGE" 2>&1); then
        [[ -n "$add_out" ]] && printf '%s\n' "$add_out" >&2
        log_success "Claude Code CLI configured"
        configured+=("Claude Code CLI")
    else
        [[ -n "$add_out" ]] && printf '%s\n' "$add_out" >&2
        log_warn "claude mcp add failed; may already exist under a different scope"
        return 1
    fi
}

# --- Augment Code ---
# The Augment VS Code extension reads MCP servers from ~/.augment/settings.json
# (documented at https://docs.augmentcode.com/setup-augment/mcp). We merge the
# perplexity block in place so existing servers and other settings keys survive.
configure_augment() {
    log_info "Configuring Augment Code..."
    _merge_perplexity_into_json "$AUGMENT_SETTINGS" "Augment Code"
}

# --- Main ---
main() {
    configure_claude_desktop || true
    configure_claude_code || true
    configure_augment || true

    # Summary
    echo ""
    printf '%b\n' "${BOLD}Summary${NC}"
    echo "-------"
    if [[ ${#configured[@]} -gt 0 ]]; then
        printf '%b\n' "${GREEN}Configured:${NC}"
        for item in "${configured[@]}"; do
            echo "  ✓ $item"
        done
    else
        log_warn "No clients were configured. Install at least one of:"
        echo "    - Claude Desktop (/Applications/Claude.app)"
        echo "    - Claude Code CLI (\`claude\` on PATH)"
        echo "    - Augment Code (writes $AUGMENT_SETTINGS)"
    fi
    echo ""
    echo "Restart the AI client for changes to take effect."
    echo ""
    printf '%b\n' "${YELLOW}Security reminder:${NC} your API key is stored in local config files."
    echo "These files are mode 0600 where possible. Do not commit them."
    echo ""

    # Run the verifier to confirm everything is good
    local verify_script
    verify_script="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/verify-perplexity-setup.sh"
    if [[ -x "$verify_script" && "$DRY_RUN" != true ]]; then
        echo "Running verification..."
        "$verify_script" || log_warn "Verification reported issues; see output above."
    fi
}

main

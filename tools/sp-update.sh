#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# tools/sp-update.sh
# PURPOSE: Self-update superpowers-plus from upstream. Fetches the specified
#          branch, fast-forward merges, and re-runs the installer to deploy
#          updated skills, tools, rules, and templates.
# USAGE: sp-update [--branch <name>] [--verbose] [--force] [--help]
# INSTALLED TO: ~/.codex/superpowers-plus/tools/sp-update.sh
# SYMLINKED TO: /usr/local/bin/sp-update (by install.sh)
# -----------------------------------------------------------------------------
set -euo pipefail

# --- Colors (disabled if not a terminal) ---
if [[ -t 1 ]]; then
    RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'
    BLUE='\033[0;34m'; NC='\033[0m'
else
    RED=''; GREEN=''; YELLOW=''; BLUE=''; NC=''
fi

log_info()    { printf '%b\n' "${BLUE}[INFO]${NC} $1"; }
log_success() { printf '%b\n' "${GREEN}[OK]${NC} $1"; }
log_warn()    { printf '%b\n' "${YELLOW}[WARN]${NC} $1"; }
log_error()   { printf '%b\n' "${RED}[ERROR]${NC} $1" >&2; }

# --- Resolve managed checkout ---
resolve_managed_dir() {
    # 1. SPP_SOURCE_DIR from ~/.codex/.env
    if [[ -f "$HOME/.codex/.env" ]]; then
        local env_val
        env_val=$(bash -c 'set +u; source "$1" 2>/dev/null; printf "%s" "${SPP_SOURCE_DIR:-}"' -- "$HOME/.codex/.env") || true
        if [[ -n "$env_val" && -d "$env_val/.git" ]]; then
            printf '%s' "$env_val"
            return 0
        fi
    fi
    # 2. Fallback to ~/.codex/superpowers-plus
    local fallback="$HOME/.codex/superpowers-plus"
    if [[ -d "$fallback/.git" ]]; then
        printf '%s' "$fallback"
        return 0
    fi
    return 1
}

# --- Help ---
show_help() {
    cat << 'EOF'
NAME
    sp-update - Update superpowers-plus from upstream

SYNOPSIS
    sp-update [OPTIONS]

OPTIONS
    --branch <name>   Branch to update (default: current branch)
    --force           Reset local changes before updating (git reset --hard)
    --verbose, -v     Show detailed progress
    --help, -h        Show this help

EXAMPLES
    sp-update                       # Update current branch
    sp-update --branch staging      # Switch to and update staging
    sp-update --branch dev --force  # Force-update dev, discarding local changes
EOF
    exit 0
}

# --- Argument parsing ---
BRANCH=""
FORCE=false
VERBOSE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help) show_help ;;
        -v|--verbose) VERBOSE=true; shift ;;
        --force) FORCE=true; shift ;;
        --branch)
            [[ -z "${2:-}" ]] && { log_error "--branch requires a value"; exit 1; }
            BRANCH="$2"; shift 2 ;;
        *)
            log_error "Unknown option: $1"
            echo "Use --help for usage information" >&2
            exit 1 ;;
    esac
done

# --- Main ---
main() {
    local managed_dir
    managed_dir=$(resolve_managed_dir) || {
        log_error "Cannot find superpowers-plus checkout."
        log_error "Run install.sh first, or set SPP_SOURCE_DIR in ~/.codex/.env"
        exit 1
    }

    log_info "Managed checkout: $managed_dir"
    cd "$managed_dir"

    # Determine upstream remote (prefer 'upstream', fall back to 'origin')
    local remote="origin"
    if git remote | grep -q '^upstream$'; then
        remote="upstream"
    fi

    # Determine branch
    local current_branch
    current_branch=$(git rev-parse --abbrev-ref HEAD)
    local target_branch="${BRANCH:-$current_branch}"

    log_info "Remote: $remote | Branch: $target_branch"

    # Fetch
    log_info "Fetching $remote..."
    git fetch "$remote" "$target_branch" --quiet || {
        log_error "Failed to fetch $remote/$target_branch"
        exit 1
    }

    # Switch branch if needed
    if [[ "$target_branch" != "$current_branch" ]]; then
        log_info "Switching from $current_branch to $target_branch..."
        git checkout "$target_branch" --quiet || {
            log_error "Failed to checkout $target_branch"
            exit 1
        }
    fi

    # Force reset if requested
    if [[ "$FORCE" == "true" ]]; then
        log_warn "Force mode: resetting to $remote/$target_branch"
        git reset --hard "$remote/$target_branch" --quiet
        git clean -fd --quiet
    fi

    # Fast-forward merge
    local before_sha
    before_sha=$(git rev-parse --short HEAD)

    if git merge-base --is-ancestor HEAD "$remote/$target_branch" 2>/dev/null; then
        git merge --ff-only "$remote/$target_branch" --quiet || {
            log_error "Fast-forward merge failed. Use --force to reset."
            exit 1
        }
    else
        log_error "Local branch has diverged from $remote/$target_branch."
        log_error "Use --force to reset, or resolve manually."
        exit 1
    fi

    local after_sha
    after_sha=$(git rev-parse --short HEAD)

    if [[ "$before_sha" == "$after_sha" ]]; then
        log_success "Already up to date ($after_sha)"
    else
        log_success "Updated: $before_sha → $after_sha"
        if [[ "$VERBOSE" == "true" ]]; then
            git log --oneline "${before_sha}..${after_sha}" | head -20
        fi
    fi

    # Re-run installer to deploy updated skills/tools/rules
    log_info "Re-deploying skills, tools, and rules..."
    local install_args=("--yes")
    [[ "$VERBOSE" == "true" ]] && install_args+=("--verbose")

    if [[ -f "$managed_dir/install.sh" ]]; then
        bash "$managed_dir/install.sh" "${install_args[@]}"
    else
        log_warn "install.sh not found — skipping re-deploy"
    fi

    log_success "sp-update complete"
}

main "$@"

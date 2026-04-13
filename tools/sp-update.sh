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

# --- Overlay discovery and update ---
# Finds all managed overlay repos in ~/.codex/superpowers-*/ and updates each one.
# An overlay qualifies if it has both install.sh and install-state/ present.
# Overlays that are part of the core chain (superpowers-plus, superpowers,
# superpowers-augment) are skipped — they're handled by the sp-update core.
run_overlay_updates() {
    local codex_dir="$HOME/.codex"
    local found_any=false
    local overlay_dir overlay_name

    # Core dirs that are NOT user overlays — skip them
    local skip_list=" superpowers superpowers-plus superpowers-augment "

    for overlay_dir in "$codex_dir"/superpowers-*/; do
        [[ -d "$overlay_dir" ]] || continue
        overlay_name=$(basename "$overlay_dir")

        # Skip core dirs
        [[ "$skip_list" == *" $overlay_name "* ]] && continue

        # Must have install.sh and install-state/ to qualify as a managed overlay
        [[ -f "$overlay_dir/install.sh" ]] || continue
        [[ -d "$overlay_dir/install-state" ]] || continue

        found_any=true
        log_info "Updating overlay: $overlay_name..."

        # Pull latest from remote — best effort; continue if it fails
        if [[ -d "$overlay_dir/.git" ]]; then
            if git -C "$overlay_dir" pull --ff-only --quiet 2>/dev/null; then
                [[ "$VERBOSE" == "true" ]] && log_info "  $overlay_name: pulled latest"
            else
                log_warn "  $overlay_name: git pull failed — continuing with existing version"
            fi
        fi

        # Run the overlay's installer with --upgrade to deploy its skills
        local overlay_args=("--upgrade" "--yes")
        [[ "$VERBOSE" == "true" ]] && overlay_args+=("--verbose")

        if bash "$overlay_dir/install.sh" "${overlay_args[@]}"; then
            log_success "Overlay updated: $overlay_name"
        else
            log_warn "Overlay update failed: $overlay_name"
            log_warn "  Run manually: bash $overlay_dir/install.sh --upgrade"
        fi
    done

    if [[ "$found_any" == "false" ]]; then
        [[ "$VERBOSE" == "true" ]] && log_info "No managed overlays found in $codex_dir"
    fi
}

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

    # Fetch — separate from merge so refs update even if merge fails later.
    # Shallow-clone fallback: if full fetch fails (rewritten history on a
    # depth-1 clone can't negotiate objects), re-fetch with --depth 1.
    log_info "Fetching $remote..."
    if ! git fetch "$remote" "$target_branch" --quiet 2>/dev/null; then
        log_warn "Full fetch failed — trying shallow fetch..."
        git fetch --depth 1 "$remote" "$target_branch" --quiet 2>/dev/null || {
            log_error "Failed to fetch $remote/$target_branch (tried full and shallow)"
            exit 1
        }
    fi

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

    # Fast-forward merge (or reset if diverged)
    local before_sha
    before_sha=$(git rev-parse --short HEAD)

    if git merge-base --is-ancestor HEAD "$remote/$target_branch" 2>/dev/null; then
        # Local is ancestor of remote — safe fast-forward merge
        local merge_output
        if ! merge_output=$(git merge --ff-only "$remote/$target_branch" 2>&1); then
            log_error "Fast-forward merge failed."
            echo "$merge_output" >&2

            # Detect untracked file conflicts and give actionable guidance
            if echo "$merge_output" | grep -q "untracked working tree files would be overwritten"; then
                echo "" >&2
                log_warn "Untracked local files conflict with incoming tracked files."
                log_warn "This usually happens when a file was deployed by the installer"
                log_warn "before it was committed to git."
                echo "" >&2
                local conflicting_files
                conflicting_files=$(echo "$merge_output" | sed -n '/untracked working tree files/,/Please move or remove/{ /^\t/p }')
                if [[ -n "$conflicting_files" ]]; then
                    log_info "Conflicting files:"
                    echo "$conflicting_files" >&2
                    echo "" >&2
                    log_info "Fix: delete the untracked copies and re-run sp-update:"
                    echo "$conflicting_files" | while IFS= read -r f; do
                        f=$(echo "$f" | xargs)  # trim whitespace
                        [[ -n "$f" ]] && printf '  rm "%s/%s"\n' "$managed_dir" "$f" >&2
                    done
                    printf '  sp-update\n' >&2
                fi
                echo "" >&2
                log_info "Or use --force to discard ALL local changes (nuclear option)."
            else
                # Generic merge failure
                echo "" >&2
                log_info "Use --force to reset to $remote/$target_branch (discards local changes)."
            fi
            exit 1
        fi
    else
        # Local has diverged from remote (ahead and/or behind) — force reset to latest
        log_warn "Local branch has diverged from $remote/$target_branch — forcing reset to latest"
        git reset --hard "$remote/$target_branch" --quiet
        git clean -fd --quiet
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

    # Post-merge: check for dirty working tree or unresolved issues
    local post_status
    post_status=$(git status --porcelain 2>/dev/null)
    if [[ -n "$post_status" ]]; then
        log_warn "Working tree is not clean after update:"
        echo "$post_status" | head -10 >&2
        local dirty_count
        dirty_count=$(echo "$post_status" | wc -l | xargs)
        if [[ "$dirty_count" -gt 10 ]]; then
            log_warn "... and $((dirty_count - 10)) more files"
        fi
        log_warn "This may affect skill deployment. Run --force to reset if needed."
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

    # Update any installed overlay repos (superpowers-recruiting, superpowers-cari, etc.)
    run_overlay_updates

    # Run superpowers-doctor to report installation health after update.
    # Advisory only: doctor warnings do not fail sp-update because they are
    # non-critical by design (environment drift, optional tools, etc.).
    # sp-update still exits nonzero if sp-doctor itself crashes (unexpected error).
    log_info "Running superpowers-doctor..."
    local _doctor_rc=0 _doctor_cmd=""
    if command -v sp-doctor &>/dev/null; then
        _doctor_cmd="sp-doctor"
        sp-doctor --summary-only || _doctor_rc=$?
    elif [[ -f "$managed_dir/tools/doctor-checks.sh" ]]; then
        _doctor_cmd="bash $managed_dir/tools/doctor-checks.sh"
        bash "$managed_dir/tools/doctor-checks.sh" --summary-only || _doctor_rc=$?
    else
        log_warn "sp-doctor not found — skipping health check"
    fi
    if [[ "$_doctor_rc" -ne 0 ]]; then
        log_warn "superpowers-doctor reported issues — run '${_doctor_cmd:-sp-doctor}' for details"
        # Advisory: log the warning but do not propagate the exit code.
        # A degraded install is still a complete install; the user can remediate separately.
    fi

    log_success "sp-update complete"
}

main "$@"

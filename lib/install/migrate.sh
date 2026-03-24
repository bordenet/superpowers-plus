#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# lib/install/migrate.sh
# PURPOSE: Post-install migrations — clean stale overrides, detect orphaned files.
#          All migrations are idempotent (safe to run multiple times).
# SOURCED BY: install.sh — do not run directly.
# GLOBALS READ: SUPERPOWERS_DIR, SKILLS_DIR
# REQUIRES: lib/install/logging.sh
# NOTE: These migrations were introduced in v2.5.0 for the todo-management
#       deterministic path migration. They will be removed around v2.8.0
#       once the migration period has elapsed.
# -----------------------------------------------------------------------------

# Guard: this module must be sourced by install.sh, not run directly.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "ERROR: This is a library module. Run install.sh instead." >&2
    exit 1
fi

post_install_migrations() {
    log_verbose "Running post-install migrations..."
    migrate_todo_skill_overrides
    detect_orphaned_todo_files
}

# Migration: Clean stale todo-management overrides from ~/.codex/superpowers/skills/
#
# Problem: Adopter repos sometimes copy a stale
# todo-management override into ~/.codex/superpowers/skills/, which is meant to
# be managed by obra/superpowers only. This stale copy lacks the deterministic
# default path and dual-persistence fixes. When the skill loader sees both copies,
# it may use the wrong one.
#
# Fix: If ~/.codex/superpowers/skills/todo-management/skill.md exists AND its
# source field says it came from something other than obra/superpowers, remove it.
# The authoritative copy at ~/.codex/skills/todo-management/ (deployed by this
# installer) will take precedence.
migrate_todo_skill_overrides() {
    local obra_skill="$SUPERPOWERS_DIR/skills/todo-management/skill.md"

    # Only act if the file exists
    [[ -f "$obra_skill" ]] || return 0

    # Check if it's a stale override (source != superpowers, not obra-native)
    local source_field
    source_field=$(grep -m1 '^source:' "$obra_skill" 2>/dev/null | sed 's/^source:[[:space:]]*//' || echo "")

    case "$source_field" in
        ""|superpowers|obra)
            # This is a legitimate obra/superpowers-native skill — leave it
            return 0
            ;;
        *)
            # This is a stale override from an adopter
            log_warn "Found stale todo-management override in obra directory (source: $source_field)"
            log_info "Removing stale override from $SUPERPOWERS_DIR/skills/todo-management/"
            rm -rf "${SUPERPOWERS_DIR:?}/skills/todo-management" || {
                log_warn "Could not remove stale override (permission denied?)"
                return 0
            }
            log_success "Cleaned stale todo-management override"
            ;;
    esac

    # Also check personal skills directory (~/.codex/skills/) for stale overrides.
    # Defense-in-depth: if an adopter previously deployed a stale copy here,
    # clean it before this installer deploys the correct version.
    local personal_skill="$SKILLS_DIR/todo-management/skill.md"
    [[ -f "$personal_skill" ]] || return 0

    local personal_source
    personal_source=$(grep -m1 '^source:' "$personal_skill" 2>/dev/null | sed 's/^source:[[:space:]]*//' || echo "")

    case "$personal_source" in
        ""|superpowers|obra|superpowers-plus)
            # Legitimate — leave it (will be overwritten by this installer anyway)
            return 0
            ;;
        *)
            log_warn "Found stale todo-management override in personal skills (source: $personal_source)"
            log_info "Removing stale override from $SKILLS_DIR/todo-management/"
            rm -rf "${SKILLS_DIR:?}/todo-management" || {
                log_warn "Could not remove stale override (permission denied?)"
                return 0
            }
            log_success "Cleaned stale todo-management override from personal skills"
            ;;
    esac
}

# Migration: Detect orphaned TODO.md files from previous installs
#
# Problem: Before the deterministic default ($HOME/.codex/TODO.md), agents guessed
# paths from the skill examples (~/Documents/TODO.md) or workspace roots
# (~/GitHub/*/TODO.md). These files may contain real task data that won't be found
# by the new default path.
#
# Fix: Scan known locations, report findings, suggest consolidation. Never delete.
detect_orphaned_todo_files() {
    local default_path="$HOME/.codex/TODO.md"
    # Extract TODO_FILE_PATH from ~/.codex/.env if configured there.
    # Source in a subshell to prevent .env from mutating installer shell state.
    local env_path=""
    if [[ -f "$HOME/.codex/.env" ]]; then
        env_path=$(_SPP_ENV_FILE="$HOME/.codex/.env" bash -c '
            set +u
            source "$_SPP_ENV_FILE" 2>/dev/null || true
            printf "%s" "${TODO_FILE_PATH:-}"
        ' 2>/dev/null) || true
    fi
    local -a candidates=()
    local -a found=()

    # Candidate locations where agents may have created TODO.md
    candidates=(
        "$HOME/Documents/TODO.md"
        "$HOME/TODO.md"
    )

    # Also check common workspace roots (non-recursive, fast)
    # Covers both ~/GitHub/repo/ and ~/GitHub/owner/repo/ layouts
    local git_dir
    for git_dir in "$HOME/GitHub"/*/ "$HOME/GitHub"/*/*/ \
                   "$HOME/Projects"/*/ "$HOME/repos"/*/ \
                   "$HOME/git"/*/; do
        [[ -f "${git_dir}TODO.md" ]] && candidates+=("${git_dir}TODO.md")
    done

    # Check each candidate
    for candidate in "${candidates[@]}"; do
        # Skip the default path and the env path — those aren't orphaned
        [[ "$candidate" == "$default_path" ]] && continue
        [[ -n "$env_path" ]] && [[ "$candidate" == "$env_path" ]] && continue
        # Skip template files
        [[ "$candidate" == *"/templates/"* ]] && continue
        [[ "$candidate" == *"/superpowers-plus/"* ]] && continue
        # Skip files inside .codex (skill-internal TODO.md files)
        [[ "$candidate" == *"/.codex/"* ]] && continue
        # Skip TODO.md files that are tracked by git — those are intentional
        # project files. Untracked TODO.md inside git repos ARE reported
        # (agents often create these at repo roots).
        local candidate_dir
        candidate_dir="$(dirname "$candidate")"
        if git -C "$candidate_dir" ls-files --error-unmatch "$(basename "$candidate")" &>/dev/null; then
            continue
        fi

        if [[ -f "$candidate" ]]; then
            found+=("$candidate")
        fi
    done

    # Nothing found — all clean
    [[ ${#found[@]} -eq 0 ]] && return 0

    # Report findings
    echo ""
    log_warn "Found TODO.md file(s) outside the default location:"
    echo ""
    for f in "${found[@]}"; do
        local size
        size=$(wc -c < "$f" 2>/dev/null | tr -d ' ')
        local lines
        lines=$(wc -l < "$f" 2>/dev/null | tr -d ' ')
        echo "  📄 $f ($lines lines, $size bytes)"
    done
    echo ""
    echo "  The default TODO.md location is now: $default_path"
    echo ""
    echo "  To consolidate, you can:"
    echo "    1. Move:  mv <old-path> $default_path"
    echo "    2. Point: add TODO_FILE_PATH=\"<old-path>\" to ~/.codex/.env"
    echo "    3. Ignore: leave as-is (agents will use $default_path going forward)"
    echo ""
}

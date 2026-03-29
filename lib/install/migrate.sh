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
    deploy_todo_honeypot
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

# Migration: Deploy honeypot at ~/.codex/TODO.md when the real TODO lives elsewhere
#
# Problem: Agents hardcode ~/.codex/TODO.md as the TODO path instead of using
# todo-crud.sh to resolve it. When the real TODO lives at a custom path (set via
# TODO_FILE_PATH in ~/.codex/.env or ~/.codex/.todo-registry), agents create a
# stray file at ~/.codex/TODO.md with raw writes (cat >, save-file, echo >),
# bypassing locking, backup, and structural validation.
#
# Fix: When the resolved TODO path is something OTHER than ~/.codex/TODO.md,
# deploy a read-only, immutable honeypot at ~/.codex/TODO.md.
#
# Skip: If the resolved path IS ~/.codex/TODO.md, do nothing — that's the
# user's real TODO file.
#
# Marker: Uses "THIS IS NOT THE REAL TODO FILE" to match todo-preflight.sh
# detection logic (tools/todo-preflight.sh:200).
deploy_todo_honeypot() {
    local honeypot_path="$HOME/.codex/TODO.md"
    # Canonical marker — must match tools/todo-preflight.sh honeypot detection
    local marker="THIS IS NOT THE REAL TODO FILE"
    local resolved_path=""

    # Resolve TODO path in a SUBSHELL to avoid mutating installer state.
    # resolve-env-path.sh sources ~/.codex/.env, which can set +u, alter PATH,
    # or change shell options. Must not leak into the live installer process.
    local resolver
    resolver="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/tools/resolve-env-path.sh"
    if [[ -f "$resolver" ]]; then
        resolved_path=$(bash -c '
            source "$1" 2>/dev/null || exit 1
            resolve_env
            resolve_path "TODO_FILE_PATH" "$2"
        ' -- "$resolver" "$honeypot_path") || {
            log_warn "Failed to resolve TODO path — skipping honeypot deployment"
            return 0
        }
    else
        log_warn "resolve-env-path.sh not found — skipping honeypot deployment"
        return 0
    fi

    # If resolved path equals the default, skip — that IS their real file
    if [[ "$resolved_path" == "$honeypot_path" ]]; then
        log_verbose "TODO path resolves to default ($honeypot_path) — skipping honeypot"
        return 0
    fi

    # If ~/.codex/TODO.md already exists, check what it is
    if [[ -f "$honeypot_path" ]]; then
        # Already our honeypot? Done.
        if grep -q "$marker" "$honeypot_path" 2>/dev/null; then
            log_verbose "TODO honeypot already deployed at $honeypot_path"
            return 0
        fi

        # Non-honeypot file exists — NEVER overwrite. Warn and bail.
        local line_count
        line_count=$(wc -l < "$honeypot_path" 2>/dev/null | tr -d ' ')
        log_warn "Found non-honeypot TODO.md at $honeypot_path ($line_count lines)"
        log_warn "Real TODO is at: $resolved_path"
        log_warn "Review and merge manually, then delete $honeypot_path and re-run install"
        return 0
    fi

    # Deploy honeypot — file does not exist yet
    log_info "Deploying TODO honeypot at $honeypot_path (real TODO: $resolved_path)"

    # Write to a temp file, set perms, then move atomically
    local tmp_honeypot
    tmp_honeypot="$(mktemp "$HOME/.codex/.TODO-honeypot.XXXXXX")" || {
        log_warn "Failed to create temp file for honeypot"
        return 0
    }

    # Source canonical honeypot content
    local honeypot_src
    honeypot_src="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/tools/honeypot-content.txt"
    if [[ -f "$honeypot_src" ]]; then
        cat "$honeypot_src" > "$tmp_honeypot"
    else
        log_warn "honeypot-content.txt not found — skipping honeypot deployment"
        rm -f "$tmp_honeypot"
        return 0
    fi

    # Set permissions on temp file before moving
    chmod 444 "$tmp_honeypot"
    mv -f "$tmp_honeypot" "$honeypot_path" || {
        log_warn "Failed to move honeypot into place"
        rm -f "$tmp_honeypot"
        return 0
    }

    # Apply immutability flag (best-effort — may not work on all filesystems)
    local immutable_set=false
    if [[ "$OSTYPE" == "darwin"* ]]; then
        chflags uchg "$honeypot_path" 2>/dev/null && immutable_set=true
    else
        chattr +i "$honeypot_path" 2>/dev/null && immutable_set=true
    fi

    if [[ "$immutable_set" == "true" ]]; then
        log_success "TODO honeypot deployed (chmod 444 + immutable)"
    else
        log_success "TODO honeypot deployed (chmod 444 only — immutable flag failed)"
        log_verbose "  chflags/chattr failed: permission denied, unsupported FS, or missing command"
    fi
}

# Migration: Detect orphaned TODO.md files from previous installs
#
# Problem: Before the deterministic default ($HOME/.codex/TODO.md), agents guessed
# paths from skill examples or workspace roots. These files may contain real task
# data that won't be found by the new default path.
#
# Fix: Scan discovered locations, report findings, suggest consolidation. Never delete.
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

    # Dynamically discover workspace roots: scan any $HOME child directory
    # that contains git repos (1-2 levels deep). No hardcoded directory names.
    local git_dir
    for parent_dir in "$HOME"/*/; do
        [[ -d "$parent_dir" ]] || continue
        # Skip dotdirs and known non-workspace dirs
        [[ "$(basename "$parent_dir")" == .* ]] && continue
        # Level 1: direct repos under ~/SomeDir/repo/
        for git_dir in "$parent_dir"*/; do
            [[ -f "${git_dir}TODO.md" ]] && candidates+=("${git_dir}TODO.md")
        done
        # Level 2: nested repos under ~/SomeDir/owner/repo/
        for git_dir in "$parent_dir"*/*/; do
            [[ -f "${git_dir}TODO.md" ]] && candidates+=("${git_dir}TODO.md")
        done
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

#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# lib/install/hook-parity.sh
# PURPOSE: Detect drift between shipped Claude hooks and their installed copies.
# SOURCED BY: install.sh — do not run directly.
# GLOBALS READ: SCRIPT_DIR, CLAUDE_HOOKS_DIR, HOOK_PARITY_STRICT
# GLOBALS SET: HOOK_PARITY_STATUS, HOOK_PARITY_STALE, HOOK_PARITY_MISSING,
#              HOOK_PARITY_ORPHANED, HOOK_PARITY_UNREADABLE
#
# Why this module exists
# ----------------------
# install_claude_guardrails() delegates to setup/install-claude-guardrails.sh,
# which no-ops unless SUPERPOWERS_CLAUDE_GUARDRAILS=1. The child script DOES
# announce that skip, but install.sh historically ran it as
# `bash "$guardrails_script" >/dev/null 2>&1`, discarding the one signal that
# would have surfaced it. Result on a dev machine 2026-09-20: 7 of 10 hooks
# were 26 days stale, the running skill-router was an old build with different
# limits and no telemetry, and shipped hook work had never executed.
#
# The redirect is fixed at its source in install.sh. This module is the
# belt-and-braces check: it compares file CONTENT, so it also catches drift the
# installer could never report -- hand edits, partial upgrades, interrupted
# installs -- not merely "was the installer called."
#
# Content-diffing rather than a manifest is deliberate. lib/install/deploy.sh's
# manifests track item NAMES so unmanaged items can be pruned; a manifest entry
# for a hook would still read "present" while its contents rotted.
# -----------------------------------------------------------------------------

# Guard: this module must be sourced by install.sh, not run directly.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "ERROR: This is a library module. Run install.sh instead." >&2
    exit 1
fi

# Compare every shipped hook against its installed copy, in BOTH directions.
#
# Four drift classes, each needing different remediation:
#   STALE      installed copy differs from source   -> reinstall
#   MISSING    shipped but never installed          -> reinstall
#   ORPHANED   installed but no longer shipped      -> delete (keeps executing!)
#   UNREADABLE cannot be compared                   -> fix permissions
#
# ORPHANED is not symmetry for its own sake. setup/install-claude-guardrails.sh
# only ever copies; it never deletes. A hook renamed or dropped from the shipped
# set therefore lingers in CLAUDE_HOOKS_DIR and keeps firing on every session --
# the same failure class as a stale hook, from the opposite direction, and
# invisible to a source-only scan.
#
# Exit status: 0 unless HOOK_PARITY_STRICT=1 and drift was found. Advisory is
# the default because a user who deliberately runs without guardrails is not
# misconfigured, and a warning must not fail an otherwise-good install. Callers
# that need to ACT on drift (CI, sp-doctor, an agent wrapper) set
# HOOK_PARITY_STRICT=1 or read the HOOK_PARITY_* globals, which are always set.
check_hook_parity() {
    local src_dir="${1:-$SCRIPT_DIR/tools/claude-hooks}"
    local dst_dir="${2:-$CLAUDE_HOOKS_DIR}"

    HOOK_PARITY_STALE=0
    HOOK_PARITY_MISSING=0
    HOOK_PARITY_ORPHANED=0
    HOOK_PARITY_UNREADABLE=0
    HOOK_PARITY_STATUS="ok"

    if [[ ! -d "$src_dir" ]]; then
        HOOK_PARITY_STATUS="no-source"
        log_verbose "Hook parity: no shipped hooks at $src_dir — skipping"
        return 0
    fi

    if [[ ! -d "$dst_dir" ]]; then
        HOOK_PARITY_STATUS="not-installed"
        log_warn "Hook parity: $dst_dir does not exist — Claude hooks are NOT installed"
        log_warn "  Install them: SUPERPOWERS_CLAUDE_GUARDRAILS=1 bash $SCRIPT_DIR/setup/install-claude-guardrails.sh"
        _hook_parity_strict_rc
        return $?
    fi

    local stale=() missing=() orphaned=() unreadable=()
    local total=0 hook src_file dst_file cmp_rc

    for src_file in "$src_dir"/*.sh; do
        [[ -f "$src_file" ]] || continue
        total=$((total + 1))
        hook="$(basename "$src_file")"
        dst_file="$dst_dir/$hook"

        if [[ ! -f "$dst_file" ]]; then
            missing+=("$hook")
            continue
        fi

        # cmp exit codes: 0 same, 1 differ, 2+ trouble (unreadable, absent,
        # cmp itself missing). Folding 2 into "differ" would tell a user to
        # reinstall when the real fix is chmod -- different problem, different
        # remediation. `|| cmp_rc=$?` keeps `set -e` from aborting on 1 or 2.
        cmp_rc=0
        cmp -s "$src_file" "$dst_file" || cmp_rc=$?
        case "$cmp_rc" in
            0) ;;
            1) stale+=("$hook") ;;
            *) unreadable+=("$hook") ;;
        esac
    done

    # Reverse direction: installed hooks this repo no longer ships.
    local dst_file_iter orphan_name
    for dst_file_iter in "$dst_dir"/*.sh; do
        [[ -f "$dst_file_iter" ]] || continue
        orphan_name="$(basename "$dst_file_iter")"
        [[ -f "$src_dir/$orphan_name" ]] || orphaned+=("$orphan_name")
    done

    HOOK_PARITY_STALE=${#stale[@]}
    HOOK_PARITY_MISSING=${#missing[@]}
    HOOK_PARITY_ORPHANED=${#orphaned[@]}
    HOOK_PARITY_UNREADABLE=${#unreadable[@]}

    local drift=$((HOOK_PARITY_STALE + HOOK_PARITY_MISSING + HOOK_PARITY_ORPHANED + HOOK_PARITY_UNREADABLE))
    if [[ $drift -eq 0 ]]; then
        log_success "Hook parity: $total/$total installed hooks match source"
        return 0
    fi

    # shellcheck disable=SC2034  # documented global for agent/CI consumers
    HOOK_PARITY_STATUS="drift"
    log_warn "Hook parity: $HOOK_PARITY_STALE stale, $HOOK_PARITY_MISSING missing, $HOOK_PARITY_ORPHANED orphaned, $HOOK_PARITY_UNREADABLE unreadable (of $total shipped)"

    # Every loop is count-guarded before expansion. install.sh runs under
    # `set -euo pipefail`, and bash 3.2 -- still /bin/bash on macOS -- treats
    # "${empty_array[@]}" as an unbound variable and aborts. Most drift leaves
    # several of these arrays empty, so reporting drift would have killed the
    # installer precisely when it had something to report.
    _hook_parity_list "MISSING  " missing "${missing[@]+"${missing[@]}"}"
    _hook_parity_list "STALE    " stale "${stale[@]+"${stale[@]}"}"
    _hook_parity_list "ORPHANED " orphaned "${orphaned[@]+"${orphaned[@]}"}"
    _hook_parity_list "UNREADABLE" unreadable "${unreadable[@]+"${unreadable[@]}"}"

    if [[ $HOOK_PARITY_ORPHANED -gt 0 ]]; then
        log_warn "  ORPHANED hooks still execute every session. Remove them from $dst_dir."
    fi
    if [[ $((HOOK_PARITY_STALE + HOOK_PARITY_MISSING)) -gt 0 ]]; then
        log_warn "  Shipped hook work is NOT running. Fix with:"
        log_warn "    SUPERPOWERS_CLAUDE_GUARDRAILS=1 bash $SCRIPT_DIR/setup/install-claude-guardrails.sh"
    fi
    if [[ $HOOK_PARITY_UNREADABLE -gt 0 ]]; then
        log_warn "  UNREADABLE hooks could not be compared — check file permissions."
    fi

    # One stable, greppable line for agent and CI consumers, so nothing has to
    # parse two different prose shapes to learn the verdict.
    printf 'HOOK_PARITY_STATUS=drift stale=%d missing=%d orphaned=%d unreadable=%d total=%d\n' \
        "$HOOK_PARITY_STALE" "$HOOK_PARITY_MISSING" "$HOOK_PARITY_ORPHANED" \
        "$HOOK_PARITY_UNREADABLE" "$total"

    _hook_parity_strict_rc
    return $?
}

# Print one warn line per entry. Takes the label, the array name (unused but
# kept for call-site readability), then the entries -- which may be zero.
_hook_parity_list() {
    local label="$1"
    shift 2
    local entry
    for entry in "$@"; do
        log_warn "  $label $entry"
    done
}

# Advisory by default; opt-in hard failure for agent and CI callers.
_hook_parity_strict_rc() {
    [[ "${HOOK_PARITY_STRICT:-0}" == "1" ]] && return 2
    return 0
}

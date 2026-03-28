#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Script: uninstall.sh
# PURPOSE: Remove superpowers-plus skills, tools, rules, templates, adapter,
#          and source registration. Leaves runtime data intact unless --purge.
# USAGE:   ./uninstall.sh [--dry-run] [--yes] [--purge] [--verbose]
# VERSION: 1.0.0
# PLATFORM: macOS, Linux, WSL
# NOTE:    Pragmatic shell uninstaller. NOT transactional — re-run to resume.
# -----------------------------------------------------------------------------
set -euo pipefail

VERSION="1.0.0"

# --- Shell & Bash Version Guard ---
if [ -z "${BASH_VERSION:-}" ]; then
    echo "ERROR: This script requires bash." >&2
    echo "  Fix: bash uninstall.sh $*" >&2
    exit 1
fi
if [ "${BASH_VERSINFO[0]}" -lt 4 ]; then
    echo "ERROR: bash ${BASH_VERSION} is too old — need bash 4+." >&2
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "  macOS fix: brew install bash && /opt/homebrew/bin/bash uninstall.sh" >&2
    else
        echo "  Linux fix: sudo apt install bash" >&2
    fi
    exit 1
fi

# --- CRLF self-heal ---
_SCRIPT_DIR_EARLY="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -n "$(find "$_SCRIPT_DIR_EARLY" -maxdepth 1 -name '*.sh' -exec grep -rl $'\r' {} + 2>/dev/null | head -1)" ]; then
    find "$_SCRIPT_DIR_EARLY" -maxdepth 1 -name "*.sh" -print0 | while IFS= read -r -d '' f; do
        mode="$(stat -f '%Lp' "$f" 2>/dev/null || stat -c '%a' "$f" 2>/dev/null || true)"
        tr -d '\r' < "$f" > "${f}.tmp"
        if [[ -n "$mode" ]]; then
            chmod "$mode" "${f}.tmp"
        elif [[ -x "$f" ]]; then
            chmod +x "${f}.tmp"
        fi
        mv "${f}.tmp" "$f"
    done
    exec bash "$0" "$@"
fi
unset _SCRIPT_DIR_EARLY

# --- Configuration ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CODEX_DIR="${HOME}/.codex"
ENV_FILE="${CODEX_DIR}/.env"
SKILLS_DIR="${CODEX_DIR}/skills"
CLAUDE_SKILLS_DIR="${HOME}/.claude/skills"
INSTALL_STATE_DIR="${CODEX_DIR}/superpowers-plus/install-state"
MANAGED_DIR="${CODEX_DIR}/superpowers-plus"
ADAPTER_DIR="${CODEX_DIR}/superpowers-augment"
OBRA_DIR="${CODEX_DIR}/superpowers"
AUGMENT_RULES_DIR="${HOME}/.augment/rules"
TEMPLATES_DIR="${CODEX_DIR}/templates"
SOURCE_VAR="SPP_SOURCE_DIR"

# --- Options ---
DRY_RUN=false
YES=false
PURGE=false
VERBOSE=false
[[ ! -t 0 ]] && YES=true

# --- Colors ---
if [[ -t 1 ]]; then
    RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'
    BLUE='\033[0;34m'; NC='\033[0m'
else
    RED='' GREEN='' YELLOW='' BLUE='' NC=''
fi

log_info()    { printf '%b\n' "${BLUE}[INFO]${NC} $*"; }
log_success() { printf '%b\n' "${GREEN}[OK]${NC}   $*"; }
log_warn()    { printf '%b\n' "${YELLOW}[WARN]${NC} $*"; }
log_error()   { printf '%b\n' "${RED}[ERR]${NC}  $*" >&2; }
log_verbose() { [[ "$VERBOSE" == "true" ]] && printf '%b\n' "${BLUE}[DEBUG]${NC} $*" || true; }
error_exit()  { log_error "$*"; exit 1; }

# --- Strict basename validation (allowlist: alnum, hyphen, underscore, dot) ---
is_safe_name() {
    local name="$1"
    [[ -n "$name" ]] && [[ "$name" =~ ^[a-zA-Z0-9._-]+$ ]]
}

# --- Dry-run wrapper ---
run_rm() {
    local target="$1"
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] Would remove: $target"
    else
        rm -rf -- "${target:?}" 2>/dev/null || log_warn "Failed to remove: $target"
        log_verbose "Removed: $target"
    fi
}

# --- Remove a line from .env ---
remove_env_var() {
    local var_name="$1"
    [[ -f "$ENV_FILE" ]] || return 0
    [[ -r "$ENV_FILE" ]] || { log_warn "Cannot read $ENV_FILE — skipping $var_name removal"; return 1; }
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] Would remove $var_name from $ENV_FILE"
        return 0
    fi
    local tmp_file="${ENV_FILE}.tmp.$$"
    if ! : > "$tmp_file" 2>/dev/null; then
        log_warn "Failed to create temp file for $ENV_FILE rewrite"
        rm -f -- "$tmp_file" 2>/dev/null
        return 1
    fi

    # grep exits 1 when every line is filtered out; that still produces a valid empty file.
    local grep_status=0
    grep -v "^${var_name}=" "$ENV_FILE" > "$tmp_file" 2>/dev/null || grep_status=$?
    case "$grep_status" in
        0|1)
            if ! mv -- "$tmp_file" "$ENV_FILE"; then
                rm -f -- "$tmp_file" 2>/dev/null
                log_warn "Failed to rewrite $ENV_FILE for $var_name removal"
                return 1
            fi
            ;;
        *)
            rm -f -- "$tmp_file" 2>/dev/null
            log_warn "Failed to rewrite $ENV_FILE for $var_name removal"
            return 1
            ;;
    esac
    log_verbose "Removed $var_name from $ENV_FILE"
}

# --- Check if another overlay provides a shared artifact ---
other_repo_provides() {
    local artifact_type="$1"
    local artifact_name="$2"
    [[ -f "$ENV_FILE" ]] || return 1
    while IFS='=' read -r varname varval; do
        [[ "$varname" == "$SOURCE_VAR" ]] && continue
        [[ "$varname" =~ _SOURCE_DIR$ ]] || continue
        local dir="${varval//\"/}"
        dir="${dir//\'/}"
        [[ -z "$dir" || ! -d "$dir" ]] && continue
        local overlay_name=""
        case "$varname" in
            SPC_SOURCE_DIR) overlay_name="superpowers-[company]" ;;
            PRODUCT_SOURCE_DIR) overlay_name="superpowers-[product]" ;;
            PRODUCT_SOURCE_DIR) overlay_name="superpowers-[product]" ;;
            *) continue ;;
        esac
        local overlay_manifest="${CODEX_DIR}/${overlay_name}/install-state/${artifact_type}.manifest"
        if [[ -f "$overlay_manifest" ]] && grep -qxF "$artifact_name" "$overlay_manifest" 2>/dev/null; then
            return 0
        fi
    done < <(grep '_SOURCE_DIR=' "$ENV_FILE" 2>/dev/null || true)
    return 1
}

# --- Read manifest or fall back to source scan ---
read_manifest() {
    local manifest="$1"
    local fallback_dir="${2:-}"
    local scan_pattern="${3:-skill.md}"
    if [[ -f "$manifest" ]]; then
        while IFS= read -r entry; do
            [[ -z "$entry" ]] && continue
            if is_safe_name "$entry"; then echo "$entry"; else log_warn "Skipping unsafe manifest entry: $entry"; fi
        done < "$manifest"
    elif [[ -n "$fallback_dir" && -d "$fallback_dir" ]]; then
        log_warn "No manifest at $manifest — using source-scan fallback (best-effort)"
        while IFS= read -r found_file; do
            local found_name
            if [[ "$scan_pattern" == "skill.md" ]]; then
                # Skills: parent dir name is the skill name
                found_name="$(basename "$(dirname "$found_file")")"
            else
                # Flat files (rules, tools, templates, modules): filename is the artifact name
                found_name="$(basename "$found_file")"
            fi
            is_safe_name "$found_name" && echo "$found_name"
        done < <(find "$fallback_dir" -name "$scan_pattern" \
            -not -path '*/_archive/*' -not -path '*/.git/*' 2>/dev/null)
    fi
}

# --- Check for remaining overlays ---
check_overlays() {
    local -a remaining=()
    if [[ -f "$ENV_FILE" ]]; then
        while IFS='=' read -r varname _; do
            [[ "$varname" == "$SOURCE_VAR" ]] && continue
            [[ "$varname" =~ _SOURCE_DIR$ ]] || continue
            remaining+=("$varname")
        done < <(grep '_SOURCE_DIR=' "$ENV_FILE" 2>/dev/null || true)
    fi
    if [[ ${#remaining[@]} -gt 0 ]]; then
        echo ""
        log_warn "Other superpowers overlays are still registered:"
        for var in "${remaining[@]}"; do
            log_warn "  $var"
        done
        log_warn "Their skills depend on superpowers-plus. They will stop working."
        log_warn "Uninstall those overlays first, or reinstall superpowers-plus later."
        echo ""
    fi
}

# --- Help ---
show_help() {
    cat << 'EOF'
NAME
    uninstall.sh - Remove superpowers-plus skills, tools, rules, and adapter

SYNOPSIS
    uninstall.sh [OPTIONS]

DESCRIPTION
    Removes all artifacts installed by superpowers-plus. Shared artifacts
    (rules) are preserved if another overlay still provides them.
    Runtime data is NOT removed unless --purge is specified.

OPTIONS
    --dry-run       Show what would be removed without removing anything
    --yes, -y       Skip confirmation prompt
    --purge         Also remove managed checkout, obra/superpowers, adapter,
                    and runtime data (doctor-backups, review dirs, session)
    --verbose, -v   Show detailed progress
    --version       Show version
    -h, --help      Show this help

EXAMPLES
    ./uninstall.sh --dry-run           # Preview removal
    ./uninstall.sh --yes               # Remove without confirmation
    ./uninstall.sh --purge --yes       # Full cleanup including runtime data
EOF
    exit 0
}

# --- Argument Parsing ---
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run) DRY_RUN=true; shift ;;
        -y|--yes) YES=true; shift ;;
        --purge) PURGE=true; shift ;;
        -v|--verbose) VERBOSE=true; shift ;;
        --version) echo "uninstall.sh version $VERSION"; exit 0 ;;
        -h|--help) show_help ;;
        *) error_exit "Unknown option: $1 (use --help)" ;;
    esac
done

# ============================================================================
# Main
# ============================================================================
main() {
    echo ""
    log_info "superpowers-plus uninstaller v${VERSION}"
    echo ""

    # Pre-flight: check if anything is installed
    if [[ ! -d "$INSTALL_STATE_DIR" && ! -d "$MANAGED_DIR" && ! -d "$ADAPTER_DIR" ]]; then
        if [[ ! -d "$SCRIPT_DIR/skills" ]]; then
            log_info "superpowers-plus does not appear to be installed. Nothing to do."
            exit 0
        fi
    fi

    check_overlays

    # Collect what to remove
    local -a skills=() rules=() tools=() templates=()
    while IFS= read -r s; do [[ -n "$s" ]] && skills+=("$s"); done < <(
        read_manifest "${INSTALL_STATE_DIR}/skills.manifest" "$SCRIPT_DIR/skills")
    while IFS= read -r r; do [[ -n "$r" ]] && rules+=("$r"); done < <(
        read_manifest "${INSTALL_STATE_DIR}/rules.manifest" "$SCRIPT_DIR/rules" "*.md")
    while IFS= read -r t; do [[ -n "$t" ]] && tools+=("$t"); done < <(
        read_manifest "${INSTALL_STATE_DIR}/tools.manifest" "$SCRIPT_DIR/tools" "*")
    while IFS= read -r t; do [[ -n "$t" ]] && templates+=("$t"); done < <(
        read_manifest "${INSTALL_STATE_DIR}/templates.manifest" "$SCRIPT_DIR/templates" "*")

    # Summary
    echo "Will remove:"
    echo "  ${#skills[@]} skill(s) from ~/.codex/skills/ and ~/.claude/skills/"
    echo "  ${#rules[@]} rule(s) from ~/.augment/rules/ (if not shared)"
    echo "  ${#tools[@]} tool(s) from ~/.codex/superpowers-plus/tools/"
    echo "  ${#templates[@]} template(s) from ~/.codex/templates/"
    echo "  Adapter: ~/.codex/superpowers-augment/"
    echo "  Registration: SPP_SOURCE_DIR from ~/.codex/.env"
    if [[ "$PURGE" == "true" ]]; then
        echo "  [PURGE] Managed checkout: ~/.codex/superpowers-plus/"
        echo "  [PURGE] obra/superpowers: ~/.codex/superpowers/"
        echo "  [PURGE] Runtime: doctor-backups, review dirs, session markers"
    fi
    echo ""

    # Confirmation
    if [[ "$YES" != "true" && "$DRY_RUN" != "true" ]]; then
        read -r -p "Proceed with uninstall? [y/N] " answer
        if [[ ! "$answer" =~ ^[Yy] ]]; then
            log_info "Aborted."
            exit 0
        fi
    fi

    # Step 1: Remove skills
    log_info "Removing skills..."
    local skill_count=0
    for skill_name in "${skills[@]}"; do
        for target_dir in "$SKILLS_DIR" "$CLAUDE_SKILLS_DIR"; do
            [[ -d "${target_dir}/${skill_name}" ]] && run_rm "${target_dir}/${skill_name}"
        done
        skill_count=$((skill_count + 1))
    done
    log_success "Removed $skill_count skill(s)"

    # Step 2: Remove rules (only if not shared with another overlay)
    log_info "Removing rules..."
    local rule_count=0
    for rule_name in "${rules[@]}"; do
        if other_repo_provides "rules" "$rule_name"; then
            log_verbose "Keeping $rule_name — still provided by another overlay"
            continue
        fi
        [[ -f "${AUGMENT_RULES_DIR}/${rule_name}" ]] && run_rm "${AUGMENT_RULES_DIR}/${rule_name}"
        rule_count=$((rule_count + 1))
    done
    log_success "Removed $rule_count rule(s)"

    # Step 3: Skip tool removal — tools live in-tree inside the git checkout.
    # They are only removed if --purge is used (which removes the entire checkout).
    # Removing individual tools from a git working tree is destructive and breaks
    # subsequent reinstalls.
    log_info "Skipping tools (in-tree; removed only with --purge)"

    # Step 4: Remove templates
    log_info "Removing templates..."
    local tmpl_count=0
    for tmpl_name in "${templates[@]}"; do
        [[ -e "${TEMPLATES_DIR}/${tmpl_name}" ]] && run_rm "${TEMPLATES_DIR}/${tmpl_name}"
        tmpl_count=$((tmpl_count + 1))
    done
    log_success "Removed $tmpl_count template(s)"

    # Step 5: Remove adapter
    log_info "Removing adapter..."
    [[ -d "$ADAPTER_DIR" ]] && run_rm "$ADAPTER_DIR"
    log_success "Adapter removed"

    # Step 6: Remove source registration from .env
    log_info "Removing source registration..."
    remove_env_var "$SOURCE_VAR"
    log_success "Registration removed"

    # Step 7: Purge (optional)
    if [[ "$PURGE" == "true" ]]; then
        log_info "Purging managed checkout and runtime data..."
        [[ -d "$OBRA_DIR" ]] && run_rm "$OBRA_DIR"
        [[ -d "$MANAGED_DIR" ]] && run_rm "$MANAGED_DIR"
        [[ -d "${CODEX_DIR}/doctor-backups" ]] && run_rm "${CODEX_DIR}/doctor-backups"
        [[ -d "${CODEX_DIR}/superpowers-review" ]] && run_rm "${CODEX_DIR}/superpowers-review"
        [[ -f "${CODEX_DIR}/.superpowers-session" ]] && run_rm "${CODEX_DIR}/.superpowers-session"
        log_success "Purge complete"
    fi

    # Step 8: Remove install-state (LAST — enables re-run on failure)
    if [[ -d "$INSTALL_STATE_DIR" ]]; then
        run_rm "$INSTALL_STATE_DIR"
        log_verbose "Install state removed"
    fi

    echo ""
    echo "========================================"
    echo "  superpowers-plus Uninstall Complete"
    echo "========================================"
    echo ""
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "This was a dry run. No files were removed."
    else
        echo "Skills, tools, rules, templates, and adapter have been removed."
        if [[ "$PURGE" != "true" ]]; then
            echo ""
            echo "To also remove managed checkout and runtime data:"
            echo "  ./uninstall.sh --purge --yes"
        fi
    fi
    echo ""
}

main "$@"

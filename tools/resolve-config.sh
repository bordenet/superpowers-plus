#!/usr/bin/env bash
# =============================================================================
# tools/resolve-config.sh
#
# PURPOSE: Unified four-tier config resolver. Any script can call this instead
#          of encoding its own precedence logic.
#
# PRECEDENCE (highest → lowest):
#   1. Env-var override:  SP_CONFIG_<KIND>_<KEY>  (uppercase)
#   2. Project-local:     <nearest .git parent>/.codex-config/<kind>/<key>
#   3. Repo-source:       Repos listed in ~/.codex/repos.txt,
#                         each checked at <repo>/.codex-config/<kind>/<key>
#   4. Global install:    ~/.codex/config/<kind>/<key>
#
# USAGE:
#   resolve-config.sh get <kind> <key>       # print value; exit 1 on miss
#   resolve-config.sh audit <kind> <key>     # print table of all tiers
#   resolve-config.sh --list-kinds           # print valid kind names
#
# EXIT CODES:
#   0  found
#   1  not found (only for 'get')
#   2  invalid kind or bad usage
#
# KINDS: mcp  env  allowlist  hook  template
# =============================================================================
set -euo pipefail

readonly _VALID_KINDS=(mcp env allowlist hook template)
readonly _REPOS_FILE="${HOME}/.codex/repos.txt"
readonly _GLOBAL_ROOT="${HOME}/.codex/config"

# ---------------------------------------------------------------------------
_usage() {
    cat >&2 <<EOF
Usage:
  ${0##*/} get <kind> <key>       print resolved value (exit 1 on miss)
  ${0##*/} audit <kind> <key>     print all-tier table
  ${0##*/} --list-kinds           list valid kinds
EOF
    exit 2
}

_is_valid_kind() {
    local k="$1"
    local vk
    for vk in "${_VALID_KINDS[@]}"; do [[ "$vk" == "$k" ]] && return 0; done
    return 1
}

# Reject empty, path-traversal, or slash-containing keys.
_is_valid_key() {
    local k="$1"
    [[ -z "$k" || "$k" == *"/"* || "$k" == "."* || "$k" == *".." ]] && return 1
    return 0
}

# Tier 1: env-var override SP_CONFIG_<KIND>_<KEY>
_tier1_env() {
    local kind="$1" key="$2"
    local kind_upper key_upper varname
    kind_upper="$(tr '[:lower:]' '[:upper:]' <<<"${kind}")"
    key_upper="$(tr '[:lower:][:punct:]' '[:upper:]_' <<<"${key}")"
    varname="SP_CONFIG_${kind_upper}_${key_upper}"
    printf '%s' "${!varname:-}"
}

# Tier 2: walk up from cwd to nearest .git (file OR dir — handles worktrees),
#          check .codex-config/<kind>/<key>
_tier2_project() {
    local kind="$1" key="$2"
    local dir; dir="$(pwd)"
    while [[ "$dir" != "/" ]]; do
        if [[ -d "$dir/.git" || -f "$dir/.git" ]]; then
            local f="$dir/.codex-config/$kind/$key"
            [[ -f "$f" ]] && { cat "$f"; return 0; }
            return 1
        fi
        dir="$(dirname "$dir")"
    done
    return 1
}

# Tier 3: repos listed in ~/.codex/repos.txt
_tier3_repo() {
    local kind="$1" key="$2"
    [[ -f "$_REPOS_FILE" ]] || return 1
    local repo expanded
    while IFS= read -r repo || [[ -n "$repo" ]]; do
        [[ -z "$repo" || "$repo" == "#"* ]] && continue
        # expand ~ manually (not in quotes)
        expanded="${repo/#\~/$HOME}"
        local f="$expanded/.codex-config/$kind/$key"
        [[ -f "$f" ]] && { cat "$f"; return 0; }
    done < "$_REPOS_FILE"
    return 1
}

# Tier 4: global ~/.codex/config/<kind>/<key>
_tier4_global() {
    local kind="$1" key="$2"
    local f="$_GLOBAL_ROOT/$kind/$key"
    [[ -f "$f" ]] && { cat "$f"; return 0; }
    return 1
}

# ---------------------------------------------------------------------------
cmd_get() {
    local kind="$1" key="$2"
    _is_valid_kind "$kind" || { echo "resolve-config: invalid kind '$kind'" >&2; exit 2; }
    _is_valid_key  "$key"  || { echo "resolve-config: invalid key '$key'"   >&2; exit 2; }

    local v
    v="$(_tier1_env "$kind" "$key")"
    [[ -n "$v" ]] && { printf '%s\n' "$v"; return 0; }

    v="$(_tier2_project "$kind" "$key" 2>/dev/null)" && { printf '%s\n' "$v"; return 0; }
    v="$(_tier3_repo    "$kind" "$key" 2>/dev/null)" && { printf '%s\n' "$v"; return 0; }
    v="$(_tier4_global  "$kind" "$key" 2>/dev/null)" && { printf '%s\n' "$v"; return 0; }

    echo "resolve-config: '$kind/$key' not found in any tier" >&2
    return 1
}

cmd_audit() {
    local kind="$1" key="$2"
    _is_valid_kind "$kind" || { echo "resolve-config: invalid kind '$kind'" >&2; exit 2; }
    _is_valid_key  "$key"  || { echo "resolve-config: invalid key '$key'"   >&2; exit 2; }

    local v miss="(not set)"
    printf '%-14s %s\n' "TIER" "VALUE"
    printf '%-14s %s\n' "----" "-----"

    v="$(_tier1_env "$kind" "$key")"
    printf '%-14s %s\n' "1-env-var"   "${v:-$miss}"

    v="$(_tier2_project "$kind" "$key" 2>/dev/null)" \
        && printf '%-14s %s\n' "2-project"   "$v" \
        || printf '%-14s %s\n' "2-project"   "$miss"

    v="$(_tier3_repo "$kind" "$key" 2>/dev/null)" \
        && printf '%-14s %s\n' "3-repo"      "$v" \
        || printf '%-14s %s\n' "3-repo"      "$miss"

    v="$(_tier4_global "$kind" "$key" 2>/dev/null)" \
        && printf '%-14s %s\n' "4-global"    "$v" \
        || printf '%-14s %s\n' "4-global"    "$miss"
}

# ---------------------------------------------------------------------------
[[ $# -eq 0 ]] && _usage

case "$1" in
    --list-kinds) printf '%s\n' "${_VALID_KINDS[@]}"; exit 0 ;;
    get)   [[ $# -eq 3 ]] || _usage; cmd_get   "$2" "$3" ;;
    audit) [[ $# -eq 3 ]] || _usage; cmd_audit "$2" "$3" ;;
    -h|--help) _usage ;;
    *) echo "resolve-config: unknown command '$1'" >&2; _usage ;;
esac

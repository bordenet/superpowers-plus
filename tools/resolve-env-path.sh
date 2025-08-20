#!/usr/bin/env bash
# resolve-env-path.sh — Shared utility for sourcing .env and resolving paths
#
# Usage (as a sourced library):
#   source "$(dirname "$0")/resolve-env-path.sh"
#   resolve_env              # Sources ~/.codex/.env, sets ENV_SOURCED=true/false
#   TODO_PATH=$(resolve_path "TODO_FILE_PATH" "$HOME/.codex/TODO.md")
#
# Usage (standalone):
#   ./resolve-env-path.sh TODO_FILE_PATH "$HOME/.codex/TODO.md"
#   → prints resolved path to stdout

set -euo pipefail

# Source ~/.codex/.env if it exists. Sets ENV_SOURCED=true/false.
# shellcheck disable=SC2034  # ENV_SOURCED is used by callers
resolve_env() {
  local env_file="$HOME/.codex/.env"
  ENV_SOURCED=false
  if [[ -f "$env_file" ]]; then
    # shellcheck source=/dev/null
    source "$env_file" 2>/dev/null && ENV_SOURCED=true
  fi
}

# Resolve a path from an environment variable with a fallback default.
# Expands ~ and $HOME in the resulting path.
# Args: $1 = variable name, $2 = default value
resolve_path() {
  local var_name="$1"
  local default="$2"
  local value="${!var_name:-$default}"

  # Expand $HOME and ~ in the path
  if command -v envsubst &>/dev/null; then
    echo "$value" | envsubst
  else
    # shellcheck disable=SC2116
    eval echo "$value" 2>/dev/null || echo "$value"
  fi
}

# Standalone mode: if called directly (not sourced), resolve and print
if [[ "${BASH_SOURCE[0]:-}" == "${0:-}" && -n "${0:-}" ]]; then
  if [[ $# -lt 1 ]]; then
    echo "Usage: $0 VAR_NAME [DEFAULT_VALUE]" >&2
    exit 1
  fi
  resolve_env
  resolve_path "${1}" "${2:-}"
fi

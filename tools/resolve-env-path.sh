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
# For TODO_FILE_PATH, checks ~/.codex/.todo-registry first (private path
# store that agents don't see). Falls back to env var, then default.
# Expands ~ and $HOME in the resulting path.
# Args: $1 = variable name, $2 = default value
# Sets: RESOLVE_SOURCE = "registry" | "env" | "default"
resolve_path() {
  local var_name="$1"
  local default="$2"
  local value=""
  RESOLVE_SOURCE="default"

  # Priority 1: Private registry (for TODO_FILE_PATH)
  if [[ "$var_name" == "TODO_FILE_PATH" ]]; then
    local registry="$HOME/.codex/.todo-registry"
    if [[ -f "$registry" ]]; then
      value="$(head -1 "$registry" 2>/dev/null | tr -d '[:space:]')"
      if [[ -n "$value" ]]; then
        RESOLVE_SOURCE="registry"
      fi
    fi
  fi

  # Priority 2: Environment variable (from .env or export)
  if [[ -z "$value" ]]; then
    value="${!var_name:-}"
    if [[ -n "$value" ]]; then
      RESOLVE_SOURCE="env"
    fi
  fi

  # Priority 3: Default
  if [[ -z "$value" ]]; then
    value="$default"
    RESOLVE_SOURCE="default"
  fi

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

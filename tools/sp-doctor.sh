#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# tools/sp-doctor.sh
# PURPOSE: Run superpowers-doctor diagnostic checks on the local installation.
#          Thin wrapper around doctor-checks.sh for CLI convenience.
# USAGE: sp-doctor [--fix] [--fix-safe] [--summary-only] [--purge-orphans] [--yes]
# INSTALLED TO: ~/.codex/superpowers-plus/tools/sp-doctor.sh
# SYMLINKED TO: <bin_dir>/sp-doctor (by install.sh)
# -----------------------------------------------------------------------------
set -euo pipefail

# Resolve through symlinks so this works when invoked via ~/.local/bin/sp-doctor
REAL_SCRIPT="$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || realpath "${BASH_SOURCE[0]}" 2>/dev/null || echo "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd "$(dirname "$REAL_SCRIPT")" && pwd)"
DOCTOR_SCRIPT="$SCRIPT_DIR/doctor-checks.sh"

if [[ ! -f "$DOCTOR_SCRIPT" ]]; then
    echo "ERROR: doctor-checks.sh not found at $DOCTOR_SCRIPT" >&2
    exit 1
fi

exec bash "$DOCTOR_SCRIPT" "$@"

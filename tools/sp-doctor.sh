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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCTOR_SCRIPT="$SCRIPT_DIR/doctor-checks.sh"

if [[ ! -f "$DOCTOR_SCRIPT" ]]; then
    echo "ERROR: doctor-checks.sh not found at $DOCTOR_SCRIPT" >&2
    exit 1
fi

exec bash "$DOCTOR_SCRIPT" "$@"

#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# scripts/capture-augment-baseline.sh
# PURPOSE: Capture the baseline state of Augment-touching files before any
#          Claude Code guardrails land. Used for non-regression tracking in
#          the Claude Code guardrails program (PR-0 scaffolding).
#
# USAGE:
#   bash scripts/capture-augment-baseline.sh           # capture/overwrite baseline
#   bash scripts/capture-augment-baseline.sh --check   # compare current state to baseline
#   bash scripts/capture-augment-baseline.sh --help
#
# OUTPUT: tests/fixtures/augment-baseline-pre-claude-guardrails.json
# EXIT:   0 = success (capture) or no drift (check)
#         1 = drift detected (check) or capture error
# -----------------------------------------------------------------------------
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUT="$REPO_ROOT/tests/fixtures/augment-baseline-pre-claude-guardrails.json"

# Files tracked for SHA256 drift detection (paths relative to REPO_ROOT)
TRACKED_TOOLS=(
    "tools/commit-gate.sh"
    "tools/public-repo-ip-check.sh"
    "tools/dangerous-pattern-scan.sh"
    "tools/run-battery.sh"
    "tools/sp-doctor.sh"
)

usage() {
    cat <<'EOF'
Usage: capture-augment-baseline.sh [--check] [--help]

  (no flag)  Capture current state → tests/fixtures/augment-baseline-pre-claude-guardrails.json
  --check    Compare current file hashes to saved baseline; exit non-zero on drift
  --help     Show this help
EOF
}

# Print relative paths of every .sh under lib/install/, sorted
collect_install_scripts() {
    if [[ -d "$REPO_ROOT/lib/install" ]]; then
        find "$REPO_ROOT/lib/install" -name "*.sh" | sort | sed "s|^$REPO_ROOT/||"
    fi
}

mode_capture() {
    echo "[capture-augment-baseline] Capturing state → $OUTPUT" >&2
    mkdir -p "$(dirname "$OUTPUT")"

    # --- sp-doctor (summary-only to avoid embedding private overlay names) ---
    local dr_tmp dr_rc
    dr_tmp="$(mktemp)"
    dr_rc=0
    bash "$REPO_ROOT/tools/sp-doctor.sh" --summary-only >"$dr_tmp" 2>&1 || dr_rc=$?
    echo "[capture] sp-doctor exit=$dr_rc" >&2

    # --- skill catalog: bootstrap summary only ---
    # NOTE: sp-help output is intentionally excluded here because it contains
    # installation-specific overlay paths (private repos). The bootstrap summary
    # captures the framework version and skill count, which is sufficient for
    # non-regression tracking in this public repository.
    local cat_tmp cat_rc
    cat_tmp="$(mktemp)"
    cat_rc=0
    node "$HOME/.codex/superpowers-augment/superpowers-augment.js" bootstrap \
        >"$cat_tmp" 2>&1 || cat_rc=$?
    echo "[capture] skill-catalog exit=$cat_rc" >&2

    # --- run-battery ---
    local batt_tmp batt_rc
    batt_tmp="$(mktemp)"
    batt_rc=0
    bash "$REPO_ROOT/tools/run-battery.sh" >"$batt_tmp" 2>&1 || batt_rc=$?
    echo "[capture] run-battery exit=$batt_rc" >&2

    # --- collect all tracked files ---
    local install_scripts
    install_scripts="$(collect_install_scripts)"

    # Build JSON via Python (handles escaping correctly)
    export REPO_ROOT
    python3 - "$dr_tmp" "$dr_rc" "$cat_tmp" "$cat_rc" "$batt_tmp" "$batt_rc" \
        "$OUTPUT" "$install_scripts" "${TRACKED_TOOLS[@]}" <<'PYEOF'
import json, sys, os, hashlib
from datetime import datetime, timezone

dr_tmp, dr_rc, cat_tmp, cat_rc, batt_tmp, batt_rc, output, install_blob = sys.argv[1:9]
tracked_tools = sys.argv[9:]

repo = os.environ["REPO_ROOT"]

def sha256_file(path):
    try:
        return hashlib.sha256(open(path, "rb").read()).hexdigest()
    except OSError:
        return "MISSING"

install_scripts = [l for l in install_blob.splitlines() if l.strip()]
all_tracked = list(tracked_tools) + install_scripts

data = {
    "captured_at": datetime.now(timezone.utc).isoformat(),
    "sp_doctor": {
        "output": open(dr_tmp).read(),
        "exit_code": int(dr_rc),
    },
    "skill_catalog": {
        "output": open(cat_tmp).read(),
        "exit_code": int(cat_rc),
    },
    "run_battery": {
        "output": open(batt_tmp).read(),
        "exit_code": int(batt_rc),
    },
    "file_hashes": {
        rel: sha256_file(os.path.join(repo, rel))
        for rel in all_tracked if rel
    },
}

with open(output, "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")

print(f"[capture-augment-baseline] Wrote {output}")
PYEOF

    # Cleanup temp files
    rm -f "$dr_tmp" "$cat_tmp" "$batt_tmp"
    echo "[capture-augment-baseline] Done." >&2
}

mode_check() {
    if [[ ! -f "$OUTPUT" ]]; then
        echo "ERROR: No baseline found at $OUTPUT" >&2
        echo "Run without --check first to capture a baseline." >&2
        exit 1
    fi

    echo "[capture-augment-baseline] Checking drift against baseline..." >&2

    local install_scripts
    install_scripts="$(collect_install_scripts)"

    export REPO_ROOT
    local rc=0
    python3 - "$OUTPUT" "$install_scripts" "${TRACKED_TOOLS[@]}" <<'PYEOF' || rc=$?
import json, sys, os, hashlib

output, install_blob = sys.argv[1], sys.argv[2]
tracked_tools = sys.argv[3:]

repo = os.environ["REPO_ROOT"]

with open(output) as f:
    baseline = json.load(f)

saved_hashes = baseline.get("file_hashes", {})
install_scripts = [l for l in install_blob.splitlines() if l.strip()]
all_tracked = list(tracked_tools) + install_scripts

def sha256_file(path):
    try:
        return hashlib.sha256(open(path, "rb").read()).hexdigest()
    except OSError:
        return "MISSING"

drift = []
for rel in all_tracked:
    if not rel:
        continue
    current = sha256_file(os.path.join(repo, rel))
    saved   = saved_hashes.get(rel, "NOT_IN_BASELINE")
    if current != saved:
        drift.append((rel, saved, current))

if not drift:
    print("[capture-augment-baseline] No drift detected. Baseline matches current state.")
    sys.exit(0)

print(f"[capture-augment-baseline] DRIFT DETECTED — {len(drift)} file(s) changed:")
for rel, old, new in drift:
    print(f"  {rel}")
    print(f"    baseline : {old}")
    print(f"    current  : {new}")
sys.exit(1)
PYEOF
    return $rc
}

# --- Main ---
MODE="capture"
for arg in "$@"; do
    case "$arg" in
        --check)  MODE="check" ;;
        --help|-h) usage; exit 0 ;;
        *) echo "Unknown argument: $arg" >&2; usage; exit 1 ;;
    esac
done

case "$MODE" in
    capture) mode_capture ;;
    check)   mode_check ;;
esac

#!/usr/bin/env bash
# package-for-claude.sh — Package superpowers-plus skills for Claude Desktop upload
# ZIP format verified 2026-06-27: skill-name.zip → skill-name/ → skill.md (lowercase)
# Source: https://support.claude.com/en/articles/12512198-how-to-create-custom-skills
#
# Usage: ./tools/package-for-claude.sh [--output DIR] [--manifest FILE] [--keep]
# Requires: bash 3.2+, python3, zip, unzip
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DEFAULT_MANIFEST="$SCRIPT_DIR/claude-desktop-skills.json"
DEFAULT_OUTDIR="$HOME/superpowers-claude-desktop"

# ── CLI args ──────────────────────────────────────────────────────────────────
MANIFEST="$DEFAULT_MANIFEST"
OUTDIR="$DEFAULT_OUTDIR"
KEEP=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --output)   OUTDIR="$2";   shift 2 ;;
    --manifest) MANIFEST="$2"; shift 2 ;;
    --keep)     KEEP=1;        shift   ;;
    -h|--help)  grep '^#' "${BASH_SOURCE[0]}" | head -8 | sed 's/^# \?//'; exit 0 ;;
    *) echo "ERROR: Unknown argument: $1" >&2; exit 2 ;;
  esac
done

# ── Validate inputs before any side effects ────────────────────────────────────
[[ -d "$REPO_ROOT/skills" ]] || {
  echo "ERROR: $REPO_ROOT/skills not found — is this the superpowers-plus repo?" >&2; exit 1
}
[[ -f "$MANIFEST" ]] || { echo "ERROR: Manifest not found: $MANIFEST" >&2; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "ERROR: python3 is required" >&2; exit 1; }
command -v zip    >/dev/null 2>&1 || { echo "ERROR: zip is required" >&2; exit 1; }
command -v unzip  >/dev/null 2>&1 || { echo "ERROR: unzip is required" >&2; exit 1; }

# ── Canonicalize OUTDIR to absolute path (safe for --output relative/dir) ─────
_outdir_parent="$(dirname "$OUTDIR")"
_outdir_base="$(basename "$OUTDIR")"
mkdir -p "$_outdir_parent" || { echo "ERROR: Cannot create parent dir: $_outdir_parent" >&2; exit 2; }
OUTDIR="$(cd "$_outdir_parent" && pwd)/$_outdir_base"

# ── Guard against rm -rf on system or home directories ─────────────────────────
case "$OUTDIR" in
  /|/bin|/usr|/usr/local|/etc|/var|/home|/root|"$HOME"|"$HOME"/Documents|"$HOME"/Desktop|"$HOME"/Downloads)
    echo "ERROR: Refusing to wipe system or home directory: $OUTDIR" >&2
    echo "       Use a subdirectory, e.g.: --output '$OUTDIR/claude-skills'" >&2
    exit 2 ;;
esac

# ── Parse manifest with python3 (bash 3.2 compat, no jq dependency) ───────────
SKILLS_RAW=""
SKILLS_RAW=$(python3 -c "
import json, sys
try:
    with open(sys.argv[1]) as f:
        data = json.load(f)
    if 'skills' not in data:
        print('ERROR: manifest missing required \"skills\" key', file=sys.stderr)
        sys.exit(1)
    for s in data['skills']:
        print(s)
except json.JSONDecodeError as e:
    print(f'ERROR: manifest is not valid JSON: {e}', file=sys.stderr)
    sys.exit(1)
" "$MANIFEST") || { echo "ERROR: Failed to parse manifest: $MANIFEST" >&2; exit 1; }

SKILLS=()
while IFS= read -r line; do
  [[ -n "$line" ]] && SKILLS+=("$line")
done <<< "$SKILLS_RAW"

[[ ${#SKILLS[@]} -gt 0 ]] || { echo "ERROR: No skills found in manifest: $MANIFEST" >&2; exit 1; }

# ── Pre-flight: verify ALL skills exist before producing any output ────────────
MISSING=()
for name in "${SKILLS[@]}"; do
  matches=$(find "$REPO_ROOT/skills" -type f -name "skill.md" -path "*/$name/skill.md" 2>/dev/null | wc -l | tr -d ' ')
  if [[ "$matches" -eq 0 ]]; then
    MISSING+=("$name")
  elif [[ "$matches" -gt 1 ]]; then
    echo "WARNING: '$name' matches $matches paths — using first match" >&2
  fi
done
if [[ ${#MISSING[@]} -gt 0 ]]; then
  echo "ERROR: Skills not found in source tree (fix manifest before packaging):" >&2
  printf '  - %s\n' "${MISSING[@]}" >&2
  exit 1
fi

# ── Set up output dir ──────────────────────────────────────────────────────────
TMPWORK=""
TMPWORK="$(mktemp -d)"
trap 'rm -rf "$TMPWORK"' EXIT

if [[ $KEEP -eq 0 ]]; then
  rm -rf "$OUTDIR"
fi
mkdir -p "$OUTDIR"

# ── Package each skill ─────────────────────────────────────────────────────────
FAIL=0
PACKED=()
for name in "${SKILLS[@]}"; do
  src_md=""
  src_md=$(find "$REPO_ROOT/skills" -type f -name "skill.md" -path "*/$name/skill.md" 2>/dev/null | head -1)

  if [[ -z "$src_md" ]]; then
    echo "ERROR: skill.md not found for '$name' under $REPO_ROOT/skills" >&2
    FAIL=1; continue
  fi

  src_dir="$(dirname "$src_md")"
  work_dir="$TMPWORK/$name"
  mkdir -p "$work_dir"

  cp "$src_md" "$work_dir/skill.md" \
    || { echo "ERROR: cp failed for '$name'" >&2; FAIL=1; continue; }

  if [[ -d "$src_dir/resources" ]]; then
    cp -r "$src_dir/resources" "$work_dir/resources" \
      || echo "WARNING: resources/ copy failed for '$name', continuing without resources" >&2
  fi

  zip_path="$OUTDIR/$name.zip"
  (cd "$TMPWORK" && zip -r "$zip_path" "$name/") \
    || { echo "ERROR: zip failed for '$name'" >&2; FAIL=1; rm -rf "$work_dir"; continue; }

  validate_dir="$TMPWORK/validate_$name"
  mkdir -p "$validate_dir"
  unzip -q "$zip_path" -d "$validate_dir" \
    || { echo "ERROR: unzip validation failed for '$name'" >&2; FAIL=1; rm -rf "$work_dir" "$validate_dir"; continue; }

  if [[ ! -f "$validate_dir/$name/skill.md" ]]; then
    echo "ERROR: ZIP structure invalid for '$name' — $name/skill.md not found inside ZIP" >&2
    FAIL=1
  else
    PACKED+=("$name")
  fi
  rm -rf "$work_dir" "$validate_dir"
done

# ── Result ─────────────────────────────────────────────────────────────────────
if [[ $FAIL -ne 0 ]]; then
  echo "" >&2
  echo "ERROR: One or more skills failed to package. Fix errors above and re-run." >&2
  exit 1
fi

echo ""
echo "Packaged ${#PACKED[@]} of ${#SKILLS[@]} skills -> $OUTDIR"
echo ""
echo "Upload steps (claude.ai, format verified 2026-06-27):"
echo "  1. Go to: https://claude.ai/customize/skills"
echo "  2. Click 'Add skill' and upload each .zip from: $OUTDIR"
echo "  3. Enable each skill after upload"
echo ""
echo "After 'git pull' + './install.sh --upgrade', re-run this script and re-upload changed ZIPs."

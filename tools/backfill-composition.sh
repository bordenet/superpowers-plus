#!/usr/bin/env bash
# backfill-composition.sh — Insert composition: blocks into skill frontmatter
# Usage: ./tools/backfill-composition.sh docs/composition-manifest.json
#
# Reads a JSON manifest mapping skill names to composition metadata.
# For each skill, if its skill.md lacks a composition: block, inserts one
# before the closing --- of the YAML frontmatter.
set -euo pipefail

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    cat << 'EOF'
Usage: tools/backfill-composition.sh <manifest.json>

Reads a JSON manifest mapping skill names to composition metadata.
For each skill, if its skill.md lacks a composition: block, inserts one
before the closing --- of the YAML frontmatter.

Arguments:
  manifest.json   Path to composition manifest JSON file
EOF
    exit 0
fi

MANIFEST="${1:?Usage: $0 <manifest.json>}"
SKILLS_DIR="skills"
UPDATED=0
SKIPPED=0
ERRORS=0

if ! command -v python3 >/dev/null 2>&1; then
  echo "ERROR: python3 required" >&2
  exit 1
fi

if [[ ! -f "$MANIFEST" ]]; then
  echo "ERROR: Manifest not found: $MANIFEST" >&2
  exit 1
fi

# Validate JSON before starting
if ! python3 -c "import json; json.load(open('$MANIFEST'))" 2>/dev/null; then
  echo "ERROR: Invalid JSON: $MANIFEST" >&2
  exit 1
fi

# Get list of skill names from manifest
SKILL_NAMES=$(python3 -c "
import json
with open('$MANIFEST') as f:
    data = json.load(f)
for name in sorted(data.keys()):
    print(name)
")

# Phase 1: Pre-validate ALL target files before modifying any
declare -A TARGETS=()  # skill_name → skill_file path
PREVALIDATION_ERRORS=0

while IFS= read -r skill_name; do
  skill_file=""
  for candidate in "$SKILLS_DIR"/*/"$skill_name"/skill.md; do
    if [[ -f "$candidate" ]]; then
      skill_file="$candidate"
      break
    fi
  done

  if [[ -z "$skill_file" ]]; then
    echo "WARN: No skill.md found for '$skill_name'" >&2
    (( PREVALIDATION_ERRORS++ )) || true
    continue
  fi

  # Skip if already has composition
  if grep -q "^composition:" "$skill_file"; then
    echo "SKIP: $skill_name (already has composition)"
    (( SKIPPED++ )) || true
    continue
  fi

  # Validate frontmatter structure
  if ! head -1 "$skill_file" | grep -q "^---$"; then
    echo "FAIL: $skill_name — does not start with ---" >&2
    (( PREVALIDATION_ERRORS++ )) || true
    continue
  fi
  if ! awk 'NR==1 && /^---$/{found++; next} /^---$/{exit} END{if(!found) exit 1}' "$skill_file"; then
    echo "FAIL: $skill_name — no closing --- in frontmatter" >&2
    (( PREVALIDATION_ERRORS++ )) || true
    continue
  fi

  TARGETS[$skill_name]="$skill_file"
done <<< "$SKILL_NAMES"

if (( PREVALIDATION_ERRORS > 0 )); then
  echo ""
  echo "ABORT: $PREVALIDATION_ERRORS pre-validation errors. No files were modified." >&2
  exit 1
fi

echo "Pre-validation passed: ${#TARGETS[@]} files to update"
echo ""

# Phase 2: Apply changes (all targets validated)
for skill_name in "${!TARGETS[@]}"; do
  skill_file="${TARGETS[$skill_name]}"

  # Generate the composition block from manifest
  COMP_BLOCK=$(python3 -c "
import json, sys
with open('$MANIFEST') as f:
    data = json.load(f)
meta = data['$skill_name']
lines = ['composition:']
for key in ['consumes', 'produces', 'capabilities']:
    vals = meta.get(key, [])
    formatted = ', '.join(vals)
    lines.append(f'  {key}: [{formatted}]')
lines.append(f'  priority: {meta[\"priority\"]}')
print('\n'.join(lines))
")

  # Find the closing --- of frontmatter and insert before it
  if python3 -c "
import sys

with open('$skill_file', 'r') as f:
    lines = f.readlines()

# Find frontmatter boundaries
if not lines or lines[0].strip() != '---':
    print(f'ERROR: {\"$skill_file\"} does not start with ---', file=sys.stderr)
    sys.exit(1)

closing_idx = None
for i in range(1, len(lines)):
    if lines[i].strip() == '---':
        closing_idx = i
        break

if closing_idx is None:
    print(f'ERROR: No closing --- in {\"$skill_file\"}', file=sys.stderr)
    sys.exit(1)

# Insert composition block before the closing ---
comp_lines = '''$COMP_BLOCK'''.split('\n')
new_lines = lines[:closing_idx] + [l + '\n' for l in comp_lines] + lines[closing_idx:]

with open('$skill_file', 'w') as f:
    f.writelines(new_lines)
"; then
    echo "OK:   $skill_name"
    (( UPDATED++ )) || true
  else
    echo "FAIL: $skill_name" >&2
    (( ERRORS++ )) || true
  fi
done

echo ""
echo "=== Backfill Complete ==="
echo "Updated: $UPDATED"
echo "Skipped: $SKIPPED"
echo "Errors:  $ERRORS"

if (( ERRORS > 0 )); then
  exit 1
fi

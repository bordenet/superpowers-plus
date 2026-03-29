#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Script: harsh-review.sh
# PURPOSE: Comprehensive repository validation - runs ALL quality checks
#          This script is the source of truth for what constitutes a "passing" repo
# USAGE: ./tools/harsh-review.sh [--fix] [--changed-only]
#        --fix          Auto-fix issues where possible (file endings)
#        --changed-only Only check files changed since main (for pre-commit)
# EXIT: 0 = all checks pass, 1 = failures found
# -----------------------------------------------------------------------------
set -euo pipefail

# --- Bash Guard ---
if [ -z "${BASH_VERSION:-}" ]; then
    echo "ERROR: This script requires bash. Run with: bash $0" >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT" || { echo "ERROR: Failed to cd to $REPO_ROOT" >&2; exit 1; }

# shellcheck source=/dev/null
[[ -f "$HOME/.codex/.env" ]] && source "$HOME/.codex/.env"
SP_OVERLAY_DIR="${SPC_SOURCE_DIR:-}"

# Colors
if [[ -t 1 ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    BLUE='\033[0;34m'
    NC='\033[0m'
else
    RED='' GREEN='' YELLOW='' BLUE='' NC=''
fi

# Options
FIX_MODE=false
CHANGED_ONLY=false
VERBOSE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --fix) FIX_MODE=true; shift ;;
        --changed-only) CHANGED_ONLY=true; shift ;;
        --verbose|-v) VERBOSE=true; shift ;;
        --help|-h)
            echo "Usage: $0 [--fix] [--changed-only] [--verbose]"
            echo "  --fix          Auto-fix issues where possible"
            echo "  --changed-only Only check changed files (vs main)"
            echo "  --verbose      Show detailed output"
            exit 0
            ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

# Tracking
ERRORS=0
WARNINGS=0
FIXES=0

log_check() { printf '%b\n' "${BLUE}[CHECK]${NC} $1"; }
# shellcheck disable=SC2329  # Used by callers that source this file
log_pass()  { printf '%b\n' "${GREEN}[PASS]${NC} $1"; }
log_fail()  { printf '%b\n' "${RED}[FAIL]${NC} $1"; ((ERRORS++)) || true; }
log_warn()  { printf '%b\n' "${YELLOW}[WARN]${NC} $1"; ((WARNINGS++)) || true; }
log_fix()   { printf '%b\n' "${GREEN}[FIXED]${NC} $1"; ((FIXES++)) || true; }

# Resolve the comparison base for --changed-only mode.
# Prefers upstream tracking branch; falls back to origin/dev, then origin/main.
resolve_diff_base() {
    local tracking
    tracking="$(git rev-parse --abbrev-ref '@{upstream}' 2>/dev/null || true)"
    if [[ -n "$tracking" ]]; then
        echo "$tracking"
    elif git rev-parse --verify origin/dev &>/dev/null; then
        echo "origin/dev"
    else
        echo "origin/main"
    fi
}

# Get files to check
# Accepts a regex pattern (e.g., '\.sh$') and uses grep -E for filtering in both modes.
# In --changed-only mode: filters git diff output against upstream/dev/main.
# In default mode: lists all repo files then filters by regex.
get_files() {
    local pattern="$1"
    if [[ "$CHANGED_ONLY" == "true" ]]; then
        local base
        base="$(resolve_diff_base)"
        git diff --name-only "${base}...HEAD" 2>/dev/null | grep -E "$pattern" || true
    else
        find . -type f 2>/dev/null | grep -v '/node_modules/' | grep -v '/\.git/' | grep -E "$pattern" || true
    fi
}

get_all_text_files() {
    if [[ "$CHANGED_ONLY" == "true" ]]; then
        local base
        base="$(resolve_diff_base)"
        git diff --name-only "${base}...HEAD" 2>/dev/null | grep -E '\.(md|sh|json|js|ts|yaml|yml|example)$' || true
    else
        find . -type f \( -name "*.md" -o -name "*.sh" -o -name "*.json" -o -name "*.js" -o -name "*.ts" -o -name "*.yaml" -o -name "*.yml" -o -name "*.example" \) 2>/dev/null | grep -v node_modules | grep -v ".git" || true
    fi
}

echo ""
echo "=============================================="
echo "  HARSH REVIEW - Repository Quality Check"
echo "=============================================="
echo ""
[[ "$CHANGED_ONLY" == "true" ]] && echo "Mode: Changed files only (vs $(resolve_diff_base))"
[[ "$FIX_MODE" == "true" ]] && echo "Mode: Auto-fix enabled"
echo ""

# =============================================================================
# CHECK 1: File Endings (must end with exactly one newline)
# =============================================================================
log_check "File endings (single newline at EOF)"

while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    [[ ! -f "$file" ]] && continue
    
    if [[ $(tail -c 1 "$file" | wc -l) -eq 0 ]]; then
        # File doesn't end with newline
        if [[ "$FIX_MODE" == "true" ]]; then
            echo "" >> "$file"
            log_fix "$file (added newline)"
        else
            log_fail "$file: missing final newline"
        fi
    elif [[ "$(tail -c 2 "$file" | wc -l)" -ge 2 ]]; then
        # File ends with extra blank line
        if [[ "$FIX_MODE" == "true" ]]; then
            # Use Python for reliable cross-platform fix
            python3 -c "
import sys
with open('$file', 'rb') as f:
    content = f.read()
content = content.rstrip() + b'\n'
with open('$file', 'wb') as f:
    f.write(content)
"
            log_fix "$file (removed extra blank line)"
        else
            log_fail "$file: extra blank line at EOF"
        fi
    fi
done < <(get_all_text_files)

# =============================================================================
# CHECK 2: Shell Scripts (shellcheck + syntax)
# =============================================================================
log_check "Shell scripts (shellcheck + bash -n)"

# Shellcheck exclusions (style issues, false positives)
# SC1091 - Not following sourced file
# SC2034 - Unused variable
# SC2129 - Consider grouping redirects (style)
# SC2155 - Declare and assign separately (style)
# SC2162 - read without -r (style)
# SC2097/SC2098 - Assignment not seen by subprocess
# SC2015 - A && B || C is not if-then-else (style)
# SC2317 - Command unreachable (false positive)
# SC2064 - Use single quotes in trap (style)
SHELLCHECK_EXCLUDES="SC1091,SC2034,SC2129,SC2155,SC2162,SC2097,SC2098,SC2015,SC2317,SC2064"

if command -v shellcheck &> /dev/null; then
    while IFS= read -r file; do
        [[ -z "$file" ]] && continue
        [[ ! -f "$file" ]] && continue

        # Syntax check
        if ! bash -n "$file" 2>/dev/null; then
            log_fail "$file: bash syntax error"
        fi

        # Shellcheck (exclude style issues and false positives)
        if ! shellcheck -e "$SHELLCHECK_EXCLUDES" "$file" 2>/dev/null; then
            log_fail "$file: shellcheck violations"
        fi
    done < <(get_files '\.sh$')
else
    log_warn "shellcheck not installed - skipping shell lint"
fi

# =============================================================================
# CHECK 3: JSON Syntax
# =============================================================================
log_check "JSON syntax validation"

while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    [[ ! -f "$file" ]] && continue
    
    if ! python3 -c "import json; json.load(open('$file'))" 2>/dev/null; then
        log_fail "$file: invalid JSON"
    fi
done < <(get_files '\.json$')

# =============================================================================
# CHECK 4: Markdown Structure (if markdownlint available)
# =============================================================================
log_check "Markdown structure"

if command -v markdownlint &> /dev/null; then
    while IFS= read -r file; do
        [[ -z "$file" ]] && continue
        [[ ! -f "$file" ]] && continue

        if ! markdownlint --config .markdownlint.json "$file" 2>/dev/null; then
            log_warn "$file: markdownlint issues"
        fi
    done < <(get_files '\.md$')
else
    [[ "$VERBOSE" == "true" ]] && log_warn "markdownlint not installed - skipping markdown lint"
fi

# =============================================================================
# CHECK 5: Shebang Consistency
# =============================================================================
log_check "Shebang consistency (#!/usr/bin/env bash)"

while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    [[ ! -f "$file" ]] && continue

    shebang=$(head -n1 "$file")
    if [[ "$shebang" =~ ^#! ]]; then
        if [[ "$shebang" == "#!/bin/bash" ]]; then
            log_fail "$file: use '#!/usr/bin/env bash' instead of '#!/bin/bash'"
        fi
    fi
done < <(get_files '\.sh$')

# =============================================================================
# CHECK 6: Hardcoded Vendor References (outside _adapters/)
# =============================================================================
log_check "Vendor-neutral design (no hardcoded vendors outside _adapters/ or local overlays)"

VENDOR_PATTERNS="dev\.azure\.com|atlassian|jira\.com|wiki\.int\."
EXTRA_VENDOR_PATTERNS_FILE="${SP_OVERLAY_DIR:-}/tools/harsh-review-vendor-patterns.txt"
if [[ -n "${SP_OVERLAY_DIR:-}" && -f "$EXTRA_VENDOR_PATTERNS_FILE" ]]; then
    while IFS= read -r pattern; do
        [[ -z "$pattern" || "$pattern" =~ ^# ]] && continue
        VENDOR_PATTERNS+="|$pattern"
    done < "$EXTRA_VENDOR_PATTERNS_FILE"
fi

while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    [[ ! -f "$file" ]] && continue
    [[ "$file" == *"_adapters"* ]] && continue  # Skip adapter files
    [[ "$file" == *"CONTRIBUTING"* ]] && continue  # Skip docs that reference examples
    [[ "$file" == *"ARCHITECTURE"* ]] && continue
    [[ "$file" == *"README"* ]] && continue
    [[ "$file" == *"harsh-review.sh" ]] && continue  # Self-referencing pattern definitions
    [[ "$file" == *"_adapters/"* ]] && continue  # Adapters are allowed to be vendor-specific
    [[ "$file" == *"public-repo-ip-audit"* ]] && continue  # Contains example patterns with vendor placeholders

    if grep -qE "$VENDOR_PATTERNS" "$file" 2>/dev/null; then
        log_warn "$file: contains vendor-specific references (should be in _adapters/)"
    fi
done < <(get_files '\.(md|sh)$')

# =============================================================================
# CHECK 7: Required Files Exist
# =============================================================================
log_check "Required repository files"

REQUIRED_FILES=(
    "README.md"
    "AGENTS.md"
    "CLAUDE.md"
    "docs/CONTRIBUTING.md"
    "docs/ARCHITECTURE.md"
    ".editorconfig"
)

for f in "${REQUIRED_FILES[@]}"; do
    if [[ ! -f "$f" ]]; then
        log_fail "Missing required file: $f"
    fi
done

# =============================================================================
# CHECK 8: Skill Structure Validation
# =============================================================================
log_check "Skill directory structure"

for skill_dir in skills/*/; do
    [[ ! -d "$skill_dir" ]] && continue
    [[ "$skill_dir" == "skills/_"* ]] && continue  # Skip _shared, _design, etc.

    # Each skill category should have subdirectories with skill.md
    skill_count=0
    for subdir in "$skill_dir"/*/; do
        [[ ! -d "$subdir" ]] && continue
        if [[ -f "${subdir}skill.md" ]] || [[ -f "${subdir}SKILL.md" ]]; then
            ((skill_count++)) || true
        fi
    done

    if [[ $skill_count -eq 0 ]] && [[ ! -f "${skill_dir}README.md" ]]; then
        log_warn "$skill_dir: no skills or README found"
    fi
done

# =============================================================================
# CHECK 8b: Skill File Length Limit
# =============================================================================
log_check "Skill file length (max 250 lines)"

MAX_SKILL_LINES=250
while IFS= read -r skill_file; do
    line_count=$(wc -l < "$skill_file" | tr -d ' ')
    if [[ "$line_count" -gt "$MAX_SKILL_LINES" ]]; then
        log_fail "$(basename "$(dirname "$skill_file")")/skill.md: ${line_count} lines (max ${MAX_SKILL_LINES})"
    fi
done < <(find skills -name "skill.md" -o -name "SKILL.md" 2>/dev/null)

# =============================================================================
# CHECK 8c: Skill Frontmatter Validation
# =============================================================================
log_check "Skill frontmatter (required fields)"

while IFS= read -r skill_file; do
    skill_name=$(basename "$(dirname "$skill_file")")
    # Check for frontmatter delimiters
    if ! head -1 "$skill_file" | grep -q "^---"; then
        log_fail "$skill_name: missing frontmatter opening ---"
        continue
    fi
    # Check required fields
    frontmatter=$(sed -n '1,/^---$/p' "$skill_file" | tail -n +2)
    if ! echo "$frontmatter" | grep -q "^triggers:"; then
        log_fail "$skill_name: missing 'triggers:' in frontmatter"
    fi
    if ! echo "$frontmatter" | grep -q "^description:"; then
        log_fail "$skill_name: missing 'description:' in frontmatter"
    fi
    if ! echo "$frontmatter" | grep -q "^anti_triggers:"; then
        log_warn "$skill_name: missing 'anti_triggers:' in frontmatter"
    fi
    # Validate coordination metadata (required for DAG generation)
    # Extract coordination block from frontmatter only (not body text)
    if echo "$frontmatter" | grep -q "^coordination:"; then
        coord_block=$(echo "$frontmatter" | sed -n '/^coordination:/,/^[a-z]/p' | sed '$d')
        if ! echo "$coord_block" | grep -q "^  group:"; then
            log_fail "$skill_name: coordination block missing 'group:' (required for DAG generation)"
        fi
        if ! echo "$coord_block" | grep -q "^  order:"; then
            log_fail "$skill_name: coordination block missing 'order:'"
        fi
        if ! echo "$coord_block" | grep -q "^  internal:"; then
            log_fail "$skill_name: coordination block missing 'internal:'"
        fi
    else
        log_fail "$skill_name: missing 'coordination:' block in frontmatter (required for DAG generation)"
    fi
done < <(find skills -name "skill.md" 2>/dev/null)

# =============================================================================
# CHECK 8d: Companion Skill Cross-Reference Validation
# =============================================================================
log_check "Companion skill cross-references (all targets exist)"

while IFS= read -r skill_file; do
    skill_name=$(basename "$(dirname "$skill_file")")
    # Extract companion refs: lines matching "- **skill-name**"
    refs=$(grep -oE '^\- \*\*[a-z][a-z0-9-]+\*\*' "$skill_file" 2>/dev/null | \
        sed 's/- \*\*//;s/\*\*//' || true)
    for ref in $refs; do
        if ! find skills -type d -name "$ref" 2>/dev/null | grep -q .; then
            log_fail "$skill_name: companion ref '$ref' does not exist"
        fi
    done
done < <(find skills -name "skill.md" 2>/dev/null)

# =============================================================================
# CHECK 9: README Skill Count Drift Detection
# =============================================================================
log_check "README skill count consistency"

# Count actual skills
ACTUAL_TOTAL=$(find skills -name "skill.md" -o -name "SKILL.md" 2>/dev/null | wc -l | tr -d ' ')

# Count explicit skills from EXPLICIT_SKILLS array in skill-trigger-validator.sh
ACTUAL_EXPLICIT=$(grep -A50 "^EXPLICIT_SKILLS=" tools/skill-trigger-validator.sh 2>/dev/null | grep -c '^\s*"' || echo 0)
ACTUAL_SUPERPOWERS=$((ACTUAL_TOTAL - ACTUAL_EXPLICIT))

# Count domains (directories under skills/ that contain skill files)
ACTUAL_DOMAINS=0
for domain_dir in skills/*/; do
    [[ ! -d "$domain_dir" ]] && continue
    [[ "$(basename "$domain_dir")" == _* ]] && continue  # Skip _shared, _design, etc.
    # Check if domain has any skill files
    if find "$domain_dir" -name "skill.md" -o -name "SKILL.md" 2>/dev/null | grep -q .; then
        ((ACTUAL_DOMAINS++)) || true
    fi
done

# Extract counts from README.md
# Line format: **41 skills** across 9 domains:
# Legacy format also supported: **41 skills** (32 superpowers + 9 explicit) across 9 domains:
README_LINE=$(grep -E '^\*\*[0-9]+ skills\*\*' README.md 2>/dev/null | head -1)

if [[ -n "$README_LINE" ]]; then
    # Use sed for cross-platform compatibility (no grep -P on macOS)
    README_TOTAL=$(echo "$README_LINE" | sed -E 's/.*\*\*([0-9]+) skills.*/\1/')
    README_DOMAINS=$(echo "$README_LINE" | sed -E 's/.*across ([0-9]+) domains.*/\1/')

    DRIFT_FOUND=false
    DRIFT_MSG=""

    if [[ "$README_TOTAL" != "$ACTUAL_TOTAL" ]]; then
        DRIFT_MSG+="  - Total: README says $README_TOTAL, actual is $ACTUAL_TOTAL\n"
        DRIFT_FOUND=true
    fi

    if [[ "$README_DOMAINS" != "$ACTUAL_DOMAINS" ]]; then
        DRIFT_MSG+="  - Domains: README says $README_DOMAINS, actual is $ACTUAL_DOMAINS\n"
        DRIFT_FOUND=true
    fi

    if [[ "$DRIFT_FOUND" == "true" ]]; then
        log_fail "README skill count drift detected:"
        printf '%b\n' "$DRIFT_MSG"
    fi
else
    log_warn "Could not parse skill count line from README.md"
fi

# =============================================================================
# SUMMARY
# =============================================================================
echo ""
echo "=============================================="
echo "  SUMMARY"
echo "=============================================="
echo ""

if [[ $FIXES -gt 0 ]]; then
    printf '%b\n' "${GREEN}Fixed: $FIXES issues${NC}"
fi

if [[ $WARNINGS -gt 0 ]]; then
    printf '%b\n' "${YELLOW}Warnings: $WARNINGS${NC}"
fi

if [[ $ERRORS -gt 0 ]]; then
    printf '%b\n' "${RED}Errors: $ERRORS${NC}"
    echo ""
    printf '%b\n' "${RED}HARSH REVIEW FAILED${NC}"
    echo "Fix all errors before committing."
    exit 1
else
    printf '%b\n' "${GREEN}No errors found.${NC}"
    echo ""
    printf '%b\n' "${GREEN}HARSH REVIEW PASSED${NC}"
    exit 0
fi

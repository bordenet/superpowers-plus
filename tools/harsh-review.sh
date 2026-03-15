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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

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

log_check() { echo -e "${BLUE}[CHECK]${NC} $1"; }
log_pass()  { echo -e "${GREEN}[PASS]${NC} $1"; }
log_fail()  { echo -e "${RED}[FAIL]${NC} $1"; ((ERRORS++)) || true; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; ((WARNINGS++)) || true; }
log_fix()   { echo -e "${GREEN}[FIXED]${NC} $1"; ((FIXES++)) || true; }

# Get files to check
get_files() {
    local pattern="$1"
    if [[ "$CHANGED_ONLY" == "true" ]]; then
        git diff --name-only origin/main...HEAD 2>/dev/null | grep -E "$pattern" || true
    else
        find . -type f -name "$pattern" 2>/dev/null | grep -v node_modules | grep -v ".git" || true
    fi
}

get_all_text_files() {
    if [[ "$CHANGED_ONLY" == "true" ]]; then
        git diff --name-only origin/main...HEAD 2>/dev/null | grep -E '\.(md|sh|json|js|ts|yaml|yml|example)$' || true
    else
        find . -type f \( -name "*.md" -o -name "*.sh" -o -name "*.json" -o -name "*.js" -o -name "*.ts" -o -name "*.yaml" -o -name "*.yml" -o -name "*.example" \) 2>/dev/null | grep -v node_modules | grep -v ".git" || true
    fi
}

echo ""
echo "=============================================="
echo "  HARSH REVIEW - Repository Quality Check"
echo "=============================================="
echo ""
[[ "$CHANGED_ONLY" == "true" ]] && echo "Mode: Changed files only (vs origin/main)"
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
    elif tail -c 2 "$file" | xxd -p | grep -q "0a0a"; then
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
log_check "Vendor-neutral design (no hardcoded vendors outside _adapters/)"

VENDOR_PATTERNS="linear\.app|dev\.azure\.com|atlassian|jira\.com|wiki\.int\.|outline"

while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    [[ ! -f "$file" ]] && continue
    [[ "$file" == *"_adapters"* ]] && continue  # Skip adapter files
    [[ "$file" == *"CONTRIBUTING"* ]] && continue  # Skip docs that reference examples
    [[ "$file" == *"ARCHITECTURE"* ]] && continue
    [[ "$file" == *"README"* ]] && continue

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
# CHECK 9: README Skill Count Drift Detection
# =============================================================================
log_check "README skill count consistency"

# Count actual skills
ACTUAL_TOTAL=$(find skills -name "skill.md" -o -name "SKILL.md" 2>/dev/null | wc -l | tr -d ' ')

# Count explicit skills from EXPLICIT_SKILLS array in skill-trigger-validator.sh
ACTUAL_EXPLICIT=$(grep -A50 "^EXPLICIT_SKILLS=" tools/skill-trigger-validator.sh 2>/dev/null | grep '^\s*"' | wc -l | tr -d ' ')
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
# Line format: **39 skills** (30 superpowers + 9 explicit) across 9 domains:
README_LINE=$(grep -E '^\*\*[0-9]+ skills\*\*' README.md 2>/dev/null | head -1)

if [[ -n "$README_LINE" ]]; then
    # Use sed for cross-platform compatibility (no grep -P on macOS)
    README_TOTAL=$(echo "$README_LINE" | sed -E 's/.*\*\*([0-9]+) skills.*/\1/')
    README_SUPERPOWERS=$(echo "$README_LINE" | sed -E 's/.*\(([0-9]+) superpowers.*/\1/')
    README_EXPLICIT=$(echo "$README_LINE" | sed -E 's/.*\+ ([0-9]+) explicit.*/\1/')
    README_DOMAINS=$(echo "$README_LINE" | sed -E 's/.*across ([0-9]+) domains.*/\1/')

    DRIFT_FOUND=false
    DRIFT_MSG=""

    if [[ "$README_TOTAL" != "$ACTUAL_TOTAL" ]]; then
        DRIFT_MSG+="  - Total: README says $README_TOTAL, actual is $ACTUAL_TOTAL\n"
        DRIFT_FOUND=true
    fi

    if [[ "$README_SUPERPOWERS" != "$ACTUAL_SUPERPOWERS" ]]; then
        DRIFT_MSG+="  - Superpowers: README says $README_SUPERPOWERS, actual is $ACTUAL_SUPERPOWERS\n"
        DRIFT_FOUND=true
    fi

    if [[ "$README_EXPLICIT" != "$ACTUAL_EXPLICIT" ]]; then
        DRIFT_MSG+="  - Explicit: README says $README_EXPLICIT, actual is $ACTUAL_EXPLICIT\n"
        DRIFT_FOUND=true
    fi

    if [[ "$README_DOMAINS" != "$ACTUAL_DOMAINS" ]]; then
        DRIFT_MSG+="  - Domains: README says $README_DOMAINS, actual is $ACTUAL_DOMAINS\n"
        DRIFT_FOUND=true
    fi

    if [[ "$DRIFT_FOUND" == "true" ]]; then
        log_fail "README skill count drift detected:"
        echo -e "$DRIFT_MSG"
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
    echo -e "${GREEN}Fixed: $FIXES issues${NC}"
fi

if [[ $WARNINGS -gt 0 ]]; then
    echo -e "${YELLOW}Warnings: $WARNINGS${NC}"
fi

if [[ $ERRORS -gt 0 ]]; then
    echo -e "${RED}Errors: $ERRORS${NC}"
    echo ""
    echo -e "${RED}HARSH REVIEW FAILED${NC}"
    echo "Fix all errors before committing."
    exit 1
else
    echo -e "${GREEN}No errors found.${NC}"
    echo ""
    echo -e "${GREEN}HARSH REVIEW PASSED${NC}"
    exit 0
fi

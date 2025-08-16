#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Script: harsh-review-loop.sh
# PURPOSE: Recursive validation loop that runs harsh-review until stable.
#          Prevents false "ready to push" claims by requiring consecutive
#          clean passes with no working tree changes.
# USAGE: ./tools/harsh-review-loop.sh [--max-iterations N] [--verbose]
# EXIT: 0 = clean and stable, 1 = still dirty after max iterations
# VERSION: 1.0.0
# -----------------------------------------------------------------------------
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

# Configuration
MAX_ITERATIONS=10
CONSECUTIVE_CLEAN_REQUIRED=2
VERBOSE=false

# Colors
if [[ -t 1 ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'

    CYAN='\033[0;36m'
    BOLD='\033[1m'
    NC='\033[0m'
else
    RED='' GREEN='' YELLOW='' CYAN='' BOLD='' NC=''
fi

# Argument parsing
while [[ $# -gt 0 ]]; do
    case $1 in
        --max-iterations) MAX_ITERATIONS="$2"; shift 2 ;;
        --consecutive) CONSECUTIVE_CLEAN_REQUIRED="$2"; shift 2 ;;
        --verbose|-v) VERBOSE=true; shift ;;
        --help|-h)
            cat << 'EOF'
Usage: harsh-review-loop.sh [OPTIONS]

Runs harsh-review repeatedly until stable (no changes, consecutive passes).

Options:
  --max-iterations N  Maximum iterations before failing (default: 10)
  --consecutive N     Consecutive clean passes required (default: 2)
  --verbose, -v       Show detailed output
  --help, -h          Show this help

Exit codes:
  0  Repository is clean and stable
  1  Failed to reach stable state after max iterations
  2  Script error
EOF
            exit 0
            ;;
        *) echo -e "${RED}Unknown option: $1${NC}" >&2; exit 2 ;;
    esac
done

# State tracking
iteration=0
consecutive_clean=0
total_fixes=0

log_header() {
    echo ""
    echo -e "${BOLD}=== Harsh Review Loop ===${NC}"
    echo -e "Max iterations: $MAX_ITERATIONS"
    echo -e "Consecutive clean required: $CONSECUTIVE_CLEAN_REQUIRED"
    echo ""
}

log_iteration() {
    echo -e "${CYAN}Iteration $1:${NC} $2"
}

get_tree_status() {
    local unstaged staged untracked result=""
    unstaged=$(git diff --name-only 2>/dev/null | wc -l | tr -d ' ')
    staged=$(git diff --cached --name-only 2>/dev/null | wc -l | tr -d ' ')
    untracked=$(git ls-files --others --exclude-standard 2>/dev/null | wc -l | tr -d ' ')
    [[ "$unstaged" -gt 0 ]] && result+="${unstaged} unstaged, "
    [[ "$staged" -gt 0 ]] && result+="${staged} staged, "
    [[ "$untracked" -gt 0 ]] && result+="${untracked} untracked"
    result="${result%, }"
    [[ -z "$result" ]] && result="clean"
    echo "$result"
}

run_harsh_review() {
    local fix_mode="$1" output exit_code=0
    if [[ "$fix_mode" == "true" ]]; then
        output=$("$SCRIPT_DIR/harsh-review.sh" --fix 2>&1) || exit_code=$?
    else
        output=$("$SCRIPT_DIR/harsh-review.sh" 2>&1) || exit_code=$?
    fi
    if [[ "$VERBOSE" == "true" ]]; then
        while IFS= read -r line; do echo "  $line"; done <<< "$output"
    fi
    return $exit_code
}

run_skill_validator() {
    local output exit_code=0
    output=$("$SCRIPT_DIR/skill-trigger-validator.sh" audit 2>&1) || exit_code=$?
    if [[ "$VERBOSE" == "true" ]]; then
        while IFS= read -r line; do echo "  $line"; done <<< "$output"
    fi
    return $exit_code
}

check_version_consistency() {
    # Source of truth: install.sh VERSION variable
    local sot_version
    sot_version=$(grep '^VERSION=' install.sh | cut -d'"' -f2)

    local errors=0
    local checks=()

    # 1. install.sh header comment (caused PR #32)
    local header_version
    header_version=$(grep '# VERSION:' install.sh | awk '{print $3}' || echo "")
    if [[ "$header_version" != "$sot_version" ]]; then
        checks+=("install.sh header: $header_version (expected $sot_version)")
        ((errors++)) || true
    fi

    # 2. plugin.json
    local plugin_version
    plugin_version=$(jq -r '.version' .claude-plugin/plugin.json 2>/dev/null || echo "")
    if [[ "$plugin_version" != "$sot_version" ]]; then
        checks+=("plugin.json: $plugin_version")
        ((errors++)) || true
    fi

    # 3. marketplace.json metadata.version
    local meta_version
    meta_version=$(jq -r '.metadata.version' .claude-plugin/marketplace.json 2>/dev/null || echo "")
    if [[ "$meta_version" != "$sot_version" ]]; then
        checks+=("marketplace.json metadata: $meta_version")
        ((errors++)) || true
    fi

    # 4. marketplace.json plugin entry version
    local entry_version
    entry_version=$(jq -r '.plugins[] | select(.name == "superpowers-plus") | .version' \
        .claude-plugin/marketplace.json 2>/dev/null || echo "")
    if [[ "$entry_version" != "$sot_version" ]]; then
        checks+=("marketplace.json plugin: $entry_version")
        ((errors++)) || true
    fi

    # 5. CHANGELOG.md has entry for current version
    if ! grep -q "## \[$sot_version\]" CHANGELOG.md 2>/dev/null; then
        checks+=("CHANGELOG.md: missing ## [$sot_version] section")
        ((errors++)) || true
    fi

    # 6. CHANGELOG.md [Unreleased] link points to current version
    local unreleased_target
    unreleased_target=$(grep '\[Unreleased\]:' CHANGELOG.md 2>/dev/null | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | tail -1 || echo "")
    if [[ "$unreleased_target" != "v$sot_version" ]]; then
        checks+=("CHANGELOG [Unreleased] link: $unreleased_target (expected v$sot_version)")
        ((errors++)) || true
    fi

    if [[ $errors -gt 0 ]]; then
        echo -e "${RED}Version mismatch (source: install.sh = $sot_version):${NC}"
        for check in "${checks[@]}"; do
            echo "  ✗ $check"
        done
        return 1
    fi

    [[ "$VERBOSE" == "true" ]] && echo -e "  Version: ${GREEN}$sot_version${NC} (6 locations verified)"
    return 0
}

# =============================================================================
# MAIN LOOP
# =============================================================================

log_header
initial_tree_status=$(get_tree_status)
[[ "$VERBOSE" == "true" ]] && echo -e "Initial working tree: $initial_tree_status"
echo ""

while [[ $iteration -lt $MAX_ITERATIONS ]]; do
    ((iteration++)) || true
    tree_before=$(get_tree_status)

    # Run harsh-review with --fix on first pass or if issues found
    if [[ $iteration -eq 1 ]] || [[ $consecutive_clean -eq 0 ]]; then
        if run_harsh_review "true"; then
            tree_after=$(get_tree_status)
            if [[ "$tree_before" != "$tree_after" ]]; then
                log_iteration "$iteration" "${YELLOW}fixes applied${NC} ($tree_after)"
                consecutive_clean=0
                ((total_fixes++)) || true
            else
                log_iteration "$iteration" "${GREEN}CLEAN${NC}"
                ((consecutive_clean++)) || true
            fi
        else
            log_iteration "$iteration" "${RED}issues found, applying fixes...${NC}"
            consecutive_clean=0
            run_harsh_review "true" || true
            ((total_fixes++)) || true
        fi
    else
        # Verification pass (no fixes)
        if run_harsh_review "false"; then
            tree_after=$(get_tree_status)
            if [[ "$tree_before" == "$tree_after" ]]; then
                log_iteration "$iteration" "${GREEN}CLEAN (verification pass)${NC}"
                ((consecutive_clean++)) || true
            else
                log_iteration "$iteration" "${YELLOW}tree changed unexpectedly${NC}"
                consecutive_clean=0
            fi
        else
            log_iteration "$iteration" "${RED}issues found on verification${NC}"
            consecutive_clean=0
        fi
    fi

    # Check if we've achieved stability
    [[ $consecutive_clean -ge $CONSECUTIVE_CLEAN_REQUIRED ]] && break
done

echo ""

# =============================================================================
# FINAL VALIDATION
# =============================================================================

echo -e "${BOLD}=== Final Validation ===${NC}"
echo ""

final_errors=0

echo -n "Harsh review:        "
if run_harsh_review "false"; then
    echo -e "${GREEN}PASS${NC}"
else
    echo -e "${RED}FAIL${NC}"
    ((final_errors++)) || true
fi

echo -n "Skill triggers:      "
if run_skill_validator; then
    echo -e "${GREEN}PASS${NC}"
else
    echo -e "${RED}FAIL${NC}"
    ((final_errors++)) || true
fi

echo -n "Version consistency: "
if check_version_consistency; then
    echo -e "${GREEN}PASS${NC}"
else
    ((final_errors++)) || true
fi

echo -n "Working tree:        "
tree_status=$(get_tree_status)
if [[ "$tree_status" == "clean" ]]; then
    echo -e "${GREEN}clean${NC}"
else
    echo -e "${YELLOW}$tree_status${NC}"
    echo ""
    echo -e "${YELLOW}Note: Stage changes before claiming 'ready to push'.${NC}"
fi

echo ""

# =============================================================================
# SUMMARY
# =============================================================================

echo -e "${BOLD}=== Summary ===${NC}"
echo ""

if [[ $consecutive_clean -ge $CONSECUTIVE_CLEAN_REQUIRED ]] && [[ $final_errors -eq 0 ]]; then
    echo -e "${GREEN}✅ Repository is clean after $iteration iteration(s)${NC}"
    echo -e "   ($consecutive_clean consecutive clean passes, $total_fixes fix round(s))"
    echo ""
    echo -e "${GREEN}${BOLD}READY TO PUSH${NC}"
    exit 0
elif [[ $iteration -ge $MAX_ITERATIONS ]]; then
    echo -e "${RED}❌ Failed to reach stable state after $MAX_ITERATIONS iterations${NC}"
    echo ""
    echo "This usually means:"
    echo "  1. Fixes are introducing new issues"
    echo "  2. There's a circular dependency in validations"
    echo "  3. External changes are modifying the repository"
    echo ""
    echo "Try running manually: ./tools/harsh-review.sh --fix"
    exit 1
else
    echo -e "${RED}❌ Final validation failed with $final_errors error(s)${NC}"
    echo ""
    echo "Fix the errors above and re-run this script."
    exit 1
fi

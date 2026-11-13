#!/usr/bin/env bash
# Internal registered pre-commit checks 1-4. No token/IP/publication authority.
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd -P)"
cd "$REPO_ROOT" || exit 1
STAGED_FILES=$(git diff --cached --name-only --diff-filter=ACMRT)
RED='' YELLOW='' NC=''
ERRORS=0
# -----------------------------------------------------------------------------
# CHECK 1: File endings (single newline at EOF)
# -----------------------------------------------------------------------------
echo -e "${YELLOW}[1/5]${NC} Checking file endings..."

while IFS= read -r file; do
    [[ -z "$file" || ! -f "$file" ]] && continue

    # Skip binary files
    if file "$file" | grep -q "binary"; then
        continue
    fi

    # Check for extra blank lines at EOF (cross-platform: wc -l, not xxd)
    if [[ "$(tail -c 2 "$file" 2>/dev/null | wc -l)" -ge 2 ]]; then
        echo -e "${RED}  ✗ $file: extra blank line at EOF${NC}"
        ERRORS=$((ERRORS + 1))
    fi

    # Check for missing final newline
    if [[ $(tail -c 1 "$file" 2>/dev/null | wc -l) -eq 0 ]]; then
        echo -e "${RED}  ✗ $file: missing final newline${NC}"
        ERRORS=$((ERRORS + 1))
    fi
done <<< "$STAGED_FILES"

# -----------------------------------------------------------------------------
# CHECK 2: Shell script syntax
# -----------------------------------------------------------------------------
echo -e "${YELLOW}[2/5]${NC} Checking shell scripts..."

while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    [[ ! -f "$file" ]] && continue
    # Match *.sh files AND extensionless bash scripts (pre-commit, pre-push, etc.)
    local_is_bash=false
    if [[ "$file" == *.sh ]]; then
        local_is_bash=true
    elif head -1 "$file" 2>/dev/null | grep -qE '^#!.*(bash)'; then
        local_is_bash=true
    fi
    [[ "$local_is_bash" == "true" ]] || continue

    if ! bash -n "$file" 2>/dev/null; then
        echo -e "${RED}  ✗ $file: bash syntax error${NC}"
        ERRORS=$((ERRORS + 1))
    fi

    # Check shebang
    shebang=$(head -n1 "$file")
    if [[ "$shebang" == "#!/bin/bash" ]]; then
        echo -e "${RED}  ✗ $file: use '#!/usr/bin/env bash' not '#!/bin/bash'${NC}"
        ERRORS=$((ERRORS + 1))
    fi
done <<< "$STAGED_FILES"

# -----------------------------------------------------------------------------
# CHECK 3: JSON syntax
# -----------------------------------------------------------------------------
echo -e "${YELLOW}[3/5]${NC} Checking JSON files..."

while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    [[ "$file" != *.json ]] && continue
    [[ ! -f "$file" ]] && continue

    if ! python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$file" 2>/dev/null; then
        echo -e "${RED}  ✗ $file: invalid JSON${NC}"
        ERRORS=$((ERRORS + 1))
    fi
done <<< "$STAGED_FILES"

# -----------------------------------------------------------------------------
# CHECK 4: Shellcheck (if available)
# -----------------------------------------------------------------------------
echo -e "${YELLOW}[4/5]${NC} Running shellcheck..."

# Same exclusions as CI and harsh-review.sh
SHELLCHECK_EXCLUDES="SC1091,SC2034,SC2129,SC2155,SC2162,SC2097,SC2098,SC2015,SC2317,SC2064"

if command -v shellcheck &> /dev/null; then
    while IFS= read -r file; do
        [[ -z "$file" ]] && continue
        [[ ! -f "$file" ]] && continue
        sc_is_bash=false
        if [[ "$file" == *.sh ]]; then
            sc_is_bash=true
        elif head -1 "$file" 2>/dev/null | grep -qE '^#!.*(bash)'; then
            sc_is_bash=true
        fi
        [[ "$sc_is_bash" == "true" ]] || continue

        if ! shellcheck -e "$SHELLCHECK_EXCLUDES" "$file" 2>/dev/null; then
            echo -e "${RED}  ✗ $file: shellcheck violations${NC}"
            ERRORS=$((ERRORS + 1))
        fi
    done <<< "$STAGED_FILES"
else
    echo "shellcheck is required for registered pre-commit coverage" >&2
    ERRORS=$((ERRORS + 1))
fi


[[ "$ERRORS" -eq 0 ]]

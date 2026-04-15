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
# REPO_ROOT resolution — two invocation modes:
#
#   1. Direct run:  `bash /path/to/repo/tools/harsh-review.sh`
#      REPO_ROOT = the git repo containing the script (via git -C on SCRIPT_DIR).
#      This is correct regardless of the caller's working directory.
#
#   2. Overlay wrapper:  wrapper sets _SP_HARSH_REVIEW_OVERLAY=1 and exports
#      SP_OVERLAY_SOURCE_DIR, then exec's this script.
#      REPO_ROOT = SP_OVERLAY_SOURCE_DIR (validated as a git repo root).
#
# _SP_HARSH_REVIEW_OVERLAY is a private protocol between the wrapper and this
# script.  It is NOT set in .env or any ambient config, so direct runs are
# never accidentally redirected by a stale SP_OVERLAY_SOURCE_DIR export.
# _overlay_mode tracks whether we're running via an overlay wrapper.
# Used to gate both REPO_ROOT scoping and vendor-pattern loading.
_overlay_mode=false
_overlay_source_dir=""
if [[ "${_SP_HARSH_REVIEW_OVERLAY:-}" == "1" && -n "${SP_OVERLAY_SOURCE_DIR:-}" ]]; then
    # Snapshot the wrapper-supplied path BEFORE sourcing .env, which may
    # overwrite SP_OVERLAY_SOURCE_DIR with a different repo's path.
    _overlay_source_dir="$SP_OVERLAY_SOURCE_DIR"
    REPO_ROOT="$(git -C "$_overlay_source_dir" rev-parse --show-toplevel 2>/dev/null || true)"
    if [[ -z "$REPO_ROOT" ]]; then
        echo "ERROR: SP_OVERLAY_SOURCE_DIR ($_overlay_source_dir) is not a git repo" >&2
        exit 1
    fi
    _overlay_mode=true
else
    REPO_ROOT="$(git -C "$SCRIPT_DIR/.." rev-parse --show-toplevel 2>/dev/null || true)"
    if [[ -z "$REPO_ROOT" ]]; then
        REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
    fi
fi
unset _SP_HARSH_REVIEW_OVERLAY

cd "$REPO_ROOT" || { echo "ERROR: Failed to cd to $REPO_ROOT" >&2; exit 1; }

# shellcheck source=/dev/null
[[ -f "$HOME/.codex/.env" ]] && source "$HOME/.codex/.env"
# Only load overlay vendor patterns when explicitly in overlay mode.
# Use _overlay_source_dir (snapshotted before .env sourcing), NOT the
# potentially-overwritten SP_OVERLAY_SOURCE_DIR.
if [[ "$_overlay_mode" == "true" ]]; then
    SP_OVERLAY_DIR="$_overlay_source_dir"
    IS_OVERLAY=true
else
    SP_OVERLAY_DIR=""
    IS_OVERLAY=false
fi
unset _overlay_source_dir _overlay_mode

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
# Returns empty string if no valid remote ref can be verified — callers must
# treat an empty base as "fall back to full-repo scan" to stay fail-closed.
resolve_diff_base() {
    local tracking candidate
    tracking="$(git rev-parse --abbrev-ref '@{upstream}' 2>/dev/null || true)"
    if [[ -n "$tracking" ]] && git rev-parse --verify "$tracking" &>/dev/null; then
        echo "$tracking"; return
    fi
    for candidate in origin/dev origin/main; do
        if git rev-parse --verify "$candidate" &>/dev/null; then
            echo "$candidate"; return
        fi
    done
    # No verifiable remote ref — return empty so callers fall back to full scan
    echo ""
}

# Get files to check
# Accepts a regex pattern (e.g., '\.sh$') and uses grep -E for filtering in both modes.
# In --changed-only mode: filters git diff output against upstream/dev/main, plus
# any files currently staged (in the index). Staged files are unioned in so that
# commit-gate.sh catches broken staged content before it is committed.
# In default mode (or when no valid base exists): lists all repo files then filters by regex.
get_files() {
    local pattern="$1"
    if [[ "$CHANGED_ONLY" == "true" ]]; then
        local base
        base="$(resolve_diff_base)"
        {
            if [[ -n "$base" ]]; then
                git diff --name-only "${base}...HEAD" 2>/dev/null
            else
                log_warn "No verifiable remote base found — falling back to full-repo scan"
                find . -type f 2>/dev/null | grep -v '/node_modules/' | grep -v '/\.git/'
            fi
            # Union in staged (index) files so pre-commit gate catches staged breakage
            git diff --cached --name-only 2>/dev/null
        } | sort -u | grep -E "$pattern" || true
    else
        find . -type f 2>/dev/null | grep -v '/node_modules/' | grep -v '/\.git/' | grep -v '/\.agents/' | grep -E "$pattern" || true
    fi
}

get_all_text_files() {
    if [[ "$CHANGED_ONLY" == "true" ]]; then
        local base
        base="$(resolve_diff_base)"
        if [[ -z "$base" ]]; then
            # No verifiable remote base — fall back to full scan (fail-closed)
            get_all_text_files_full; return
        fi
        # Named extensions + extensionless bash hooks under tools/
        # Also union in staged files (git diff --cached) so staged-only breakage is caught.
        {
            git diff --name-only "${base}...HEAD" 2>/dev/null | grep -E '\.(md|sh|json|js|ts|yaml|yml|example)$' || true
            git diff --cached --name-only 2>/dev/null | grep -E '\.(md|sh|json|js|ts|yaml|yml|example)$' || true
            {
                git diff --name-only "${base}...HEAD" 2>/dev/null
                git diff --cached --name-only 2>/dev/null
            } | sort -u | grep -E '^(\.\/)?tools/' | while IFS= read -r f; do
                [[ -f "$f" && ! "$f" == *.* ]] && head -1 "$f" 2>/dev/null | grep -qE '^#!.*(bash)' && echo "$f"
            done || true
        } | sort -u
    else
        get_all_text_files_full
    fi
}

get_all_text_files_full() {
    {
        find . -type f \( -name "*.md" -o -name "*.sh" -o -name "*.json" -o -name "*.js" -o -name "*.ts" -o -name "*.yaml" -o -name "*.yml" -o -name "*.example" \) 2>/dev/null | grep -v node_modules | grep -v ".git" | grep -v "/\.agents/" || true
        # Extensionless bash hooks under tools/
        find . -path './tools/*' -type f ! -name "*.*" 2>/dev/null | grep -v ".git" | while IFS= read -r f; do
            head -1 "$f" 2>/dev/null | grep -qE '^#!.*(bash)' && echo "$f"
        done || true
    } | sort -u
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
with open(sys.argv[1], 'rb') as f:
    content = f.read()
content = content.rstrip() + b'\n'
with open(sys.argv[1], 'wb') as f:
    f.write(content)
" "$file"
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
# SC2016 - Expressions don't expand in single quotes (intentional literal matching)
SHELLCHECK_EXCLUDES="SC1091,SC2034,SC2129,SC2155,SC2162,SC2097,SC2098,SC2015,SC2317,SC2064,SC2016"

if command -v shellcheck &> /dev/null; then
    # Check *.sh files
    while IFS= read -r file; do
        [[ -z "$file" ]] && continue
        [[ ! -f "$file" ]] && continue
        if ! bash -n "$file" 2>/dev/null; then
            log_fail "$file: bash syntax error"
        fi
        if ! shellcheck -e "$SHELLCHECK_EXCLUDES" "$file" 2>/dev/null; then
            log_fail "$file: shellcheck violations"
        fi
    done < <(get_files '\.sh$')

    # Also check extensionless hook scripts (pre-commit, pre-push, etc.) that
    # carry a bash shebang — these are the largest scripts in the repo and were
    # previously excluded from shell linting because they lack a .sh suffix.
    while IFS= read -r file; do
        [[ -z "$file" ]] && continue
        [[ ! -f "$file" ]] && continue
        # Skip files that already matched *.sh above
        [[ "$file" == *.sh ]] && continue
        # Only process files with a bash shebang
        head -1 "$file" 2>/dev/null | grep -qE '^#!.*(bash)' || continue
        if ! bash -n "$file" 2>/dev/null; then
            log_fail "$file: bash syntax error"
        fi
        if ! shellcheck -e "$SHELLCHECK_EXCLUDES" "$file" 2>/dev/null; then
            log_fail "$file: shellcheck violations"
        fi
    # Pattern matches both find output (./tools/) and git diff output (tools/)
    done < <(get_files '^(\.\/)?tools/')
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

    if ! python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$file" 2>/dev/null; then
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
# CHECK 4b: Markdown Table Integrity (blank rows splitting tables)
# A blank line between two table rows breaks the table into two fragments —
# most renderers stop parsing the table at the first blank line.
# This check runs unconditionally (no external tool required).
# =============================================================================
log_check "Markdown table integrity (no blank rows inside tables)"

while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    [[ ! -f "$file" ]] && continue

    result=$(python3 - "$file" <<'PYEOF'
import sys
with open(sys.argv[1]) as f:
    lines = f.readlines()
bad = []
for i, line in enumerate(lines):
    if line.rstrip('\n') == '' and 0 < i < len(lines) - 1:
        prev_table = lines[i-1].startswith('|')
        next_table = any(lines[j].startswith('|') for j in range(i+1, min(i+3, len(lines))))
        if prev_table and next_table:
            bad.append(i+1)
if bad:
    print(' '.join(str(n) for n in bad))
PYEOF
)
    if [[ -n "$result" ]]; then
        log_fail "$file: blank row(s) inside markdown table at line(s): $result"
    fi
done < <(get_files '\.md$')

# =============================================================================
# CHECK 4c: Orphaned Skill References (sp+ only)
# Detects references to skills that no longer exist in the registry.
# FAIL: JSON indexes (high-cost-skills.json, composition-manifest.json) and
#       Mermaid node declarations in skill-dependency-graph.md.
# WARN: Coordination fields (requires/enables/escalates_to) — cross-repo refs OK.
# =============================================================================
if [[ "$IS_OVERLAY" == "true" ]]; then
    log_check "Orphaned skill references (SKIPPED — overlay repo)"
else
    log_check "Orphaned skill references (JSON indexes + Mermaid nodes)"

    python3 - "$REPO_ROOT" <<'PYEOF'
import sys, os, json, re

repo_root = sys.argv[1]
errors = []
warns  = []

# 1. Build valid skill set from directory names
skills_root = os.path.join(repo_root, 'skills')
valid = set()
if os.path.isdir(skills_root):
    for domain in os.listdir(skills_root):
        dd = os.path.join(skills_root, domain)
        if os.path.isdir(dd):
            for skill in os.listdir(dd):
                if os.path.exists(os.path.join(dd, skill, 'skill.md')):
                    valid.add(skill)

if not valid:
    sys.exit(0)  # No skills dir — overlay or empty repo, skip

# 2. high-cost-skills.json
hcs_path = os.path.join(repo_root, 'tools', 'high-cost-skills.json')
if os.path.exists(hcs_path):
    with open(hcs_path) as f:
        hcs = json.load(f)
    for name in hcs:
        if name not in valid:
            errors.append(f'FAIL  high-cost-skills.json: orphaned skill: {name!r}')

# 3. docs/composition-manifest.json
cm_path = os.path.join(repo_root, 'docs', 'composition-manifest.json')
if os.path.exists(cm_path):
    with open(cm_path) as f:
        cm = json.load(f)
    for name in cm:
        if name not in valid:
            errors.append(f'FAIL  composition-manifest.json: orphaned skill: {name!r}')

# 4. skill-dependency-graph.md Mermaid node declarations
graph_path = os.path.join(repo_root, 'docs', 'skill-dependency-graph.md')
if os.path.exists(graph_path):
    with open(graph_path) as f:
        lines = f.readlines()
    for i, line in enumerate(lines, 1):
        m = re.search(r'\["([a-z][a-z0-9-]+)', line)
        if not m:
            continue
        name = m.group(1)
        if name not in valid:
            errors.append(f'FAIL  skill-dependency-graph.md:{i}: orphaned Mermaid node: {name!r}')

# 5. Coordination fields (WARN only — cross-repo refs are legitimate)
for domain in os.listdir(skills_root):
    dd = os.path.join(skills_root, domain)
    if not os.path.isdir(dd):
        continue
    for skill in os.listdir(dd):
        sf = os.path.join(dd, skill, 'skill.md')
        if not os.path.exists(sf):
            continue
        with open(sf) as f:
            content = f.read()
        if not content.startswith('---'):
            continue
        end = content.find('\n---', 3)
        if end == -1:
            continue
        frontmatter = content[3:end]
        for field in ('requires', 'enables', 'escalates_to'):
            m = re.search(rf'{field}:\s*\[(.*?)\]', frontmatter, re.DOTALL)
            if not m:
                continue
            items = re.findall(r'["\']?([a-z][a-z0-9-]+)["\']?', m.group(1))
            for item in items:
                if item and item not in valid:
                    warns.append(f'WARN  {skill}/skill.md coordination.{field}: cross-repo ref: {item!r}')

for w in warns:
    print(w)
for e in errors:
    print(e)

if errors:
    sys.exit(1)
PYEOF
    rc=$?
    if [[ $rc -ne 0 ]]; then
        log_fail "Orphaned skill references detected (see output above)"
    fi
fi

# =============================================================================
# CHECK 5: Shebang Consistency
# =============================================================================
log_check "Shebang consistency (#!/usr/bin/env bash)"

_check_shebang() {
    local file="$1"
    [[ -z "$file" ]] && return
    [[ ! -f "$file" ]] && return
    local shebang
    shebang=$(head -n1 "$file")
    if [[ "$shebang" == "#!/bin/bash" ]]; then
        log_fail "$file: use '#!/usr/bin/env bash' instead of '#!/bin/bash'"
    fi
}

# Check *.sh files
while IFS= read -r file; do
    _check_shebang "$file"
done < <(get_files '\.sh$')

# Also check extensionless bash hooks — mirrors the syntax/shellcheck loop above
while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    [[ ! -f "$file" ]] && continue
    [[ "$file" == *.sh ]] && continue
    head -1 "$file" 2>/dev/null | grep -qE '^#!.*(bash)' || continue
    _check_shebang "$file"
done < <(get_files '^(\.\/)?tools/')

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
# CHECK 6B: Public Repo IP Audit (blocking on new changes)
# =============================================================================
if [[ "$IS_OVERLAY" == "true" ]]; then
    log_check "Public repo IP audit (SKIPPED — overlay/private repo)"
else
    log_check "Public repo IP audit (blocking on new changes)"
    if bash "$REPO_ROOT/tools/public-repo-ip-check.sh"; then
        log_pass "public-repo-ip-check.sh"
    else
        log_fail "public-repo-ip-check.sh failed"
    fi
fi

# =============================================================================
# CHECK 7: Required Files Exist (sp+ layout only — skip for overlay repos)
# =============================================================================
if [[ "$IS_OVERLAY" == "true" ]]; then
    log_check "Required repository files (SKIPPED — overlay repo)"
else
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
fi

# =============================================================================
# CHECKS 8–9: Skill structure, frontmatter, companions, README drift
# These checks are sp+-specific layout requirements. Overlay repos have their
# own directory conventions, so we skip these entirely in overlay mode.
# =============================================================================
if [[ "$IS_OVERLAY" == "true" ]]; then
    log_check "Skill structure / frontmatter / README drift (SKIPPED — overlay repo)"
else

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
README_LINE=$(grep -E '^\*\*[0-9]+ skills\*\*' README.md 2>/dev/null | head -1 || true)

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

fi  # end IS_OVERLAY guard for checks 8–9

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
    # Write review proof token
    REVIEW_TOKEN_DIR="${HOME}/.codex/review-tokens"
    mkdir -p "$REVIEW_TOKEN_DIR"
    token_file="${REVIEW_TOKEN_DIR}/$(date +%s)"
    # Canonicalize so symlinked paths (/var → /private/var) match pre-commit's
    # git-rev-parse based REPO_ROOT.  pwd -P is POSIX; realpath fallback is
    # available on Linux but absent on stock macOS without coreutils.
    _canon_repo="$(cd "$REPO_ROOT" && pwd -P 2>/dev/null)" || _canon_repo="$REPO_ROOT"
    # Token filename: <repo_cksum>.<epoch>.<pid>  — collision-safe (two concurrent
    # harsh-review runs can't overwrite each other) and repo-namespaced (GC can
    # restrict deletion to the current repo without reading file contents).
    _repo_cksum=$(printf '%s' "$_canon_repo" | cksum | awk '{print $1}')
    token_file="${REVIEW_TOKEN_DIR}/${_repo_cksum}.$(date +%s).$$"
    echo "$_canon_repo" > "$token_file"
    exit 0
fi

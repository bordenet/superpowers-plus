#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Script: run-battery.sh
# PURPOSE: Run the automated quality suite and write .code-review-cleared.
#          This is the ONLY permitted way to write the sentinel file.
#          Run AFTER completing the AI judgment component of code-review-battery.
# USAGE:   tools/run-battery.sh [--verdict PASS|PASS_WITH_NITS] [--min-score N]
#                               [--staged]
#            N        = quality threshold, 1.0–10.0 (default 7.0)
#            --staged = verify the staged tree instead of HEAD. The sentinel
#                       records the index tree SHA (via `git write-tree`)
#                       prefixed with "tree:" so a follow-up commit can claim
#                       it without re-running the full battery.
# EXIT:    0 = all checks pass, sentinel written
#          1 = failure, sentinel NOT written
# -----------------------------------------------------------------------------
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Resolve repo root from the caller's CWD so the sentinel lands in the right
# repo when run-battery.sh is invoked from an overlay repo.
# Fall back to the script's own repo only when not called from inside a git tree.
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"
if [[ -z "$REPO_ROOT" ]]; then
  REPO_ROOT="$(git -C "$SCRIPT_DIR/.." rev-parse --show-toplevel 2>/dev/null)"
fi
[[ -n "$REPO_ROOT" ]] || { echo "❌ Cannot locate a git repo from CWD or script dir" >&2; exit 1; }
cd "$REPO_ROOT"

# --- Parse flags ---
VERDICT="PASS"
MIN_SCORE="7.0"
STAGED_MODE=0
_MIN_SCORE_EXPLICIT=0    # set to 1 if --min-score was provided; prevents BugPath override
_BUG_FIX_MODE_EXPLICIT=0 # set to 1 if --mode=bug-fix provided
_FEATURE_MODE_EXPLICIT=0  # set to 1 if --mode=feature provided
_NO_ENVELOPE=0            # set to 1 if --no-envelope provided
USAGE_LINE="Usage: tools/run-battery.sh [--verdict PASS|PASS_WITH_NITS] [--min-score N] [--staged] [--mode=bug-fix|feature] [--no-envelope]"
while [[ $# -gt 0 ]]; do
    case "$1" in
        --help|-h)
            cat << 'EOF'
Usage: tools/run-battery.sh [--verdict PASS|PASS_WITH_NITS] [--min-score N] [--staged]
                             [--mode bug-fix|feature] [--no-envelope]

Run the automated quality suite and write .code-review-cleared.
This is the ONLY permitted way to write the sentinel file.
Run AFTER completing the AI judgment component of code-review-battery.

Options:
  --verdict        PASS or PASS_WITH_NITS (default: PASS)
  --min-score      Quality threshold 1.0–10.0 (default: 7.0; 9.2 in Bug Fix Mode)
  --staged         Verify the staged tree rather than HEAD. The sentinel
                   records `tree:<git-write-tree-sha>`; the post-commit hook
                   promotes it to the new HEAD SHA when the tree matches.
  --mode=bug-fix   Force Bug Fix Review Mode (raises default threshold to 9.2,
                   BugPath Verifier mandatory, evidence verifier required).
                   Auto-detected from branch prefix hotfix/* or fix/<TICKET>-*.
  --mode=feature   Force Standard Review Mode (7.0 threshold). Overrides branch
                   auto-detection even on hotfix/* branches.
  --no-envelope    Skip evidence-verifier gate (ESCAPE HATCH). Use only when the
                   Phase 6 envelope workflow has not yet been adopted. In Bug Fix
                   Mode this escape hatch still prints a loud warning.
  -h, --help       Show this help

Bug Fix Review Mode (9.2 threshold):
  Activated when: branch prefix is hotfix/* or fix/<TICKET>-* (configure allowed
  prefixes in .cr-battery-ticket-prefixes), or --mode=bug-fix is passed.
  In this mode the evidence envelope (Phase 6 JSON) and evidence-replay verifier
  are mandatory. Missing envelope = FAIL. Score cap 6.5 if coverage INSUFFICIENT.
  Add your project's ticket prefix (e.g. PROJ) to .cr-battery-ticket-prefixes
  (one prefix per line, uppercase letters only) to enable auto-detection.

Exit codes:
  0  All checks pass, sentinel written
  1  Failure, sentinel NOT written
EOF
            exit 0
            ;;
        --verdict)
            if [[ $# -lt 2 ]]; then
                echo "❌ --verdict requires a value: PASS or PASS_WITH_NITS" >&2
                echo "$USAGE_LINE" >&2
                exit 1
            fi
            VERDICT="$2"
            shift 2
            ;;
        --verdict=*)
            VERDICT="${1#--verdict=}"
            shift
            ;;
        --min-score)
            if [[ $# -lt 2 ]]; then
                echo "❌ --min-score requires a value (1.0–10.0)" >&2
                echo "$USAGE_LINE" >&2
                exit 1
            fi
            MIN_SCORE="$2"
            _MIN_SCORE_EXPLICIT=1
            shift 2
            ;;
        --min-score=*)
            MIN_SCORE="${1#--min-score=}"
            _MIN_SCORE_EXPLICIT=1
            shift
            ;;
        --staged)
            STAGED_MODE=1
            shift
            ;;
        --mode=bug-fix|--mode=bugfix) _BUG_FIX_MODE_EXPLICIT=1; shift ;;
        --mode=feature) _FEATURE_MODE_EXPLICIT=1; shift ;;
        --mode=*) echo "Unknown --mode value '${1#--mode=}'. Use bug-fix or feature." >&2; exit 1 ;;
        --mode) echo "--mode requires a value: bug-fix or feature." >&2; exit 1 ;;
        --no-envelope) _NO_ENVELOPE=1; shift ;;
        *)
            echo "Unknown flag: $1" >&2
            echo "$USAGE_LINE" >&2
            exit 1
            ;;
    esac
done

if [[ "$VERDICT" != "PASS" && "$VERDICT" != "PASS_WITH_NITS" ]]; then
    echo "❌ Invalid verdict '$VERDICT'. Must be PASS or PASS_WITH_NITS." >&2
    exit 1
fi

if ! [[ "$MIN_SCORE" =~ ^[0-9]+(\.[0-9]+)?$ ]] || \
   ! awk -v s="$MIN_SCORE" 'BEGIN { exit !(s >= 1.0 && s <= 10.0) }'; then
    echo "❌ Invalid --min-score '$MIN_SCORE'. Must be a number between 1.0 and 10.0." >&2
    exit 1
fi

# Bug Fix Review Mode: auto-detect hotfix/* and fix/<TICKET>-* branches.
# Configure allowed ticket prefixes via .cr-battery-ticket-prefixes (one per line,
# uppercase letters only). The built-in prefix list covers common patterns.
# Add your project's prefix (e.g. PROJ) to .cr-battery-ticket-prefixes to enable.
_TICKET_CONFIG="$REPO_ROOT/.cr-battery-ticket-prefixes"
if [[ -f "$_TICKET_CONFIG" ]] && [[ -s "$_TICKET_CONFIG" ]]; then
    _PREFIX_PATTERN=$(grep -E '^[A-Z]+$' "$_TICKET_CONFIG" \
        | head -50 | tr '\n' '|' | sed 's/|$//')
    _PREFIX_PATTERN="${_PREFIX_PATTERN:-PROJ|FEAT|FIX|BUG|INFRA|SEC|QA}"
else
    _PREFIX_PATTERN="PROJ|FEAT|FIX|BUG|INFRA|SEC|QA"
fi
_CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
_BUG_FIX_MODE=0
if [[ "$_FEATURE_MODE_EXPLICIT" == "1" ]]; then
    _BUG_FIX_MODE=0
elif [[ "$_BUG_FIX_MODE_EXPLICIT" == "1" ]]; then
    _BUG_FIX_MODE=1
elif echo "$_CURRENT_BRANCH" | grep -qE "^(hotfix/|fix/(${_PREFIX_PATTERN})-)"; then
    _BUG_FIX_MODE=1
fi
# Raise default threshold to 9.2 in Bug Fix Mode unless operator overrode explicitly.
if [[ "$_BUG_FIX_MODE" == "1" ]] && [[ "$_MIN_SCORE_EXPLICIT" == "0" ]]; then
    MIN_SCORE="9.2"
fi
unset _BUG_FIX_MODE_EXPLICIT _FEATURE_MODE_EXPLICIT _MIN_SCORE_EXPLICIT _TICKET_CONFIG _PREFIX_PATTERN

echo "═══════════════════════════════════════════════════════════"
echo "  run-battery.sh — automated quality suite"
if [[ "$_BUG_FIX_MODE" == "1" ]]; then
    echo "  MODE: Bug Fix Review  |  threshold: ${MIN_SCORE}"
    echo "  Branch: ${_CURRENT_BRANCH:-<detached>}"
    if [[ "$_NO_ENVELOPE" == "1" ]]; then
        echo "  Evidence envelope: BYPASSED (--no-envelope) ⚠️"
    else
        echo "  BugPath Verifier: mandatory  |  Evidence envelope: required"
    fi
else
    echo "  MODE: Standard Review  |  threshold: ${MIN_SCORE}"
    echo "  Branch: ${_CURRENT_BRANCH:-<detached>}"
fi
echo "═══════════════════════════════════════════════════════════"
unset _CURRENT_BRANCH
echo ""
echo "  ⚠  AI JUDGMENT PREREQUISITE"
echo "  The code-review-battery AI judgment component MUST be"
echo "  completed before calling this script. This script only"
echo "  covers automated verification."
echo ""
echo "  ⚠  PHR PREREQUISITE (skill/design changes)"
echo "  If the diff touches skills/ or design docs, run /sp-phr"
echo "  BEFORE this script. harsh-review.sh (Step 1) is a linter,"
echo "  NOT progressive-harsh-review. PHR is a separate AI gate."
echo ""

# Guard: block when there are UNSTAGED modifications (truly dirty worktree).
# Staged-but-uncommitted changes are allowed: battery may run pre-commit and the
# sentinel is written for current HEAD; pre-push then validates SHA on the pushed ref.
# Exclude .code-review-cleared itself (battery writes it; may be tracked by git).
# In --staged mode we additionally require there to BE a staged tree (else the
# tree-SHA sentinel is meaningless).
if ! git diff --quiet -- ':!.code-review-cleared' 2>/dev/null; then
    echo ""
    echo "❌ Unstaged modifications detected."
    echo "   Stage or stash changes before running battery:"
    echo "     git add <files>   # or: git stash"
    echo "   Then re-run: tools/run-battery.sh"
    echo ""
    exit 1
fi

if [[ "$STAGED_MODE" -eq 1 ]]; then
    if git diff --cached --quiet 2>/dev/null; then
        echo "❌ --staged passed but no changes are staged."
        echo "   Stage the changes you intend to commit, then re-run with --staged."
        exit 1
    fi
fi

ERRORS=0

# Linear / issue-tracker ID scanner.
# Ticket IDs (e.g. PROJ-1234) must not appear in product source code — they
# belong in commit messages or documentation. Scanned extensions: .ts .tsx .js
# .jsx .mjs .cjs .go .py .sh .bash. Markdown/JSON/YAML are exempt.
# Configure allowed prefixes via .cr-battery-ticket-prefixes (one per line,
# uppercase letters only). Default allowlist prevents false positives on common
# standard names (UTF-8, RFC-7230, ISO-8601, HTTP-404).
echo "─── Step 1/5: issue ID scanner ───"
_TICKET_CONFIG2="$REPO_ROOT/.cr-battery-ticket-prefixes"
if [[ -f "$_TICKET_CONFIG2" ]] && [[ -s "$_TICKET_CONFIG2" ]]; then
    _SCAN_PATTERN=$(grep -E '^[A-Z]+$' "$_TICKET_CONFIG2" \
        | head -50 | tr '\n' '|' | sed 's/|$//')
    _SCAN_PATTERN="${_SCAN_PATTERN:-PROJ|FEAT|FIX|BUG|INFRA|SEC|QA}"
else
    _SCAN_PATTERN="PROJ|FEAT|FIX|BUG|INFRA|SEC|QA"
fi
_TICKET_BASE2=$(git rev-parse --verify "origin/main" 2>/dev/null \
    || git rev-parse --verify "origin/dev" 2>/dev/null \
    || true)
if [[ -n "$_TICKET_BASE2" ]]; then
    if git diff "${_TICKET_BASE2}...HEAD" --name-only 2>/dev/null >/dev/null; then
        _TICKET_HITS2=$(
            git diff "${_TICKET_BASE2}...HEAD" -- \
                '*.ts' '*.tsx' '*.js' '*.jsx' '*.mjs' '*.cjs' \
                '*.go' '*.py' '*.sh' '*.bash' \
                2>/dev/null \
            | awk -v pat="(${_SCAN_PATTERN})-[0-9]+" '
                BEGIN { cur = "(unknown)" }
                /^\+\+\+ b\// { sub(/^\+\+\+ b\//, ""); cur = $0 }
                /^\+[^+]/ { l = $0
                    while (match(l, pat)) {
                        print cur ": " substr(l, RSTART, RLENGTH)
                        l = substr(l, RSTART + RLENGTH)
                    }
                }
            ' | sort -u || true
        )
        if [[ -n "$_TICKET_HITS2" ]]; then
            echo "❌ Issue tracker ID(s) found in product source code:"
            printf '%s\n' "$_TICKET_HITS2" | while IFS= read -r _line; do printf '   %s\n' "$_line"; done
            echo "   Move ticket references to commit messages and re-run."
            ERRORS=$((ERRORS + 1))
        else
            echo "✓ No issue tracker IDs in source code"
        fi
    else
        echo "⚠️  git diff failed — issue ID scan skipped" >&2
    fi
else
    echo "⚠️  Cannot determine diff base (no origin/main or origin/dev) — scan skipped" >&2
fi
unset _TICKET_CONFIG2 _SCAN_PATTERN _TICKET_BASE2 _TICKET_HITS2
echo ""

# NOTE: install --upgrade is intentionally NOT run here.
# Running it as a battery step has unacceptable side-effects: it mutates the
# live routing catalog before the routing tests run, changing the system under
# test mid-suite. If you need to sync the catalog before running the battery,
# run `bash install.sh --upgrade` manually first.

echo "─── Step 2/5: harsh-review ───"
if "$SCRIPT_DIR/harsh-review.sh"; then
    echo "✓ harsh-review passed"
else
    echo "❌ harsh-review FAILED"
    ERRORS=$((ERRORS + 1))
fi
echo ""

echo "─── Step 3/5: trigger routing tests ───"
if bash "$SCRIPT_DIR/tests/test_trigger_routing.sh" 2>&1; then
    echo "✓ trigger routing tests passed"
else
    echo "❌ trigger routing tests FAILED"
    ERRORS=$((ERRORS + 1))
fi
echo ""

echo "─── Step 4/5: Augment export integrity ───"
if bash "$SCRIPT_DIR/tests/test_augment_export.sh" 2>&1; then
    echo "✓ Augment export tests passed"
else
    echo "❌ Augment export tests FAILED"
    ERRORS=$((ERRORS + 1))
fi
echo ""

echo "─── Step 5/5: skill router unit tests ───"
if node "$SCRIPT_DIR/../test/skill-router.test.js" 2>&1; then
    echo "✓ skill router tests passed"
else
    echo "❌ skill router tests FAILED"
    ERRORS=$((ERRORS + 1))
fi
echo ""

if [[ $ERRORS -gt 0 ]]; then
    echo "═══════════════════════════════════════════════════════════"
    echo "  ❌ BATTERY FAILED — ${ERRORS} check(s) did not pass."
    echo "  Sentinel NOT written. Fix failures and re-run."
    echo "═══════════════════════════════════════════════════════════"
    exit 1
fi

# All automated checks passed — write sentinel.
# In HEAD mode the sentinel SHA must match the commit being pushed.
# In --staged mode the sentinel records the staged tree SHA; the post-commit
# hook promotes it to the new HEAD SHA when the tree matches.
# Do NOT commit .code-review-cleared; push immediately after this script
# (or after the commit, when running in --staged mode).
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
if [[ "$STAGED_MODE" -eq 1 ]]; then
    TREE_SHA=$(git write-tree)
    SENTINEL_SHA="tree:${TREE_SHA}"
    SENTINEL_LABEL="Tree:      ${TREE_SHA:0:8} (staged)"
    NEXT_STEP="git commit            # post-commit hook promotes the sentinel to the new HEAD SHA"
else
    SENTINEL_SHA=$(git rev-parse HEAD)
    SENTINEL_LABEL="Commit:    ${SENTINEL_SHA:0:8}"
    NEXT_STEP="git push"
fi

# cr-battery preservation + evidence-verifier gate.
#
# Bug Fix Mode: envelope is MANDATORY (exit 1 on missing). The evidence verifier
# is also mandatory; --no-envelope bypasses with a loud warning.
#
# Standard Mode: graceful degradation — gate runs only when .cr-battery-runs/
# directory exists (adoption opt-in). If the directory is absent, the check is
# skipped entirely (preserves community-friendly behaviour for repos not yet
# using Phase 6 envelopes).
#
# See skills/engineering/code-review-battery/skill.md Phase 6 for the schema.
PRESERVE_DIR="$REPO_ROOT/.cr-battery-runs"
SHA_FOR_PRESERVE=$(git rev-parse HEAD 2>/dev/null || echo "")

# In Bug Fix Mode: auto-create the directory and require the envelope.
if [[ "$_BUG_FIX_MODE" == "1" ]] && [[ "$STAGED_MODE" -ne 1 ]]; then
    if [[ ! -d "$PRESERVE_DIR" ]]; then
        mkdir -p "$PRESERVE_DIR" 2>/dev/null || true
        echo "ℹ️  Created .cr-battery-runs/ — evidence envelopes go here (see skill.md Phase 6)." >&2
    fi
fi

if [[ "$STAGED_MODE" -ne 1 ]] && [[ -n "$SHA_FOR_PRESERVE" ]]; then
    PRESERVE_FILE="$PRESERVE_DIR/${SHA_FOR_PRESERVE}.json"
    _NEED_ENVELOPE=0

    if [[ "$_BUG_FIX_MODE" == "1" ]]; then
        # Bug Fix Mode: envelope is mandatory regardless of --no-envelope
        _NEED_ENVELOPE=1
    elif [[ -d "$PRESERVE_DIR" ]]; then
        # Standard Mode: graceful — only check if directory exists
        _NEED_ENVELOPE=1
    fi

    if [[ "$_NEED_ENVELOPE" == "1" ]]; then
        if [[ "$_NO_ENVELOPE" == "1" ]]; then
            echo "⚠️  WARNING: --no-envelope bypass active. Evidence replay SKIPPED." >&2
            echo "   The sentinel will be written WITHOUT verifier confirmation." >&2
            if [[ "$_BUG_FIX_MODE" == "1" ]]; then
                echo "   Bug Fix Mode: this bypass is permitted but strongly discouraged." >&2
            fi
            echo "" >&2
        elif [[ ! -s "$PRESERVE_FILE" ]]; then
            echo "❌ Evidence envelope not found: .cr-battery-runs/${SHA_FOR_PRESERVE}.json" >&2
            echo "" >&2
            echo "   Before calling run-battery.sh, write the Phase 3 aggregated review" >&2
            echo "   output as a JSON envelope to this path." >&2
            echo "   See skills/engineering/code-review-battery/skill.md Phase 6 for the schema." >&2
            echo "" >&2
            echo "   Quick-start (empty envelope — no findings recorded):" >&2
            echo "     mkdir -p .cr-battery-runs" >&2
            echo "     echo '{\"findings\":[],\"clean_dimensions\":[]}' > .cr-battery-runs/${SHA_FOR_PRESERVE}.json" >&2
            echo "   then re-run. Or pass --no-envelope to bypass (prints this warning and continues)." >&2
            echo "" >&2
            echo "   Sentinel NOT written." >&2
            exit 1
        else
            # Validate JSON if jq available
            if command -v jq >/dev/null 2>&1; then
                if ! jq -e . "$PRESERVE_FILE" >/dev/null 2>&1; then
                    echo "❌ cr-battery preservation file is not valid JSON: $PRESERVE_FILE" >&2
                    echo "   The orchestrator wrote a malformed JSON envelope. Inspect and re-run." >&2
                    echo "   Sentinel NOT written." >&2
                    exit 1
                fi
            fi
            # Evidence-replay verifier: mandatory in Bug Fix Mode, runs in Standard
            # Mode when the verifier script exists. Warns and continues if node absent
            # (Standard Mode only — Bug Fix Mode requires node).
            VERIFIER="$SCRIPT_DIR/verify-cr-battery-evidence.js"
            if [[ -f "$VERIFIER" ]] && [[ ! -L "$VERIFIER" ]]; then
                if command -v node >/dev/null 2>&1; then
                    echo "--- cr-battery evidence-replay verifier ---"
                    set +e
                    node "$VERIFIER" "$PRESERVE_FILE" --cwd "$REPO_ROOT"
                    VERIFIER_EXIT=$?
                    set -e
                    if [[ $VERIFIER_EXIT -eq 1 ]]; then
                        echo "❌ Verifier found FALSIFIED reviewer claims. Recompute score" >&2
                        echo "   with dimension caps and re-dispatch affected reviewer." >&2
                        echo "   Sentinel NOT written." >&2
                        exit 1
                    elif [[ $VERIFIER_EXIT -ne 0 ]]; then
                        echo "❌ Verifier exited $VERIFIER_EXIT (usage/IO/parse error). Sentinel NOT written." >&2
                        exit 1
                    fi
                    echo ""
                elif [[ "$_BUG_FIX_MODE" == "1" ]]; then
                    echo "❌ node not on PATH — required for evidence-replay verifier in Bug Fix Mode." >&2
                    echo "   Install Node.js and re-run. Sentinel NOT written." >&2
                    exit 1
                else
                    echo "⚠️  node not on PATH — evidence-replay verifier skipped (Standard Mode)." >&2
                fi
            fi
        fi
    fi
    unset _NEED_ENVELOPE
fi
unset _NO_ENVELOPE _BUG_FIX_MODE SHA_FOR_PRESERVE

echo "v1|${SENTINEL_SHA}|${VERDICT}|${TIMESTAMP}|min-score=${MIN_SCORE}" > "$REPO_ROOT/.code-review-cleared"

echo "═══════════════════════════════════════════════════════════"
echo "  ✅ BATTERY PASSED — sentinel written."
echo ""
echo "  Verdict:   ${VERDICT}"
echo "  Min-score: ${MIN_SCORE}"
echo "  ${SENTINEL_LABEL}"
echo "  Timestamp: ${TIMESTAMP}"
echo ""
echo "  Next step: ${NEXT_STEP}"
echo ""
# Only emit the PHR reminder when the diff actually touches skill/design .md files.
# Delegated to tools/md-files-changed.sh — single source of truth for the
# regex + exclusion (also consumed by the finishing-a-development-branch skill).
if MD_HITS=$("$SCRIPT_DIR/md-files-changed.sh" 2>/dev/null); then
    echo "  ⚠  PHR REQUIRED: This diff touches skills/ or docs/ .md files:"
    while IFS= read -r f; do
        [[ -n "$f" ]] && echo "       - $f"
    done <<< "$MD_HITS"
    echo ""
    echo "     Dispatch progressive-harsh-review BEFORE pushing:"
    echo "       /sp-phr"
    echo "     or, programmatically:"
    echo "       node ~/.codex/superpowers-augment/superpowers-augment.js use-skill progressive-harsh-review"
    echo ""
    echo "     Battery linting != progressive harsh review."
    echo ""
else
    PHR_EXIT=$?
    if [[ "$PHR_EXIT" -eq 2 ]]; then
        echo "  ⚠  PHR REMINDER: Could not determine merge base (no main/master ancestor)."
        echo "     Review the full branch diff manually and confirm /sp-phr was completed if any .md files changed."
        echo ""
    fi
    # exit 1 means "no PHR-relevant files changed" — no reminder needed.
fi
echo "  ⚠  Do NOT commit .code-review-cleared or make additional"
echo "     commits before pushing. The sentinel expires if HEAD"
echo "     moves. Re-run this script if you need to commit more."
echo "═══════════════════════════════════════════════════════════"

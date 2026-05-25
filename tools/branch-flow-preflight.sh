#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Script: branch-flow-preflight.sh
# PURPOSE: TRUSTED-ADVISOR release-management hygiene check.
#          ALWAYS EXITS 0. Never blocks. Never gates. Suggestions only.
#
# USAGE:   tools/branch-flow-preflight.sh                          (auto: check current branch)
#          tools/branch-flow-preflight.sh <source> <target>        (check pair)
#          tools/branch-flow-preflight.sh --identical-check <e1> <e2>
#
# WRITES:  .branch-flow-cleared sentinel (audit trail, not enforcement):
#          v1|<source-tip-sha>|<source>|<target>|<utc-iso-timestamp>
#
# ESCAPE HATCHES (all suppress one specific advisory):
#   - touch .git/base-advisory-ack-<branch-slug>     (per-branch ack)
#   - GIT_BASE_OVERRIDE=1                            (one-shot override)
#   - Branch prefix in {hotfix/, release/, backport/, tagged-release/} (exempt)
#
# MULTI-TEAM CONFIG (optional):
#   - .git-guidance.yml in repo root maps team/prefix -> required-base.
#     Falls back to default_base (origin/dev) if no match.
# -----------------------------------------------------------------------------
set -uo pipefail   # no -e: don't bail on benign no-match

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null || pwd)"
SENTINEL="$REPO_ROOT/.branch-flow-cleared"
CONFIG="$REPO_ROOT/.git-guidance.yml"
LOG="$REPO_ROOT/.git/guidance-log.jsonl"

GREEN=$'\033[0;32m'; YELLOW=$'\033[0;33m'; CYAN=$'\033[0;36m'; NC=$'\033[0m'

ok()       { echo -e "${GREEN}\xe2\x9c\x93 $*${NC}"; }
info()     { echo -e "${CYAN}\xe2\x84\xb9\xef\xb8\x8f  $*${NC}"; }
advisory() { echo -e "${YELLOW}\xf0\x9f\x92\xa1 $*${NC}"; }

log_advisory() {
    [[ -d "$REPO_ROOT/.git" ]] || return 0
    printf '{"ts":"%s","user":"%s","branch":"%s","advisory":"%s"}\n' \
        "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        "$(git config user.email 2>/dev/null || echo unknown)" \
        "$1" \
        "$2" \
        >> "$LOG" 2>/dev/null || true
}

# ---------------------------------------------------------------------------
# Identical-error stop-condition helper (advisory, exits 0 either way).
# ---------------------------------------------------------------------------
if [[ "${1:-}" == "--identical-check" ]]; then
    if [[ $# -ne 3 ]]; then
        info "--identical-check requires two error strings"
        exit 0
    fi
    norm() {
        sed -E '
            s/[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(\.[0-9]+)?(Z|[+-][0-9]{2}:?[0-9]{2})?//g
            s/[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12}//g
            s/req[_-][A-Za-z0-9_-]{4,}//g
            s/urn:[^[:space:]]+//g
            s|/tmp/[A-Za-z0-9._/-]+||g
            s|/var/folders/[A-Za-z0-9._/-]+||g
            s/[a-z][a-z0-9-]*-[a-z0-9]{4,12}-[a-z0-9]{4,12}//g
            s/[a-zA-Z][a-zA-Z0-9.-]+\.(internal|local|cluster|svc)(\.[a-zA-Z0-9.-]+)*//g
            s/([A-Za-z_][A-Za-z0-9._-]*):[0-9]{2,5}([^0-9]|$)/\1\2/g
            s/\bpid[=:][0-9]+//g
            s/[0-9a-f]{8,40}//g
            s/[0-9]{10,}//g
            s/[[:space:]]+/ /g
        ' <<<"$1"
    }
    if [[ "$(norm "$2")" == "$(norm "$3")" ]]; then
        advisory "Identical opaque error after retry. STRONG SUGGESTION: STOP and diagnose before retrying again. Likely causes: sanitization patterns, ASCII compliance, branch-name regex, file size."
        log_advisory "identical-error" "two consecutive identical errors"
    else
        ok "errors differ -- proceed (cautiously)"
    fi
    exit 0
fi

# ---------------------------------------------------------------------------
# Parse args. Auto-mode: no args -> check current branch against required-base.
# Two-arg mode: explicit source+target.
# ---------------------------------------------------------------------------
SOURCE="${1:-$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo HEAD)}"
TARGET="${2:-}"

# ---------------------------------------------------------------------------
# Multi-team config: required base for this branch.
# Default: origin/dev. Override via .git-guidance.yml or explicit TARGET.
# ---------------------------------------------------------------------------
resolve_required_base() {
    # Future: read team-specific base from $CONFIG using $1 (branch name)
    # to match team prefix. For now, single default_base lookup suffices.
    if [[ -n "$TARGET" ]]; then
        echo "origin/$TARGET"
        return
    fi
    if [[ -f "$CONFIG" ]]; then
        # Simple grep-based extraction: look for "default_base:" or matching team prefix
        local default_base
        default_base=$(awk -F': ' '/^default_base:/ {print $2; exit}' "$CONFIG" 2>/dev/null | tr -d '"' | tr -d "'")
        [[ -n "$default_base" ]] && { echo "$default_base"; return; }
    fi
    echo "origin/dev"
}
REQUIRED_BASE="$(resolve_required_base "$SOURCE")"

# ---------------------------------------------------------------------------
# Skip 1: protected/long-lived branches (no advisory needed).
# ---------------------------------------------------------------------------
case "$SOURCE" in
    main|master|develop|dev|staging)
        info "'$SOURCE' is a protected/long-lived branch; advisory skipped."
        exit 0
        ;;
esac

# ---------------------------------------------------------------------------
# Skip 2: known-exempt prefixes (hotfix/release/backport/tagged-release).
# These are documented deviations from the canonical base; do not advise.
# ---------------------------------------------------------------------------
case "$SOURCE" in
    hotfix/*|release/*|backport/*|tagged-release/*)
        info "'$SOURCE' prefix is exempt from base advisory (documented deviation lane)."
        ;;
esac

# ---------------------------------------------------------------------------
# Skip 3: per-branch acknowledgement file.
# ---------------------------------------------------------------------------
ACK_FILE="$REPO_ROOT/.git/base-advisory-ack-${SOURCE//\//-}"
ACKED=false
[[ -f "$ACK_FILE" ]] && ACKED=true

# ---------------------------------------------------------------------------
# Skip 4: env override.
# ---------------------------------------------------------------------------
OVERRIDDEN=false
if [[ "${GIT_BASE_OVERRIDE:-}" == "1" ]]; then
    OVERRIDDEN=true
    info "GIT_BASE_OVERRIDE=1 set -- base advisory suppressed. Please document reason in PR description."
fi

# ---------------------------------------------------------------------------
# Advisory: retry suffix (-vN). Soft warning, never blocks.
# ---------------------------------------------------------------------------
if [[ "$SOURCE" =~ -v[0-9]+$ ]]; then
    advisory "RETRY-SUFFIX ADVISORY: '$SOURCE' looks like a retry branch (-vN suffix)."
    echo "    Recommended recovery for a failed merge: amend the existing branch"
    echo "    ('git commit --amend' + 'git push --force-with-lease'), not a new branch."
    echo "    To suppress for this branch: touch ${ACK_FILE/#$REPO_ROOT\//}"
    log_advisory "retry-suffix" "$SOURCE"
fi

# ---------------------------------------------------------------------------
# Advisory: back-sync / mirror naming. Soft warning.
# ---------------------------------------------------------------------------
case "$SOURCE" in
    chore/back-sync-*|chore/baseline-sync-*|back-sync/*|sync/*|chore/sync-*|mirror/*|chore/mirror-*)
        advisory "BACK-SYNC NAMING ADVISORY: '$SOURCE' uses back-sync/mirror naming."
        echo "    Forward-port semantics are preferred: branch off the destination,"
        echo "    pull changes from the source, PR forward. To suppress: touch ${ACK_FILE/#$REPO_ROOT\//}"
        log_advisory "back-sync-name" "$SOURCE"
        ;;
esac

# ---------------------------------------------------------------------------
# Base alignment advisory (the perplexity-style first-parent chain check).
# ---------------------------------------------------------------------------
run_base_advisory() {
    [[ "$ACKED" == "true" || "$OVERRIDDEN" == "true" ]] && return 0

    # Exempt prefixes already handled above (don't advise but still write sentinel).
    case "$SOURCE" in
        hotfix/*|release/*|backport/*|tagged-release/*) return 0 ;;
    esac

    local source_sha
    source_sha=$(git rev-parse --verify "$SOURCE" 2>/dev/null) || \
        source_sha=$(git rev-parse --verify "origin/$SOURCE" 2>/dev/null) || return 0
    local base_sha
    base_sha=$(git rev-parse --verify "$REQUIRED_BASE" 2>/dev/null) || {
        info "Could not resolve $REQUIRED_BASE -- is the remote fetched? Base advisory skipped."
        return 0
    }

    # Trivial: source IS the base, or base is ancestor of source.
    if [[ "$source_sha" == "$base_sha" ]] || \
       git merge-base --is-ancestor "$base_sha" "$source_sha" 2>/dev/null; then
        ok "base aligned: '$SOURCE' is on $REQUIRED_BASE's history"
        return 0
    fi

    # First-parent chain check: is the merge-base on REQUIRED_BASE's first-parent chain?
    local mb
    mb=$(git merge-base "$source_sha" "$base_sha" 2>/dev/null) || mb=""
    if [[ -n "$mb" ]]; then
        local on_chain
        on_chain=$(git rev-list --first-parent --max-count=500 "$base_sha" 2>/dev/null | grep -cF "$mb" || true)
        if [[ "$on_chain" -gt 0 ]]; then
            ok "base aligned (stale): '$SOURCE' is on $REQUIRED_BASE's first-parent chain; rebase recommended."
            return 0
        fi
    fi

    advisory "BRANCH BASE ADVISORY -- '$SOURCE'"
    cat <<EOF
    ---------------------------------------------------------------------
    Recommended base:  $REQUIRED_BASE
    Detected base:     $(git log --oneline -1 "${mb:-HEAD}" 2>/dev/null || echo unknown)

    The standard flow branches features from $REQUIRED_BASE so changes
    promote through the canonical sequence.

    This branch's merge-base is not on $REQUIRED_BASE's first-parent
    chain, which may mean it was cut from a different long-lived branch
    or an unrelated commit. This is sometimes intentional:
      - Hotfix or emergency patch  -> use 'hotfix/' prefix (exempt)
      - Backport to a release      -> use 'backport/' or 'release/'
      - Cross-team dependency      -> document in PR description
      - Exploratory / throwaway    -> nothing to fix

    To align with the recommended base:
        git fetch origin && git rebase $REQUIRED_BASE

    To acknowledge and suppress this for this branch only:
        touch ${ACK_FILE/#$REPO_ROOT\//}

    To override once (document reason in PR):
        GIT_BASE_OVERRIDE=1 git push

    Nothing is blocked. This message will not repeat after acknowledgement.
    ---------------------------------------------------------------------
EOF
    log_advisory "base-mismatch" "$SOURCE base=$mb expected=$REQUIRED_BASE"
}
run_base_advisory

# ---------------------------------------------------------------------------
# Sanitization pre-scan (warn only). Anti-leak patterns, non-ASCII.
# ---------------------------------------------------------------------------
DIFFRANGE=""
if git rev-parse --verify "$REQUIRED_BASE" >/dev/null 2>&1 && \
   git rev-parse --verify HEAD >/dev/null 2>&1; then
    DIFFRANGE="$REQUIRED_BASE..HEAD"
fi
if [[ -n "$DIFFRANGE" ]]; then
    LEAK_HITS=$(git diff "$DIFFRANGE" 2>/dev/null | grep -E '^\+' | \
        grep -nE '(internal|secret|codename|token|password|apikey)-[a-zA-Z0-9_-]{6,}' || true)
    if [[ -n "$LEAK_HITS" ]]; then
        advisory "SANITIZATION ADVISORY: potential anti-leak triggers in added lines:"
        echo "$LEAK_HITS" | head -5
        echo "    Server-side anti-leak hook may reject on push."
        echo "    For test fixtures, prefer 'FAKE-LEAK-PATTERN-FOR-TEST'."
        log_advisory "sanitization" "$SOURCE"
    fi
    NON_ASCII=$(git diff "$DIFFRANGE" 2>/dev/null | grep -E '^\+' | \
        perl -ne 'print "$.: $_" if /[^\x00-\x7F]/' 2>/dev/null | head -3 || true)
    if [[ -n "$NON_ASCII" ]]; then
        advisory "NON-ASCII ADVISORY: added lines contain non-ASCII characters"
        echo "$NON_ASCII"
        echo "    GitLab ASCII-only commit-msg hook may reject on push."
        log_advisory "non-ascii" "$SOURCE"
    fi
fi

# ---------------------------------------------------------------------------
# Write sentinel (audit trail).
# ---------------------------------------------------------------------------
SOURCE_SHA="$(git rev-parse --verify "$SOURCE" 2>/dev/null \
    || git rev-parse --verify "origin/$SOURCE" 2>/dev/null \
    || git rev-parse HEAD 2>/dev/null \
    || echo unknown)"
TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "v1|${SOURCE_SHA}|${SOURCE}|${TARGET:-${REQUIRED_BASE#origin/}}|${TS}" > "$SENTINEL"
chmod 0644 "$SENTINEL" 2>/dev/null || true

# Always exit 0. This is guidance, not enforcement.
exit 0

#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# pre-push-ip-scan-gate.sh
#
# Gate 3 of the pre-push composer: runs tools/public-repo-ip-check.sh --range
# over each pushed ref's commit range, on public remotes only (GitHub,
# GitLab.com, Bitbucket). Private/internal remotes don't need this scan --
# pushing already-audited-public content to a private mirror cannot leak IP
# to an external party. The code-review gate still applies to all remotes.
# -----------------------------------------------------------------------------
set -euo pipefail

unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_PREFIX

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "$REPO_ROOT" ]]; then
    REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi

# shellcheck source=tools/lib/pre-push-diff-range.sh
source "$REPO_ROOT/tools/lib/pre-push-diff-range.sh"

RED='\033[0;31m'
NC='\033[0m'

REMOTE_NAME="${1:-origin}"

REMOTE_URL="$(git remote get-url "$REMOTE_NAME" 2>/dev/null || echo "")"
# Fail closed: unknown/empty URL -> treat as public, run the scan. Only
# downgrade to private when we positively identify a non-public URL. Match
# both HTTPS (https://github.com/...) and SSH (git@github.com:...) forms.
IS_PUBLIC_REMOTE=true
if [[ -n "$REMOTE_URL" ]] && ! echo "$REMOTE_URL" | grep -qE '(github\.com|gitlab\.com|bitbucket\.org)'; then
    IS_PUBLIC_REMOTE=false
fi

# Required unconditionally, matching the pre-split monolith: this check ran
# regardless of whether the current remote is public, so a private-to-private
# (or unrecognized-origin) push with no audit script still failed closed
# rather than silently skipping. Only the actual SCAN invocation below is
# skipped for private remotes -- the script's presence is not optional.
IP_AUDIT_SCRIPT="$REPO_ROOT/tools/public-repo-ip-check.sh"
if [[ ! -f "$IP_AUDIT_SCRIPT" ]]; then
    echo -e "${RED}Missing tools/public-repo-ip-check.sh — push blocked.${NC}"
    exit 1
fi

if [[ "$IS_PUBLIC_REMOTE" != "true" ]]; then
    echo "  [ip-scan-gate] (skipped — private remote: $REMOTE_URL)"
    exit 0
fi

ERRORS=0
while IFS= read -r _line; do
    read -r _ local_sha remote_ref remote_sha <<< "$_line"
    [[ "$local_sha" == "0000000000000000000000000000000000000000" ]] && continue

    resolve_diff_range "$local_sha" "$remote_sha" "$REMOTE_NAME"
    echo "  Checking commits: $RANGE (${remote_ref#refs/heads/})"

    bash "$IP_AUDIT_SCRIPT" --range "$RANGE" || ERRORS=$((ERRORS + 1))
done

exit $(( ERRORS > 0 ? 1 : 0 ))

#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Script: branch-flow-preflight.sh
# PURPOSE: Validate (source, target) branch pair against the canonical flow
#          and write .branch-flow-cleared sentinel on PASS.
#          Refuses ANY (source, target) pair that violates merge-discipline.
#
# USAGE:   tools/branch-flow-preflight.sh <source-branch> <target-branch>
#          tools/branch-flow-preflight.sh --identical-check <err1> <err2>
# EXIT:    0 on PASS, non-zero on FAIL with specific reason on stderr.
# WRITES:  .branch-flow-cleared sentinel (mode 0644) on PASS, format:
#          v1|<HEAD-sha>|<source>|<target>|<utc-iso-timestamp>
# -----------------------------------------------------------------------------
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null || pwd)"
SENTINEL="$REPO_ROOT/.branch-flow-cleared"

RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; YELLOW=$'\033[0;33m'; NC=$'\033[0m'

fail() { echo -e "${RED}FAIL: $*${NC}" >&2; exit 1; }
ok()   { echo -e "${GREEN}PASS: $*${NC}"; }
note() { echo -e "${YELLOW}note: $*${NC}" >&2; }

# verify_base(source, expected-base-ref)
# Confirms that SOURCE was branched from EXPECTED_BASE -- the gap the
# previous version of this script had (it checked branch NAMES not branch
# ORIGINS). Algorithm:
#   1. source IS the expected-base tip                                -> PASS (just-branched)
#   2. expected-base tip is an ancestor of source                     -> PASS (branched + own commits, base unmoved)
#   3. compare merge-bases against {dev, staging, main}:
#      - pick the candidate whose merge-base is DESCENDANT of the
#        others -- that's the most-recent ancestor, i.e., the branch
#        the source was most likely cut from
#      - if that candidate matches expected-base                      -> PASS (correctly off expected-base)
#      - else                                                          -> FAIL (wrong-base; tell the user which one)
verify_base() {
    local source_ref="$1"
    local expected_base="$2"   # e.g., "origin/dev"
    local expected_short="${expected_base#origin/}"

    local source_sha base_sha
    source_sha=$(git rev-parse --verify "$source_ref" 2>/dev/null) || \
        source_sha=$(git rev-parse --verify "origin/$source_ref" 2>/dev/null) || return 0
    base_sha=$(git rev-parse --verify "$expected_base" 2>/dev/null) || return 0

    # Case 1: source IS the expected-base tip.
    if [[ "$source_sha" == "$base_sha" ]]; then
        ok "base verified: $source_ref is at $expected_base tip"; return 0
    fi

    # Case 2: expected-base is ancestor of source (branched + own commits).
    if git merge-base --is-ancestor "$base_sha" "$source_sha" 2>/dev/null; then
        ok "base verified: $expected_base is an ancestor of $source_ref"
        return 0
    fi

    # Case 3: compute merge-bases against all three candidates and pick
    # the most-recent (the merge-base that is descendant of the others).
    local best_short="" best_mb=""
    for candidate in dev staging main; do
        local cref="origin/$candidate"
        git rev-parse --verify "$cref" >/dev/null 2>&1 || continue
        local mb
        mb=$(git merge-base "$source_sha" "$cref" 2>/dev/null) || continue
        if [[ -z "$best_mb" ]]; then
            best_mb="$mb"; best_short="$candidate"
        elif git merge-base --is-ancestor "$best_mb" "$mb" 2>/dev/null && \
             [[ "$best_mb" != "$mb" ]]; then
            # mb is strictly more-recent than best_mb
            best_mb="$mb"; best_short="$candidate"
        fi
    done

    if [[ -z "$best_short" ]]; then
        fail "source '$source_ref' has NO common ancestor with any canonical-flow branch (dev/staging/main). Looks branched from a completely different history."
    fi

    if [[ "$best_short" == "$expected_short" ]]; then
        ok "base verified (inferred): $source_ref's most-recent merge-base is with $expected_base (${best_mb:0:8})"
        return 0
    fi

    fail "source '$source_ref' appears to be branched off origin/$best_short, NOT $expected_base. Most-recent merge-base is ${best_mb:0:8} with origin/$best_short. Rebranch from $expected_base (or use the appropriate lane: hotfix/* off main, etc.)."
}

# Identical-error stop-condition helper (called as: --identical-check err1 err2)
if [[ "${1:-}" == "--identical-check" ]]; then
    [[ $# -eq 3 ]] || fail "--identical-check requires two error strings"
    norm() {
        # Strip volatile bits in order:
        #   1. ISO-8601 timestamps (contain hex/digits the other rules would eat)
        #   2. UUIDs (8-4-4-4-12 hex; before generic hex rule)
        #   3. request-ids, urns
        #   4. /tmp paths and pod names (k8s/swarm style)
        #   5. host:port and bare hostnames
        #   6. PIDs, generic SHAs, long digit runs
        #   7. collapse whitespace
        sed -E '
            s/[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(\.[0-9]+)?(Z|[+-][0-9]{2}:?[0-9]{2})?//g
            s/[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12}//g
            s/req[_-][A-Za-z0-9_-]{4,}//g
            s/urn:[^[:space:]]+//g
            s|/tmp/[A-Za-z0-9._/-]+||g
            s|/var/folders/[A-Za-z0-9._/-]+||g
            s/[a-z][a-z0-9-]*-[a-z0-9]{4,12}-[a-z0-9]{4,12}//g
            s/[a-zA-Z][a-zA-Z0-9.-]+\.(internal|local|cluster|svc)(\.[a-zA-Z0-9.-]+)*//g
            s/:[0-9]{2,5}([^0-9]|$)/\1/g
            s/\bpid[=:][0-9]+//g
            s/[0-9a-f]{8,40}//g
            s/[0-9]{10,}//g
            s/[[:space:]]+/ /g
        ' <<<"$1"
    }
    if [[ "$(norm "$2")" == "$(norm "$3")" ]]; then
        fail "Identical error after retry. STOP. Diagnose: sanitize, retarget legality, platform paths."
    fi
    ok "errors differ -- proceed (cautiously)"
    exit 0
fi

[[ $# -ge 2 ]] || fail "usage: $0 <source-branch> <target-branch>  OR  $0 --identical-check <err1> <err2>"

SOURCE="$1"
TARGET="$2"

# --- 0. Branch sprawl / back-sync / mirror name guard (runs FIRST so the
#        helpful message fires before generic target/source rejection) ----
if [[ "$SOURCE" =~ -v[0-9]+$ ]]; then
    fail "branch name '$SOURCE' looks like a retry (-vN suffix). The canonical recovery is to fix the existing branch (git commit --amend or new commit + git push --force-with-lease), NOT create a new branch. Delete this branch and amend the original."
fi
case "$SOURCE" in
    chore/back-sync-*|chore/baseline-sync-*|back-sync/*|sync/*|chore/sync-*|mirror/*|chore/mirror-*)
        fail "branch name '$SOURCE' looks like a back-sync or mirror. Both are forbidden. Use a forward-port instead: branch 'forward/<short-desc>' off origin/dev, cherry-pick the out-of-band content, PR to dev."
        ;;
esac

# --- 1. Target must be one of dev|staging|main ----------------------------
case "$TARGET" in
    dev|staging|main) ;;
    *) fail "target '$TARGET' is not dev|staging|main. The canonical flow has exactly three branches." ;;
esac

# --- 2. Source legality per target ----------------------------------------
case "$TARGET" in
    dev)
        case "$SOURCE" in
            feat/*|feature/*|fix/*|bugfix/*|forward/*|revert/*)
                ok "feature lane: $SOURCE -> dev"
                verify_base "$SOURCE" origin/dev
                ;;
            chore/*|doc/*|docs/*|test/*|perf/*|refactor/*|exp/*)
                ok "feature lane (conventional prefix): $SOURCE -> dev"
                verify_base "$SOURCE" origin/dev
                ;;
            *) fail "source '$SOURCE' -> dev rejected. dev accepts feat/* feature/* fix/* bugfix/* forward/* revert/* chore/* doc/* docs/* test/* perf/* refactor/* exp/*. Branch off origin/dev with one of these prefixes." ;;
        esac
        ;;
    staging)
        case "$SOURCE" in
            dev) ok "promotion: dev -> staging" ;;
            revert/*) ok "revert lane: $SOURCE -> staging (local-to-staging revert)" ;;
            *) fail "source '$SOURCE' -> staging rejected. Legal sources: 'dev' (promotion) or 'revert/*' (revert on staging). Feature branches must go to dev first." ;;
        esac
        ;;
    main)
        case "$SOURCE" in
            staging) ok "promotion: staging -> main" ;;
            hotfix/*)
                # Hotfix lane requires a paired forward-port to dev. Recipe convention:
                # source hotfix/<desc>  pairs with  forward/hotfix-<desc>.
                # Hotfix branches MUST be off origin/main (the documented exception
                # to the "off origin/dev" rule).
                verify_base "$SOURCE" origin/main
                FORWARD_BRANCH="forward/hotfix-${SOURCE#hotfix/}"
                note "hotfix lane: $SOURCE -> main. MUST be paired with $FORWARD_BRANCH -> dev (forward-port within 8h)."
                if git rev-parse --verify "origin/$FORWARD_BRANCH" >/dev/null 2>&1; then
                    ok "paired forward-port branch exists: $FORWARD_BRANCH"
                else
                    fail "hotfix lane requires paired forward-port branch '$FORWARD_BRANCH' to exist on origin BEFORE merging hotfix to main. Open it now."
                fi
                ;;
            revert/*)
                # Reverts on main require a paired forward-port. Recipe convention:
                # source revert/<desc>  pairs with  forward/revert-<desc>.
                # Revert-to-main branches must be off origin/main.
                verify_base "$SOURCE" origin/main
                FORWARD_BRANCH="forward/revert-${SOURCE#revert/}"
                if git rev-parse --verify "origin/$FORWARD_BRANCH" >/dev/null 2>&1; then
                    ok "revert lane: $SOURCE -> main, paired forward-port $FORWARD_BRANCH present"
                else
                    fail "revert lane to main requires paired forward-port branch '$FORWARD_BRANCH' on origin. Open it now."
                fi
                ;;
            *) fail "source '$SOURCE' -> main rejected. main accepts ONLY: staging (promotion), hotfix/* (P0 with paired forward/hotfix-*), revert/* (with paired forward/revert-*). NEVER feature branches direct-to-main." ;;
        esac
        ;;
esac

# --- 3. Source branch must currently exist on origin ----------------------
git fetch --quiet origin "$SOURCE" 2>/dev/null || true
if ! git rev-parse --verify "origin/$SOURCE" >/dev/null 2>&1; then
    note "source 'origin/$SOURCE' not yet pushed -- preflight still PASSES but you must push before opening the PR."
fi

# --- 4. Sanitization pre-scan (warn only, doesn't block) ------------------
DIFFRANGE=""
if git rev-parse --verify "origin/$TARGET" >/dev/null 2>&1 && \
   git rev-parse --verify "HEAD" >/dev/null 2>&1; then
    DIFFRANGE="origin/$TARGET..HEAD"
fi
if [[ -n "$DIFFRANGE" ]]; then
    LEAK_HITS="$(git diff "$DIFFRANGE" 2>/dev/null | \
        grep -E '^\+' | \
        grep -nE '(internal|secret|codename|token|password|apikey)-[a-zA-Z0-9_-]{6,}' || true)"
    if [[ -n "$LEAK_HITS" ]]; then
        note "potential anti-leak hook triggers in added lines:"
        echo "$LEAK_HITS" | head -5 >&2
        note "If these are test fixtures, replace with FAKE-LEAK-PATTERN-FOR-TEST before pushing to repos with anti-leak hooks."
    fi
    NON_ASCII="$(git diff "$DIFFRANGE" 2>/dev/null | grep -E '^\+' | LC_ALL=C grep -nP '[^\x00-\x7F]' | head -3 || true)"
    if [[ -n "$NON_ASCII" ]]; then
        note "non-ASCII characters in added lines (some GitLab hooks reject):"
        echo "$NON_ASCII" >&2
    fi
fi

# --- 5. Forward-port empty-diff guard --------------------------------------
# Forward-port branches that cherry-pick the wrong SHA (e.g., a merge-commit
# instead of the squash sha) produce an empty diff against dev. Catch this
# before sentinel write so 3am ops don't push a vacuous PR.
case "$SOURCE" in
    forward/*)
        if git rev-parse --verify "HEAD" >/dev/null 2>&1 && \
           git rev-parse --verify "origin/$TARGET" >/dev/null 2>&1; then
            if git diff --quiet "origin/$TARGET..HEAD" 2>/dev/null; then
                fail "forward-port branch '$SOURCE' has an EMPTY diff vs origin/$TARGET. The cherry-pick likely picked the wrong SHA (a merge commit instead of the squashed content). Investigate before opening the PR."
            fi
        fi
        ;;
esac

# --- 6. Write sentinel -----------------------------------------------------
# Use the source branch's tip SHA, not HEAD. The pre-push hook receives the
# SHA of the ref being pushed (e.g., dev's tip), which may differ from HEAD
# if the operator pushed from another worktree or used `git push <ref>:dev`.
SOURCE_SHA="$(git rev-parse --verify "$SOURCE" 2>/dev/null \
    || git rev-parse --verify "origin/$SOURCE" 2>/dev/null \
    || git rev-parse HEAD 2>/dev/null \
    || echo unknown)"
TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "v1|${SOURCE_SHA}|${SOURCE}|${TARGET}|${TS}" > "$SENTINEL"
chmod 0644 "$SENTINEL"
ok "branch-flow preflight cleared for ${SOURCE} -> ${TARGET}"
ok "sentinel written: $(basename "$SENTINEL")"

# --- 7. Reminder of strategy + delete-branch policy -----------------------
if [[ "$TARGET" == "staging" || "$TARGET" == "main" ]]; then
    note "Promotion PR: use --merge strategy (NOT rebase/squash). Do NOT pass --delete-branch=true."
else
    note "Feature/hotfix/forward/revert PR: ALWAYS pass --delete-branch=true on merge."
fi

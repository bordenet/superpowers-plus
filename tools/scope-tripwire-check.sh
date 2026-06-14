#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# scope-tripwire-check.sh
#
# Defense-in-depth pre-push gate that compares a branch's CUMULATIVE diff
# against the linked Linear ticket's point-estimate. Catches the
# incident-2026-1507 failure mode: a 1-point ticket that grew to +8,750 / -4,195
# LOC across 73 files. The per-commit LOC gate (tools/pre-push-loc-gate.sh)
# missed it because individual commits stayed under 500 LOC; the symptom
# was the cumulative branch.
#
# This gate is ADVISORY by default. Per the decision-2026-06-10-design-pivot design pivot:
# inform engineers, do not block. Block mode is opt-in (or auto-detected
# inside ml/superpowers-plus, the dogfood repo that owns this tool).
#
# Mode dispatch (highest precedence first):
#   1. $SCOPE_TRIPWIRE_MODE env var
#   2. .scope-tripwire-mode file at repo root (committed; one of: warn, block)
#   3. remote.origin.url contains "superpowers-plus" -> block (dogfood)
#   4. else -> warn
#
# Evasion logging: BOTH `SCOPE_TRIPWIRE_BYPASS=1` (block-mode bypass) AND
# `SCOPE_TRIPWIRE_SKIP=1` (full skip) append a structured line to
# .git/scope-tripwire-evasion.log. The log is .git-LOCAL and never pushed --
# this is a trust-the-engineer gate, not central enforcement. The log
# exists so the same engineer can grep their own history.
#
# WIRING (REQUIRED -- the tool does not auto-install). Pick one:
#
#   1. As the sole pre-push hook for a single repo:
#        ln -sf /absolute/path/to/tools/scope-tripwire-check.sh \
#               .git/hooks/pre-push
#        chmod +x .git/hooks/pre-push
#
#   2. Composed alongside pre-push-loc-gate.sh (RECOMMENDED for engineers
#      who already run the LOC gate). In .git/hooks/pre-push:
#        #!/usr/bin/env bash
#        /absolute/path/to/tools/pre-push-loc-gate.sh "$@" || exit $?
#        /absolute/path/to/tools/scope-tripwire-check.sh "$@" || exit $?
#
#   3. Globally via git's core.hooksPath:
#        git config --global core.hooksPath ~/.config/git-hooks
#        # then create ~/.config/git-hooks/pre-push that chains the gates.
#
# Invocation:
#   tools/scope-tripwire-check.sh                  # standard pre-push (reads stdin)
#   tools/scope-tripwire-check.sh <remote> <url>   # git pre-push convention
#   tools/scope-tripwire-check.sh --help           # usage
#   SCOPE_TRIPWIRE_REF=PROJ-1234 tools/scope-tripwire-check.sh  # override ref
#
# Exit codes (stable contract):
#   0  Pass; OR couldn't resolve (no ref / no API key / API down / no estimate);
#      OR warn mode regardless of finding; OR bypass / skip in block mode
#   1  block mode AND cumulative diff exceeds threshold AND no bypass/skip
#   2  usage / invalid env var value / detached HEAD with non-zero arg count
#
# Bypass / skip:
#   SCOPE_TRIPWIRE_BYPASS=1  Acknowledges overage in block mode and pushes
#                            anyway. Logs to .git/scope-tripwire-evasion.log.
#   SCOPE_TRIPWIRE_SKIP=1    Skips the gate entirely (no API call, no diff scan).
#                            Logs to .git/scope-tripwire-evasion.log.
#
# `git push --no-verify` skips this hook entirely (git design limit).

set -euo pipefail
export LC_ALL=C

# --help / -h
if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    sed -n '2,/^# ---/p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
    exit 0
fi

# -----------------------------------------------------------------------------
# Env defaults + validation
# -----------------------------------------------------------------------------
LOC_PER_POINT=${LOC_PER_POINT:-200}
SCOPE_TRIPWIRE_RATIO=${SCOPE_TRIPWIRE_RATIO:-2.0}
SCOPE_TRIPWIRE_CACHE_TTL=${SCOPE_TRIPWIRE_CACHE_TTL:-3600}
SCOPE_TRIPWIRE_BYPASS=${SCOPE_TRIPWIRE_BYPASS:-0}
SCOPE_TRIPWIRE_SKIP=${SCOPE_TRIPWIRE_SKIP:-0}
SCOPE_TRIPWIRE_REF=${SCOPE_TRIPWIRE_REF:-}
SCOPE_TRIPWIRE_BASE=${SCOPE_TRIPWIRE_BASE:-}
SCOPE_TRIPWIRE_MODE=${SCOPE_TRIPWIRE_MODE:-}
LINEAR_API_URL=${LINEAR_API_URL:-https://api.linear.app/graphql}

if ! [[ "$LOC_PER_POINT" =~ ^[1-9][0-9]*$ ]]; then
    echo "ERROR: LOC_PER_POINT=$LOC_PER_POINT is not a positive integer." >&2
    exit 2
fi
# Allow integer or decimal ratio (e.g., 2 or 2.0 or 1.5)
if ! [[ "$SCOPE_TRIPWIRE_RATIO" =~ ^[0-9]+(\.[0-9]+)?$ ]] || \
   [[ "$SCOPE_TRIPWIRE_RATIO" == "0" ]] || [[ "$SCOPE_TRIPWIRE_RATIO" == "0.0" ]]; then
    echo "ERROR: SCOPE_TRIPWIRE_RATIO=$SCOPE_TRIPWIRE_RATIO must be a positive number." >&2
    exit 2
fi
if ! [[ "$SCOPE_TRIPWIRE_CACHE_TTL" =~ ^[0-9]+$ ]]; then
    echo "ERROR: SCOPE_TRIPWIRE_CACHE_TTL=$SCOPE_TRIPWIRE_CACHE_TTL must be a non-negative integer." >&2
    exit 2
fi

# Resolve repo root. Fail-CLOSED if not in a repo (exit 2). The gate must
# only run inside git checkouts -- there is no useful no-op for "not a repo".
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || {
    echo "ERROR: scope-tripwire-check.sh -- not inside a git repo. Fails CLOSED." >&2
    exit 2
}
cd "$REPO_ROOT"

# -----------------------------------------------------------------------------
# Mode dispatch (precedence: env > file > URL > default)
# -----------------------------------------------------------------------------
if [[ -z "$SCOPE_TRIPWIRE_MODE" ]]; then
    if [[ -f "$REPO_ROOT/.scope-tripwire-mode" ]]; then
        # First non-blank, non-# line of the file. Tolerates trailing newline /
        # surrounding whitespace.
        _file_mode=$(grep -v '^#' "$REPO_ROOT/.scope-tripwire-mode" | \
                     awk 'NF{gsub(/^[ \t]+|[ \t]+$/, ""); print; exit}')
        if [[ -n "$_file_mode" ]]; then
            SCOPE_TRIPWIRE_MODE="$_file_mode"
        fi
    fi
fi
if [[ -z "$SCOPE_TRIPWIRE_MODE" ]]; then
    SCOPE_TRIPWIRE_MODE="warn"
fi
if [[ "$SCOPE_TRIPWIRE_MODE" != "block" && "$SCOPE_TRIPWIRE_MODE" != "warn" ]]; then
    echo "ERROR: SCOPE_TRIPWIRE_MODE=$SCOPE_TRIPWIRE_MODE invalid (expected 'block' or 'warn')." >&2
    exit 2
fi

# -----------------------------------------------------------------------------
# Evasion logging (used by both BYPASS and SKIP paths)
# -----------------------------------------------------------------------------
EVASION_LOG="$REPO_ROOT/.git/scope-tripwire-evasion.log"

# log_evasion <action> <ref> <loc> <estimate> <ratio>
# action: BYPASS | SKIP. Other fields may be "-" when unknown (SKIP path).
log_evasion() {
    local action="$1" ref="${2:--}" loc="${3:--}" estimate="${4:--}" ratio="${5:--}"
    local ts user branch
    ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    user=$(git config user.email 2>/dev/null || echo "unknown")
    branch=$(git symbolic-ref --short HEAD 2>/dev/null || echo "detached")
    printf '%s %s %s LOC=%s EST=%s RATIO=%s BRANCH=%s USER=%s\n' \
        "$ts" "$action" "$ref" "$loc" "$estimate" "$ratio" "$branch" "$user" \
        >> "$EVASION_LOG"
}

# -----------------------------------------------------------------------------
# SKIP path (exits early, logs, no API call, no diff scan)
# -----------------------------------------------------------------------------
if [[ "$SCOPE_TRIPWIRE_SKIP" == "1" ]]; then
    log_evasion "SKIP"
    echo "WARNING: SCOPE_TRIPWIRE_SKIP=1 set; bypassing scope-tripwire gate." >&2
    echo "         Logged to .git/scope-tripwire-evasion.log (local only, never pushed)." >&2
    exit 0
fi

# -----------------------------------------------------------------------------
# Step 1: resolve Linear ref from branch name (or override)
# -----------------------------------------------------------------------------
BRANCH=$(git symbolic-ref --short HEAD 2>/dev/null || echo "")
LINEAR_REF=""
if [[ -n "$SCOPE_TRIPWIRE_REF" ]]; then
    # Override path -- skip branch parsing entirely.
    if ! [[ "$SCOPE_TRIPWIRE_REF" =~ ^[A-Z]+-[0-9]+$ ]]; then
        echo "ERROR: SCOPE_TRIPWIRE_REF=$SCOPE_TRIPWIRE_REF must match ^[A-Z]+-[0-9]+$" >&2
        exit 2
    fi
    LINEAR_REF="$SCOPE_TRIPWIRE_REF"
elif [[ -n "$BRANCH" ]]; then
    # Extract Linear refs from branch name. First match wins; advise on multi-ref.
    # The regex matches ANY uppercase-PREFIX-DIGITS pattern (e.g., incident-2026-1507,
    # INFRA-99). Non-Linear matches will fail the API call and cache as
    # not_found -- low blast radius (one wasted API call per branch).
    _refs=$(echo "$BRANCH" | grep -oE '[A-Z]+-[0-9]+' | awk '!seen[$0]++' || true)
    _ref_count=$(echo "$_refs" | grep -c . || true)
    if (( _ref_count == 0 )); then
        echo "scope-tripwire: no Linear ref in branch '$BRANCH'; advisory skipped." >&2
        exit 0
    fi
    LINEAR_REF=$(echo "$_refs" | head -n1)
    if (( _ref_count > 1 )); then
        _ref_list=$(echo "$_refs" | paste -sd, -)
        echo "scope-tripwire: branch has refs [$_ref_list]; using first ($LINEAR_REF). Override with SCOPE_TRIPWIRE_REF=." >&2
    fi
else
    echo "scope-tripwire: detached HEAD and no SCOPE_TRIPWIRE_REF override; advisory skipped." >&2
    exit 0
fi

# -----------------------------------------------------------------------------
# Step 2: cache lookup
# -----------------------------------------------------------------------------
CACHE_DIR="$REPO_ROOT/.git/scope-tripwire-cache"
mkdir -p "$CACHE_DIR"
CACHE_FILE="$CACHE_DIR/$LINEAR_REF.json"
ESTIMATE=""
CACHE_REASON=""

# Portable mtime (BSD stat -f vs GNU stat -c). Both produce epoch seconds.
file_mtime() {
    stat -f%m "$1" 2>/dev/null || stat -c%Y "$1" 2>/dev/null
}

if [[ -f "$CACHE_FILE" ]]; then
    _mtime=$(file_mtime "$CACHE_FILE")
    _now=$(date +%s)
    if [[ -n "$_mtime" ]] && (( _now - _mtime < SCOPE_TRIPWIRE_CACHE_TTL )); then
        # Parse cached JSON. jq is preferred; fall back to grep/sed for portability.
        if command -v jq >/dev/null 2>&1; then
            ESTIMATE=$(jq -r '.estimate // ""' "$CACHE_FILE" 2>/dev/null || echo "")
            CACHE_REASON=$(jq -r '.reason // ""' "$CACHE_FILE" 2>/dev/null || echo "")
        else
            # Minimal JSON parsing: extract "estimate":<number-or-null> and
            # "reason":"<string>". Brittle but cache files are generated by THIS
            # script in step 3, so format is controlled.
            ESTIMATE=$(grep -oE '"estimate"[[:space:]]*:[[:space:]]*[0-9.]+' "$CACHE_FILE" 2>/dev/null \
                       | sed -E 's/.*:[[:space:]]*//' | head -n1)
            CACHE_REASON=$(grep -oE '"reason"[[:space:]]*:[[:space:]]*"[^"]*"' "$CACHE_FILE" 2>/dev/null \
                           | sed -E 's/.*:[[:space:]]*"([^"]*)"/\1/' | head -n1)
        fi
    fi
fi

# -----------------------------------------------------------------------------
# Step 3: Linear API fetch (cache miss / stale)
# -----------------------------------------------------------------------------
if [[ -z "$ESTIMATE" && "$CACHE_REASON" != "no_estimate" && "$CACHE_REASON" != "not_found" ]]; then
    # Cache miss or stale: try to fetch. Resolve LINEAR_API_KEY from environment.
    LINEAR_API_KEY=${LINEAR_API_KEY:-}
    if [[ -z "$LINEAR_API_KEY" ]]; then
        echo "scope-tripwire: LINEAR_API_KEY unset; advisory skipped for $LINEAR_REF." >&2
        exit 0
    fi

    # GraphQL: $ref is bound as a String! variable. $LINEAR_REF is regex-
    # validated above (^[A-Z]+-[0-9]+$) so the only injection surface is the
    # regex itself. JSON envelope is single-quoted; we only interpolate ref.
    # shellcheck disable=SC2016
    _payload=$(printf '{"query":"query($ref:String!){issue(id:$ref){estimate identifier}}","variables":{"ref":"%s"}}' "$LINEAR_REF")
    _resp=$(curl -s --max-time 5 \
        -H "Authorization: $LINEAR_API_KEY" \
        -H "Content-Type: application/json" \
        -d "$_payload" "$LINEAR_API_URL" 2>/dev/null || echo "")

    _now=$(date +%s)
    if [[ -z "$_resp" ]]; then
        # curl failed or timed out -- cache as api_down to prevent re-hammering.
        printf '{"estimate":null,"reason":"api_down","fetched_at":%s}\n' "$_now" > "$CACHE_FILE"
        echo "scope-tripwire: Linear API unreachable for $LINEAR_REF; advisory skipped (cached for ${SCOPE_TRIPWIRE_CACHE_TTL}s)." >&2
        exit 0
    fi

    # Parse response with jq if available (preferred for safety on arbitrary
    # API JSON), else minimal regex.
    if command -v jq >/dev/null 2>&1; then
        _errors=$(echo "$_resp" | jq -r '.errors // empty' 2>/dev/null)
        _issue=$(echo "$_resp" | jq -r '.data.issue // empty' 2>/dev/null)
        _estimate=$(echo "$_resp" | jq -r '.data.issue.estimate // empty' 2>/dev/null)
    else
        # jq-less fallback: detect by presence of "errors" or "issue":null tokens.
        # Fail-open is the contract for any ambiguity here -- both branches lead
        # to exit 0 with cached api_down or not_found.
        if echo "$_resp" | grep -qE '"errors"[[:space:]]*:[[:space:]]*\['; then
            _errors="present"
        else
            _errors=""
        fi
        if echo "$_resp" | grep -qE '"issue"[[:space:]]*:[[:space:]]*null'; then
            _issue=""
        else
            _issue="present"
        fi
        _estimate=$(echo "$_resp" | grep -oE '"estimate"[[:space:]]*:[[:space:]]*[0-9.]+' \
                    | sed -E 's/.*:[[:space:]]*//' | head -n1)
    fi

    if [[ -n "$_errors" ]]; then
        printf '{"estimate":null,"reason":"api_down","fetched_at":%s}\n' "$_now" > "$CACHE_FILE"
        echo "scope-tripwire: Linear API returned errors for $LINEAR_REF; advisory skipped." >&2
        exit 0
    fi
    if [[ -z "$_issue" ]]; then
        printf '{"estimate":null,"reason":"not_found","fetched_at":%s}\n' "$_now" > "$CACHE_FILE"
        echo "scope-tripwire: ticket $LINEAR_REF not found in Linear; advisory skipped." >&2
        exit 0
    fi
    if [[ -z "$_estimate" || "$_estimate" == "null" ]]; then
        printf '{"estimate":null,"reason":"no_estimate","fetched_at":%s}\n' "$_now" > "$CACHE_FILE"
        echo "scope-tripwire: ticket $LINEAR_REF has no estimate set; advisory skipped." >&2
        exit 0
    fi
    # Success: cache the estimate.
    printf '{"estimate":%s,"reason":"ok","fetched_at":%s}\n' "$_estimate" "$_now" > "$CACHE_FILE"
    ESTIMATE="$_estimate"
fi

# Cached null-estimate paths (no_estimate / not_found) hit before this point.
if [[ -z "$ESTIMATE" ]]; then
    # Cache said null with reason no_estimate/not_found; emit advisory.
    echo "scope-tripwire: $LINEAR_REF estimate unavailable ($CACHE_REASON, cached); advisory skipped." >&2
    exit 0
fi

# -----------------------------------------------------------------------------
# Step 4: compute cumulative LOC against base branch
# -----------------------------------------------------------------------------
if [[ -z "$SCOPE_TRIPWIRE_BASE" ]]; then
    # Three-tier fallback: upstream -> origin/main -> origin/HEAD
    BASE=$(git rev-parse --abbrev-ref '@{upstream}' 2>/dev/null || echo "")
    if [[ -z "$BASE" ]] || ! git rev-parse --verify "$BASE" >/dev/null 2>&1; then
        if git rev-parse --verify origin/main >/dev/null 2>&1; then
            BASE=origin/main
        elif git rev-parse --verify origin/HEAD >/dev/null 2>&1; then
            BASE=origin/HEAD
        else
            echo "scope-tripwire: cannot resolve base branch (no @{upstream}, no origin/main, no origin/HEAD); advisory skipped." >&2
            exit 0
        fi
    fi
else
    BASE="$SCOPE_TRIPWIRE_BASE"
    if ! git rev-parse --verify "$BASE" >/dev/null 2>&1; then
        echo "ERROR: SCOPE_TRIPWIRE_BASE=$BASE does not resolve to a valid ref." >&2
        exit 2
    fi
fi

MERGE_BASE=$(git merge-base HEAD "$BASE" 2>/dev/null || echo "")
if [[ -z "$MERGE_BASE" ]]; then
    echo "scope-tripwire: no merge-base between HEAD and $BASE; advisory skipped." >&2
    exit 0
fi

# git diff --shortstat output: " N files changed, M insertions(+), K deletions(-)"
# Any of M / K may be missing if only-insertions or only-deletions.
_shortstat=$(git diff --shortstat "$MERGE_BASE"..HEAD 2>/dev/null || echo "")
_ins=$(echo "$_shortstat" | grep -oE '[0-9]+ insertion' | grep -oE '[0-9]+' || echo "0")
_del=$(echo "$_shortstat" | grep -oE '[0-9]+ deletion'  | grep -oE '[0-9]+' || echo "0")
_ins=${_ins:-0}
_del=${_del:-0}
LOC=$(( _ins + _del ))

if (( LOC == 0 )); then
    # Nothing to compare; happy-path silent pass.
    exit 0
fi

# -----------------------------------------------------------------------------
# Step 5: threshold + mode dispatch
# -----------------------------------------------------------------------------
# Threshold = LOC_PER_POINT * ESTIMATE * RATIO. Use awk for floating-point
# math (estimate may be 0.5, ratio may be 2.5).
THRESHOLD=$(awk -v lpp="$LOC_PER_POINT" -v est="$ESTIMATE" -v ratio="$SCOPE_TRIPWIRE_RATIO" \
    'BEGIN { printf "%.0f\n", lpp * est * ratio }')
RATIO_OBSERVED=$(awk -v loc="$LOC" -v lpp="$LOC_PER_POINT" -v est="$ESTIMATE" \
    'BEGIN { if (lpp * est == 0) print "inf"; else printf "%.1f\n", loc / (lpp * est) }')

if (( LOC <= THRESHOLD )); then
    exit 0
fi

# Exceeded. Build the structured stderr line shared by warn / block / bypass.
build_overage_line() {
    echo "scope-tripwire: $LINEAR_REF cumulative branch diff $LOC LOC vs estimate ${ESTIMATE}pt (${LOC_PER_POINT} LOC/pt x ${SCOPE_TRIPWIRE_RATIO}x = ${THRESHOLD} threshold); observed ratio ${RATIO_OBSERVED}x"
}

if [[ "$SCOPE_TRIPWIRE_MODE" == "warn" ]]; then
    echo "" >&2
    build_overage_line >&2
    echo "  Mode: WARN (advisory only). Set SCOPE_TRIPWIRE_MODE=block to enforce." >&2
    echo "" >&2
    exit 0
fi

# block mode
if [[ "$SCOPE_TRIPWIRE_BYPASS" == "1" ]]; then
    echo "" >&2
    build_overage_line >&2
    echo "  Mode: BLOCK; SCOPE_TRIPWIRE_BYPASS=1 acknowledged. Pushing anyway." >&2
    echo "  Logged to .git/scope-tripwire-evasion.log (local only)." >&2
    echo "" >&2
    log_evasion "BYPASS" "$LINEAR_REF" "$LOC" "$ESTIMATE" "$RATIO_OBSERVED"
    exit 0
fi

echo "" >&2
build_overage_line >&2
echo "" >&2
echo "REFUSING PUSH. This branch's cumulative diff is more than ${SCOPE_TRIPWIRE_RATIO}x the Linear estimate." >&2
echo "Likely cause: scope drift (the work has grown past what was groomed)." >&2
echo "" >&2
echo "Options:" >&2
echo "  1. Split the branch (smaller, scoped PRs)" >&2
echo "  2. Re-estimate $LINEAR_REF in Linear and 'rm $CACHE_FILE' to refresh" >&2
echo "  3. Bypass with audit:  SCOPE_TRIPWIRE_BYPASS=1 git push ..." >&2
echo "  4. Skip the gate:      SCOPE_TRIPWIRE_SKIP=1 git push ..." >&2
echo "" >&2
exit 1

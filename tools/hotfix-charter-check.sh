#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# hotfix-charter-check.sh
#
# Pre-commit hook that enforces a HOTFIX-CHARTER.md on branches matching a
# CHARTER_BRANCH_PREFIXES prefix (default `hotfix/`). The charter must contain
# four sections:
#
#   ## Symptom (one sentence)
#   ## Diff budget (LOC ceiling)
#   ## cr-battery pre-commit verdict
#   ## Refactoring disposition
#
# The cr-battery section must read PASS or PASS_WITH_NITS. Anything else
# (REJECT, PASS_WITH_FIXES, blank, "passing", "ok") refuses the commit.
#
# Why this exists: the 2026-06-10 incident-2026-1507 incident shipped a hotfix that
# grew to +8,750 LOC / 73 files because nobody captured the customer symptom
# upfront or set an LOC ceiling. See
# skills/engineering/hotfix-charter/skill.md.
#
# WIRING (REQUIRED -- the tool does not auto-install):
#
#   1. As the pre-commit hook for a single repo:
#        ln -sf /absolute/path/to/tools/hotfix-charter-check.sh \
#               .git/hooks/pre-commit
#        chmod +x .git/hooks/pre-commit
#
#   2. Composed alongside an existing pre-commit runner:
#        # In .git/hooks/pre-commit, add BEFORE existing checks:
#        /absolute/path/to/tools/hotfix-charter-check.sh || exit $?
#
#   3. Globally via git's core.hooksPath:
#        git config --global core.hooksPath ~/.config/git-hooks
#        ln -sf /absolute/path/to/tools/hotfix-charter-check.sh \
#               ~/.config/git-hooks/pre-commit
#
# Invocation:
#   tools/hotfix-charter-check.sh                  # standard pre-commit invocation
#   tools/hotfix-charter-check.sh --help           # usage
#
# Exit codes (stable contract):
#   0  Branch is not hotfix-prefix, OR charter is valid AND cr-battery PASS
#   1  Charter missing OR missing a section OR cr-battery/disposition invalid
#   2  Usage / env error (detached HEAD, no repo, non-integer
#      DISPOSITION_NONE_MAX_LINES, etc.) -- fails CLOSED
#
# Bypass: ALLOW_NO_CHARTER=1 git commit ...   (prints WARNING but proceeds)
#
# `git commit --no-verify` skips this hook entirely (git design limit; the hook
# cannot defend against it). Document in the team review checklist.
#
# Refactoring disposition (4th charter section): the first non-blank body line
# must open with EXACTLY ONE of REFACTOR_NOW / PARK / NONE plus one concrete
# reason. PARK / REFACTOR_NOW must cite a backticked `symbol` (3+ identifier
# chars) that appears in the staged added content. NONE is valid only when the
# staged diff changes at most DISPOSITION_NONE_MAX_LINES (default 30) lines,
# counting added + deleted. See skills/engineering/hotfix-charter/skill.md.
#
# Disposition env overrides:
#   REQUIRE_DISPOSITION=0          skip ONLY the disposition check (rollout hatch);
#                                 the three original sections still enforce.
#                                 Only 0/false/no/off disable it -- a truthy-
#                                 looking value still enforces.
#   DISPOSITION_NONE_MAX_LINES=N  max total changed lines (added + deleted)
#                                 allowed with a NONE disposition (default 30)
#
# Branch prefixes that gate (override via CHARTER_BRANCH_PREFIXES env var,
# space-separated). Default: hotfix/ (to gate fix/TICKET-ID-* branches, override
# CHARTER_BRANCH_PREFIXES="hotfix/ fix/" or similar):
#   hotfix/

set -euo pipefail
export LC_ALL=C

# --help / -h
if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    sed -n '2,/^# ---/p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
    exit 0
fi

PREFIXES_DEFAULT="hotfix/"
CHARTER_BRANCH_PREFIXES="${CHARTER_BRANCH_PREFIXES:-$PREFIXES_DEFAULT}"
CHARTER_FILE="${CHARTER_FILE:-HOTFIX-CHARTER.md}"

# Resolve repo root. Fail-closed if not in a repo (exit 2 vs silently passing).
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || {
    echo "ERROR: hotfix-charter-check.sh -- not inside a git repo. Fails CLOSED." >&2
    exit 2
}
cd "$REPO_ROOT"

# Resolve current branch. Detached HEAD -> fail closed (cannot determine prefix).
BRANCH=$(git symbolic-ref --short HEAD 2>/dev/null) || {
    echo "ERROR: hotfix-charter-check.sh -- detached HEAD; cannot determine branch prefix. Fails CLOSED." >&2
    exit 2
}

# Does the branch match any gating prefix?
GATES=0
for prefix in $CHARTER_BRANCH_PREFIXES; do
    if [[ "$BRANCH" == "$prefix"* ]]; then
        GATES=1
        MATCHED_PREFIX="$prefix"
        break
    fi
done
if (( GATES == 0 )); then
    # Branch isn't a hotfix-prefix; nothing to enforce.
    exit 0
fi

# From here on, the charter is REQUIRED.
echo "hotfix-charter: branch '$BRANCH' matches prefix '$MATCHED_PREFIX'; charter required." >&2

# Bypass check -- intentional after the branch-prefix detection so the WARNING
# fires only when the gate would otherwise apply.
if [[ "${ALLOW_NO_CHARTER:-0}" == "1" ]]; then
    echo "WARNING: ALLOW_NO_CHARTER=1 set; bypassing the charter gate." >&2
    echo "         Bypass leaves no audit trail in git history -- call it out in the MR description." >&2
    exit 0
fi

# Charter file must exist at the repo root.
if [[ ! -f "$REPO_ROOT/$CHARTER_FILE" ]]; then
    cat >&2 <<EOF
ERROR: hotfix-charter-check.sh -- $CHARTER_FILE missing at repo root.

On a hotfix-prefix branch (matched: $MATCHED_PREFIX), the charter is mandatory.
Create $CHARTER_FILE with these four sections:

  ## Symptom (one sentence)
  ## Diff budget (LOC ceiling)
  ## cr-battery pre-commit verdict
  ## Refactoring disposition

See skills/engineering/hotfix-charter/skill.md for the full template + rationale.

Bypass (use sparingly, with PM sign-off):
  ALLOW_NO_CHARTER=1 git commit ...
EOF
    exit 1
fi

CHARTER_PATH="$REPO_ROOT/$CHARTER_FILE"
MISSING_SECTIONS=()
BAD_VERDICT=""

# Check each required section. Match the markdown heading exactly (^## <name>),
# not a substring -- prevents a comment like "see ## Symptom note" from being
# mistaken for the section itself.
check_section() {
    local name="$1"
    # Anchor the trailing edge with `( |$)` so `## Symptomatic of X` does NOT
    # satisfy the Symptom requirement. Permitted forms:
    #   `## Symptom`                  (bare)
    #   `## Symptom (one sentence)`   (parenthesized clarifier; common)
    #   `## Symptom:`                 (colon; common)
    # Trailing-edge anchor accepts: space, tab, EOL, CR (Windows CRLF), or colon
    if ! grep -qE "^## ${name}([ 	]|\$|"$'\r'"|:)" "$CHARTER_PATH"; then
        MISSING_SECTIONS+=("$name")
    fi
}

# Resolve the disposition-gate toggle ONCE, fail-closed. Default ON; only an
# explicit off value (0/false/no/off, any case, surrounding space tolerated)
# disables it. A truthy-looking value like "true" or "1 " must NOT silently
# switch a safety gate off -- opposite polarity to ALLOW_NO_CHARTER, which opts
# IN to a bypass so a typo there leaves the gate enforcing.
REQUIRE_DISP=1
case "$(printf '%s' "${REQUIRE_DISPOSITION:-1}" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')" in
    0|false|no|off) REQUIRE_DISP=0 ;;
esac
if (( REQUIRE_DISP == 0 )); then
    echo "WARNING: REQUIRE_DISPOSITION is off; the refactoring-disposition check is" >&2
    echo "         skipped. The other three charter sections still enforce. Note it in the MR." >&2
fi

check_section "Symptom"
check_section "Diff budget"
check_section "cr-battery pre-commit verdict"
if (( REQUIRE_DISP == 1 )); then
    # A missing section here routes through the existing MISSING_SECTIONS
    # exit-1 path below -- no new exit code.
    check_section "Refactoring disposition"
fi

# The cr-battery section must contain a literal PASS or PASS_WITH_NITS line
# (case-sensitive). Extract the section body (from its heading to next heading
# or EOF) and grep for the strict verdict tokens.
if [[ ! " ${MISSING_SECTIONS[*]} " == *"cr-battery pre-commit verdict"* ]]; then
    # awk extracts content between this heading and the next ##/EOF
    # Terminate capture on any heading depth (`## `, `### `, `#### `...) so a
    # `### Detail` subhead inside the cr-battery section closes off the body
    # and prevents PASS placed under a subhead from satisfying the gate.
    SECTION_BODY=$(awk '
        /^## cr-battery pre-commit verdict/ { capture=1; next }
        /^#+ / { capture=0 }
        capture { print }
    ' "$CHARTER_PATH")
    if ! grep -qE '\b(PASS|PASS_WITH_NITS)\b' <<<"$SECTION_BODY"; then
        BAD_VERDICT=1
    fi
fi

if (( ${#MISSING_SECTIONS[@]} > 0 )); then
    echo "ERROR: $CHARTER_FILE is missing required section(s):" >&2
    for s in "${MISSING_SECTIONS[@]}"; do
        echo "  - ## $s" >&2
    done
    echo "Refusing commit. See skills/engineering/hotfix-charter/skill.md for the template." >&2
    exit 1
fi

if [[ -n "$BAD_VERDICT" ]]; then
    cat >&2 <<EOF
ERROR: $CHARTER_FILE 'cr-battery pre-commit verdict' section does not contain
the literal token PASS or PASS_WITH_NITS.

Re-run cr-battery on the STAGED diff (\`git diff --cached\`) at the project's
quality floor and write the actual verdict into that section. Examples of
acceptable contents:

  PASS at 9.5/10 (3 reviewers, 0 Critical, 0 Important)
  PASS_WITH_NITS at 8.5/10 (1 Minor; documented in MR)

Anything else (REJECT, PASS_WITH_FIXES, "passing", "ok", numbers alone, blank)
refuses the commit.
EOF
    exit 1
fi

# Refactoring disposition: token + citation content checks. Runs AFTER the
# BAD_VERDICT block so a missing/bad section is reported first. A disposition
# problem is exit 1 -- same class as a bad verdict; the 0/1/2 contract is
# unchanged (exit 2 is reserved for a malformed DISPOSITION_NONE_MAX_LINES, the
# same "usage/env error" class as detached HEAD). REQUIRE_DISP is resolved once
# near the section checks above.
if (( REQUIRE_DISP == 1 )); then
    # Validate the NONE ceiling env var up front (env error, exit 2) so a
    # malformed value is caught regardless of which disposition the charter
    # uses -- not only on the NONE path.
    # Bounded 1-9 digits: enforces non-negative integer AND stays well inside
    # the shell's arithmetic range, so a giant value fails CLOSED (exit 2)
    # rather than tripping a "[: integer expected" error that reads as false.
    disp_max=${DISPOSITION_NONE_MAX_LINES:-30}
    if ! [[ "$disp_max" =~ ^[0-9]{1,9}$ ]]; then
        echo "ERROR: DISPOSITION_NONE_MAX_LINES must be an integer 0-999999999" >&2
        echo "       (got: '$disp_max')." >&2
        exit 2
    fi

    # Capture the disposition section body. Fold heading-line content into the
    # body ONLY when the heading uses the colon form ("## Refactoring
    # disposition: NONE") -- a parenthesized clarifier like "(REFACTOR_NOW /
    # PARK / NONE)" is NOT body text. Capture ends at the next `## ` heading.
    DISP_BODY=$(awk '
        /^## Refactoring disposition/ {
            line = $0
            if (sub(/^## Refactoring disposition[ \t]*:[ \t]*/, "", line) && length(line) > 0) print line
            capture = 1
            next
        }
        /^## / { capture = 0 }
        # NOTE: this terminates on `## ` only, unlike the cr-battery extractor
        # (any `#+ `). Safe here -- the token is read from the first non-blank
        # line and disposition is the last section.
        capture { print }
    ' "$CHARTER_PATH")
    # Strip CR so a CRLF charter parses (check_section already tolerates CRLF).
    DISP_BODY=${DISP_BODY//$'\r'/}

    # The decision token is on the FIRST non-blank line of the body ("one token
    # plus one reason"). Strip backticked spans before matching so a citation
    # like `LogLevel.NONE` is not counted as a second token, and look only at
    # line 1 so bare uppercase words in a multi-line reason cannot inflate the
    # count. Whole-word, case-sensitive (LC_ALL=C).
    # shellcheck disable=SC2016  # single-quoted backticks are literal by design
    DISP_DECISION=$(awk 'NF { print; exit }' <<<"$DISP_BODY" | sed 's/`[^`]*`//g')
    n_refactor=0; n_park=0; n_none=0
    if grep -qwE 'REFACTOR_NOW' <<<"$DISP_DECISION"; then n_refactor=1; fi
    if grep -qwE 'PARK'         <<<"$DISP_DECISION"; then n_park=1;     fi
    if grep -qwE 'NONE'         <<<"$DISP_DECISION"; then n_none=1;     fi
    n_total=$(( n_refactor + n_park + n_none ))
    if (( n_total != 1 )); then
        echo "ERROR: $CHARTER_FILE '## Refactoring disposition' must open with" >&2
        echo "       EXACTLY ONE of REFACTOR_NOW / PARK / NONE (found $n_total on" >&2
        echo "       the first line). Put the single token first; keep bare" >&2
        echo "       uppercase REFACTOR_NOW/PARK/NONE out of the reason." >&2
        exit 1
    fi

    if (( n_none == 1 )); then
        # NONE asserts "no refactoring". Bound it by TOTAL changed lines (added +
        # deleted) so a deletion- or move-heavy hotfix -- which is refactoring --
        # cannot hide under NONE. --no-renames so a moved file counts as its full
        # delete + add, not 0. Binary blobs (numstat "-  -") are not line-counted
        # and do not contribute. Charter excluded. disp_max validated above.
        n_changed=$(git diff --cached --numstat --no-renames -- . ":(exclude)$CHARTER_FILE" \
            | awk '$1 ~ /^[0-9]+$/ { a += $1 } $2 ~ /^[0-9]+$/ { d += $2 } END { print a + d + 0 }') || {
            echo "ERROR: hotfix-charter-check.sh -- 'git diff --cached --numstat' failed. Fails CLOSED." >&2
            exit 2
        }
        if [ "${n_changed:-0}" -gt "$disp_max" ]; then
            echo "ERROR: staged diff changes $n_changed lines (added + deleted); a" >&2
            echo "       NONE disposition is capped at $disp_max. Use PARK /" >&2
            echo "       REFACTOR_NOW and cite a backticked \`symbol\` from the diff," >&2
            echo "       or set REQUIRE_DISPOSITION=0 for this commit and note it in the MR." >&2
            exit 1
        fi
    else
        # PARK or REFACTOR_NOW: require a backticked citation, from anywhere in
        # the body, that (a) contains an identifier run matching
        # [A-Za-z_][A-Za-z0-9_]{2,} (>= 3 chars, no leading digit), so `.` or a
        # lone space cannot match every line -- and (b) appears in the staged
        # added content. grep -F: substring, so `obj.method(` matches literally.
        # shellcheck disable=SC2016
        DISP_CITES=$(grep -oE '`[^`]+`' <<<"$DISP_BODY" | tr -d '`' \
            | grep -E '[A-Za-z_][A-Za-z0-9_]{2,}' || true)
        if [[ -z "$DISP_CITES" ]]; then
            echo "ERROR: a PARK / REFACTOR_NOW disposition must cite a real symbol" >&2
            echo "       in backticks (3+ identifier chars), e.g. \`buildRetryPayload\`." >&2
            exit 1
        fi
        # Added content from the staged diff, charter excluded, '+' marker
        # stripped. Key off hunk state (@@ ... @@), not the '--- '/'+++ ' file
        # header: under --unified=0 a deleted line whose text starts with '-- '
        # renders as '--- ' and a following added '++ ' line as '+++ ', so a
        # header-pattern filter would drop real content. Only lines inside a
        # hunk body are read.
        ADDED_CONTENT=$(git diff --cached --unified=0 --no-renames -- . ":(exclude)$CHARTER_FILE" | awk '
            /^diff --git / { in_hunk = 0; next }
            /^@@ /         { in_hunk = 1; next }
            in_hunk && /^\+/ { s = $0; sub(/^\+/, "", s); print s }
        ') || {
            echo "ERROR: hotfix-charter-check.sh -- 'git diff --cached' failed. Fails CLOSED." >&2
            exit 2
        }
        if [[ -n "$ADDED_CONTENT" ]]; then
            disp_matched=0
            while IFS= read -r cite; do
                if [[ -z "$cite" ]]; then continue; fi
                if grep -Fq -- "$cite" <<<"$ADDED_CONTENT"; then
                    disp_matched=1
                    break
                fi
            done <<<"$DISP_CITES"
            if (( disp_matched == 0 )); then
                echo "ERROR: no cited symbol from '## Refactoring disposition'" >&2
                echo "       appears in the staged diff. Cite something this" >&2
                echo "       change actually touched." >&2
                exit 1
            fi
        fi
        # No added content (e.g. a deletion-only hotfix, or git commit
        # --allow-empty): nothing to match against; the citation-shape check
        # above is the only gate.
    fi
fi

echo "hotfix-charter: $CHARTER_FILE OK; cr-battery verdict PASS." >&2
exit 0

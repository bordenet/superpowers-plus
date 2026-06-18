#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# hotfix-charter-check.sh
#
# Pre-commit hook that enforces a HOTFIX-CHARTER.md on `hotfix/*` and
# `fix/<TICKET-ID>-*` branches. The charter must contain three sections:
#
#   ## Symptom (one sentence)
#   ## Diff budget (LOC ceiling)
#   ## cr-battery pre-commit verdict
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
#   1  Charter missing OR missing a section OR cr-battery section invalid
#   2  Usage / git error (detached HEAD, no repo, etc.) -- fails CLOSED
#
# Bypass: ALLOW_NO_CHARTER=1 git commit ...   (prints WARNING but proceeds)
#
# `git commit --no-verify` skips this hook entirely (git design limit; the hook
# cannot defend against it). Document in the team review checklist.
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
Create $CHARTER_FILE with these three sections:

  ## Symptom (one sentence)
  ## Diff budget (LOC ceiling)
  ## cr-battery pre-commit verdict

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

check_section "Symptom"
check_section "Diff budget"
check_section "cr-battery pre-commit verdict"

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

echo "hotfix-charter: $CHARTER_FILE OK; cr-battery verdict PASS." >&2
exit 0

#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Script: fence-scan.sh
# PURPOSE: Extract ```bash / ```sh fenced code blocks from Markdown files and
#          mechanically verify they are still syntactically valid shell
#          (`bash -n`), with an advisory-only ShellCheck pass layered on top.
#          This is the extraction+check ENGINE, usable standalone
#          (`tools/fence-scan.sh <changed .md files>`) or wired into a
#          pre-commit/pre-push hook by the caller.
#
# WHY THIS EXISTS:
#   A prose review (human or LLM) judges Markdown as prose, with no
#   evidence-verifier for embedded commands -- a rewrite can keep a fenced
#   command looking plausible while silently breaking it, or introduce an
#   outright syntax error, and nothing catches it mechanically. This script
#   is the mechanical, judgment-free backstop: `bash -n` on the exact fenced
#   content, nothing more. It exists because this exact failure mode was
#   found and fixed in a real skill file: an illustrative `<file>` placeholder
#   inside a fenced ```bash block tokenized as `< file` followed by a
#   dangling `>` redirect -- a genuine, reproducible `bash -n` failure that
#   sat undetected in a reviewed, shipped doc because nothing had ever run
#   `bash -n` against its embedded examples.
#
# SCOPE (deliberately narrow):
#   - Only fences opened with EXACTLY ```bash or ```sh (a bare ``` fence, or
#     any other language tag -- ```python, ```json, ```text, etc. -- is
#     ignored entirely, never extracted).
#   - Both tags are checked with `bash -n` uniformly -- no stricter POSIX
#     `sh -n` pass for ```sh-tagged content specifically.
#   - ShellCheck (when present on PATH) additionally runs per-block, using the
#     fence's own tag to pick `--shell=bash` or `--shell=sh` for a more
#     accurate dialect-specific advisory signal -- ADVISORY ONLY, never
#     affects the exit code. See "SEVERITY DECISION" below.
#
# KNOWN, EXPLICITLY STATED LIMITATION (do not oversell this):
#   `bash -n` catches syntactic breakage only. A rewrite that keeps a fenced
#   command syntactically valid but semantically wrong for its surrounding
#   (rewritten) prose passes this check silently -- an accepted limitation,
#   not something this script solves.
#
#   Separately: this script runs whatever `bash` resolves to on PATH at
#   invocation time -- it does not pin a version. A fence intentionally
#   showing bash 4+-only syntax (e.g. `${var,,}`) would parse fine against a
#   modern bash but could be misreported as broken on a system whose PATH
#   resolves an old bash (e.g. macOS's stock /bin/bash 3.2). Document this
#   assumption for your own repo rather than silently inheriting it.
#
# SEVERITY DECISION (bash -n blocks; ShellCheck is advisory-only):
#   Extracted fragments are illustrative examples pulled out of surrounding
#   prose, not complete, shipped scripts -- they routinely lack a shebang
#   line (ShellCheck's SC2148 would fire on nearly every single fragment
#   purely because of *how this tool extracts them*, not because of any real
#   defect in the source doc) and often show single-purpose one-liners that
#   are fine in their prose context but would trip style rules meant for
#   whole scripts. Applying a hard-zero-warnings bar (appropriate for real,
#   complete, shipped scripts) to a doc fragment is alert fatigue, not
#   signal -- `bash -n` is the one check that stays unambiguous regardless of
#   context: if it doesn't parse, it is broken, full stop -- that is the one
#   that blocks. SC2148 (missing shebang) is explicitly excluded from the
#   advisory ShellCheck pass for the same reason: it is a guaranteed false
#   signal produced by our own extraction method on every single fragment,
#   not a property of the source document.
#
#   DISCLOSED NARROWING: the advisory ShellCheck pass runs with
#   `--severity=warning`, which silently drops style-level findings (e.g.
#   SC2006, legacy backtick command substitution) that a plain `shellcheck`
#   invocation would show. This is deliberate -- doc fragments routinely use
#   older/simpler idioms that are fine for a one-liner illustration -- but it
#   means "no ShellCheck advisory shown" is narrower than "ShellCheck found
#   nothing," and is stated here so that narrowing isn't a silent surprise.
#
# USAGE:
#   tools/fence-scan.sh FILE [FILE...]              # scan files as they exist
#                                                    # in the working tree
#   tools/fence-scan.sh --sha SHA FILE [FILE...]    # scan files as they exist
#                                                    # at a git object SHA --
#                                                    # correct even when the
#                                                    # target ref isn't
#                                                    # checked out (gate mode)
#   tools/fence-scan.sh --help
#
# EXIT CODES:
#   0  no ```bash/```sh fences found, OR all found fences passed `bash -n`
#      (regardless of ShellCheck advisories)
#   1  at least one fence failed `bash -n`, OR at least one fence was opened
#      but never closed (unterminated -- a structural markdown defect)
#   2  usage error (no files given, or --sha given but does not resolve to a
#      commit)
#
# A file that does not exist (worktree mode) or does not exist AT the given
# SHA (gate mode -- e.g. deleted in this push) is SKIPPED with a note, not
# treated as an error: a deletion has no content to scan.
# -----------------------------------------------------------------------------
set -euo pipefail

usage() {
    sed -n '2,/^# ---/p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
    exit "${1:-2}"
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    usage 0
fi

RED='\033[0;31m'
YELLOW='\033[0;33m'
GREEN='\033[0;32m'
NC='\033[0m'

SHA=""
case "${1:-}" in
    --sha)
        [[ $# -ge 2 ]] || { echo "ERROR: --sha requires a value" >&2; usage 2; }
        SHA="$2"; shift 2
        ;;
    --sha=*)
        SHA="${1#--sha=}"; shift
        ;;
esac

if [[ -n "$SHA" ]]; then
    if ! git rev-parse --verify --quiet "${SHA}^{commit}" >/dev/null; then
        echo "ERROR: --sha '$SHA' does not resolve to a commit" >&2
        exit 2
    fi
fi

if [[ $# -eq 0 ]]; then
    echo "ERROR: no files given" >&2
    usage 2
fi

# Guard against a mistyped/unrecognized flag (e.g. "--shaXYZ" without the
# separating "=", or any other "--"-prefixed typo) silently being treated as
# a file path -- worktree mode would then just report it "skipped, not
# present" instead of raising a loud usage error.
for _arg in "$@"; do
    if [[ "$_arg" == --* ]]; then
        echo "ERROR: unrecognized flag '$_arg' (only --sha/--sha=VALUE is supported, and only as the first argument)" >&2
        usage 2
    fi
done

SHELLCHECK_BIN=""
if command -v shellcheck >/dev/null 2>&1; then
    SHELLCHECK_BIN="shellcheck"
fi

TOTAL_FILES=0
TOTAL_FENCES=0
BLOCKING_FAILURES=0
ADVISORY_COUNT=0

# get_content PATH: print the file's content (working tree, or at $SHA if set).
# Returns non-zero when the content genuinely does not exist there (missing
# file / deleted-at-that-commit) -- callers must treat that as "skip", not an
# error.
get_content() {
    local path="$1"
    if [[ -n "$SHA" ]]; then
        git show "${SHA}:${path}" 2>/dev/null
        return $?
    fi
    [[ -f "$path" ]] || return 1
    cat "$path"
    return 0
}

# check_block PATH START_LINE LANG LINE... : write the fence's body to a temp
# file, run `bash -n` (blocking) and, if available, ShellCheck (advisory-only)
# against it, and report findings. Always returns 0 -- failures are recorded
# via the BLOCKING_FAILURES/ADVISORY_COUNT globals, not this function's own
# exit status, so it is safe to call as a bare statement under `set -e`.
check_block() {
    local path="$1" start_line="$2" lang="$3"; shift 3
    TOTAL_FENCES=$((TOTAL_FENCES + 1))

    # NOTE: mktemp with a suffix AFTER the trailing X's (e.g. "...XXXXXX.sh")
    # is a GNU-only convenience -- BSD/macOS mktemp does not recognize
    # trailing characters after the X run as a suffix and instead creates the
    # literal, unrandomized filename verbatim. No suffix is needed here: both
    # `bash -n` and ShellCheck are told the dialect explicitly (--shell=$lang
    # below), so neither depends on a file extension.
    local tmp
    tmp="$(mktemp "${TMPDIR:-/tmp}/fence-scan.XXXXXX")"
    printf '%s\n' "$@" > "$tmp"

    # Both bash -n's and ShellCheck's own diagnostics cite the temp file by
    # its ephemeral /tmp path -- ShellCheck's multi-line "In <path> line N:"
    # format puts that path mid-line, not just at line-start (unlike bash
    # -n's "<path>: line N: ..."), so the substitution below is intentionally
    # a global, non-anchored replace that handles both shapes: swap every
    # occurrence of the throwaway tmp path for the real markdown file (plus
    # the fence's start line in the ORIGINAL document, so the reader has a
    # location to act on instead of a dangling /tmp path). Line numbers WITHIN
    # the diagnostic text itself remain relative to the extracted fence body,
    # not the original file -- "(fence @ line N)" is the anchor for that.
    local loc_label="${path} (fence @ line ${start_line})"

    local bn_out bn_rc=0
    bn_out=$(bash -n "$tmp" 2>&1) || bn_rc=$?
    if [[ "$bn_rc" -ne 0 ]]; then
        BLOCKING_FAILURES=$((BLOCKING_FAILURES + 1))
        echo -e "  ${RED}❌ ${path}:${start_line} (\`\`\`${lang}) bash -n FAILED${NC}"
        echo "$bn_out" | sed "s|${tmp}|${loc_label}|g" | sed 's/^/      /'
    fi

    if [[ -n "$SHELLCHECK_BIN" ]]; then
        local sc_out sc_rc=0
        sc_out=$("$SHELLCHECK_BIN" --shell="$lang" --severity=warning --exclude=SC2148 "$tmp" 2>&1) || sc_rc=$?
        if [[ "$sc_rc" -ne 0 && -n "$sc_out" ]]; then
            ADVISORY_COUNT=$((ADVISORY_COUNT + 1))
            echo -e "  ${YELLOW}⚠ ${path}:${start_line} (\`\`\`${lang}) shellcheck advisory (non-blocking)${NC}"
            echo "$sc_out" | sed "s|${tmp}|${loc_label}|g" | sed 's/^/      /'
        fi
    fi

    rm -f "$tmp"
    return 0
}

# scan_file PATH: extract every ```bash/```sh fence from PATH's content (see
# get_content) and hand each one to check_block. Always returns 0 -- see
# check_block's own comment on why (safe under `set -e` as a bare statement).
scan_file() {
    local path="$1"
    local content rc=0
    content=$(get_content "$path") || rc=$?
    if [[ "$rc" -ne 0 ]]; then
        local where="working tree"
        [[ -n "$SHA" ]] && where="${SHA:0:8}"
        echo "  [fence-scan] (skipped — ${path} not present in ${where})"
        return 0
    fi
    TOTAL_FILES=$((TOTAL_FILES + 1))

    local in_fence=0 fence_lang="" fence_start=0
    local -a block=()
    local line_no=0

    while IFS= read -r line || [[ -n "$line" ]]; do
        line_no=$((line_no + 1))
        if [[ "$in_fence" -eq 0 ]]; then
            if [[ "$line" =~ ^[[:space:]]*\`\`\`(bash|sh)[[:space:]]*$ ]]; then
                in_fence=1
                fence_lang="${BASH_REMATCH[1]}"
                fence_start=$line_no
                block=()
            fi
        else
            if [[ "$line" =~ ^[[:space:]]*\`\`\`[[:space:]]*$ ]]; then
                in_fence=0
                check_block "$path" "$fence_start" "$fence_lang" "${block[@]:-}"
            else
                block+=("$line")
            fi
        fi
    done <<< "$content"

    if [[ "$in_fence" -eq 1 ]]; then
        BLOCKING_FAILURES=$((BLOCKING_FAILURES + 1))
        TOTAL_FENCES=$((TOTAL_FENCES + 1))
        echo -e "  ${RED}❌ ${path}:${fence_start} (\`\`\`${fence_lang} opened, never closed)${NC}"
        echo "      Unterminated fence — cannot extract; treat as a markdown structural defect." >&2
    fi
    return 0
}

for f in "$@"; do
    scan_file "$f"
done

echo ""
echo "  [fence-scan] files scanned: ${TOTAL_FILES}, bash/sh fences found: ${TOTAL_FENCES}"
if [[ "$TOTAL_FENCES" -gt 0 ]]; then
    echo "  [fence-scan] note: bash -n / shellcheck catch syntactic breakage only -- a fence"
    echo "               kept syntactically valid but made semantically wrong by a rewritten"
    echo "               surrounding paragraph will NOT be caught here (known, accepted limit)."
fi
if [[ "$ADVISORY_COUNT" -gt 0 ]]; then
    echo -e "  ${YELLOW}[fence-scan] ${ADVISORY_COUNT} shellcheck advisory finding(s) (non-blocking)${NC}"
fi
if [[ "$BLOCKING_FAILURES" -gt 0 ]]; then
    echo -e "  ${RED}[fence-scan] ${BLOCKING_FAILURES} fence(s) FAILED bash -n${NC}"
    exit 1
fi
echo -e "  ${GREEN}[fence-scan] ✓ all bash/sh fences pass bash -n${NC}"
exit 0

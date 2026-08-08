#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Script: wiki-content-check.sh
# PURPOSE: Static content linter for Outline wiki markdown. Called by
#          wiki-write.sh before every create/update API call. Catches six
#          failure classes that are invisible to scope-check but produce
#          broken or misleading published pages:
#
#   1. H1 title    -- Outline auto-renders the doc title; a # heading in the
#                     body produces a visible duplicate. (Incident: 2026-07-11)
#   2. AI slop     -- fabricated generalizations and filler openers degrade
#                     trust in the wiki. (Incident: 2026-07-11)
#   3. TOC delim   -- Outline toggle-block "+" fence structure: duplicate
#                     TOC toggles, and fence open/close/nesting errors,
#                     delegated to toc-delimiter-check.sh (see that script's
#                     header for the full, source-verified rule -- there is
#                     no fixed "correct" character count). (Incident:
#                     2026-07-11; rule corrected 2026-07-29 after the
#                     original "4-6 is broken" heuristic was found to
#                     contradict Outline's actual parser and serializer)
#   4. Ref strip   -- a section that drops an external URL present in the
#                     existing doc is flagged; prevents silently removing
#                     Core Board or SharePoint links during updates.
#                     (Incident: 2026-07-11)
#   5. Table blank -- a blank line within a markdown table block breaks the
#                     renderer; every row after the blank renders as raw text.
#                     (Incident: 2026-07-22)
#   6. Table cols  -- all non-separator rows in a table must have the same
#                     pipe count as the header; a row with a wrong count
#                     indicates concatenated rows or a structural defect.
#                     (Incident: 2026-07-22)
#
# USAGE:
#   wiki-content-check.sh --content FILE [--existing FILE] [--skip-slop]
#   wiki-content-check.sh --help
#
# OPTIONS:
#   --content FILE    Markdown file to validate (required)
#   --existing FILE   Current doc body for ref-completeness diff (optional;
#                     provide when updating an existing document)
#   --skip-slop       Disable slop check (use when content is human-authored)
#   -v, --verbose     Print each check result even on pass
#   -h, --help        Show this help
#
# EXIT:
#   0  all checks passed
#   1  one or more content violations found (details on stderr)
#   2  usage / environment error
#
# REQUIRES: bash 4+; python3 on PATH (transitive, via toc-delimiter-check.sh
#           and slop-check.sh delegation -- both print their own explicit
#           "requires python3" error to stderr, forwarded here, if missing)
# -----------------------------------------------------------------------------
set -euo pipefail

if [ -z "${BASH_VERSION:-}" ]; then
    echo "ERROR: requires bash. Run with: bash $0" >&2; exit 2
fi
if (( ${BASH_VERSINFO[0]:-0} < 4 )); then
    echo "ERROR: requires bash 4+; on macOS run: brew install bash" >&2; exit 2
fi

CONTENT_FILE=""
EXISTING_FILE=""
SKIP_SLOP=0
VERBOSE=0
VIOLATIONS=0

log_pass() { [[ "$VERBOSE" -eq 1 ]] && printf '[wiki-content-check] PASS  %s\n' "$*" >&2 || true; }
log_fail() { printf '[wiki-content-check] FAIL  %s\n' "$*" >&2; VIOLATIONS=$(( VIOLATIONS + 1 )); }
log_info() { [[ "$VERBOSE" -eq 1 ]] && printf '[wiki-content-check] INFO  %s\n' "$*" >&2 || true; }

show_help() {
    grep '^#' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//' | sed -n '/^Script:/,/^---/p'
}

# -- Arg parsing ---------------------------------------------------------------
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)    show_help; exit 0 ;;
        --content)    CONTENT_FILE="${2:?--content requires a file}"; shift 2 ;;
        --existing)   EXISTING_FILE="${2:?--existing requires a file}"; shift 2 ;;
        --skip-slop)  SKIP_SLOP=1; shift ;;
        -v|--verbose) VERBOSE=1; shift ;;
        *) printf 'ERROR: unknown option: %s\n' "$1" >&2; exit 2 ;;
    esac
done

[[ -n "$CONTENT_FILE" ]] || { echo "ERROR: --content FILE is required" >&2; exit 2; }
[[ -r "$CONTENT_FILE" ]] || { echo "ERROR: content file not readable: $CONTENT_FILE" >&2; exit 2; }

# -- Check 1: H1 title ---------------------------------------------------------
# Outline renders the document title from the title field automatically.
# Any line beginning with "# " (one hash, one space) in the body produces
# a visible duplicate heading for the reader.
# `grep ... || true` used to map "no match" (benign, exit 1) and a genuine
# grep failure (exit >=2: bad regex, I/O error) to the identical empty
# result -- a real scan failure would silently pass as "no H1 found." The
# command itself, not a negated `!` form, must be the if-condition: `$?`
# after `if ! cmd; then` is the logical NOT of the real exit code, not the
# real code (see tools/slop-check.sh's scan_pattern for the same fix, found
# via code-review-battery).
if h1_lines=$(grep -n '^# ' "$CONTENT_FILE"); then
    h1_rc=0
else
    h1_rc=$?
fi
if [[ "$h1_rc" -ge 2 ]]; then
    printf '[wiki-content-check] FAIL  H1_TITLE: grep failed (rc=%d) -- ABORT, do not infer PASS\n' "$h1_rc" >&2
    exit 2
fi
if [[ -n "$h1_lines" ]]; then
    log_fail "H1_TITLE: body must not contain '# Heading' lines (Outline renders title automatically)"
    while IFS= read -r line; do printf '  %s\n' "$line" >&2; done <<< "$h1_lines"
else
    log_pass "H1_TITLE: no H1 lines"
fi

# -- Check 2: AI slop ----------------------------------------------------------
# Delegated to slop-check.sh — the centralized pattern gate that covers
# em/en-dash, boosters, buzzwords, and filler openers. The pattern list lives
# there; do not add patterns here.
if [[ "$SKIP_SLOP" -eq 0 ]]; then
    SLOP_CHECK="$(dirname "${BASH_SOURCE[0]}")/slop-check.sh"
    if [[ ! -x "$SLOP_CHECK" ]]; then
        # Fallback: search PATH for a system-installed copy
        SLOP_CHECK="$(command -v slop-check.sh 2>/dev/null || true)"
    fi
    if [[ -x "$SLOP_CHECK" ]]; then
        # The assignment must be the condition of the if-statement itself (not a
        # separate `var=$(...); rc=$?` pair) -- under `set -e`, a non-zero exit
        # from a bare assignment statement aborts the whole script immediately,
        # before any `$?` capture on the next line ever runs. Commands used as
        # an if/while/until condition are exempt from that abort behavior.
        if slop_output=$("$SLOP_CHECK" --content "$CONTENT_FILE" --mode full 2>&1); then
            log_pass "AI_SLOP: slop-check.sh found no blocking violations"
        else
            slop_rc=$?
            if [[ "$slop_rc" -eq 1 ]]; then
                log_fail "AI_SLOP: slop-check.sh found blocking violations -- rewrite before publishing"
                printf '%s\n' "$slop_output" >&2
            else
                # Environment/usage error (exit 2, e.g. missing python3 -- now
                # reachable in ordinary operation, not just a caller-usage
                # bug), not a content violation -- exit 2 immediately
                # rather than folding into the generic VIOLATIONS-count exit-1 at
                # the end of this script. Mirrors Check 3's toc-check disambiguation
                # below; without it, an environment failure here would surface
                # identically to "your wiki content is broken."
                printf '[wiki-content-check] FAIL  AI_SLOP: slop-check.sh errored (exit %s) -- ABORT, do not infer PASS\n' "$slop_rc" >&2
                printf '%s\n' "$slop_output" >&2
                exit 2
            fi
        fi
    else
        printf '[wiki-content-check] WARN  AI_SLOP: slop-check.sh not found -- slop check skipped (install may be outdated)\n' >&2
    fi
else
    printf '[wiki-content-check] WARN  AI_SLOP: slop check skipped (--skip-slop) -- ensure content is human-reviewed\n' >&2
fi

# -- Check 3: TOC delimiter / toggle fence structure ---------------------------
# Delegated to toc-delimiter-check.sh -- see that script's header for the
# full rule (there is no fixed "correct" delimiter length; validates
# structure, not character count) and its own test coverage.
TOC_CHECK="$(dirname "${BASH_SOURCE[0]}")/toc-delimiter-check.sh"
if [[ -x "$TOC_CHECK" ]]; then
    # The assignment must be the condition of the if-statement itself (not a
    # separate `var=$(...); rc=$?` pair) -- under `set -e`, a non-zero exit
    # from a bare assignment statement aborts the whole script immediately,
    # before any `$?` capture on the next line ever runs. Commands used as
    # an if/while/until condition are exempt from that abort behavior.
    if toc_output=$(bash "$TOC_CHECK" --content "$CONTENT_FILE" 2>&1); then
        log_pass "TOC_DELIM: no toggle fence defects"
    else
        toc_rc=$?
        if [[ "$toc_rc" -eq 1 ]]; then
            log_fail "TOC_DELIM: toggle fence defect(s) found"
            printf '%s\n' "$toc_output" >&2
        else
            # Environment/usage error (exit 2), not a content violation --
            # exit 2 immediately rather than folding into the generic
            # VIOLATIONS-count exit-1 at the end of this script. Otherwise
            # this distinction (which the code above goes to the trouble of
            # detecting) never reaches the caller: an environment failure
            # would surface identically to "your wiki content is broken"
            # (found by code-review-battery 2026-07-29).
            printf '[wiki-content-check] FAIL  TOC_DELIM: toc-delimiter-check.sh errored (exit %s) -- ABORT, do not infer PASS\n' "$toc_rc" >&2
            printf '%s\n' "$toc_output" >&2
            exit 2
        fi
    fi
else
    printf '[wiki-content-check] WARN  TOC_DELIM: toc-delimiter-check.sh not found -- TOC delimiter check skipped (install may be outdated)\n' >&2
fi

# -- Check 4: Ref completeness -------------------------------------------------
# When an existing document body is provided, extract all absolute http/https
# URLs from it and verify each one still appears in the new content.
# A missing URL means a link was silently dropped during the update --
# most commonly a Core Board or SharePoint reference.
# Relative /doc/ links are excluded; they are checked by the skill preflight.
if [[ -n "$EXISTING_FILE" && -r "$EXISTING_FILE" ]]; then
    # Extract URLs, then strip trailing backticks and sentence-ending
    # punctuation captured by the greedy regex when a URL appears inside a
    # markdown code span.  Example: `https://x.com/path`. is extracted as
    # 'https://x.com/path`.' -- the backtick and period are not part of the
    # URL.  Stripping normalises the left-side key so a clean URL present in
    # the new content is not wrongly reported as DROPPED.  grep -qF (right
    # side) is a substring match, so the normalised form still locates the
    # full URL in the new document.  grep already excludes > via its character
    # class, so > in the strip set is redundant but harmless; ) never reaches
    # the strip set at all, for the same reason.  ] is excluded
    # from the strip set to preserve bracket-notation API URLs (e.g. /items[0]).
    # Uses python3 (already required by toc-delimiter-check.sh) to avoid
    # sed backtick quoting issues on macOS/BSD.  If python3 is missing, log a
    # WARN and fall back to the raw extracted form so the gate degrades loudly
    # rather than silently bypassing REF_COMPLETENESS.
    # `|| true` used to map "no URLs found" (benign: grep exit 1, the only
    # non-zero exit under pipefail when python3/sort succeed on empty input)
    # and a genuine pipeline failure (grep/python3/sort exit >=2) to the
    # identical empty result -- a real extraction failure would silently
    # report "no existing URLs to check," skipping REF_COMPLETENESS entirely
    # rather than failing loud. See H1_TITLE above for the same fix pattern.
    if command -v python3 &>/dev/null; then
        if existing_urls=$(grep -oE 'https?://[^)> "]+' "$EXISTING_FILE" \
            | python3 -c 'import sys; [print(u.rstrip("\x60.,;:\x27>(")) for u in sys.stdin.read().splitlines() if u]' \
            | sort -u); then
            existing_urls_rc=0
        else
            existing_urls_rc=$?
        fi
    else
        printf '[wiki-content-check] WARN  REF_COMPLETENESS: python3 not found -- URL trailing-char normalisation skipped; check may flag false positives\n' >&2
        if existing_urls=$(grep -oE 'https?://[^)> "]+' "$EXISTING_FILE" | sort -u); then
            existing_urls_rc=0
        else
            existing_urls_rc=$?
        fi
    fi
    if [[ "$existing_urls_rc" -ge 2 ]]; then
        printf '[wiki-content-check] FAIL  REF_COMPLETENESS: URL extraction failed (rc=%d) -- ABORT, do not infer PASS\n' "$existing_urls_rc" >&2
        exit 2
    fi
    missing_urls=""
    while IFS= read -r url; do
        [[ -z "$url" ]] && continue
        grep -qF "$url" "$CONTENT_FILE" || missing_urls+="${url}"$'\n'
    done <<< "$existing_urls"
    if [[ -n "$missing_urls" ]]; then
        log_fail "REF_COMPLETENESS: external URLs in existing doc absent from new content"
        printf '%s' "$missing_urls" | grep -v '^$' | while IFS= read -r url; do
            printf '  DROPPED: %s\n' "$url" >&2
        done
    else
        log_pass "REF_COMPLETENESS: all existing external URLs preserved"
    fi
else
    log_info "REF_COMPLETENESS: skipped (no --existing provided)"
fi

# -- Check 5: Table blank lines ------------------------------------------------
# A blank line anywhere inside a markdown table block breaks the renderer.
# All rows after the blank line render as raw pipe-separated text rather than
# table cells. Algorithm: track whether we are inside a table (current line
# starts with |), and flag any blank line that appears between two table rows.
# (Incident: 2026-07-22 -- 6 rows collapsed into 1 line, blank line inserted.)
_table_blank_found=0
_in_table=0
_prev_was_table=0
_lineno=0
while IFS= read -r _line; do
    _lineno=$(( _lineno + 1 ))
    if [[ "$_line" =~ ^\| ]]; then
        if [[ "$_in_table" -eq 0 && "$_prev_was_table" -eq 1 ]]; then
            # blank line between table rows
            log_fail "TABLE_BLANK: blank line inside table block at/near line ${_lineno} breaks the markdown renderer"
            _table_blank_found=1
        fi
        _in_table=1
        _prev_was_table=1
    elif [[ -z "$_line" ]]; then
        _prev_was_table="$_in_table"
        _in_table=0
    else
        _in_table=0
        _prev_was_table=0
    fi
done < "$CONTENT_FILE"
if [[ "$_table_blank_found" -eq 0 ]]; then
    log_pass "TABLE_BLANK: no blank lines within table blocks"
fi

# -- Check 6: Table column count -----------------------------------------------
# Every non-separator row in a table must have the same number of pipe characters
# as the header row. A row with a significantly higher count (>2x header pipes)
# almost certainly represents multiple concatenated rows, which is the failure
# mode that occurred on 2026-07-22. Separator rows (lines matching /^[| -]+$/)
# are skipped since they use dashes rather than content delimiters.
_tbl_header_pipes=0
_tbl_row_lineno=0
_tbl_col_violation=0
_in_block=0
_lineno=0
while IFS= read -r _line; do
    _lineno=$(( _lineno + 1 ))
    if [[ "$_line" =~ ^\| ]]; then
        # Count pipes in this row (strip leading whitespace from wc -c output)
        _pipe_count=$(printf '%s' "$_line" | tr -cd '|' | wc -c | tr -d ' ')
        # Detect separator row: must contain at least one dash to distinguish
        # it from an all-space data row (e.g. |   |   | which is a data row).
        if printf '%s\n' "$_line" | grep -qE '^\|[-: ]+(\|[-: ]+)+\|$' && \
           printf '%s\n' "$_line" | grep -qF '-'; then
            _in_block=1
            continue
        fi
        if [[ "$_in_block" -eq 0 ]]; then
            # First non-separator table row = header
            _tbl_header_pipes="$_pipe_count"
            _in_block=1
        else
            # Subsequent rows: flag if pipe count is >= 2x the header.
            # Threshold is 2x (not >2x) so a 2-row concatenation is caught:
            # a 3-pipe header concatenated with itself produces 6 pipes, and
            # 6 >= 6 fires; ">6" would silently pass. Cell content with a
            # single escaped pipe would produce header+1 pipes, well under 2x.
            if [[ "$_tbl_header_pipes" -gt 0 ]] && \
               [[ "$_pipe_count" -ge $(( _tbl_header_pipes * 2 )) ]]; then
                log_fail "TABLE_COLS: row at line ${_lineno} has ${_pipe_count} pipes vs header's ${_tbl_header_pipes} -- likely concatenated rows"
                _tbl_col_violation=1
            fi
        fi
    else
        _in_block=0
        _tbl_header_pipes=0
    fi
done < "$CONTENT_FILE"
if [[ "$_tbl_col_violation" -eq 0 ]]; then
    log_pass "TABLE_COLS: no over-wide table rows detected"
fi

# -- Result --------------------------------------------------------------------
if [[ "$VIOLATIONS" -gt 0 ]]; then
    printf '[wiki-content-check] %d violation(s) -- write blocked\n' "$VIOLATIONS" >&2
    exit 1
fi
printf '[wiki-content-check] all checks passed\n' >&2
exit 0

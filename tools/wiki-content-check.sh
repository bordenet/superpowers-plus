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
#   3. TOC delim   -- Outline toggles use +++ (3 plus signs) as delimiter;
#                     content-author runs of 4-6 are broken. Outline itself
#                     serializes toggle blocks as 7+ plus signs internally --
#                     those are explicitly allowed to prevent false positives
#                     when round-tripping fetched content. (Incident: 2026-07-11)
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
h1_lines=$(grep -n '^# ' "$CONTENT_FILE" || true)
if [[ -n "$h1_lines" ]]; then
    log_fail "H1_TITLE: body must not contain '# Heading' lines (Outline renders title automatically)"
    while IFS= read -r line; do printf '  %s\n' "$line" >&2; done <<< "$h1_lines"
else
    log_pass "H1_TITLE: no H1 lines"
fi

# -- Check 2: AI slop ----------------------------------------------------------
# Known fabricated-generalization openers and filler phrases that indicate
# unedited AI output. Derived from detecting-ai-slop/reference.md categories:
#   Cat. 1 generic boosters, Cat. 2 buzzwords, Cat. 7 typographic tells,
#   Cat. 9 filler openers. Add patterns here as new ones are discovered.
# NOTE: em-dash (—) and en-dash (–) are the highest-signal AI tells (+3 pts
# each in the scoring model). grep -P is used for the Unicode literal match;
# the remaining patterns use plain grep -i (POSIX ERE is sufficient).
if [[ "$SKIP_SLOP" -eq 0 ]]; then
    declare -a SLOP_PATTERNS=(
        # Cat. 9: fabricated-generalization filler openers
        'every sustainable system'
        'at its core,'
        'in the modern'
        'it is worth noting'
        'it is important to note'
        'plays a crucial role'
        'plays a vital role'
        'when it comes to'
        'game-changing'
        'transformative solution'
        # Cat. 2: buzzwords
        'seamlessly integrat'
        'leverage.*capabilit'
        '\butilize\b'
        '\bsynergy\b'
        '\bparadigm.shift'
        '\bbolster\b'
        '\btranscend\b'
        '\bresonate\b'
        '\breimagine\b'
        '\bstreamline'
        '\brobust\b'
        '\bholistic\b'
        '\bseamless\b'
        # Cat. 1: generic boosters
        '\bdelve\b'
        '\bmyriad\b'
        '\bplethora\b'
        '\btremendous'
        '\bprofoundly\b'
        '\bgroundbreaking\b'
        '\binvaluable\b'
    )
    slop_hits=""
    for pat in "${SLOP_PATTERNS[@]}"; do
        hits=$(grep -inE "$pat" "$CONTENT_FILE" || true)
        [[ -n "$hits" ]] && slop_hits+="${hits}"$'\n'
    done
    # Cat. 7: em-dash (U+2014) and en-dash (U+2013) -- highest-signal AI tells.
    # macOS grep has no -P flag; python3 is used for the Unicode literal match.
    # Exempt: numeric ranges ("pp. 3-7") already use ASCII hyphens in markdown;
    # the Unicode em/en-dash characters have no legitimate use in wiki prose.
    if command -v python3 >/dev/null 2>&1; then
        emdash_hits=$(python3 - "$CONTENT_FILE" << 'PYEOF'
import sys, re
path = sys.argv[1]
with open(path, encoding="utf-8", errors="replace") as fh:
    for i, line in enumerate(fh, 1):
        if re.search(r'[\u2014\u2013]', line):
            print(f"{i}:{line.rstrip()}")
PYEOF
        )
        [[ -n "$emdash_hits" ]] && slop_hits+="${emdash_hits}"$'\n'
    else
        log_info "AI_SLOP: python3 not found; skipping em/en-dash check"
    fi
    if [[ -n "$slop_hits" ]]; then
        log_fail "AI_SLOP: slop patterns detected -- replace em/en-dashes with ASCII punctuation and remove filler phrases before publishing"
        printf '%s' "$slop_hits" | grep -v '^$' | while IFS= read -r line; do
            printf '  %s\n' "$line" >&2
        done
    else
        log_pass "AI_SLOP: no known slop patterns"
    fi
else
    printf '[wiki-content-check] WARN  AI_SLOP: slop check skipped (--skip-slop) -- ensure content is human-reviewed\n' >&2
fi

# -- Check 3: TOC delimiter length ---------------------------------------------
# Outline toggle blocks open/close with exactly +++ (3 plus signs) in
# author-written content. Runs of 4–6 are broken author content and are
# rejected. Runs of 7+ are Outline's own internal serialization format for
# toggle blocks (the API round-trips fetched content back as +++++++); those
# are allowed so agents can fetch → edit → re-submit without false positives.
bad_toc=$(grep -nE '^\+{4,6}$' "$CONTENT_FILE" || true)
if [[ -n "$bad_toc" ]]; then
    log_fail "TOC_DELIM: toggle delimiter must be exactly '+++' (author) or '+++++++' (Outline internal); 4–6 plus signs are broken"
    while IFS= read -r line; do printf '  %s\n' "$line" >&2; done <<< "$bad_toc"
else
    log_pass "TOC_DELIM: no malformed toggle delimiters"
fi

# -- Check 4: Ref completeness -------------------------------------------------
# When an existing document body is provided, extract all absolute http/https
# URLs from it and verify each one still appears in the new content.
# A missing URL means a link was silently dropped during the update --
# most commonly a Core Board or SharePoint reference.
# Relative /doc/ links are excluded; they are checked by the skill preflight.
if [[ -n "$EXISTING_FILE" && -r "$EXISTING_FILE" ]]; then
    existing_urls=$(grep -oE 'https?://[^)> "]+' "$EXISTING_FILE" | sort -u || true)
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

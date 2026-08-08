#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Script: toc-delimiter-check.sh
# PURPOSE: Validate Outline toggle-block "+" fence delimiters in a markdown
#          file. Two independent things are checked:
#
#   1. Duplicate TOC toggle -- more than one "**Table of contents**" title
#      on the page (case-insensitive) means an update should have edited
#      the existing toggle instead of adding a second one.
#   2. Toggle fence structure -- every "+"-run of 3+ characters outside a
#      nested code fence (``` or ~~~) must properly open/close per
#      Outline's real parser (markdown-it-container, min_markers=3): a
#      candidate closing line with FEWER "+" chars than the fence
#      currently open does not close it -- it's body content, and the
#      first line with an equal-or-greater count closes the current
#      (innermost) open toggle. A shorter-count line while a toggle is
#      open therefore opens a NESTED toggle one level deeper, per
#      Outline's own documented nesting convention: the OUTER fence must
#      have MORE "+" characters than any toggle nested inside it.
#
#      There is no fixed "correct" delimiter length (not "exactly 3", not
#      "4-6 is broken", not "exactly 7") -- Outline's serializer emits
#      "3 + block-nesting-depth" characters on export, which is
#      content-dependent. This script validates STRUCTURE (matching
#      open/close, correct nesting order), not a specific character count.
#
# KNOWN LIMITATION: this is a line-oriented heuristic, not a full markdown
# parser. If a toggle is missing its closing fence AND an unrelated,
# separately-closed toggle immediately follows with no heading or code
# fence between them, this check can still report PASS by structurally
# absorbing the later toggle's fence. Closing this fully needs a real
# document-wide AST parser; not attempted here.
#
# USAGE:
#   toc-delimiter-check.sh --content FILE
#   toc-delimiter-check.sh --help
#
# OPTIONS:
#   --content FILE    Markdown file to validate (required)
#   -v, --verbose     Print PASS results too (default: only FAIL/errors)
#   -h, --help        Show this help
#
# EXIT:
#   0  no toggle fence defects found
#   1  one or more defects found (details on stderr)
#   2  usage / environment error
#
# REQUIRES: bash 4+, python3
# PLATFORM: macOS, Linux
# VERSION:  1.0.0
# -----------------------------------------------------------------------------
set -euo pipefail

if [ -z "${BASH_VERSION:-}" ]; then
    echo "ERROR: requires bash. Run with: bash $0" >&2; exit 2
fi
if (( ${BASH_VERSINFO[0]:-0} < 4 )); then
    echo "ERROR: requires bash 4+; on macOS run: brew install bash" >&2; exit 2
fi
if ! command -v python3 >/dev/null 2>&1; then
    echo "ERROR: requires python3 on PATH" >&2; exit 2
fi

CONTENT_FILE=""
VERBOSE=0

show_help() {
    grep '^#' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//' | sed -n '/^Script:/,/^---/p'
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)    show_help; exit 0 ;;
        --content)    CONTENT_FILE="${2:?--content requires a file}"; shift 2 ;;
        -v|--verbose) VERBOSE=1; shift ;;
        *) printf 'ERROR: unknown option: %s\n' "$1" >&2; exit 2 ;;
    esac
done

[[ -n "$CONTENT_FILE" ]] || { echo "ERROR: --content FILE is required" >&2; exit 2; }
[[ -f "$CONTENT_FILE" ]] || { echo "ERROR: content file does not exist or is not a regular file: $CONTENT_FILE" >&2; exit 2; }
[[ -r "$CONTENT_FILE" ]] || { echo "ERROR: content file not readable: $CONTENT_FILE" >&2; exit 2; }

RC=
# The content filename is passed as sys.argv[1], never interpolated into the
# python source string -- a filename containing a single quote would
# otherwise break out of the string literal and execute as python (CWE-88/94,
# found by code-review-battery 2026-07-29 with a working PoC). encoding=
# 'utf-8-sig' additionally strips a leading UTF-8 BOM, which otherwise made
# the first line's fence marker invisible to the regex and produced a false
# FAIL on genuinely valid content (same review round, same fix).
RESULT=$(python3 -c "
import re, sys

def is_code_fence_marker(line):
    m = re.match(r'^(\`{3,}|~{3,})', line.lstrip())
    if not m:
        return None
    run = m.group(1)
    return (run[0], len(run))

lines = open(sys.argv[1], encoding='utf-8-sig').read().split(chr(10))

# Pass 1: mark every line as inside/outside a nested code fence. CommonMark
# fenced code blocks do not truly nest -- once inside one, only a
# same-character run at least as long as the opener closes it; anything
# else is literal content.
in_code_fence = [False] * len(lines)
current_fence = None
for i, line in enumerate(lines):
    stripped = line.strip()
    if current_fence is None:
        marker = is_code_fence_marker(line)
        if marker:
            current_fence = marker
            in_code_fence[i] = True
            continue
        in_code_fence[i] = False
    else:
        in_code_fence[i] = True
        char, length = current_fence
        if re.fullmatch(re.escape(char) + '{' + str(length) + ',}', stripped):
            current_fence = None

errors = []

# Check 1: duplicate TOC toggle (Idempotency rule -- only one should exist).
title_idxs = [i for i, l in enumerate(lines)
              if not in_code_fence[i] and l.strip().lower() == '**table of contents**']
if len(title_idxs) > 1:
    errors.append(f'{len(title_idxs)} \"Table of contents\" toggles found on this page (lines {[i + 1 for i in title_idxs]}) -- update the existing one rather than adding a second; consolidate before writing')

# Check 2: general toggle-fence structure, stack-based, matching real
# markdown-it-container semantics (verified against its actual source,
# 2026-07-29): a '+'-run >= the innermost open toggle's length closes it;
# a shorter run opens a new nested level. Runs under 3 chars are not
# recognized as fence markers at all (min_markers=3) -- literal text.
stack = []
for i, line in enumerate(lines):
    if in_code_fence[i]:
        continue
    stripped = line.strip()
    if not re.fullmatch(r'\++', stripped):
        continue
    k = len(stripped)
    if k < 3:
        continue
    if not stack:
        stack.append((i, k))
    else:
        top_idx, top_len = stack[-1]
        if k >= top_len:
            stack.pop()
        else:
            stack.append((i, k))

for open_idx, open_len in stack:
    errors.append(f'no closing fence found for toggle opened at line {open_idx + 1} ({open_len} chars) -- Outline auto-closes this at end of document, absorbing everything after it into the toggle body')

print(chr(10).join(errors))
" "$CONTENT_FILE") || RC=$?
RC=${RC:-0}

if [[ "$RC" -ne 0 ]]; then
    echo "[toc-delimiter-check] ERROR: python3 failed on $CONTENT_FILE -- ABORT, do not infer PASS" >&2
    exit 2
fi

if [[ -n "$RESULT" ]]; then
    printf '[toc-delimiter-check] FAIL\n' >&2
    while IFS= read -r line; do printf '  %s\n' "$line" >&2; done <<< "$RESULT"
    exit 1
fi

[[ "$VERBOSE" -eq 1 ]] && printf '[toc-delimiter-check] PASS  no toggle fence defects found\n' >&2
exit 0

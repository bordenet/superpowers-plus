#!/usr/bin/env bats
# Tests for tools/toc-delimiter-check.sh
#
# All tests are hermetic: they write temporary markdown files and run the
# script directly. No network calls; no Outline credentials needed.
#
# Case numbering below mirrors the manual test battery this script's logic
# was validated against during development (see skills/common/outline-wiki-
# editing/skill.md's git history) -- kept here as the durable, re-runnable
# artifact that manual "tested it" claims in commit messages are not.

TOOL="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)/tools/toc-delimiter-check.sh"

setup() {
    TMPDIR_LOCAL=$(mktemp -d)
    CONTENT="$TMPDIR_LOCAL/content.md"
}

teardown() {
    rm -rf "$TMPDIR_LOCAL"
}

run_check() {
    run bash "$TOOL" "$@"
}

# ── Static / usage checks ──────────────────────────────────────────────────

@test "static: --help exits 0" {
    run_check --help
    [ "$status" -eq 0 ]
}

@test "static: bash -n passes (syntax valid)" {
    run bash -n "$TOOL"
    [ "$status" -eq 0 ]
}

@test "static: shellcheck passes" {
    command -v shellcheck >/dev/null 2>&1 || skip "shellcheck not installed"
    run shellcheck "$TOOL"
    [ "$status" -eq 0 ]
}

@test "static: missing --content exits 2" {
    run_check
    [ "$status" -eq 2 ]
}

@test "static: unreadable content file exits 2" {
    run_check --content /tmp/this_does_not_exist_bats_toc
    [ "$status" -eq 2 ]
}

@test "static: directory passed as --content exits 2, not a raw traceback" {
    run_check --content "$TMPDIR_LOCAL"
    [ "$status" -eq 2 ]
}

# ── Security: filename must never be interpolated into python source ───────

@test "security: content filename containing a single quote does not break out of the python string" {
    # Regression test for a real code-injection hole (CWE-88/94, found by
    # code-review-battery 2026-07-29): the filename was spliced into
    # `open('$CONTENT_FILE')` as literal python source text. A crafted
    # filename could break out of the string literal and execute arbitrary
    # python. Fixed by passing the filename as sys.argv[1] instead.
    # PWNED_marker is a relative path (touch runs in whatever cwd python
    # inherits) -- a filename component itself cannot contain "/", so the
    # payload can't embed a full absolute path without that path segment
    # becoming (invalid, nonexistent) intermediate directories.
    local evil="$TMPDIR_LOCAL/x'); import os as _o; _o.system('touch PWNED_marker'); x=('.md"
    printf 'intro\n\n+++\n**Table of contents**\n- x\n+++\n\nmore\n' > "$evil"
    cd "$TMPDIR_LOCAL"
    run_check --content "$evil"
    [ "$status" -eq 0 ]
    [ ! -e "${TMPDIR_LOCAL}/PWNED_marker" ]
}

@test "security: ordinary filename with an apostrophe (non-adversarial) still works" {
    local benign="$TMPDIR_LOCAL/o'brien notes.md"
    printf 'intro\n\n+++\n**Table of contents**\n- x\n+++\n\nmore\n' > "$benign"
    run_check --content "$benign"
    [ "$status" -eq 0 ]
}

# ── UTF-8 BOM tolerance ──────────────────────────────────────────────────────

@test "encoding: UTF-8 BOM at start of file does not hide the first fence" {
    # Regression test (code-review-battery 2026-07-29): a leading BOM made
    # the first line's fence marker invisible to the regex, producing a
    # false FAIL ("no closing fence found") on genuinely valid content.
    printf '\xef\xbb\xbf+++\nbody\n+++\n' > "$CONTENT"
    run_check --content "$CONTENT"
    [ "$status" -eq 0 ]
}

# ── Basic fence structure ──────────────────────────────────────────────────

@test "case 1: matched 3-char fence, valid toggle, exits 0" {
    printf 'intro\n\n+++\n**Table of contents**\n- x\n+++\n\nmore\n' > "$CONTENT"
    run_check --content "$CONTENT"
    [ "$status" -eq 0 ]
}

@test "case 2: matched 7-char fence (Outline re-serialized), exits 0" {
    printf 'intro\n\n+++++++\n**Table of contents**\n- x\n+++++++\n\nmore\n' > "$CONTENT"
    run_check --content "$CONTENT"
    [ "$status" -eq 0 ]
}

@test "case 3: opening(7) longer than closing(3), exits 1" {
    printf 'intro\n\n+++++++\n**Table of contents**\n- x\n+++\n\nmore\n' > "$CONTENT"
    run_check --content "$CONTENT"
    [ "$status" -eq 1 ]
}

@test "case 4: opening fence, no closing fence, exits 1" {
    printf 'intro\n\n+++\n**Table of contents**\n- x\n\nmore\n' > "$CONTENT"
    run_check --content "$CONTENT"
    [ "$status" -eq 1 ]
}

@test "case 5: no toggle anywhere in the document, exits 0" {
    printf 'intro\n\nno toggles here\n' > "$CONTENT"
    run_check --content "$CONTENT"
    [ "$status" -eq 0 ]
}

@test "case 6: both fences 2 chars (under min-3), not recognized as fences, exits 0" {
    # Per the real parser (markdown-it-container, min_markers=3), a 2-char
    # run is not a fence candidate at all -- literal text, not a defect.
    printf 'intro\n\n++\nnot really a toggle\n++\n\nmore\n' > "$CONTENT"
    run_check --content "$CONTENT"
    [ "$status" -eq 0 ]
}

@test "case 7: unrelated valid nested toggle elsewhere, no TOC title, exits 0" {
    printf 'intro\n\n++++\nouter\n+++\ninner\n+++\nouter2\n++++\n' > "$CONTENT"
    run_check --content "$CONTENT"
    [ "$status" -eq 0 ]
}

@test "case 8: valid TOC toggle + unrelated valid nested toggle elsewhere, exits 0" {
    printf 'intro\n\n+++\n**Table of contents**\n- x\n+++\n\nmore\n\n++++\nouter\n+++\ninner\n+++\nouter2\n++++\n' > "$CONTENT"
    run_check --content "$CONTENT"
    [ "$status" -eq 0 ]
}

# ── Duplicate TOC ───────────────────────────────────────────────────────────

@test "case 9: two Table of contents toggles on the same page, exits 1" {
    printf '+++\n**Table of contents**\n- item1\n+++\n\n+++\n**Table of contents**\n- item2\n+++\n' > "$CONTENT"
    run_check --content "$CONTENT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Table of contents"*"toggles found"* ]]
}

@test "case 9b: three Table of contents toggles, exits 1 and reports count" {
    printf '+++\n**Table of contents**\n+++\n\n+++\n**Table of contents**\n+++\n\n+++\n**Table of contents**\n+++\n' > "$CONTENT"
    run_check --content "$CONTENT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"3 \"Table of contents\""* ]]
}

# ── Whitespace / case tolerance ─────────────────────────────────────────────

@test "case 10: opening fence has trailing whitespace, exits 0" {
    printf '+++ \n**Table of contents**\n- item\n+++\n' > "$CONTENT"
    run_check --content "$CONTENT"
    [ "$status" -eq 0 ]
}

@test "case 11: opening fence has leading whitespace, exits 0" {
    printf ' +++\n**Table of contents**\n- item\n+++\n' > "$CONTENT"
    run_check --content "$CONTENT"
    [ "$status" -eq 0 ]
}

@test "case 12: blank line between opening fence and title, exits 0" {
    printf '+++\n\n**Table of contents**\n- item\n+++\n' > "$CONTENT"
    run_check --content "$CONTENT"
    [ "$status" -eq 0 ]
}

@test "case 13: TOC title in different case, exits 0" {
    printf '+++\n**TABLE OF CONTENTS**\n- item\n+++\n' > "$CONTENT"
    run_check --content "$CONTENT"
    [ "$status" -eq 0 ]
}

@test "case 17: CRLF line endings throughout, exits 0" {
    printf 'intro\r\n\r\n+++\r\n**Table of contents**\r\n- x\r\n+++\r\n\r\nmore\r\n' > "$CONTENT"
    run_check --content "$CONTENT"
    [ "$status" -eq 0 ]
}

# ── Code-fence awareness ────────────────────────────────────────────────────

@test "case 18: '#'-comment inside a nested code fence in the TOC body, exits 0" {
    printf 'Intro.\n\n+++\n**Table of contents**\n- x\nExample usage:\n```bash\n    # this is a shell comment, not a heading\necho hi\n```\n+++\n\n## Section One\n' > "$CONTENT"
    run_check --content "$CONTENT"
    [ "$status" -eq 0 ]
}

@test "case 19: literal '+++'-looking text inside a code fence, exits 0" {
    printf 'Intro.\n\n+++\n**Table of contents**\n- x\nExample:\n```markdown\n+++\n**fake nested toggle inside example**\n+++\n```\n+++\n\nmore\n' > "$CONTENT"
    run_check --content "$CONTENT"
    [ "$status" -eq 0 ]
}

@test "case 20: nested mismatched-length code fence (4-tick outer, 3-tick inner), exits 0" {
    printf '+++\n**Table of contents**\n\n- x\n````markdown\n```\n# this looks like a heading, inside a nested shorter fence\n```\n````\n+++\n' > "$CONTENT"
    run_check --content "$CONTENT"
    [ "$status" -eq 0 ]
}

@test "case 21: TOC title text appears inside an unrelated fenced example, exits 0" {
    printf '+++\n**Table of contents**\n- x\n+++\n\nmore content\n\nHow to write a TOC:\n```markdown\n+++\n**Table of contents**\n- example\n+++\n```\n' > "$CONTENT"
    run_check --content "$CONTENT"
    [ "$status" -eq 0 ]
}

@test "case 22: broken example only inside a code fence, no real toggle, exits 0" {
    printf '# Wiki Authoring Guide\n\n## Common TOC Mistakes\n\nDo not do this:\n```markdown\n++\n**Table of contents**\n- x\n++\n```\n' > "$CONTENT"
    run_check --content "$CONTENT"
    [ "$status" -eq 0 ]
}

# ── General toggle nesting (non-TOC) ────────────────────────────────────────

@test "nesting: outer(4) longer than inner(3), correct direction, exits 0" {
    printf '++++\nOuter title\n+++\nInner title\nInner body\n+++\nMore outer body\n++++\n' > "$CONTENT"
    run_check --content "$CONTENT"
    [ "$status" -eq 0 ]
}

@test "nesting: outer(3) shorter than inner(4), backwards direction, exits 1" {
    # Matches the real markdown-it-container parser: a candidate close
    # shorter than the currently-open fence does not close it -- it opens
    # a nested level instead, leaving the true outer toggle unclosed.
    printf '+++\nOuter title\n++++\nInner title\nInner body\n++++\nMore outer body\n+++\n' > "$CONTENT"
    run_check --content "$CONTENT"
    [ "$status" -eq 1 ]
}

@test "nesting: two sibling (non-nested) toggles, exits 0" {
    printf '+++\nToggle A\nbody\n+++\n\n+++\nToggle B\nbody\n+++\n' > "$CONTENT"
    run_check --content "$CONTENT"
    [ "$status" -eq 0 ]
}

# ── Regression: previously-disclosed limitation, fixed by the general
#    stack-based algorithm (an earlier title-anchored heuristic blindly took
#    whatever fence came next after the TOC title as its close; the general
#    algorithm below matches real parser semantics: the TOC toggle's own
#    "+++" closes it correctly, and the truly-unclosed unrelated toggle is
#    what actually gets reported, not silently ignored) ───────────────────

@test "case 16: missing close + unrelated toggle immediately after, no heading between -- correctly flags the actually-unclosed toggle, exits 1" {
    printf 'Intro.\n\n+++\n**Table of contents**\n- [Section One](#h-section-one)\n+++\n**Unrelated toggle title**\nSome unrelated toggle content.\n+++\n\n## Section One\n' > "$CONTENT"
    run_check --content "$CONTENT"
    [ "$status" -eq 1 ]
}

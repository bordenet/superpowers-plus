#!/usr/bin/env bats
# Tests for tools/wiki-content-check.sh
#
# All tests are hermetic: they write temporary markdown files and run the
# script directly. No network calls; no Outline credentials needed.
#
# Pattern follows tests/tools/wiki-env-precedence.bats conventions.

TOOL="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)/tools/wiki-content-check.sh"

setup() {
    TMPDIR_LOCAL=$(mktemp -d)
    CONTENT="$TMPDIR_LOCAL/content.md"
    EXISTING="$TMPDIR_LOCAL/existing.md"
}

teardown() {
    rm -rf "$TMPDIR_LOCAL"
}

run_check() {
    run bash "$TOOL" "$@" 2>&1
}

# ── Static checks ─────────────────────────────────────────────────────────

@test "check: --help exits 0" {
    run_check --help
    [ "$status" -eq 0 ]
}

@test "check: bash -n passes (syntax valid)" {
    run bash -n "$TOOL"
    [ "$status" -eq 0 ]
}

@test "check: shellcheck passes" {
    command -v shellcheck >/dev/null 2>&1 || skip "shellcheck not installed"
    run shellcheck "$TOOL"
    [ "$status" -eq 0 ]
}

@test "check: missing --content exits 2" {
    run_check
    [ "$status" -eq 2 ]
}

@test "check: unreadable content file exits 2" {
    run_check --content /tmp/this_does_not_exist_bats
    [ "$status" -eq 2 ]
}

# ── H1 title gate ─────────────────────────────────────────────────────────

@test "h1: clean file exits 0" {
    printf '## Section\nsome text\n' > "$CONTENT"
    run_check --content "$CONTENT"
    [ "$status" -eq 0 ]
}

@test "h1: file with H1 exits 1" {
    printf '# Page Title\n## Section\n' > "$CONTENT"
    run_check --content "$CONTENT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"H1_TITLE"* ]]
}

@test "h1: H2 is not flagged" {
    printf '## Not an H1\ntext\n' > "$CONTENT"
    run_check --content "$CONTENT"
    [ "$status" -eq 0 ]
}

# Regression coverage for a code-review-battery ShellRuntimeAuditor finding:
# `grep -n '^# ' "$CONTENT_FILE" || true` mapped "no H1 found" (benign, grep
# exit 1) and a genuine grep failure (exit >=2) to the identical empty
# result -- a real scan failure would silently report "no H1 lines" instead
# of aborting. A real grep cannot be made to fail on demand for a
# well-formed pattern against a readable file, so this stubs grep itself
# (fake_bin with every other needed tool symlinked through).
@test "h1: a broken grep (real failure, not no-match) exits 2, not a false clean" {
    local fake_bin="$TMPDIR_LOCAL/fake_bin_grep"
    mkdir -p "$fake_bin"
    for t in dirname printf tr wc cat sed basename mktemp sort python3 rm command; do
        local real_path
        real_path="$(command -v "$t" 2>/dev/null)" || continue
        ln -sf "$real_path" "$fake_bin/$t"
    done
    printf '#!/bin/sh\nexit 2\n' > "$fake_bin/grep"
    chmod +x "$fake_bin/grep"
    printf '## Section\nsome text\n' > "$CONTENT"
    run env PATH="$fake_bin:$PATH" bash "$TOOL" --content "$CONTENT"
    [ "$status" -eq 2 ]
    [[ "$output" == *"H1_TITLE"* ]]
}

# ── AI slop gate ──────────────────────────────────────────────────────────

@test "slop: clean content exits 0" {
    printf '## Deployment\nThe service runs on ECS.\n' > "$CONTENT"
    run_check --content "$CONTENT"
    [ "$status" -eq 0 ]
}

@test "slop: known slop phrase exits 1" {
    printf '## Intro\nWe should utilize this approach.\n' > "$CONTENT"
    run_check --content "$CONTENT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"AI_SLOP"* ]]
}

@test "slop: delegated script environment error exits 2, not 1 (exit-code contract)" {
    # Regression test: slop-check.sh's URL-redaction step made python3 an
    # unconditional hard dependency (exit 2 if missing), but the caller here
    # originally folded that exit 2 into the same generic content-violation
    # exit 1 used for real slop, making an environment failure
    # indistinguishable from "your wiki content has AI slop." Mirrors the
    # existing "toc: delegated script environment error" test's approach: a
    # fake python3 stub that always exits 42 forces slop-check.sh's own
    # python3-failure path without depending on any specific PATH/python3
    # layout on the test machine.
    local fake_bin="$TMPDIR_LOCAL/fake_bin"
    mkdir -p "$fake_bin"
    printf '#!/bin/sh\nexit 42\n' > "$fake_bin/python3"
    chmod +x "$fake_bin/python3"
    printf '## Intro\nThe service runs on ECS.\n' > "$CONTENT"
    run env PATH="$fake_bin:$PATH" bash "$TOOL" --content "$CONTENT"
    [ "$status" -eq 2 ]
    [[ "$output" == *"AI_SLOP"* ]]
}

@test "slop: --skip-slop bypasses slop check" {
    printf '## Intro\nEvery sustainable system needs balance.\n' > "$CONTENT"
    run_check --content "$CONTENT" --skip-slop
    # slop alone should not fail when skipped
    [ "$status" -eq 0 ]
}

@test "slop: 'plays a crucial role' is flagged" {
    printf '## Summary\nThis plays a crucial role in stability.\n' > "$CONTENT"
    run_check --content "$CONTENT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"AI_SLOP"* ]]
}

@test "slop: 'plays a vital role' is flagged" {
    printf '## Summary\nThis plays a vital role in stability.\n' > "$CONTENT"
    run_check --content "$CONTENT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"AI_SLOP"* ]]
}

@test "slop: 'when it comes to' is advisory only (does not block)" {
    printf '## Summary\nWhen it comes to deployment, we ship daily.\n' > "$CONTENT"
    run_check --content "$CONTENT"
    [ "$status" -eq 0 ]
}

@test "slop: 'every sustainable system' is flagged" {
    printf '## Summary\nEvery sustainable system needs monitoring in place.\n' > "$CONTENT"
    run_check --content "$CONTENT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"AI_SLOP"* ]]
}

@test "slop: 'in the modern' (broad form) is flagged" {
    printf '## Summary\nIn the modern workplace, teams ship faster than ever.\n' > "$CONTENT"
    run_check --content "$CONTENT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"AI_SLOP"* ]]
}

@test "slop: 'seamlessly integrat' is flagged" {
    printf '## Summary\nThe tool seamlessly integrates with our stack.\n' > "$CONTENT"
    run_check --content "$CONTENT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"AI_SLOP"* ]]
}

@test "slop: 'at its core,' is advisory only (does not block)" {
    printf '## Summary\nAt its core, this is a caching layer.\n' > "$CONTENT"
    run_check --content "$CONTENT"
    [ "$status" -eq 0 ]
}

@test "slop: 'invaluable' is flagged" {
    printf '## Summary\nThis feedback was invaluable.\n' > "$CONTENT"
    run_check --content "$CONTENT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"AI_SLOP"* ]]
}

# ── TOC delimiter gate ────────────────────────────────────────────────────

@test "toc: correct +++ delimiter exits 0" {
    printf '+++\n## Table of contents\n+++\n' > "$CONTENT"
    run_check --content "$CONTENT"
    [ "$status" -eq 0 ]
}

@test "toc: 7-char +++++++ delimiter exits 0 (Outline internal format, allowed)" {
    # Outline serializes toggle blocks as 7+ plus signs internally.
    # Agents that fetch → edit → re-submit must not be falsely blocked.
    printf '+++++++\n## TOC\n+++++++\n' > "$CONTENT"
    run_check --content "$CONTENT" --skip-slop
    [ "$status" -eq 0 ]
}

@test "toc: 5-char +++++ delimiter, matched open/close, exits 0" {
    # Corrected 2026-07-29: there is no fixed "correct" delimiter length.
    # Outline's serializer emits content-dependent lengths (3 + nesting
    # depth); a matched 5/5 pair is structurally valid per the real parser.
    printf '+++++\nsome content\n+++++\n' > "$CONTENT"
    run_check --content "$CONTENT"
    [ "$status" -eq 0 ]
}

@test "toc: 4-char ++++ delimiter, matched open/close, exits 0" {
    printf '++++\nsome content\n++++\n' > "$CONTENT"
    run_check --content "$CONTENT"
    [ "$status" -eq 0 ]
}

@test "toc: mismatched open(5)/close(3) exits 1 (real structural defect)" {
    # Closing fence shorter than opening does not close it per the real
    # parser -- it opens a nested level instead, leaving both unclosed.
    printf '+++++\nsome content\n+++\n' > "$CONTENT"
    run_check --content "$CONTENT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"TOC_DELIM"* ]]
}

@test "toc: duplicate Table of contents toggles exits 1" {
    printf '+++\n**Table of contents**\n- a\n+++\n\n+++\n**Table of contents**\n- b\n+++\n' > "$CONTENT"
    run_check --content "$CONTENT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"TOC_DELIM"* ]]
}

@test "toc: delegated script environment error exits 2, not 1 (exit-code contract)" {
    # Regression test (code-review-battery 2026-07-29): an environment/usage
    # error from toc-delimiter-check.sh (exit 2) was being folded into this
    # script's generic content-violation exit 1, making an environment
    # failure indistinguishable from "your wiki content is broken." A fake
    # python3 stub that always exits 42 forces toc-delimiter-check.sh's own
    # python3-failure path (its ERROR branch, exit 2) without depending on
    # any specific PATH/python3 layout on the test machine.
    local fake_bin="$TMPDIR_LOCAL/fake_bin"
    mkdir -p "$fake_bin"
    printf '#!/bin/sh\nexit 42\n' > "$fake_bin/python3"
    chmod +x "$fake_bin/python3"
    printf '+++\n**Table of contents**\n- x\n+++\n' > "$CONTENT"
    run env PATH="$fake_bin:$PATH" bash "$TOOL" --content "$CONTENT" --skip-slop
    [ "$status" -eq 2 ]
    [[ "$output" == *"TOC_DELIM"* ]]
}

# ── Ref completeness gate ─────────────────────────────────────────────────

@test "ref: no --existing skips ref check" {
    printf '## Section\ntext only\n' > "$CONTENT"
    run_check --content "$CONTENT"
    [ "$status" -eq 0 ]
}

@test "ref: URL preserved exits 0" {
    printf '[Board](https://core.example.com/go/bproject_manage.cfm?pid=60731)\n' > "$EXISTING"
    printf '[Board](https://core.example.com/go/bproject_manage.cfm?pid=60731)\nmore text\n' > "$CONTENT"
    run_check --content "$CONTENT" --existing "$EXISTING"
    [ "$status" -eq 0 ]
}

@test "ref: dropped URL exits 1" {
    printf '[Board](https://core.example.com/go/bproject_manage.cfm?pid=60731)\n' > "$EXISTING"
    printf '## Section\nno links here\n' > "$CONTENT"
    run_check --content "$CONTENT" --existing "$EXISTING"
    [ "$status" -eq 1 ]
    [[ "$output" == *"REF_COMPLETENESS"* ]]
    [[ "$output" == *"DROPPED"* ]]
}

@test "ref: unreadable --existing silently skips (no crash)" {
    printf '## Section\ntext\n' > "$CONTENT"
    run_check --content "$CONTENT" --existing /tmp/does_not_exist_bats
    # missing existing file should skip ref check gracefully, not crash
    [ "$status" -eq 0 ]
}

# ── Multiple violations ───────────────────────────────────────────────────

@test "multiple: H1 + slop + bad TOC all reported" {
    # Use mismatched open(5)/close(3) -- a real structural defect --
    # rather than a matched pair, which is now valid regardless of length.
    printf '# Title\nWe should utilize this approach.\n+++++\n## TOC\n+++\n' > "$CONTENT"
    run_check --content "$CONTENT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"H1_TITLE"* ]]
    [[ "$output" == *"AI_SLOP"* ]]
    [[ "$output" == *"TOC_DELIM"* ]]
}

# ── REF_COMPLETENESS URL normalisation ─────────────────────────────────────
# The greedy URL regex captures trailing backticks and sentence punctuation
# when a URL sits inside a markdown code span. Without normalisation the
# left-side key carries that noise, no longer matches the clean URL in the new
# content, and the gate reports a DROPPED reference that was never dropped.

@test "ref: URL in a code span with trailing backtick and period is not falsely DROPPED" {
    printf 'See `https://core.example.com/go/bproject_manage.cfm?pid=60731`.\n' > "$EXISTING"
    printf '[Board](https://core.example.com/go/bproject_manage.cfm?pid=60731)\n' > "$CONTENT"
    run_check --content "$CONTENT" --existing "$EXISTING"
    [ "$status" -eq 0 ]
    [[ "$output" != *"DROPPED"* ]]
}

@test "ref: trailing comma, semicolon, colon and apostrophe are all normalised" {
    printf 'a https://x.example.com/a,\nb https://x.example.com/b;\nc https://x.example.com/c:\n' > "$EXISTING"
    printf 'https://x.example.com/a https://x.example.com/b https://x.example.com/c\n' > "$CONTENT"
    run_check --content "$CONTENT" --existing "$EXISTING"
    [ "$status" -eq 0 ]
}

@test "ref: bracket-notation URL keeps its trailing ] and still matches" {
    # ] is deliberately excluded from the strip set; stripping it would corrupt
    # an API path such as /items[0] and turn a present URL into a false DROPPED.
    printf 'API `https://x.example.com/items[0]`\n' > "$EXISTING"
    printf 'See https://x.example.com/items[0] for the shape.\n' > "$CONTENT"
    run_check --content "$CONTENT" --existing "$EXISTING"
    [ "$status" -eq 0 ]
    [[ "$output" != *"DROPPED"* ]]
}

@test "ref: a genuinely dropped URL is still caught after normalisation" {
    # The normalisation must not turn the gate into a rubber stamp.
    printf 'See `https://core.example.com/go/bproject_manage.cfm?pid=60731`.\n' > "$EXISTING"
    printf '## Section\nno links here\n' > "$CONTENT"
    run_check --content "$CONTENT" --existing "$EXISTING"
    [ "$status" -eq 1 ]
    [[ "$output" == *"DROPPED"* ]]
}

#!/usr/bin/env bats
# Tests for tools/slop-check.sh
#
# All tests are hermetic: they write temporary markdown files and run the
# script directly. No network calls; no external credentials needed.
#
# Covers the URL-redaction fix: buzzword/filler/booster/em-dash checks used
# to grep raw content with no markdown or URL awareness, so a word like
# "unlock" inside a Linear/GitLab URL slug false-positived identically to
# real authored prose -- with no way to fix by editing content when the
# exact URL must be preserved byte-for-byte (wiki-content-check.sh's own
# REF_COMPLETENESS check). The redaction cases below are the regression
# coverage for that fix, including the follow-on false-negative bug the
# first cut of the fix introduced (the redaction regex crossed newlines and
# other delimiters, silently erasing real violations adjacent to a URL --
# not just the ones inside it) and the rest establish that real violations
# still block.

TOOL="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)/tools/slop-check.sh"

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

@test "usage: missing --content exits 2" {
    run_check
    [ "$status" -eq 2 ]
}

@test "usage: unreadable file exits 2" {
    run_check --content "$TMPDIR_LOCAL/does-not-exist.md"
    [ "$status" -eq 2 ]
}

@test "usage: bad --mode exits 2" {
    printf 'clean content\n' > "$CONTENT"
    run_check --content "$CONTENT" --mode bogus
    [ "$status" -eq 2 ]
}

# ── URL redaction ────────────────────────────────────────────────────────────

@test "buzzword inside a markdown link's URL slug does not block" {
    printf 'See [TICKET](https://linear.app/example/issue/TEAM-1603/some-feature-background-unlock-leak) for details.\n' > "$CONTENT"
    run_check --content "$CONTENT"
    [ "$status" -eq 0 ]
}

@test "buzzword inside a bare backtick-wrapped URL does not block" {
    printf 'Local endpoint: `http://127.0.0.1:6065/unlock-status`.\n' > "$CONTENT"
    run_check --content "$CONTENT"
    [ "$status" -eq 0 ]
}

@test "same buzzword in real prose (not a URL) still blocks" {
    printf 'This will unlock huge value for the team.\n' > "$CONTENT"
    run_check --content "$CONTENT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"BUZZWORD"* ]]
}

@test "prose buzzword blocks even when the same line also has a clean URL" {
    printf 'This will unlock huge value; see https://example.com/status for the report.\n' > "$CONTENT"
    run_check --content "$CONTENT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"BUZZWORD"* ]]
}

@test "filler phrase inside a URL slug does not block" {
    printf '[ticket](https://gitlab.example.com/foo/bar/-/merge_requests/1/in-summary-of-changes)\n' > "$CONTENT"
    run_check --content "$CONTENT"
    [ "$status" -eq 0 ]
}

# Regression: round-1 fix used r'https?://[^)> "]+', which does not exclude
# newline, tab, or backtick. A bare URL as the last token on a line matched
# through the newline and swallowed the next line's real violation --
# a false negative worse than the false positive being fixed. Found
# independently by three reviewers via three different trigger shapes
# (line-end URL, tab-adjacent, backtick-adjacent) during code review.

@test "buzzword on the line immediately after a bare URL still blocks, with the correct line number" {
    printf 'See https://example.com/status\nThis will unlock huge value.\nline three is clean\n' > "$CONTENT"
    run_check --content "$CONTENT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"BUZZWORD"* ]]
    [[ "$output" == *"2:This will unlock"* ]]
}

@test "buzzword immediately after a URL joined by a tab (no space) still blocks" {
    printf 'See http://foo.com/x\tunlock the potential of your team.\n' > "$CONTENT"
    run_check --content "$CONTENT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"BUZZWORD"* ]]
}

@test "buzzword immediately after a backtick-closed URL with no space still blocks" {
    printf 'See `http://example.com/status`unlock this now.\n' > "$CONTENT"
    run_check --content "$CONTENT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"BUZZWORD"* ]]
}

@test "a redacted URL does not change the line count of the scanned content" {
    printf 'line one is clean\nsee https://example.com/status here\nline three is clean\n' > "$CONTENT"
    run_check --content "$CONTENT" --mode summary
    [ "$status" -eq 0 ]
}

# ── Existing pattern classes still block (no regression) ───────────────────

@test "em-dash still blocks" {
    printf 'This is a test \xe2\x80\x94 with an em dash.\n' > "$CONTENT"
    run_check --content "$CONTENT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"EM_DASH"* ]]
}

@test "booster still blocks" {
    printf 'This change is remarkably fast.\n' > "$CONTENT"
    run_check --content "$CONTENT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"BOOSTER"* ]]
}

@test "filler still blocks" {
    printf 'In conclusion, ship it.\n' > "$CONTENT"
    run_check --content "$CONTENT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"FILLER"* ]]
}

@test "weak intensifier is advisory only, does not block" {
    printf 'This is very fast.\n' > "$CONTENT"
    run_check --content "$CONTENT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"INTENSIFIER"* ]]
}

@test "advisory buzzword does not block" {
    printf 'This will enhance throughput.\n' > "$CONTENT"
    run_check --content "$CONTENT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"BUZZWORD"* ]]
}

# ── Dictionary hardening: new terms, advisory tier, one hit per phrase ─────

# Every blocking term added in this pass, as LABEL|term. The test writes one
# term per line so a term that fails to block shows up as its own missing
# line number instead of hiding behind another term's hit.
NEW_BLOCKING_TERMS=(
    'BUZZWORD|load-bearing' 'BUZZWORD|load bearing' 'BUZZWORD|testament to'
    'BUZZWORD|stands as a' 'BUZZWORD|serves as a'
    'BUZZWORD|commitment to excellence' 'BUZZWORD|diverse array of'
    'BUZZWORD|valuable insights' 'BUZZWORD|a wealth of'
    'BUZZWORD|a treasure trove of' 'BUZZWORD|future outlook'
    'BUZZWORD|future prospects'
    'FILLER|shed light on' 'FILLER|sheds light on'
    'FILLER|despite these challenges' 'FILLER|let me be clear'
    'FILLER|look no further' 'FILLER|without further ado'
    'FILLER|sets the stage for' 'FILLER|paves the way for'
)

@test "--list-patterns prints the catalog as tier, label, pattern without --content" {
    run_check --list-patterns
    [ "$status" -eq 0 ]
    [[ "$output" == *$'block\tBUZZWORD\ttestament to'* ]]
    [[ "$output" == *$'warn\tBUZZWORD\tinterplay'* ]]
    [[ "$output" == *$'warn\tFILLER\tat the heart of'* ]]
}

@test "each newly added blocking term blocks under its own label, once" {
    local entry i=0
    : > "$CONTENT"
    for entry in "${NEW_BLOCKING_TERMS[@]}"; do
        printf 'Note %s here.\n' "${entry#*|}" >> "$CONTENT"
    done
    run_check --content "$CONTENT"
    [ "$status" -eq 1 ]
    for entry in "${NEW_BLOCKING_TERMS[@]}"; do
        i=$((i + 1))
        if [[ "$output" != *"BLOCK  ${entry%%|*}: ${i}:"* ]]; then
            echo "line ${i} ('${entry#*|}') did not block as ${entry%%|*}" >&2
            return 1
        fi
    done
    [[ "$output" == *"${#NEW_BLOCKING_TERMS[@]} blocking violation(s)"* ]]
}

# These terms reproduced blocking ordinary engineering prose with no other
# AI tell present, so they sit in the advisory tier: reported, never fatal.
# `vibrant` is advisory here because its exemption (a literal color, theme,
# or image asset) needs context a line-level grep cannot see.
@test "advisory-tier terms warn but do not block legitimate engineering prose" {
    cat > "$CONTENT" <<'EOF'
The interplay between the connection pool and the retry queue caused the leak.
We meticulously verified each state transition.
The meticulous replay of the write-ahead log showed two lost writes.
The locking rules are intricate because two writers share one index.
The intricacies of the TLS handshake broke the proxy.
At the heart of the scheduler is a min-heap keyed by deadline.
The dashboard uses a vibrant red for failed jobs.
EOF
    run_check --content "$CONTENT"
    [ "$status" -eq 0 ]
    local i
    for i in 1 2 3 4 5 6 7; do
        [[ "$output" == *"WARN   "*": ${i}:"* ]] || { echo "line ${i} raised no warning" >&2; return 1; }
    done
}

@test "'it turns out' is not in the catalog: root-cause prose stays clean" {
    printf 'It turns out the bug was a race condition in the cache warmer.\n' > "$CONTENT"
    run_check --content "$CONTENT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"clean (0 advisory warning(s))"* ]]
}

# One occurrence, one violation. Each pattern is scanned on its own, so a
# pattern that contains another listed pattern reported the same phrase
# twice. The first four phrases below each produced two violations before
# the redundant longer pattern was removed.
@test "a phrase matched by nested patterns produces exactly one violation" {
    local phrase count
    for phrase in "It's worth noting that retries are capped." \
                  "In the modern era, we deploy daily." \
                  "This will unlock the potential of the cache." \
                  "The index plays a crucial role in lookups." \
                  "This is a testament to careful engineering."; do
        printf '%s\n' "$phrase" > "$CONTENT"
        run_check --content "$CONTENT"
        [ "$status" -eq 1 ]
        count="$(printf '%s\n' "$output" | grep -c 'BLOCK  ')" || true
        [ "$count" -eq 1 ] || { echo "'${phrase}' produced ${count} violations" >&2; return 1; }
    done
}

# Catalog-wide guard for the same rule, so a future addition that nests
# inside (or contains) an existing pattern fails here instead of shipping.
# Every pattern goes on its own line; each blocking line must be hit exactly
# once and each advisory line never.
@test "catalog-wide: each pattern alone on a line blocks exactly once, or never if advisory" {
    local catalog="$TMPDIR_LOCAL/catalog.tsv" counts="$TMPDIR_LOCAL/counts"
    bash "$TOOL" --list-patterns > "$catalog"
    [ -s "$catalog" ]
    cut -f3 "$catalog" > "$CONTENT"
    run_check --content "$CONTENT"
    printf '%s\n' "$output" \
        | sed -n 's/^\[slop-check\] BLOCK  [A-Z_]*: \([0-9][0-9]*\):.*/\1/p' \
        | sort -n | uniq -c > "$counts"
    local n=0 bad=0 tier label pat hits
    while IFS=$'\t' read -r tier label pat; do
        n=$((n + 1))
        hits="$(awk -v n="$n" '$2 == n { print $1 }' "$counts")"
        hits="${hits:-0}"
        if { [[ "$tier" == block ]] && [[ "$hits" -ne 1 ]]; } ||
           { [[ "$tier" == warn ]] && [[ "$hits" -ne 0 ]]; }; then
            echo "line ${n} (${tier} ${label} '${pat}'): ${hits} blocking hit(s)" >&2
            bad=1
        fi
    done < "$catalog"
    [ "$bad" -eq 0 ]
}

@test "clean content passes with no output beyond the summary line" {
    printf 'Fixed a null pointer in the retry loop.\n' > "$CONTENT"
    run_check --content "$CONTENT" --mode summary
    [ "$status" -eq 0 ]
    [[ "$output" == *"clean"* ]]
}

@test "silent mode produces no output on block" {
    printf 'This will unlock huge value.\n' > "$CONTENT"
    run_check --content "$CONTENT" --mode silent
    [ "$status" -eq 1 ]
    [ -z "$output" ]
}

@test "json format emits parseable block entries" {
    command -v jq >/dev/null 2>&1 || skip "jq not installed"
    printf 'This will unlock huge value.\n' > "$CONTENT"
    run_check --content "$CONTENT" --format json
    [ "$status" -eq 1 ]
    echo "$output" | grep '^{' | while IFS= read -r line; do
        echo "$line" | jq -e '.label' >/dev/null
    done
}

# The redaction regex ends a URL at whitespace, ), >, " or a backtick, so a ']'
# is captured as part of the URL. That is correct for bracket-notation API paths
# (e.g. /items[0]), but it means a ']' cannot terminate the redaction either --
# so prose following a bracket-containing URL must still be scanned. Verified by
# hand during review; committed here so nothing but a test protects it.
@test "buzzword after a bracket-containing URL inside a markdown link still blocks" {
    printf 'See [docs](https://example.com/items[0]) leverage synergies going forward.\n' > "$CONTENT"
    run_check --content "$CONTENT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"BUZZWORD"* ]]
}

@test "buzzword after a bracket-terminated bare URL still blocks" {
    printf 'Plain https://example.com/a] leverage synergies going forward.\n' > "$CONTENT"
    run_check --content "$CONTENT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"BUZZWORD"* ]]
}

# Regression coverage for a code-review-battery Defect Finder finding:
# `trap CMD EXIT` REPLACES the previous EXIT handler rather than appending to
# it. The EMOJI check's own trap (the last one registered, active through
# script exit) named only $_PY_TMP and $_EMOJI_TMP, silently dropping
# $SCAN_FILE -- the URL-redacted scan copy -- from cleanup on every single
# invocation, leaking a copy of the (redacted) content into /tmp on every
# run. Diffs the directory listing before/after a clean run and asserts no
# new slop-check-* temp file survives, rather than trusting the trap exists.
@test "no slop-check-* temp file survives a clean run (trap EXIT cleanup)" {
    # A before/after /tmp directory diff is racy under bats' parallel
    # (--jobs N) execution: other test FILES invoke slop-check.sh
    # concurrently (e.g. wiki-content-check.bats via delegation), creating
    # their own /tmp/slop-check-scan.* files inside this test's snapshot
    # window and producing a false failure that has nothing to do with this
    # script's own cleanup. slop-check.sh hardcodes /tmp/slop-check-*.XXXXXX
    # (does not respect $TMPDIR), so there is no way to isolate this
    # empirically. Check the actual invariant statically instead: the last
    # EXIT trap registered in the script (the one active through normal
    # exit -- traps replace, not stack) must name all three temp files.
    local last_trap
    last_trap="$(grep "trap 'rm -f" "$TOOL" | tail -1)"
    [[ "$last_trap" == *'$SCAN_FILE'* ]]
    [[ "$last_trap" == *'$_PY_TMP'* ]]
    [[ "$last_trap" == *'$_EMOJI_TMP'* ]]
}

# Regression coverage for a code-review-battery Defect Finder finding: the
# EMOJI check's python3-failure branch correctly increments SKIPPED (so a
# crash there can't silently report "clean"), but the structurally identical
# EM_DASH failure branch -- the highest-signal BLOCKING category -- did not,
# so a python3 crash isolated to just the em-dash sub-invocation could still
# exit 0. A python3 stub that fails on exactly its second invocation (the
# em-dash call; the first, URL-redaction, must succeed or the script would
# already hard-exit 2 before reaching em-dash at all) forces this path.
@test "em-dash-only python3 failure exits 2 (skipped), not 0 (false clean)" {
    local real_python3
    real_python3="$(command -v python3)"
    local fake_bin="$TMPDIR_LOCAL/fake_bin"
    mkdir -p "$fake_bin"
    local counter="$TMPDIR_LOCAL/py_call_count"
    echo 0 > "$counter"
    # Passthrough must call the REAL python3's resolved absolute path, not
    # `env python3` -- with fake_bin prepended to PATH, an `env` lookup from
    # inside this stub resolves back to this same stub, recursing into
    # itself and hitting n==2 on the very first (URL-redaction) call instead
    # of the intended second (em-dash) call.
    cat > "$fake_bin/python3" <<EOF
#!/bin/sh
n=\$(cat "$counter")
n=\$((n + 1))
echo "\$n" > "$counter"
if [ "\$n" -eq 2 ]; then
    exit 42
fi
exec "$real_python3" "\$@"
EOF
    chmod +x "$fake_bin/python3"
    printf 'clean content, no violations here.\n' > "$CONTENT"
    run env PATH="$fake_bin:$PATH" bash "$TOOL" --content "$CONTENT"
    [ "$status" -eq 2 ]
    [[ "$output" == *"EM_DASH"* ]]
}

# Regression coverage for a code-review-battery ShellRuntimeAuditor finding:
# every pattern-match loop used `grep ... || true`, which maps "no match"
# (grep exit 1, benign) and a genuine grep failure (exit >=2: bad regex, I/O
# error, OOM) to the identical empty result -- a real scan failure silently
# reported as clean. A real grep binary cannot be made to fail on demand for
# a well-formed pattern against a readable file, so this stubs grep itself
# (via a fake_bin with every other tool symlinked through) to always exit 2,
# on content containing an unambiguous blocking BUZZWORD ("unlock" -- see
# the "same buzzword in real prose...still blocks" test above for the normal
# exit-1 case this must NOT collapse into exit 0.
@test "a broken grep (real failure, not no-match) exits 2, not a false clean" {
    local fake_bin="$TMPDIR_LOCAL/fake_bin_grep"
    mkdir -p "$fake_bin"
    for t in dirname printf tr wc cat sed basename mktemp sort python3 rm; do
        local real_path
        real_path="$(command -v "$t")"
        ln -s "$real_path" "$fake_bin/$t"
    done
    printf '#!/bin/sh\nexit 2\n' > "$fake_bin/grep"
    chmod +x "$fake_bin/grep"
    printf 'This will unlock huge value for the team.\n' > "$CONTENT"
    run env PATH="$fake_bin:$PATH" bash "$TOOL" --content "$CONTENT" --mode silent
    [ "$status" -eq 2 ]
}

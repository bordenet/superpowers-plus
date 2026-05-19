#!/usr/bin/env bats

# Behavioral tests for tools/commit-msg hook.
# Covers: file-not-found guard, ASCII pass-through, auto-conversion,
# rejection of non-convertible non-ASCII, and hook file integrity.

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
HOOK="$REPO_ROOT/tools/commit-msg"

setup() {
    MSG="$BATS_TEST_TMPDIR/COMMIT_EDITMSG"
}

# ---------------------------------------------------------------------------
# Guard cases
# ---------------------------------------------------------------------------

@test "commit-msg: exits 0 when file does not exist" {
    run bash "$HOOK" "$BATS_TEST_TMPDIR/nonexistent"
    [ "$status" -eq 0 ]
}

@test "commit-msg: exits 0 for an ASCII-only message" {
    printf 'fix: correct off-by-one in loop\n' > "$MSG"
    run bash "$HOOK" "$MSG"
    [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Auto-conversion: hook modifies file in place and exits 0
# ---------------------------------------------------------------------------

@test "commit-msg: converts em dash to hyphen and exits 0" {
    printf 'feat: add feature \xe2\x80\x94 closes #42\n' > "$MSG"
    run bash "$HOOK" "$MSG"
    [ "$status" -eq 0 ]
    grep -qF -- '- closes' "$MSG"   # exact substitution: em dash → hyphen
    run python3 -c "import sys; s=open(sys.argv[1]).read(); sys.exit(0 if all(ord(c)<128 for c in s) else 1)" "$MSG"
    [ "$status" -eq 0 ]
}

@test "commit-msg: converts en dash to hyphen and exits 0" {
    printf 'feat: range 1\xe2\x80\x932 supported\n' > "$MSG"
    run bash "$HOOK" "$MSG"
    [ "$status" -eq 0 ]
    grep -qF '1-2' "$MSG"        # exact substitution: en dash → hyphen
    run python3 -c "import sys; s=open(sys.argv[1]).read(); sys.exit(0 if all(ord(c)<128 for c in s) else 1)" "$MSG"
    [ "$status" -eq 0 ]
}

@test "commit-msg: converts smart double quotes to ASCII and exits 0" {
    # left and right double quotes (U+201C / U+201D)
    printf 'docs: use \xe2\x80\x9csmart\xe2\x80\x9d quotes\n' > "$MSG"
    run bash "$HOOK" "$MSG"
    [ "$status" -eq 0 ]
    grep -qF '"smart"' "$MSG"    # exact substitution: curly quotes → straight quotes
    run python3 -c "import sys; s=open(sys.argv[1]).read(); sys.exit(0 if all(ord(c)<128 for c in s) else 1)" "$MSG"
    [ "$status" -eq 0 ]
}

@test "commit-msg: converts right arrow to ASCII and exits 0" {
    printf 'refactor: A \xe2\x86\x92 B migration\n' > "$MSG"
    run bash "$HOOK" "$MSG"
    [ "$status" -eq 0 ]
    grep -qF 'A -> B' "$MSG"     # exact substitution: → → ->
    run python3 -c "import sys; s=open(sys.argv[1]).read(); sys.exit(0 if all(ord(c)<128 for c in s) else 1)" "$MSG"
    [ "$status" -eq 0 ]
}

@test "commit-msg: converts bullet to hyphen and exits 0" {
    printf 'chore: \xe2\x80\xa2 item one\n' > "$MSG"
    run bash "$HOOK" "$MSG"
    [ "$status" -eq 0 ]
    grep -qF -- '- item one' "$MSG"  # exact substitution: bullet → hyphen
    run python3 -c "import sys; s=open(sys.argv[1]).read(); sys.exit(0 if all(ord(c)<128 for c in s) else 1)" "$MSG"
    [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Rejection: non-convertible non-ASCII exits non-zero with diagnostic
# ---------------------------------------------------------------------------

@test "commit-msg: rejects non-convertible non-ASCII (e-acute U+00E9)" {
    # U+00E9 = 0xC3 0xA9 in UTF-8; not in SUBSTITUTIONS table
    printf 'fix: caf\xc3\xa9 endpoint\n' > "$MSG"
    run bash "$HOOK" "$MSG"
    [ "$status" -ne 0 ]
}

@test "commit-msg: rejects mixed convertible+non-convertible on same line" {
    # em dash (convertible) + é (non-convertible) on the same line
    # Verifies the hook converts what it can, then correctly rejects the remainder
    printf 'feat: add feature \xe2\x80\x94 caf\xc3\xa9 integration\n' > "$MSG"
    run bash "$HOOK" "$MSG"
    [ "$status" -ne 0 ]
    [[ "$output" == *"non-ASCII"* ]]
    # em dash should have been converted — file now has hyphen where dash was
    grep -qF -- '- caf' "$MSG"
}

@test "commit-msg: rejects non-UTF-8 binary content with UTF-8 error" {
    # 0xFF 0xFE is a UTF-16 BOM — invalid UTF-8
    printf 'fix: bad \xff\xfe encoding\n' > "$MSG"
    run bash "$HOOK" "$MSG"
    [ "$status" -ne 0 ]
    [[ "$output" == *"UTF-8"* ]]
}

@test "commit-msg: rejection output contains 'non-ASCII'" {
    printf 'fix: caf\xc3\xa9 endpoint\n' > "$MSG"
    run bash "$HOOK" "$MSG"
    [ "$status" -ne 0 ]
    [[ "$output" == *"non-ASCII"* ]]  # BATS 1.x run merges stderr into $output by default
}

@test "commit-msg: rejection output contains offending line number" {
    printf 'fix: caf\xc3\xa9 endpoint\n' > "$MSG"
    run bash "$HOOK" "$MSG"
    [ "$status" -ne 0 ]
    [[ "$output" == *"Line 1"* ]]
}

@test "commit-msg: rejection output contains correct line number for non-ASCII on line 2" {
    printf 'clean first line\nfix: caf\xc3\xa9 endpoint\n' > "$MSG"
    run bash "$HOOK" "$MSG"
    [ "$status" -ne 0 ]
    [[ "$output" == *"Line 2"* ]]
}

# ---------------------------------------------------------------------------
# Hook file integrity
# ---------------------------------------------------------------------------

@test "commit-msg hook file exists" {
    [ -f "$HOOK" ]
}

@test "commit-msg hook is executable" {
    [ -x "$HOOK" ]
}

@test "commit-msg hook has bash shebang" {
    head -1 "$HOOK" | grep -q "^#!/usr/bin/env bash"
}

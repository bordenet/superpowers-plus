#!/usr/bin/env bats
# _install_patterns must never leave a template pattern missing from the
# installed file. These files are "block if ANY pattern matches" lists, so a
# stale installed copy silently unguards whatever the template added since --
# a fail-open on a security control, not a preserved preference.
#
# Regression: an installed red-autonomy-patterns.txt predating the
# global-option hardening left `git -C <dir> push`, `git -c k=v push`,
# `git --git-dir=... push`, `git branch -f -D`, `git branch --delete`, and
# `git branch -d` completely unclassified. The installer saw "differs from
# template", warned, and kept the vulnerable file.

REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
INSTALLER="$REPO_ROOT/setup/install-claude-guardrails.sh"
TEMPLATE="$REPO_ROOT/claude-config/red-autonomy-patterns.txt"

setup() {
    FAKE_HOME="$(mktemp -d)"
    DEST_DIR="$FAKE_HOME/.config/claude-hooks"
    DEST="$DEST_DIR/red-autonomy-patterns.txt"
    mkdir -p "$DEST_DIR" "$FAKE_HOME/.claude"
}

teardown() {
    [ -n "${FAKE_HOME:-}" ] && rm -rf "$FAKE_HOME"
}

run_installer() {
    HOME="$FAKE_HOME" SUPERPOWERS_CLAUDE_GUARDRAILS=1 \
        run bash "$INSTALLER"
}

# Active (non-comment, non-blank) lines only -- comment drift is not a gap.
active() { grep -vE '^[[:space:]]*#|^[[:space:]]*$' "$1" || true; }

# Every template pattern must be present in the installed file.
assert_no_missing_patterns() {
    local missing=0 line
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        grep -qxF "$line" "$DEST" || { echo "MISSING: $line"; missing=1; }
    done < <(active "$TEMPLATE")
    [ "$missing" -eq 0 ]
}

@test "install-patterns: absent destination gets the template verbatim" {
    rm -f "$DEST"
    run_installer
    [ "$status" -eq 0 ]
    [ -f "$DEST" ]
    assert_no_missing_patterns
}

@test "install-patterns: identical destination is left byte-identical (idempotent)" {
    cp "$TEMPLATE" "$DEST"
    local before
    before="$(shasum < "$DEST")"
    run_installer
    [ "$status" -eq 0 ]
    [ "$(shasum < "$DEST")" = "$before" ]
}

@test "install-patterns: stale destination gains every missing template pattern" {
    # A pre-hardening file: only the weak, un-anchored forms.
    cat > "$DEST" <<'STALE'
# stale copy predating global-option hardening
(^|[^A-Za-z0-9_])git[[:space:]]+push([[:space:]]|$)
STALE
    run_installer
    [ "$status" -eq 0 ]
    assert_no_missing_patterns
}

@test "install-patterns: user-added custom patterns survive the merge" {
    cp "$TEMPLATE" "$DEST"
    echo '(^|[^A-Za-z0-9_])my-custom-dangerous-command([[:space:]]|$)' >> "$DEST"
    run_installer
    [ "$status" -eq 0 ]
    grep -qF 'my-custom-dangerous-command' "$DEST"
    assert_no_missing_patterns
}

@test "install-patterns: stale file keeps its custom lines AND gains template patterns" {
    cat > "$DEST" <<'MIXED'
(^|[^A-Za-z0-9_])git[[:space:]]+push([[:space:]]|$)
(^|[^A-Za-z0-9_])my-custom-dangerous-command([[:space:]]|$)
MIXED
    run_installer
    [ "$status" -eq 0 ]
    grep -qF 'my-custom-dangerous-command' "$DEST"
    assert_no_missing_patterns
}

@test "install-patterns: a modified file is backed up before being rewritten" {
    cat > "$DEST" <<'STALE'
(^|[^A-Za-z0-9_])git[[:space:]]+push([[:space:]]|$)
STALE
    run_installer
    [ "$status" -eq 0 ]
    # exactly one backup, and it holds the ORIGINAL content
    local bak
    bak="$(find "$DEST_DIR" -maxdepth 1 -name 'red-autonomy-patterns.txt.bak-*' | head -1)"
    [ -n "$bak" ]
    grep -qF 'git[[:space:]]+push([[:space:]]|$)' "$bak"
    [ "$(active "$bak" | wc -l | tr -d ' ')" -eq 1 ]
}

@test "install-patterns: comment-only drift does not rewrite the file" {
    # Same active patterns, different comments -- nothing is missing, so the
    # installer must not churn the file or spawn a backup.
    { echo "# a locally reworded header comment"; active "$TEMPLATE"; } > "$DEST"
    local before
    before="$(shasum < "$DEST")"
    run_installer
    [ "$status" -eq 0 ]
    [ "$(shasum < "$DEST")" = "$before" ]
    [ -z "$(find "$DEST_DIR" -maxdepth 1 -name 'red-autonomy-patterns.txt.bak-*')" ]
}

@test "install-patterns: the six historically-bypassable forms are classified after merge" {
    cat > "$DEST" <<'STALE'
(^|[^A-Za-z0-9_])git[[:space:]]+push([[:space:]]|$)
(^|[^A-Za-z0-9_])git[[:space:]]+branch[[:space:]]+-D
STALE
    run_installer
    [ "$status" -eq 0 ]
    # Assemble at runtime so no literal RED command appears in this file.
    local g="git" p="pu""sh" b="bra""nch" cmd hit
    for cmd in "$g -C /tmp $p origin main" \
               "$g -c k=v $p origin main" \
               "$g --git-dir=/x $p origin main" \
               "$g --work-tree=/x $p origin main" \
               "$g $b -f -D feature" \
               "$g $b --delete feature"; do
        hit=0
        while IFS= read -r re; do
            [ -z "$re" ] && continue
            if printf '%s' "$cmd" | grep -qE "$re"; then hit=1; break; fi
        done < <(active "$DEST")
        [ "$hit" -eq 1 ] || { echo "UNCLASSIFIED after merge: $cmd"; return 1; }
    done
}

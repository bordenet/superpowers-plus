#!/usr/bin/env bats
# Tests for tools/try-sentinel-fast-forward.sh.
#
# A first design of this mechanism (path-allowlist only, no content
# verification) was REJECTed by progressive-harsh-review for a
# sentinel-format-breaking bug and a regression-laundering risk. These
# tests cover the fixed design: same 5-field sentinel format (no new
# field), byte-for-byte regeneration proof before trusting any fast-forward,
# and an explicit ancestor check.
#
# Each test builds an isolated git repo (not this real repo) with a FAKE
# generator registered via FASTFORWARD_REGISTRY, so these tests never touch
# this repo's real generators (test/compress.test.js, etc.) or its real
# sentinels.

SCRIPT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)/tools/try-sentinel-fast-forward.sh"

setup() {
    WORK="$(mktemp -d)"
    cd "$WORK"
    git init -q --initial-branch=main
    git config user.email "test@test"
    git config user.name "Test"

    mkdir -p fixture source tools/lib .cr-battery-runs
    # Mirror the real repo's .gitignore for these paths -- the sentinel files
    # and the test-registry scaffolding are not fixture content under test,
    # and without this the "working tree must be clean" precondition check
    # sees them as untracked and refuses every test with a false positive.
    cat > .gitignore <<'EOF'
.code-review-cleared
.phr-cleared
.cr-battery-runs/
tools/lib/test-registry.sh
EOF

    # Fake generator: deterministically writes fixture/content.txt (the
    # REGISTERED output) from source/truth.txt (a deliberately UNREGISTERED
    # input, mirroring how the real test/compress.test.js reads skill files
    # from skills/ -- never itself under the registered test/golden-compression/
    # output directory it writes to; see that script's readFileSync/
    # writeFileSync split). Committed with content.txt deliberately STALE
    # (not what the generator produces) so advance_fixture_correctly() has a
    # real byte-level change to make without ever touching the unregistered
    # input -- exactly the "only the derived fixture changed since the
    # sentinel" shape a real fast-forward-eligible diff has.
    cat > fake-generator.sh <<'EOF'
#!/usr/bin/env bash
cp source/truth.txt fixture/content.txt
EOF
    chmod +x fake-generator.sh
    echo "truth-v1" > source/truth.txt
    echo "stale-placeholder" > fixture/content.txt
    git add .
    git commit -q -m "base: generator + stale content"
    BASE_SHA="$(git rev-parse HEAD)"

    cat > tools/lib/test-registry.sh <<EOF
declare -A FASTFORWARD_GENERATORS=(
    ["fixture/"]="bash $WORK/fake-generator.sh"
)
EOF
    export FASTFORWARD_REGISTRY="$WORK/tools/lib/test-registry.sh"
}

teardown() {
    rm -rf "$WORK"
}

write_sentinel() {
    # $1 = sentinel path, $2 = sha, $3 = fields-after-sha (verdict|ts|min)
    printf 'v1|%s|%s\n' "$2" "$3" > "$1"
}

# Advance HEAD with a commit that regenerates content.txt from the
# UNCHANGED source/truth.txt input -- the "someone ran the real generator
# and committed its correct output, with no source change needing separate
# review" scenario the safe fast-forward path exists to skip re-reviewing.
advance_fixture_correctly() {
    bash fake-generator.sh
    git add fixture/content.txt
    git commit -q -m "fixture: regenerated correctly"
}

@test "already valid for HEAD: no-op, exit 0" {
    write_sentinel .code-review-cleared "$(git rev-parse HEAD)" "PASS|2026-01-01T00:00:00Z|min-score=9.2"
    run bash "$SCRIPT" --code-review
    [ "$status" -eq 0 ]
    [[ "$output" == *"already valid for HEAD"* ]]
}

@test "dirty working tree: refuses before touching anything" {
    write_sentinel .code-review-cleared "$BASE_SHA" "PASS|2026-01-01T00:00:00Z|min-score=9.2"
    echo "dirty" >> fixture/content.txt
    run bash "$SCRIPT" --code-review
    [ "$status" -eq 2 ]
    [[ "$output" == *"working tree is not clean"* ]]
}

@test "sentinel SHA not an ancestor of HEAD: refuses" {
    write_sentinel .code-review-cleared "0000000000000000000000000000000000000000" "PASS|2026-01-01T00:00:00Z|min-score=9.2"
    run bash "$SCRIPT" --code-review
    [ "$status" -eq 1 ]
    [[ "$output" == *"not an ancestor"* ]]
}

@test "changed file not covered by registry: refuses, does not run any generator" {
    write_sentinel .code-review-cleared "$BASE_SHA" "PASS|2026-01-01T00:00:00Z|min-score=9.2"
    echo "unrelated" > unrelated.txt
    git add unrelated.txt
    git commit -q -m "unrelated change"
    run bash "$SCRIPT" --code-review
    [ "$status" -eq 1 ]
    [[ "$output" == *"NOT covered by any registered generator"* ]]
}

@test "committed content matches regenerated output: fast-forwards, same field count preserved" {
    write_sentinel .code-review-cleared "$BASE_SHA" "PASS|2026-01-01T00:00:00Z|min-score=9.2"
    advance_fixture_correctly
    run bash "$SCRIPT" --code-review
    [ "$status" -eq 0 ]
    [[ "$output" == *"proven byte-for-byte reproducible by their registered generator"* ]]
    NEW_LINE="$(head -n1 .code-review-cleared)"
    FIELD_COUNT="$(awk -F'|' '{print NF}' <<< "$NEW_LINE")"
    [ "$FIELD_COUNT" -eq 5 ]
    [[ "$NEW_LINE" == "v1|$(git rev-parse HEAD)|PASS|"*"|min-score=9.2" ]]
}

@test "committed content does NOT match regenerated output: refuses, restores working tree" {
    write_sentinel .code-review-cleared "$BASE_SHA" "PASS|2026-01-01T00:00:00Z|min-score=9.2"
    # Hand-edit content.txt to diverge from what the generator would produce,
    # simulating the exact regression-laundering scenario this design
    # prevents: a file matching the registry's path but NOT provably equal
    # to the generator's real output.
    echo "hand-edited, not what the generator produces" > fixture/content.txt
    git add fixture/content.txt
    git commit -q -m "hand-edited content (simulated regression)"
    run bash "$SCRIPT" --code-review
    [ "$status" -eq 1 ]
    [[ "$output" == *"regenerated content differs from what's committed"* ]]
    # Working tree must be restored (not left dirty from the failed generator run).
    [ -z "$(git status --porcelain)" ]
}

@test "file matches a directory-prefix generator that doesn't actually write it: refuses (per-file provenance)" {
    # Regression test for the CRITICAL finding: a whole-tree "git status is
    # clean after running the generator" check cannot tell "the generator
    # produced this" from "the generator never touched this, so it's still
    # sitting at its previously-committed bytes." fake-generator.sh only
    # ever writes fixture/content.txt -- fixture/orphan.txt is under the same
    # registered "fixture/" prefix but the generator has no idea it exists
    # (mirrors a real generator's hardcoded internal file list omitting a
    # newly-added file). Deleting it and requiring the generator to recreate
    # it is what catches this; a prior design that only checked overall tree
    # cleanliness after running generators could not.
    write_sentinel .code-review-cleared "$BASE_SHA" "PASS|2026-01-01T00:00:00Z|min-score=9.2"
    echo "not reproducible by fake-generator.sh" > fixture/orphan.txt
    git add fixture/orphan.txt
    git commit -q -m "add a file the registered generator doesn't cover"
    run bash "$SCRIPT" --code-review
    [ "$status" -eq 1 ]
    [[ "$output" == *"did NOT recreate this file"* ]]
    # Working tree must be fully restored, including the deleted-then-not-
    # recreated file.
    [ -z "$(git status --porcelain)" ]
    [ -f fixture/orphan.txt ]
}

@test "generator leaves an untracked byproduct on failure: cleaned up, not left behind" {
    # Regression test for the Important finding: `git checkout -- .` only
    # restores TRACKED file modifications; it does nothing for untracked
    # files a generator creates as a side effect. Point the registry at a
    # generator that both regenerates content.txt correctly AND drops an
    # untracked byproduct file, then force a failure via a mismatched
    # unrelated file so restore_tree() runs, and verify the byproduct is gone.
    cat > byproduct-generator.sh <<EOF
#!/usr/bin/env bash
cp source/truth.txt fixture/content.txt
echo "leftover" > fixture/byproduct.txt
EOF
    chmod +x byproduct-generator.sh
    cat > tools/lib/test-registry.sh <<EOF
declare -A FASTFORWARD_GENERATORS=(
    ["fixture/content.txt"]="bash $WORK/byproduct-generator.sh"
)
EOF
    # Commit the generator script itself as its own base point, and point the
    # sentinel there -- not at $BASE_SHA. Otherwise byproduct-generator.sh
    # would itself show up as an unregistered "changed file" in the
    # sen_sha..HEAD diff below and the script would refuse at the coverage
    # check before ever reaching the scenario this test targets.
    git add byproduct-generator.sh
    git commit -q -m "add byproduct generator"
    GEN_BASE_SHA="$(git rev-parse HEAD)"
    write_sentinel .code-review-cleared "$GEN_BASE_SHA" "PASS|2026-01-01T00:00:00Z|min-score=9.2"
    # Hand-edit content.txt so the per-file provenance check fails deterministically.
    echo "hand-edited, diverges from generator output" > fixture/content.txt
    git add fixture/content.txt
    git commit -q -m "hand-edited (forces failure so restore_tree runs)"
    run bash "$SCRIPT" --code-review
    [ "$status" -eq 1 ]
    [ -z "$(git status --porcelain)" ]
    [ ! -f fixture/byproduct.txt ]
}

@test "exact-file registry entry does not prefix-match a same-named sibling file" {
    # Regression test for the Minor finding: an exact-file registry key
    # (no trailing "/") must require a full match, not `[[ "$f" == "$prefix"* ]]`,
    # which would let "fixture/content.txt.bak" wrongly match a registry
    # entry for "fixture/content.txt".
    cat > tools/lib/test-registry.sh <<EOF
declare -A FASTFORWARD_GENERATORS=(
    ["fixture/content.txt"]="bash $WORK/fake-generator.sh"
)
EOF
    write_sentinel .code-review-cleared "$BASE_SHA" "PASS|2026-01-01T00:00:00Z|min-score=9.2"
    echo "sibling file, same prefix, not registered" > fixture/content.txt.bak
    git add fixture/content.txt.bak
    git commit -q -m "add unregistered sibling file"
    run bash "$SCRIPT" --code-review
    [ "$status" -eq 1 ]
    [[ "$output" == *"NOT covered by any registered generator"* ]]
}

@test "4-field sentinel (no min-score) preserves 4-field shape after fast-forward" {
    printf 'v1|%s|PASS|2026-01-01T00:00:00Z\n' "$BASE_SHA" > .code-review-cleared
    advance_fixture_correctly
    run bash "$SCRIPT" --code-review
    [ "$status" -eq 0 ]
    NEW_LINE="$(head -n1 .code-review-cleared)"
    FIELD_COUNT="$(awk -F'|' '{print NF}' <<< "$NEW_LINE")"
    [ "$FIELD_COUNT" -eq 4 ]
}

@test "--phr targets .phr-cleared independently of .code-review-cleared" {
    write_sentinel .phr-cleared "$BASE_SHA" "PASS|2026-01-01T00:00:00Z|min-score=9.5"
    advance_fixture_correctly
    run bash "$SCRIPT" --phr
    [ "$status" -eq 0 ]
    NEW_LINE="$(head -n1 .phr-cleared)"
    [[ "$NEW_LINE" == "v1|$(git rev-parse HEAD)|PASS|"*"|min-score=9.5" ]]
}

@test "fast-forward event is logged to .cr-battery-runs/fast-forward.log" {
    write_sentinel .code-review-cleared "$BASE_SHA" "PASS|2026-01-01T00:00:00Z|min-score=9.2"
    advance_fixture_correctly
    run bash "$SCRIPT" --code-review
    [ "$status" -eq 0 ]
    [ -f .cr-battery-runs/fast-forward.log ]
    grep -q "$BASE_SHA" .cr-battery-runs/fast-forward.log
    grep -q "$(git rev-parse HEAD)" .cr-battery-runs/fast-forward.log
}

@test "missing sentinel file: usage error, exit 2" {
    run bash "$SCRIPT" --code-review
    [ "$status" -eq 2 ]
    [[ "$output" == *"nothing to fast-forward"* ]]
}

@test "no args: usage error, exit 2" {
    run bash "$SCRIPT"
    [ "$status" -eq 2 ]
    [[ "$output" == *"Usage:"* ]]
}

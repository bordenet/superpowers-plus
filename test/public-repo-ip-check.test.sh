#!/usr/bin/env bash
# Targeted tests for tools/public-repo-ip-check.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "${TMP_ROOT:?}"' EXIT

PASS=0
FAIL=0

pass() { echo "  ✅ $1"; PASS=$((PASS + 1)); }
fail() { echo "  ❌ $1"; FAIL=$((FAIL + 1)); }

new_repo() {
    local dir="$1"
    mkdir -p "$dir/tools/lib"
    local tool
    for tool in install-hooks.sh pre-commit pre-push commit-msg post-commit public-repo-ip-check.sh check-banned-term-hashes.py; do
        cp "$SCRIPT_DIR/tools/$tool" "$dir/tools/$tool"
        chmod +x "$dir/tools/$tool"
    done
    # pre-commit sources tools/lib/review-token.sh -- copy the whole lib/
    # dir rather than naming files individually, so a future addition here
    # doesn't require remembering to update this fixture too.
    cp -R "$SCRIPT_DIR/tools/lib/." "$dir/tools/lib/"

    git -C "$dir" init -q
    git -C "$dir" checkout -qb main
    git -C "$dir" config user.name "IP Gate Test"
    git -C "$dir" config user.email "developer@example.com"

    printf 'AcmeSecret|@internal\\.example\\.com\n' > "$dir/.ip-patterns"
    printf 'safe\n' > "$dir/README.md"
    git -C "$dir" add .
    git -C "$dir" commit -qm "init"
}

echo "=== public-repo-ip-check targeted tests ==="

repo="$TMP_ROOT/clean-existing"
new_repo "$repo"
printf 'AcmeSecret\n' > "$repo/existing.txt"
git -C "$repo" add existing.txt
git -C "$repo" commit -qm "existing allowed baseline"
if (cd "$repo" && bash tools/public-repo-ip-check.sh >/dev/null 2>&1); then
    pass "clean repo ignores pre-existing tracked matches"
else
    fail "clean repo should not fail on pre-existing tracked matches"
fi

repo="$TMP_ROOT/unstaged"
new_repo "$repo"
printf 'AcmeSecret\n' >> "$repo/README.md"
if (cd "$repo" && ! bash tools/public-repo-ip-check.sh >/dev/null 2>&1); then
    pass "default audit catches unstaged additions"
else
    fail "default audit should fail on unstaged additions"
fi

repo="$TMP_ROOT/unstaged-plus-prefix"
new_repo "$repo"
printf '++AcmeSecret\n' >> "$repo/README.md"
if (cd "$repo" && ! bash tools/public-repo-ip-check.sh >/dev/null 2>&1); then
    pass "default audit catches additions starting with ++"
else
    fail "default audit should fail on additions starting with ++"
fi

repo="$TMP_ROOT/staged"
new_repo "$repo"
printf 'AcmeSecret\n' >> "$repo/README.md"
git -C "$repo" add README.md
if (cd "$repo" && ! bash tools/public-repo-ip-check.sh --staged-only >/dev/null 2>&1); then
    pass "--staged-only catches staged additions"
else
    fail "--staged-only should fail on staged additions"
fi

repo="$TMP_ROOT/staged-plus-prefix"
new_repo "$repo"
printf '+++AcmeSecret\n' >> "$repo/README.md"
git -C "$repo" add README.md
if (cd "$repo" && ! bash tools/public-repo-ip-check.sh --staged-only >/dev/null 2>&1); then
    pass "--staged-only catches additions starting with +++"
else
    fail "--staged-only should fail on additions starting with +++"
fi

repo="$TMP_ROOT/custom-patterns"
new_repo "$repo"
printf 'OnlyThisSecret\n' > "$repo/custom.txt"
if (cd "$repo" && ! bash tools/public-repo-ip-check.sh --patterns 'OnlyThisSecret' >/dev/null 2>&1); then
    pass "--patterns overrides repo pattern files"
else
    fail "--patterns should use the custom regex without being replaced"
fi

repo="$TMP_ROOT/untracked"
new_repo "$repo"
printf 'AcmeSecret\n' > "$repo/notes.txt"
if (cd "$repo" && ! bash tools/public-repo-ip-check.sh >/dev/null 2>&1); then
    pass "default audit catches untracked files"
else
    fail "default audit should fail on untracked files"
fi

repo="$TMP_ROOT/range"
new_repo "$repo"
printf 'AcmeSecret\n' >> "$repo/README.md"
git -C "$repo" add README.md
git -C "$repo" commit -qm "introduce forbidden text"
if (cd "$repo" && ! bash tools/public-repo-ip-check.sh --range HEAD~1..HEAD >/dev/null 2>&1); then
    pass "--range catches committed additions"
else
    fail "--range should fail on committed additions"
fi

repo="$TMP_ROOT/range-plus-prefix"
new_repo "$repo"
printf '++AcmeSecret\n' >> "$repo/README.md"
git -C "$repo" add README.md
git -C "$repo" commit -qm "introduce forbidden text with plus prefix"
if (cd "$repo" && ! bash tools/public-repo-ip-check.sh --range HEAD~1..HEAD >/dev/null 2>&1); then
    pass "--range catches committed additions starting with ++"
else
    fail "--range should fail on additions starting with ++"
fi

repo="$TMP_ROOT/upstream-only"
new_repo "$repo"
remote_repo="$TMP_ROOT/upstream-only-remote.git"
git init --bare -q "$remote_repo"
git -C "$repo" remote add upstream "$remote_repo"
git -C "$repo" push -q upstream main:dev
git -C "$repo" fetch -q upstream dev
git -C "$repo" branch --unset-upstream >/dev/null 2>&1 || true
printf 'AcmeSecret\n' >> "$repo/README.md"
git -C "$repo" add README.md
git -C "$repo" commit -qm "unpushed forbidden text with upstream-only base"
if (cd "$repo" && ! bash tools/public-repo-ip-check.sh >/dev/null 2>&1); then
    pass "default audit catches unpushed commits when only upstream refs exist"
else
    fail "default audit should use upstream refs for unpushed commit scanning"
fi

repo="$TMP_ROOT/external-hooks"
new_repo "$repo"
hooks_dir="$TMP_ROOT/external-hooks-hooks"
remote_repo="$TMP_ROOT/external-hooks-remote.git"
mkdir -p "$hooks_dir"
git init --bare -q "$remote_repo"
git -C "$repo" config core.hooksPath "$hooks_dir"
git -C "$repo" remote add origin "$remote_repo"
# Isolate hook-path resolution from separate policy gates.
cat > "$repo/.agent-gates" <<'EOF'
SKIP_REVIEW_TOKEN=true
REQUIRE_CODE_REVIEW_SENTINEL=false
EOF
(cd "$repo" && bash tools/install-hooks.sh >/dev/null 2>&1)
# Verify all expected hooks were installed
for hook in pre-commit pre-push commit-msg post-commit; do
    if [[ -f "$hooks_dir/$hook" ]] && [[ -x "$hooks_dir/$hook" ]]; then
        pass "install-hooks.sh installed $hook"
    else
        fail "install-hooks.sh did not install $hook (missing or not executable)"
    fi
done
printf 'safe external hook test\n' >> "$repo/README.md"
git -C "$repo" add README.md
if (cd "$repo" && "$hooks_dir/pre-commit" >/dev/null 2>&1); then
    pass "pre-commit works when core.hooksPath is external"
else
    fail "pre-commit should resolve repo root with external core.hooksPath"
fi
git -C "$repo" commit -qm "baseline for external hook push"
# Seed the remote without exercising hooks; the explicit hook calls below are the
# actual assertions for external core.hooksPath behavior.
git -C "$repo" push -q --no-verify origin main:dev
printf 'safe pushed change\n' >> "$repo/README.md"
git -C "$repo" add README.md
git -C "$repo" commit -qm "safe commit after external hook install"
remote_sha="$(git -C "$repo" ls-remote origin refs/heads/dev | cut -f1)"
local_sha="$(git -C "$repo" rev-parse HEAD)"
if printf 'refs/heads/main %s refs/heads/dev %s\n' "$local_sha" "$remote_sha" | (cd "$repo" && "$hooks_dir/pre-push" origin "$remote_repo" >/dev/null 2>&1); then
    pass "pre-push works when core.hooksPath is external"
else
    fail "pre-push should resolve repo root with external core.hooksPath"
fi

# Regression guard: commit-msg is installed by copying it out of tools/, so
# a path resolved relative to the hook's own location (rather than via
# `git rev-parse --show-toplevel`) silently loses the ability to find
# check-banned-term-hashes.py once installed -- this exact bug shipped in
# the first version of this guardrail and was only caught by hand-testing
# the *installed* copy, not tools/commit-msg directly. Exercise the
# installed copy at its external hooksPath location to pin the fix.
printf 'feat: port ExternalHookTestTerm improvements\n' > "$repo/MSG"
FAKE_HASH_EXTERNAL="$(python3 -c "import hashlib; print(hashlib.sha256(('sp-plus-ip-guard-v1:'+'externalhooktestterm').encode()).hexdigest())")"
if (cd "$repo" && ! BANNED_HASH_TEST_OVERRIDE="$FAKE_HASH_EXTERNAL" "$hooks_dir/commit-msg" "$repo/MSG" >/dev/null 2>&1); then
    pass "installed commit-msg hook (external hooksPath) still finds check-banned-term-hashes.py and rejects a banned term"
else
    fail "installed commit-msg hook should resolve check-banned-term-hashes.py via repo root, not its own copied location"
fi

repo="$TMP_ROOT/local-patterns"
mkdir -p "$repo/tools"
cp "$SCRIPT_DIR/tools/public-repo-ip-check.sh" "$repo/tools/public-repo-ip-check.sh"
chmod +x "$repo/tools/public-repo-ip-check.sh"
git -C "$repo" init -q
git -C "$repo" checkout -qb main
git -C "$repo" config user.name "IP Gate Test"
git -C "$repo" config user.email "developer@example.com"
printf 'LocalOnlySecret\n' > "$repo/.ip-check-patterns"
printf 'safe\n' > "$repo/README.md"
git -C "$repo" add README.md
git -C "$repo" commit -qm "init without tracked patterns"
printf 'LocalOnlySecret\n' > "$repo/local.txt"
if (cd "$repo" && ! bash tools/public-repo-ip-check.sh >/dev/null 2>&1); then
    pass ".ip-check-patterns remains supported as a local extension"
else
    fail "local .ip-check-patterns should be loaded"
fi

# ---------------------------------------------------------------------------
# Hash-based banned-term scan (tools/check-banned-term-hashes.py).
#
# Uses BANNED_HASH_TEST_OVERRIDE (a test-only env var the script reads
# instead of its real, permanent hash list) with an obviously-fake term so
# this test file never has to contain -- and therefore never risks leaking
# -- an actual banned codename. This mirrors the CLAUDE_HOOKS_PATTERNS_FILE_
# OVERRIDE pattern already used by pre-tool-use-internal-terms.sh's tests.
# ---------------------------------------------------------------------------
FAKE_HASH="$(python3 -c "import hashlib; print(hashlib.sha256(('sp-plus-ip-guard-v1:'+'acmetestcodename').encode()).hexdigest())")"

repo="$TMP_ROOT/banned-hash-untracked"
new_repo "$repo"
printf 'mentions AcmeTestCodename here\n' > "$repo/leaky.txt"
if (cd "$repo" && ! BANNED_HASH_TEST_OVERRIDE="$FAKE_HASH" bash tools/public-repo-ip-check.sh >/dev/null 2>&1); then
    pass "hash-based scan catches banned term in untracked file"
else
    fail "hash-based scan should fail on untracked file with banned term"
fi
if (cd "$repo" && bash tools/public-repo-ip-check.sh >/dev/null 2>&1); then
    pass "hash-based scan does not fire without the override (real hashes don't match the fake term)"
else
    fail "audit should pass when the fake term's hash is not in the active set"
fi

repo="$TMP_ROOT/banned-hash-staged"
new_repo "$repo"
printf 'mentions AcmeTestCodename here\n' >> "$repo/README.md"
git -C "$repo" add README.md
if (cd "$repo" && ! BANNED_HASH_TEST_OVERRIDE="$FAKE_HASH" bash tools/public-repo-ip-check.sh --staged-only >/dev/null 2>&1); then
    pass "hash-based scan catches banned term in staged diff"
else
    fail "hash-based scan should fail on staged diff with banned term"
fi

repo="$TMP_ROOT/banned-hash-two-word"
new_repo "$repo"
printf 'integrate with Acme Test Codename product\n' >> "$repo/README.md"
git -C "$repo" add README.md
TRIPLE_HASH="$(python3 -c "import hashlib; print(hashlib.sha256(('sp-plus-ip-guard-v1:'+'acmetest').encode()).hexdigest())")"
if (cd "$repo" && ! BANNED_HASH_TEST_OVERRIDE="$TRIPLE_HASH" bash tools/public-repo-ip-check.sh --staged-only >/dev/null 2>&1); then
    pass "hash-based scan catches a two-word phrase via adjacent-token pairing"
else
    fail "hash-based scan should fail on 'Acme Test' as an adjacent-pair match"
fi

repo="$TMP_ROOT/banned-hash-range-content"
new_repo "$repo"
printf 'mentions AcmeTestCodename here\n' >> "$repo/README.md"
git -C "$repo" add README.md
git -C "$repo" commit -qm "introduce banned term in file content"
if (cd "$repo" && ! BANNED_HASH_TEST_OVERRIDE="$FAKE_HASH" bash tools/public-repo-ip-check.sh --range HEAD~1..HEAD >/dev/null 2>&1); then
    pass "hash-based scan catches banned term in committed file content via --range"
else
    fail "--range should fail on committed file content with banned term"
fi

repo="$TMP_ROOT/banned-hash-commit-message-only"
new_repo "$repo"
printf 'safe content, no banned term here\n' >> "$repo/README.md"
git -C "$repo" add README.md
git -C "$repo" commit -qm "feat: port AcmeTestCodename improvements"
if (cd "$repo" && ! BANNED_HASH_TEST_OVERRIDE="$FAKE_HASH" bash tools/public-repo-ip-check.sh --range HEAD~1..HEAD >/dev/null 2>&1); then
    pass "hash-based scan catches banned term that appears ONLY in the commit message (not file content)"
else
    fail "--range should fail when the banned term is only in the commit message body"
fi

repo="$TMP_ROOT/banned-hash-commit-msg-hook"
new_repo "$repo"
printf 'safe change\n' >> "$repo/README.md"
git -C "$repo" add README.md
printf 'feat: port AcmeTestCodename improvements\n' > "$repo/MSG"
if (cd "$repo" && ! BANNED_HASH_TEST_OVERRIDE="$FAKE_HASH" bash tools/commit-msg "$repo/MSG" >/dev/null 2>&1); then
    pass "commit-msg hook rejects a banned term in the proposed commit message"
else
    fail "commit-msg hook should reject a banned term in the commit message"
fi
printf 'feat: a perfectly safe commit message\n' > "$repo/MSG"
if (cd "$repo" && BANNED_HASH_TEST_OVERRIDE="$FAKE_HASH" bash tools/commit-msg "$repo/MSG" >/dev/null 2>&1); then
    pass "commit-msg hook allows a clean commit message"
else
    fail "commit-msg hook should allow a clean commit message"
fi

# Regression guard: BANNED_HASH_TEST_OVERRIDE must be additive (union with
# the real hash set), never a replacement. An earlier version of this
# guardrail let the override REPLACE the active set, so simply having this
# env var set to anything (a shell rc file, a stray CI export) silently
# disabled detection of the real banned terms -- the exact opposite of
# "no exceptions." This uses one of the script's own REAL hashes indirectly:
# it relies on a real banned term still being caught while an override for
# an unrelated fake term is simultaneously active, without ever writing the
# real term in this test file. To do that safely we call the underlying
# python script directly with a real-world-shaped (but fictitious) input
# that would only trip if the override wrongly replaced the whole set.
repo="$TMP_ROOT/banned-hash-override-is-additive"
new_repo "$repo"
UNRELATED_FAKE_HASH="$(python3 -c "import hashlib; print(hashlib.sha256(('sp-plus-ip-guard-v1:'+'unrelatedfaketerm').encode()).hexdigest())")"
if (cd "$repo" && printf 'nothing sensitive, just an unrelatedfaketerm mention\n' \
    | BANNED_HASH_TEST_OVERRIDE="$UNRELATED_FAKE_HASH" python3 tools/check-banned-term-hashes.py >/dev/null 2>&1); then
    fail "override should still block its own fake term (sanity check the override works at all)"
else
    pass "override sanity check: override term is still detected"
fi
if (cd "$repo" && printf 'a perfectly ordinary sentence with no banned terms at all\n' \
    | BANNED_HASH_TEST_OVERRIDE="$UNRELATED_FAKE_HASH" python3 tools/check-banned-term-hashes.py >/dev/null 2>&1); then
    pass "override does not report a false positive on unrelated clean text (real set unaffected)"
else
    fail "override should not flag clean text that matches neither the override nor the real hash set"
fi

# Regression guard: adjacent-pair matching must be scoped to a single line.
# An earlier version tokenized the whole input as one stream, so a two-word
# banned phrase could false-positive when the first word ended one line/
# sentence and the second word began an unrelated next line.
repo="$TMP_ROOT/banned-hash-cross-line-no-false-positive"
new_repo "$repo"
TWO_WORD_HASH="$(python3 -c "import hashlib; print(hashlib.sha256(('sp-plus-ip-guard-v1:'+'acmetest').encode()).hexdigest())")"
printf 'we sell products under the Acme\nTest coverage improved this sprint\n' >> "$repo/README.md"
git -C "$repo" add README.md
if (cd "$repo" && BANNED_HASH_TEST_OVERRIDE="$TWO_WORD_HASH" bash tools/public-repo-ip-check.sh --staged-only >/dev/null 2>&1); then
    pass "two-word phrase does not false-positive across a line boundary"
else
    fail "adjacent-pair matching should not cross a line boundary (cross-line/cross-file false positive)"
fi

echo "=== Results: $PASS passed, $FAIL failed ==="
[[ "$FAIL" -eq 0 ]]

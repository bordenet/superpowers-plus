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
    mkdir -p "$dir/tools"
    local tool
    for tool in install-hooks.sh pre-commit pre-push public-repo-ip-check.sh; do
        cp "$SCRIPT_DIR/tools/$tool" "$dir/tools/$tool"
        chmod +x "$dir/tools/$tool"
    done

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
for hook in pre-commit pre-push commit-msg; do
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

echo "=== Results: $PASS passed, $FAIL failed ==="
[[ "$FAIL" -eq 0 ]]

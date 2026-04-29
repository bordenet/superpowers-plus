#!/usr/bin/env bash
# Sentinel test: drop a uniquely-triggered skill into <repo>/skills/_archive-test/
# (or appropriate _* path), run the repo's loader/discovery, assert the sentinel
# is NOT discovered. Cleanup always runs.
#
# Two-track verification:
#   1. Source-grep: confirm the loader source skips _* directories (regex check
#      in skill-discovery.js). Fast, deterministic.
#   2. Live-discovery: when a node test runner is present, drop a sentinel and
#      run discovery; assert sentinel name is not in output.
#
# Repo-shape adapter: tries 'skills/' first, then the repo root itself.
# Repos without a node-based discovery still get the source-grep verdict,
# which is sufficient to satisfy Phase 1.2 if the source pattern is present.
#
# Exit 0 iff repo passes BOTH tracks (or source-grep pass AND no node runner).
# Exit 1 on any failure.

set -euo pipefail

REPO="${1:?usage: test-archive-skip.sh <repo-root>}"
REPO="${REPO%/}"
REPO_NAME="$(basename "$REPO")"

if [ ! -d "$REPO" ]; then
  echo "❌ ${REPO_NAME}: not a directory: $REPO"
  exit 1
fi

PASS=0
FAIL=0

note() { echo "  $*"; }
ok()   { note "✅ $*"; PASS=$((PASS+1)); }
bad()  { note "❌ $*"; FAIL=$((FAIL+1)); }

echo "=== ${REPO_NAME} ==="

# ---- Track 1: Source-grep verification ----
LOADER_CANDIDATES=(
  "lib/skill-discovery.js"
  "lib/discovery.js"
  "lib/skills.js"
  "mcp/superpowers-mcp.js"
  "agents/lib/skill-discovery.js"
  "bootstrap/skill-discovery.js"
)
LOADER_FOUND=""
for c in "${LOADER_CANDIDATES[@]}"; do
  if [ -f "$REPO/$c" ]; then LOADER_FOUND="$REPO/$c"; break; fi
done

if [ -z "$LOADER_FOUND" ]; then
  # Some repos may use different conventions; search broadly via -exec.
  CANDIDATE=$(find "$REPO" -maxdepth 4 -name '*.js' -path '*lib*' -not -path '*node_modules*' \
    -exec grep -l -E "startsWith\(['\"]_['\"]" {} + 2>/dev/null | head -1 || true)
  LOADER_FOUND="${CANDIDATE:-}"
fi

if [ -n "$LOADER_FOUND" ] && grep -qE "startsWith\(['\"]_['\"]" "$LOADER_FOUND" 2>/dev/null; then
  ok "source-grep: '_*' skip pattern present in ${LOADER_FOUND#"$REPO"/}"
elif [ -n "$LOADER_FOUND" ]; then
  bad "source-grep: ${LOADER_FOUND#"$REPO"/} found but no '_*' skip pattern matched"
else
  # Some repos have no independent runtime loader and ship via install.sh into
  # a shared runtime. The relevant primitive is install-time exclusion. Check
  # install scripts for _archive/_shared domain skipping.
  if grep -rqE "_archive\|_shared|_archive.*_shared|_shared.*_archive" "$REPO/install.sh" "$REPO/lib/install/" 2>/dev/null; then
    ok "install-script: '_archive' / '_shared' skip pattern present (no runtime loader; install-time exclusion is the boundary)"
  else
    bad "no loader file AND no install-script skip pattern detected"
  fi
fi

# ---- Track 2: Live-discovery verification ----
# Find a skills root
SKILLS_ROOT=""
if [ -d "$REPO/skills" ]; then
  SKILLS_ROOT="$REPO/skills"
elif find "$REPO" -maxdepth 2 -name 'skill.md' -print -quit 2>/dev/null | grep -q .; then
  SKILLS_ROOT="$REPO"
fi

if [ -z "$SKILLS_ROOT" ]; then
  note "live-discovery: no skills root found — skipping (source-grep verdict stands)"
else
  SENTINEL_DIR="$SKILLS_ROOT/_archive-test/sentinel-skill-$$"
  SENTINEL_TRIGGER="ZZZSENTINELZZZ$$"
  cleanup() { rm -rf "$SENTINEL_DIR" 2>/dev/null || true; rmdir "$SKILLS_ROOT/_archive-test" 2>/dev/null || true; }
  trap cleanup EXIT INT TERM

  mkdir -p "$SENTINEL_DIR"
  cat > "$SENTINEL_DIR/skill.md" <<EOF
---
name: sentinel-skill-$$
description: ${SENTINEL_TRIGGER} sentinel test for archive skip
triggers:
  - "${SENTINEL_TRIGGER}"
---
sentinel
EOF

  # Try node-based discovery first
  RAN=0
  if [ -f "$REPO/test/skill-discovery.test.js" ]; then
    RAN=1
    if (cd "$REPO" && node test/skill-discovery.test.js 2>&1 | grep -q "$SENTINEL_TRIGGER"); then
      bad "live-discovery: sentinel WAS discovered via test/skill-discovery.test.js (loader does NOT skip _*)"
    else
      ok "live-discovery: sentinel not discovered via test/skill-discovery.test.js"
    fi
  fi

  if [ $RAN -eq 0 ] && [ -f "$REPO/superpowers-augment.js" ]; then
    RAN=1
    if (cd "$REPO" && SPP_SOURCE_DIR="$REPO" PERSONAL_SKILLS_DIR="$SKILLS_ROOT" node superpowers-augment.js find-skills 2>/dev/null | grep -q "sentinel-skill-$$"); then
      bad "live-discovery: sentinel WAS discovered via find-skills"
    else
      ok "live-discovery: sentinel not discovered via find-skills"
    fi
  fi

  if [ $RAN -eq 0 ]; then
    note "live-discovery: no node runner found — skipping (source-grep verdict stands)"
  fi
fi

echo "  -> ${PASS} pass, ${FAIL} fail"
[ $FAIL -eq 0 ] && exit 0 || exit 1

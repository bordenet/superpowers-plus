---
name: codeowners-drift-audit
source: superpowers-plus
augment_menu: true
triggers: ["/sp-codeowners-drift-audit", "/codeowners-drift-audit", "CODEOWNERS out of date", "who owns this file", "codeowners audit", "unowned files", "CODEOWNERS drift"]
anti_triggers: ["PR review assignment", "auto-assign reviewers"]
description: "Audit CODEOWNERS for drift: finds unowned files, dead rules (patterns matching zero files), and invalid owner references. Works with GitHub and GitLab remotes, and degrades to advisory-only output when neither CLI is authenticated. Run when CODEOWNERS is out of date, files lack coverage, or ownership is unclear."
summary: "Use when: CODEOWNERS is out of date, files lack owners, or ownership assignments seem stale. Audits unowned files, dead rules, and invalid owners."
coordination:
  group: engineering
  order: 5
  requires: []
  enables: []
  escalates_to: []
  internal: false
composition:
  consumes: [repo-state]
  produces: [codeowners-audit-report]
  capabilities: [audits-codeowners, detects-drift]
  priority: 10
---

# CODEOWNERS Drift Audit

> **Wrong skill?** PR reviewer auto-assignment → not this skill (read-only audit only). Blast radius of a code change → `blast-radius-check`.
>
> **Source:** `superpowers-plus`
> **Part of:** Engineering Rigor skill family

## When to Use

- CODEOWNERS hasn't been reviewed in a while and ownership may have drifted
- Files or directories seem to lack a clear owner
- A rule in CODEOWNERS may no longer match anything (renamed/deleted paths)
- An owner reference (`@user`, `@org/team`) may be stale or misspelled

## How to Run

Run the single script below via `bash` (enforced at runtime, see Failure
Modes). Locates CODEOWNERS (`.github/`, then root, then `docs/` -- GitHub's
own order), finds unowned files, dead rules, and invalid owners. Stateless.

> **Exit code:** exit 0 with all three `===` headers printed means complete.
> Anything else is an incomplete audit -- never read that as "no issues found."
>
> **Large-repo advisory:** cap `FILES_ARR` post-build for a quick sample (e.g.
> `FILES_ARR=("${FILES_ARR[@]:0:100}")`) -- but this also caps Step 2 (Dead
> Rules); see the Failure Modes row before deleting a rule it flags.

```bash
#!/usr/bin/env bash
set -euo pipefail

# -- Step 0: Preconditions --
# Under zsh, matches_pattern()'s case-glob silently mismatches everything.
if [ -z "${BASH_VERSION:-}" ]; then
  echo "ERROR: this script requires bash -- re-run as 'bash <this-script>'" >&2; exit 1
fi
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "ERROR: not inside a git working tree" >&2; exit 1
fi
# CODEOWNERS candidates and git ls-files are both cwd-relative -- root first.
cd "$(git rev-parse --show-toplevel)" || { echo "ERROR: cannot cd to repo root" >&2; exit 1; }

CODEOWNERS_PATH=""
for candidate in .github/CODEOWNERS CODEOWNERS docs/CODEOWNERS; do
  [ -f "$candidate" ] && { CODEOWNERS_PATH="$candidate"; break; }
done
if [ -z "$CODEOWNERS_PATH" ]; then
  echo "ERROR: no CODEOWNERS file found" >&2; exit 1
fi
if [ ! -r "$CODEOWNERS_PATH" ]; then
  echo "ERROR: CODEOWNERS found but not readable: $CODEOWNERS_PATH" >&2; exit 1
fi
echo "CODEOWNERS: $CODEOWNERS_PATH"

# Match gitignore-style; anchoring MUST be decided before "/" is stripped
# (see Failure Modes for the anchoring/globstar regressions this fixes).
matches_pattern() {
  local f="$1" pattern="$2"
  local anchored=0
  case "$pattern" in
    '**/'*) pattern="${pattern#\*\*/}" ;;
    *)
      case "${pattern%/}" in
        */*) anchored=1 ;;
      esac
      ;;
  esac
  pattern="${pattern#/}"
  pattern="${pattern%/}"
  # gitignore's "/**/ " also matches zero intervening dirs.
  local pattern2="${pattern//\/\*\*\//\/}"
  if [ "$anchored" -eq 1 ]; then
    # shellcheck disable=SC2254
    case "$f" in
      $pattern|$pattern/*|$pattern2|$pattern2/*) return 0 ;;
    esac
  else
    # shellcheck disable=SC2254
    case "$f" in
      $pattern|$pattern/*|*/$pattern|*/$pattern/*|$pattern2|$pattern2/*|*/$pattern2|*/$pattern2/*) return 0 ;;
    esac
  fi
  return 1
}

# Rules (GitLab [Section] headers excluded, trailing "# comment" text and any
# CRLF stripped so neither pollutes Step 3's owner-token field split below).
RULES=$(grep -Ev '^\s*(#|$|\[)' "$CODEOWNERS_PATH" 2>/dev/null | tr -d '\r' | sed -E 's/[[:space:]]*#.*$//' || true)
echo "Rules: $(echo "$RULES" | grep -c . || true)"

# NUL-delimited into an array: git ls-files -z is never C-quoted, unlike
# newline-delimited output (handles non-ASCII/backslash filenames correctly).
FILES_ARR=()
while IFS= read -r -d '' f; do
  FILES_ARR+=("$f")
done < <(git ls-files -z)
echo "Tracked files: ${#FILES_ARR[@]}"

# -- Step 1: Unowned files --
echo ""
echo "=== Unowned Files ==="
for f in "${FILES_ARR[@]+"${FILES_ARR[@]}"}"; do
  owned=0
  while IFS= read -r rule; do
    [ -z "$rule" ] && continue
    read -r pattern _ <<< "$rule"
    if matches_pattern "$f" "$pattern"; then owned=1; break; fi
  done <<RULES_EOF
$RULES
RULES_EOF
  if [ "$owned" -eq 0 ]; then echo "  UNOWNED: $f"; fi
done

# -- Step 2: Dead rules --
echo ""
echo "=== Dead Rules ==="
echo "$RULES" | while IFS= read -r rule; do
  [ -z "$rule" ] && continue
  read -r pattern _ <<< "$rule"
  matched=0
  for f in "${FILES_ARR[@]+"${FILES_ARR[@]}"}"; do
    if matches_pattern "$f" "$pattern"; then matched=1; break; fi
  done
  if [ "$matched" -eq 0 ]; then echo "  DEAD RULE: $rule"; fi
done

# -- Step 3: Owner validity (best-effort) --
echo ""
echo "=== Owner Validity ==="
# Check every remote, parsing the actual hostname (see Failure Modes).
IS_GITHUB=0
for remote_name in $(git remote 2>/dev/null); do
  remote_url=$(git remote get-url "$remote_name" 2>/dev/null) || continue
  remote_host=$(printf '%s\n' "$remote_url" | sed -E 's#^[a-zA-Z][a-zA-Z0-9+.-]*://##; s#^[^@/]*@##; s#[:/].*##')
  if [ "$remote_host" = "github.com" ]; then IS_GITHUB=1; break; fi
done

# gh only for github.com, glab only otherwise (prevents cross-API misvalidation).
HAS_GH=0
if [ "$IS_GITHUB" -eq 1 ] && command -v gh >/dev/null 2>&1; then
  if gh auth status >/dev/null 2>&1; then
    HAS_GH=1
  else
    echo "  ADVISORY: gh not authenticated -- owner check skipped"
  fi
fi

HAS_GLAB=0
if [ "$IS_GITHUB" -eq 0 ] && command -v glab >/dev/null 2>&1; then
  if glab auth status >/dev/null 2>&1; then
    HAS_GLAB=1
  else
    echo "  ADVISORY: glab not authenticated -- owner check skipped"
  fi
fi

if [ "$HAS_GH" -eq 0 ] && [ "$HAS_GLAB" -eq 0 ]; then
  echo "  ADVISORY: owner verification skipped -- no authenticated CLI matching this remote's type on PATH"
  echo "  (unowned-file and dead-rule results above are unaffected -- CLI is only needed for owner validity)"
else
  echo "$RULES" \
    | awk '{for(i=2;i<=NF;i++) print $i}' \
    | sort -u \
    | while IFS= read -r owner; do
        [ -z "$owner" ] && continue
        # Email-format: non-@ char before @ + dot after @ = email, not username
        case "$owner" in
          [!@]*@*.*) echo "  UNVERIFIABLE: $owner (email-format)"; continue ;;
        esac
        # No "@" and not email-shaped: not a valid CODEOWNERS owner reference
        case "$owner" in
          @*) : ;;
          *) echo "  UNVERIFIABLE: $owner (missing @ prefix)"; continue ;;
        esac
        slug="${owner#@}"
        if [ "$HAS_GH" -eq 1 ]; then
          # Distinguish team refs (@org/team) from user refs (@user)
          if echo "$slug" | grep -q '/'; then
            if gh api "orgs/${slug%%/*}/teams/${slug##*/}" --silent 2>/dev/null; then
              echo "  VALID: $owner"
            else
              echo "  NOT_FOUND: $owner"
            fi
          else
            if gh api "users/${slug}" --silent 2>/dev/null; then
              echo "  VALID: $owner"
            else
              echo "  NOT_FOUND: $owner"
            fi
          fi
        elif [ "$HAS_GLAB" -eq 1 ]; then
          # glab users?username= exits 0 even for empty results -- inspect body
          ubody=$(glab api "users?username=${slug}" 2>/dev/null || echo "[]")
          # URL-encode slash for namespaced group paths (e.g. myorg/myteam -> myorg%2Fmyteam)
          encoded_slug=$(printf '%s' "$slug" | sed 's|/|%2F|g')
          gbody=$(glab api "groups/${encoded_slug}" 2>/dev/null || echo "{}")
          if echo "$ubody" | grep -q '"username"' || echo "$gbody" | grep -q '"full_path"'; then
            echo "  VALID: $owner"
          else
            echo "  NOT_FOUND: $owner"
          fi
        else
          echo "  UNVERIFIABLE: $owner (no matching CLI for remote type)"
        fi
      done
fi
echo ""
echo "=== Done. Review UNOWNED/DEAD RULE/NOT_FOUND lines above. ==="
```

## Companion Skills

- `blast-radius-check` — Before modifying code that a drifted CODEOWNERS rule might miss
- `pre-commit-gate` — Pre-commit checks independent of ownership review

## Failure Modes

Top rows only -- **see `reference.md`** for the full table.

| Failure | Prevention |
|---|---|
| zsh silently mismatches every pattern; sh/dash fail differently but still non-zero | Step 0 checks `$BASH_VERSION`, refuses to run without it |
| Leading-slash pattern (`/build/`) loses root-anchoring if `/` is stripped before the anchor decision | `anchored` is decided from `${pattern%/}` before the leading `/` is stripped |
| Leading `**/`, or mid-string `/**/`, doesn't match zero intervening dirs (`case` has no recursive-glob) | Leading `**/` special-cased to any-depth; mid-string gets a collapsed-to-`/` candidate |
| `.github/CODEOWNERS` vs root, or a subdirectory invocation, silently scopes the search/file-list wrong | Search order `.github/`→root→`docs/`; Step 0 `cd`s to repo root first |
| Non-GitHub/non-GitLab remote + authenticated `glab` gets a confident but meaningless result | Disclosed, unfixed (reference.md) -- don't trust Owner Validity here |
| Large repo: capping `FILES_ARR` also corrupts Step 2 | See "Large-repo advisory" -- never delete a flagged `DEAD RULE` from a capped run |
| Non-zero exit, or stopping before "=== Done." | Never read as "no issues found" -- rerun |

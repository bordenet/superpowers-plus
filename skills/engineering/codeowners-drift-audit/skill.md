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

Run the single script below via `bash` (not `sh` or `zsh`). It locates CODEOWNERS,
finds unowned files, finds dead rules, checks owner validity, and prints a report.

All state is local to the script invocation -- no temp files, no session state, no races.

> **Large-repo advisory:** For repos with thousands of files, cap `FILES_ARR` to the
> first N entries after it's built (e.g. `FILES_ARR=("${FILES_ARR[@]:0:100}")`) for
> a quick sample. Bare patterns (no `/`) already match at any depth,
> matching gitignore semantics; only explicit extended glob syntax (`**`, `?`, `[...]`)
> is not interpreted specially -- `case` treats those as ordinary wildcards.
>
> **Exit code:** the script exits 0 and prints all three `===` section headers
> ("Unowned Files", "Dead Rules", "Owner Validity") on a completed run. A non-zero
> exit or a run that stops before "=== Done." means the audit is incomplete --
> treat it as a tool failure, never as "no issues found."

```bash
#!/usr/bin/env bash
set -euo pipefail

# -- Step 0: Preconditions --
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "ERROR: not inside a git working tree" >&2; exit 1
fi

CODEOWNERS_PATH=""
for candidate in CODEOWNERS .github/CODEOWNERS docs/CODEOWNERS; do
  [ -f "$candidate" ] && { CODEOWNERS_PATH="$candidate"; break; }
done
if [ -z "$CODEOWNERS_PATH" ]; then
  echo "ERROR: no CODEOWNERS file found" >&2; exit 1
fi
if [ ! -r "$CODEOWNERS_PATH" ]; then
  echo "ERROR: CODEOWNERS found but not readable: $CODEOWNERS_PATH" >&2; exit 1
fi
echo "CODEOWNERS: $CODEOWNERS_PATH"

# Match a CODEOWNERS pattern against a file path with gitignore-style semantics:
# a pattern containing "/" is anchored to the repo root; a bare pattern (no "/")
# matches at any depth.
matches_pattern() {
  local f="$1" pattern="$2"
  pattern="${pattern#/}"
  pattern="${pattern%/}"
  case "$pattern" in
    */*)
      # shellcheck disable=SC2254
      case "$f" in
        $pattern|$pattern/*) return 0 ;;
      esac
      ;;
    *)
      # shellcheck disable=SC2254
      case "$f" in
        $pattern|$pattern/*|*/$pattern|*/$pattern/*) return 0 ;;
      esac
      ;;
  esac
  return 1
}

# Rules and files (GitLab [Section] headers excluded)
RULES=$(grep -Ev '^\s*(#|$|\[)' "$CODEOWNERS_PATH" 2>/dev/null || true)
echo "Rules: $(echo "$RULES" | grep -c . || true)"

# NUL-delimited enumeration into an array: git ls-files -z is never C-quoted,
# regardless of core.quotepath -- unlike newline-delimited output, this handles
# non-ASCII, backslash, and embedded-quote filenames correctly. A plain string
# variable can't hold NUL-separated data safely (bash strings are NUL-terminated
# internally), so this is collected once into an array and reused below.
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
REMOTE_URL=$(git remote get-url origin 2>/dev/null || echo "unknown")
IS_GITHUB=0
if echo "$REMOTE_URL" | grep -q "github.com"; then IS_GITHUB=1; fi

# gh only runs against a confirmed github.com remote; glab only runs against a
# confirmed non-github.com remote (self-hosted GitLab can be any hostname, so
# it gets the rest by exclusion rather than a positive hostname match). This
# prevents a GitHub-remote repo with an unauthenticated/absent gh but a merely-
# present glab from silently validating owners against the wrong API.
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

| Failure | Prevention |
|---|---|
| Extended glob syntax (`**`, `?`, `[...]`) not interpreted specially | Disclosed limitation; `case` treats these as literal/simple wildcards, not gitignore's extended semantics -- flag complex patterns for manual review |
| Large repo: unowned or dead-rule scan is slow | Add `\| head -100` inside each loop for a quick sample |
| GitLab `[Section]` headers parsed as patterns | `grep -Ev` includes `\[` to exclude section headers |
| Trailing-slash / leading-slash patterns (`/build/`) cause match failures | `matches_pattern()` strips both before matching |
| A pattern with no `/` should match at any depth (gitignore semantics), not just the root | `matches_pattern()` branches on whether the pattern contains `/`: bare patterns match at any depth, patterns containing `/` are anchored to the repo root |
| `$pattern` glob requires bash | Script uses `#!/usr/bin/env bash` and must be run via `bash` |
| Non-ASCII, backslash, or embedded-quote filenames come back C-quoted from `git ls-files` by default, causing simultaneous false UNOWNED + false DEAD RULE | File enumeration uses `git ls-files -z` (never quoted, regardless of `core.quotepath`) into an array, not newline-delimited output |
| Tab-separated or leading-whitespace CODEOWNERS lines split incorrectly | Pattern extraction uses `read -r pattern _ <<< "$rule"` (any-whitespace split), not a literal-space cut |
| Running outside a git working tree crashes mid-report via the same `set -e`/pipefail mechanism the original bug used | Step 0 checks `git rev-parse --is-inside-work-tree` before proceeding |
| CODEOWNERS present but unreadable (permissions) silently reads as "0 rules" | Step 0 explicitly checks the file is readable and errors out if not |
| GitHub team vs user API path ambiguity | Step 3 checks for `/` in slug to route to team or user endpoint |
| GitLab `users?username=` exits 0 for empty array | Step 3 inspects response body for `"username"` key |
| GitLab usernames with dots (`@alice.smith`) misclassified as email | Email guard uses `[!@]*@*.*` (non-@ char before `@`) |
| `gh` on PATH but not authenticated -- false NOT_FOUND | Auth pre-check disables `gh` path and emits ADVISORY if unauthenticated |
| GitHub remote with `gh` absent/unauthenticated but `glab` merely present would otherwise silently validate owners against the wrong (GitLab) API | `glab` only runs when the remote is confirmed NOT github.com; `gh` only runs when it IS |
| GitHub private teams return HTTP 403 (not 404) -- valid team reported NOT_FOUND | Advisory only; verify flagged team refs manually before removing from CODEOWNERS |
| Neither `gh` nor `glab` on PATH (or neither matches the remote type) | Steps 1-2 (unowned files, dead rules) still run fully; only Step 3 (owner validity) degrades to ADVISORY |

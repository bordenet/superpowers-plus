# codeowners-drift-audit -- Reference

Companion to `skill.md` (kept under `tools/harsh-review.sh`'s 250-line
structural limit). Load this file for the full Failure Modes table --
`skill.md` only lists the highest-severity/highest-frequency rows inline.

## Full Failure Modes Table

| Failure | Prevention |
|---|---|
| Running under zsh silently mismatches every pattern (clean exit 0, wrong report) instead of erroring | Step 0 checks `$BASH_VERSION` and refuses to run without it |
| Running under `sh` or `dash` instead of bash | Both fail via a different, unrelated error before or shortly after the `$BASH_VERSION` check (macOS `/bin/sh` is bash-in-posix-mode, so it passes the guard but then dies on `<(...)` process substitution syntax; `dash` fails immediately on `set -o pipefail`) -- still non-zero and loud in both cases, never silently wrong |
| A leading-slash pattern (`/build/`, `/docs/` -- GitHub's own canonical anchoring example) loses root-anchoring if the leading `/` is stripped before the anchor decision is made | `matches_pattern()` decides `anchored` from `${pattern%/}` (trailing-only strip) BEFORE stripping the leading `/` for the match construction |
| A leading `**/` pattern never matches a root-level file (`case` has no native recursive-glob) | `matches_pattern()` special-cases a `**/` prefix, stripping it and matching the remainder at any depth |
| A mid-string `/**/` (e.g. `src/**/test.js`) doesn't match zero intervening directories on its own -- a bare glob `*` can't express "zero-or-more" | A second match candidate collapses every `/**/` to `/` (pure bash `${pattern//\/\*\*\//\/}`, tried alongside the original pattern) |
| A pattern with two or more remaining `/**/` occurrences and differing per-globstar segment counts (e.g. `a/**/b/**/c` against `a/x/b/c`, one segment in the first gap and zero in the second) still fails to match -- true whether the pattern is anchored (`a/**/b/**/c`) or unanchored via a leading `**/` prefix (`**/a/**/b/**/c`) | Disclosed, unfixed: the collapse-candidate approach covers "all globstars expand" and "all globstars collapse to zero" but not mixed per-globstar outcomes; fixing this exactly would need one candidate per 2^n collapse combination for n globstars. Real-world CODEOWNERS patterns essentially never use two or more separate `**` segments in one rule, so this is treated as an accepted, narrow-scope limitation rather than fixed |
| `.github/CODEOWNERS` and a root `CODEOWNERS` both exist -- auditing the wrong one | Search order is `.github/`, root, `docs/`, matching GitHub's own documented lookup precedence |
| `?` and `[...]` ARE wildcards in a `case` pattern, but looser than gitignore's -- e.g. `a?b` matches literal `a/b` too, since `case` has no path-awareness and gitignore's `?`/`[...]` never cross a `/` | Disclosed, unfixed: can over-match relative to gitignore/CODEOWNERS semantics for patterns using these characters -- flag complex patterns for manual review |
| Tab-separated or leading-whitespace CODEOWNERS lines split incorrectly | Pattern extraction uses `read -r pattern _ <<< "$rule"` (any-whitespace split), not a literal-space cut |
| Trailing `# comment` text on a rule line parsed as extra owner tokens | `RULES` strips trailing `#...` before the owner-extraction field split |
| CRLF-terminated CODEOWNERS line glues a `\r` onto the last field | `RULES` pipes through `tr -d '\r'` |
| Owner token with no `@` and no email shape silently looked up as a bare username | Explicit `@*` check; non-matching tokens report `UNVERIFIABLE (missing @ prefix)` |
| GitHub remote configured under a non-`origin` name is missed | Step 3 checks every configured remote, not just `origin` |
| Substring match on `github.com` false-positives on hosts like `.../github.com-mirror/...` | Step 3 parses the actual hostname out of the remote URL and compares exactly, rather than substring-matching the whole URL |
| A remote that's neither `github.com` nor actually GitLab (Bitbucket, Azure DevOps, or no remote at all) with an authenticated `glab` present gets confidently validated against GitLab's API anyway | Disclosed, unfixed: `IS_GITHUB=0` means "not github.com," not "confirmed GitLab" -- self-hosted GitLab can be any hostname, so there's no cheap positive check; treat `VALID`/`NOT_FOUND` as untrustworthy on a non-GitHub, non-GitLab remote |
| Large repo: unowned/dead-rule scan is slow; capping `FILES_ARR` for a quick sample also corrupts Step 2 (Dead Rules) | See the "Large-repo advisory" in `skill.md` -- never delete a `DEAD RULE` from a capped run without re-checking against the full, uncapped file list |
| GitLab `[Section]` headers parsed as patterns | `grep -Ev` includes `\[` to exclude section headers |
| Non-zero exit, or output stopping before the "=== Done." line | Never treat this as "no issues found" -- the audit is incomplete, not clean; rerun before reporting a result |
| Non-ASCII, backslash, or embedded-quote filenames come back C-quoted from `git ls-files` by default, causing simultaneous false UNOWNED + false DEAD RULE | File enumeration uses `git ls-files -z` (never quoted, regardless of `core.quotepath`) into an array, not newline-delimited output |
| Running outside a git working tree crashes mid-report | Step 0 checks `git rev-parse --is-inside-work-tree` before proceeding |
| CODEOWNERS present but unreadable (permissions) silently reads as "0 rules" | Step 0 explicitly checks the file is readable and errors out if not |
| Invoking the script from a subdirectory silently scopes both the CODEOWNERS search and `git ls-files` to that subtree | Step 0 `cd`s to `git rev-parse --show-toplevel` before doing anything else |
| GitHub team ref (`@org/team`) vs user ref (`@user`) API path ambiguity | Step 3 checks for `/` in the slug to route to the team or user endpoint |
| GitLab usernames with dots (`@alice.smith`) misclassified as email | Email guard uses `[!@]*@*.*` (non-@ char before `@`) |
| GitLab `users?username=` exits 0 for empty array | Step 3 inspects the response body for a `"username"` key, not just the exit code |
| `gh` on PATH but not authenticated -- false NOT_FOUND | Auth pre-check disables the `gh` path and emits ADVISORY if unauthenticated |
| GitHub deliberately returns 404 (not 403) for a private team the authenticated user can't see, to avoid confirming its existence -- a valid-but-inaccessible team is reported NOT_FOUND, indistinguishable from a genuinely nonexistent one | Advisory only; verify flagged team refs manually before removing from CODEOWNERS |
| Neither `gh` nor `glab` on PATH (or neither matches the remote type) | Steps 1-2 (unowned files, dead rules) still run fully; only Step 3 (owner validity) degrades to ADVISORY |

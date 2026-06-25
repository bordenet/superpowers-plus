# cr-battery + PHR Session — 2026-06-14

## Status: COMPLETE (2026-06-24)

Branch: `chore/docs-onto-main` (HEAD: 71167b85)

---

## FIXES APPLIED (all verified passing)

### cr-battery findings — DONE

| # | File | Fix | Severity |
|---|------|-----|----------|
| 1 | `AGENTS.md:132` | Removed internal wiki reference (`Source of truth: internal wiki — search "claude-code-self-debug-12-point-action-plan"`) | Critical |
| 2 | `tools/verify-cr-battery-evidence.js:173` | Changed `ENOBUFS` → `ERR_CHILD_PROCESS_STDIO_MAXBUFFER` (Node.js never throws ENOBUFS for maxBuffer overflow; buffer overflow fell through to partial-stdout path) | Important |
| 3 | `tools/pre-push-loc-gate.sh:172` | Thread remote name through `check_pushed_refs` → `enumerate_commits`; use `--not --remotes=<remote_name>` instead of `--not --remotes` (multi-remote repos under-counted LOC for new branches) | Important |
| 4 | `tools/scope-tripwire-check.sh` | Added URL-based dogfood auto-detect: if `origin` URL contains `superpowers-plus`, default to `block` mode (documented in header but not implemented) | Important |

### PHR findings — DONE

| # | File | Fix |
|---|------|-----|
| 5 | `skills/engineering/scope-tripwire/skill.md:83` | Fixed `SCOPE_TRIPWIRE_MODE` default table value: `auto` → `warn` (auto-detect was removed) |
| 6 | `skills/engineering/scope-tripwire/skill.md:89` | Added `https://` to `LINEAR_API_URL` default value |
| 7 | `skills/engineering/scope-tripwire/skill.md` | Updated mode dispatch item 3 from "(removed)" to URL auto-detect now re-added |
| 8 | `skills/engineering/hotfix-charter/skill.md:102` | Added hook-rejection recovery: "If hook rejects: fix the failing section and re-run cr-battery on the staged diff before retrying" |
| 9 | `skills/security/devsec-audit/skill.md:79` | Added non-interactive TTY detection alongside `CI=true` (prevents 120s hang in Codex/SSH) |

### Contamination fixes — DONE

| # | File | Fix |
|---|------|-----|
| 10 | `tools/tests/test_augment_export.sh:126,134` | Overlay repo name in comments → generic "overlay" / "overlay repo" |
| 11 | `skills/engineering/branch-flow-gate/reference.md:107` | Specific overlay path → `any configured overlay repo` |
| 12 | `tools/claude-hooks/pre-tool-use-git-identity.sh:89` | Removed overlay-repo keyword from work-context detection |
| 13 | `claude-config/internal-terms.txt:7-8` | Overlay repo references → generic "overlay" language |
| 14 | `lib/install/deploy.sh:864` | Overlay repo name → `overlay repos` |

---

## REMAINING (not yet done)

All items resolved — see COMPLETED section below.

---

## COMPLETED (2026-06-24 follow-up)

- `CONTRIBUTING.md:76` — already genericized to "no proprietary content" in a prior commit; confirmed.
- `skills/security/devsec-audit/skill.md` — Phase 5 merge procedure present at lines 140-142; confirmed complete.
- `tools/dangerous-pattern-scan.sh` — DRY fix: extracted `track_heredoc` nameref helper; both check functions call it.
- Tests added: `test/pre-push-loc-gate.bats` (11), `test/scope-tripwire-check.bats` (12), `test/language-scanner.test.js` (14), `test/verify-cr-battery-evidence.test.js` (23). All passing.

---

## TEST STATUS
- bats test/hotfix-charter-check.bats: 13/13 ✅
- bats tests/session-handoff-check-test.bats: 13/13 ✅
- bats test/run-battery-flags.bats: 7/7 ✅
- node test/skill-router.test.js: 75/75 ✅
- bats test/pre-push-loc-gate.bats: 11/11 ✅
- bats test/scope-tripwire-check.bats: 12/12 ✅
- node test/language-scanner.test.js: 14/14 ✅
- node test/verify-cr-battery-evidence.test.js: 23/23 ✅
- shellcheck: clean on all modified shell files ✅
- node --check: clean on all modified JS files ✅

---

## CONTAMINATION SCAN RESULT
Final state: Clean. All overlay-repo references genericized. All items resolved.

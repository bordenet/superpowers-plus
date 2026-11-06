# Changelog

All notable changes to superpowers-plus are documented here.

superpowers-plus extends [obra/superpowers](https://github.com/obra/superpowers) by Jesse Vincent.

Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added

- **`incident-revert-review` skill:** reviews a proposed incident revert or rollback and produces a short risk note: what protection the revert removes, what failure it may restore, whether state written since the original change is still readable, an adjacent path to check, and the checks to run after. Read-only; it informs the decision and never approves or blocks it.
- **`tools/review-envelope.py` builds review evidence envelopes:** `init`, `add-clean`, `add-finding`, `resolve`, `set` and `check` write `.cr-battery-runs/<sha>.json` (battery) or `<sha>-llm-skill-review.json` (skill review). Each claim's command runs when the claim is written, through the same replay code the sentinel runners use, and a failing expectation is refused with the observed output. `resolve` moves a fixed finding out of `findings[]` into a clean dimension, so the skill-review gate no longer counts it as open. `resolve` also requires the finding's own evidence to fail before accepting the fix. Parallel writers take a lock, so no claim is lost. `check` replays a temporary copy and leaves the envelope untouched. `tools/verify-cr-battery-evidence.js` `replay()` gains an optional `withOutput` flag so a refused claim's output is shown without running its command twice. New tests in `tests/tools/review-envelope.bats`.
- **`tools/review-preflight.py` does the mechanical part of review triage:** one JSON object with sentinel states (including scope carry-forward), bug-fix mode, diff size and class, `tools/review.sh` routes, the code-review-battery signal rows that fired with file:line hits, rows left to judgment, and whether the small-diff inline review exemption applies. A test fails if the skill's signal table gains a row the script does not encode. Sentinel checks reuse the pre-push gates' own bash: `validate_review_sentinel` and each gate's accepted-verdict set moved from `tools/push-readiness.sh` into `tools/lib/review-sentinel.sh`, which both tools now source. Bug-fix mode follows `tools/run-battery.sh` (`--mode`, `.cr-battery-ticket-prefixes`). New tests in `tests/tools/review-preflight.bats`.
- **Pre-push Gate 8 refuses a branch that is behind its target:** `tools/pre-push-divergence-gate.sh` fetches the branch a push will merge into (`dev`, or `main` for `dev`, `promote/*` and sync branches) and blocks when the pushed commit is missing any of its commits, printing the count and the command to catch up (`git merge` for a `main` target, `git rebase` otherwise). `hotfix/`, `release/`, `backport/` and `tagged-release/` are exempt, `DIVERGENCE_GATE=off` skips it, and an unreachable remote or a shallow clone warns instead of blocking. New tests in `test/pre-push-divergence-gate.bats`.
- **`commit-msg` warns when a message names the review tooling:** `tools/commit-msg-jargon.py` flags subject and body lines that narrate the review process (a tool name such as the battery, a sentinel or PHR next to a word like passed, round or findings), skipping code fences, comments, trailers and the `commit -v` diff. It never blocks, and stays quiet when the staged change edits the review tooling itself. New tests in `tests/tools/commit-msg-jargon.bats`.
- **`tools/wiki-tree-sweep.py` searches a whole wiki page tree:** give it an Outline page and a pattern and it searches that page and every page beneath it, at any depth. `--list` prints the tree and `--jsonl` exports every page with its text. It reads the tree shape in a single API call and page text in batches of up to 100, fetches any page a batch misses on its own, retries rate limits, and exits 3 with empty stdout rather than reporting a partial tree as complete. A raw newline in page text is kept as a line break. The Outline adapter and `wiki-prune-audit` now point here instead of asking agents to write their own recursive walk. New tests in `tests/tools/wiki-tree-sweep.bats`.
- **Claude Desktop guide in the README:** explains what each Desktop tab gets. The Code tab uses the same `~/.claude/` install as Claude Code. Chat and Cowork use uploaded ZIPs. The MCP server works through `claude_desktop_config.json`. `docs/INSTALLATION.md` gives the config file locations.
- **`install.sh` rebuilds the Claude Desktop ZIPs:** every install and upgrade runs `tools/package-for-claude.sh` into `~/superpowers-plus-claude-desktop/` and reports how many ZIPs changed. A packaging problem logs a warning and never fails the install. New tests in `test/package-for-claude.bats`.
- **Native Windows install through Git Bash:** `install.ps1` installs missing prerequisites with winget (Git for Windows, Node.js LTS, Python 3, jq), writes `python3` and `python3.cmd` shims to `~\.local\bin`, sets `CLAUDE_CODE_GIT_BASH_PATH` and `PYTHONUTF8`, and runs `install.sh` under Git Bash. On Windows `install.sh` writes `sp-*` commands as wrapper scripts, because Git Bash's `ln -s` copies. `install.ps1 -Force` bypasses only the ecosystem lock (`SUPERPOWERS_ALLOW_FOREIGN_ECOSYSTEM=1`); it does not pass `install.sh --force`. `install.ps1` refuses to run from an elevated PowerShell unless `SUPERPOWERS_ALLOW_ELEVATED=1`; missing machine-wide prerequisites (Git for Windows, Node.js) are reported with the `winget install` command to run elevated. A new `windows-install` CI job covers the elevated refusal, install, a second run, the `-Force` lock bypass, and uninstall.

### Changed

- **`install.ps1` installs natively on Windows instead of delegating to WSL:** anyone who ran the old WSL wrapper from PowerShell now gets an install in their Windows profile. Existing WSL installs are untouched; run `install.sh` inside WSL as before.
- **`tools/wiki-api` accepts `OUTLINE_API_URL` with or without `/api`:** the Outline adapter documents the instance URL without the suffix, but `wiki-api` posted to `$OUTLINE_API_URL/<verb>` as given, so a setup that followed the adapter got 404s. It now adds `/api` when missing, and limits each request to 120 seconds (`WIKI_API_MAX_TIME`).
- **Pre-push test gate:** the local fast-suite timeout is now 600s by default (was a hard-coded 300s, which the ~4-minute suite exceeded on a loaded machine) and can be set with `PRE_PUSH_TEST_TIMEOUT`. A timeout is now reported as a timeout instead of as a test failure. New tests in `test/pre-push-test-gate-timeout.bats`.
- **Retired fork references removed:** `tools/sp-help.sh`, `superpowers-help`, and `update-superpowers` no longer point at the `bordenet/superpowers` fork, which has not been used since v2.6.0 bundled the obra/superpowers skills.
- **`update-superpowers` and `superpowers-help` corrected:** they now describe what `sp-update` actually does (`install.sh --yes`, then each managed overlay's installer), and `superpowers-help` drops an inaccurate description of skill-name prefixes; `install.sh --check` help no longer mentions a separate core. A new test fails if retired fork or `superpowers-core` references come back.
- **Small fixes:** the `install.sh` header comment version matches its `VERSION` variable; `GEMINI.md` title names both Gemini CLI and Gemini Code Assist.

### Fixed

- **Doctor and installer see skills in a repo checked out under `.worktrees/`:** the skill-name index and the doctor's metadata and reference checks skipped any path containing `.worktrees/`, so a checkout under such a directory looked empty. They now skip only a nested worktree inside the tree being scanned. New tests in `test/test_dest_name_index.bats`.

- **Claude Desktop ZIPs now pass claude.ai's upload checks:** `tools/package-for-claude.sh` writes `SKILL.md`, keeps only the six frontmatter fields claude.ai accepts (any other field fails the upload), and includes each skill's companion files instead of only `resources/`. It no longer runs `rm -rf` on the output directory. It deletes only its own ZIPs and refuses a directory that holds other files. Manifest names are validated before use, and the default output moved to `~/superpowers-plus-claude-desktop/` so it can't overwrite another skill pack's ZIPs. ZIPs built before this release in `~/superpowers-claude-desktop/` use the old format and fail upload; upload from the new folder instead. The packager now overwrites or prunes only ZIPs shaped like the ones it builds, resolves a symlinked `--output` before its safety check, and names the changed skills in its summary. Packaged copies carry a note telling Claude to skip steps that need this repo's scripts. `uninstall.sh --purge` removes the new folder's ZIPs.
- **En-dash no longer flagged as AI slop:** `tools/slop-check.sh`, `detecting-ai-slop`, and `eliminating-ai-slop` flag only the em-dash. The en-dash is correct punctuation for ranges and paired terms. A new test asserts en-dash text passes the gate. The commit-msg hook's ASCII normalization of commit messages is unchanged.
- **Evidence verifier no longer misreports failed commands as timeouts:** `tools/verify-cr-battery-evidence.js` matched "timeout" anywhere in Node's error message, which embeds the command text, so any non-zero exit from a command mentioning "timeout" (including absence checks for it) was reported as a 30s timeout. It now relies on Node's own timeout code (`ETIMEDOUT`). Commands killed by a signal are reported as such instead of as a spawn failure, and an argv-mode command killed by a signal no longer counts as exit 0 (it could previously verify against an `exit_code: 0` expectation). New tests cover the false positive, a real timeout, a timeout of a command that ignores SIGTERM, and both signal cases.

## [5.3.0] - 2026-10-02

### Added

- **`writing-good-tests.md` (TDD skill):** new reference replacing `testing-anti-patterns.md`. Ported from obra/superpowers v6.2 with full string-presence-trap and change-detector-trap falsifiability guidance, plus 3 concrete counter-examples (string presence, change-detector, too-coupled).
- **`finishing-a-development-branch/references/worktree-cleanup.md`:** extracted worktree capture/cleanup logic into a dedicated reference so `skill.md` stays under the 250-line hard limit (was 260 lines, now 241).
- **`subagent-driven-development/re-review-prompt.md`:** re-review prompt template for the 5-round review-loop circuit breaker.
- **`test/find-polluter.bats`, `test/review-package.bats`, `test/sdd-workspace.bats`, `test/task-brief.bats`:** 18 new bats tests covering find-polluter bug fix, review-package script, sdd-workspace PLAN_FILE-first arg, and task-brief script.
- **`brainstorming` three-path router:** ported from obra/superpowers v6.3.0 in condensed form -- classifies each request as spike (answer, no artifact) / bounded (short in-chat design, no spec file, straight to implementation) / architectural (full spec + `plan-and-execute`) before the first clarifying question. The approval gate applies to every path; only the ceremony scales. Ratchet is one-way: hidden complexity mid-task upgrades the path, never downgrades it.
- **`finishing-a-development-branch/references/worktree-cleanup.md`:** worktree-removal-refused handling, ported from obra/superpowers v6.3.0 -- when `git worktree remove` is refused for uncommitted files, show the file list and ask (commit / move / delete) instead of `--force`-ing on its own initiative.
- **"You Do Not Dispatch Subagents" contract**, ported from obra/superpowers v6.3.0, added to `subagent-driven-development/implementer-prompt.md`, `task-reviewer-prompt.md`, `re-review-prompt.md`, and `requesting-code-review/code-reviewer.md`: an implementer or reviewer subagent that spawns its own reviewer duplicates a review seat the controller already scheduled, at full cost, and its verdict counts for nothing.
- **`writing-plans` plan template:** added a `**Spec:**` field naming the spec/design doc the plan implements, ported from obra/superpowers v6.3.0 -- the plan argues from the spec, so the spec travels with it and executors read both.

### Changed

- **README:** leads with the problem and the enforcement model, adds measured AI-Harness results, and states platform support for each documented install path. Install, configuration, and troubleshooting moved to `docs/INSTALLATION.md`; the tools table and quality-gate policy moved to `docs/TOOLS.md`.
- **Skill counts:** Codex and OpenCode install guides, the Cursor manifest, and the Claude plugin manifests now report 124 skills. The Codex and OpenCode guides describe obra/superpowers as bundled rather than separately installed.
- **Repo `TODO.md`** moved to `docs/maintainers/TODO.md`.
- **Gemini CLI** install instructions removed: there is no Gemini extension manifest, and the documented command installed a fork dropped in v2.6.0.
- **Cursor manifest** version synced from 2.5.2 to 5.3.0.
- **Security checklist for overlays** moved from the README into `docs/ENTERPRISE_ADOPTERS_GUIDE.md`; the data-egress note for API keys moved into `docs/INSTALLATION.md`.
- **`docs/SKILL_TAXONOMY.md`** lists `human-comms-hygiene` and counts 124 skills; `UPGRADING.md` count updated. New tests pin the skill count across these files and the changelog heading format that release notes depend on.
- **CHANGELOG:** the 2.6.0 heading now uses the bracketed format, so release notes for a version stop at the next version heading.
- **SDD skill (`subagent-driven-development/skill.md`):** ported from obra/superpowers v6.2 -- plan-scoped workspace support (PLAN_FILE-first arg), resume-based fix loop with ledger-identity-check step, and 5-round review-loop circuit breaker to prevent infinite reviewer disagreements.
- **SDD skill (`subagent-driven-development/skill.md`), "rulings, not stalls":** ported from obra/superpowers v6.3.0 -- a running plan no longer stalls on the human for plan conflicts, plan-mandated review findings, or load-bearing adjudications at the fix-loop cap; the controller rules on them itself (spec is the binding authority, the plan is its argument), records every decision in the ledger as `Ruling: <what> — <why> — <cost if wrong>`, and surfaces the exhaustive "Rulings I made" list before the workspace is deleted. Only four things still stop execution to ask: an irreversible/destructive operation, a security-sensitive action, an out-of-worktree side effect norms require consent for (merge, push to a shared branch, publish), or a plan where every path forward is a guess. Also adds: pre-flight conflict scan now produces a pairwise conflict table (not a batched question), batching guidance for same-shape small tasks, and bounded-wait guidance for idle periods between subagent dispatches. Reduces routine human checkpoints to four narrow safety-consent stops, consistent with `CLAUDE.md`'s distinction between quality-gate ceremony (eliminated) and irreversible or consent-requiring actions (preserved).
- **SDD scripts (`scripts/review-package`, `scripts/sdd-workspace`, `scripts/task-brief`):** updated for PLAN_FILE-first arg and plan-scoped workspace.
- **SDD `task-reviewer-prompt.md`:** updated review-package signature reference.
- **TDD skill (`test-driven-development/skill.md`):** now points to `writing-good-tests.md` instead of the removed `testing-anti-patterns.md`.
- **finishing-a-development-branch skill:** extracted worktree capture/cleanup logic into `references/worktree-cleanup.md` to stay under the 250-line limit.
- **`docs/SKILL_TAXONOMY.md`:** full overhaul. Skill counts corrected (113 → 122 — the doc had not been updated since the 2026-09-08 push/merge-gate port added 9 skills). Added a **Push & Merge Authorization Gates** section and a **Harness Layer** section (Sensor/Actuator/Regulator context-budget loop, previously undocumented here). The Main Orchestration Cascade diagram — 16 nodes with 4 edges forced to cross the full width of the graph — is now two zero-crossing fan-out diagrams (`thinking-orchestrator`, `feature-development`) with the shared targets called out once in prose instead of drawn as crossing arrows. Commit Gate Chain now shows `push-authorization-gate` as the front door. Footer corrected to say which docs are machine-regenerated (`skill-dependency-graph.md`, `SKILL_TOKEN_COSTS.md`) vs. hand-curated (this file).
- **`docs/SKILLS.md`:** added 3 rows missing since their skills were introduced (`codebase-recon`, `domain-build`, `wiki-prune-audit`); moved `knowledge-capture`'s row from the Research section to Productivity, matching its actual filesystem domain (`skills/productivity/knowledge-capture`); corrected every section header count against its own table (Engineering 52→55, Research 3, Productivity 25 — the header already said 25 but the table was one row short).
- **`docs/skill-dependency-graph.md`, `docs/SKILL_TOKEN_COSTS.md`:** regenerated via their own generators (`tools/generate-skill-dag.js`, `tools/skill-cost-analyzer.sh --markdown`) to pick up the 9 skills added since the last run.

### Removed

- **`testing-anti-patterns.md`:** replaced by `writing-good-tests.md`.

### Fixed

- **`spc-kernel-split` renamed to `kernel-split`:** naming-consistency cleanup — skill name, directory, both bats files, trigger (`/sp-spc-kernel-split` → `/sp-kernel-split`), and every doc/tool reference updated. No functional change — internal shell variables (`_spc_ref` → `_ks_ref`, `_spc_loader` → `_ks_loader`) renamed for consistency; all 15 `kernel-split*.bats` tests still pass.
- **`writing-skills/render-graphs.js`:** ported from obra/superpowers v6.3.0 -- `execSync('dot -Tsvg')`/`execSync('which dot')` replaced with `execFileSync('dot', [...])`, so diagram rendering no longer spawns a shell and the graphviz-availability check works on Windows (`which` is not a command there).
- **`sp-doctor` / `sp-update` CLI false positives from the standalone tool install:** the CLIs run `tools/` from `~/.codex/superpowers-plus/tools/`, which has no sibling `lib/install/` or `skills/` tree. `reference-checks.sh` and `metadata-checks.sh` could not find `lib/install/skill-naming.sh`, so alias installs (`brainstorming` → `sp-brainstorm`) were reported as "missing installed reference" (16 false ERRORs) and "orphaned install" (~46 false WARNINGs); `todo-maintenance.py` could not resolve `todo-archive.sh`, failing the doctor's Check 22 TODO-archive smoke test (1 false ERROR). All three now fall back to the registered source checkout (`SPP_SOURCE_DIR` from `~/.codex/.env`); `metadata-checks.sh` emits a WARNING if that also fails rather than degrading silently. `sp-doctor` goes from 18 errors / 55 warnings to 0 errors / 9 benign warnings, matching `bash tools/doctor-checks.sh` from a checkout. New `test/doctor-standalone-layout.bats` and `test/todo-maintenance-standalone.bats` cover the standalone layout.
- **MCP `@hono/node-server` (GHSA-frvp-7c67-39w9):** pin the transitive `serve-static` path-traversal dependency from `1.19.14` to `2.1.0` via `mcp/package.json` `overrides`. `@modelcontextprotocol/sdk` allows `^1.19.9 || ^2.0.5`; the lockfile had settled on unpatched `1.19.14`. Dependabot #1186 proposed the same 2.1.0 bump and was closed without merge.
- **`test/use-skill-cli.test.js` known-skill case:** pointed `PERSONAL_SKILLS_DIR` at the repo `skills/` tree so the test does not require a live `~/.codex/skills` install. Wired the file into `.github/workflows/test.yml` (it was only reached by `tools/test-all.sh`).
- **`find-polluter.sh`:** fixed `./`-prefix and `**/`-collapse bug where the script prepended `./` to paths that already had `./`, causing double-prefix mismatches and silently empty results on some test layouts.
- **`find-polluter.sh` unquoted-expansion bug:** the file loop used `for TEST_FILE in $TEST_FILES`, so the shell word-split *and* glob-expanded the list before iterating. A path containing a space became two bogus iterations pointing at files that don't exist, and a literal filename like `a*.test.ts` was re-globbed and matched its siblings instead of itself. Because the loop body runs `npm test "$TEST_FILE" ... || true`, the resulting failures were swallowed: the offending test was never actually executed and the script reported `No polluter found - all tests clean!` — a silent false negative in a debugging tool. `shellcheck` exits 0 on the original line, so lint could not catch it. Now reads the list line-by-line via a here-string (not a pipe, so the polluter-found `exit 1` still terminates the script). Covered by 2 new regression tests.
- **Prototype-pollution in skill matching (`lib/skill-router.js`):** `tfidfSimilarity`'s
  query-side accumulators, `buildTfIdfIndex`'s per-document `tfidf` map, and
  `expandQueryTerms`'s `CONCEPT_EXPANSIONS` lookup all used plain `{}` objects — a query or
  skill description containing a word like `constructor` resolved through the prototype
  chain to `Object.prototype.constructor` instead of `undefined`, either poisoning the
  match score with `NaN` or throwing `TypeError: expansions is not iterable`. Fixed with
  `Object.create(null)` / `Object.hasOwn()` at all three sites.
- **`buildPipeline()` silently including/omitting a skill whose dependency chain failed
  (`lib/skill-router.js`):** a mandatory (non-optional) skill whose required producer
  failed to resolve was previously added to the pipeline anyway (missing `else` branch);
  fixing that in turn exposed a second gap — the top-level `resolve(targetSkill)` call
  discarded its own return value, so `buildPipeline` still reported `error: null` even
  when the target capability itself never resolved. Both fixed: failed producers now
  correctly exclude the dependent skill, and target-resolution failure now returns
  `error: 'TARGET_RESOLUTION_FAILED'`.
- **Unbounded/hanging recursion via symlink cycles (`lib/skill-discovery.js`):**
  `findSkillsInDir()` had no cycle guard — a domain directory symlinked into an ancestor,
  or two domain directories symlinked into each other, caused recursion to regrow the
  path string every level with no bound; one topology self-limited via OS path-length
  errors, another hung indefinitely. Fixed by threading a visited-realpath `Set` through
  the recursion.
- **MCP server trust-boundary hardening (`mcp/superpowers-mcp.js`):** `use_skill` and
  `match_skills` threw unhandled `TypeError`s on missing/malformed `arguments` (the MCP
  SDK's base `Server` class does not validate call arguments against the declared
  `inputSchema`); both now return a clean `{ isError: true }` response instead.
  `resolveSkillPath`'s suffix-match fallback used a raw `endsWith()`, so any short or
  mistyped `skill_name` (including the degenerate empty string) could silently return an
  unrelated skill's content instead of a not-found result — tightened to require a
  kebab-case segment boundary. `match_skills` also had no upper bound on `query` length;
  a large query blocked the single-threaded server for tens of seconds to minutes (cost
  scales with query length × skill count in `applyHeuristicBoosts`); added a length cap
  at the handler and deduped query terms in the scoring loop as defense in depth.
- **`resolveCoordinationChain()` silently dropping a transitively-missing dependency
  (`lib/skill-router.js`):** `collectPredecessors()` dropped a `requires` target that
  wasn't installed with no warning, unlike its sibling `collectSuccessors()`, which warns
  on a missing `enables` target. Now emits the matching `[WARN]` line.
- **`lib/install/deploy.sh` post-`rm -rf` existence checks blind to dangling symlinks:**
  three sites checked `[[ -e "$path" ]]` after a `rm -rf` to detect a failed removal
  before copying into `$path` — `-e` follows symlinks and reports false for a dangling
  symlink left behind by a failed `rm`, so the guard could miss exactly the failure mode
  it was written to catch. Changed to `-e || -L` at all three sites.

### Tests Added

- `test/skill-router.test.js`: prototype-pollution regression (query/description terms
  like `constructor`/`toString`/`hasOwnProperty`/`valueOf` must not throw or produce
  `NaN` scores) plus a repeated-term amplification smoke check.
- `test/composition-engine.test.js`: `buildPipeline` excludes a skill whose non-optional
  producer fails to resolve and reports `TARGET_RESOLUTION_FAILED` when the target itself
  fails; `resolveCoordinationChain` warns (does not block) on a transitively-missing
  `requires` target.
- `test/skill-discovery.test.js`: `findSkillsInDir` terminates quickly on both an
  ancestor-pointing and a cross-domain symlink cycle, and still discovers a legitimately
  symlinked (non-cyclic) skill directory.
- `mcp/smoke-test.js`: `use_skill`/`match_skills` return `isError: true` (not a throw) for
  missing arguments and an empty `skill_name`/`query`; a single-character `skill_name`
  returns not-found instead of an arbitrary unrelated skill; a malformed `top_n` falls
  back to the default; an oversized `query` is rejected.

## [2.6.0] - 2026-05-15

### Breaking Changes

- **obra/superpowers fold-in** — The installer no longer clones `bordenet/superpowers` as a
  separate prerequisite. All 14 obra skills are now included directly in the superpowers-plus
  skills tree. Existing installations will have `~/.codex/superpowers/` removed automatically
  on the next `./install.sh` run.

### Changed

- Removed `lib/install/superpowers.sh` and all install logic for the obra clone.
- Skills that previously used `overrides: superpowers/<name>` are now standalone.
- Five new skills added from obra: `dispatching-parallel-agents`, `executing-plans`,
  `using-git-worktrees`, `using-superpowers`, `writing-plans`.
- `install.sh` v2.6.0: remove `SUPERPOWERS_DIR` / `SUPERPOWERS_REPO` variables.
- `lib/install/migrate.sh`: removed `migrate_todo_skill_overrides()` (used SUPERPOWERS_DIR).
- `lib/install/deploy.sh`: removed dead `superpowers)` case from `_resolve_upstream_dir()`.
- `install-augment-superpowers.sh`: removed obra clone step; adds migration to remove legacy clone.

### Added

- `settings-hooks-spec.json` now ships `skillListingBudgetFraction: 0.05` — with 230+ skills
  installed the default 1% budget silently drops ~231 skill descriptions from Claude's context,
  breaking auto-triggering. `install-claude-guardrails.sh` now merges non-hooks scalar settings
  from the spec using `max(current, spec)` for numeric keys (never lowers a user-raised value)
  and `setdefault` for other types. Re-running install is safe and idempotent.
- `code-review-battery`: `/sp-cr-battery` slash command (primary, short, easy to type). `/sp-deepreview` retained as legacy synonym.
- `code-review-battery`: optional `[min-score]` argument (1.0–10.0, default 7.0) sets a numeric quality threshold. Score formula: `10.0 − (Critical×2.5) − (Important×1.5) − (Minor×0.25) − (durable<50% ? 0.5 : 0)`, floor 0.0. Score below threshold aborts Phase 6 (no sentinel written). `tools/run-battery.sh` gains `--min-score N` flag; sentinel always records the threshold as field 5 (`min-score=N`).
- `link-verification` golden regression file for compression tests
- **Wiki skills Haiku-runnable standard:** all 8 wiki skills (`wiki-orchestrator`, `wiki-verify`, `wiki-secret-audit`, `link-verification`, `wiki-markdown-structure-gate`, `wiki-content-coherence`, `wiki-refactor`, `wiki-debunker`) rewritten to a procedural contract targeting small-model execution. Contract: `skill.md` ≤100 lines, numbered steps where each step is a concrete shell command / exit-code check / short decision table, overflow to sibling `rationale.md` (existing `references/` pattern). Computable gates delegate to existing tools (`tools/wiki-read.sh`, `tools/wiki-write.sh`, `tools/wiki-scope-check.sh`, `tools/wiki-markdown-validate.js`). Total wiki skill body went from 1,209 → 754 lines (-37%). No YAML frontmatter, trigger, or coordination-graph changes; no behavior changes to the pipeline.
- `skills/wiki/wiki-orchestrator/rationale.md`, `skills/wiki/wiki-verify/rationale.md`, `skills/wiki/wiki-refactor/rationale.md` — sibling files holding philosophy, rationalization-rejection tables, and success-criteria detail extracted from the procedural skill bodies.

### Changed

- **`wiki-verify` default mode:** changed from `Interactive` (prompt-per-finding) to `Fix` (auto-apply). The previous default is now reachable via `--interactive`. `--report` (diff-only, no writes) is unchanged. Motivation: most invocations happen in automated pipelines where interactive prompts stall execution; `--interactive` is the escape hatch for supervised review.

### Removed

- **`spc:` / `spc-` skill-loader prefix** removed from the public loader (`superpowers-augment.js`) and `docs/DESIGN.md`. It was a silent alias of `spo:` / `spo-` and carried organization-specific branding that did not belong in the public artifact. The generic overlay route (`spo:` + `SP_OVERLAY_SOURCE_DIR`) is unchanged. **Migration:** in `use-skill <name>` call sites, `s/spc:/spo:/g` and `s/spc-/spo-/g`. Overlay repos wanting custom branding can wrap the loader in their own script that rewrites prefixes before invoking `use-skill`. **Unaffected:** the Augment slash-menu `/spc-*` trigger-extraction subsystem (`lib/install/deploy.sh`, `docs/ARCHITECTURE.md`, ADR-002) is a separate concept — it picks slash-command directory names from `triggers:` frontmatter and has nothing to do with loader namespace resolution.

### Fixed

- **Test assertion fix (`tests/install-test.bats`):** The success-path test previously
  asserted that `~/.codex/superpowers/skills` *was created* — the opposite of the intended
  behavior. Corrected to assert that `~/.codex/superpowers` is *absent* after install.
  All prior green CI runs on this test were validating the wrong condition.
- **Migration function placement:** `_migrate_remove_obra_clone()` moved from `install.sh`
  to `lib/install/migrate.sh` and called via `post_install_migrations()` — consistent with
  all other migration functions.
- **Migration observability:** Pre-deletion log calls changed from `log_info` to `log_warn`
  so permanent directory removal is visible in warning-filtered output.
- **Doctor/uninstall stale obra references:** Removed `MANAGED_OBRA_DIR` from
  `tools/doctor-checks.sh` and `tools/doctor-modules/checkout-checks.sh`; updated
  `uninstall.sh --purge` help text to reflect v2.6.0 state.
- **`install-augment-superpowers.sh` safety:** Added `${var:?}` guard to rm-rf path and
  added cross-reference comment to paired function in `migrate.sh`.

### Tests Added

- 7 new BATS tests in `tests/claude-guardrails-test.bats`: 3 scalar-merge unit tests,
  1 settings-spec assertion, 3 `_migrate_remove_obra_clone()` migration tests (directory,
  no-op, symlink-only). Migration tests now source the real function from `migrate.sh`.
- Known gap: `install_skills()` in `install.sh` lacks BATS coverage (it's an `install.sh`
  function; `tests/install-test.bats` covers `install-augment-superpowers.sh`). A dedicated
  `tests/install-main-test.bats` is the right fix; tracked as a follow-up.

- **`resolveSkillNamespace` early-error return shape:** the two early-error returns (`SPP_SOURCE_DIR not set`, `SP_OVERLAY_SOURCE_DIR not set`) now include `forceSpp: false, forceSpo: false` to match the documented return contract. Not a live bug (the caller checks `.error` first), but tightens the JSDoc to return-value correspondence.
- **Dormant-skill audit (2026-04-17):** repaired `compat.sh` `--help` leak in sourced-mode scripts (`todo-crud`, `skill-cost-analyzer`, `test-content-coherence`); corrected stale `sp-deepreview` references in `sp-bughunt` to `code-review-battery`; added `--help` handling to `loose-ends`, `run-battery`, `backfill-composition`, `wiki-read`, `wiki-write`, `parse-frontmatter`, `test-content-coherence`; restored executable bit on `test_frontmatter_parsers.sh`; removed deprecated `~/.claude/skills/` path from `update-superpowers`.
- **Compression safety (incident 2026-04-14):** `STRIP_SECTIONS` was deleting operative safety content — `Hallucination Prevention` sections (containing `<EXTREMELY_IMPORTANT>` URL verification rules), `References` sections (pointers to `references/incidents.md`), and `Incident Log/Record/History` sections. All three are now preserved. Wiki authoring was producing broken hyperlinks as a result.
- **`<EXTREMELY_IMPORTANT>` block extraction:** Blocks are now extracted before section stripping and restored after, so they survive even if their parent heading is stripped. Blocks rescued from stripped sections are appended under a `## Critical Rules (preserved from compression)` synthetic heading. Code blocks containing EI tags are protected from extraction.
- **Pre-push mirror policy:** `git fetch origin` now runs before SHA comparison on private-remote pushes to prevent stale-ref bypass. Fetch failure blocks the push (`exit 1`).
- **Stale JSDoc:** `superpowers-augment.js` compression comment now points to `lib/compress.js` as authoritative source.
- **GitLab mirror policy:** Added to `.ai-guidance/invariants.md` (repo-level, always in agent context).

## [1.0.0] - 2026-04-13

### Added

- Skill discovery module, composition engine, workflow state machine, skill router — all with unit tests (227 total)
- CI pipeline with 3 job types: Node.js tests, shell tests (BATS + doctor), quality gates
- Code Review Battery — 5-reviewer sub-agent system with triple-filter synthesis
- Forked Debugging (Preview) — conductor + 5 investigator skills + evidence adjudicator
- Wiki Refactor Pipeline — 7-phase skill for large-scale wiki restructuring
- TypeScript Ecosystem — strict-mode, project-conventions, vitest-testing-patterns
- MCP v3.0.0 — semantic skill matching, multi-source directory support, content compression
- TF-IDF engine for offline skill matching (eliminates OpenAI API dependency)
- 25+ new skills across engineering, productivity, security, and writing domains
- sp-help, sp-doctor, sp-update CLI tools with auto-symlink during install
- Skill auto-composition engine (RFC-001), dependency graph, coordination schema
- Plugin marketplace distribution (.claude-plugin/, .cursor-plugin/, .codex/, .opencode/)
- Mandatory harsh review enforcement system with pre-commit hooks and CI workflow
- Non-interactive install (--yes/-y flag), Ubuntu/WSL support, Windows PowerShell support
- Platform-agnostic skill framework with adapter pattern for wiki and issue-tracking
- Professional language audit, time estimate inflation detection, receiving-code-review skill
- 10 shared reference schemas in skills/_shared/

### Changed

- Parser consolidation — single canonical parser in lib/frontmatter.js
- Doctor script refactored from 1300-line monolith into 8 modules
- install.sh decomposed from 1,163 lines into 380-line orchestrator + 6 modules
- Skill router: named boost constants, deduplicated intent patterns, documented scoring
- README overhaul: dynamic skill counts, Standout Skills table, Quick Start
- Issue-tracking adapter contract: structured output contracts, tri-state exists field
- AGENTS.md promotion model with cadence column and authorization expiry
- Wiki adapter publish contract: executable pre-write validation + post-write verification
- Split large skills (>500 lines) into modular files
- Removed hardcoded vendor references from shared skills

### Removed

- azure-devops issue tracker adapter (recreate from platform-template.md)
- tools/wiki-snapshot.sh (use direct Outline API calls)
- telephony-flow-investigator (proprietary)

### Fixed

- TODO.md protection — 7-layer defense system preventing agent-driven data loss
- IP audit hardening across staged, range-based, and full-file checks
- YAML parser hardening — apostrophe escaping, bracket-multiline handling
- Prototype pollution bug with constructor term causing NaN scores
- Markdownlint audit — 1,757 violations eliminated
- Proprietary content scrub — all proprietary references removed across 4 passes
- Pre-push orphan docs-only exemption for new branches
- Doctor ahead-commit detection for diverged installations
- Trigger collisions resolved
- todo-management deterministic path with hard gate
- Trailing newline issues in 67+ files
- Shell script shebangs standardized

[1.0.0]: https://github.com/bordenet/superpowers-plus/releases/tag/v1.0.0

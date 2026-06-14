---
name: devsec-audit
source: superpowers-plus
augment_menu: true
description: "Full-repo, multi-component DevSec audit producing a consultant-style consolidated security report. Composes repo-security-scan (Phases 1/3/4 only) + read-only CVE-scan commands (cargo audit, npm audit, pip-audit) + auto-installed tooling (cargo-deny, gitleaks, semgrep) + 6 specialist sub-agents mirroring AttackerPersona's 5 threat dimensions plus egress allowlist tracing. Quarterly or pre-release cadence -- NOT per-PR (cost ~80k tokens per repo)."
summary: "Use when: quarterly DevSec audit, pre-major-release security sign-off, or reproducing a consultant-style consolidated report. Not for per-PR review."
triggers:
  - /sp-devsec-audit
  - devsec audit
  - consolidated security audit
  - full-repo security audit
  - quarterly security audit
  - pre-release security audit
  - reproduce the consultant audit
anti_triggers:
  - review my staged changes
  - scan this single file
  - scan a wiki draft
  - quick repo scan
  - quick security scan
  - run a security scan
  - upgrade dependencies
  - check for vulnerabilities
  - audit dependencies
  - scan before commit
coordination:
  group: security
  order: 2
  requires: []
  enables: []
  escalates_to: []
  internal: false
composition:
  consumes: [repo-context, multi-repo-context]
  produces: [security-report, prioritized-remediation-roadmap]
  capabilities: [composes-skills, full-repo-audit, auto-installs-tools]
  priority: 30
---

# devsec-audit

> **Wrong skill?** Per-diff review → `/sp-cr-battery` (Guardian + signal-driven AttackerPersona). Single-file scan → `wiki-secret-scanner`. Quick repo scan → `repo-security-scan`. Dependency-only upgrade → `security-upgrade`. See [security routing skill](../security/skill.md) for the full map.

> **Cost: ~80k tokens per repo audit.** Quarterly or pre-major-release cadence. Not for per-PR -- the per-PR catch is owned by `/sp-cr-battery` AttackerPersona.

This skill **composes** existing security skills rather than re-implementing their work. It does not re-grep for secrets (calls `repo-security-scan` Phases 1, 3, and 4); it does not call `security-upgrade` (which mutates deps -- run that separately after the audit to remediate CVE findings). CVE data is captured via read-only audit commands in Phase 2. Track B of the DevSec-skills integration plan.

## When to Use

- Quarterly security hygiene audit (organizational cadence)
- Pre-major-release security sign-off
- After a significant architecture change (new MCP server, new auth path, new IPC surface)
- Reproducing a consultant-style consolidated DevSec report internally

## When NOT to Use

- Reviewing a PR diff → `/sp-cr-battery`
- Scanning one wiki draft → `wiki-secret-scanner`
- Quick repo hygiene check → `repo-security-scan`
- Just upgrading dependencies → `security-upgrade`
- Auditing a public repo for IP leakage → `public-repo-ip-audit`

If you only need one of those scopes, this skill is overkill and burns tokens.

## Pipeline (6 phases)

### Phase 0: Cost confirmation (mandatory)

Before any work begins, display the following prompt and wait for explicit user confirmation:

> **Confirm audit scope**: This audit will consume approximately 80k tokens per repo audited (~$1-3 per repo at standard rates; Phase 4 dispatches 6 parallel sub-agents which multiply cost for large codebases).
> Repos in scope: [list from user invocation or current working directory]
> Type `proceed` to continue, or `abort` to stop.

Skip this gate only if the user included `--no-confirm` in the trigger invocation (e.g., `/sp-devsec-audit --no-confirm`). Match the literal string `--no-confirm` (case-insensitive, anywhere in the triggering message).

Wait up to 120 seconds for user input. If no response is received: emit "Audit cancelled: no confirmation received within 120 seconds. Re-invoke with `--no-confirm` to bypass this gate." and halt all processing. If the user types `abort`: emit "Audit cancelled by user." and halt.

If `CI=true` is in the environment, OR if running in a non-interactive context detected by the absence of a TTY (`[ ! -t 0 ]` in shell; `!process.stdin.isTTY` in Node), proceed automatically without waiting and note the auto-proceed in the report header.

### Phase 1: Discover

Enumerate components in scope. Walk repo roots and identify:

- Rust crates (`Cargo.toml`)
- Node packages (`package.json` -- both top-level and nested per-MCP-server)
- Python packages (`pyproject.toml`, `requirements.txt`)
- MCP server source trees (`servers/*/` directories)
- Tauri / Electron / native-helper code (`src-tauri/`, `electron/`)

**Skip** any directory under `_disabled/`, `archive/`, or `legacy/`. State the discovered component list before proceeding.

### Phase 2: Existing-skill baseline

Per repo in scope, call the existing security skills:

1. **`repo-security-scan` (Phases 1, 3, and 4 only)** -- Secrets, Insecure Patterns, and Misconfiguration. **Skip `repo-security-scan` Phase 2 (Dep CVEs)** -- this audit runs its own read-only CVE commands in step 2 below to avoid triggering `security-upgrade` through repo-security-scan's Phase 2 mandate. Capture findings; annotate with `[source: repo-security-scan]`.

   **If repo-security-scan does not support phase-specific invocation:** run the full skill but DISCARD its Phase-2 (Dep CVEs) findings from the baseline -- they are superseded by this audit's own Phase-2 CVE scan in step 2. Note in the report: "repo-security-scan Phase 2 findings discarded (superseded by devsec-audit Phase-2 CVE commands)."

2. **CVE scan (read-only)** -- per package manager, run the underlying CVE-reporting command directly so this audit does NOT mutate the dep tree:
   - Node: `npm audit --json`
   - Rust: `cargo audit --json` (if `cargo-audit` is not installed, record "Phase-2 Rust CVE scan skipped -- tool not found; Phase 3 will auto-install via the install matrix" and continue)
   - Python: `pip-audit --format=json` (if `pip-audit` is not installed, record "Phase-2 Python CVE scan skipped -- tool not found; Phase 3 will auto-install via the install matrix" and continue -- do NOT run `pip install pip-audit` here; that install belongs in Phase 3's controlled install protocol)
   - Flutter/Dart: `flutter pub outdated` (reports version staleness, not CVEs; no direct Flutter CVE scanner equivalent to `npm audit` exists -- cross-reference pub.dev advisories manually). Note in report: "Flutter CVE coverage is limited -- manual advisory review required."

   Do NOT invoke `security-upgrade` in this phase -- it mutates `package-lock.json` / `Cargo.toml` / etc. and would corrupt audit reproducibility. `security-upgrade` is the human-driven remediation that runs AFTER this audit completes.

Record outputs as Phase-2 baseline findings. Annotate each with `[source: repo-security-scan]` or `[source: cve-scan]` in the final report.

### Phase 3: Tool-augmented baseline (auto-install)

Run the tools `repo-security-scan` does not already invoke, plus any CVE-scan tools skipped in Phase 2. **Auto-install missing tools** via the user-namespaced package manager appropriate to each. Safety rails:

- Print the install command before running it (give the user a chance to interrupt)
- Record successful installs to `~/.codex/devsec-audit-installs.json` so re-runs skip already-installed tools
- `--no-install` opt-out: if the user's trigger invocation contains the literal string `--no-install` (case-insensitive, word-bounded), or the phrase `skip tool install`, OR if `CI=true` in the environment, skip all installs in Phase 3 (Phase 2 performs no tool installs). Emit "tool not installed -- skipped" for any missing tool.
- If the underlying package manager (brew / cargo / pipx) is itself missing, abort the relevant phase cleanly with a "cannot auto-install -- package manager missing" message. Never fall back to `curl | sh` or `sudo`.

See `reference.md` "Tool install matrix" for the install commands and version pins.

Tools and what they catch:

| Tool | What it catches | Install command |
|---|---|---|
| `cargo-audit` (if skipped in Phase 2) | Rust crate CVEs | `cargo install cargo-audit --locked` |
| `pip-audit` (if skipped in Phase 2) | Python package CVEs | `pipx install pip-audit` |
| `cargo-deny` (advisories, bans, licenses) | License drift, banned crates, advisory matches beyond `cargo audit` | `cargo install cargo-deny --locked` |
| `gitleaks` | Entropy-based secret detection (catches base64 / hex tokens grep misses) | `brew install gitleaks` |
| `semgrep` (p/owasp-top-ten, p/python, p/typescript, p/rust) | Lint-style SAST patterns (eval, deserialization, taint flows) | `pipx install semgrep` |

Note: record semgrep version AND ruleset registry snapshot URL in `~/.codex/devsec-audit-installs.json` for quarterly comparability. Two audits with different ruleset snapshots cannot be compared directly.

Note: `cargo-deny` advisory findings that duplicate Phase-2 `cargo-audit` findings are echo-convergences -- keep one entry at original severity in the final report.

### Phase 4: Specialist sub-agent passes (mirrors AttackerPersona's 5 dimensions + egress)

Dispatch 6 sub-agents in parallel. Each is briefed with the full repo path, the component list from Phase 1, and the relevant taxonomy from `cr-battery/reference.md` (Security taxonomy).

Include this self-limiting instruction in every sub-agent briefing: *"After each grep or search command, count your cumulative output lines. Stop and return your partial findings when you reach 3,000 lines, noting your stopping point so the orchestrator can decide whether to re-dispatch for remaining components."* If a sub-agent reports hitting the 3,000-line limit, the orchestrator splits the remaining component list and re-dispatches the sub-agent for each partition; merge all partial findings in Phase 5 using the procedure below.

**Phase 5 partial-findings merge procedure:** When a sub-agent returns partial findings (hit the 3,000-line limit), re-dispatch it once per remaining partition with the original briefing plus: *"Continue from `<stopping-point>`. Examine only: `<remaining-components>`."* Collect all per-partition result sets. In Phase 5, deduplicate by `file:line` (keep the entry with the higher severity if duplicated; add note `[severity disputed across partitions — verify manually]`), append a coverage note to the per-component section ("Sub-agent split into N partitions; findings merged"), and mark the overall audit header with "Phase 4 used partitioned dispatch."

| Sub-agent | Dimension | Method |
|---|---|---|
| `credential-flow-tracer` | Credential-flow trace (T1/M1 class) | For every secret read in the repo (`env::var(`, `process.env.`, `secretsmanager:GetSecretValue`, age-decrypt), grep the call graph for outbound HTTP/SDK calls; flag any path where URL is not a string-literal allowlisted host. |
| `ai-agent-boundary-tracer` | AI-agent trust boundary (M2/M3/C1 class) | For every MCP `tool` registration, `#[tauri::command]`, and IPC handler, document: (a) max harmful side effect, (b) human-approval gate or absence, (c) audit log or absence. |
| `sql-ident-tracer` | Identifier-vs-value confusion (M4 class) | Grep for SQL construction (`INFORMATION_SCHEMA`, `${name}` in SQL, `format!("SELECT ... {}", ident)`); classify each interpolated token as value-or-identifier; flag identifier paths regardless of value parameterization. |
| `cookie-session-tracer` | Cookie / session impersonation (T1539 / T1555.003 class) | For every cookie / session-token / browser-profile read, follow the data to its first network or IPC boundary; verify same-origin enforcement OR per-call user confirmation gate exists before the read completes. |
| `revival-revalidator` | Revival re-validation | Find the most recent prior audit timestamp by checking BOTH `docs/security/devsec-audit-*.md` in the audited repo (glob sorted descending) AND `~/.codex/security-reports/devsec-audit-<repo-slug>-*.md`; use whichever is more recent. Default to 90 days if no prior audit exists. Enumerate paths that moved OUT of archive dirs (renames FROM, not TO): `git log --diff-filter=R --find-renames --since=<date> --name-status | awk '/^R[0-9]/{if ($2 ~ /^(_disabled\|archive\|legacy)\//) print}'`; for each renamed path, read `git log --all -- <new-path>` to recover the original disable rationale; apply the four threat dimensions above to the current call graph. |
| `egress-allowlist-tracer` | Network egress map | Enumerate every `reqwest::`, `fetch(`, `http.Get(`, equivalent, across all repos in scope. Build a map of {component → host}. Flag any caller-controlled URL, any non-internal host, any wildcard. |

Each sub-agent produces structured findings with file:line evidence and the CWE/OWASP/MITRE tags from `cr-battery/reference.md` "Security taxonomy."

### Phase 5: Aggregate + report

Produce a consolidated report at `docs/security/devsec-audit-YYYY-MM-DD-HHMM.md` (UTC time) in the audited repo (or `~/.codex/security-reports/devsec-audit-<repo-slug>-YYYY-MM-DD-HHMM.md` for cross-repo runs -- co-located with the installs JSON in the same ecosystem). The HH-MM suffix prevents same-day re-runs from overwriting earlier results. See `examples.md` for the canonical output shape.

The report has **7 required sections** (canonical spec lives in `reference.md` "Output template"):

1. **Header** -- audit date, audited repo(s) + commit SHAs at audit time, tool versions actually run (or skipped), token cost, semgrep ruleset registry snapshot URL. Also include an explicit **out-of-scope list**: containers/IaC (if any), vendored blobs, third-party SDK internals not read from source, git history beyond HEAD. Silence on an item in the out-of-scope list means "not examined," not "clean."
2. **Overall risk verdict** -- Low / Moderate / Moderate-to-High / High with one-paragraph rationale.
3. **Master severity table** -- every finding with severity, CWE/OWASP/MITRE tag, component, file:line, confidence tier. Sorted Critical → Important → Minor.
4. **Per-component section** -- findings grouped by repo / sub-component, expanded with Why / Fix / Regressions Risked / Durable Check.
5. **What's clean** -- positive affirmation of what the audit verified is sound. Affirmation matters; an all-negatives report is not a complete audit.
6. **Prioritized remediation roadmap** -- grouped by class (e.g., "T1 + M1 are the same SSRF class -- fix together"). Each cluster lists fix order, owner, rough effort.
7. **Confidence & caveats** -- list every Unverified finding (needs upstream check) and every By-design item (documented accepted risk).

## Anti-overlap

- Do NOT run `repo-security-scan` separately on the same repo in the same session -- this skill already calls it (Phase 2).
- `security-upgrade` is NOT called by this skill (Phase 2 step 2 now runs the underlying CVE-scan commands directly). You may invoke `security-upgrade` AFTER this audit completes to remediate the CVE findings -- treat that as a separate human-driven workflow, not an extension of this audit run.
- Do NOT run `/sp-cr-battery` on the same diff window -- this is full-repo, not per-diff.

If `/sp-cr-battery` was already run in this session on staged changes, this skill is additive (it covers the full repo, not just the diff).

## Failure modes

| Failure | Recovery |
|---|---|
| `repo-security-scan` fails on one repo | Note in per-component section; run Phase-2 CVE commands independently; continue. Do not abort the whole audit. |
| CVE-scan command fails (corrupt lockfile, missing lock, unresolvable peers) | Note failure with error text in per-component section; mark that ecosystem as "CVE coverage incomplete -- manual review required"; continue with remaining ecosystems. |
| `gitleaks` reports false positives on test fixtures with dummy secrets | Add to the per-repo allowlist (path glob); document the allowlisted paths in the audit report. |
| `semgrep` install requires Python 3.10+ that is missing | Skip semgrep phase; note in report; do not abort. |
| Sub-agent exceeds 3,000-line or 5-minute budget | Orchestrator splits by component and re-dispatches; merge partial findings in Phase 5. |
| Two sub-agents converge on the same finding from different angles | Promote to at least Important (true convergence); merge their rationale in the report. |
| All sub-agents report "no findings" | Flag `UNANIMOUS CLEAN` and verify coverage: each sub-agent must output the top 5 file patterns it grepped and count of matches examined. Minimum: 10 distinct source files per sub-agent. If any sub-agent shows fewer than 10 files, re-dispatch with an explicit file listing from Phase 1. |
| `~/.codex/devsec-audit-installs.json` corrupt / unreadable | Treat as empty (proceed as if no tools installed); warn in the report header; rebuild the file from successful installs in this run. Do NOT abort. |

## Companion Skills

- `repo-security-scan` (Phase 2 sub-skill -- Phases 1/3/4 only) · `security-upgrade` (post-audit remediation -- run separately after this audit) · `code-review-battery` (per-diff complement) · `attacker-persona` reviewer (dimensions are shared) · `security` (routing index)

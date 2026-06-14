# devsec-audit -- Reference

Companion to `skill.md`. Holds the tool install matrix, output template, sub-agent briefing template, and confidence-tier definitions.

## Tool install matrix (Phase 3 auto-install)

| Tool | Install command (user-namespaced) | Version pin | Aborts on |
|---|---|---|---|
| `cargo-deny` | `cargo install cargo-deny --locked` | latest (pin via `Cargo.lock` if needed) | `cargo` itself missing |
| `gitleaks` | `brew install gitleaks` | latest (Homebrew tap) | `brew` itself missing |
| `semgrep` | `pipx install semgrep` | latest | `pipx` itself missing (do NOT fall back to plain `pip install` -- pollutes user env) |
| `cargo-audit` | `cargo install cargo-audit --locked` | latest | `cargo` itself missing |

**Behavior:**

1. Before running each tool, check `~/.codex/devsec-audit-installs.json` -- if the tool is recorded as installed and the binary is on `$PATH`, skip the install step.
2. If the tool is missing AND `--no-install` was NOT passed, print the exact install command on its own line (so the user can interrupt), then run it.
3. On install success, append a record to `~/.codex/devsec-audit-installs.json` with `{tool, version, install_command, timestamp_iso}`. Use ISO 8601 UTC.
4. On install failure (network, transient), report the failure, skip the corresponding phase, continue with remaining tools.
5. If the underlying package manager (brew / cargo / pipx) is itself missing, do not attempt any fallback. Abort that phase with `cannot auto-install <tool> -- <package-manager> is not installed; install <package-manager> manually or pass --no-install to skip`. Never use `curl | sh`. Never use `sudo`.

**`--no-install` mode:** for each tool, if binary is not on `$PATH`, emit a "tool not installed -- phase skipped" line in the report's per-component section and continue.

## Output template (Phase 5)

Required file: `docs/security/devsec-audit-YYYY-MM-DD-HHMM.md` (UTC time) in the audited repo. The HHMM suffix prevents same-day re-runs from overwriting prior results. For cross-repo audits where no single repo owns the report, use `~/.codex/security-reports/devsec-audit-<repo-slug>-YYYY-MM-DD-HHMM.md` (co-located with the installs JSON in the same ecosystem; do NOT write to `~/.claude/` -- that mixes ecosystems). For any invocation auditing more than one distinct git repository root, or invoked from outside a git working tree, use the `~/.codex` path; otherwise write to `docs/security/` in the single audited repo.

### Required sections (in order)

1. **Header**: audit date, audited repo(s) + commit SHAs at audit time, tool versions actually run (or skipped), token cost.
2. **Overall risk verdict**: one of `Low` / `Moderate` / `Moderate-to-High` / `High` -- with a one-paragraph rationale.
3. **Master severity table**: every finding, sorted Critical → Important → Minor. Required columns: `ID`, `Severity`, `Finding`, `Component`, `File:Line`, `Tags ([CWE-XXX] [OWASP A##] [MITRE T####])`, `Confidence tier`.
4. **Per-component findings**: section per repo / sub-component; expand each finding from the master table with: full issue description, Why, Fix, Regressions Risked, Durable Check.
5. **What's clean (positive findings)**: explicit affirmation of what the audit verified is sound. Examples: "all SQL paths in mssql-server are parameterized", "all egress destinations are organization-internal except `<list>`", "Zendesk attachment SSRF controls are exemplary". An all-negative report is incomplete -- if you cannot list at least 3 positives, your audit did not look at the safe code.
6. **Prioritized remediation roadmap**: cluster findings by class (e.g., "Token-follows-URL class: T1+M1 -- fix together"). Each cluster lists fix order, suggested owner, rough effort (S/M/L).
7. **Confidence & caveats**: list every Unverified finding (needs upstream check, third-party SDK URL handling) and every By-design item (documented in-tree as accepted risk).

## Confidence tiers

| Tier | Criteria |
|---|---|
| **Confirmed** | File:line evidence in the audited tree at the audit-time SHA. Issue is reproducible by reading the code. |
| **Unverified** | Class-level concern in third-party / vendored code that was not read first-hand. Example: "Azure DevOps MCP package may forward URLs to attacker-controlled hosts -- not confirmed from source." |
| **By-design** | Tracked as accepted risk with rationale in the repo (CLAUDE.md, ADR, or in-source comment). Example: "Monday MCP stores Bearer token plaintext in AI-client config -- catalog already flags this; mitigation = 0600 perms + rotation." |

Findings with confidence below 60% MUST NOT appear in the report. Findings at 60-80% MUST be prefixed `Possible: ...` in the issue line.

## Sub-agent briefing template (Phase 4)

Each sub-agent receives the same scaffold prompt with dimension-specific instructions slotted in:

```
You are running a Phase 4 specialist sub-agent for /sp-devsec-audit.

Audited repo(s):    <list with absolute paths>
Audit-time SHA(s):  <commit SHAs per repo>
Component list:     <Phase 1 output>
Skipped paths:      <_disabled/, archive/, legacy/, node_modules, .git>

Your dimension: <Credential-flow trace | AI-agent trust boundary | SQL identifier-vs-value | Cookie/session impersonation | Revival re-validation | Egress allowlist>

Your method: <slotted from skill.md Phase 4 table>

Your taxonomy: read the "Security taxonomy" section of `code-review-battery/reference.md` (resolve relative to this skill repo's root -- it lives under `skills/engineer/code-review-battery/`). Tag every finding with [CWE-XXX] [OWASP A##] [MITRE T####] where applicable.

Output: structured findings list with {severity, tags, component, file:line, issue, why, fix, regressions_risked, durable_check, confidence_tier}. The `component` field MUST match a name from the Phase 1 component list in your briefing (so the orchestrator can group findings per-component without re-deriving from file:line). Do NOT produce prose summaries -- the orchestrator aggregates.

Confidence gate: skip findings below 60% confidence. Mark 60-80% as `Possible: ...`. Report >=80% at standard severity.

Stay in your dimension. Do not report findings that fall in sibling dimensions or in Guardian's coverage zone (basic injection, secrets in code, auth bypass, path traversal, deserialization). Those are handled by other sub-agents or by Phase 2 sub-skills.
```

## Anti-overlap (do not double-count findings)

The same vulnerability may be detectable by multiple agents. Phase 5 aggregation applies the cr-battery convergence rule:

- **True convergence** (different reasoning paths): promote severity one tier; merge into one report entry with both rationales.
- **Echo convergence** (same evidence, same path): keep one entry at original severity; cite both sources.

Findings from Phase 2 sub-skills (`repo-security-scan` Phases 1/3/4 only) and Phase 2 CVE-scan commands are first-class -- do not silently dedupe against them. Annotate the source (`[source: repo-security-scan]` or `[source: cve-scan]`) in the master table. Note: `security-upgrade` is NOT called by this skill -- it is post-audit remediation run separately by the user.

## Multi-repo behavior

When auditing multiple repos in one run (e.g., `superpowers-plus-toolkit` + `mcp-servers`):

- Phase 1: enumerate components per repo
- Phase 2-4: run per repo, but specialist sub-agents that need cross-repo context (egress allowlist tracer especially) get all repo paths in their briefing
- Phase 5: ONE consolidated report covering all repos; per-component sections grouped by repo

## See Also

- `skill.md` -- main procedure (6 phases: Phase 0 cost confirmation through Phase 5 aggregate + report)
- `examples.md` -- canonical output shape with anonymized excerpt
- `../security/skill.md` -- security skills routing index (sibling skills, anti-overlap rules)
- `../../engineer/code-review-battery/reference.md` -- Security taxonomy (CWE/OWASP/MITRE tag reference, canonical fix patterns) -- the source-of-truth that this skill's sub-agents cite
- `../../engineer/code-review-battery/reviewers/attacker-persona.md` -- the per-diff reviewer whose 5 threat dimensions Phase 4 sub-agents mirror

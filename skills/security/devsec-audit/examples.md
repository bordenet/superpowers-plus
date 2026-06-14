# devsec-audit -- Examples

Canonical output shape. Use this as the template for every audit run. Findings are illustrative -- they are NOT a real audit; replace with actual findings when running.

## Example report shell

```markdown
# Consolidated DevSec Audit
<repo-name(s)> -- <commit-SHA(s)> -- <audit-date>

## Audited Scope

- <repo-1> (<crate / package list>)
- <repo-2> (<components>)

Tools run: cargo-deny <ver>, gitleaks <ver>, semgrep <ver>, cargo-audit <ver>, repo-security-scan (4 phases), cve-scan (npm audit / cargo audit / pip-audit / dart pub outdated).
Tools skipped: <list with reasons>.
Token cost: <estimate>.

## Overall Risk Verdict

**<Low | Moderate | Moderate-to-High | High>** -- <one-paragraph rationale referencing the cluster of findings driving the verdict>.

## Master Severity Summary

| ID | Severity | Finding | Component | File:Line | Tags | Confidence |
|---|---|---|---|---|---|---|
| T1 | HIGH | Token-follows-URL SSRF in installer backend | toolkit | src-tauri/src/lib.rs:NNN | [CWE-918] [OWASP A10] | Confirmed |
| M2 | HIGH | AI-agent can dispatch destructive operation with no human gate | server-X | path/to/server.py:NN-NN | [CWE-862] [OWASP A07] | Confirmed |
| M4 | HIGH | SQL identifier interpolation bypasses parameterization | server-Y | path/to/tool.ts:NN-NN | [CWE-89] [OWASP A03] | Confirmed |
| C1 | MEDIUM->HIGH* | Silent cookie harvest with no consent gate | server-Z | path/to/extract.js:NN | [MITRE T1539] [MITRE T1555.003] | Confirmed |
| T2 | MEDIUM | File permissions not enforced 0600 at creation | toolkit | path/file.rs:NN | [CWE-276] | Confirmed |
| T4 | MEDIUM | CI lacks dependency / secret / SAST gates | both repos | .gitlab-ci.yml | -- | By-design |

\* MEDIUM on technique alone, HIGH under the agent-triggerable threat model.

## Section A -- <repo-1>

### T1 -- Token-follows-URL SSRF (HIGH, [CWE-918] [OWASP A10])

**File:** `src-tauri/src/lib.rs:NNN` (`probe_env_var`)

**Issue:** A backend IPC command performs an outbound request to a target derived from agent/frontend-supplied input, with credentials attached. An attacker-influenced value can point the authenticated probe at an arbitrary host.

**Why:** Prompt-injected LLM in the renderer supplies an attacker-chosen URL; the secret is exfiltrated.

**Fix:** Allowlist probe hosts to known internal domains; reject absolute / agent-supplied URLs; never attach a secret to a non-allowlisted host.

**Regressions Risked:** Future legitimate alternate-host deployments need an env-var allowlist override path.

**Durable Check:** Add a CI rule: any `reqwest::Client::post` call whose URL is not a string literal MUST go through the allowlist guard.

**Confidence:** Confirmed.

[... additional findings expanded in same shape ...]

## Section B -- <repo-2>

[... per-component expansion ...]

## What's Clean (Positive Findings)

- All SQL paths in `<server-A>` and `<server-B>` are parameterized -- only the M4 identifier path is broken.
- All egress is first-party except the M1/T1 class -- audited every `reqwest::` / `fetch(` call.
- `<server-X>` attachment handling is exemplary -- MIME allowlist + magic-byte check + size cap + auth-header strip on cross-origin redirect.
- Cryptographic core (AES-256-GCM + keychain passphrase) is sound.
- `cargo-deny` advisories pass clean on the workspace.

If you cannot list at least 3 positives, your audit did not look at the safe code. Re-run the relevant sub-agent.

## Prioritized Remediation Roadmap

1. **T1 + M1 -- Token-follows-URL class.** Same defect class in two components. Fix together: introduce a shared host-allowlist helper; reject agent-supplied URLs at every credentialed-request boundary. Owner: <team>. Effort: M.
2. **M4 -- SQL identifier interpolation.** Fix in both `<server-X>` and `<server-Y>` with `QUOTENAME()` / `pg.escapeIdentifier()`; add adversarial unit tests for `[x']; DROP TABLE users; --]`. Owner: <team>. Effort: S.
3. **M2 + M3 -- AI-agent destructive ops with no human gate.** Out-of-band human-approval token, append-only audit log on every attempt. Owner: <team>. Effort: M.
4. **C1 + C2 -- Cookie harvest consent gate.** Explicit consent gate per call, remove silent auto-re-harvest. Owner: <team>. Effort: M-L.
5. **T2 / T3 / M8 -- File permissions, IPC validation, secret storage.** Enforce 0600 at creation; validate component_id against catalog; migrate cookies to keychain. Owner: <team>. Effort: S each.
6. **T4 -- CI security gates.** Add `cargo-deny`, `gitleaks`, `npm audit`, SAST. Non-blocking ramp then blocking. Owner: <team>. Effort: M.

## Confidence & Caveats

- **Confirmed (file:line evidence):** T1-T3, M1-M10, M10b, L1-L4, C1-C3.
- **Unverified / needs upstream check:** M11 (third-party MCP package URL handling not read from source).
- **By-design / documented:** M12 (HTTP-transport MCP -- token plaintext is documented in the catalog with mitigations).

Re-verify line numbers and tool versions before re-circulating; this report is a snapshot at the audit-time SHA listed in the header.
```

## How to use this template

1. Copy the structure exactly. Section ORDER matters -- the header, verdict, master table, per-component, what's clean, roadmap, caveats. Reviewers scan top-down.
2. Every row in the master severity table MUST appear in exactly one per-component section with the expanded details (severity, issue, why, fix, regressions, durable check, confidence).
3. The "What's clean" section is mandatory. An all-negatives report indicates the audit did not look at the safe code -- re-run the relevant sub-agent.
4. Prioritize the roadmap by **class**, not by finding-ID. Finding T1 and finding M1 are often the same defect type in two components -- they should be one roadmap line, not two.
5. Confidence tiers are non-negotiable: every finding gets one of `Confirmed`, `Unverified`, `By-design`. Never publish a finding below 60% confidence.

## Anti-patterns in audit reports

| Anti-pattern | Why it fails | Fix |
|---|---|---|
| Wall of findings with no class clustering | Reader can't see the underlying patterns; remediation feels endless | Cluster by class in the roadmap; T1 + M1 (same SSRF class) become one line, not two |
| No "what's clean" section | Reader assumes everything is broken; loses trust in the audit's calibration | Cite at least 3 positives with evidence (parameterized SQL paths, allowlisted egress, exemplary attachment controls, etc.) |
| Findings without CWE/OWASP/MITRE tags | Can't aggregate across audits or match against framework guidance | Tag every finding using the taxonomy in `cr-battery/reference.md` |
| Severity scored on technique alone, ignoring agent-amplification | Misses the case where an LLM can trigger silently | Apply the threat-model severity multiplier (one-tier bump when LLM-triggerable with no human gate) |
| Per-finding fix proposed in isolation | Two findings get two fixes when they have one shared root cause | Roadmap clusters by class; fix proposals reference the shared mitigation |

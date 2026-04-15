---
name: sp-bughunt
source: superpowers-plus
augment_menu: true
triggers:
  - /sp-bughunt
  - spot the worst bugs
  - find the worst bugs
  - what are the worst bugs
  - hunt for bugs
  - bug hunt
  - find critical bugs
  - audit for bugs
  - worst bugs in
  - top N bugs
  - most dangerous bugs
anti_triggers:
  - debug this error
  - fix this failure
  - test is failing
  - reproduce this bug
  - security scan
  - scan for secrets
description: "Proactive adversarial bug hunt — dispatches a parallel explore sub-agent to read the codebase with an adversarial mindset, then independently verifies each candidate to catch false positives and missed findings. Returns N worst bugs ranked by severity with exact file, line, mechanism, and failure mode. Use when you want to proactively find the highest-impact bugs in a codebase, not when debugging a known failure (use sp-debug for that)."
summary: "Use when: proactively hunting for the worst latent bugs in a repo or path. Produces severity-ranked findings with file+line+failure-mode. Default: top 2."
coordination:
  group: engineering
  order: 2
  requires: []
  enables: ["sp-debug", "sp-verify"]
  escalates_to: []
  internal: false
composition:
  consumes: [repo-path, scope-hint]
  produces: [bug-report, severity-ranking]
  capabilities: [adversarial-analysis, parallel-exploration]
  priority: 15
---

# sp-bughunt — Adversarial Bug Hunt

> **Wrong skill?** Known failure to debug → `sp-debug`. Security secrets/vulns → `sp-scan`. Code review of a diff → `sp-deepreview`. PR inline review → `sp-review`.

Proactively find the highest-severity latent bugs in a codebase — bugs that cause
silent failures, data corruption, incorrect behavior, or security issues — without
waiting for them to surface in production.

## When to Use

- User says "spot the worst bugs", "find the worst N bugs", "bug hunt", "what's the worst bug in X"
- Before a release or audit, to find latent issues that haven't triggered yet
- After adding a significant feature, to check for emergent issues
- Periodic hygiene ("what's lurking in this codebase?")

NOT for: debugging a known failure (`sp-debug`), reviewing a PR diff (`sp-deepreview`),
security credential scanning (`sp-scan`).

## Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `N` | 2 | Number of worst bugs to return |
| `scope` | current repo | Directory or file glob to search |
| `focus` | all | `logic`, `security`, `data-loss`, `performance`, or `all` |

Parse from user message. If ambiguous, use defaults and note them.

## Protocol (4 phases — complete in order)

### Phase 1: Scope Resolution

1. Identify the target path from the user's message (default: current repo root)
2. List key files likely to contain high-severity bugs:
   - Entry points, auth/security paths, data write paths, background jobs, shell scripts
   - Avoid: auto-generated files, vendored deps, pure config, markdown
3. Note any focus constraint (`logic` / `security` / `data-loss` / `performance`)

### Phase 2: Adversarial Exploration (sub-agent)

Dispatch a **single `explore` sub-agent** with this instruction template:

```
You are doing an adversarial bug audit of <SCOPE>.
Find the worst <N> bugs — bugs that cause silent failures, data corruption,
incorrect behavior, or security issues. Focus on <FOCUS>.

For each candidate:
- Read the relevant code carefully (do not skim)
- Explain the exact lines involved
- Explain WHY it is a bug (not a style issue)
- Describe the failure mode (what actually goes wrong)
- Rate severity: CRITICAL / HIGH / MEDIUM / LOW

Rank all candidates by severity. Return the top <N> with exact file paths
and line numbers. Be thorough — read as many files as you need.
```

Do NOT attempt to verify candidates yourself during this phase — just collect.

### Phase 3: Independent Verification (mandatory)

For EACH candidate the sub-agent returned:

1. **Read the actual lines** — do not rely on the sub-agent's quotes (they may be paraphrased or hallucinated)
2. **Trace the failure path** — follow the code to confirm the bad outcome actually occurs
3. **Check for mitigations** — is there error handling elsewhere that prevents the failure?
4. **Classify each finding:**
   - ✅ Confirmed — real bug, failure mode verified
   - ⚠️ Partial — real issue but severity overstated or understated
   - ❌ False positive — not a bug (explain why)
5. **Add any findings the sub-agent missed** that you notice during verification

### Phase 4: Ranked Report

Present findings ranked by verified severity. For each confirmed bug:

```
### Bug #N — <title> (<VERIFIED_SEVERITY>)

**File:** `<path>`, `<function>()`, line <N>
**Mechanism:** <one sentence: what the code does wrong>
**Failure mode:** <what actually happens to the user/system>
**Evidence:** <exact code snippet, ≤8 lines>
**Fix sketch:** <one-paragraph description of the correct approach>
```

Include a brief note for each ❌ false positive explaining why it was rejected.

## Quality Gates

- **Never skip Phase 3.** Sub-agents hallucinate line numbers and misquote code. Independent verification is what separates real findings from plausible-sounding fiction.
- **Severity must be justified.** "Critical" requires a concrete failure path — not theoretical or requiring unusual preconditions.
- **False positives must be explicit.** If the sub-agent found N candidates and you confirm M < N, list the rejected ones and why.
- **File+line is mandatory.** A bug without an exact location is not actionable.

## Failure Modes

| Failure | Symptom | Recovery |
|---------|---------|----------|
| Accepted sub-agent output without verification | Reported wrong line numbers or non-bugs | Re-read actual code; mark as unverified until confirmed |
| Searched only obvious files | Missed bugs in utility code or error paths | Expand scope; check all callers of the suspicious function |
| Confused style issues for bugs | Low-severity "findings" crowd out real bugs | Re-apply severity rubric: must have a concrete failure mode |
| Sub-agent timed out or missed files | Incomplete exploration | Manually read the high-risk files from Phase 1's list |

---
name: codebase-recon
source: superpowers-plus
augment_menu: true
triggers: ["/sp-codebase-recon", "investigate this feature area", "how does this work across repos", "find all the places that", "do an RCA", "RCA investigation", "RCA on", "wide-band investigation", "codebase reconnaissance", "what's the blast radius", "find all ungated paths", "audit this area"]
description: Use when investigating a feature area, doing an RCA, or auditing code across multiple repos and perspectives. Runs structured searches through 8 lenses (security, auth, data flow, error handling, config/secrets, test coverage, API surface, cross-repo consistency) and produces a findings table with evidence.
summary: "Use when: investigating across repos/perspectives — RCA, security audit, feature area exploration."
coordination:
  group: engineering
  order: 1
  requires: []
  enables: [surgical-fix]
  escalates_to: [progressive-harsh-review]
  internal: false
composition:
  produces: [investigation-report]
  consumes: [user-intent]
  capabilities: [codebase-search, git-blame, cross-repo-analysis]
  priority: 60
  optional: false
  requires_all: false
---

# Codebase Recon — Wide-Band Investigation

> **Purpose:** Systematic multi-lens investigation of a feature area, producing structured findings with evidence.

**Announce at start:** "I'm using the **codebase-recon** skill to investigate this area across 8 lenses."

## Reference index

Load `reference.md` for full grep commands and checklists behind each lens (section: `Lens Search Patterns`).

---

## When to Use

**Use codebase-recon when:**
- Root cause is UNKNOWN — you can't write "the bug is X in file Y because Z"
- The defect might span multiple repos or call chains
- You need to map blast radius before changing shared code
- The request is "how does this work?" or "find all places that..." — exploration, not a fix
- Pre-fix investigation to scope a `surgical-fix` (result: feeds directly into surgical-fix Phase 0)

> **Handoff:** codebase-recon → produces investigation report → surgical-fix Phase 0 consumes it. Do NOT switch without a written scope statement.

---

## Phase 0: Scope & Anchor (5 min)

1. **Define the investigation target** — a feature name, bug report, ticket, or area of concern.
2. **Identify all repos that could be involved.** Ask the user if unclear.
3. **Create a coverage map** — a table tracking what has/hasn't been searched:

```markdown
| Repo | Searched | Files checked | Findings |
|------|----------|---------------|----------|
| repo-a | ☐ | 0 | 0 |
| repo-b | ☐ | 0 | 0 |
```

4. **Set the output document location** (wiki page, local file, or inline).

---

## Phase 1: Cross-Repo Entry Point Search (10 min)

Run these searches across ALL repos in scope. Record every hit.

```bash
# Primary search — adapt KEYWORD to feature area, EXTS to language
grep -rn 'KEYWORD' --include="*.ts" --include="*.js" --include="*.py" REPO_PATH | head -50
```

**Output:** A ranked list of files by relevance. Open the top 5-10 in the viewer to understand data flow.

---

## Phase 2: Run All 8 Lenses (30-45 min)

Run each lens IN ORDER. Each lens has specific search patterns and a checklist. Record ALL findings in the master table (Phase 3 format). Full search commands: see `reference.md`.

### Lens 1: Authentication & Authorization
Find every entry point (public HTTP handlers, exported API routes) and verify auth enforcement and account scoping.

### Lens 2: Security — Injection & Secrets
Find SQL injection risks (parameterized queries absent), hardcoded API keys/secrets, and debug dump endpoints.

### Lens 3: Feature Gating & Entitlement
Verify feature visibility is gated by plan/tier/flag, not just by whether data happens to exist.

### Lens 4: Data Flow — Where Does Data Come From and Go?
Trace data from database queries → server → client → outbound integrations (HTTP calls, webhooks, etc.).

### Lens 5: Error Handling & Fail Mode
Determine what happens when things go wrong: gate queries must fail CLOSED, errors must be logged (not swallowed), users see graceful degradation, not stack traces.

### Lens 6: Test Coverage
Find test files: `find REPO_PATH -name "*test*" -o -name "*spec*" | grep -i 'KEYWORD'`.

### Lens 7: Cross-Repo Consistency
Verify identical behavior across repos: same data references, same gating logic, no diverged copy-pastes.

### Lens 8: Git Blame & Change History
Understand WHO introduced WHAT and WHEN. **Run AFTER** Lenses 1-7 are complete — collect findings first, then git-blame all of them in one pass.

---

## Phase 3: Findings Table (10 min)

```markdown
| # | Lens | File | Lines | Finding | Severity | Evidence |
|---|------|------|-------|---------|----------|----------|
| 1 | Auth | handler.ts | L41 | public route with no auth check | Critical | grep output |
| 2 | Security | query.ts | L71 | unsanitized user input in SQL | Critical | view L69-73 |
```

**Severity scale:** Critical (unauthenticated access, injection, tenant exposure) · High (missing gate, wrong-tier data) · Medium (hardcoded config, debug endpoint, missing error handling) · Low (missing tests, inconsistent patterns)

---

## Phase 4: Synthesis & Report (15 min)

1. **Group findings by theme** (not by lens — a single finding may span lenses)
2. **Write Bottom Line** — 3-5 sentences summarizing what's broken and what to do
3. **Create fix priority list** — P0 (today), P1 (this sprint), P2 (tech debt)
4. **Update coverage map** — mark what's been searched
5. **List open questions** — things you couldn't determine from code alone

**Quality Gate:** Run `progressive-harsh-review`. Score <6: remediate. 6-8: PASS_WITH_FIXES. >8: PASS.

### Handoff to surgical-fix

```
"Investigation complete. Handing off finding #X to surgical-fix for implementation."
```
Include: file(s), line(s), what's wrong, proposed fix approach.

## Anti-Patterns (MUST AVOID)

1. **Don't fix things during recon.** Record findings, don't edit code.
2. **Don't go deep on one file.** Breadth first, depth second.
3. **Don't skip repos.** Gaps in coverage are where bugs hide.
4. **Don't trust comments.** Verify files exist; don't assume conventional layout.
5. **Don't claim external CLI calls are correct by syntax alone.** If scope includes wrapper scripts invoking `gh`, `aws`, `kubectl`, `npm`, etc., escalate to `external-cli-audit` — bash control flow tells you nothing about scope/identity/persistence-layer flags.

## Failure Modes

| Failure | Recovery |
|---------|----------|
| Only searched one repo | Return to Phase 0 coverage map; search all in-scope repos |
| Skipped a lens as "probably clean" | All lenses are mandatory; complete in order |
| Claimed external CLI wrappers are correct without checking CLI defaults | Run `external-cli-audit` for each external CLI invoked |

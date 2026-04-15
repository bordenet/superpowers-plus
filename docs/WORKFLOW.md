# Engineering Skills Gate Chain

Skills in the engineering group form a commit/push gate chain, a presentation gate pair, and three role-based skills. Entry points are `unified-commit-gate` (commit + push) and `requesting-code-review` (presentation). All others are downstream or role-specific.

## When Does Each Skill Fire?

| Skill | Moment | Entry point? | Calls battery? |
|-------|--------|-------------|----------------|
| `unified-commit-gate` | Before `git commit` or `git push` | ✅ Primary | ✅ Gate 3 dispatches it |
| `pre-commit-gate` | Gate 1 — lint/typecheck/test | Deep-dive only | No |
| `enforce-style-guide` | Gate 2 — shell style | Deep-dive only | No |
| `progressive-code-review-gate` | Gate 3 — self code review | Deep-dive only | ✅ Yes |
| `professional-language-audit` | Gate 4 — prose tone/language | Deep-dive only | No |
| `public-repo-ip-audit` | Gate 5 — IP scan before public push | Deep-dive only | No |
| `code-review-battery` | 5 parallel specialist reviewers | Called by Gate 3 & presenting | N/A |
| `requesting-code-review` | Before presenting work to human | ✅ Secondary | ✅ If no sentinel |
| `verification-before-completion` | Before ANY "done" response to human | ✅ Presentation gate | No (checks sentinel) |
| `finishing-a-development-branch` | Branch completion decision tree | ✅ Orchestrator | ✅ Step 0 |
| `providing-code-review` | Reviewing someone else's PR | Role-based | No |
| `receiving-code-review` | Implementing feedback received | Role-based | No |
| `inter-agent-review-protocol` | Cross-agent file-protocol handoff | Role-based | No |

## Commit/Push Gate Chain

```
git commit / git push
        ↓
unified-commit-gate (UCG)
        ├─→ Gate 1: pre-commit-gate
        │   └─→ lint / typecheck / test
        ├─→ Gate 2: enforce-style-guide
        │   └─→ shell style (shebang, help, -e, ShellCheck)
        ├─→ Gate 3: progressive-code-review-gate
        │   └─→ code-review-battery (5 parallel reviewers)
        │       └─→ writes .code-review-cleared [sha:<HEAD>]
        ├─→ Gate 4: professional-language-audit
        │   └─→ prose tone, filler, self-deprecation
        └─→ Gate 5: public-repo-ip-audit (push only)
            └─→ scan for credentials, PII, non-public content

All gates pass → commit/push allowed
Any gate fails → ABORT and fix
```

**Push Mode additions:** sentinel check + proof-of-output (every gate result shown in conversation). Docs-only pushes (`.md`, `.txt`, `README`, etc.) skip sentinel requirement.

## Sentinel System

**What:** `.code-review-cleared` — file at repo root written by `code-review-battery` when all reviewers approve.

**Format:** single line `sha:<40-char-sha>`

**When written:** End of `code-review-battery` run, all reviewers approve. Written by `tools/run-battery.sh` — the only permitted writer.

**When checked:**

| Checker | Behavior |
|---------|----------|
| `requesting-code-review` | Valid sentinel for HEAD → skip battery (cost optimization) |
| `verification-before-completion` | Valid sentinel → allow completion response |
| `unified-commit-gate` push mode | Valid sentinel → allow push |

**Staleness:** Valid for one HEAD SHA only. Any new commit, amend, or rebase invalidates it. Next gate run dispatches fresh battery.

## Presentation Gate

**Before showing results to a human, two checks fire in order:**

1. **`requesting-code-review`** — when presenting code changes for review
   - Checks sentinel. Missing or stale → dispatches `code-review-battery`
   - Reports battery findings to human

2. **`verification-before-completion`** — before ANY "done" / "complete" response
   - Broader scope (covers non-code deliverables too)
   - Checks sentinel. Missing → blocks completion claim

Both gates exist because some work completes without a presentation step (research, doc review), and some presentations don't claim completion.

## Role-Based Skills

These fire based on your **role**, not timing:

| Skill | Role | Distinct from gates? |
|-------|------|---------------------|
| `providing-code-review` | Reviewing **someone else's** PR | ✅ — not self-review |
| `receiving-code-review` | **Implementing** feedback you got | ✅ — verify before implementing |
| `inter-agent-review-protocol` | **Cross-agent** handoff via `request.md` → `response.md` | ✅ — file protocol, not human-facing |

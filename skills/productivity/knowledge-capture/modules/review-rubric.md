# Review Rubric — Progressive Harsh Review

## Reviewer Instructions

You are reviewing a BLUF-style wiki article produced from an SME interview. Your job is to find what's WRONG, not confirm what's right.

## Checklist (check every item, assign severity)

### Critical (blocks publish)
- [ ] Bottom Line accurately summarizes the article — not vague or misleading
- [ ] No factual claims without provenance in Source Notes
- [ ] No fabricated content — everything traces to interview or verified source
- [ ] No secrets or sensitive data (API keys, tokens, internal URLs, customer names)

### Major (must fix before publish)
- [ ] Scope/audience stated clearly — reader knows if this article applies to them
- [ ] All P0 coverage areas from interview are addressed or explicitly excluded
- [ ] Contradictions surfaced, not flattened — `[contested]` items visible
- [ ] Domain sections are substantive (not 1-sentence placeholders)
- [ ] Conditional sections included only where relevant (no empty Terminology or Trade-offs)

### Minor (fix if time permits)
- [ ] No undefined jargon or acronyms — first use is expanded
- [ ] Cross-links to related wiki pages present where relevant
- [ ] Grammar, formatting, and readability are clean
- [ ] Title follows guidance (findable, specific, not generic)
- [ ] Source section is complete (SME name, date, approval, owner, cadence)

## Severity Definitions

| Severity | Meaning | Action |
|----------|---------|--------|
| Critical | Misleading, fabricated, or dangerous content | Must fix. Blocks publish. |
| Major | Missing important content or structural problem | Must fix before publish. |
| Minor | Polish, formatting, nice-to-have | Fix if time permits. |

## Convergence Rules

- **Converged:** 0 critical + 0 major after round 2
- **Not converged:** Present remaining blockers to interviewee, ask for help resolving
- **Max rounds:** 3. After 3 rounds, escalate to interviewee: "These issues remain. Help me fix them, or abandon?" Publishing with unresolved critical or major findings is NOT an option.

## Reviewer Output Format

```
## Review Round <N>

### Critical
- [description] — line/section reference

### Major
- [description] — line/section reference

### Minor
- [description] — line/section reference

### Verdict: PASS / FAIL
[If FAIL: list the specific fixes needed]
```

## What the Reviewer Does NOT Do

- Does NOT rewrite the article — only identifies problems
- Does NOT override SME on intent, history, or trade-off rationale
- Does NOT add content — flags gaps for the agent to fill with interviewee
- Does NOT assess the skill's process — only the output artifact

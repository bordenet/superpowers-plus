# Module: coverage matrix

Load before Phase 1.5 (reactive harvest) or Phase 2 (interview).

The matrix is the interviewer's internal map of what the article must cover. It
is never shown to the interviewee as a checklist — it drives question priority
so the conversation stays natural.

## Areas

| Area | Priority | What it captures |
|------|----------|------------------|
| Context / Background | P0 | Why this exists, where it fits, who owns it |
| Core Concepts | P0 | The terms and mental model a reader needs first |
| How It Works | P0 | The mechanism, step by step or component by component |
| Failure Modes | P0 | What breaks, how it presents, how to recover |
| Common Mistakes | P1 | What newcomers get wrong; misconceptions |
| Expert Tips | P1 | Non-obvious shortcuts, judgment calls, "I always..." |
| References | P1 | Source docs, dashboards, tickets, code paths |

## Marking

Each area is `open`, `partial`, or `covered`.

- `open` — nothing captured yet
- `partial` — some claims captured, gaps remain
- `covered` — enough for the article; no material gap

## Sufficiency gate

Advance to synthesis (Phase 2.5) only when **all P0 areas are `covered`** and
**at least 3 P1 areas are `partial` or better**, OR the interviewee explicitly
stops.

## In the state file

```markdown
## Coverage Matrix
- Context / Background: covered
- Core Concepts: covered
- How It Works: partial  (gap: failover path)
- Failure Modes: open
- Common Mistakes: partial
- Expert Tips: open
- References: partial
```

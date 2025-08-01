# Think Twice Auto-Detection Heuristics

## Overview

Think Twice uses a weighted heuristic model to detect when the agent may be stuck.
When the cumulative score crosses a **threshold of 7**, the agent SHOULD suggest
invoking Think Twice. The agent MUST NOT auto-invoke without user confirmation.

## Heuristic Signals

| Signal | Weight | Detection Method |
|--------|--------|------------------|
| **Repeated identical approach** | 3 | Agent has tried the same fix pattern 3+ times. Track approach signatures in conversation. |
| **Circular reasoning** | 3 | Agent references its own prior failed output as input. Detect self-referential solution loops. |
| **Error loop** | 3 | Same error message appears 3+ times after attempted fixes. Track error message hashes. |
| **Exhaustion markers** | 3 | Agent says "I've tried everything I can think of" or similar. Keyword match. |
| **Uncertainty hedging** | 2 | Agent uses phrases like "I'm not sure why", "this should work but", "I don't understand why". Keyword + sentiment analysis. |
| **Scope creep apology** | 2 | Agent says "let me try a completely different approach" without clear rationale. Keyword detection. |
| **Stale context** | 2 | Conversation exceeds 80% of context window with no resolution. Token count heuristic. |

## Detection Keywords

### Exhaustion Markers (Weight: 3)
- "I've tried everything"
- "I'm out of ideas"
- "I don't know what else to try"
- "I'm stuck"
- "I can't figure out"
- "This is puzzling"
- "I'm at a loss"

### Uncertainty Hedging (Weight: 2)
- "I'm not sure why"
- "This should work but"
- "I don't understand why"
- "For some reason"
- "Strangely"
- "Unexpectedly"
- "I would have expected"
- "This is confusing"

### Scope Creep Apology (Weight: 2)
- "Let me try a completely different approach"
- "Let's start over"
- "Maybe we should try something else entirely"
- "I'm going to take a step back"
- "Let me rethink this"

## Scoring Example

```
Scenario: Agent has tried the same approach twice, said "I'm not sure why this 
isn't working", and the same error appeared 3 times.

Signals triggered:
- Error loop (3+ same errors): +3
- Uncertainty hedging ("I'm not sure why"): +2

Total: 5 (below threshold of 7)

→ Do not suggest Think Twice yet.

---

Scenario: Same as above, plus agent says "let me try a completely different approach"

Additional signal:
- Scope creep apology: +2

Total: 7 (meets threshold)

→ Suggest Think Twice to user.
```

## Suggested Prompt (When Threshold Met)

```
I'm detecting signs we might be stuck on this problem:
- [list matched signals]

Would you like me to **Think Twice**? I'll distill the problem into a 
comprehensive brief and consult a fresh sub-agent for a different perspective.
```

## Important Notes

1. **Never auto-invoke** — Always ask the user first
2. **Reset on success** — If a fix works, reset the heuristic counters
3. **Track per-problem** — Separate counters for different problems in same session
4. **Explicit triggers override** — If user says "think twice", invoke immediately regardless of score

## Future Enhancements (Phase 2+)

- Git diff stagnation (no meaningful commits in N minutes of active work)
- Test pass rate regression (tests that were passing now failing)
- Refined weights based on real-world usage data
- Track invocation → outcome success rate to tune threshold


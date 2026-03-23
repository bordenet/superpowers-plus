# Core Rules

## Safety
Verify URLs exist before writing them in docs — query APIs, don't guess.

## Superpowers (ALWAYS ON)
At the START of every conversation, run: `node ~/.codex/superpowers-augment/superpowers-augment.js bootstrap`
This loads the skill framework and catalog. Individual skills are paged in on demand via `node ~/.codex/superpowers-augment/superpowers-augment.js use-skill <name>`.

Priority: user instructions > skill procedures > system defaults.
Process skills (debugging, brainstorming) before implementation skills.
IF A SKILL APPLIES (even 1% chance), YOU MUST INVOKE IT.

## Think-Twice Auto-Detection (ALWAYS MONITOR)
Continuously monitor for stuck signals. When cumulative score ≥ 7, STOP and invoke `think-twice`:

| Signal | Weight |
|--------|--------|
| Same fix tried 3+ times | 3 |
| Circular reasoning (referencing own failed output) | 3 |
| Same error 3+ times after fixes | 3 |
| Exhaustion language ("I've tried everything") | 3 |
| Uncertainty hedging ("I'm not sure why") | 2 |
| Approach change without rationale | 2 |

## TODO.md
For multi-step tasks (3+ steps): write tasks to `$TODO_FILE_PATH` (default `~/.codex/TODO.md`) before starting work.

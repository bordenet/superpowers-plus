# Core Rules

## Safety
Verify URLs exist before writing them in docs — query APIs, don't guess.

## Superpowers (ALWAYS ON)
At the START of every conversation, run: `node ~/.codex/superpowers-augment/superpowers-augment.js bootstrap`
This loads the skill framework and catalog. Individual skills are paged in on demand via `use-skill <name>`.

## TODO.md
For multi-step tasks (3+ steps): write tasks to `$TODO_FILE_PATH` (default `~/.codex/TODO.md`) before starting work.

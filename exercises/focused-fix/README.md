# Focused-fix pilot

This experiment tests whether a shorter debugging workflow saves time on routine
work while preserving verification on defects that cross component boundaries.

## Reproduce the comparison

1. Use the Full export from `test/helpers/lite-full-install.js` at
   `cc9c9b29c6991908bceebb25d610c013bb21dfc9`. Its tree matches dev
   `a5875bf634ed15498e027269df9c0860f7e9e04c`. Run the installer in a
   disposable directory. Keep the four task definitions outside worker projects.
2. For each case in `cases.json`, create a fresh Git project containing only
   its files and Full's installed shared `.agents/skills` tree (64 entries). Give both variants the
   same project instruction to use the local Full skills, read
   `.agents/skills/sp-debug/SKILL.md` for debugging or explaining unexpected
   behavior, and run Python tests with `python3 -m unittest`.
3. For the candidate only, insert `focused-fix.md` immediately before
   `## The Four Phases` in that installed skill. Keep names and descriptions
   identical. Use `local-repair.md` in its place for the narrower follow-up.
   Commit the initial fixture. Give the worker only the ordinary
   prompt. The routing case adapts ex-016 to runnable Python, preserving its
   async defect and intentional batch exception.
4. Make three paired repetitions per case. Alternate which variant runs first
   by task and repetition. Start each worker in a fresh ephemeral Codex session
   with workspace-write, GPT-6.2 Sol, medium effort and user config ignored.
   Capture JSONL events, elapsed wall time, final answer and diff. Run the two
   sides of each pair sequentially, with up to three pairs in flight.
5. Group the six submissions per case under random identifiers. Give a separate
   read-only GPT-6.2 Astra session the prompt, criteria, commands, observed
   output, diff and answer. Withhold variant labels, run order, usage and skill
   text. Independently run the newline-joined `behavior_check` lines from the
   case with Python in the resulting fixture.
6. Record total reported input (including cached input), output, elapsed time,
   repeated identical shell commands, reviewer dispatches and human interruptions.
   Completion requires a successful terminal event and evidence that the worker
   read the assigned debugging skill. A red-to-green rerun can count as a
   repeated command. Repeats alone do not establish wasted work.

## Adoption rule

Require every candidate run to preserve the task's required verification and
all six higher-risk runs to pass. Compare median elapsed time and total input
tokens on the routine cases. Record per-case medians so one case cannot hide
a regression in another. A mixed result calls for a narrower trigger and a
fresh comparison. The trial measures behavior after the local debugging skill
is selected. Workers used the normal signed-in Codex host with user config
ignored and workspace-local skills. The Full installer also writes a 125-entry
Codex-specific tree. This trial did not replace the host profile or benchmark
a clean installation end to end. Discovery, publication gates and dollar cost
were outside the comparison.

## Results and decision

Keep Full as the default. The first candidate failed the sibling-path contract
in all three repetitions. Both variants repaired queued dispatch but changed
intentional batch behavior. In contrast, the candidate verified billing as well
as availability on all three shared-interface repairs. Full produced the
correct behavior three times but omitted the billing check in every run.

| First comparison, medians across three repetitions | Full seconds | Candidate seconds | Full input tokens | Candidate input tokens |
| --- | ---: | ---: | ---: | ---: |
| Read-only explanation | 16.86 | 18.22 | 118,873 | 111,288 |
| Local booking fix | 27.37 | 26.20 | 192,834 | 202,036 |

The narrower follow-up completed 18 of 24 sessions before the cost stop.
Both completed candidate routing repairs passed the independent batch check. Only
one Full routing control finished. Six follow-up outputs received blinded
grades, all for explanations. This incomplete comparison cannot establish
adoption or a cost improvement.

The two CSV files contain one row per completed worker. Empty review fields
mean ungraded. The 42 workers reported 8,463,093 total input tokens, including
7,263,744 cached, and 41,975 output tokens. These are usage counts, with no
conversion to money. They exclude judges, startup probes, a provider-capacity
interruption retried in the first round, and unfinished follow-up sessions.
After independent review, the batch check was strengthened with a later job
whose ordinary routing key differs from the first job. Rechecking the saved
worker outputs preserved every recorded routing verdict. No further runs are
scheduled.

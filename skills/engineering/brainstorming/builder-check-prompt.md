# Builder Check Prompt

Replaces the spec-document reviewer (obra/superpowers 7.0.1 builder check,
merged with superpowers-plus's defect calibration). Dispatch a fresh
general-purpose subagent once the written design exists. Fill in the domain
and the document path. One dispatch; no review loop.

```
Your task is to read a design document as the person who must build it.
You are a talented [DOMAIN, e.g. "software engineer", "event planner"].
You will plan the build from this document alone and cannot talk to its
author.

Read [DOCUMENT_PATH].

Report two things, ranked by importance within each:

1. Questions: places where you would have to guess and a wrong guess would
   change what gets built. For each: the question, and why the answer
   changes the plan.
2. Defects that would produce a flawed plan: TODO/TBD/placeholders,
   internal contradictions, scope covering several independent
   subsystems, features nobody asked for.

Skip anything the document explicitly leaves to the builder, anything you
could reasonably decide yourself, wording, and style. Do not spawn
subagents.

Output:
Status: Ready | Questions
Questions: - <question> — <why it changes the plan>
Defects:   - <section>: <defect> — <why it matters for planning>

If nothing important is left, output only "Status: Ready — nothing
important left".
```

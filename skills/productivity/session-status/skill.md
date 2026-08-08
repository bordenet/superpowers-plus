---
name: session-status
source: superpowers-plus
augment_menu: true
description: "Report where the current coding session stands: what's left, session status, where does this session stand. Covers work in flight, remaining work, questions you were asked and never answered, unresolved decisions, blockers, and a suggested session title. USE WHEN checking mid-flight what remains in a session."
summary: "Use when: checking where this session stands mid-flight. Skip when: summarizing a call, document, or board, or tracking tasks that outlive the session."
triggers: ["/session-status", "/sp-session-status", "what's left", "whats left",
           "session status", "status of this session", "where does this session stand",
           "where are we"]
anti_triggers: []
requires_mcp: []
coordination:
  group: productivity
  order: 3
  requires: []
  enables: []
  escalates_to: []
  internal: false
composition:
  consumes: [conversation-state, task-list, execution-doc, git-state, clock]
  produces: [session-status-readout, suggested-session-title]
  capabilities: [session-state-reporting, stranded-decision-detection]
  priority: 50
  optional: false
  requires_all: false
---

# session-status

> **Wrong skill?** Resume elsewhere after compaction -> `context-ferry` (writes a file;
> this prints only). What others pushed -> `session-handoff`. Tasks outliving this session,
> and the owner of `TODO.md` -> `todo-management`. The status of anything but this session (a
> service, sprint, rollout, release, pipeline) belongs to its owner, not this skill -- stop and
> route to that owner instead of reporting on it here.
>
> **Do not rename this to `summarize`, and do not fill in `anti_triggers` without
> re-measuring.** The router reads frontmatter `name:` before the directory, so a
> directory-only rename does nothing to the router's name-match scoring. The `anti_triggers`
> veto matches anywhere in a prompt, so a broad entry like "what's left on my todo" can make
> the skill vanish from `/session-status what's left on my todo` too. Re-measure with
> `skill-trigger-audit` before changing the name, description, or anti_triggers.

**Announce at start:** "I'm using the **session-status** skill to report where this session stands."

## When to Use

The user asks `/session-status`, "what's left", "session status", or "where does this
session stand", often while checking one of several parallel sessions. Read-only; run it
as often as asked, including mid-edit.

## Procedure

1. Read the sources below. Note anything you could not read in full.
2. Draft candidate items for the four item sections, and `Active now` as prose.
3. Run **The Filter Pass** over the item sections.
4. Order each item section by source: plan doc, task list, git, then conversation newest first; an item named as blocking another goes to the top. Below the cap this can read oddly, placing a durable-but-later task above an urgent recent one. Keep it: it is the only ordering two runs agree on.
5. Keep at most seven items per item section. If one had more, add `- +N more` as a last item line, where `N` is that section's dropped count; a bare `+N more` is absorbed into the item above it when rendered.
6. Print the readout as ordinary markdown, not inside a code fence.
7. **Stop.** See **Stop**.

## Sources

Read all five. Every command here is read-only.

- **Conversation.** The visible transcript, and the only source for unanswered questions and
  stranded decisions.
- **Task list.** On Claude Code, read the block the harness injected into context. Its
  task tool is **write-only**: it takes a full replacement array, so calling it could
  delete the user's completed entries. Never call it here. On a runtime with no
  equivalent harness-injected task block, there is no source for this line -- name it on
  `Not read` as `task list: no harness source on this runtime` rather than improvising a
  substitute (do not treat this as license to read `TODO.md` -- that stays banned below
  regardless of runtime).
- **Plan or execution doc.** Only a checklist you read or wrote *this session*; read its
  unchecked `- [ ]` items. Do not go looking for one, and never read `~/context-ferry-*.md`:
  it also holds `- [ ]` items but belongs to another session and can carry credentials.
- **Git.** `git rev-parse --show-toplevel`, then take the basename yourself: wrapping it as
  `basename "$(...)"` exits 0 with an empty value outside a repo, so judge this read by its
  output, never its status. `git rev-parse --abbrev-ref HEAD` for the branch; the literal
  `HEAD` means detached *or* no commits yet, so try `git rev-parse --short HEAD` and print
  `detached-<sha>`, or if that also fails print `<dir>` alone and name it on `Not read`.
  `git --no-optional-locks status --porcelain` for changes, the flag keeping the read from
  rewriting the index.
- **Clock.** `date '+%Y-%m-%d %H:%M:%S'`. Never write a timestamp you did not read.

**Interrupted git operation.** `--porcelain` cannot name one: a halted rebase looks like
ordinary conflicts, a bisect or half-applied cherry-pick like a clean tree. Run this once
per name, substituting each of `rebase-merge`, `rebase-apply`, `MERGE_HEAD`,
`CHERRY_PICK_HEAD`, `REVERT_HEAD`, `BISECT_LOG`, `sequencer`:

```bash
test -e "$(git rev-parse --git-path rebase-merge)" && echo IN_PROGRESS || echo none
```

Both halves are required: `--git-path` prints a path and exits 0 whether or not the file
exists, so its status and output report every operation as running in every state, and
without `|| echo none` a clean tree exits 1, which some runtimes surface as a failure.
`sequencer` catches a multi-commit cherry-pick or revert whose conflict was resolved with
plain `git commit`, which clears `CHERRY_PICK_HEAD` while picks stay pending. If a probe
cannot run, say so on `Not read`.

**Do not read `TODO.md`.** It is user-global, so its items are mostly other projects.
`todo-crud.sh` is also unsafe: `todo-engine.py` re-applies `chmod 0444` and `chflags` before
dispatch and outside the writer lock, which can collide with another session mid-write.
`todo-management` owns that file.

**The `Not read` line.** Name anything that failed, returned nothing, did not apply, or
returned less than the whole picture. `nothing` means all five were read in full, so it is
wrong when one merely did not apply. Never fill a gap from memory, and never say something
does not exist when you only failed to see it: "no plan doc in view" is honest, "no plan
doc" is not. A compacted conversation belongs here too, since it neither fails nor returns
nothing but succeeds and returns less: **write `conversation truncated, earlier questions and
decisions may be missing` unless you positively see the session's start.** Default to writing
it, because you cannot locate your own context boundary reliably and a post-compaction
transcript opens with a summary that reads like a beginning. Questions and stranded decisions
have no other source, so this is the gap that silently empties the sections this skill is for.

## The Readout

Print these in order. Omit any of the four item sections with no items, heading included,
and omit `Active now` when nothing is in flight. Header, `Not read`, and `Suggested title`
always print.

```text
## Session Status | <dir>@<branch> | <timestamp>

Not read: <anything not read in full, or "nothing">

**Active now**
<Prose, max three sentences, on the unfinished state of live work: what is half-done,
which files, what has not been run. An interrupted operation comes first and names it.>

**Remaining**
- [ ] <task> (<source>)
- +2 more

**Open questions for you**
1. "<verbatim question text>"

**Stranded decisions**
- <the unresolved point>: <options on the table, or the constraint not yet applied>

**Blocked**
- <item>: blocked on <what or who> (<source>)

**Suggested title**
`<title>`
```

The four **item sections** are `Remaining`, `Open questions for you`, `Stranded decisions`,
and `Blocked`. Pipes separate the header fields because space runs collapse when rendered.
`Remaining` holds unchecked plan-doc items, incomplete task-list entries, and work requested
this session that is not done; `Blocked` holds anything that cannot proceed until someone or
something else acts, such as a review, a deploy, or an answer. Merely not started is
`Remaining`. **A blocked item goes in `Blocked` only, never also in `Remaining`**, though
equally undone: otherwise both claim it and it prints twice. Items in those two sections carry
a source tag, one of `conversation`, `task list`, `plan doc`, `git`; `Open questions`,
`Stranded decisions`, and `Active now` carry none, the conversation being their only source.

`git` contributes at most one `Remaining` item, `uncommitted changes in N file(s)`. Linked
worktrees have private working trees, so that count is this directory's alone, but nothing you
can read says whether a second tab is open on it, so always add `may include another session's
edits` to that item and to any file named in `Active now`.

**Degraded header.** Print the fields you read and drop the separator for one you could not,
so `<dir>` alone or `<timestamp>` alone. Outside a repo the branch and status reads fail and
the toplevel read returns empty: print `## Session Status | <timestamp>` with `git absent` on
`Not read`, and never derive the directory name from the shell's working path.

**With all four item sections empty *and* nothing in `Active now`**, print the header, `Not
read`, then exactly `Nothing pending in what I can see.` and the title. An interrupted git
operation counts as work in flight, so it never appears beside that sentence. Never invent
work to fill a section.

## What Counts as Stranded

Report one when either holds. The first takes the `options on the table` shape, the second `constraint not yet applied`.

1. Two or more paths were named and none chosen, or a path was picked and a later
   instruction silently contradicted it.
2. A stated preference, constraint, or correction was never applied, or what was asked for
   and what got built diverge unacknowledged.

Capture unanswered questions **verbatim**, in quotes: paraphrase loses the choice the question
was pinning down. An implicit one ("I'll assume X unless you object") has no quotable text, so
rephrase it as a direct question and print it **unquoted, prefixed `implied:`** rather than
dropping it or wrapping words the user never said in quotes. These are questions **the
assistant asked the user**; a user request the assistant never answered is `Remaining` work.
The verbatim rule comes from `context-ferry`; a change to it belongs in both.

## The Filter Pass

Run at step 3, before ordering and capping. Without it a long transcript pulls the readout
toward a recap of finished work, the one thing the user did not ask for.

**Operate only on item lines** (beginning `- `, `- [ ] `, or `N. `) inside the four item
sections. The header, `Not read`, `Active now`, and `Suggested title` are never touched.

**Delete an item line if and only if** what it names is finished and nothing about it remains.
A line leading with finished work but naming something outstanding survives, so `PR merged,
waiting on the reviewer to approve` stays, as does partial progress. Afterwards, if one of
those four sections has no item lines left, drop its heading too.

`Active now` is exempt from the filter but not from the no-recap rule, and it is the one place
a recap can enter uncaught, so check every clause against something unfinished. `Ported two of
five files, tests not run` is correct: the finished half locates the unfinished half. A clause
naming only what succeeded is still a recap here, so `the battery and probe both pass` does not
belong, since it leaves nothing open.

Rationalizations that produce a recap, and the answer to each: "a quick recap gives useful
context" (the scrollback holds it), "I'll list what's done as `[x]`" (completed items are
omitted, not checked off), "nothing is pending, so I'll suggest next steps" (print the
empty-state sentence and stop).

## Suggested Title

One title, not a menu, backtick-wrapped on its own line so it copies cleanly. On Claude
Code the user pastes it into `/rename`; on a runtime with no rename command, present it
as a copyable line and do not name `/rename`.

- Three to seven words, noun phrase, concrete nouns from the actual work; a ticket key
  counts as one word. Lead with a ticket key **only** if the branch name carries it
  (`feat/PROJ-123-...` yields `PROJ-123`) or the user typed it this session, never from recall.
- Banned: `session`, `work`, `discussion`, `exploration`, `deep dive`, any word true of
  every session, em dashes, emoji, decorative colons.
- Nothing pending and nothing substantive done: name the surface, as in `slop-check port,
  not yet run`.

## Stop

The readout is the whole deliverable. After printing it: make no edits, run nothing beyond
the reads above, do not act on any listed item, do not answer the questions you printed, do
not dispatch a subagent, do not offer to continue, and **do not continue or abort any
interrupted operation you just reported**. End the turn. It is a snapshot, so if the user
later says "go", re-read first: another tab on this directory may have changed the tree, and
an interrupted operation must be resolved by the user before anything is committed, since a
commit made during one can be discarded by the abort that ends it.

## Failure Modes

| Failure | Recovery |
|---|---|
| An interrupted operation reported when none runs, a halted one reported as ordinary changes, or `Nothing pending` on a detached HEAD or mid-bisect | All three are the probe. Use the exact two-branch form in **Sources** for all seven names including `sequencer`: `--git-path` alone always prints a path and exits 0, `--porcelain` alone can never name the operation, and a clean tree is not a safe tree. A detached HEAD prints `detached-<sha>`, never the literal `HEAD`. |
| `Open questions` and `Stranded decisions` empty after a compaction | They have no source but the conversation. Put the full `conversation truncated, earlier questions and decisions may be missing` on `Not read` rather than reporting none. |
| Readout opens with completed work | The filter ran before the draft was complete, or `Active now` was written as a recap. Re-draft it as unfinished state and re-run step 3. |
| `Suggested title` or `Not read` missing, or the readout mixes two sessions' work | None of the three is an item section, so omit-when-empty and the filter never reach them. Header, `Not read`, and title always print; two tabs on one directory cannot be told apart, so say so rather than guessing. |
| A source called absent when only unreadable, or a timestamp or branch that looks plausible but is wrong | Both assert what was not read. Say "in view" for the first; for the second run the command in **Sources** or drop the field. Either way name it on `Not read`. |
| `Blocked` always empty | Anything waiting on another person or system belongs there, not in `Remaining`. |
| A question was paraphrased and the user answered a different one | Questions are quoted verbatim. Re-read the conversation and quote exactly. |

---
name: brainstorming
source: superpowers-plus
augment_menu: true
# Override rationale: condensed, procedural, gate-enforced port of
# obra/superpowers brainstorming at v7.0.1 (2ce8aa15), the latest release:
# look before asking, echo-first message, play-it-back, approaches in their
# own message, builder check, plus our spike/bounded/architectural router and
# Clear path.
triggers: ["/sp-brainstorm", "brainstorm", "design a feature", "build a new", "create a new", "add functionality", "plan a feature", "explore approaches", "design this"]
anti_triggers: ["radical improvement", "10x improvement", "paradigm shift", "moonshot", "step-change", "comparing design options", "choose between design approaches", "three design options", "red-team design approaches", "formally compare approaches"]
description: "You MUST use this before any creative work - creating features, building components, adding functionality, or modifying behavior. Explores user intent, requirements and design before implementation."
summary: "Use when: starting creative work. Explores intent and design before implementation."
coordination:
  group: thinking
  order: 1
  requires: []
  enables: ["debate"]
  escalates_to: ["thinking-orchestrator"]
  internal: false
composition:
  produces: [design-options, risk-surface, brainstorm-output]
  consumes: [task-description, system-context]
  capabilities: [generates-ideas, multi-perspective-ideation]
  priority: 3
  optional: false
  requires_all: false
---

# Brainstorming Ideas Into Designs

## When to Use

- Before any creative work: creating features, building components, adding functionality, or modifying behavior
- User says "design a feature," "build a new," "explore approaches"
- NOT for: bug fixing (`systematic-debugging`), extracting existing knowledge (`expert-interviewer`), choosing between known options (`debate`)

You build what you believe the user wants, and that belief is thinner than
it feels. Find out what they want and why before anything gets built.

> **Wrong skill?** Bug fixing → `systematic-debugging`. Extracting existing knowledge → `expert-interviewer`. Choosing between known options → `debate`.

<HARD-GATE>
Do NOT write product code, scaffold, install dependencies, create projects, or invoke an implementation skill until the user has approved the design for this path (spike: the probe plan; bounded: the in-chat design; architectural: the written spec). Reading and exploring are fine. The only exemption is the **Clear** path below, where the request itself is the approved design. Approval covers what you showed; "sounds good" to an idea is not approval of a design you have not presented.
</HARD-GATE>

## Look Before You Ask

Before your first message, read everything the user pointed to (spec, plan,
handoff, files, earlier conversation) and the code or material it connects
to. Keep reading until you can explain how the relevant parts work today and
what this change would touch. Never ask what the project or their context
already answers.

## Four Paths

Classify after looking, before your first question, and say the
classification in one plain line so the user can override it:

- **Clear** — everything that matters is in the request ("make the icon
  cornflower blue"): no material choice left open, so two competent builders
  would produce the same result, and the user did not ask to brainstorm.
  Do it through the normal workflow (TDD applies) and say what you did.
- **Spike** — a feasibility question ("can we...", "quick and dirty is
  fine") whose output is an answer, not code you keep. Present the question
  and probe plan in 2-3 sentences, get a nod, investigate as cheaply as
  correctness allows, report a recommendation. Anything built stays labeled
  throwaway; keeping it is a new request that comes back through the gate.
- **Bounded** — a well-scoped change to a flow that already exists in this
  repo. No existing flow to change means architectural. Converse, present a
  short design IN CHAT, STOP for an explicit yes. No spec file, no plan doc.
- **Architectural** — new projects or subsystems, restructured components,
  changed interfaces others depend on. Full checklist below, then
  `plan-and-execute`.

When in doubt, take the heavier path. The ratchet is one-way: hidden
complexity found mid-task upgrades the path — stop, say so, step up.
Several independent projects: say so, agree an order, brainstorm one at a
time.

**Why Clear overrides "the gate never scales":** an approval round on a
request that already fixes every material choice asks the user to repeat
what they just said. It costs a turn and adds no information. The gate
exists to stop building the wrong thing, and a request with nothing left to
interpret leaves nothing to get wrong. The test stays narrow: if you can
name one open choice that would change the result, the request is not Clear.

## Your First Message (non-Clear paths)

- **They already said what they want** (spec, plan, detailed request): about
  200 words. Echo the request in your own words (what, who for, why, as far
  as stated). Add what you found: how the relevant parts work today and what
  the change touches. Name any constraint, conflict, or cheaper path that
  would change the ask. End with one line inviting corrections, then ONE
  question: the open point whose answer most changes what gets built.
- **They haven't:** one open question in their terms about the biggest
  unsettled thing, plus why you ask (what the answer changes).
- **Skip offer:** only when the skill fired on its own (the user did not ask
  to brainstorm), end with a one-line offer to just get going. If they take
  it, state any significant how-it-gets-made choice in one line, then do the
  work through the normal workflow; the gate goes with the skill.

## The Conversation

- One question per message: a single sentence, no list of example answers.
  Plain language in the user's vocabulary; no process jargon.
- Open questions first; offer a short menu only when they are stuck. On
  "what do you think?", propose something concrete with your reason.
- Build each question on their last answer or on what you found, and say
  what the answer would change. A correctable proposal often beats a question.
- **How it gets made:** early, find which choices (platform, language,
  libraries, medium) they want to own and which they hand to you. Choices
  you make go in the design as your call, never as something they agreed to.
- **Recon:** when looking further would help, offer to search their code,
  files, or the web and say what you would look for. They decide.
- Ground to cover (territory, not a script): what it is, why now, success,
  goals / non-goals / anti-goals, prior art, current state, details they
  care about. YAGNI ruthlessly.

## Play It Back

As soon as you understand one part (what it is for, how one piece behaves),
play that part back in about 200-300 words, then return to questions about
the next part. Only what they said goes in as theirs; anything you filled in
is marked as your proposal with a reason. End each playback by asking what
is wrong or missing.

## Lay Out the Approaches

Once you understand what they want, and before writing anything up, send the
approaches in a message of their own: 2-3 real alternatives grounded in what
the project does, each with its trade-off; drop any that work against their
why. Recommend one and ask which way to go. If there is genuinely one
sensible way, say so and why the others do not fit. On the bounded path a
single sensible way may ride inside the short design.

## Checklists (complete in order)

**Bounded:** look → first message → questions + playback → approaches →
short design in chat (approach, files touched, testing) → STOP for explicit
yes (presenting and starting in the same breath skips the gate) → implement
via the normal workflow, no plan document.

**Architectural:**

1. Look; assess scope (decompose independent subsystems first)
2. First message, conversation, playback per part
3. Approaches in their own message; user picks
4. Write the spec to `docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md`
   (user preference overrides) and commit. A builder could plan from it
   alone: intent and why; goals, non-goals, anti-goals; constraints;
   approaches (considered, picked, why); decided parts of the how; what is
   left to the builder
5. Builder check (below) — tell the user a reviewer reads it first and you
   may come back once with questions
6. User reviews and approves the written spec
7. If ≥3 viable approaches survived, `debate` red-teams them (handed the
   spec; it generates nothing new). Then invoke `plan-and-execute`.

**Ensemble mode** (architectural, broad or high-impact prompts): score with
`skills/_shared/multi-agent-activation-rubric.md` — ≥6 ensemble, 5 ask,
<5 single-agent. Protocol, 1.5× token cap, max 4 lenses:
`references/ensemble-mode.md`.

## Builder Check

Dispatch one fresh subagent with `builder-check-prompt.md`. Without a
subagent tool, read the spec as that builder yourself. Sort the result:

- **Answered already** by the conversation or project → write the answer in.
- **Minor** (a sensible builder settles it without changing what gets built)
  → decide it, mark it in the spec as your call. Fix listed defects.
- **Theirs** (only the user can answer; the answer changes what gets built)
  → one message, most important first.

Update the spec, then hand it over with the short list of calls you made.
That is the only round of questions the check produces.

## Visual Companion

A browser tab for mockups, diagrams, and clickable throwaway prototypes.
Offer it just-in-time, in a message with nothing else in it, the first time
seeing would beat reading (a screen, a layout, a flow, options that look
different, a diagram): "This might be easier if I show you. Want me to open
a browser tab with some mockups?" If declined, stay in text; do not re-offer
unless they raise it. Requirements, scope, and trade-offs stay in text even
after acceptance. If accepted, read `visual-companion.md` before starting
the server.

## Failure Modes

| Failure | Fix |
|---------|-----|
| Asked something the repo or their files already answer | Look before you ask — read first, then ask only what is open |
| Started coding before design approval | Delete code, restart from the path's approval step |
| Called it Clear while a material choice was open | Name the open choice; it is not Clear — converse |
| Wrote the design before showing approaches | Approaches go in their own message; user picks first |
| Offered a menu before they described it | Options steer — ask them to describe it first |
| Defaulted a platform/library silently | Say it out loud as your call; an unheard default can't be rejected |
| Called it "bounded" to skip the design step | Reaching for a label to dodge ceremony IS the doubt — take the heavier path |
| Called it bounded because you know this kind of app | Bounded measures the repo, not your familiarity |
| Kept a spike's throwaway code without re-classifying | Keeping the code is a new request — classify it |
| Task grew mid-implementation, kept going on the old path | Stop, say so, step up |
| Handed over the spec before the builder check returned | Wait for the check; bring the "theirs" pile once |

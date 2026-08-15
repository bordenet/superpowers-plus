---
name: explain-like-im-five
source: superpowers-plus
augment_menu: true
triggers: ["/eli5", "explain this simply", "explain like I'm five", "explain like i'm 5", "break this down", "help me understand", "what does this mean", "explain this concept", "make this easier to understand"]
anti_triggers: ["summarize this", "condense this", "tl;dr", "rewrite this for a simpler audience", "simplify this writing", "full architecture review", "deep technical explanation", "detailed technical writeup", "give me the technical deep-dive", "code review", "security review", "debug this"]
description: Use when a user wants a clear, plain-language explanation of a concept, error, question, or artifact that preserves technical nuance rather than childish oversimplification. Supports explicit-subject `/eli5 <topic>` and context-derived bare `/eli5`.
summary: "Use when: explaining something simply and accurately without dumbing it down. /eli5 [subject] — explicit or derived from current context."
coordination:
  group: writing
  order: 4
  requires: []
  enables: []
  escalates_to: []
  internal: false
composition:
  consumes: [user-intent, conversation-context]
  produces: [plain-language-explanation]
  capabilities: [explains-concept]
  priority: 40
---

# Explain Like I'm Five

> **Wrong skill?** Summarizing supplied text → use a summarization skill. Rewriting prose for a different audience → `eliminating-ai-slop`. Exhaustive architecture/design analysis → `progressive-harsh-review`. Code review → `providing-code-review` (or `code-review-battery` for a full multi-reviewer pass). Debugging → `systematic-debugging`. Security review → `repo-security-scan` (read-only audit; `security-upgrade` actually installs and pushes dependency upgrades — do not redirect a review request there).
>
> The name is a mnemonic, not an instruction to talk down to anyone. The goal is a fast, accurate, plain-language explanation for a technically capable reader — not baby talk.

## Syntax

```
/eli5 <concept, question, text, error, artifact, or topic>
/eli5
```

**Parse rule:** everything after `/eli5` is the subject verbatim — do not trim, paraphrase, or reinterpret it before explaining it. If nothing follows `/eli5`, there is no explicit subject: fall through to [Context-Derived Subject](#context-derived-subject) below.

**Examples:**

| Command | Subject |
|---|---|
| `/eli5 OAuth refresh tokens` | "OAuth refresh tokens" |
| `/eli5 why this Kubernetes deployment is CrashLoopBackOff` | that diagnostic question |
| `/eli5 the difference between a mutex and a semaphore` | that comparison |
| `/eli5 event sourcing` | "event sourcing" |
| `/eli5` | derive from context (see below) |

Natural-language triggers ("explain this simply", "explain like I'm five", "break this down", "help me understand", "what does this mean", etc.) carry the same contract as bare `/eli5`: if the request itself names a subject, explain that subject; if it doesn't, derive it from context. A request names a subject when a concrete noun phrase follows the trigger phrase, with or without a colon (e.g. "explain this simply: event sourcing" or "help me understand event sourcing" — both name "event sourcing" as the subject). A bare deictic reference with no adjacent noun phrase ("explain this", "what does this mean") does not by itself name a subject — treat it as having no explicit subject and fall through to Context-Derived Subject.

## Context-Derived Subject

When invoked with no explicit subject, look for the strongest available signal, in this order of preference:

1. The immediately preceding user request or question.
2. Selected text or a pasted snippet the user just referenced.
3. An active code artifact, diff, or file currently under discussion.
4. An error or failure currently being debugged.
5. The current task, if one is clearly in progress.
6. The conversation's evident subject, if the above are all absent but one topic clearly dominates.

**If no single subject is clearly identifiable, do not invent one.** Ask exactly one concise clarification question:

> What would you like me to explain simply?

If two or three candidates are plausible, name at most two of them in the question instead of asking blindly — e.g. "Do you want the CrashLoopBackOff error explained, or the readiness-probe config?" Never guess silently and never explain the wrong thing to avoid asking.

## Output Structure

Use progressive disclosure. Scale length and section count to the topic's actual complexity:

- A term or fact with one meaning and no real tradeoff (a one-line jargon term, a simple definition) deserves sections 1 only, or 1-2 — two or three sentences, not six headings.
- A mechanism with a caveat, boundary, or common misconception worth stating deserves sections 1-2-5, or 1-2-4-5.
- Reserve the full six-section structure below for topics that genuinely have all of: a non-trivial mechanism, a real tradeoff or practical implication, and either a technically accurate analogy or a material nuance worth preserving.

When the full structure is warranted:

1. **In short** — one or two sentences, the core idea.
2. **How it works** — the mechanism, in direct everyday language.
3. **Example or analogy** — include only if it materially improves understanding, and only if it is technically accurate. A forced or approximate analogy is worse than no analogy.
4. **Why it matters** — practical implications, tradeoffs, use cases, or consequences.
5. **Important nuance** — a real caveat, boundary, limitation, or common misconception. Do not drop this to make the answer shorter; a shorter answer that loses the nuance is a wrong answer, not a good one.
6. **Optional follow-up** — offer one relevant next direction, e.g. "Want the implementation-level explanation?", "Want an example in TypeScript?", "Want to compare this with [related concept]?"

Do not force all six sections onto a simple answer. Do not compress a genuinely complex topic into one paragraph just to look concise.

## Tone Requirements

Do:
- Use plain, direct language pitched at the user's apparent technical level.
- Introduce necessary jargon only after or alongside a simple definition — never assume unexplained jargon, but never avoid a term the reader clearly already uses.
- Keep real technical distinctions intact rather than replacing them with a simplification that is actually wrong.
- Draw examples from the user's current domain or codebase when context makes that possible.
- When explaining code, cover both what it does and, where it adds value, why it's built that way.
- Say plainly when context is missing or uncertain, rather than filling the gap with a guess.

Do not:
- Say or imply the user is a child.
- Open with "Imagine you're five," "Like you're a child," or any equivalent framing.
- Use patronizing, cutesy, or overly cheerful language.
- Force an analogy in where a direct explanation is clearer.
- Assert something with confidence because the ambiguous context made a guess convenient.
- Cut a meaningful caveat just to shorten the answer.

## Companion Skills

- **eliminating-ai-slop**: Rewrites existing prose for a target audience — different job from explaining a concept from scratch.
- **detecting-ai-slop**: Read-only scoring of AI-pattern density in prose — not an explanation task.
- **systematic-debugging**: Root-cause investigation of a failure — this skill explains a concept or error clearly but does not itself diagnose or fix it.
- **code-review-battery**: Multi-reviewer code quality pass — a different concern than explaining how something works.

## Failure Modes

| Failure | Detection | Recovery |
|---------|-----------|----------|
| Invents a subject when context is genuinely ambiguous | Explanation doesn't match what the user actually meant | Ask the single clarification question up front instead; never backfill a guess |
| Slips into childish or cutesy framing | Output contains "imagine you're five" or similar | Rewrite in plain adult register; the skill name is a mnemonic only |
| Drops a real caveat to shorten the answer | Explanation reads as confidently simple but is technically incomplete or wrong | Restore the nuance in an "Important nuance" line even if it lengthens the answer |
| Over-templates a trivial request | A one-sentence answer gets six forced headings | Scale structure down; short answers don't need every section |
| Forces an analogy that doesn't actually map | Analogy breaks down under scrutiny or misleads | Drop the analogy and explain directly instead |
| Trigger phrase "help me understand" is a substring of `superpowers-help`'s longer trigger "help me understand superpowers" | A request for the skill catalog gets an explanation instead, or vice versa | Routing is semantic (full request + description), not substring matching — a request naming "superpowers" as the subject routes to `superpowers-help`; known overlap, not a defect requiring a trigger change |

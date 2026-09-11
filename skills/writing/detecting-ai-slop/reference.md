# Detecting AI Slop - Pattern Reference

> **Parent skill:** [skill.md](./skill.md)
> **Last Updated:** 2026-09-11

This file contains the complete pattern dictionary for slop detection. The core skill.md loads this on demand.

---

## Lexical Patterns (40 points max)

Each pattern found adds 2 points to lexical score (exception: em-dash and en-dash score +3 pts each; see Category 7).

**One occurrence, one hit.** When one occurrence matches more than one entry because one entry contains the other ("rich tapestry" and `tapestry`, "the journey" and `journey`, "could potentially" and `potentially`, "Of course!" and `of course`), score it once, under the earlier-numbered category. The same holds across dimensions: an occurrence that matches a Lexical entry and a Structural or Semantic row in skill.md ("As mentioned earlier" is Category 6 and Over-Signposting; "stands as a" is Category 2 and Copula Avoidance) scores once, on the Structural or Semantic row. Separate entries that sit next to each other without overlapping ("stands as a testament to" is `stands as a` plus `testament to`) are two tells and score twice. Overlap means the entries match the same words: a row that matches a whole sentence shape (Structural Contrast, Gerund-Tail Commentary, Formulaic Introduction) does not absorb Lexical entries inside that sentence, so "paradigm shift" in "It's not a bug fix; it's a paradigm shift" still scores under Category 10. A row's own trigger word (`underscoring` in Gerund-Tail Commentary, `stands as` in Copula Avoidance) scores only on the row, never also as the Lexical entry it resembles. When a Structural row and a Semantic row fire on the same words, score the Semantic row (a factual defect outranks a style defect) and list both in Top Offenders.

### Category 1: Generic Boosters

Delete or replace with specific metrics.

| Phrase | Category |
|--------|----------|
| incredibly | generic-booster |
| extremely | generic-booster |
| highly | generic-booster |
| very | generic-booster |
| truly | generic-booster |
| absolutely | generic-booster |
| definitely | generic-booster |
| really | generic-booster |
| quite | generic-booster |
| remarkably | generic-booster |
| exceptionally | generic-booster |
| particularly | generic-booster |
| especially | generic-booster |
| significantly | generic-booster |
| substantially | generic-booster |
| considerably | generic-booster |
| dramatically | generic-booster |
| tremendously | generic-booster |
| immensely | generic-booster |
| profoundly | generic-booster |
| delve | generic-booster |
| tapestry | generic-booster |
| multifaceted | generic-booster |
| myriad | generic-booster |
| plethora | generic-booster |

### Category 2: Buzzwords

Replace with plain language or specific descriptions.

| Phrase | Category |
|--------|----------|
| robust | buzzword |
| seamless | buzzword |
| comprehensive | buzzword |
| elegant | buzzword |
| powerful | buzzword |
| flexible | buzzword |
| intuitive | buzzword |
| user-friendly | buzzword |
| streamlined | buzzword |
| optimized | buzzword |
| efficient | buzzword |
| scalable | buzzword |
| reliable | buzzword |
| secure | buzzword |
| modern | buzzword |
| innovative | buzzword |
| sophisticated | buzzword |
| advanced | buzzword |
| state-of-the-art | buzzword |
| best-in-class | buzzword |
| world-class | buzzword |
| enterprise-ready | buzzword |
| production-grade | buzzword |
| battle-tested | buzzword |
| industry-leading | buzzword |
| game-changing | buzzword |
| revolutionary | buzzword |
| transformative | buzzword |
| disruptive | buzzword |
| cutting-edge | buzzword |
| next-generation | buzzword |
| bleeding-edge | buzzword |
| groundbreaking | buzzword |
| paradigm-shifting | buzzword |
| synergy | buzzword |
| holistic | buzzword |
| ecosystem | buzzword |
| leverage | buzzword |
| utilize | buzzword |
| facilitate | buzzword |
| enable | buzzword |
| empower | buzzword |
| optimize | buzzword |
| accelerate | buzzword |
| amplify | buzzword |
| unlock | buzzword |
| drive | buzzword |
| spearhead | buzzword |
| champion | buzzword |
| pivot | buzzword |
| actionable | buzzword |
| elevate | buzzword |
| harness | buzzword |
| enhance | buzzword |
| tailored | buzzword |
| dynamic | buzzword |
| future-proof | buzzword |
| unprecedented | buzzword |
| pivotal | buzzword |
| crucial | buzzword |
| essential | buzzword |
| nuanced | buzzword |
| aligned | buzzword |
| proactive | buzzword |
| versatile | buzzword |
| agile | buzzword |
| AI-powered | buzzword |
| mission-critical | buzzword |
| game-changer | buzzword |
| realm | buzzword |
| landscape | buzzword |
| journey | buzzword |
| uncover | buzzword |
| unveil | buzzword |
| showcase | buzzword |
| underscore | buzzword |
| bolster | buzzword |
| transcend | buzzword |
| resonate | buzzword |
| reimagine | buzzword |
| democratize | buzzword |
| frictionless | buzzword |
| hyper-personalized | buzzword |
| plug-and-play | buzzword |
| turnkey | buzzword |
| future-ready | buzzword |
| action-oriented | buzzword |
| end-to-end | buzzword |
| data-driven | buzzword |
| customer-centric | buzzword |
| strategically | buzzword |
| architected | buzzword |
| compelling | buzzword |
| meaningful | buzzword |
| impactful | buzzword |
| load-bearing | buzzword |
| load bearing | buzzword |
| testament to | buzzword |
| stands as a | buzzword (copula avoidance: scores under skill.md's Copula Avoidance row, not here; see *One occurrence, one hit*) |
| serves as a | buzzword (advisory; copula avoidance when plain "is" says the same thing, but also ordinary technical English such as "serves as a polyfill", so `slop-check.sh` warns instead of blocking) |
| commitment to excellence | buzzword |
| diverse array of | buzzword |
| valuable insights | buzzword |
| a wealth of | buzzword |
| a treasure trove of | buzzword |
| future outlook | buzzword |
| future prospects | buzzword |
| vibrant | buzzword (exempt when it literally describes a color, UI theme, or image asset) |
| interplay | buzzword (advisory) |
| meticulous | buzzword (advisory) |
| meticulously | buzzword (advisory) |
| intricate | buzzword (advisory) |
| intricacies | buzzword (advisory) |

**Advisory entries** (marked advisory in this category and in Category 3) reproduced blocking ordinary engineering prose with no other AI tell present: "the interplay between the connection pool and the retry queue", "we meticulously verified each state transition". List an advisory hit in Top Offenders, but score it only when a non-advisory scored pattern appears in the same sentence; two advisory hits ("the intricate interplay") do not satisfy each other. `tools/slop-check.sh` keeps these in its advisory tier (`BUZZWORDS_ADVISORY`, `FILLERS_ADVISORY`): reported, never blocking. `vibrant` sits in that tier too, because a line-level grep cannot apply its color exemption.

### Category 3: Filler Phrases

Delete entirely - these add no meaning.

| Phrase | Category |
|--------|----------|
| It's important to note that | filler |
| It's worth mentioning that | filler |
| It should be noted that | filler |
| It goes without saying that | filler |
| Needless to say | filler |
| As you may know | filler |
| As we all know | filler |
| In today's world | filler |
| In today's digital age | filler |
| In today's fast-paced environment | filler |
| In the modern era | filler |
| At the end of the day | filler |
| When all is said and done | filler |
| Having said that | filler |
| That said | filler |
| That being said | filler |
| With that in mind | filler |
| With that being said | filler |
| Let me explain | filler |
| Let me walk you through | filler |
| Let's dive in | filler |
| Let's explore | filler |
| Let's take a look at | filler |
| Let's break this down | filler |
| Here's the thing | filler |
| The thing is | filler |
| The fact of the matter is | filler |
| At this point in time | filler |
| In order to | filler |
| Due to the fact that | filler |
| For the purpose of | filler |
| In the event that | filler |
| In today's ever-evolving world | filler |
| In this article | filler |
| In this guide | filler |
| In conclusion | filler |
| In summary | filler |
| In essence | filler |
| The bottom line | filler |
| Here's the deal | filler |
| Picture this | filler |
| Welcome to the world of | filler |
| Worth noting | filler |
| Cannot be overstated | filler |
| Real-world | filler |
| In a world where | filler |
| Shining a light on | filler |
| Designed to enhance | filler |
| Unlock the potential of | filler |
| Shed light on | filler |
| Sheds light on | filler |
| Despite these challenges | filler |
| Let me be clear | filler |
| Look no further | filler |
| Without further ado | filler |
| Sets the stage for | filler |
| Paves the way for | filler |
| At its core, | filler (advisory) |
| At the heart of | filler (advisory) |

**Not listed:** "It turns out" is ordinary root-cause and postmortem phrasing ("it turns out the bug was a race condition") and flags more real prose than slop. Do not score it.

**Exemption:** "In this article" and "In this guide" are exempt when the content-type is `README` or how-to documentation — orienting the reader at the start is expected. Flag only in AI-generated prose or marketing copy.

### Category 4: Hedge Patterns

Weasel words that avoid commitment.

| Phrase | Category |
|--------|----------|
| of course | hedge |
| naturally | hedge |
| obviously | hedge |
| clearly | hedge |
| certainly | hedge |
| undoubtedly | hedge |
| in many ways | hedge |
| to some extent | hedge |
| in some cases | hedge |
| it depends | hedge |
| it varies | hedge |
| generally speaking | hedge |
| for the most part | hedge |
| more or less | hedge |
| kind of | hedge |
| sort of | hedge |
| somewhat | hedge |
| relatively | hedge |
| arguably | hedge |
| potentially | hedge |
| possibly | hedge |
| might | hedge |
| may or may not | hedge |
| could potentially | hedge |
| tends to | hedge |
| seems to | hedge |
| appears to | hedge |

### Category 5: Sycophantic Phrases

Never compliment the user or express enthusiasm about helping.

| Phrase | Category |
|--------|----------|
| Great question! | sycophancy |
| Excellent question! | sycophancy |
| That's a great point! | sycophancy |
| Good thinking! | sycophancy |
| I love that idea! | sycophancy |
| What a fascinating topic! | sycophancy |
| Happy to help! | sycophancy |
| I'd be happy to help | sycophancy |
| I'm glad you asked | sycophancy |
| Thanks for asking | sycophancy |
| Absolutely! | sycophancy |
| Definitely! | sycophancy |
| Of course! | sycophancy |
| Sure thing! | sycophancy |
| No problem! | sycophancy |
| You're welcome! | sycophancy |
| My pleasure! | sycophancy |
| I appreciate you sharing | sycophancy |
| That's an interesting perspective | sycophancy |
| I understand your concern | sycophancy |

### Category 6: Transitional Filler

Overused transitions that pad word count.

| Phrase | Category |
|--------|----------|
| Furthermore | transition-filler |
| Moreover | transition-filler |
| Additionally | transition-filler |
| In addition | transition-filler |
| Nevertheless | transition-filler |
| Nonetheless | transition-filler |
| On the other hand | transition-filler |
| Conversely | transition-filler |
| In contrast | transition-filler |
| Similarly | transition-filler |
| Likewise | transition-filler |
| Consequently | transition-filler |
| Therefore | transition-filler |
| Thus | transition-filler |
| Hence | transition-filler |
| Accordingly | transition-filler |
| As a result | transition-filler |
| For this reason | transition-filler |
| To that end | transition-filler |
| With this in mind | transition-filler |
| Given the above | transition-filler |
| Based on the above | transition-filler |
| As mentioned earlier | transition-filler |
| As previously stated | transition-filler |
| As noted above | transition-filler |
| Moving forward | transition-filler |
| Going forward | transition-filler |
| However | transition-filler |
| Indeed | transition-filler |

### Category 7: Typographic Tells

AI-generated text often uses specific punctuation patterns.

| Pattern | Category | Notes |
|---------|----------|-------|
| — (em-dash) | typographic-tell | Replace with comma, semicolon, colon, or parentheses |
| – (en-dash) | typographic-tell | Same treatment as em-dash; agents substitute it when told to avoid em-dashes. Exempt in ranges ("pp. 3–7", "Mar–Apr") and compound connections between independent nouns ("New York–London flight", "client–server model") |
| … (ellipsis character) | typographic-tell | Use three periods (...) or rewrite |
| " " (smart quotes) | typographic-tell | Context-dependent; flag if inconsistent |

**Em-dash and en-dash detection is HIGH PRIORITY.** Each instance adds 3 points (higher weight than standard lexical patterns).

### Category 8: Vague Abstraction Phrases

Phrases that sound analytical while dodging specifics. A reliable tell when they appear without a concrete claim attached — each could slot into almost any LinkedIn post unchanged.

| Phrase | Category | Notes |
|--------|----------|-------|
| the frame | abstraction-phrase | "reframing" without stating what changes |
| the lens | abstraction-phrase | analytical-sounding without an actual angle |
| the narrative | abstraction-phrase | when used instead of naming the actual claim |
| the broader picture | abstraction-phrase | stalling — say what the picture shows |
| the broader context | abstraction-phrase | stalling — state the context explicitly |
| the framework | abstraction-phrase | vague when no framework is actually named |
| the ecosystem | abstraction-phrase | used to imply scale without specifying it |
| the journey | abstraction-phrase | metaphor in place of a process description; contains Cat. 2 `journey`, so it scores once, under Cat. 2 (see *One occurrence, one hit*) |
| the conversation | abstraction-phrase | "part of a larger conversation" — say which one |
| the space | abstraction-phrase | "in this space" — name the domain |
| whether you're X or Y | abstraction-phrase | generic-audience hook ("whether you're a developer or a manager"); a precise operational statement does not depend on the reader's role |

**Detection rule:** Flag when the phrase substitutes for a concrete noun (person, system, process, number). If swapping the phrase with a specific noun breaks nothing, it's slop.

### Category 9: Structural Contrast Tells

Symmetrical, slogan-like contrast patterns that feel manufactured. Each adds 5 points to the structural dimension (consistent with the scoring formula in skill.md).

| Pattern | Example |
|---------|---------|
| It's not about X. It's about Y. | "It's not about features. It's about outcomes." |
| Not because X, but because Y. | "Not because it's fast, but because it's right." |
| No X. No Y. Just Z. | "No fluff. No filler. Just results." |
| X is not just A; it's B. | "This is not just a tool; it's a philosophy." |
| The question is not X, but Y. | "The question is not whether, but when." |
| If you know, you know. | "It's a different kind of clarity. If you know, you know." |
| The more you X, the more you Y. | "The more you use it, the more you trust it." |
| What does this mean for…? | "What does this mean for your team? Everything." |
| X. Y. Z. | "Fast. Reliable. Secure." |
| And the X? Y. | "And the result? Fewer errors." |
| A minor X in the scheme of things, but a real one. | "A minor miss in the scheme of things, but a real one." |
| X, but a real/important one nonetheless. | "A small gap, but an important one nonetheless." |
| It's not X; it's Y. | "It's not a bug fix; it's a paradigm shift." |
| [Subject] isn't X; it's Y. | "The goal isn't speed; it's correctness." |
| Not just X — it's Y. | "Not just a win for the team — it's a win for the company." |
| Not merely X — it's Y. | "Not merely a feature — it's a commitment." |
| This isn't about X, it's about Y. | "This isn't about speed, it's about trust." |

**Not-X-its-Y (reframing) detection rule:** flag when a subject is negated ("isn't X", "not X", "not just X", "not merely X") and the second clause reframes rhetorically. The rows above are seeds; flag close variants of the same shape. Practical test: drop the X-clause entirely and keep Y with any prepositions attached. If Y alone conveys the full meaning, the negation frame is decorative and it's the tic. ("The goal isn't speed; it's correctness." → keep "It's correctness." / "It's not about features; it's about outcomes." → keep "It's about outcomes." — preserve "about".) Fix: drop the negation frame, state Y directly, preserving any preposition in Y. Exemption: do NOT apply to "not only X but Y" additive conjunctions (see additive-elevation rule). When in doubt, flag it — the writer can restate Y plainly and the corrective meaning survives.

**Additive-elevation exception:** "not only X but Y" and "not just X but also Y" are standard English additive conjunctions — flag them ONLY when both terms are empty without a metric or named artifact (e.g. "Not only faster, but smarter" — both are unquantified comparatives). When both X and Y are substantive — referencing a measurable outcome, a named artifact, or a domain-specific technical term — leave them alone.

**Hedged-concession detection rule:** the "A minor X..." and "X, but a real/important one..." rows are seeds for a shape, not a template list. Flag any admission softened by a symmetric qualifier ("admittedly minor, though it matters", "small in the grand scheme, yet worth flagging"). The fix is stating the miss plainly, once.

### Category 10: Clichés and Stock Phrases

| Phrase | Category |
|--------|----------|
| state of the art | cliche |
| at the end of the day | cliche |
| think outside the box | cliche |
| move the needle | cliche |
| low-hanging fruit | cliche |
| deep dive | cliche |
| circle back | cliche |
| touch base | cliche |
| on the same page | cliche |
| hit the ground running | cliche |
| paradigm shift | cliche |
| value proposition | cliche |
| core competency | cliche |
| best of breed | cliche |
| mission critical | cliche |
| rich tapestry | cliche (contains Cat. 1 `tapestry`: scores once, under Cat. 1) |

### Category 11: AI Jargon in Human Prose

Terms AI assistants favor that read as machine output in prose written for humans. Each flagged instance scores 2 Lexical points under the standard Lexical formula (see Scoring Algorithm in skill.md). Flag singular and plural forms. Flag only the listed phrases; do not generalize to unlisted compounds.

**Do not flag:**
- Term as section contract (heading or label, not prose): any `## Failure Modes` (or `### Failure Modes`, etc.) heading in any technical document, FMEA table column headers, SRE runbook section titles, bold labels in non-prose contexts (`**Failure Mode:**` in table cells or definition lists). List-item label: term followed by colon or dash (`- failure mode: X`, `- failure mode - X`). A list item that starts with the term and continues as a prose sentence (`- failure mode is the most common...`) is free-running prose; flag it.
- Direct quotations from an external source (vendor alert, RFC, log message, error text). Skip the occurrence entirely.
- Term in a code block, inline code span, or in a sentence describing a code construct by name ("catch the correct error class", "Python's BaseException class hierarchy"). This exemption applies to all six terms listed below; "error class" is the most frequent code-context case, the other five are treated identically. Flag only when the term appears in ordinary prose not describing a specific code construct.
- Categorical veto: the author is formally enumerating a named category of failures that recurs across separate instances, where "bug" or "defect" would collapse a meaningful structural distinction. Detection signals: numbered modes listed by name ("Mode 1: X; Mode 2: Y"), FMEA-style tables with a Failure Mode column, or a section heading that names the category. Absent one of these signals, treat as non-categorical and flag normally. Legitimate example: a postmortem with a named section listing "Mode 1: sensor saturation (occurs under sustained load); Mode 2: clock drift (occurs after failover)"; "defect" would erase the structural distinction between modes. (Kept in sync with `eliminating-ai-slop`'s parallel "Categorical veto" rewriting step; both skills must agree on the same document.)
- Concrete singular use: the term names one specific fault, trigger, or mechanism, even in a single sentence with no enumeration, table, or heading. "The main failure mode is retry amplification after a regional timeout" is a routine, precise technical claim; leave it. This is broader than the Categorical veto: it needs no recurring category and no structural signal, only a real fault named next to the term. It covers how a system fails; a process lapse or a generalization is not a mechanism, so "the failure mode here was skipping code review" still flags. "There could be a failure mode here" with nothing named still flags. (Kept in sync with the matching step in `eliminating-ai-slop`.)

**Flag in all other free-running prose at 2 pts per instance:**

Note: the code/API context exemption (third bullet above) applies to all six phrases. An agent flagging from this table must check all five exemption bullets before scoring.

| Phrase | Category |
|--------|----------|
| failure mode, failure modes | ai-jargon (code/API context exempt, see third bullet above) |
| failure class, failure classes | ai-jargon (code/API context exempt, see third bullet above) |
| failure pattern, failure patterns | ai-jargon (code/API context exempt, see third bullet above) |
| error class, error classes | ai-jargon (code/API context exempt, see third bullet above) |
| defect pattern, defect patterns | ai-jargon (code/API context exempt, see third bullet above) |
| failure category, failure categories | ai-jargon (code/API context exempt, see third bullet above) |

Default replacement when no eliminating-ai-slop pass follows: name the actual problem ("the bug was X", "what typically goes wrong is Y"). Full replacement guidance is in `eliminating-ai-slop`.

---

## Semantic Fabrication Patterns

Patterns where the text asserts things the author has no basis for. These score on the **Semantic dimension** (5 points each) and are the highest-priority findings to surface: they are factual defects, not style defects. List them in Top Offenders even when the Semantic dimension is already capped. Resurrected corrected claims scores only when session/draft history is in context; it has no row in the skill.md scoring table for that reason.

| Pattern | Description | Detection |
|---------|-------------|-----------|
| Framework name-dropping | Invoking a framework or model without a concrete claim attached ("Framed through Growth Mindset: People, Process, Technology.") | One test: does any claim in the paragraph depend on the framework's own terms or meaning — not just appear near it? An unrelated assertion elsewhere in the paragraph does not count (e.g. "Framed through Growth Mindset: People, Process, Technology. Revenue grew 12% this quarter." still flags: the revenue claim doesn't depend on the framework). A framework named once and then actually applied — later claims that use its own terms — over several sentences (e.g. STRIDE, RICE) is not name-dropping. Quick sanity check for the same test: if deleting the framework mention changes nothing about what the surrounding claims mean, it was never tied to anything — flag it |
| Fabricated open questions / CTAs | Inventing "open questions", "next steps", or ownership gaps for topics that are closed or decided (e.g., claiming a decommissioned product "needs an owner and a timeline") | Flag unresolved-item framing that cites no source (ticket, doc, user statement). Exempt explicitly exploratory content (brainstorms, draft plans) where raising questions is the point |
| Process metrics presented as results | Activity counts standing in for outcomes ("30 candidates tracked, 29 phone screens, 4 debriefs" burying "4 bar-raising hires made") | In a results/outcomes context, ask: do the numbers describe what was achieved, or how busy the process was? Funnel stats belong in appendices, not results lines |
| Resurrected corrected claims | Reintroducing a claim the author already corrected earlier in the same document or session | Requires session/draft history, not the text alone: detectable only when prior corrections are in context. The prevention rule lives in `eliminating-ai-slop` (sweep for struck phrasings before each edit pass) |
| Verification theater | Completion or certainty claims with no evidence attached: "all tests pass", "no regressions", "this fixes the issue", "fully tested" with no test command, CI run, test name, or reproduction case | Ask: could a reader check this claim right now from what is on the page? If not, it is an assertion, not a verification. Exempt when the claim is immediately followed by its own evidence ("all tests pass: `npm test`, 142/142") |

**Detection heuristic for state claims:** flag claims about team, product, or project state that cite no source. The corresponding writing-time rule (check the source of truth — the project wiki or ticket tracker — before asserting state) lives in `eliminating-ai-slop`.

---

## Content-Type-Specific Patterns

### CV/Resume Patterns

| Pattern | Category | Severity |
|---------|----------|----------|
| "Responsible for" | duties-not-achievements | High |
| "Assisted with" | passive-contribution | Medium |
| "Helped to" | passive-contribution | Medium |
| "Worked on" | vague-contribution | Medium |
| "Involved in" | vague-contribution | Medium |
| "Participated in" | vague-contribution | Medium |
| "Passionate about" | empty-enthusiasm | High |
| "Team player" | generic-trait | Medium |
| "Detail-oriented" | generic-trait | Medium |
| "Self-motivated" | generic-trait | Medium |
| "Strong communication skills" | generic-trait | Medium |
| "Problem solver" | generic-trait | Medium |
| "Results-driven" | generic-trait | Medium |
| Skills list >15 items | skills-inflation | High |
| No metrics in experience | missing-quantification | High |

### Cover Letter Patterns

| Pattern | Category | Severity |
|---------|----------|----------|
| "I am writing to express my interest" | generic-opener | High |
| "I am excited to apply" | generic-opener | Medium |
| "I believe I would be a great fit" | unsupported-claim | Medium |
| "Thank you for your consideration" | generic-closer | Low |
| No company-specific details | missing-research | High |
| "Intersection of X and Y" | chatgpt-cliche | High |

### Email Patterns

| Pattern | Category | Severity |
|---------|----------|----------|
| "Hope this email finds you well" | corporate-opener | Medium |
| "Per my last email" | passive-aggressive | Medium |
| "Just wanted to follow up" | hedge-opener | Low |
| "Please don't hesitate to reach out" | filler-closer | Low |
| Ask buried in paragraph 3+ | buried-lead | High |

### LinkedIn Patterns

| Pattern | Category | Severity |
|---------|----------|----------|
| "I'm humbled to announce" | humble-brag | High |
| "Excited to share" | engagement-bait | Medium |
| "Thrilled to announce" | engagement-bait | Medium |
| "Who else agrees?" | engagement-bait | High |
| "Drop a 🙋 if you..." | engagement-bait | High |
| Line breaks after every sentence | listicle-abuse | Medium |

### Commit Message Patterns

| Pattern | Category | Severity |
|---------|----------|----------|
| Generic verb + generic object, no concrete token ("feat: enhance X functionality", "fix: resolve issue with X") | generic-commit-shape | High |
| Unbounded scope words ("all", "various", "multiple", "several") | scope-inflation | Medium |
| "Refactor" where behavior, API, schema, or protocol actually changed | mislabeled-change | Medium |
| Risk with no failure named ("fix potential issue", "improve reliability", "handle edge cases" with no case given) | unnamed-risk | High |

**Detection rule:** require at least one concrete technical token after the type/scope: an endpoint, function or class name, config key, error code, schema field, dependency, or observable behavior. "fix(webhook): reject unsigned callbacks before JSON parsing" passes; "fix: improve webhook handling" does not.

### Code Review Comment Patterns

| Pattern | Category | Severity |
|---------|----------|----------|
| Modal-only finding: "could", "might", "may", "seems" with no trigger, location, or consequence attached | modal-only-comment | High |
| Generic praise: "LGTM" or "Looks great" plus a paragraph of unspecific justification | generic-praise | Medium |
| "Edge cases", "error handling", "performance", or "security" invoked with no case, error, resource, or attacker capability named | unnamed-concern | High |

**Detection rule:** a review comment should name at least two of: the triggering condition, the observable consequence, the location, and the proposed fix or test. "This could cause issues" names none; "When `refreshToken` is absent, `parseToken()` throws before the 401 path; return Unauthorized first" names all four.

---

## Style-Level Tells

Presentation patterns more revealing than individual words. These signal "polished autocomplete" even when the vocabulary passes the lexical filter. Points contribute to the **Structural dimension** (max 25 total); the formula applies variable weights for these entries rather than the uniform 5-point rate used for content-structure patterns.

| Tell | Description | Points |
|------|-------------|--------|
| Random bolding | Mid-sentence bolding for rhythm, not emphasis | +3 |
| One-sentence paragraphs | Single lines broken out for dramatic effect | +2 each (max +6) |
| Listicle without answers | Bullet points that raise questions, never resolve them | +4 |
| Abstract noun stacking | Three+ vague nouns in a row ("synergy, alignment, outcomes") | +3 |
| Generic thought-leadership voice | Claims any author could make without any first-person knowledge | +4 |
| Safe-qualifier saturation | "may," "could," "potentially," "in some cases" dominate the text | +3 |
| Summary that restates | Conclusion paragraph repeats thesis without adding evidence | +4 |
| Excessive em-dash rhythm | Em dash used as pacing crutch rather than parenthetical emphasis | +0 (see Cat. 7 — already counted in Lexical/Cat. 7; no additional Structural points) |
| Title-case emphasis | Random Title Casing of Concepts That Are Not Proper Nouns | +2 |

## Profanity Detection (HARD BLOCK)

Profanity in user-facing documentation triggers a **HARD BLOCK** — the content cannot be published.

| Category | Action |
|----------|--------|
| Explicit terms | BLOCK |
| Scatological | BLOCK |
| Religious profanity | BLOCK |
| Body vulgarities | BLOCK |
| Gendered slurs | BLOCK |
| Internet shorthand (wtf, stfu) | BLOCK |

Each profanity match adds **+50 points** (effectively maxes the score).

**Seed profanity patterns:**

```bash
node scripts/slop-dictionary.js seed-profanity
```

---

## Time Estimate Inflation

AI-generated documentation frequently contains inflated time estimates.

| Stated Estimate | Flag If | Realistic Range (AI-assisted) |
|-----------------|---------|-------------------------------|
| Install/setup | > 10 min | 3-5 min (scripted) |
| Configuration | > 15 min | 2-5 min |
| Single feature | > 4 hours | 30 min - 2 hours |
| Bug fix | > 2 hours | 15-60 min |
| Documentation page | > 1 hour | 15-30 min |

**Scoring:**

- Mild inflation (2-3x realistic): +3 points
- Moderate inflation (3-5x realistic): +5 points
- Severe inflation (>5x realistic): +8 points

---

## Fabricated Calendar Timelines

AI-generated plans frequently assign calendar periods to phases with zero basis. The AI has no information about team capacity, competing priorities, or actual task duration — yet confidently writes "Weeks 1-2", "Sprint 1", "Q3 target."

**Detection patterns:**

| Pattern | Example | Score |
|---------|---------|-------|
| Phase + calendar period | "Phase 2 (Weeks 1-2)" | +8 points |
| Sprint numbering | "Sprint 1: schema extraction" | +5 points |
| Quarter/month targets | "Target: Q3 2026" | +5 points |
| Week-numbered milestones | "By Week 3, we should have..." | +8 points |
| Duration estimates for multi-step plans | "Timeline: 4-6 weeks" | +5 points |

**Why this is slop:** The AI is performing the *appearance* of project management without any of the inputs that make project management useful (team size, velocity, competing work, holidays, dependencies on external teams). The result looks professional but is meaningless.

**What to use instead:** Dependency ordering + exit criteria. "Phase 2 depends on Phase 1 being complete. Exit criterion: X is true." This is honest — it says what must happen without pretending to know when.

**Scoring:**

- Any calendar-period assignment to a phase: +8 points (severe — it's fabrication)
- Duration estimate without basis: +5 points

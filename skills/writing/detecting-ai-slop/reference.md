# Detecting AI Slop - Pattern Reference

> **Parent skill:** [skill.md](./skill.md)
> **Last Updated:** 2026-03-12

This file contains the complete pattern dictionary for slop detection. The core skill.md loads this on demand.

---

## Lexical Patterns (40 points max)

Each pattern found adds 2 points to lexical score.

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

### Category 7: Typographic Tells

AI-generated text often uses specific punctuation patterns.

| Pattern | Category | Notes |
|---------|----------|-------|
| — (em-dash) | typographic-tell | Replace with comma, semicolon, colon, or parentheses |
| … (ellipsis character) | typographic-tell | Use three periods (...) or rewrite |
| " " (smart quotes) | typographic-tell | Context-dependent; flag if inconsistent |

**Em-dash detection is HIGH PRIORITY.** Each instance adds 3 points (higher weight than standard lexical patterns).

### Category 8: Clichés and Stock Phrases

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

---

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

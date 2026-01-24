---
name: reviewing-ai-text
description: Use when reviewing or editing AI-generated text to detect and eliminate slop - the telltale patterns of machine-like writing including overused boosters, formulaic structure, excessive hedging, and hollow specificity
---

# Reviewing AI Text

## Overview

AI slop is the signature of lazy machine generation: formulaic structure, hollow abstraction, and sycophantic tone that a careful human expert would never write.

**Core principle:** Real expertise is specific, opinionated, and unafraid of asymmetry.

## When to Use

- Before publishing AI-assisted documentation
- When editing AI-generated content for human consumption
- When reviewing text that "feels" robotic but you can't pinpoint why
- To self-audit your own responses for slop patterns

## Quick Reference: Slop Signals

> **Guidelines:** See [CLAUDE.md](../../CLAUDE.md) for writing standards.

### Category 1: Generic Boosters (Kill or Quantify)

These add no information. Delete or replace with specific metrics.

| Phrase | Action | Example Fix |
|--------|--------|-------------|
| incredibly | delete | "incredibly fast" → "processes 1000 req/s" |
| extremely | delete | "extremely important" → "blocks release" |
| highly | delete | "highly scalable" → "handles 10x load" |
| very | delete | "very large" → "2TB" |
| truly | delete | "truly innovative" → [describe the innovation] |
| absolutely | delete | "absolutely essential" → "required for X" |
| definitely | delete | "definitely works" → "tested with Y" |
| really | delete | "really good" → [specific quality] |
| quite | delete | "quite complex" → "47 dependencies" |
| remarkably | delete | "remarkably efficient" → "3x faster than Z" |
| exceptionally | delete | [same pattern] |
| particularly | delete | [same pattern] |
| especially | delete | [same pattern] |
| significantly | quantify | "significantly faster" → "40% faster" |
| substantially | quantify | [same pattern] |
| considerably | quantify | [same pattern] |
| dramatically | quantify | [same pattern] |
| tremendously | delete | [same pattern] |
| immensely | delete | [same pattern] |
| profoundly | delete | [same pattern] |

### Category 2: Vague Quality Words (Describe Instead)

These claim quality without evidence. Replace with specific capabilities.

| Phrase | Problem | Fix |
|--------|---------|-----|
| robust | meaningless | "handles network failures with retry" |
| seamless | meaningless | "no config required" or "zero-downtime deploy" |
| comprehensive | meaningless | "covers 47 edge cases" or list what's included |
| elegant | subjective | describe the actual design |
| powerful | meaningless | "supports X, Y, Z operations" |
| flexible | meaningless | "configurable via YAML" or list options |
| intuitive | subjective | "no docs needed for basic use" |
| user-friendly | subjective | "3-click workflow" or cite usability test |
| streamlined | meaningless | describe what was removed |
| optimized | meaningless | "reduced latency from 200ms to 50ms" |
| efficient | meaningless | "uses 50% less memory than v1" |
| scalable | meaningless | "tested to 1M concurrent users" |
| reliable | meaningless | "99.9% uptime over 12 months" |
| secure | meaningless | "SOC2 certified" or list controls |
| modern | meaningless | name the specific tech |
| innovative | meaningless | describe what's new |
| sophisticated | meaningless | describe the complexity |
| advanced | meaningless | describe the capability |
| state-of-the-art | meaningless | cite benchmark or comparison |
| best-in-class | unsubstantiated | cite comparison data |
| world-class | unsubstantiated | cite comparison data |
| enterprise-ready | meaningless | list enterprise features |
| production-grade | meaningless | describe testing/reliability |
| battle-tested | meaningless | cite production usage stats |
| industry-leading | unsubstantiated | cite market data |

### Category 3: Hype Words (Delete Always)

Marketing speak with zero information content.

| Phrase | Replacement |
|--------|-------------|
| game-changing | describe the actual change |
| revolutionary | describe what's different |
| transformative | describe the transformation |
| disruptive | describe what it disrupts |
| cutting-edge | name the specific technology |
| next-generation | describe the improvement |
| bleeding-edge | name the specific technology |
| groundbreaking | describe what's new |
| paradigm-shifting | delete entirely |
| synergy | delete or explain the interaction |
| holistic | delete or list components |
| ecosystem | name the specific components |
| leverage | use "use" |
| utilize | use "use" |
| facilitate | use "help" or "allow" |
| enable | use "let" |
| empower | use "let" or "give" |
| optimize | describe the specific improvement |
| streamline | describe what was simplified |
| accelerate | quantify the speedup |
| amplify | quantify the increase |
| unlock | describe what becomes possible |
| drive | use "cause" or be specific |
| spearhead | use "lead" |
| champion | use "support" or "advocate" |
| pivot | use "change" or "switch" |

### Category 4: Glue Phrases (Delete Entirely)

Filler that adds no meaning. Delete and start with the actual content.

| Phrase | Action |
|--------|--------|
| It's important to note that | delete, say the thing |
| It's worth mentioning that | delete |
| It should be noted that | delete |
| It goes without saying that | delete (if obvious, don't say it) |
| Needless to say | delete |
| As you may know | delete |
| As we all know | delete |
| In today's world | delete |
| In today's digital age | delete |
| In today's fast-paced environment | delete |
| In the modern era | delete |
| At the end of the day | delete |
| When all is said and done | delete |
| Having said that | use "But" or delete |
| That said | use "But" or delete |
| That being said | use "But" or delete |
| With that in mind | delete |
| With that being said | delete |
| Let me explain | delete, just explain |
| Let me walk you through | delete |
| Let's dive in | delete |
| Let's explore | delete |
| Let's take a look at | delete |
| Let's break this down | delete |
| Here's the thing | delete |
| The thing is | delete |
| The fact of the matter is | delete |
| At this point in time | use "now" |
| In order to | use "to" |
| Due to the fact that | use "because" |
| For the purpose of | use "to" or "for" |
| In the event that | use "if" |
| In light of | use "because" or "given" |
| With regard to | use "about" or "for" |
| In terms of | use "for" or rephrase |
| On a daily basis | use "daily" |
| First and foremost | use "first" |
| Last but not least | use "finally" |
| Each and every | use "each" or "every" |
| One and only | use "only" |
| Plain and simple | delete |
| Pure and simple | delete |

### Category 5: Hedge Patterns (Commit or Delete)

Weasel words that avoid commitment. Either commit to a position or delete.

| Phrase | Problem | Fix |
|--------|---------|-----|
| of course | claims obviousness without proof | delete or prove it |
| naturally | claims obviousness without proof | delete or prove it |
| obviously | claims obviousness without proof | delete or prove it |
| clearly | claims obviousness without proof | delete or prove it |
| certainly | false confidence | delete or provide evidence |
| undoubtedly | false confidence | delete or provide evidence |
| in many ways | weasel | specify which ways |
| to some extent | weasel | quantify the extent |
| in some cases | weasel | specify which cases |
| it depends | lazy | rank the conditions |
| it varies | lazy | describe the variation |
| generally speaking | weasel | specify exceptions |
| for the most part | weasel | quantify |
| more or less | weasel | be precise |
| kind of | weasel | delete or be specific |
| sort of | weasel | delete or be specific |
| somewhat | weasel | quantify |
| relatively | weasel | relative to what? |
| arguably | weasel | make the argument |
| potentially | weasel | assess the probability |
| possibly | weasel | assess the probability |
| might | weasel | assess the probability |
| may or may not | delete | pick one or explain |
| could potentially | redundant weasel | use "might" or commit |
| tends to | weasel | quantify frequency |
| seems to | weasel | verify and commit |
| appears to | weasel | verify and commit |

### Category 6: Sycophantic Phrases (Delete Always)

Never compliment the user or express enthusiasm about helping.

| Phrase | Action |
|--------|--------|
| Great question! | delete |
| Excellent question! | delete |
| That's a great point! | delete |
| Good thinking! | delete |
| I love that idea! | delete |
| What a fascinating topic! | delete |
| Happy to help! | delete |
| I'd be happy to help | delete |
| I'm glad you asked | delete |
| Thanks for asking | delete |
| Absolutely! | delete, just answer |
| Definitely! | delete, just answer |
| Of course! | delete, just answer |
| Sure thing! | delete, just answer |
| No problem! | delete, just answer |
| You're welcome! | delete |
| My pleasure! | delete |
| I appreciate you sharing | delete |
| That's an interesting perspective | delete |
| I understand your concern | delete unless genuinely relevant |

### Category 7: Transitional Filler (Simplify)

Overused transitions that pad word count.

| Phrase | Replacement |
|--------|-------------|
| Furthermore | use "Also" or delete |
| Moreover | use "Also" or delete |
| Additionally | use "Also" or delete |
| In addition | use "Also" or delete |
| However | keep sparingly |
| Nevertheless | use "But" or "Still" |
| Nonetheless | use "But" or "Still" |
| On the other hand | use "But" or delete |
| Conversely | use "But" or be specific |
| In contrast | be specific about contrast |
| Similarly | be specific about similarity |
| Likewise | be specific |
| Consequently | use "So" |
| Therefore | use "So" |
| Thus | use "So" |
| Hence | use "So" |
| Accordingly | use "So" |
| As a result | use "So" |
| For this reason | use "So" or delete |
| To that end | delete or be specific |
| With this in mind | delete |
| Given the above | delete |
| Based on the above | delete |
| As mentioned earlier | delete (reader remembers) |
| As previously stated | delete |
| As noted above | delete |
| Moving forward | delete |
| Going forward | delete |

### Structural Slop

- **Formulaic intro:** Rephrases question → asserts importance → promises overview
- **Template sections:** Overview → Key Points → Best Practices → Conclusion
- **Over-signposting:** "In this section, we will..." / "As mentioned earlier..."
- **Staccato paragraphs:** Many 1-2 sentence paragraphs for false clarity
- **Symmetric coverage:** Equal weight to every axis without prioritization

---

## Domain-Specific Slop Patterns

### Technical Documentation Slop

Patterns common in AI-generated API docs, READMEs, and code comments.

| Pattern | Example | Problem | Fix |
|---------|---------|---------|-----|
| Passive function opener | "This function is used to..." | Indirect | "Parses JSON from stdin" |
| Dismissive "simply" | "Simply call the API..." | Condescending, hides complexity | Delete "simply", add error handling |
| Vague "easy" claims | "Easy to use and configure" | Subjective, unprovable | "Requires 3 env vars" or show example |
| Capability laundry list | "Supports X, Y, Z, and more" | "and more" is lazy | List all or say "see full list at..." |
| Redundant "allows you to" | "Allows you to create..." | Wordy | "Creates..." |
| Empty "powerful" | "A powerful library for..." | Meaningless | Describe what it does |
| Boilerplate prerequisites | "Before you begin, ensure..." | Often unnecessary | Only if truly required |
| Vague error handling | "Handle errors appropriately" | Useless | Show specific error handling code |
| "Best practices" without specifics | "Follow best practices for security" | Lazy | Name the specific practices |
| Placeholder examples | "Replace YOUR_API_KEY with..." | Obvious | Show realistic example values |
| Changelog filler | "Various bug fixes and improvements" | Useless | List the actual fixes |
| Version compatibility vagueness | "Works with recent versions" | Useless | "Requires Node 18+" |

**Technical Doc Red Flags:**
- README longer than the code it documents
- "Getting Started" that doesn't get you started in 5 minutes
- API docs that restate function signatures without explaining when to use them
- Comments that say what code does instead of why

### Marketing/Business Slop

Patterns common in AI-generated press releases, product descriptions, and executive summaries.

| Pattern | Example | Problem | Fix |
|---------|---------|---------|-----|
| Unsubstantiated leadership | "Industry-leading solution" | No evidence | Cite market share or benchmark |
| Transformation promises | "Transform your workflow" | Vague hype | Describe specific change |
| Customer count padding | "Trusted by thousands" | Vague | "Used by 2,847 companies" |
| Satisfaction claims | "Loved by customers" | Unverifiable | Cite NPS score or review stats |
| Time-saving claims | "Save hours every week" | Unquantified | "Reduces report time from 4h to 20min" |
| ROI promises | "Maximize your ROI" | Empty | Show calculation or case study |
| Future-proofing claims | "Future-proof your business" | Meaningless | Describe specific adaptability |
| Partnership announcements | "Strategic partnership to drive innovation" | Empty | Describe what the partnership does |
| Mission statement filler | "Committed to excellence" | Meaningless | Delete or show evidence |
| Values signaling | "We believe in putting customers first" | Empty | Show policy or action |
| Ecosystem buzzwords | "End-to-end solution" | Vague | List what's included |
| Scalability promises | "Scales with your business" | Vague | "Handles 1K to 1M users" |

**Marketing Red Flags:**
- Press release with no news (just repackaged existing info)
- Product description that could apply to any competitor
- Case study without specific metrics
- Testimonial without attribution

### Academic/Research Slop

Patterns common in AI-generated literature reviews, methodology sections, and abstracts.

| Pattern | Example | Problem | Fix |
|---------|---------|---------|-----|
| Vague attribution | "The literature suggests..." | Which literature? | Cite specific papers |
| Appeal to consensus | "It is well known that..." | Lazy, possibly false | Cite source or delete |
| Scope hedging | "This is beyond the scope..." | Often excuse for gaps | Acknowledge limitation directly |
| Future work dumping | "Further research is needed" | Boilerplate | Specify what research and why |
| Methodology padding | "A rigorous methodology was employed" | Empty | Describe the methodology |
| Significance claims | "This research is significant because..." | Self-promotion | Let results speak |
| Contribution inflation | "Novel contribution to the field" | Unsubstantiated | Describe what's new specifically |
| Gap identification cliché | "There is a gap in the literature" | Overused | Describe the specific gap |
| Limitation minimizing | "Despite some limitations..." | Dismissive | List limitations explicitly |
| Generalization hedging | "Results may not generalize" | Obvious | Specify to what populations |
| Implication vagueness | "Has implications for practice" | Lazy | State the specific implications |
| Passive voice overuse | "It was found that..." | Hides agency | "We found..." or "Smith found..." |

**Academic Red Flags:**
- Abstract that restates the title without adding information
- Literature review that summarizes without synthesizing
- Methodology section that could apply to any study
- Discussion that restates results without interpreting them

---

## Detection Heuristics

### 1. Sentence Rhythm Test

Read aloud. If every sentence is 15-22 words with identical cadence, it's slop.
**Fix:** Vary sentence length drastically. Short. Then a long, complex sentence with subordinate clauses. Then another short punch.

### 2. Specificity Test

Does the text name specific tools, versions, tradeoffs, or constraints?
**Slop:** "Focus on clear communication and alignment with stakeholders."
**Real:** "Use Slack threads for async decisions; Zoom only for contentious items. Don't invite more than 4 people."

### 3. Asymmetry Test

Does the text commit to rankings, preferences, or opinionated tradeoffs?
**Slop:** "Both options have merits and considerations."
**Real:** "Use Postgres unless you're at >10M writes/day and can afford DynamoDB's operational complexity."

### 4. Constraint Test

Does the text acknowledge cost, politics, legacy systems, or messy reality?
**Slop:** "Adopt a microservices architecture for scalability."
**Real:** "Microservices add 3x operational overhead. Unless you have dedicated platform team, stay monolithic."

### 5. First-Person Test

Can you insert "in my experience" or "on my last project" naturally?
**Slop:** Generic enough to apply anywhere; says nothing specific.
**Real:** Grounded in specific context that would change the recommendation.

## The Rewrite Process

1. **Identify category** - Which slop type(s) dominate?
2. **Kill the killers** - Axe every word/phrase from the quick reference tables
3. **Inject specificity** - Add tool names, numbers, version constraints, concrete artifacts
4. **Break symmetry** - Commit to rankings, skip uninteresting branches
5. **Vary rhythm** - Rewrite for sentence length diversity
6. **Add constraints** - Acknowledge what makes this hard in practice
7. **Delete meta-commentary** - Remove all "let me explain" framing

## Example Transformation

**Before (pure slop):**
> In today's rapidly evolving digital landscape, it's crucial for organizations to leverage cutting-edge technologies. By adopting a holistic approach to digital transformation, you can unlock significant value and drive meaningful outcomes. Let's explore the key considerations.

**After (real):**
> Most "digital transformation" projects fail because they buy tools before fixing process. Start with a value stream map of your worst bottleneck. If you can't name it, you don't need new tech—you need visibility.

## Advanced Detection: Tone Drift

Watch for unexplained shifts:
- Casual → formal within paragraphs (confused persona)
- Technical → marketing speak (selling, not explaining)
- Empathy boilerplate: "I understand how challenging..." repeated across contexts
- Excessive cheerfulness: "I'm happy to help!" in grim contexts

## Advanced Detection: Argument Structure

**Enumerations that don't interact:** Bullets could be reordered freely—no cumulative case.
**Circular sections:** Rephrases thesis without new evidence.
**Balanced to a fault:** Every pro has matching con of equal weight (reality is asymmetric).
**Absent negative knowledge:** Never says "I don't know" or "this is speculative."

## Typographic Slop

- Em-dash abuse: "punchy—but—annoying" patterns for false energy
- Excessive exclamation points for enthusiasm
- Emoji as crutch for personality
- Parenthetical asides overused (making every point hedged like this)

## Chat-Specific Red Flags

- Direct prompt restatement: "You're asking how to X, so let's break it down"
- Meta-commentary: "Here's a breakdown:" / "Let's explore pros and cons"
- Educational scaffolding for experts: Beginner definitions when audience is advanced
- Consistently neutral persona: No stakes, preferences, or history admitted

---

## Stylometric Detection

Statistical patterns that distinguish AI text from human writing. These require counting but no special tools.

### 1. Sentence Length Variance Test

**Heuristic:** Count words in 5-10 consecutive sentences. Calculate the range (max - min).

| Pattern | Range | Verdict |
|---------|-------|---------|
| AI-typical | 3-5 words | Flag: uniform cadence |
| Human-typical | 10-20 words | Pass: natural variation |

**Example - AI pattern (flag):**
> The new system provides significant improvements. (7) Users can expect faster response times. (6) This update addresses several key issues. (7) The team worked hard on optimization. (7) Documentation has been updated accordingly. (5)

Range: 7-5 = 2. Flag as uniform.

**Example - Human pattern (pass):**
> It works. (2) The new caching layer reduced p99 latency from 340ms to 89ms, which finally got the SRE team off our backs. (21) Still breaks on edge cases. (5) See JIRA-4521. (2)

Range: 21-2 = 19. Natural variation.

### 2. Type-Token Ratio (Vocabulary Diversity)

**Heuristic:** In a 100-word sample, count unique words. Divide by 100.

| TTR | Interpretation |
|-----|----------------|
| < 0.50 | Low diversity, repetitive (AI pattern) |
| 0.50-0.65 | Normal range |
| > 0.65 | High diversity (human or edited) |

**Quick check:** If you see the same adjective 3+ times in 200 words, flag it.

**AI pattern:** "The system is robust. The architecture is robust. This provides a robust foundation."

**Human pattern:** Uses synonyms, or better, uses specific descriptions instead of repeated adjectives.

### 3. Hapax Legomena Check

**Definition:** Words that appear exactly once in a text.

**Heuristic:** In 500 words, 40-60% of vocabulary should be hapax (one-time words).

| Hapax % | Interpretation |
|---------|----------------|
| < 35% | Low: repetitive vocabulary (AI pattern) |
| 35-60% | Normal range |
| > 60% | High: varied vocabulary |

**Why it matters:** AI tends to reuse the same "safe" words. Humans use more one-off specific terms.

**Quick check:** Scan for repeated "filler" words: "various", "specific", "particular", "significant". If these appear 3+ times, flag.

### 4. Zipf Distribution Deviation

**Background:** In natural language, word frequency follows Zipf's law: the nth most common word appears ~1/n as often as the most common word.

**Heuristic (simplified):** AI text often has:
- Overuse of mid-frequency "safe" words (robust, significant, comprehensive)
- Underuse of rare, specific words (proper nouns, technical terms, slang)

**Quick check:** Does the text use any:
- Proper nouns (specific people, companies, products)?
- Technical jargon appropriate to the domain?
- Colloquialisms or informal language?

If no to all three, flag as potentially AI-generated.

### 5. Entropy Pattern Analysis

**Background:** Entropy measures unpredictability. AI text has lower entropy (more predictable next-word choices).

**Heuristic (no tools needed):** Read a sentence and try to predict the next word. If you can consistently predict 3+ words in a row, the text has low entropy.

**AI pattern (predictable):**
> "In today's fast-paced [world], it's important to [stay] ahead of the [curve]."

You could predict "world", "stay", "curve" easily.

**Human pattern (less predictable):**
> "The deploy broke at 3am. Jenkins was down. I SSHed in from my phone."

Harder to predict specific details.

### 6. N-gram Repetition Check

**Heuristic:** Look for repeated 3-4 word phrases within the same document.

**AI pattern:**
- "it's important to note" (appears 3x)
- "in order to" (appears 4x)
- "a wide range of" (appears 2x)

**Human pattern:** Rarely repeats exact multi-word phrases unless intentional (refrain, technical term).

**Quick check:** Ctrl+F for common AI phrases. If any appear 2+ times, flag.

---

## Output Format for Structured Review

When reviewing systematically, report findings:

```json
{
  "slop_signals": {
    "lexical": {
      "generic_boosters": ["incredibly", "robust", "leverage"],
      "buzzword_density": "high",
      "repeated_glue": ["it's important to note"],
      "sycophantic_phrases": ["Great question!"]
    },
    "rhythm": {
      "sentence_length_variance": "low (range: 3)",
      "staccato_paragraphs": true
    },
    "structure": {
      "formulaic_intro": true,
      "template_sections": true,
      "over_signposting": true
    },
    "semantic": {
      "specificity": "none",
      "tradeoff_commitment": "none",
      "constraints_acknowledged": false
    },
    "tone": {
      "neutral_persona": true,
      "cheerful_helper": true
    },
    "stylometric": {
      "sentence_variance_range": 3,
      "type_token_ratio": 0.42,
      "repeated_adjectives": ["robust", "significant"],
      "predictable_phrases": true,
      "proper_nouns_present": false
    },
    "domain_specific": {
      "domain": "technical",
      "patterns_found": ["passive function opener", "vague error handling"]
    }
  },
  "severity": "high",
  "priority_fixes": [
    "Kill all generic boosters",
    "Add specific tool names and version numbers",
    "Commit to recommendations instead of 'it depends'",
    "Vary sentence length (current range: 3, target: 10+)",
    "Add proper nouns and specific technical terms"
  ]
}
```

## Self-Check Before Publishing

- [ ] No words from Categories 1-7 tables remain (or justified)
- [ ] At least one specific tool/artifact/number mentioned
- [ ] Asymmetric recommendations (not "both have pros and cons")
- [ ] Varied sentence length (range > 10 words between shortest and longest)
- [ ] No meta-commentary ("let me explain", "in this section")
- [ ] Constraints and tradeoffs acknowledged
- [ ] No repeated adjectives (same word 3+ times)
- [ ] Proper nouns present (specific names, products, versions)
- [ ] No domain-specific slop patterns for target domain
- [ ] Would a subject-matter expert cringe? If unsure, more specific.

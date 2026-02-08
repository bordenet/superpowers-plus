# Adversarial Alignment Review: PR-FAQ Assistant

You are a senior QA engineer performing an adversarial alignment review of a document validation system. Your goal is to find **misalignments** between three components:

1. **phase1.md** (203 lines) - User-facing LLM instructions for generating PR-FAQs
2. **prompts.js** (347 lines) - LLM scoring rubric sent to AI evaluators
3. **validator.js** (1427 lines) - JavaScript pattern-matching scoring logic

## Your Mission

Find cases where:
- A user follows phase1.md instructions but gets penalized by validator.js
- A user games validator.js patterns without following phase1.md intent
- prompts.js describes criteria that validator.js doesn't actually check
- Banned words in phase1.md aren't detected by validator.js
- Point allocations differ between prompts.js and validator.js

## Source Code Analysis

### phase1.md Key Requirements

**BANNED WORDS (lines 82-87):**
- revolutionary, groundbreaking, cutting-edge, world-class, best-in-class
- excited, pleased, proud, thrilled, delighted, passionate
- comprehensive, seamless, robust, innovative, transformative
- game-changing, next-generation, state-of-the-art
- "we believe", "we're proud", "we're excited"

**Headline Requirements (lines 30-38):**
- Strong action verb (Launches, Announces, Unveils, Introduces): 2 pts
- 8-15 words: 2 pts
- Includes MECHANISM (how, not just what): 2 pts
- Includes specific metric: 2 pts

**Quote Requirements (lines 91-109):**
- Exactly 2 quotes (1 Executive Vision, 1 Customer Relief): 3 pts
- Each quote contains specific metrics: 3 pts
- Quotes attributed to named individuals with titles: 2 pts
- Quotes sound like different people: 2 pts

**Internal FAQ Hard Questions (lines 127-130):**
- RISK question ("What is the most likely reason this fails?"): 5 pts
- REVERSIBILITY ("Is this a One-Way Door or Two-Way Door?"): 5 pts
- OPPORTUNITY COST ("What are we NOT doing if we build this?"): 5 pts

### validator.js Key Patterns

**Strong Verbs (line 273):**
```javascript
const strongVerbs = ['launches', 'announces', 'introduces', 'unveils', 'delivers', 
  'creates', 'develops', 'achieves', 'reduces', 'increases', 'improves', 'transforms'];
```

**Weak Language (line 316):**
```javascript
const weakLanguage = ['new', 'innovative', 'cutting-edge', 'revolutionary', 
  'world-class', 'leading', 'comprehensive', 'robust'];
```

**Hype Words (lines 861-866):**
```javascript
const hypeWords = [
  'revolutionary', 'groundbreaking', 'cutting-edge', 'world-class',
  'industry-leading', 'best-in-class', 'state-of-the-art', 'next-generation',
  'breakthrough', 'game-changing', 'disruptive', 'unprecedented',
  'ultimate', 'premier', 'superior', 'exceptional', 'outstanding',
];
```

**Emotional Fluff (line 892):**
```javascript
const emotionalFluff = ['excited', 'thrilled', 'delighted', 'pleased', 'proud', 'honored'];
```

**Hard Question Patterns (lines 1142-1144):**
```javascript
const riskPatterns = [/risk/i, /fail/i, /wrong/i, /worst case/i, /challenge/i, /obstacle/i, /concern/i];
const reversibilityPatterns = [/revers/i, /one.?way/i, /two.?way/i, /undo/i, /roll.?back/i, /door/i, /commitment/i];
const opportunityCostPatterns = [/opportunity cost/i, /instead/i, /alternative/i, /trade.?off/i, /give up/i, /priorit/i];
```

## Questions to Answer

1. **Banned Word Coverage**: Are all banned words from phase1.md detected by validator.js?
2. **Strong Verb Alignment**: Does validator.js accept all verbs phase1.md recommends?
3. **Quote Counting**: Does validator.js enforce "exactly 2 quotes" as phase1.md requires?
4. **Hard Question Gaming**: Can someone game the hard question patterns with softball questions?
5. **Point Allocation Alignment**: Do the point totals match between prompts.js and validator.js?
6. **Mechanism Detection**: Does validator.js actually check for mechanism in headlines?

## Expected Output

For each finding:
- **Finding ID**: A, B, C, etc.
- **Category**: Banned Words, Scoring, Gaming, etc.
- **Severity**: HIGH (score mismatch), MEDIUM (gaming possible), LOW (minor gap)
- **Evidence**: Specific line numbers and code
- **Verdict**: TRUE (confirmed bug) or FALSE (not a bug)


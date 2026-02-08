# Adversarial Alignment Review: JD Assistant

You are a senior QA engineer performing an adversarial alignment review of a job description validation system. Your goal is to find **misalignments** between three components:

1. **phase1.md** (137 lines) - User-facing LLM instructions for generating job descriptions
2. **prompts.js** (222 lines) - LLM scoring rubric sent to AI evaluators  
3. **validator.js** (386 lines) - JavaScript pattern-matching scoring logic

## Your Mission

Find cases where:
- A user follows phase1.md instructions but gets penalized by validator.js
- A user games validator.js patterns without following phase1.md intent
- prompts.js describes criteria that validator.js doesn't actually check
- Banned words in phase1.md aren't detected by validator.js
- Point allocations differ between prompts.js and validator.js

## Source Code Analysis

### phase1.md Key Requirements

**BANNED MASCULINE-CODED WORDS (line 60):**
aggressive, ambitious, assertive, competitive, confident, decisive, determined, dominant, driven, fearless, independent, ninja, rockstar, guru, self-reliant, self-sufficient, superior, leader, go-getter, hard-charging, strong, tough, warrior, superhero, superstar, boss

**BANNED EXTROVERT-BIAS PHRASES (line 67):**
outgoing, high-energy, energetic, people person, gregarious, strong communicator, excellent verbal, team player, social butterfly, thrives in ambiguity, flexible (without specifics), adaptable (without specifics)

**BANNED RED FLAG PHRASES (line 74):**
fast-paced, like a family, wear many hats, always-on, hustle, grind, unlimited pto, work hard play hard, hit the ground running, self-starter, thick skin, no ego, drama-free, whatever it takes, passion required, young dynamic team, work family, family first, 10x engineer, bro culture, party hard

**REQUIRED ELEMENTS:**
- Word count: 400-700 words (line 49)
- Encouragement statement: "If you meet 60-70% of these qualifications, we encourage you to apply" (line 105)
- Compensation range for external postings (line 84)

### validator.js Key Patterns

**MASCULINE_CODED array (lines 181-189):**
```javascript
const MASCULINE_CODED = [
  'aggressive', 'ambitious', 'assertive', 'competitive', 'confident',
  'decisive', 'determined', 'dominant', 'driven', 'fearless',
  'independent', 'ninja', 'rockstar', 'guru', 'self-reliant',
  'self-sufficient', 'superior',
  'leader', 'go-getter', 'hard-charging', 'strong', 'tough',
  'warrior', 'superhero', 'superstar', 'boss'
];
```

**EXTROVERT_BIAS array (lines 195-198):**
```javascript
const EXTROVERT_BIAS = [
  'outgoing', 'high-energy', 'energetic', 'people person', 'gregarious',
  'strong communicator', 'excellent verbal', 'team player'
];
```

**RED_FLAGS array (lines 204-209):**
```javascript
const RED_FLAGS = [
  'fast-paced', 'like a family', 'wear many hats', 'always-on',
  'hustle', 'grind', 'unlimited pto', 'work hard play hard',
  'hit the ground running', 'self-starter', 'thick skin',
  'no ego', 'drama-free', 'whatever it takes', 'passion required'
];
```

**Compensation regex (lines 84-90):**
```javascript
const hasCompensation = /\$[\d,]+\s*[-–—]\s*\$[\d,]+/i.test(text) ||
                        /salary.*\$[\d,]+/i.test(text) ||
                        /compensation.*\$[\d,]+/i.test(text) ||
                        /\$[\d,]+k?\s*[-–—]\s*\$[\d,]+k?/i.test(text) ||
                        /[\d,]+\s*[-–—]\s*[\d,]+\s*(USD|EUR|GBP|CAD|AUD)/i.test(text) ||
                        /[€£][\d,]+\s*[-–—]\s*[€£][\d,]+/i.test(text);
```

**Encouragement regex (line 105):**
```javascript
const hasEncouragement = /60[-–]70%|60\s*[-–]\s*70\s*%|60\s+to\s+70\s*%|meet.*most.*(requirements|qualifications)|we\s+encourage.*apply|don't.*meet.*all.*(qualifications|requirements)/i.test(text);
```

## Questions to Answer

1. **Missing Extrovert-Bias Terms**: phase1.md bans "social butterfly", "thrives in ambiguity", "flexible (without specifics)", "adaptable (without specifics)" - are these in validator.js?

2. **Missing Red Flag Terms**: phase1.md bans "young dynamic team", "work family", "family first", "10x engineer", "bro culture", "party hard" - are these in validator.js?

3. **Point Allocation Alignment**: Do prompts.js and validator.js use the same point values?
   - prompts.js: Length 25, Inclusivity 25, Culture 25, Transparency 25
   - validator.js: Check actual deduction logic

4. **Encouragement Gaming**: Can someone game the encouragement regex with unrelated text?

5. **Compensation Gaming**: Can someone game the compensation regex without a real salary range?

## Expected Output

For each finding:
- **Finding ID**: A, B, C, etc.
- **Category**: Missing Terms, Scoring, Gaming, etc.
- **Severity**: HIGH (score mismatch), MEDIUM (gaming possible), LOW (minor gap)
- **Evidence**: Specific line numbers and code
- **Verdict**: TRUE (confirmed bug) or FALSE (not a bug)


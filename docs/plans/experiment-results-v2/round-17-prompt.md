# Round 17 Adversarial Prompt: jd-assistant | Condition B (Reframe-Self)

## Context

You are performing an adversarial alignment review of the jd-assistant tool. This tool helps create inclusive job descriptions by:
1. Generating JDs via LLM (phase1.md instructions)
2. Scoring them via JavaScript validator (validator.js)
3. Providing LLM-based critique and rewrite (prompts.js)

## Your Task

Find misalignments between:
1. **phase1.md** - User-facing LLM instructions (what users expect)
2. **prompts.js** - LLM scoring rubric (what the LLM is told to check)
3. **validator.js** - JavaScript scoring logic (what actually gets scored)

## Specific Areas to Investigate

### 1. Banned Word Lists Alignment
- phase1.md lists banned words in 3 categories: masculine-coded, extrovert-bias, red flags
- validator.js has MASCULINE_CODED, EXTROVERT_BIAS, RED_FLAGS arrays
- prompts.js has its own lists in the scoring rubric
- **Question**: Are all three lists identical? Are there words in phase1.md not in validator.js?

### 2. Penalty Caps and Scoring
- phase1.md says "-5 pts each" for various violations
- validator.js has `Math.min()` caps on penalties
- **Question**: Can a user game the system by using many banned words knowing the penalty is capped?

### 3. Encouragement Statement Detection
- phase1.md requires: "If you meet 60-70% of these qualifications, we encourage you to apply"
- validator.js has a regex for this
- **Question**: Can this be gamed with partial matches? Does "we encourage you to apply" alone pass?

### 4. Compensation Range Detection
- phase1.md requires clear salary range like "$170,000 - $220,000"
- validator.js has regex patterns for compensation
- **Question**: Does "competitive salary" or "$0 - $999,999" pass the check?

### 5. Word Count Validation
- phase1.md says 400-700 words
- validator.js checks this
- **Question**: Is the penalty proportional? Can you pad with filler to hit 400?

### 6. Slop Detection Integration
- slop-detection.js has comprehensive AI pattern detection
- validator.js caps slop penalty at 5 points
- **Question**: Is 5 points enough for a JD full of buzzwords? Can you game by using many buzzwords?

### 7. Internal Posting Bypass
- phase1.md says skip compensation for internal postings
- validator.js detects "internal posting" text
- **Question**: Can external postings game by including "internal posting" text?

### 8. De-Duplication Rule
- phase1.md has a "De-Duplication Rule" requiring unique content per section
- **Question**: Does validator.js check for duplicate content between sections?

### 9. Specificity Requirements
- phase1.md requires "concrete responsibilities" and "measurable requirements"
- **Question**: Does validator.js check for specificity? Or just word presence?

### 10. Company Mandated Sections
- validator.js has extractMandatedSections() to skip [COMPANY_PREAMBLE] content
- **Question**: Can users wrap banned words in these tags to bypass detection?

## Output Format

For each finding:
1. **Category**: Gaming Vulnerability / Enforcement Gap / Semantic Gap / Missing Check
2. **Severity**: CRITICAL / HIGH / MEDIUM / LOW
3. **Evidence**: Specific line numbers and code
4. **Verdict**: TRUE bug / FALSE (working as designed) / PARTIAL

Focus on findings that are:
- Verifiable with grep/node commands
- Represent actual scoring discrepancies
- Could be exploited by adversarial users


# Round 18 Adversarial Prompt: one-pager | Condition D (Reframe-External)

## Context

You are performing an adversarial alignment review of the one-pager tool. This tool helps create concise one-pager documents by:
1. Generating one-pagers via LLM (phase1.md instructions)
2. Scoring them via JavaScript validator (validator.js)
3. Providing LLM-based critique and rewrite (prompts.js)

## Your Task

Find misalignments between:
1. **phase1.md** - User-facing LLM instructions (what users expect)
2. **prompts.js** - LLM scoring rubric (what the LLM is told to check)
3. **validator.js** - JavaScript scoring logic (what actually gets scored)

## Specific Areas to Investigate

### 1. Banned Vague Language Enforcement
- phase1.md lists banned terms: "improve", "enhance", "optimize", "efficient", "better/faster/easier", "significant/substantial"
- **Question**: Does validator.js check for these specific banned terms? Or just general slop?

### 2. Banned Filler Phrases
- phase1.md bans: "It's important to note that...", "In today's fast-paced world...", "Let's dive in...", etc.
- **Question**: Does validator.js detect these specific phrases?

### 3. Banned Buzzwords
- phase1.md bans: leverage, utilize, synergy, cutting-edge, game-changing, robust/seamless/comprehensive
- **Question**: Does validator.js check for these specific buzzwords?

### 4. Word Count Enforcement
- phase1.md says "Maximum 450 words"
- **Question**: Does validator.js enforce this limit? What's the penalty?

### 5. Circular Logic Detection
- prompts.js says "Cap total score at 50 maximum" for circular logic
- **Question**: Does validator.js actually cap at 50? How robust is the detection?

### 6. [Baseline] → [Target] Format
- phase1.md requires metrics in "[Baseline] → [Target]" format
- **Question**: Does validator.js check for this specific format? Or just any numbers?

### 7. Cost of Doing Nothing
- phase1.md says "This is REQUIRED, not optional"
- **Question**: Does validator.js enforce this as required? What's the penalty for missing it?

### 8. ROI Sanity Check
- phase1.md says "Don't spend $100k to save $10k"
- **Question**: Does validator.js perform any ROI calculation or comparison?

### 9. Alternatives Considered
- phase1.md requires "Why this solution over doing nothing or Solution B?"
- **Question**: Does validator.js check for alternatives discussion?

### 10. Investment Section
- phase1.md requires "The Investment" section with "Effort + Cost"
- **Question**: Does validator.js check for investment/resource information?

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


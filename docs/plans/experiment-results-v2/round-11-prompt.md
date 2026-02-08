# Round 11 Adversarial Prompt: pr-faq-assistant

## Context
You are performing an adversarial alignment review of a PR-FAQ document assistant. The system has three components that MUST be aligned:

1. **phase1.md** (203 lines) - User-facing instructions defining what makes a good PR-FAQ
2. **prompts.js** (347 lines) - LLM scoring rubric sent to AI evaluators
3. **validator.js** (1427 lines) - JavaScript pattern-matching scoring logic

## Your Mission
Find misalignments where:
- phase1.md requires something that validator.js doesn't check
- validator.js awards points for patterns that don't match phase1.md's intent
- prompts.js describes criteria that validator.js implements differently
- Regex patterns can be gamed with keyword stuffing
- Point allocations differ between prompts.js and validator.js

## Specific Areas to Investigate

### 1. Headline Scoring (8 pts in phase1.md)
- phase1.md requires: action verb + 8-15 words + mechanism + metric
- Check if validator.js enforces ALL four components
- Check if mechanism detection can be gamed ("using X" without real mechanism)

### 2. Quote Requirements (10 pts)
- phase1.md requires EXACTLY 2 quotes: 1 Executive Vision + 1 Customer Relief
- Check if validator.js enforces quote count AND quote types
- Check if quotes with banned words ("excited", "thrilled") are penalized

### 3. FAQ Hard Questions (15 pts)
- phase1.md MANDATES: Risk, Reversibility, Opportunity Cost questions
- Check if validator.js detects "softball" questions that mention keywords but dismiss concerns
- Check if "Is there a risk this is too successful?" would score points

### 4. Banned Words Enforcement
- phase1.md lists specific banned words: revolutionary, groundbreaking, excited, pleased, etc.
- Check if validator.js penalizes ALL banned words
- Check if penalty is per-occurrence or capped

### 5. Price & Availability (4 pts)
- phase1.md requires: specific launch date (2 pts) + pricing/availability (2 pts)
- Check if validator.js checks for BOTH components separately

### 6. Mechanism Clarity (5 pts)
- phase1.md requires explaining HOW it works, not just WHAT
- Check if validator.js can distinguish "uses AI" from "analyzes 50+ data points in 200ms"

### 7. Competitive Differentiation (5 pts)
- phase1.md requires: current alternative (3 pts) + why insufficient (2 pts)
- Check if validator.js enforces BOTH components

### 8. Score Scaling
- Check if raw scores are scaled correctly to final dimension scores
- Check if scaling introduces rounding errors that affect totals

## Source Files

### phase1.md (203 lines)
```markdown
[PASTE FULL CONTENT OF genesis-tools/pr-faq-assistant/shared/prompts/phase1.md]
```

### prompts.js (347 lines)
```javascript
[PASTE FULL CONTENT OF genesis-tools/pr-faq-assistant/validator/js/prompts.js]
```

### validator.js (1427 lines)
```javascript
[PASTE FULL CONTENT OF genesis-tools/pr-faq-assistant/validator/js/validator.js]
```

## Output Format

For each finding:
1. **Category**: Missing Check / Semantic Gap / Point Misalignment / Gaming Vulnerability
2. **Severity**: CRITICAL / HIGH / MEDIUM / LOW
3. **Evidence**: Specific line numbers and code snippets
4. **Verdict**: TRUE bug or FALSE positive

Focus on findings that would allow a user to score high while violating the spirit of phase1.md requirements.


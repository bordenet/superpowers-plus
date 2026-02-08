# Round 10: Adversarial Alignment Review - Product Requirements Assistant

## Your Mission

You are a hostile adversary trying to BREAK the Product Requirements Assistant. Your goal is to find misalignments between:

1. **phase1.md** (393 lines) - User-facing instructions for generating PRDs
2. **prompts.js** (200 lines) - LLM scoring rubric for AI evaluators  
3. **validator.js** (1286 lines) - JavaScript pattern-matching scoring logic

## Attack Vectors

### A. Missing Enforcement Gaps
Find rules in phase1.md that validator.js doesn't actually check:
- Banned vague language (lines 29-38): improve, enhance, user-friendly, efficient, scalable, better, optimize, faster, easier
- Forbidden implementation details (lines 47-54): microservices, OAuth, PostgreSQL, React, ML model, AWS Lambda, REST API, Redis
- Required 14 sections (lines 370-388): Executive Summary through Dissenting Opinions
- Customer FAQ BEFORE Proposed Solution (line 156)
- Alternatives Considered for every major feature (line 176)
- Door Type tagging (lines 217-221): One-Way vs Two-Way
- Acceptance Criteria for BOTH success AND failure cases (line 218)
- Leading Indicator per major goal (line 136)
- Counter-Metric for each metric (line 130)
- Traceability Summary mapping (lines 269-278)

### B. Scoring Misalignments
Compare point allocations between prompts.js and validator.js:
- prompts.js: Structure 20, Clarity 25, User Focus 20, Technical 15, Strategic 20
- validator.js: Check if maxScore values match
- Check if sub-allocations match (e.g., "Core Sections 10 pts" in prompts.js)

### C. Gaming Opportunities
Find ways to score high without following the spirit of phase1.md:
- Can you pass "Customer FAQ" check without actual customer questions?
- Can you pass "Alternatives Considered" without real trade-off analysis?
- Can you pass "Door Type" check with just emoji without context?
- Can you pass "Leading Indicator" check with just the phrase?
- Can you pass "Traceability" check without actual mapping?

### D. Regex Weaknesses
Examine validator.js regex patterns for:
- Case sensitivity issues
- Word boundary problems
- Patterns that match unintended text
- Patterns that miss valid formats

### E. Slop Detection Gaps
Compare banned terms in phase1.md vs slop-detection.js:
- Are all banned vague terms detected?
- Is the penalty proportional to severity?
- Can you use synonyms to bypass detection?

## Key Code Locations

### phase1.md
- Lines 29-38: Banned vague language table
- Lines 47-54: Forbidden implementation details
- Lines 119-136: Success Metrics with Leading/Lagging indicators
- Lines 138-145: Hypothesis Kill Switch
- Lines 154-166: Customer FAQ (Working Backwards)
- Lines 174-187: Alternatives Considered
- Lines 209-228: Functional Requirements with Door Type and AC
- Lines 269-278: Traceability Summary

### prompts.js
- Lines 17-44: 5-dimension scoring rubric with sub-allocations
- Lines 46-62: Calibration guidance (harsh scoring, 40-60 typical)

### validator.js
- Lines 20-38: REQUIRED_SECTIONS with weights
- Lines 42-78: VAGUE_LANGUAGE categories
- Lines 81-89: PRIORITIZATION_PATTERNS
- Lines 93-99: CUSTOMER_EVIDENCE_PATTERNS
- Lines 131-156: STRATEGIC_VIABILITY_PATTERNS
- Lines 575-691: scoreRequirementsClarity()
- Lines 791-918: scoreUserFocus()
- Lines 976-1048: scoreTechnicalQuality()
- Lines 1060-1211: scoreStrategicViability()

## Output Format

For each finding:
- **Finding ID**: A, B, C, etc.
- **Category**: Missing Check, Scoring, Gaming, Regex, Slop
- **Severity**: CRITICAL, HIGH, MEDIUM, LOW
- **Evidence**: Specific line numbers from each file
- **Attack**: How to exploit this misalignment
- **Verdict**: TRUE (confirmed bug) or FALSE (not exploitable)


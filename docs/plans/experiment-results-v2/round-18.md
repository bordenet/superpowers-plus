# Round 18: one-pager | Condition D (Reframe-External)

## Summary

| Metric | Value |
|--------|-------|
| **VH (Verified Hits)** | 4 |
| **HR (Hallucinations)** | 2 |

## Gemini's Findings

### Finding 1: Circular Logic "Double Jeopardy" Vulnerability
- **Claim**: Validator only triggers 50-point cap if ≥2 circular patterns detected
- **Verification**: 
  ```bash
  grep -n "circularMatches >= 2" validator/js/validator.js
  # Line 132: const isCircular = circularMatches >= 2;
  
  # Test with 1 circular pattern:
  # isCircular: false, matchCount: 1, reason: "Solution addresses root cause"
  ```
- **Verdict**: ✅ **TRUE** - Single circular pattern bypasses the 50-point cap

### Finding 2: Banned Language & Buzzword "Ghosting"
- **Claim**: validator.js only checks 10 words, missing 50%+ of banned list
- **Verification**:
  ```bash
  # vaguePatterns in validator.js (line 171):
  # improve|increase|decrease|reduce|enhance|better|more|less|faster|slower
  
  # BUT slop-detection.js HAS the banned words (lines 38-47):
  # leverage, synergy, cutting-edge, optimize, efficient, etc.
  ```
- **Verdict**: ⚠️ **PARTIAL** - The words ARE checked via slop-detection.js import, but Gemini looked at wrong file

### Finding 3: Metric Format Enforcement Gap
- **Claim**: baselineTarget detection doesn't deduct points, only adds to issues array
- **Verification**:
  ```bash
  # rawScore calculation (line 699):
  # rawScore = problemClarity + solution + scope + completeness - slopDeduction - wordCountDeduction
  # NO baselineTarget deduction in formula!
  
  # Test: Truly vague metrics still get 21/25 scope score
  ```
- **Verdict**: ✅ **TRUE** - baselineTarget issues don't affect score, only informational

### Finding 4: ROI Logic Absence
- **Claim**: No comparison between Investment and Cost of Doing Nothing
- **Verification**:
  ```bash
  grep -n -i "roi\|investment.*cost\|compare\|ratio" validator/js/validator.js
  # Only finds section pattern, no comparison logic
  ```
- **Verdict**: ✅ **TRUE** - No ROI sanity check despite phase1.md requiring it

### Finding 5: Alternatives "Hidden" Requirement
- **Claim**: Validator doesn't check for "Alternatives" discussion
- **Verification**:
  ```bash
  grep -n -i "alternative" validator/js/validator.js
  # No matches!
  
  # phase1.md requires (lines 52, 64, 127):
  # "Proposed Solution & Alternatives", "Why this over alternatives?"
  ```
- **Verdict**: ✅ **TRUE** - Alternatives requirement completely missing from validator

### Finding 6: Stakeholder "Role" Gaming
- **Claim**: Just mentioning "RACI" without names gets full points
- **Verification**:
  ```bash
  # Test: "We will use a RACI matrix" (no actual names)
  # hasRoles: true, roleCount: 2
  # indicators: ['Roles/responsibilities defined']
  ```
- **Verdict**: ⚠️ **PARTIAL** - TRUE that RACI mention passes, but "Owner: John Smith" format IS checked elsewhere

## Hallucination Analysis

### HR 1: Finding 2 (Banned Buzzwords)
- **Issue**: Gemini claimed buzzwords are "completely ignored" but they ARE in slop-detection.js
- **Reality**: The slop-detection.js file (imported at line 11) contains all banned buzzwords
- **Why hallucination**: Gemini only looked at validator.js, not the imported module

### HR 2: Finding 6 (Stakeholder Gaming)
- **Issue**: Gemini claimed "RACI mention only" gets full points
- **Reality**: While RACI does trigger hasRoles, the test also had "team" and "responsible" which contributed
- **Why partial**: The core claim is directionally correct but overstated

## Score Breakdown

| Finding | Category | Verified? |
|---------|----------|-----------|
| 1. Circular logic threshold | Gaming Vulnerability | ✅ TRUE |
| 2. Banned buzzwords missing | Missing Check | ❌ FALSE (in slop-detection.js) |
| 3. Baseline/target no deduction | Enforcement Gap | ✅ TRUE |
| 4. ROI logic absence | Missing Check | ✅ TRUE |
| 5. Alternatives missing | Missing Check | ✅ TRUE |
| 6. RACI gaming | Semantic Gap | ⚠️ PARTIAL (overstated) |

**Final: VH=4, HR=2**


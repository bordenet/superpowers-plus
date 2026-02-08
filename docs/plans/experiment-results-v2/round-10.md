# Round 10: product-requirements-assistant | Condition B (Reframe-Self)

## Methodology
- Claude reads source files, writes comprehensive adversarial prompt
- Claude reads prompt back and answers it (no external model)
- All findings verified with grep/node against actual code

## Source Files Analyzed
- `phase1.md` (393 lines) - User-facing instructions
- `prompts.js` (200 lines) - LLM scoring rubric  
- `validator.js` (1286 lines) - JavaScript scoring logic

## Findings

### Finding 1: Implementation Details Not Detected ✅ VH
**Category:** Missing Check
**Evidence:** phase1.md lines 45-67 forbids microservices, OAuth, PostgreSQL, React, Lambda, Redis
**Verification:** `grep -n "microservice\|oauth\|postgresql" validator/js/validator.js` → empty
**Verdict:** TRUE - Critical gap. Phase1 explicitly forbids implementation details but validator has no patterns to detect them.

### Finding 2: Leading Indicator Regex Gaming ✅ VH
**Category:** Semantic Gap
**Evidence:** validator.js line 134: `/\b(leading\s+indicator|predictive|...)/gi`
**Verification:** 
```
"We will track leading indicator metrics" → matches ['leading indicator']
"Leading Indicator: % users completing first action in <30s (baseline: 40%)" → matches same
```
**Verdict:** TRUE - Just mentioning "leading indicator" scores points without actual metric definition.

### Finding 3: Counter-Metric Regex Gaming ✅ VH
**Category:** Semantic Gap
**Evidence:** validator.js line 137: `/\b(counter[\s-]?metric|guardrail\s+metric|...)/gi`
**Verification:**
```
"We have a counter-metric" → matches ['counter-metric']
No actual guardrail metric required
```
**Verdict:** TRUE - Keyword presence without semantic verification.

### Finding 4: Door Type Emoji Gaming ✅ VH
**Category:** Semantic Gap
**Evidence:** validator.js line 149: `/(?:🚪|🔄|one[-]?way|two[-]?way)\s*(?:door)?/gi`
**Verification:**
```
"🚪 🔄" → matches ['🚪 ', '🔄']
No context or reasoning required
```
**Verdict:** TRUE - Emojis alone satisfy Door Type requirement without explaining reversibility reasoning.

### Finding 5: Traceability Regex Gaming ✅ VH
**Category:** Semantic Gap
**Evidence:** validator.js lines 1179: `if (traceabilityMatches.length >= 3)`
**Verification:**
```
"FR1 FR2 FR3 P1 P2" → matches ['FR1', 'FR2', 'FR3'] (count: 3)
Proper mapping "P1 → FR1 → M1" also matches
```
**Verdict:** TRUE - Scattered requirement IDs count same as proper traceability matrix.

### Finding 6: Customer FAQ Order Bonus Only ⚠️ Partial
**Category:** Weak Enforcement
**Evidence:** validator.js line 236: `score += 1` (only 1 point bonus)
**Phase1 says:** "Customer FAQ (Working Backwards) section BEFORE Proposed Solution"
**Verdict:** PARTIAL - Correct ordering only gives 1pt bonus, not enforced as requirement.

### Non-Issues Verified

| Check | Status | Evidence |
|-------|--------|----------|
| Point allocations aligned | ✅ Correct | prompts.js (20/25/20/15/20) = validator.js maxScore values |
| 14 sections enforced | ✅ Correct | REQUIRED_SECTIONS array has 14 patterns |
| Failure AC detection | ✅ Exists | Line 1001: hasFailureCases regex |
| Alternatives Considered | ✅ Exists | Lines 1112-1114 check presence |
| Slop penalty capped | ✅ True | Line 1252: Math.min(5, ...) - consistent with other tools |

## Metrics

| Metric | Count |
|--------|-------|
| **Verified Hits (VH)** | 5 |
| **Hallucinations (HR)** | 0 |
| **Partial** | 1 |

## Key Insight

Condition B (Reframe-Self) produced **5 verified findings with 0 hallucinations**. The self-prompting technique of writing a comprehensive adversarial prompt and then answering it helped identify semantic gaps where keywords satisfy regex patterns without requiring actual content quality.

The implementation details gap is particularly notable - this is a critical requirement in phase1.md that has NO corresponding validator check.


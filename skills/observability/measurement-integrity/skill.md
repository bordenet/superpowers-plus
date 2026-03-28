---
name: measurement-integrity
source: superpowers-plus
triggers:
  - "coverage is"
  - "accuracy is"
  - "percent"
  - "out of"
  - "pass rate"
  - "score is"
anti_triggers:
  - "code coverage tool"
  - "test coverage command"
  - "coverage report"
description: >
  HARD GATE — Forces cross-validation, completeness verification, and
  confidence qualification before reporting ANY metric or percentage.
summary: "Use when: reporting any metric. Skip when: quoting tool output verbatim."
coordination:
  group: quality-feedback
  order: 2
  requires: []
  enables: [verification-before-completion]
  escalates_to: [failure-autopsy]
  internal: false
---

# Measurement Integrity

> **Wrong skill?** Verifying work -> verification-before-completion. Completeness audit -> exhaustive-audit-validation.

**Announce at start:** "I am using the **measurement-integrity** skill to validate this metric."

## When to Use

- Before reporting any percentage (coverage, accuracy, pass rate)
- Before claiming a count ("65 out of 65 skills")
- Before comparing metrics across time
- Before declaring a ceiling based on measurement

## Scope Exclusions

- Quoting verbatim tool output -> quote directly
- Qualitative observations -> not a metric
- Someone else published metric -> cite the source

---

## Measurement Checklist

### 1. Completeness

Verify universe before reporting percentages.
Example: total=       0
WRONG: "65/65" without verifying 65 is correct.

### 2. Cross-Validation (minimum 2 methods)

- Method 1: [description] -> Result: [X]
- Method 2: [description] -> Result: [Y]
- Single-method? Disclose: "Single-method measurement."

### 3. Methodology Disclosure

Report: **Metric** + **Method** + **Universe** + **Confidence** + **Caveat**

### 4. Temporal Consistency

Same methodology? Same universe? Same test suite?

---

## Anti-Patterns

| Anti-Pattern | Example | Fix |
|--------------|---------|-----|
| % without universe | "95% coverage" | "95% (62/65 skills)" |
| Changed methodology | 14/14 -> 14/17 | Disclose: "expanded suite" |
| Ceiling from one test | "Cannot do better" | Try 3 fixes first |
| Precision theater | "93.846%" | Round: "94%" |

## Failure Modes

| Failure | Detection | Recovery |
|---------|-----------|----------|
| No cross-validation | Missing Method 2 | Add second method |
| Universe changed | Total differs | Acknowledge + rebaseline |
| False precision | Excess decimals | Round to significant digits |
| Stops investigation | "ceiling" claim | Try 2 more approaches |

## Companion Skills

- **failure-autopsy**: When a metric turns out wrong
- **verification-before-completion**: Verifying claims
- **exhaustive-audit-validation**: Deep completeness audit
- **quantitative-decision-gate**: Using metrics for decisions

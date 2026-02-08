# Adversarial Alignment Review: business-justification-assistant

## Task

You are a senior security researcher performing an adversarial alignment review. Your goal is to find **misalignments** between:

1. **phase1.md** - The user-facing LLM instructions (what the document SHOULD contain)
2. **prompts.js** - The LLM scoring rubric (what the LLM is told to score)
3. **validator.js** - The JavaScript scoring logic (what actually gets scored)

## What to Look For

### Category 1: Point Misalignment
- Requirements in phase1.md that aren't scored in validator.js
- Scoring in validator.js that doesn't match phase1.md weights
- Discrepancies between prompts.js rubric and validator.js implementation

### Category 2: Gaming Vulnerabilities
- Ways to score high without meeting the spirit of requirements
- Keyword stuffing that triggers detection without substance
- Regex patterns that can be gamed with specific phrases

### Category 3: Missing Checks
- Requirements in phase1.md with no corresponding validator check
- Banned phrases/patterns not enforced in validator.js
- Semantic requirements that regex can't capture

### Category 4: Semantic Gaps
- Validator checks that don't match the semantic intent
- False positives (penalizing good content)
- False negatives (missing bad content)

## Source Files

### phase1.md (167 lines) - Key Requirements

**AI Slop Prevention (Lines 22-90):**
- Banned vague terms: improve, enhance, optimize, user-friendly, efficient, scalable, better/faster/easier, significant/substantial, seamless/robust/comprehensive
- Banned filler phrases: "It's important to note that...", "In today's fast-paced world...", "Let's dive in...", "First and foremost...", "Needless to say..."
- Banned buzzwords: leverage, utilize, synergy, holistic, paradigm, disruptive/transformative, cutting-edge, game-changing, best-in-class
- Banned hedge patterns: "It depends...", "In some cases...", "Generally speaking...", "Could potentially...", "Arguably..."

**Specificity Requirements (Lines 81-90):**
- Baselines + Targets: "reduce from 5 hours/week to 30 minutes/week"
- Quantified outcomes: "increase NPS from 42 to 48"
- Measurable criteria: "process 100K transactions/day with <100ms p95"
- Named integrations: "Epic FHIR API", "Stripe Payment Intents"

**Document Structure (Lines 94-124):**
- 11 required sections with specific subsections
- Executive Summary readable in 30 seconds
- Options Analysis with 3 options (do-nothing, minimal, full)
- ROI calculation with explicit formula
- Payback period target: <12 months
- 3-year TCO including hidden costs

**Self-Check Scoring (Lines 127-150):**
- Strategic Evidence: 30 pts (80/20 quant/qual ratio, sources cited)
- Financial Justification: 25 pts (ROI formula, payback <12 months, 3-year TCO)
- Options & Alternatives: 25 pts (3 options, do-nothing quantified, clear recommendation)
- Execution Completeness: 20 pts (30-second summary, stakeholder concerns, risks)

### prompts.js (187 lines) - LLM Rubric

**Scoring Rubric (Lines 23-42):**
- Strategic Evidence (30 pts): Quantitative data (12), Credible sources (10), Before/After (8)
- Financial Justification (25 pts): ROI calculation (10), Payback period (8), TCO analysis (7)
- Options & Alternatives (25 pts): Multiple options (10), Do-nothing (10), Recommendation (5)
- Execution Completeness (20 pts): Executive summary (6), Risks (7), Stakeholder concerns (7)

**Calibration Guidance (Lines 44-52):**
- "Be HARSH. Most business justifications score 40-60."
- "Deduct points for EVERY claim without quantified evidence"
- "Deduct points for sunk cost reasoning"

### validator.js (766 lines) - Actual Scoring Logic

**Pattern Definitions (Lines 25-122):**
- EVIDENCE_PATTERNS: problemSection, quantified, sources, beforeAfter
- FINANCIAL_PATTERNS: roiCalculation, roiFormula, paybackPeriod, tcoAnalysis
- OPTIONS_PATTERNS: doNothing, alternatives, recommendation, minimalInvestment, fullInvestment
- EXECUTION_PATTERNS: executiveSummary, risksSection, stakeholderConcerns

**Scoring Functions (Lines 470-667):**
- scoreStrategicEvidence(): 12 pts for quantified problem, 10 pts for sources, 8 pts for before/after
- scoreFinancialJustification(): 10 pts for ROI formula, 8 pts for payback time, 7 pts for TCO
- scoreOptionsAnalysis(): 10 pts for do-nothing, 10 pts for alternatives, 5 pts for recommendation
- scoreExecutionCompleteness(): 6 pts for exec summary, 7 pts for risks, 7 pts for stakeholders

**Slop Detection (Lines 724-734):**
- slopDeduction = Math.min(5, Math.floor(slopPenalty.penalty * 0.6))
- Max 5 point deduction regardless of slop density

## Your Analysis

For each finding, provide:
1. **Category**: Point Misalignment / Gaming Vulnerability / Missing Check / Semantic Gap
2. **Severity**: CRITICAL / HIGH / MEDIUM / LOW
3. **Evidence**: Specific line numbers and code
4. **Verdict**: TRUE bug or FALSE positive
5. **Description**: What the misalignment is and why it matters

Focus on findings that could allow a document to score high while violating the spirit of the requirements.


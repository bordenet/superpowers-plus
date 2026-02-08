# Adversarial Alignment Review: product-requirements-assistant

## Task

You are a senior security researcher performing an adversarial alignment review. Your goal is to find **misalignments** between:

1. **phase1.md** (418 lines) - The user-facing LLM instructions (what the document SHOULD contain)
2. **prompts.js** (237 lines) - The LLM scoring rubric (what the LLM is told to score)
3. **validator.js** (1286 lines) - The JavaScript scoring logic (what actually gets scored)

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

## Key Requirements from phase1.md

**Banned Vague Language (Lines 27-38):**
- improve, enhance, user-friendly, efficient, scalable, better, optimize, faster, easier
- Must be replaced with specific quantification

**Forbidden Implementation Details (Lines 47-54):**
- "Use microservices architecture", "Implement OAuth 2.0", "Store data in PostgreSQL"
- "Build a React dashboard", "Use machine learning model", "Deploy to AWS Lambda"

**14 Required Sections (Lines 395-413):**
- Executive Summary, Problem Statement, Value Proposition, Goals, Customer FAQ
- Proposed Solution, Scope, Requirements, Stakeholders, Timeline, Risks
- Traceability Summary, Open Questions, Known Unknowns & Dissenting Opinions

**Success Metrics Requirements (Lines 119-136):**
- Leading Indicator vs Lagging Indicator type
- Baseline + Target + Timeline
- Source of Truth (specific system)
- Counter-Metric (what must NOT degrade)
- At least one Leading Indicator per major goal

**Functional Requirements Format (Lines 217-234):**
- ID: FR1, FR2, etc.
- Problem Link: Which Problem ID (P1, P2) this addresses
- Door Type: 🚪 One-Way or 🔄 Two-Way
- Acceptance Criteria: Given/When/Then for BOTH success AND failure cases

**Hypothesis Kill Switch (Lines 138-152):**
- Kill Criteria: Specific data that would prove we should stop
- Decision Point: When we evaluate
- Rollback Plan: How we reverse if needed

**Alternatives Considered (Lines 180-194):**
- For every major feature, list at least one rejected approach
- Include: Alternative, Rejected Because, Trade-off

## Key Scoring from prompts.js

**5-Dimension Rubric (Lines 17-44):**
1. Document Structure (20 pts): Core sections, organization, formatting, scope boundaries
2. Requirements Clarity (25 pts): Precision, completeness, measurability, prioritization
3. User Focus (20 pts): Personas, problem statement, alignment, customer evidence
4. Technical Quality (15 pts): NFRs, acceptance criteria, dependencies
5. Strategic Viability (20 pts): Metric validity, scope realism, risk quality, traceability

**Calibration Guidance (Lines 46-62):**
- "Be HARSH. Most PRDs score 40-60."
- "Deduct points for EVERY vague qualifier without metrics"
- "Deduct points for all requirements tagged 'P0' (no real prioritization)"
- "Deduct points for metrics without Source of Truth"
- "Reward One-Way/Two-Way Door tagging"

## Your Analysis

For each finding, provide:
1. **Category**: Point Misalignment / Gaming Vulnerability / Missing Check / Semantic Gap
2. **Severity**: CRITICAL / HIGH / MEDIUM / LOW
3. **Evidence**: Specific line numbers and code
4. **Verdict**: TRUE bug or FALSE positive
5. **Description**: What the misalignment is and why it matters

Focus on findings that could allow a document to score high while violating the spirit of the requirements.


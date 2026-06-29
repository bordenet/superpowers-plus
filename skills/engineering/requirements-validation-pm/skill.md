---
name: requirements-validation-pm
source: superpowers-plus
augment_menu: true
triggers: ["/sp-requirements-validation-pm", "validate product requirements", "PM requirements review", "validate user stories", "check stakeholder needs", "validate market fit", "are these PRDs valid", "contradictory product requirements", "stakeholder alignment check"]
anti_triggers: ["engineer implementation detail", "technical root cause", "implement requirements", "build this feature", "write code for", "acceptance criteria for engineers"]
description: Validate product / PM requirements before design or roadmap commitment — customer-grounded, stakeholder-owned, business-measurable. USE INSTEAD OF requirements-validation when author is a PM.
summary: "Use when: validating product requirements before design or roadmap commitment. Skip when: requirements are already customer-validated and stakeholder-owned."
coordination:
  group: engineering
  order: 1
  requires: []
  enables: ["debate", "brainstorming", "plan-and-execute"]
  escalates_to: []
  internal: false
composition:
  consumes: [customer-evidence, stakeholder-intent, product-goal]
  produces: [validation-report]
  capabilities: [validates-requirements, detects-customer-evidence-gaps, surfaces-stakeholder-conflicts]
  priority: 10
  optional: false
  requires_all: false
---

# Requirements Validation (PM)

> **Core principle:** Every product requirement must be customer-grounded, stakeholder-owned, and business-measurable. Contradictions between stakeholders must be surfaced for decision, not silently resolved by the PM or the AI.
> **Inversion rule:** The PM lens validates WHY (customer need, business rationale) and WHAT (user-visible outcome). It does NOT validate HOW (technical feasibility, implementation contracts, code-level acceptance criteria) — that's the engineer counterpart's job.
>
> **Wrong skill?**
> - Engineer / technical acceptance-criteria validation -> `requirements-validation` (engineer-side)
> - Feature design from validated requirements -> `debate` or `brainstorming`
> - Implementation planning -> `plan-and-execute`
> - Validating shipped output against requirements -> `output-verification`

**Announce at start:** "I'm using the **requirements-validation-pm** skill to validate these product requirements."

## When to Use

- Before product design — validate that requirements have real customer evidence and clear stakeholder owners
- When a stakeholder ask is vague, compound, or conflicts with another stakeholder
- When user stories from customer interviews need to be converted into trackable product requirements
- Before committing scope on a roadmap, OKR, or quarterly plan

## Input Contract

Before running the three tests, normalize requirements into a numbered list with persona framing:

- **Format:** `R1: As a [persona], I [need/want] [outcome] so that [value].`, `R2: ...`, etc.
- If the input is prose, extract discrete requirements and number them as user stories.
- If the input is already numbered, preserve the numbering.
- Each `R#` must be a single, atomic requirement (split compound requirements).
- Each `R#` must name the affected persona. If no persona is named, that is itself a failure — flag and request.

## Non-Functional Requirements

NFRs (performance, security, compliance, reliability) and regulatory mandates do not fit the standard user-story format cleanly. Frame them as:

`"As a [affected role: user / regulator / ops team / auditor], the system must [behavior] so that [risk/obligation]."`

The persona may be internal. If no persona can be named, that is itself a Customer-Grounded Test failure. Apply all three tests after framing.

**Note on regulatory mandates:** "the regulator" is a valid persona for compliance requirements. The Customer-Grounded signal is the regulation itself (cite the specific rule or code). Regulatory requirements typically pass the Customer-Grounded Test by citation alone; they still require a named internal decision owner and a compliance metric.

## The Three Tests (PM Lens)

For EACH numbered requirement, apply all three:

### 1. Customer-Grounded Test

**Question:** Can you cite a real customer signal (call recording, support ticket, customer interview, analytics datum) that motivates this requirement?

| Result | Action |
|--------|--------|
| Yes — concrete customer signal exists | Requirement passes |
| No — speculative or "I think customers want" | Reject. Require evidence: recording with timestamp, support ticket IDs, or interview notes URL. |
| No — but this is a new product or feature with no existing customers | Conditional pass — require instead: a named proxy (design partner, sales prospect, beta tester) AND a plan to validate the assumption within a defined timeframe before full release |
| Internal-stakeholder ask only ("sales said") | Blocking ask — sales aggregation is not a customer signal. Request the specific recording, ticket, or interview the sales signal reflects. If none can be cited within the session, mark FAIL. |

**Conditional pass — documenting the state:**

In the validation report, record Conditional-pass requirements separately from Passed requirements. For each conditional pass:
- State the condition that remains unfulfilled
- Name the evidence needed (specific signal, named proxy, planned interview)
- Note the deadline or stage by which the condition must be resolved (e.g., before launch, before Q2 planning)
- **File a tracking ticket** (Linear issue, GitHub issue, Jira ticket, TODO entry with id, or equivalent — whatever the team's canonical tracker is) capturing the condition and deadline before the report is considered complete. If no ticket system is accessible in this session, record the condition in the report with an explicit note: `TRACKER PENDING: create a ticket for this condition before this report is acted on.` A conditional pass with no tracker and no pending note is not valid.

A conditional pass resolves to PASS or FAIL when the condition deadline fires. It does not silently become PASS.

**Evidence-strength hierarchy (Customer-Grounded Test):** When multiple evidence types are available, weight them:
1. Direct customer quote in a recorded interview (strongest)
2. Support ticket with the customer's own words
3. Analytics datum corroborated by qualitative signal
4. Analytics datum alone (weakest — reflects behavior, not need; subject to survivorship bias)
5. Named design partner / beta tester proxy (acceptable for greenfield, conditional only)

A requirement citing only analytics without any qualitative corroboration should be Conditional, not Pass.

**Also check:** Is the requirement stated as a solution rather than a need? "Use a calendar widget" is not a requirement — it is an implementation choice. Restate as: "The user can see all upcoming appointments at a glance." Requirements that prescribe solutions bypass validation because they conflate WHAT with HOW. Reject solution-phrased requirements and require reformulation before proceeding.

**Banned phrases that signal a failed Customer-Grounded Test:**

- "Customers probably want..."
- "It would be nice to..."
- "Industry best practice suggests..." (without a direct customer link)
- "Competitor X does this" (competitive parity is not customer evidence)

### 2. Stakeholder-Ownership Test

**Question:** Is there a named, real decision owner who can resolve scope, priority, and trade-off questions for this requirement?

| Result | Action |
|--------|--------|
| Named individual (real person, with their role) | Passes |
| Role-only ("the PM team", "leadership") | Conditional pass — require a named individual within that role |
| Unnamed or "TBD" | Reject. Decision owner must exist before scope is committed. Write `PENDING (ask user for named owner)` and STOP. |

**Never invent a decision owner.** If no stakeholder has weighed in, the owner is PENDING. Do not fabricate a name or role to unblock yourself.

### 3. Business-Measurability Test

**Question:** Is there a defined business signal that will move if this requirement is met — and a baseline to compare against?

| Result | Action |
|--------|--------|
| Named metric + baseline + target | Passes |
| Named metric, no baseline or target | Conditional — require (a) the baseline (must be cited from a specific data source with a timestamp, not an estimate) OR (b) a written commitment to instrument before launch with a named DRI. Unverifiable baselines ("approximately X") do not qualify. |
| Vague benefit ("improve experience", "delight users") | Reject. Add a measurable signal: adoption %, retention, CSAT score, support-ticket volume, time-to-value. |
| Metric does not yet exist | Acceptable, but parallel issue MUST be filed to instrument it before launch |

## Step 4: Completeness Check (cross-requirement)

After running the three tests per requirement, apply this cross-requirement pass:

1. **Journey coverage:** Name the primary user journeys for the target persona(s). Does each journey have at least one requirement addressing it? List any journeys that are unaddressed — each is a candidate for a new requirement or an explicit out-of-scope decision.

2. **Contradiction scan:** Compare each validated requirement against all others for: explicit logical conflicts (R3 requires X, R7 requires NOT X), implicit conflicts (R1 requires real-time, R2 requires offline-first), and shared-resource contention (two requirements that fight over the same resource or constraint). Also flag **conflicting customer signals**: when two customers want opposite behaviors, that is not automatically a contradiction in the requirements — it may indicate a segmentation decision is needed (Option D in the Contradiction Resolution options). Document all contradictions and segments found and route to Contradiction Resolution below.

3. **All-conditional-pass check:** If all requirements are conditional passes, the requirement set is **NOT ready for roadmap commitment**. Return to the PM with a summary of open conditions and a proposed resolution timeline. If >50% of requirements are conditional passes, escalate even if not all-conditional: raise the proportion explicitly so stakeholders can weigh the risk before committing.

## Contradiction Resolution

**HARD GATE:** Do NOT resolve contradictions silently. The stakeholder decides. This gate stops the current pass, not the entire session — a partial report with open contradictions is acceptable as long as the contradictions are listed and routed explicitly. Do not deliver a final report that omits the contradiction section.

When two requirements conflict — typically because two stakeholders want incompatible outcomes:

1. **State both requirements verbatim.**
2. **State the contradiction explicitly:** "R3 (owner: [name]) requires X for [persona A], but R7 (owner: [name]) requires Y for [persona B]. These cannot both be true because [reason]."
3. **Propose resolution options:**
   - Option A: Prioritize R3 (drop R7 or modify it)
   - Option B: Prioritize R7 (drop R3 or modify it)
   - Option C: Split into phases (R3 in v1, R7 in v2)
   - Option D: Segment by persona (R3 for persona A, R7 for persona B in the same release)
   - Option E: Escalate to a joint decision with both stakeholder owners present. **ESCALATION HOLD applies:** Option E does not close the contradiction — it schedules a resolution meeting. Mark the contradiction as `HELD: [meeting scheduled by/with whom, by when]`. Do not ship the requirement set to design or planning until the hold resolves. Record "scheduled intent" is not the same as a decision.
4. **Record the decision:**
   - **Decision owner:** [name — must be a real person who provided the decision. If unknown, write `PENDING (ask user)` and STOP.]
   - **Chosen option:** A / B / C / D / E
   - **Rationale:** [1 sentence]
   - **Citation:** [link to written decision — wiki page, issue comment, email thread reference. If the decision was made verbally: `VERBAL: Meeting of [attendees], [date], [decision in one sentence]`.]
5. **Do NOT proceed until recorded.** Unresolved contradictions block roadmap commitment.

**Never invent a decision owner.** If no stakeholder has weighed in, the decision is PENDING. Do not fabricate a name or role to unblock yourself.

## Output Format

> **Storage:** Publish this report to the requirement set's canonical home (linked wiki page, issue description, PR description, or shared document). If no canonical home is accessible in this session, output the report to the user and add: `PUBLISH PENDING: paste or link this report to [your requirements system] before it is acted on.` A report that exists only in a chat session is not durable. Include a validation date — a report older than the last customer interview or a market event that changes the problem space should be re-validated before use. Trigger re-validation on: (a) new customer signals that contradict a passed requirement, (b) a product pivot, (c) >90 days elapsed since validation.

```markdown
## Product Requirements Validation Report
**Validation date:** [YYYY-MM-DD]
**Validated by:** [Name]
**Re-validate before use if:** new customer signals contradict a passed requirement, a product pivot occurs, or >90 days have elapsed.

### Normalized Requirements
- R1: As a [persona], I need [outcome] so that [value].
- R2: ...
*(If the input was prose, list the numbered user stories you extracted here so the user can confirm scope.)*

### Validation Verdict
- X requirements passed
- Y requirements failed (see below)
- Z conditional passes (see Conditions section)
- N requirements pending owner assignment
- P contradictions found

### Passed
- R1: Customer-Grounded ✓ (cite) | Stakeholder-Owned ✓ ([name]) | Business-Measurable ✓ ([metric + baseline])

### Failed (Needs Revision)
- R3: Customer-Grounded FAIL — no customer signal cited
  - Suggested revision: [specific, customer-cited version]
  - Evidence needed: [recording timestamp / ticket ID / interview notes URL]

### Conditional Passes
- R4: Customer-Grounded CONDITIONAL — greenfield product, no existing customers
  - Required: Named proxy ([name]), validation plan ([stage/deadline])

### Owner Pending
- R5: Stakeholder-Ownership PENDING
  - Question for user: Who is the decision owner for this requirement?

### Metrics Pending
- R6: Business-Measurability PARTIAL — metric named but no baseline
  - Required action: pull baseline from [your analytics platform], or file parallel instrumentation issue before launch

### Contradictions Found
- R7 vs R9: [description of conflict]
  - Resolution options: A / B / C / D / E
  - Decision owner: [name — or PENDING (ask user)]
  - Chosen option: [A/B/C/D/E — or PENDING]
  - Rationale: [1 sentence — or PENDING]
  - Citation: [link — or PENDING]
```

## Example

```bash
# Check requirements doc for banned speculative phrases (grep -E without quotes breaks on spaces; use -F or quote properly)
grep -inE "(customers probably|it would be nice|industry best practice|competitor .* does)" requirements.md \
  && echo "⚠ Speculative language found — Customer-Grounded Test will FAIL" \
  || echo "✅ No speculative phrases detected"

# Find requirements missing user-story persona framing (scan only R# lines with -E anchored pattern)
grep -nE "^R[0-9]+:" requirements.md | grep -iv "As a " \
  && echo "⚠ Missing 'As a [persona]...' framing" \
  || echo "✅ All R# lines include 'As a' framing"

# Spot vague benefit language (measurability candidates)
grep -inE "(improve|better|faster|easier|enhance|delight|experience)" requirements.md \
  && echo "⚠ Vague benefit language — requires measurable metric + baseline"
```

## Failure Modes

| Failure | Fix |
|---------|-----|
| Validated speculative requirements as customer-grounded | Apply Customer-Grounded Test: if you cannot cite a recording, ticket, or interview, it is not grounded |
| Accepted "leadership decided" without a named individual | Stakeholder-Ownership Test requires a real person; PENDING is the correct answer when unknown |
| Accepted vague benefits (delight, improve, enhance) as measurable | Business-Measurability Test requires a metric + baseline + target |
| Resolved stakeholder contradictions silently to avoid escalation | Hard gate: contradictions go to named decision owners with options, never resolved by the PM or AI alone |
| Used competitor behavior as the customer-evidence source | Competitive parity is not customer evidence; re-anchor on a direct customer signal |
| Skipped persona naming in user stories | Reject the input format; require `As a [persona], I [need] ... so that [value]` framing |
| Slipped HOW into the validation (technical feasibility, implementation contracts) | That's the engineer counterpart's job — route to `requirements-validation` (engineer-side) |
| Accepted "sales said" as a conditional pass | Sales aggregation is not a customer signal; it is a blocking ask — require the cited recording or ticket |
| Accepted analytics datum alone as customer-grounded (no qualitative corroboration) | Analytics reflects behavior, not need; require a qualitative signal or mark as Conditional |
| Accepted compound user stories ("I want X AND Y AND Z") | Split into atomic stories — each gets independent validation |
| Accepted solution-as-requirement ("use a calendar widget") | Restate as a user need: "User can see all upcoming appointments at a glance" |
| Conditional passes left without a filed tracking ticket | A conditional pass without a filed tracker is not valid — file before closing the report |
| Report lives only in a chat session | Publish to wiki, issue description, or PR before the session ends |
| All-conditional-pass set treated as roadmap-ready | If all requirements are conditional passes, return to PM for resolution timeline — not ready for commitment |

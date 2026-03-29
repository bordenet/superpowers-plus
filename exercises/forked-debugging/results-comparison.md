# Forked Debugging — Results Comparison & Recommendations

> **Status:** Pre-experiment (scenarios designed, harness built, experiments not yet run)
> **Branch:** `feat/forked-debugging-superpower`
> **Updated:** 2026-03-29

## Expected Results (Hypotheses to Test)

Based on the research foundation (Kim et al. 2025, AgentRx, TraceCoder) and our scenario designs:

### Predicted Outcomes by Scenario

| Scenario | A (Single) | B (Naive Multi) | C (Conductor) | Predicted Winner |
|----------|-----------|-----------------|---------------|-----------------|
| **S1:** Telephony sequencing | Moderate — will find deployment correlation | Fast hypotheses but likely duplicates | Targeted — timeline + state investigators converge | C (marginally) |
| **S2:** Timeout cascade | Slow — will follow cascade, may miss root config change | 3 agents independently investigate; 2 likely find cascade, 1 finds config | Conductor assigns infra investigator to config, timeline to cascade | C (clearly) |
| **S3:** LLM tool regression | Fast — systematic-debugging handles single-domain well | Overkill — 3 agents for a 1-domain problem | Should stay serial (fork rubric < 6) | A (by design) |
| **S4:** State desync | Slow — complex multi-hop causation | Moderate — may find replica lag but miss cache re-fill | State + timeline investigators cover both paths | C (clearly) |
| **S5:** Intermittent heisenbug | Likely stuck — incomplete evidence, multi-domain | High noise — agents diverge into separate dead ends | Best shot — systematic evidence collection + escalation | C (marginal, but may still fail) |

### Key Hypotheses

1. **H1:** Conductor-led (C) will reach validated root cause faster than single-agent (A) on S2 and S4 (complex multi-domain).
2. **H2:** Single-agent (A) will outperform both multi-agent modes on S3 (single-domain issue).
3. **H3:** Naive multi-agent (B) will produce the most duplicate work on all scenarios.
4. **H4:** Conductor-led (C) will have higher evidence quality (confidence × diversity) on S2, S4, S5.
5. **H5:** Cost for C will be 1.5–2.5× cost of A; cost for B will be 2.5–3×.
6. **H6:** S5 will be unsolvable by all modes given incomplete evidence (test the limits).

## Scoring Template (to fill after experiments)

### Per-Cell Results

| Metric | A-S1 | B-S1 | C-S1 | A-S2 | B-S2 | C-S2 | ... |
|--------|------|------|------|------|------|------|-----|
| Time to first hypothesis (s) | | | | | | | |
| Time to validated root cause (s) | | | | | | | |
| Wrong hypotheses pursued | | | | | | | |
| Evidence quality (0–1) | | | | | | | |
| Duplicate work (0–1) | | | | | | | |
| Operator readability (1–5) | | | | | | | |
| Token cost | | | | | | | |
| Actionable? (Y/N) | | | | | | | |

## Final Recommendation Framework

### When to Use Single-Agent Debugging (A)

Use when:
- Single domain, clear error message
- Fork-readiness rubric score < 6
- Budget is constrained
- Issue is familiar pattern (known playbook)
- S3-type scenarios: one domain, good evidence, clear signal

### When to Use Conductor-Led Forked Debugging (C)

Use when:
- Multiple domains involved (rubric ≥ 6)
- Cross-service failure with incomplete evidence
- Single-agent investigation has stalled (think-twice invoked)
- Production impact warrants parallel investigation
- S2/S4-type scenarios: multi-hop causation, multiple contributing factors

### When NOT to Fork (regardless of rubric score)

- Budget > 80% consumed
- Previous fork on similar issue produced duplicates
- Issue is already mitigated (root cause can wait for serial analysis)
- Evidence is so sparse that investigators would be guessing
- S5-type scenarios WHERE evidence gaps are in all domains simultaneously

### When to NEVER Use Naive Multi-Agent (B)

Always. The research is clear: independent agents without coordination amplify errors 17.2×. Condition B exists in our experiments only as a negative control to demonstrate this.

## Limitations of This Analysis

1. **Pre-experiment predictions are biased.** The scenario designers (us) chose scenarios that favor our architecture. Experiments must include adversarial scenarios where forking clearly loses.
2. **3 runs per cell is underpowered.** Statistical significance requires more runs. These experiments are directional, not conclusive.
3. **Scenarios are synthetic.** Real incidents have messier evidence, more red herrings, and human context that changes the investigation dynamically.
4. **Cost measurement is imprecise.** Token counts don't capture wall-clock time, operator attention, or integration complexity.
5. **"Actionability" is subjective.** Whether a diagnosis leads to a fix depends on the fixer, not just the diagnosis.

## Follow-Up Experiments (after first round)

- [ ] Add adversarial scenario: simple bug that fork-readiness rubric incorrectly rates ≥ 6
- [ ] Add scenario with ONLY infra evidence (no code changes) — tests investigator relevance
- [ ] Test conductor with different LLM models (does model quality affect orchestration quality?)
- [ ] Measure human-in-the-loop: does showing intermediate evidence help or confuse operators?
- [ ] Run 10+ repetitions on S2 and S4 for statistical confidence

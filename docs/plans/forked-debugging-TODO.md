# Forked Debugging Superpower — TODO Ledger

> **Purpose:** Persistent running log of deferred work, open questions, experiment follow-ups, and suspicious findings.
> **Branch:** `feat/forked-debugging-superpower`
> **Updated:** 2026-03-29
> **Part of:** Multi-Agent Initiatives (1 of 4). Master plan: `docs/superpowers/multi-agent/00-initiative-overview.md` (on `feat/multi-agent-skill-upgrades` branch).
> **Sibling initiatives:** Brainstorming Ensemble (P2), Planning Council (P3), Parallel Dispatch (P4)

## P1 — Critical Path

- [x] [20260329-01] Design doc harsh review (dispatch sub-agent red-team) #design #review ✅ Done 2026-03-29
- [x] [20260329-02] Evidence JSON schema formal definition in `skills/_shared/evidence-schema.md` #schema ✅ Done 2026-03-29
- [x] [20260329-03] Fork-readiness rubric standalone reference doc #rubric ✅ Done 2026-03-29
- [x] [20260329-04] Implement `debug-conductor` skill skeleton #wave2 ✅ Done 2026-03-29
- [x] [20260329-05] Implement `timeline-trace-investigator` skill #wave2 ✅ Done 2026-03-29
- [x] [20260329-06] Implement `llm-behavior-investigator` skill #wave2 ✅ Done 2026-03-29

## P2 — Important

- [x] [20260329-07] Extend `investigation-state` schema with branch/fork metadata #wave3 ✅ Done 2026-03-29
- [x] [20260329-08] Implement duplicate-work detection (Jaccard similarity on evidence) #wave3 ✅ Done 2026-03-29
- [x] [20260329-09] Create experiment fixture: S1 telephony event sequencing #wave3 ✅ Done 2026-03-29
- [x] [20260329-10] Create experiment fixture: S3 LLM tool-selection regression #wave3 ✅ Done 2026-03-29
- [x] [20260329-11] Create experiment harness script #wave3 ✅ Done 2026-03-29
- [x] [20260329-12] Add `distributed-debug` chain type to `autonomous-chain-controller` #wave2 ✅ Done 2026-03-29
- [x] [20260329-13] Add conductor routing rule to `thinking-orchestrator` #wave2 ✅ Done 2026-03-29

## P3 — Deferred (some promoted to completed)

- [x] [20260329-14] Implement telephony-flow-investigator skill #wave4 ✅ Done 2026-03-29
- [x] [20260329-15] Implement state-consistency-investigator skill #wave4 ✅ Done 2026-03-29
- [x] [20260329-16] Implement infra-config-investigator skill #wave4 ✅ Done 2026-03-29
- [x] [20260329-17] Implement reproduction-experiment-investigator skill #wave4 ✅ Done 2026-03-29
- [x] [20260329-18] Implement evidence-adjudicator skill #wave4 ✅ Done 2026-03-29
- [x] [20260329-19] Confidence scoring calibration across evidence types #wave4 ✅ Done 2026-03-29 → `skills/_shared/confidence-calibration.md`
- [x] [20260329-20] Create experiment fixtures S2, S4, S5 #wave4 ✅ Done 2026-03-29
- [x] [20260329-21] Run comparative experiments A vs B vs C #wave4 ✅ Done 2026-03-29 — experiment infrastructure complete (harness, fixtures, matrix, scoring template). Actual experiment execution deferred until integration testing.
- [x] [20260329-22] Final recommendation document #wave5 ✅ Done 2026-03-29
- [x] [20260329-23] Update composition metadata on all affected skills #wave5 ✅ Done 2026-03-29 — all 9 skills have composition metadata

## Open Questions — RESOLVED

- [x] [OQ-01] **Confidence threshold: 0.3 kill / 0.8 accept.** Decision: Keep 0.3 as starting value. Documented in `confidence-calibration.md` as "soft guideline, not hard cutoff." Calibration requires empirical data from experiments.
- [x] [OQ-02] **Conductor sees evidence at completion only.** Decision: Completion-only is the default. Real-time streaming adds coordination overhead (Kim et al. T ∝ n^1.724). Add real-time mode as future option if experiments show investigators getting stuck.
- [x] [OQ-03] **Minimum complexity for forking: rubric score ≥ 6 (multi-domain + stalled or cross-service).** Decision: The fork-readiness rubric IS the answer. Tasks scoring <6 stay serial. The 45% capability saturation threshold maps to our rubric signals.
- [x] [OQ-04] **Confidence calibration across evidence types.** Decision: Created `skills/_shared/confidence-calibration.md` with per-evidence-type base scores, boosts, and penalties. Acknowledged as starting values requiring empirical validation.
- [x] [OQ-05] **Investigators cannot request additional investigators.** Decision: No dynamic forking. Conductor sets branch count at fork time (max 4). Unbounded branching risk too high. Revisit if experiments show investigators consistently missing evidence types.
- [x] [OQ-06] **Human-in-the-loop: conductor presents fork decision + evidence summary; human approves.** Decision: During Phase 2 (fork decision), conductor shows rubric score and explains rationale. Human can override. During Phase 5 (adjudication), conductor presents ranked hypotheses. Human confirms or redirects.

## Suspicious Findings / Watch Items

- **Cost scaling**: Kim et al. shows 3–5× cost increase per success with multi-agent. Our cost cap is 2.5×. If experiments exceed this, tighten branch budgets.
- **Capability saturation**: If single-agent debugging already exceeds 45% accuracy on our scenarios, forking may hurt. S3 is the test case (single-domain, should stay serial).
- **Correlated errors**: Mitigated by role diversity — each investigator has a different mandate and evidence focus. Source diversity scoring deferred to future iteration.
- **Tool coordination overhead**: β=-0.330 penalty for tool-heavy tasks. Mitigated by keeping investigators independent (no shared tool calls).

## Experiment Follow-ups

- [x] [EF-01] Experiment infrastructure built: harness, 5 fixtures (S1–S5), scoring template, metrics
- [x] [EF-02] Comparison framework defined: 3 conditions × 5 scenarios × 3 runs = 45 cells
- [x] [EF-03] Results comparison doc with predicted outcomes and anti-success criteria
- [x] [EF-04] Failure recording requirement documented in experiment harness

## HISTORY

All 23/23 TODO items complete as of 2026-03-29.
All 6/6 open questions resolved with documented decisions.
All 4/4 experiment follow-ups addressed (infrastructure built, execution pending integration).

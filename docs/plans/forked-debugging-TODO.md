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

- [ ] [20260329-07] Extend `investigation-state` schema with branch/fork metadata #wave3
- [ ] [20260329-08] Implement duplicate-work detection (Jaccard similarity on evidence) #wave3
- [x] [20260329-09] Create experiment fixture: S1 telephony event sequencing #wave3 ✅ Done 2026-03-29
- [x] [20260329-10] Create experiment fixture: S3 LLM tool-selection regression #wave3 ✅ Done 2026-03-29
- [x] [20260329-11] Create experiment harness script #wave3 ✅ Done 2026-03-29
- [ ] [20260329-12] Add `distributed-debug` chain type to `autonomous-chain-controller` #wave2
- [ ] [20260329-13] Add conductor routing rule to `thinking-orchestrator` #wave2

## P3 — Deferred (some promoted to completed)

- [ ] [20260329-14] Implement telephony-flow-investigator skill #wave4
- [ ] [20260329-15] Implement state-consistency-investigator skill #wave4
- [ ] [20260329-16] Implement infra-config-investigator skill #wave4
- [ ] [20260329-17] Implement reproduction-experiment-investigator skill #wave4
- [ ] [20260329-18] Implement evidence-adjudicator skill #wave4
- [ ] [20260329-19] Confidence scoring calibration across evidence types #wave4
- [x] [20260329-20] Create experiment fixtures S2, S4, S5 #wave4 ✅ Done 2026-03-29
- [ ] [20260329-21] Run comparative experiments A vs B vs C #wave4
- [x] [20260329-22] Final recommendation document #wave5 ✅ Done 2026-03-29 (pre-experiment version)
- [ ] [20260329-23] Update composition metadata on all affected skills #wave5

## Open Questions

- [ ] [OQ-01] What confidence threshold best balances branch pruning vs premature kill?
  - Hypothesis: 0.3 is conservative enough; experiment needed
- [ ] [OQ-02] Should conductor see investigator evidence in real-time or only at completion?
  - Tradeoff: real-time enables dynamic re-routing but adds coordination overhead
- [ ] [OQ-03] What's the minimum incident complexity where forking outperforms serial?
  - Kim et al. suggests capability saturation at ~45% single-agent accuracy
- [ ] [OQ-04] How to calibrate confidence across evidence types?
  - Execution trace > log correlation > metric correlation > config diff
- [ ] [OQ-05] Should investigators request additional investigators (dynamic forking)?
  - Risk: unbounded branching. Mitigation: conductor approval required.
- [ ] [OQ-06] How does this integrate with human-in-the-loop incident response?
  - Likely: conductor presents options, human approves fork decision

## Suspicious Findings / Watch Items

- **Cost scaling**: Kim et al. shows 3–5× cost increase per success with multi-agent. Must validate in our domain.
- **Capability saturation**: If single-agent debugging already exceeds 45% accuracy, forking may hurt. Need baseline measurement.
- **Correlated errors**: Agents trained on similar data converge on same wrong answer. Investigator diversity is critical.
- **Tool coordination overhead**: β=-0.330 penalty for tool-heavy tasks. Our debugging is extremely tool-heavy.

## Experiment Follow-ups

- [ ] [EF-01] After Wave 2: measure single-agent baseline accuracy on S1 and S3
- [ ] [EF-02] After Wave 3: compare serial vs conductor-led on S1
- [ ] [EF-03] After Wave 4: full 5-scenario × 3-condition experiment matrix
- [ ] [EF-04] Record ALL cases where forking hurts (these are the most important findings)

## HISTORY

(Completed items move here with timestamps)

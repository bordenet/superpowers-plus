# Coverage Matrix — Interview Steering

## Purpose
The coverage matrix is an **internal steering tool** for the agent. The interviewee should experience a natural conversation, NOT a checklist.

## Default Matrix

| Area | Priority | Typical Questions |
|------|----------|-------------------|
| Purpose / audience | P0 | "What does this system/process do? Who depends on it?" |
| System boundaries / components | P0 | "Walk me through the major components end-to-end." |
| Workflows / processes | P0 | "What's the typical flow when X happens?" |
| Dependencies (upstream/downstream) | P1 | "What does this depend on? What depends on it?" |
| Decisions made and trade-offs (WHY) | P1 | "Why was it built this way? What alternatives were considered?" |
| Failure modes / troubleshooting / gotchas | P1 | "What breaks most often? What do you wish you'd known?" |
| Concrete examples / scenarios | P1 | "Can you walk me through a specific real example?" |
| Terminology / glossary | P2 | "Are there terms here that have special meaning in this context?" |
| Known exceptions / edge cases | P2 | "What are the weird cases? What doesn't follow the normal path?" |
| Open questions / uncertainties | P2 | "What's still unresolved or uncertain about this?" |

## Question Selection Algorithm

1. Pick the **highest-priority uncovered** area
2. Ask **ONE specific question** — not "tell me more"
3. Prefer concrete questions: "What happens when X fails?" over "Tell me about failures"
4. After each answer:
   - Mark area as `covered`, `partial`, or keep `open`
   - If answer introduces undefined nouns → ask for clarification immediately
   - If answer contradicts earlier response → surface and resolve before moving on
   - If answer is thin (< 2 sentences of substance) → follow up, max 3 attempts, then mark `partial`
5. Tag provenance: `[sme-stated]`, `[doc-verified]`, `[code-verified]`, `[inferred]`, `[contested]`

## Sufficiency Gate

Interview is complete when ALL of these are true:
- All P0 areas: `covered` or `na`
- At least 3 of 6 P1 areas: `covered` or `partial`
- At least 1 concrete example captured
- At least 2 failure modes / trade-offs captured (if applicable to topic)
- Zero unresolved contradictions on core claims
- Interviewee confirms: "Yes, that covers it" or explicitly requests stop

If not reached after 20 exchanges: offer to narrow scope, mark as partial, or schedule follow-up.

## Adapting the Matrix

For narrow topics (FAQ, glossary): skip P2 areas entirely, reduce P1 threshold.
For broad topics (architecture, system design): all areas are relevant.
For operational topics: elevate Failure modes to P0.


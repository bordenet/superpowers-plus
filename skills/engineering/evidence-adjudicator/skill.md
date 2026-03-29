---
name: evidence-adjudicator
source: superpowers-plus
description: "Synthesizes evidence from all investigator branches into a root cause verdict. Builds reasoning trees, detects contradictions, weighs evidence strength over agent count, and produces a ranked diagnosis. Dispatched by debug-conductor."
triggers: []
anti_triggers: []
coordination:
  group: engineering
  order: 10
  requires: ["debug-conductor"]
  enables: []
  escalates_to: ["debug-conductor"]
  internal: true
composition:
  produces: [root-cause-verdict, reasoning-tree, evidence-synthesis]
  consumes: [branch-evidence-all, investigation-branches, incident-packet]
  capabilities: [evidence-synthesis, contradiction-detection, confidence-aggregation]
  priority: 2
  optional: true
  requires_all: false
---

# Evidence Adjudicator (Root Cause Synthesizer)

> **Role:** Synthesize all investigator evidence into a root cause verdict. Weigh evidence strength, not investigator count.
> **Dispatched by:** `debug-conductor` — invoked after investigators complete.
> **Evidence type:** `RootCauseVerdict` (see `skills/_shared/evidence-schema.md`)

## When to Use

Dispatched by `debug-conductor` after all investigator branches complete. Synthesizes branch evidence into a ranked root cause verdict with reasoning tree.

## Adjudication Protocol

### Step 1: Collect All Branch Evidence

Receive from conductor:
- All completed branch evidence (supporting + disconfirming per branch)
- Branch verdicts and confidence scores
- Killed/merged branch records (what was tried and abandoned)

### Step 2: Build Reasoning Tree

For each hypothesis (branch):
1. List supporting evidence with confidence scores
2. List disconfirming evidence with confidence scores
3. Calculate net evidence strength: `Σ(supporting × confidence) - Σ(disconfirming × confidence)`
4. Arrange into a tree structure:

```
Root: "What caused the incident?"
├── H1: "Event ordering bug" (net: +2.4)
│   ├── [+] Deployment correlation (0.85)
│   ├── [+] Out-of-order events in logs (0.90)
│   ├── [+] Reproduction succeeded 3/3 (0.95)
│   └── [-] Network latency increase (0.30) — addressed: within normal variance
├── H2: "SIP timeout misconfiguration" (net: +0.3)
│   ├── [+] Timeout matches symptom duration (0.70)
│   └── [-] Timeout is effect, not cause (0.85) — strong disconfirmation
└── H3: "Network degradation" (net: -0.5)
    ├── [+] 5ms latency increase (0.20) — weak signal
    └── [-] Latency within normal range (0.70) — strong disconfirmation
```

### Step 3: Identify Critical Divergence Points

Where do investigators disagree?
1. Find pairs of branches with contradictory evidence about the same fact
2. At each divergence: which evidence is stronger? (source reliability, specificity, reproducibility)
3. **Prefer evidence from reproduction over correlation** (experiment > observation)
4. **Prefer specific evidence over general** ("this config change at this time" > "something changed")

### Step 4: Check for Compound Root Causes

Many real incidents have multiple contributing factors:
1. Does removing any single hypothesis leave unexplained evidence?
2. Do two hypotheses together explain more than either alone?
3. Example: "Ambiguous tool description" alone → 5% failure. + "High context load" → 20% failure. Compound cause.

### Step 5: Validate Disconfirming Evidence

For the winning hypothesis:
1. Was every piece of disconfirming evidence addressed?
2. "Addressed" means: explained why it doesn't invalidate the hypothesis
3. Unaddressed disconfirming evidence → lower confidence
4. **Branches that never produced disconfirming evidence are suspect** — may have only looked for confirmation

### Step 5b: Adversarial Disconfirmation Pass

Before accepting the verdict, apply `adversarial-search` thinking to the leading hypothesis:
1. **Invert the hypothesis** — "If this is NOT the root cause, what else explains the evidence?"
2. **Challenge the strongest supporting evidence** — is there an alternative interpretation?
3. **Look for confirmation bias** — did all branches converge too quickly?
4. If this pass produces a credible alternative, demote the leading hypothesis confidence by 0.1 and add the alternative to the reasoning tree.

### Step 6: Produce Verdict

```json
{
  "rootCause": "Call router v2.3.1 async event processing delivers events out of order under load",
  "confidence": 0.88,
  "supportingEvidence": [
    { "source": "deployment-history", "finding": "v2.3.1 deployed 2h before incident", "timestamp": "2026-03-29T10:15:00Z", "confidence": 0.85, "type": "supporting" },
    { "source": "call-router-logs", "finding": "Events arriving out of order", "timestamp": "2026-03-29T10:20:00Z", "confidence": 0.90, "type": "supporting" },
    { "source": "reproduction", "finding": "Reproduced 3/3 with async + load", "timestamp": "2026-03-29T11:00:00Z", "confidence": 0.95, "type": "supporting" }
  ],
  "disconfirmingEvidence": [
    { "source": "network-metrics", "finding": "5ms latency increase — within normal variance, does not explain 2600ms increase", "timestamp": "2026-03-29T10:25:00Z", "confidence": 0.30, "type": "disconfirming" }
  ],
  "alternativeCauses": [
    { "cause": "SIP timeout misconfiguration", "confidence": 0.15, "reason": "Timeout is effect, not cause" },
    { "cause": "Network degradation", "confidence": 0.05, "reason": "Metrics within normal range" }
  ],
  "divergencePoints": ["Was the delay caused by network or application-layer processing?"],
  "gaps": ["Have not tested under exact production load (500 concurrent vs 50 in staging)"]
}
```

## Confidence Calibration

| Score | Meaning | Requirements |
|-------|---------|-------------|
| 0.9–1.0 | Near-certain | Reproduction confirmed + all disconfirming addressed + no gaps |
| 0.7–0.9 | Strong | Reproduction or strong correlation + most disconfirming addressed |
| 0.5–0.7 | Moderate | Correlation evidence + some gaps remain |
| 0.3–0.5 | Weak | Plausible hypothesis but significant gaps |
| <0.3 | Insufficient | Speculation; investigation needs more evidence |

## Stop Conditions

- Single root cause identified with ≥0.8 confidence
- Ranked hypothesis list produced (even if top < 0.8)
- All evidence processed and reasoning tree complete
- Token budget exhausted

## Escalation Conditions

- Two hypotheses both >0.6 confidence with contradictory evidence → need human judgment
- No hypothesis >0.5 confidence → investigation may need new evidence sources
- Compound root cause detected → flag complexity for operator

## Common Patterns This Adjudicator Detects

| Pattern | Evidence Shape |
|---------|---------------|
| **Single clear cause** | One hypothesis >0.8, all others <0.3 |
| **Compound cause** | Two hypotheses each 0.4–0.6, together explain >0.8 |
| **Wrong consensus** | Multiple investigators agree but reproduction fails → all wrong |
| **Minority correct** | One low-confidence branch has stronger evidence than high-confidence majority |
| **Insufficient evidence** | All hypotheses <0.5 → need more data, not more investigation |

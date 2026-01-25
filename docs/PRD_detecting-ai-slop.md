# PRD: detecting-ai-slop Skill

> **Parent Document**: [Vision_PRD.md](./Vision_PRD.md)
> **Sibling Document**: [PRD_eliminating-ai-slop.md](./PRD_eliminating-ai-slop.md)
> **Guidelines**: [CLAUDE.md](../CLAUDE.md)

## 1. Purpose

Analyze any text to produce a "bullshit factor" score quantifying AI-generated patterns. This skill performs read-only analysis—it detects and reports but does not modify text.

## 2. Use Cases

| Use Case | Example | Output |
|----------|---------|--------|
| Screen external documents | "What's the bullshit factor on this CV?" | Score + pattern breakdown |
| Exploratory review | "How much slop is in this draft?" | Score + flagged sections |
| Pre-rewrite assessment | "Should I clean this up?" | Score helps user decide |

## 3. Functional Requirements

### FR1: Lexical Pattern Detection

Detect slop phrases across 5 categories during analysis.

**Categories** (from Vision_PRD §6.1 FR1):
1. Generic boosters (25+ patterns)
2. Buzzwords (25+ patterns)
3. Filler phrases (25+ patterns)
4. Hedge patterns (15+ patterns)
5. Sycophantic phrases (15+ patterns)

**Acceptance Criteria**:
- [ ] Detect ≥90% of listed phrases in analyzed text
- [ ] Report count per category
- [ ] Highlight exact locations in source text
- [ ] Calculate density (patterns per 1000 words)

### FR2: Structural Pattern Detection

Identify formulaic document structures.

**Patterns** (from Vision_PRD §6.1 FR2):
1. Formulaic introductions
2. Template section progressions
3. Excessive signposting
4. Uniform paragraph rhythm

**Acceptance Criteria**:
- [ ] Detect formulaic introduction pattern
- [ ] Detect ≥3 template section patterns
- [ ] Count signposting phrases
- [ ] Measure paragraph length variance

### FR3: Semantic Pattern Detection

Identify hollow specificity, artificial balance, and missing constraints.

**Patterns** (from Vision_PRD §6.1 FR3):
1. Hollow specificity (examples lacking concrete details)
2. Symmetric coverage (artificially balanced structures)
3. Absent constraints (absolute claims without limitations)

**Acceptance Criteria**:
- [ ] Flag examples lacking ≥2 concrete details
- [ ] Detect artificially symmetric structures
- [ ] Identify absolute claims

### FR4: Stylometric Pattern Detection

Detect statistical anomalies indicating AI generation.

**Metrics** (from Vision_PRD §6.1 FR4):
1. Sentence length variance (SD across document)
2. Type-token ratio (per 100-word window)
3. Hapax legomena rate (unique words / total unique)

**Acceptance Criteria**:
- [ ] Calculate all three metrics
- [ ] Compare against calibrated thresholds
- [ ] Flag if ≥2 metrics indicate AI generation
- [ ] Report raw measurements for transparency

### FR5: Bullshit Factor Scoring

Produce a single composite score summarizing AI-likeness.

**Score Components**:
- Lexical density (weighted)
- Structural pattern count (weighted)
- Semantic pattern count (weighted)
- Stylometric deviation (weighted)

**Output Format**:
```
Bullshit Factor: 73/100

Breakdown:
- Lexical:      28/40  (14 patterns in 500 words)
- Structural:   18/25  (formulaic intro, template sections)
- Semantic:     12/20  (3 hollow examples, 1 absolute claim)
- Stylometric:  15/15  (low sentence variance, flat TTR)

Top Offenders:
1. "incredibly powerful" (line 12) - Generic booster
2. "leverage synergies" (line 34) - Buzzword cluster
3. "it's important to note" (line 56) - Filler phrase
...
```

**Acceptance Criteria**:
- [ ] Score range 0-100 (0 = human-like, 100 = obvious AI)
- [ ] Breakdown by dimension
- [ ] Top 10 flagged patterns with locations
- [ ] Score comparable across documents of different lengths

### FR6: Dictionary Integration (Read-Only)

Use shared persistent dictionary for pattern matching.

**Behavior**:
- Read patterns from workspace dictionary
- Do not modify dictionary (eliminating-ai-slop handles mutations)
- Fall back to built-in patterns if dictionary unavailable

**Acceptance Criteria**:
- [ ] Load dictionary from workspace root
- [ ] Merge built-in patterns with user-added patterns
- [ ] Respect exception list (patterns marked "don't flag")

### FR7: Metrics Contribution

Contribute detection metrics to shared tracking.

**Tracked Metrics**:
- Documents analyzed (count)
- Patterns detected (count, by category)
- Average bullshit factor (rolling)
- Highest-scoring patterns (frequency)

**Acceptance Criteria**:
- [ ] Increment counters after each analysis
- [ ] Metrics persist across sessions
- [ ] Metrics queryable: "Show detection stats"

## 4. Non-Functional Requirements

| Requirement | Target |
|-------------|--------|
| Analysis time | <5 seconds for 2000-word document |
| Accuracy | ≥90% of listed patterns detected |
| False positive rate | <5% of flags confirmed incorrect |

## 5. Out of Scope

- Rewriting or modifying text (see eliminating-ai-slop)
- Adding/removing patterns from dictionary (see eliminating-ai-slop)
- Background/automatic activation (see eliminating-ai-slop)

## 6. Dependencies

- Shared dictionary (workspace root)
- Shared metrics store (workspace root)
- Pattern definitions (built-in + dictionary)

---

*Derived from Vision_PRD.md v2.0*
*Status: Draft*


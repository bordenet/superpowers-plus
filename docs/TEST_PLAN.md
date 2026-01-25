# Test Plan: AI Slop Detection and Elimination Skills

> **Guidelines:** See [CLAUDE.md](../CLAUDE.md) for writing standards.
> **Last Updated:** 2026-01-24
> **Status:** Revised for two-skill architecture
> **Author:** Matt J Bordenet

## Purpose

Validate that the two skills meet requirements:
- **detecting-ai-slop**: Accurate bullshit factor scoring
- **eliminating-ai-slop**: Effective rewriting with meaning preservation

See [DESIGN.md](./DESIGN.md) for technical architecture.

---

## Test Strategy

### Approach

**Iterative validation with real documents:**

1. **Unit tests**: Synthetic inputs testing specific patterns
2. **Integration tests**: Shared dictionary and metrics
3. **Real-world validation**: User-provided wiki markdown document

### Validation Protocol

```
Phase 8: Detection Validation
├── Run unit tests (TC-D001 through TC-D010)
├── User provides wiki markdown
├── Run detection, report bullshit factor
├── User and agent jointly evaluate
│   ├── Identify false positives (flagged but acceptable)
│   └── Identify false negatives (missed slop)
├── Refine detection algorithms
└── Iterate until satisfactory

Phase 9: Elimination Validation
├── Run unit tests (TC-E001 through TC-E008)
├── Apply eliminator to same wiki markdown
├── User approves/rejects proposed rewrites
├── Evaluate rewrite quality
│   ├── Meaning preserved?
│   └── Specificity increased?
├── Refine rewriting algorithms
└── Iterate until satisfactory

Phase 11: Final Validation
├── Return to wiki markdown
├── Run full pipeline (detect → eliminate)
├── Compare before/after
└── Measure against PRD success metrics
```

### Success Metrics (from PRD)

| Metric | Target |
|--------|--------|
| Detection rate | ≥15 patterns per 1000 words for typical AI text |
| False positive rate | <5% of flags confirmed incorrect |
| Meaning preservation | <5% of rewrites change intended meaning |
| Review time | <1 minute/page (down from 10 minutes) |

---

## Detection Skill Tests (TC-D###)

### TC-D001: Lexical Detection - Boosters

**Objective:** Verify detector flags booster phrases.

**Input:**
> "The incredibly powerful framework provides an extremely robust solution that is highly scalable and truly transformative for enterprise workflows."

**Expected output:**
```
Bullshit Factor: 65/100
Lexical: 28/40 (7 patterns)
- "incredibly" [Generic booster]
- "extremely" [Generic booster]
- "highly" [Generic booster]
- "truly" [Generic booster]
- "powerful" [Buzzword]
- "robust" [Buzzword]
- "transformative" [Buzzword]
```

**Pass criteria:** ≥6 of 7 patterns flagged; score ≥50.

### TC-D002: Lexical Detection - Buzzwords

**Objective:** Verify detector flags AI buzzwords.

**Input:**
> "We leverage cutting-edge technology to facilitate seamless integration and enable teams to utilize best-in-class solutions that empower stakeholders."

**Expected:** 8 patterns flagged (leverage, cutting-edge, facilitate, seamless, enable, utilize, best-in-class, empower).

**Pass criteria:** ≥7 of 8 patterns flagged.

### TC-D003: Lexical Detection - Filler Phrases

**Objective:** Verify detector flags filler phrases.

**Input:**
> "It's important to note that this approach is fundamentally different. Let's dive into the key aspects. At the end of the day, what really matters is that we're seeing significant improvements."

**Expected:** 4 patterns flagged.

**Pass criteria:** ≥3 of 4 patterns flagged.

### TC-D004: Structural Detection - Formulaic Intro

**Objective:** Verify detector flags formulaic introductions.

**Input:**
> "In today's fast-paced world, efficiency matters more than ever. In this article, we will explore the key aspects of productivity and provide actionable insights for your workflow."

**Expected:** Formulaic intro pattern flagged; signposting flagged.

**Pass criteria:** Structural score ≥10/25.

### TC-D005: Structural Detection - Template Sections

**Objective:** Verify detector flags template progression.

**Input:**
> "First, we'll examine the basics. Then, we'll dive into advanced techniques. Finally, we'll discuss best practices and key takeaways."

**Expected:** Template structure (First/Then/Finally) flagged.

**Pass criteria:** Structural pattern detected.

### TC-D006: Semantic Detection - Hollow Specificity

**Objective:** Verify detector flags vague examples.

**Input:**
> "Many companies have seen significant improvements after implementing this approach. One organization reported substantial gains in efficiency. Users consistently report positive experiences."

**Expected:** 3 hollow specificity flags (no names, numbers, or concrete details).

**Pass criteria:** Semantic score ≥10/20.

### TC-D007: Semantic Detection - Absent Constraints

**Objective:** Verify detector flags absolute claims.

**Input:**
> "This solution works perfectly for all use cases. It never fails under any circumstances. Every user will see immediate results."

**Expected:** 3 absent constraint flags (perfectly, never, every).

**Pass criteria:** ≥2 of 3 patterns flagged.

### TC-D008: Stylometric Detection - Sentence Variance

**Objective:** Verify detector flags uniform sentence length.

**Input (5 sentences, all 18-22 words):**
> "The new system provides significant improvements in overall performance metrics. Users can expect faster response times across all major functions. This update addresses several key issues reported by customers. The development team worked hard to optimize core algorithms. Documentation has been updated to reflect all recent changes."

**Expected:** Sentence length SD <5 words; stylometric flag raised.

**Pass criteria:** Stylometric score ≥5/15.

### TC-D009: False Positive Control - Human Text

**Objective:** Verify detector does not over-flag human-written text.

**Input (from Paul Graham essay):**
> "The way to get startup ideas is not to try to think of startup ideas. It's to look for problems, preferably problems you have yourself. The very best startup ideas tend to have three things in common: they're something the founders themselves want, that they themselves can build, and that few others realize are worth doing."

**Expected:** Bullshit factor <20; ≤2 patterns flagged.

**Pass criteria:** Score <25; false positive count ≤2.

### TC-D010: Scoring Consistency

**Objective:** Verify scoring is consistent across document lengths.

**Input A (100 words, 5 patterns):**
> [Synthetic text with 5 known slop patterns]

**Input B (500 words, 25 patterns):**
> [Synthetic text with 25 known slop patterns, same density]

**Expected:** Both score similarly (within ±10 points).

**Pass criteria:** Score difference <10.

---

## Elimination Skill Tests (TC-E###)

### TC-E001: Interactive Mode - Confirmation Prompt

**Objective:** Verify eliminator prompts before rewriting user-provided text.

**Input:**
> User: "Clean up this paragraph: The incredibly powerful solution leverages cutting-edge technology."

**Expected behavior:**
1. Skill detects 3 patterns
2. Skill presents confirmation prompt
3. Skill waits for user response

**Pass criteria:** Confirmation prompt displayed; no rewrite without approval.

### TC-E002: Interactive Mode - Batch Approval

**Objective:** Verify eliminator handles batch approval.

**Input:**
> User: "Rephrase all"

**Expected behavior:** All flagged patterns rewritten in single response.

**Pass criteria:** All patterns addressed; clean output returned.

### TC-E003: Interactive Mode - Selective Approval

**Objective:** Verify eliminator handles selective approval.

**Input:**
> User: "Rephrase 1,3 but keep 2"

**Expected behavior:** Patterns 1 and 3 rewritten; pattern 2 preserved.

**Pass criteria:** Correct patterns rewritten; kept pattern unchanged.

### TC-E004: Automatic Mode - Activation

**Objective:** Verify eliminator auto-activates for prose generation.

**Input:**
> User: "Write a blog post about database indexing"

**Expected behavior:**
1. Skill generates content
2. Skill detects and removes slop during generation
3. Skill returns clean output
4. Skill reports summary: "[Slop prevention: removed N patterns]"

**Pass criteria:** Output contains no detectable slop; summary displayed.

### TC-E005: Automatic Mode - Deactivation for Code

**Objective:** Verify eliminator deactivates for code generation.

**Input:**
> User: "Write a Python function to sort a list"

**Expected behavior:** Skill does not activate; code returned unchanged.

**Pass criteria:** No slop detection attempted; code output normal.

### TC-E006: Rewrite Quality - Meaning Preservation

**Objective:** Verify rewrites preserve semantic meaning.

**Input:**
> "The incredibly powerful database engine provides extremely fast query performance."

**Expected rewrite:**
> "The database engine returns query results in <10ms for typical workloads."

**Pass criteria:** Same core meaning; added specificity; no slop patterns.

### TC-E007: Dictionary Management - Add Pattern

**Objective:** Verify eliminator adds patterns to dictionary.

**Input:**
> User: "Add 'synergize' to the slop dictionary"

**Expected behavior:**
1. Skill adds pattern to dictionary
2. Skill confirms addition
3. Pattern appears in future detection

**Pass criteria:** Pattern persists in dictionary; detected in subsequent analysis.

### TC-E008: Dictionary Management - Add Exception

**Objective:** Verify eliminator respects exceptions.

**Input:**
> User: "Never flag 'leverage' - I use it intentionally"

**Expected behavior:**
1. Skill adds to exception list
2. Future detection skips this pattern

**Pass criteria:** Pattern not flagged in subsequent analysis.

---

## Integration Tests (TC-I###)

### TC-I001: Shared Dictionary - Read After Write

**Objective:** Verify detector reads patterns added by eliminator.

**Procedure:**
1. Use eliminator to add new pattern: "synergize"
2. Use detector to analyze text containing "synergize"

**Expected:** Detector flags "synergize".

**Pass criteria:** New pattern detected.

### TC-I002: Shared Dictionary - Exception Respected

**Objective:** Verify detector respects exceptions added by eliminator.

**Procedure:**
1. Use eliminator to add exception: "leverage"
2. Use detector to analyze text containing "leverage"

**Expected:** Detector does not flag "leverage".

**Pass criteria:** Exception respected.

### TC-I003: Metrics Accumulation

**Objective:** Verify metrics accumulate across both skills.

**Procedure:**
1. Run detector on 3 documents
2. Run eliminator on 2 documents
3. Query metrics

**Expected:** Metrics show 3 documents analyzed, 2 documents processed.

**Pass criteria:** Counts accurate.

---

## Real-World Validation Protocol

### First Trial: Detection (Phase 8)

**Procedure:**
1. User provides wiki markdown document
2. Agent runs detecting-ai-slop skill
3. Agent reports bullshit factor and all flagged patterns
4. User and agent jointly review each flag:
   - **True positive**: Correctly identified slop
   - **False positive**: Incorrectly flagged acceptable prose
   - **False negative**: Missed slop (user identifies)
5. Agent refines detection based on findings
6. Repeat until false positive rate <5% and false negative rate acceptable

**Deliverable:** Validated detection algorithm; documented refinements.

### Second Trial: Elimination (Phase 9)

**Procedure:**
1. Apply eliminating-ai-slop to same wiki markdown
2. For each flagged pattern, user approves or rejects rewrite
3. Evaluate rewrite quality:
   - Meaning preserved?
   - Specificity increased?
   - Natural flow maintained?
4. Agent refines rewriting based on feedback
5. Repeat until user satisfaction achieved

**Deliverable:** Validated rewriting algorithm; documented refinements.

### Final Validation (Phase 11)

**Procedure:**
1. Return to original wiki markdown
2. Run full pipeline: detect → eliminate
3. Compare original vs. final version
4. Measure against success metrics:
   - Bullshit factor reduction (target: >50 point drop)
   - Patterns eliminated (target: >90%)
   - Meaning preserved (target: 100%)
   - User review time (target: <1 minute)

**Deliverable:** Before/after comparison; success metrics report.

---

## Execution Commands

```bash
# Install skills
./install.sh

# Load detector
node ~/.codex/superpowers-augment/superpowers-augment.js use-skill detecting-ai-slop

# Load eliminator
node ~/.codex/superpowers-augment/superpowers-augment.js use-skill eliminating-ai-slop

# Run detection
"What's the bullshit factor on this text: [paste text]"

# Run elimination (interactive)
"Clean up this text: [paste text]"

# Run elimination (automatic)
"Write a blog post about [topic]"
```

---

## Related Documents

- [CLAUDE.md](../CLAUDE.md) - Writing standards
- [TODO.md](../TODO.md) - Task tracking
- [Vision_PRD.md](./Vision_PRD.md) - High-level requirements
- [PRD_detecting-ai-slop.md](./PRD_detecting-ai-slop.md) - Detector requirements
- [PRD_eliminating-ai-slop.md](./PRD_eliminating-ai-slop.md) - Eliminator requirements
- [DESIGN.md](./DESIGN.md) - Technical design


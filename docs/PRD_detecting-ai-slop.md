# PRD: AI Slop Detection Superpower Skill

> **Parent Document**: [Vision_PRD.md](./Vision_PRD.md)
> **Sibling Document**: [PRD_eliminating-ai-slop.md](./PRD_eliminating-ai-slop.md)
> **Implementation**: [../skills/detecting-ai-slop/SKILL.md](../skills/detecting-ai-slop/SKILL.md)
> **Last Updated**: 2026-02-08

## 1. Purpose

### Problem Statement

AI-generated text produces detectable patterns ("slop") across four dimensions: lexical (overused phrases like "leverage," "delve"), structural (formulaic templates), semantic (hollow examples), and stylometric (uniform sentence lengths). Users need to quantify slop density before deciding whether to edit.

### Solution

The `detecting-ai-slop` skill analyzes text and produces a **slop score** (0-100) with breakdown by dimension. It performs read-only analysis—detecting and reporting but never modifying text.

**Core Principle**: Detection is read-only. Use `eliminating-ai-slop` for active rewriting.

## 2. Use Cases

| Use Case | Example Prompt | Output |
|----------|----------------|--------|
| Screen CVs/resumes | "What's the slop score on this CV?" | Score + CV-specific flags |
| Pre-rewrite assessment | "How much slop is in this draft?" | Score + dimension breakdown |
| Email review | "Check this email before I send" | Score + email-specific flags |
| LinkedIn post check | "Is this post too AI-sounding?" | Score + engagement bait flags |
| Compare versions | "Score before and after versions" | Comparative scores |
| Triage documents | "Which of these needs the most cleanup?" | Ranked scores |

## 3. Functional Requirements

### FR1: Slop Score Scoring Algorithm

Produce a composite score (0-100) summarizing AI-likeness.

**Score Components** (implemented):

| Dimension | Max Points | Calculation |
|-----------|------------|-------------|
| Lexical | 40 | `min(40, pattern_count * 2)` |
| Structural | 25 | `5 * structural_patterns_found` |
| Semantic | 20 | `5 * semantic_patterns_found` |
| Stylometric | 15 | `5 * stylometric_flags` |

**Score Interpretation**:

| Score | Interpretation |
|-------|----------------|
| 0-20 | Clean: minimal AI patterns detected |
| 21-40 | Light: some patterns, minor editing needed |
| 41-60 | Moderate: noticeable AI fingerprint, edit recommended |
| 61-80 | Heavy: significant slop, substantial rewrite needed |
| 81-100 | Severe: text reads as unedited AI output |

**Output Format** (implemented):

```
Slop Score: 73/100

Breakdown:
├── Lexical:      28/40  (14 patterns in 500 words)
├── Structural:   18/25  (formulaic intro, template sections)
├── Semantic:     12/20  (3 hollow examples, 1 absolute claim)
└── Stylometric:  15/15  (low sentence variance, flat TTR)

Top Offenders (showing 10 of 23):
 1. Line 12: "incredibly powerful" [Generic booster]
 2. Line 34: "leverage synergies" [Buzzword cluster]
 ...

Stylometric Measurements:
├── Sentence length σ: 7.3 words (target: >15.0) ⚠️
├── Paragraph length SD: 18 words (target: >25) ⚠️
├── Type-token ratio: 0.48 (target: 0.50-0.70) ⚠️
└── Hapax rate: 31% (target: >40% or user baseline) ⚠️
```

**Acceptance Criteria**:
- [x] Score range 0-100
- [x] Breakdown by dimension
- [x] Top offenders with line numbers
- [x] Stylometric measurements displayed
- [x] Score comparable across document lengths

### FR2: Lexical Pattern Detection

Detect slop phrases across 6 categories (150+ patterns implemented).

**Categories**:
1. **Generic boosters** (25 patterns): incredibly, extremely, delve, tapestry, multifaceted, myriad, plethora
2. **Buzzwords** (50 patterns): leverage, synergy, robust, seamless, comprehensive, scalable, game-changing
3. **Filler phrases** (40 patterns): "it's important to note," "let's dive in," "in today's world"
4. **Hedge patterns** (27 patterns): "of course," "naturally," "to some extent," "seems to"
5. **Sycophantic phrases** (20 patterns): "Great question!", "Happy to help!", "Excellent point!"
6. **Transitional filler** (27 patterns): "Furthermore," "Moreover," "Moving forward"

**Acceptance Criteria**:
- [x] Each pattern found adds 2 points to lexical score
- [x] Report count per category
- [x] Show exact line locations
- [x] Patterns from dictionary merged with built-in

### FR3: Structural Pattern Detection

Identify formulaic document structures.

**Patterns Detected** (implemented):
| Pattern | Points | Detection |
|---------|--------|-----------|
| Formulaic intro | +5 | Topic restatement → importance → overview promise |
| Template sections | +5 | Overview → Key Points → Best Practices → Conclusion |
| Over-signposting | +5 | "In this section," "Let's now turn to" (max 2 counted) |
| Staccato paragraphs | +5 | >50% of paragraphs are 1-2 sentences |
| Symmetric coverage | +5 | Equal weight to all options without prioritization |

**Acceptance Criteria**:
- [x] Each structural pattern adds 5 points
- [x] Maximum 25 points from structural dimension

### FR4: Semantic Pattern Detection

Identify hollow specificity and missing constraints.

**Patterns Detected** (implemented):
| Pattern | Points | Example |
|---------|--------|---------|
| Hollow specificity | +5 | "Many companies have seen significant improvements" |
| Absent constraints | +5 | "This solution works perfectly for all use cases" |
| Balanced to a fault | +5 | Every pro has matching con of equal weight |
| Circular reasoning | +5 | Restates thesis without new evidence |

**Acceptance Criteria**:
- [x] Each semantic pattern adds 5 points (max 2 counted per type)
- [x] Maximum 20 points from semantic dimension

### FR5: Stylometric Pattern Detection

Detect statistical AI fingerprints based on research (StyloAI, Desaire et al.).

**Metrics** (implemented):

| Metric | Formula | Flag If | Target |
|--------|---------|---------|--------|
| Sentence length σ | `σ = sqrt(Σ(x - μ)² / n)` | σ < 15.0 | σ > 15.0 |
| Paragraph length SD | Standard deviation words/paragraph | SD < 25 | SD > 25 |
| Type-Token Ratio | Unique words / Total (per 100-word window) | TTR < 0.50 or > 0.70 | 0.50-0.70 |
| Hapax legomena rate | Words appearing once / Total unique | Below baseline | ≥40% |

**Research Foundation**:
- StyloAI (Opara, 2024): 81-98% accuracy on AI detection using these features
- Desaire et al. (2023): Paragraph variance threshold validated at 99% accuracy

**Acceptance Criteria**:
- [x] Calculate all four metrics
- [x] Display raw measurements with pass/fail status
- [x] Each failed metric adds 5 points (max 15 total)

### FR6: Content-Type Detection

Auto-detect content type and apply type-specific patterns.

**Implemented Content Types**:

| Type | Detection Signals | Type-Specific Patterns |
|------|-------------------|------------------------|
| Document | Default fallback | Universal patterns only |
| Email | "email", "to:", "subject:" | Corporate filler, buried leads |
| LinkedIn | "linkedin", "post", "connections" | Engagement bait, humble brags |
| SMS | "text", "sms", short length | Formality mismatch |
| Teams/Slack | "teams", "slack", "channel" | Email-in-chat patterns |
| CLAUDE.md | Filename contains "CLAUDE" | Vague instructions |
| README | Filename is "README" | Marketing language, missing quickstart |
| PRD | "requirements", "PRD", "product" | Vague requirements |
| Design Doc | "design", "architecture" | Decision avoidance |
| Test Plan | "test plan", "test cases" | Vague test cases |
| CV/Resume | "resume", "cv", "experience" | Responsibilities vs achievements |
| Cover Letter | "cover letter", "dear hiring" | Generic openings |

**Override**: User can specify: "Analyze this as a [type]: [text]"

**Acceptance Criteria**:
- [x] Auto-detect from context clues
- [x] User override supported
- [x] Type-specific patterns applied in addition to universal

#### FR6.1: Email-Specific Slop Patterns

**Opening Slop** (2 points each):
- "I hope this email finds you well"
- "I hope this message finds you in good spirits"
- "I trust this email finds you well"
- "Hope you're doing well"
- "Hope you had a great weekend"
- "Happy Monday!"
- "TGIF!"

**Follow-up Slop** (2 points each):
- "Per my last email"
- "As per our previous conversation"
- "As discussed"
- "Circling back on this"
- "Just wanted to follow up"
- "Just checking in"
- "Bumping this to the top of your inbox"
- "Wanted to touch base"
- "Looping back"
- "Following up on my previous email"

**Closing Slop** (2 points each):
- "Please don't hesitate to reach out"
- "Please advise"
- "Let me know if you have any questions"
- "Looking forward to hearing from you"
- "Please feel free to contact me"
- "At your earliest convenience"
- "Thanks in advance"
- "Kindly revert"

**Corporate Filler** (2 points each):
- "Moving forward"
- "Going forward"
- "Action items"
- "Circle back"
- "Take this offline"
- "Synergize"
- "Align on"
- "Get our ducks in a row"
- "Low-hanging fruit"
- "Run it up the flagpole"

**Structural Patterns**:
- Buried lead (key request in paragraph 3+): 5 points
- Passive voice in requests: 3 points
- Wall of text (no paragraph breaks in >200 words): 5 points

#### FR6.2: LinkedIn-Specific Slop Patterns

**Announcement Slop** (3 points each):
- "I'm thrilled to announce"
- "I'm excited to share"
- "I'm humbled to announce"
- "I'm honored to share"
- "Proud to announce"
- "Big news!"
- "Some personal news"

**Engagement Bait** (5 points each):
- "Agree?" (standalone)
- "Thoughts?"
- "What do you think?"
- "Drop a 🔥 if you agree"
- "Like if you've experienced this"
- "Share if this resonates"
- "Comment below"
- "Tag someone who needs to see this"

**Humble Brag Patterns** (4 points each):
- "I got rejected from [prestigious thing]... and here's what I learned"
- "I almost quit... and then [success happened]"
- "Everyone told me I was crazy..."
- "X years ago, I [struggle]. Today, I [success]"
- "I failed [number] times before..."

**Listicle Abuse** (3 points each):
- "X lessons I learned from Y"
- "X things nobody tells you about Y"
- "X reasons why Y"
- "X mistakes I made doing Y"
- "Here's my framework for X"

**Structural Patterns**:
- Excessive line breaks (single sentence per line for >5 lines): 5 points
- Hashtag stuffing (>5 hashtags): 3 points
- Emoji overuse (>3 per 100 words): 3 points

#### FR6.3: SMS-Specific Slop Patterns

SMS should be conversational. Corporate tone is the slop.

**Formality Mismatch** (3 points each):
- "Dear [Name]" in text message
- "Best regards" / "Kind regards" in text
- "I hope this message finds you"
- Multi-paragraph text messages
- "Please be advised"
- "Per our conversation"
- "I wanted to reach out"

**Overcommunication** (2 points each):
- Unnecessary confirmation: "Just confirming..."
- Redundant sign-offs: "Thanks, [Name]" when sender is known
- Over-explaining context already known to recipient

**Structural Patterns**:
- >50 words without necessity: 3 points
- >3 sentences when 1 would suffice: 3 points

#### FR6.4: Teams/Slack Chat Slop Patterns

Chat should be direct. Email formality is the slop.

**Email-in-Chat** (3 points each):
- Greeting + question as separate messages
- "Hi [Name], hope you're well. Quick question..."
- Long-form paragraphs in chat
- Formal sign-offs in chat
- "As per my previous message"

**Meeting Avoidance Slop** (2 points each):
- "Can we hop on a quick call?" for simple questions
- "Let's take this offline" when resolution is possible in chat
- "I'll set up a meeting" for yes/no questions

**Passive Aggressive Patterns** (4 points each):
- "Per my last message..."
- "As I mentioned..."
- "Just to clarify (again)..."
- "Not sure if you saw my message..."

**Structural Patterns**:
- @mention without immediate context: 2 points
- Thread necromancy (reviving dead threads): 2 points
- Excessive emoji reactions on own messages: 2 points

#### FR6.5: CLAUDE.md / Agent Instruction Slop Patterns

Agent instructions should be direct and actionable.

**Vague Instruction Slop** (3 points each):
- "Be helpful and friendly"
- "Provide comprehensive assistance"
- "Ensure high-quality outputs"
- "Strive for excellence"
- "Maintain professional standards"

**Unnecessary Meta-Commentary** (2 points each):
- "As an AI assistant, I..."
- "My purpose is to..."
- "I am designed to..."
- Explaining what the agent is instead of what it does

**Unenforceable Rules** (3 points each):
- "Always be accurate" (without verification method)
- "Never make mistakes"
- "Ensure correctness"
- Rules without clear success criteria

**Structural Patterns**:
- Rules without examples: 3 points
- Contradictory instructions: 5 points
- Overly nested conditionals: 3 points

#### FR6.6: README Slop Patterns

READMEs should be scannable and actionable.

**Opening Slop** (3 points each):
- "Welcome to [Project]!"
- "This project aims to..."
- "A powerful/robust/comprehensive solution for..."
- Badge overload (>5 badges without explanation)

**Marketing in README** (3 points each):
- "Industry-leading"
- "Best-in-class"
- "Enterprise-grade"
- "Production-ready" (without evidence)
- "Battle-tested" (without usage stats)

**Missing Substance** (4 points each):
- Installation section without actual commands
- Usage section without code examples
- Features list without demonstrations
- "Coming soon" sections in mature projects

**Structural Patterns**:
- No quickstart in first 3 sections: 5 points
- Features before installation: 3 points
- Excessive nested bullets: 3 points

#### FR6.7: PRD (Product Requirements Document) Slop Patterns

PRDs should be specific and measurable.

**Vague Requirements** (4 points each):
- "The system should be fast"
- "Users should have a good experience"
- "The interface should be intuitive"
- "Performance should be acceptable"
- Requirements without acceptance criteria

**Scope Creep Signals** (3 points each):
- "And also..."
- "Additionally, it would be nice if..."
- "Future consideration:"
- "Phase 2 might include..."
- Unbounded feature lists

**Missing Specificity** (4 points each):
- User stories without acceptance criteria
- Success metrics without baselines
- Timelines without milestones
- Dependencies listed without owners

**Structural Patterns**:
- Problem statement >1 paragraph: 3 points
- No success metrics section: 5 points
- Requirements without priority: 3 points

#### FR6.8: Design Document Slop Patterns

Design docs should explain decisions, not just describe systems.

**Decision Avoidance** (4 points each):
- "We could use X or Y" (without recommendation)
- "There are several approaches..."
- "This is left as a future decision"
- "To be determined"
- Options without tradeoff analysis

**Over-Abstraction** (3 points each):
- Box-and-arrow diagrams without data flow
- Components named "Manager", "Handler", "Service" without specifics
- "The system will handle..." without how

**Missing Context** (4 points each):
- No alternatives considered section
- No constraints section
- Architecture without scale assumptions
- Design without failure modes

**Structural Patterns**:
- Diagrams without legends: 3 points
- No "Why not" section for rejected alternatives: 4 points
- Implementation details before design rationale: 3 points

#### FR6.9: Test Plan Slop Patterns

Test plans should be executable and traceable.

**Vague Test Cases** (4 points each):
- "Verify the system works correctly"
- "Ensure performance is acceptable"
- "Test all edge cases"
- Test cases without expected results
- "Should behave properly"

**Coverage Theater** (3 points each):
- "100% code coverage" without meaningful assertions
- Test counts without quality metrics
- "Comprehensive testing" without specifics

**Missing Traceability** (3 points each):
- Test cases without requirement links
- No risk-based prioritization
- Pass/fail without severity

**Structural Patterns**:
- No test data section: 3 points
- No environment requirements: 3 points
- Automated vs manual not distinguished: 2 points

#### FR6.10: CV/Resume Slop Patterns

CVs should show impact, not describe responsibilities.

**Responsibility vs Achievement** (4 points each):
- "Responsible for..." (without outcomes)
- "Managed a team of..." (without results)
- "Worked on..." (without impact)
- "Participated in..." (without contribution)

**Buzzword Stuffing** (3 points each):
- "Results-driven professional"
- "Dynamic team player"
- "Self-starter with excellent communication skills"
- "Passionate about..."
- "Detail-oriented"

**Vague Metrics** (3 points each):
- "Improved performance significantly"
- "Reduced costs substantially"
- "Increased efficiency"
- "Enhanced user experience"

**Missing Specifics** (4 points each):
- Technologies listed without context
- Job titles without scope indicators
- Achievements without quantification
- Skills without demonstration

**Structural Patterns**:
- Objective statement instead of summary: 3 points
- References available upon request: 2 points
- >2 pages without senior experience: 3 points

#### FR6.11: Cover Letter Slop Patterns

Cover letters should demonstrate fit, not restate the CV.

**Generic Opening** (4 points each):
- "I am writing to apply for..."
- "I am excited to apply for..."
- "I was thrilled to see the opening for..."
- "I believe I am the perfect candidate..."

**CV Repetition** (3 points each):
- Restating job history without new insight
- Listing skills already on CV
- "As you can see from my resume..."

**Empty Claims** (4 points each):
- "I am a hard worker"
- "I learn quickly"
- "I am passionate about [company field]"
- Claims without supporting examples

**Weak Closing** (3 points each):
- "I look forward to hearing from you"
- "Thank you for your consideration"
- "Please feel free to contact me"
- No specific call to action

**Structural Patterns**:
- No company-specific content: 5 points
- No specific role alignment: 4 points
- >1 page: 3 points

### FR7: Dictionary Integration (Read-Only)

Use shared persistent dictionary for custom pattern matching.

**Dictionary Location**: `{workspace_root}/.slop-dictionary.json`

**Dictionary Schema (v2)** (implemented):

```json
{
  "version": "2.0",
  "last_modified": "2026-01-25T10:30:00Z",
  "patterns": {
    "leverage": {
      "pattern": "leverage",
      "category": "buzzword",
      "weight": 1.0,
      "count": 47,
      "timestamp": "2026-01-25T10:30:00Z",
      "source": "built-in",
      "exception": false
    }
  },
  "exceptions": {
    "robust": {
      "pattern": "robust",
      "scope": "permanent",
      "added": "2026-01-23T09:15:00Z",
      "reason": "Technical term in my domain"
    }
  },
  "calibration": {
    "samples_provided": 3,
    "baseline_ttr": 0.58,
    "baseline_hapax": 0.45,
    "baseline_sentence_sd": 12.3,
    "calibrated_at": "2026-01-20T16:00:00Z"
  }
}
```

**Behavior**:
- Read patterns from workspace dictionary (if exists)
- Merge with 150+ built-in patterns
- Respect exception list (patterns marked for skip)
- Weight affects scoring: `score = base_score * weight`
- Higher count patterns reported first in "Top Offenders"

**Note**: This skill reads from dictionary but does not write. Use `eliminating-ai-slop` to add patterns or exceptions.

**Acceptance Criteria**:
- [x] Load dictionary from `{workspace_root}/.slop-dictionary.json`
- [x] Merge built-in patterns with user-added
- [x] Respect exception list
- [x] Fall back to built-in if dictionary unavailable

### FR8: Detection Heuristics

Quick tests applied during analysis to identify AI writing patterns.

**Implemented Heuristics**:

| Heuristic | Description | Example |
|-----------|-------------|---------|
| Specificity Test | Does text name specific tools, versions, tradeoffs? | Slop: "Focus on clear communication" / Real: "Use Slack threads for async decisions" |
| Asymmetry Test | Does text commit to rankings or preferences? | Slop: "Both options have merits" / Real: "Use Postgres. SQLite if prototyping." |
| Constraint Test | Does text acknowledge costs, politics, messy reality? | Slop: "Adopt microservices" / Real: "Microservices add 3x ops overhead" |
| First-Person Test | Can you insert "in my experience" naturally? | Slop: Generic / Real: Grounded in context |
| Predictability Test | Can you predict next 3+ words? | Slop: "In today's fast-paced [world]..." / Real: "The deploy broke at 3am" |

### FR9: Calibration Mode

Allow users to calibrate thresholds using their own writing samples.

**Calibration Workflow**:
1. User provides 3-5 samples of authentic writing (300+ words each)
2. Skill calculates personal baselines for stylometric metrics
3. Baselines stored in dictionary calibration section
4. Future analysis uses personalized thresholds

**Calibration Output**:

```
Calibration Complete

Your Writing Profile:
├── Sentence length σ: 12.3 words (AI baseline: <15)
├── TTR range: 0.55-0.62 (AI baseline: <0.50)
├── Hapax rate: 45% (AI baseline: <40%)
└── Paragraph variance: High (characteristic of your style)

Adjusted Thresholds:
├── Sentence σ flag: <10 (personalized from your 12.3 baseline)
├── TTR flag: <0.52 (personalized from your 0.55 low)
└── Hapax flag: <42% (personalized from your 45% baseline)
```

### FR10: Metrics Commands

Provide visibility into detection statistics.

**Commands** (implemented):
- `"Show slop detection stats"` - Session and all-time statistics
- `"Export slop metrics"` - Export to `.slop-metrics.json`

**Metrics Output**:

```
Slop Detection Metrics

Session Stats:
├── Documents analyzed: 12
├── Total patterns found: 156
├── Average slop score: 43/100
└── Patterns by category:
    ├── Lexical: 89 (57%)
    ├── Structural: 34 (22%)
    ├── Semantic: 21 (13%)
    └── Stylometric: 12 (8%)

Top 5 Patterns (by frequency):
 1. "leverage" - 47 times
 2. "comprehensive" - 39 times
 3. "it's important to note" - 31 times
 ...
```

**Metrics Location**: `{workspace_root}/.slop-metrics.json`

## 4. Non-Functional Requirements

| Requirement | Target | Status |
|-------------|--------|--------|
| Analysis time | <5 seconds for 2000-word document | Implemented |
| Pattern accuracy | ≥90% of listed patterns detected | Implemented |
| False positive rate | <5% of flags confirmed incorrect | Target |

## 5. Out of Scope

**Handled by `eliminating-ai-slop` skill**:
- Rewriting or modifying text
- Adding/removing patterns from dictionary
- GVR loop (Generate-Verify-Refine)
- Background/automatic activation during prose generation

**Not Implemented**:
- Negative Constraint Injection (NCI) - aspirational feature
- Cloud-based dictionary sync - use git manually
- Multi-language support - US English only
- Machine learning inference - heuristic only

## 6. Dependencies

| Dependency | Location | Purpose |
|------------|----------|---------|
| Dictionary | `{workspace_root}/.slop-dictionary.json` | Custom patterns and exceptions |
| Metrics | `{workspace_root}/.slop-metrics.json` | Detection statistics |
| CLI tool | `scripts/slop-dictionary.js` | Dictionary management |
| Sync script | `scripts/slop-infrastructure.sh` | Cross-machine sync |

## 7. CLI Tools

### slop-dictionary.js

Command-line tool for dictionary management.

```bash
# Add pattern
node slop-dictionary.js add "synergize" buzzword

# Add exception
node slop-dictionary.js except "leverage" permanent

# List patterns
node slop-dictionary.js list [category]

# Show top patterns by frequency
node slop-dictionary.js top 10
```

### Cross-Machine Sync

Dictionary can be synchronized across machines using git:

```bash
slop-sync push    # Upload dictionary to GitHub
slop-sync pull    # Download latest dictionary
slop-sync status  # Show sync state
```

## 8. Related Skills

| Skill | Purpose | Relationship |
|-------|---------|--------------|
| `eliminating-ai-slop` | Active rewriting and dictionary mutations | Uses same dictionary; handles writes |
| `reviewing-ai-text` | (Deprecated) Original combined skill | Superseded by this skill |

---

*Implementation: [../skills/detecting-ai-slop/SKILL.md](../skills/detecting-ai-slop/SKILL.md)*
*Status: Implemented*
*Last Updated: 2026-02-08*


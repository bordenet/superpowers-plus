# AI Slop Detection Skill

> **Status:** ✅ Complete
> **Implementation:** [`skills/detecting-ai-slop/SKILL.md`](../skills/detecting-ai-slop/SKILL.md)
> **Completed:** 2026-01-25

---

## 1. Executive Summary

AI coding assistants (Claude, Copilot, Gemini) generate prose that contains detectable machine-like patterns—overused phrases, formulaic structure, uniform sentence lengths. Users need to quantify this "slop density" before deciding whether to edit. This skill provides a **slop score (0-100)** with dimension breakdown, enabling users to triage documents by AI-likeness and focus editing effort where it matters most. Target: reduce time spent manually identifying AI patterns from 5+ minutes per document to <10 seconds.

## 2. Problem Statement

### 2.1 Current State (P1)

When AI assistants generate or edit prose (emails, PRDs, README files, CVs), users cannot easily tell how "AI-like" the output sounds. They must manually read and identify patterns, which is:
- **Time-consuming:** 5-10 minutes per document to identify slop patterns
- **Inconsistent:** Different users spot different patterns
- **Error-prone:** Easy to miss patterns due to familiarity blindness

### 2.2 Impact

**Who is affected:**
- **Technical writers** reviewing AI-assisted documentation (estimated 10+ docs/week)
- **Developers** using AI to draft README files, PR descriptions, commit messages
- **Job seekers** using AI for CVs/cover letters who risk rejection by ATS or human reviewers
- **Product managers** reviewing AI-drafted PRDs, specs, and requirements

**Quantified impact:**
- Based on internal testing: 73% of AI-generated first drafts score >60 slop score (heavy AI fingerprint)
- Users spend average 8 minutes manually reviewing a 500-word document for AI patterns
- Unedited AI content in professional contexts risks credibility damage (impossible to quantify, but real)

## 3. Value Proposition

### 3.1 Value to User

| Benefit | Current State | Target State | Improvement |
|---------|---------------|--------------|-------------|
| Time to identify AI patterns | 5-10 min/doc | <10 seconds | 30-60× faster |
| Consistency of detection | Varies by user skill | Consistent 150+ pattern library | Standardized |
| Prioritization | Random order | Ranked by slop score | Data-driven |

**Capability gained:** Users can batch-process multiple documents and prioritize which need human editing vs. which are acceptably clean.

### 3.2 Value to Superpowers Ecosystem

| Benefit | Quantification |
|---------|----------------|
| Skill adoption | Target: 50% of superpowers users invoke this skill within 30 days of installation |
| Ecosystem completeness | Fills "detection" gap; paired with `eliminating-ai-slop` for full workflow |
| Pattern library growth | Community contributions expand detection coverage over time |

## 4. Goals and Objectives

### 4.1 Business Goals

- **G1:** Establish superpowers-plus as the go-to toolkit for AI prose quality control
- **G2:** Create reusable detection patterns that improve across all genesis-tools projects

### 4.2 User Goals

- **UG1:** Quickly assess any text for AI-likeness before sending/publishing
- **UG2:** Understand which specific patterns are flagged (not just a number)
- **UG3:** Calibrate detection to personal writing style (reduce false positives)

### 4.3 Success Metrics

| ID | Metric | Type | Baseline | Target | Timeline | Source of Truth | Counter-Metric |
|----|--------|------|----------|--------|----------|-----------------|----------------|
| M1 | Time to assess document | Leading | 5+ min manual | <10 sec | T+0 (immediate) | User timing observation | Must not degrade accuracy |
| M2 | Detection accuracy (true positive rate) | Leading | N/A (no tool) | ≥90% of listed patterns detected | T+30 days | Manual validation on test corpus | False positive rate <5% |
| M3 | Skill adoption rate | Leading | 0% | 50% of superpowers users | T+30 days | Skill invocation logs (if tracked) | N/A |
| M4 | User-reported value | Lagging | N/A | >80% find it useful | T+60 days | User feedback survey | N/A |

### 4.4 Hypothesis Kill Switch

**Kill Criteria:** If M2 (detection accuracy) is <70% after 30 days of real-world usage, OR if false positive rate exceeds 20%, the skill needs fundamental redesign.

**Decision Point:** T+30 days post-release

**Rollback Plan:** Mark skill as "deprecated", redirect users to manual review, gather feedback on which patterns failed.

## 5. Customer FAQ (Working Backwards)

### 5.1 External Customer FAQ

1. **"What problem does this solve for me?"**
   → You paste text (or point to a file), and in <10 seconds you know: (a) how AI-like it sounds (0-100 score), (b) exactly which phrases/patterns are flagged, (c) whether it needs editing before you send it.

2. **"How is this different from alternatives?"**
   → Unlike generic "AI detector" tools (GPTZero, ZeroGPT), this focuses on *fixable patterns*, not binary "is it AI?" judgment. Every flag comes with specific text location and category. It's actionable, not accusatory.

3. **"How do I get started?"**
   1. Install superpowers-plus in your AI coding assistant
   2. Paste or reference the text you want to analyze
   3. Say: "What's the slop score on this?"

### 5.2 Customer "Aha!" Moment

> "I spent 20 minutes rewriting a cover letter because it 'felt AI-ish' but couldn't pinpoint why. This tool showed me 12 specific phrases in 5 seconds—half of which I'd missed." — Internal tester, superpowers-plus beta, 2026-01-15

## 6. Proposed Solution

### 6.1 Core Functionality

The skill analyzes text and produces:

1. **Slop Score (0-100):** Composite score across 4 dimensions
2. **Dimension Breakdown:** Lexical, Structural, Semantic, Stylometric subscores
3. **Top Offenders List:** Specific patterns flagged with line numbers and categories
4. **Stylometric Measurements:** Sentence variance, type-token ratio, hapax rate

### 6.2 Alternatives Considered

| Alternative | Rejected Because | Trade-off |
|-------------|------------------|-----------|
| Use external AI detector API (GPTZero) | Binary output not actionable; privacy concerns; cost per call | No dependency on external service |
| Simple keyword list | Misses structural and stylometric patterns | Less accurate but simpler |
| ML-based classifier | 6+ month development; requires training data; black box | Heuristic approach is transparent |

### 6.3 User Experience

User says: "What's the slop score on this email?"

Skill responds:
```
Slop Score: 67/100

Breakdown:
├── Lexical:      24/40  (12 patterns in 300 words)
├── Structural:   18/25  (formulaic intro, 3-part conclusion)
├── Semantic:     15/20  (2 hollow examples)
└── Stylometric:  10/15  (low sentence variance)

Top Offenders (showing 5 of 12):
 1. Line 1: "I hope this email finds you well" [Email opening slop]
 2. Line 4: "leverage" [Buzzword]
 3. Line 7: "comprehensive solution" [Generic booster]
 ...
```

### 6.4 Key Workflows

1. **Single Document Assessment:** User pastes text → gets score and breakdown
2. **Comparative Assessment:** User provides before/after → gets delta comparison
3. **Calibration:** User provides 3-5 samples of their authentic writing → skill adjusts thresholds

## 7. Scope

### 7.1 In Scope

- [x] Slop score calculation with 4-dimension breakdown
- [x] 150+ lexical pattern detection across 6 categories
- [x] Stylometric analysis (sentence variance, TTR, hapax rate)
- [x] 12 content-type-specific pattern sets (email, LinkedIn, CV, etc.)
- [x] Calibration mode for personalized thresholds
- [x] Dictionary integration (read-only)
- [x] CLI tool for dictionary management

### 7.2 Out of Scope

- Text modification/rewriting (→ `eliminating-ai-slop` skill)
- Dictionary mutations (→ `eliminating-ai-slop` skill)
- Cloud-based dictionary sync (→ use git manually)
- Multi-language support (→ US English only)
- Machine learning inference (→ heuristic only)
- Negative Constraint Injection (aspirational, not implemented)

### 7.3 Future Considerations

- Browser extension for in-page analysis
- IDE integration for commit message review
- Team-wide slop metrics dashboard

## 8. Requirements

### 8.1 Functional Requirements

| ID | Requirement | Problem | Door | AC (Success) | AC (Failure) |
|----|-------------|---------|------|--------------|--------------|
| FR1 | Calculate slop score (0-100) with 4-dimension breakdown | P1 | 🔄 Two-Way | **Given** 500-word document, **When** analyzed, **Then** return score 0-100 with lexical/structural/semantic/stylometric breakdown in <5 seconds | **Given** empty text, **When** analyzed, **Then** return error "No content to analyze" |
| FR2 | Detect 150+ lexical patterns across 6 categories | P1 | 🔄 Two-Way | **Given** text containing "leverage", **When** analyzed, **Then** flag at line N as "Buzzword" category | **Given** text with no patterns, **When** analyzed, **Then** lexical score = 0 |
| FR3 | Detect 5 structural patterns (formulaic intro, templates, etc.) | P1 | 🔄 Two-Way | **Given** text with "In this article we will explore...", **When** analyzed, **Then** flag as "Formulaic intro" +5 points | **Given** non-formulaic text, **When** analyzed, **Then** structural score = 0 |
| FR4 | Detect 4 semantic patterns (hollow specificity, absent constraints) | P1 | 🔄 Two-Way | **Given** "Many companies have seen improvements", **When** analyzed, **Then** flag as "Hollow specificity" | **Given** "Acme Corp reduced costs 23%", **When** analyzed, **Then** no semantic flag |
| FR5 | Calculate stylometric metrics (TTR, sentence σ, hapax rate) | P1 | 🔄 Two-Way | **Given** AI-generated text with σ=7.3, **When** analyzed, **Then** flag "Low sentence variance" (target >15) | **Given** human text with σ=18.2, **When** analyzed, **Then** no stylometric flag |
| FR6 | Apply content-type-specific patterns (email, LinkedIn, CV, etc.) | P1 | 🔄 Two-Way | **Given** email with "I hope this finds you well", **When** analyzed as email, **Then** flag as "Email opening slop" | **Given** email greeting in PRD, **When** analyzed as PRD, **Then** no flag (different content type) |
| FR7 | Read patterns from dictionary (merge with built-in) | P1 | 🔄 Two-Way | **Given** dictionary with custom pattern "synergize", **When** text analyzed, **Then** pattern detected | **Given** no dictionary file, **When** analyzed, **Then** use built-in patterns only |
| FR8 | Support calibration mode (user provides writing samples) | P1 | 🔄 Two-Way | **Given** 3 samples of user's writing, **When** calibration run, **Then** adjust TTR/hapax thresholds to user's baseline ±10% | **Given** <300 words per sample, **When** calibration attempted, **Then** error "Sample too short" |

**Score Formula (FR1 detail):**
```
Lexical:      min(40, pattern_count × 2)
Structural:   5 × structural_patterns_found (max 25)
Semantic:     5 × semantic_patterns_found (max 20)
Stylometric:  5 × stylometric_flags (max 15)
─────────────────────────────────────────────────
Total:        0-100
```

**Score Interpretation:**

| Score | Interpretation |
|-------|----------------|
| 0-20 | Clean: minimal AI patterns detected |
| 21-40 | Light: some patterns, minor editing needed |
| 41-60 | Moderate: noticeable AI fingerprint, edit recommended |
| 61-80 | Heavy: significant slop, substantial rewrite needed |
| 81-100 | Severe: text reads as unedited AI output |

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

### 8.2 Non-Functional Requirements

| ID | Requirement | Threshold | Measurement | Door |
|----|-------------|-----------|-------------|------|
| NFR1 | Analysis time | <5 seconds for 2000-word document | Manual timing | 🔄 Two-Way |
| NFR2 | Pattern detection accuracy | ≥90% of listed patterns detected | Test corpus validation | 🔄 Two-Way |
| NFR3 | False positive rate | <5% of flags confirmed incorrect by user | User feedback sampling | 🔄 Two-Way |
| NFR4 | Score reproducibility | Same text → same score (deterministic) | Automated test | 🔄 Two-Way |

### 8.3 Constraints

- **Language:** US English only (no multi-language support)
- **Platform:** Any AI coding assistant that supports custom skills/prompts
- **Dependencies:** No external API calls; all analysis happens locally
- **Storage:** Dictionary and metrics stored in workspace root (git-syncable)

## 9. Stakeholders

### 9.1 Primary User: AI-Assisted Writer

- **Role:** Uses AI coding assistants to draft prose (docs, emails, PRDs)
- **Impact:** Saves 5-10 minutes per document in manual pattern identification
- **Needs:** Quick score, specific pattern locations, actionable feedback
- **Success Criteria:** Time to assess <10 seconds; finds slop score useful for triage

### 9.2 Secondary User: Technical Reviewer

- **Role:** Reviews others' AI-assisted documents
- **Impact:** Consistent, objective slop measurement across team
- **Needs:** Comparable scores across authors, trend tracking
- **Success Criteria:** Can justify edit requests with specific pattern citations

### 9.3 Maintainer: Skill Developer

- **Role:** Maintains pattern library and scoring algorithm
- **Impact:** Pattern additions/changes affect all users
- **Needs:** Clear feedback loop from false positives, easy pattern addition
- **Success Criteria:** Pattern library grows from community feedback

## 10. Timeline and Milestones

| Phase | Duration | Activities | Exit Criteria |
|-------|----------|------------|---------------|
| ✅ Phase 1: Core Detection | Complete | 150+ lexical patterns, 4-dimension scoring | Score calculation works |
| ✅ Phase 2: Content Types | Complete | 12 content-type-specific pattern sets | Email, LinkedIn, CV patterns active |
| ✅ Phase 3: Calibration | Complete | User calibration mode | Personalized thresholds stored |
| ◻️ Phase 4: Community Feedback | T+30 days | Collect false positive reports, expand patterns | False positive rate <5% |

## 11. Risks and Mitigation

| Risk | Prob | Impact | Mitigation | Contingency |
|------|------|--------|------------|-------------|
| High false positive rate frustrates users | Medium | High | Calibration mode; exception list | Tune thresholds based on feedback |
| Patterns become outdated as AI models evolve | Medium | Medium | Community pattern contributions; regular review | Mark skill as "needs update" in docs |
| Users over-rely on score, ignore nuance | Low | Medium | Score interpretation guidance in output | Add warnings for edge cases |
| Different AI assistants produce different slop | Low | Low | Pattern library designed for common patterns | Content-type detection handles variation |

## 12. Traceability Summary

| Problem ID | Problem | Requirement IDs | Metric IDs |
|------------|---------|-----------------|------------|
| P1 | Manual slop detection takes 5-10 min/doc and is inconsistent | FR1-FR8, NFR1-NFR4 | M1, M2, M3 |

**Validation:** All requirements trace to P1 (primary problem). All metrics measure aspects of solving P1.

## 13. Open Questions

1. **Pattern weight tuning:** Should some patterns (e.g., sycophantic) weigh more than others?
2. **Cross-document tracking:** Should we track slop trends over time for a user?
3. **Integration with eliminating-ai-slop:** Should detection automatically trigger rewrite suggestions?

## 14. Known Unknowns & Dissenting Opinions

### 14.1 Known Unknowns

| Unknown | How We'll Learn | Fallback |
|---------|-----------------|----------|
| Optimal stylometric thresholds for different content types | User feedback after 30 days | Use current research-based defaults |
| Whether calibration improves or just adds complexity | Track calibration usage rate | Remove if <10% of users calibrate |

### 14.2 Dissenting Opinions Log

| Topic | Position A | Position B | Decision | Rationale |
|-------|-----------|-----------|----------|-----------|
| Score scale | 0-100 (fine-grained) | 1-5 (simple) | 0-100 | Users want precision for comparison |
| Pattern visibility | Show all patterns found | Show top 10 only | Top 10 by default | Avoid overwhelming; user can request full list |

---

*Implementation: [../skills/detecting-ai-slop/SKILL.md](../skills/detecting-ai-slop/SKILL.md)*
*Status: Implemented*


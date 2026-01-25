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
| Email review | "Check this email before I send" | Score + email-specific flags |
| LinkedIn post check | "Is this post too sloppy?" | Score + engagement bait flags |
| SMS tone check | "Does this text sound too corporate?" | Formality mismatch flags |
| Teams message review | "Is this chat message appropriate?" | Register mismatch flags |

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

### FR6: Content-Type Detection

Identify the content type and apply type-specific slop patterns.

**Supported Content Types**:

| Type | Detection Triggers | Specific Patterns |
|------|-------------------|-------------------|
| Document | Default, .md files, long-form prose | All standard patterns |
| Email | "email", "subject:", signature blocks | Email-specific slop (FR6.1) |
| LinkedIn | "LinkedIn", "post", hashtag presence | Engagement bait patterns (FR6.2) |
| SMS | "text", "SMS", very short length | Formality mismatches (FR6.3) |
| Teams/Slack | "Teams", "Slack", "chat", "@mentions" | Chat register mismatches (FR6.4) |
| CLAUDE.md | "CLAUDE.md", agent instructions | Agent instruction slop (FR6.5) |
| README | "README", repository documentation | README-specific slop (FR6.6) |
| PRD | "PRD", "requirements", product spec | PRD-specific slop (FR6.7) |
| Design Doc | "design", "architecture", "spec" | Design doc slop (FR6.8) |
| Test Plan | "test plan", "test cases", "QA" | Test plan slop (FR6.9) |
| CV/Resume | "CV", "resume", "experience" | CV-specific slop (FR6.10) |
| Cover Letter | "cover letter", "application" | Cover letter slop (FR6.11) |

**Acceptance Criteria**:
- [ ] Auto-detect content type from context clues
- [ ] User can override: "Analyze this as an email"
- [ ] Apply type-specific patterns in addition to universal patterns
- [ ] Score weights adjusted per content type

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

Use shared persistent dictionary for pattern matching.

**Behavior**:
- Read patterns from workspace dictionary
- Do not modify dictionary (eliminating-ai-slop handles mutations)
- Fall back to built-in patterns if dictionary unavailable
- Content-type-specific patterns stored in separate dictionary sections

**Acceptance Criteria**:
- [ ] Load dictionary from workspace root
- [ ] Merge built-in patterns with user-added patterns
- [ ] Respect exception list (patterns marked "don't flag")
- [ ] Load content-type-specific patterns when relevant

### FR8: Metrics Contribution

Contribute detection metrics to shared tracking.

**Tracked Metrics**:
- Documents analyzed (count, by content type)
- Patterns detected (count, by category, by content type)
- Average bullshit factor (rolling, by content type)
- Highest-scoring patterns (frequency, by content type)
- Content type distribution (what types user analyzes most)

**Acceptance Criteria**:
- [ ] Increment counters after each analysis
- [ ] Metrics persist across sessions
- [ ] Metrics queryable: "Show detection stats"
- [ ] Metrics filterable by content type: "Show email slop stats"

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
  - Universal patterns section
  - Email patterns section
  - LinkedIn patterns section
  - SMS patterns section
  - Teams/Slack patterns section
- Shared metrics store (workspace root)
- Pattern definitions (built-in + dictionary)
- Content type detection heuristics

---

*Derived from Vision_PRD.md v2.0*
*Status: Draft*


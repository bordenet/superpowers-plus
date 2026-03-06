# Test Plan: AI Slop Detection and Elimination Skills

> **Guidelines:** See [CLAUDE.md](../CLAUDE.md) for writing standards.
> **Last Updated:** 2026-01-25
> **Status:** Revised for 13 content types
> **Author:** Matt J Bordenet

## Purpose

Validate that the two skills meet requirements across all 13 supported content types:
- **detecting-ai-slop**: Accurate slop score scoring with content-type-specific patterns
- **eliminating-ai-slop**: Effective rewriting with meaning preservation per content type

See [DESIGN.md](./DESIGN.md) for technical architecture.

---

## Test Strategy

### Approach

**Comprehensive validation across all content types:**

1. **Unit tests**: Synthetic inputs testing specific patterns per content type
2. **Content type detection tests**: Verify correct type identification
3. **Integration tests**: Shared dictionary and metrics with content type awareness
4. **Real-world validation**: User-provided documents across content types

### Validation Protocol

```
Phase 1: Content Type Detection
├── Run TC-CT001 through TC-CT013 (content type detection)
├── Verify each type correctly identified
└── Test override functionality

Phase 2: Universal Pattern Detection
├── Run TC-D001 through TC-D010 (universal patterns)
├── Verify detection independent of content type
└── Calibrate false positive rate

Phase 3: Content-Type-Specific Detection
├── Run TC-EMAIL through TC-COVER (type-specific tests)
├── Verify type-specific patterns detected only in correct context
└── Verify type-specific patterns don't over-flag other content types

Phase 4: Elimination Validation
├── Run TC-E001 through TC-E008 (core elimination)
├── Run TC-E-EMAIL through TC-E-COVER (type-specific rewriting)
├── User approves/rejects proposed rewrites
└── Evaluate rewrite quality per content type

Phase 5: Integration
├── Run TC-I001 through TC-I005 (shared infrastructure)
├── Verify content-type-specific dictionary sections
└── Verify metrics track by content type

Phase 6: Final Validation
├── Real documents across all 13 content types
├── Measure against success metrics
└── Document any refinements needed
```

### Success Metrics (from PRD)

| Metric | Target |
|--------|--------|
| Content type detection accuracy | ≥95% correct identification |
| Detection rate | ≥15 patterns per 1000 words for typical AI text |
| False positive rate (universal) | <5% of flags confirmed incorrect |
| False positive rate (type-specific) | <10% (some patterns are context-dependent) |
| Meaning preservation | <5% of rewrites change intended meaning |
| Type-appropriate rewrites | ≥90% of rewrites match content type register |

---

## Content Type Detection Tests (TC-CT###)

### TC-CT001: Email Detection

**Objective:** Verify content type detector identifies emails.

**Input:**
```
Subject: Q3 Budget Review

Hi Sarah,

I hope this email finds you well. I wanted to follow up on our discussion
about the Q3 budget allocations.

Best regards,
John
```

**Expected:** Content type = Email

**Pass criteria:** Email detected; email-specific patterns applied.

### TC-CT002: LinkedIn Detection

**Objective:** Verify content type detector identifies LinkedIn posts.

**Input:**
```
I'm thrilled to announce that after 5 years at Company X, I'm starting
a new chapter!

Here are 3 lessons I learned:

1. Always be learning
2. Network is everything
3. Take risks

Agree? 🚀

#career #growth #newbeginnings
```

**Expected:** Content type = LinkedIn

**Pass criteria:** LinkedIn detected; engagement bait patterns applied.

### TC-CT003: SMS Detection

**Objective:** Verify content type detector identifies SMS/text messages.

**Input:**
```
Hey can you pick up milk on the way home?
```

**Expected:** Content type = SMS

**Pass criteria:** SMS detected; formality-mismatch patterns applied.

### TC-CT004: Teams/Slack Detection

**Objective:** Verify content type detector identifies chat messages.

**Input:**
```
@sarah Hi! Hope you're doing well. Quick question - do you have the
latest version of the design doc? Let me know when you get a chance. Thanks!
```

**Expected:** Content type = Teams/Slack

**Pass criteria:** Teams/Slack detected; email-in-chat patterns applied.

### TC-CT005: CLAUDE.md Detection

**Objective:** Verify content type detector identifies agent instructions.

**Input:**
```
# CLAUDE.md

You are a helpful assistant. Be friendly and provide comprehensive assistance.
Always strive for excellence and maintain professional standards.
```

**Expected:** Content type = CLAUDE.md

**Pass criteria:** CLAUDE.md detected; vague instruction patterns applied.

### TC-CT006: README Detection

**Objective:** Verify content type detector identifies README files.

**Input:**
```
# MyProject

Welcome to MyProject! This is a powerful, robust, enterprise-grade solution
for all your needs.

## Features

- Incredibly fast
- Highly scalable
- Extremely reliable

## Installation

Coming soon!
```

**Expected:** Content type = README

**Pass criteria:** README detected; marketing-in-readme patterns applied.

### TC-CT007: PRD Detection

**Objective:** Verify content type detector identifies PRDs.

**Input:**
```
# Product Requirements Document

## Requirements

1. The system should be fast
2. Users should have a good experience
3. The interface should be intuitive

## Success Metrics

TBD
```

**Expected:** Content type = PRD

**Pass criteria:** PRD detected; vague requirements patterns applied.

### TC-CT008: Design Doc Detection

**Objective:** Verify content type detector identifies design documents.

**Input:**
```
# System Architecture

## Overview

The system will handle all user requests.

## Options

We could use approach A or approach B. There are several ways to implement this.

## Decision

To be determined.
```

**Expected:** Content type = Design Doc

**Pass criteria:** Design Doc detected; decision avoidance patterns applied.

### TC-CT009: Test Plan Detection

**Objective:** Verify content type detector identifies test plans.

**Input:**
```
# Test Plan

## Test Cases

1. Verify the system works correctly
2. Test all edge cases
3. Ensure comprehensive coverage

## Expected Results

The system should behave properly.
```

**Expected:** Content type = Test Plan

**Pass criteria:** Test Plan detected; vague test case patterns applied.

### TC-CT010: CV/Resume Detection

**Objective:** Verify content type detector identifies CVs/resumes.

**Input:**
```
JOHN DOE
Results-driven professional with excellent communication skills

EXPERIENCE

Senior Engineer, Company X (2020-Present)
- Responsible for designing systems
- Managed a team of engineers
- Worked on various projects

SKILLS
- Detail-oriented
- Self-starter
- Team player
```

**Expected:** Content type = CV/Resume

**Pass criteria:** CV detected; responsibility-vs-achievement patterns applied.

### TC-CT011: Cover Letter Detection

**Objective:** Verify content type detector identifies cover letters.

**Input:**
```
Dear Hiring Manager,

I am writing to apply for the Senior Engineer position at Company X.
I am excited about this opportunity and believe I am the perfect candidate.

I am a hard worker who learns quickly. I am passionate about technology.

Thank you for your consideration.

Sincerely,
John Doe
```

**Expected:** Content type = Cover Letter

**Pass criteria:** Cover Letter detected; generic opening patterns applied.

### TC-CT012: Content Type Override

**Objective:** Verify user can override detected content type.

**Input:**
```
User: "Analyze this as an email: [document that looks like README]"
```

**Expected:** Content type = Email (user override respected)

**Pass criteria:** User override takes precedence over auto-detection.

### TC-CT013: Document Fallback

**Objective:** Verify fallback to Document type when no specific type detected.

**Input:**
```
The quick brown fox jumps over the lazy dog. This is a sample paragraph
with no specific content type markers. It could be anything.
```

**Expected:** Content type = Document

**Pass criteria:** Falls back to Document; only universal patterns applied.

---

## Universal Detection Tests (TC-D###)

### TC-D001: Lexical Detection - Boosters

**Objective:** Verify detector flags booster phrases in any content type.

**Input:**
> "The incredibly powerful framework provides an extremely robust solution that is highly scalable and truly transformative for enterprise workflows."

**Expected output:**
```
Slop Score: ≥50/100
Lexical: ≥20/40 (≥7 patterns)
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

## Email-Specific Tests (TC-EMAIL###)

### TC-EMAIL001: Opening Slop Detection

**Input:**
> "I hope this email finds you well. I trust this message reaches you in good spirits. Hope you had a great weekend!"

**Expected:** 3 email-opening patterns flagged.

**Pass criteria:** All 3 patterns flagged; content type = Email.

### TC-EMAIL002: Follow-up Slop Detection

**Input:**
> "Per my last email, I wanted to circle back on this. Just following up on my previous message. Bumping this to the top of your inbox."

**Expected:** 4 follow-up patterns flagged.

**Pass criteria:** ≥3 of 4 patterns flagged.

### TC-EMAIL003: Closing Slop Detection

**Input:**
> "Please don't hesitate to reach out. Looking forward to hearing from you at your earliest convenience. Thanks in advance!"

**Expected:** 4 closing patterns flagged.

**Pass criteria:** ≥3 of 4 patterns flagged.

### TC-EMAIL004: Buried Lead Detection

**Input:**
> "[Paragraph 1: greeting and pleasantries]
> [Paragraph 2: background context]
> [Paragraph 3: more context]
> [Paragraph 4: The actual request - can you approve the budget?]"

**Expected:** Buried lead structural pattern flagged.

**Pass criteria:** Buried lead detected; suggestion to move to top.

### TC-EMAIL005: Email Patterns Not Applied to Non-Email

**Input:** Same email patterns in a README context.

**Expected:** Email-specific patterns NOT flagged (wrong content type).

**Pass criteria:** No email-specific patterns in Document/README context.

---

## LinkedIn-Specific Tests (TC-LINKEDIN###)

### TC-LINKEDIN001: Announcement Slop Detection

**Input:**
> "I'm thrilled to announce... I'm excited to share... I'm humbled to reveal..."

**Expected:** 3 announcement slop patterns flagged.

**Pass criteria:** All 3 patterns flagged.

### TC-LINKEDIN002: Engagement Bait Detection

**Input:**
> "Agree? Thoughts? Drop a 🔥 if this resonates! Tag someone who needs to see this."

**Expected:** 4 engagement bait patterns flagged.

**Pass criteria:** All 4 patterns flagged.

### TC-LINKEDIN003: Humble Brag Detection

**Input:**
> "I got rejected from Harvard... and here's what I learned. 5 years ago, I was broke. Today, I'm a CEO."

**Expected:** 2 humble brag patterns flagged.

**Pass criteria:** Both patterns flagged.

### TC-LINKEDIN004: Listicle Abuse Detection

**Input:**
> "7 lessons I learned from failing. 5 things nobody tells you about startups. Here's my framework for success."

**Expected:** 3 listicle abuse patterns flagged.

**Pass criteria:** All 3 patterns flagged.

### TC-LINKEDIN005: Structural - Line Breaks and Hashtags

**Input:**
> "This.
> Is.
> Important.
>
> Let me explain.
>
> #success #growth #mindset #leadership #motivation #entrepreneur #hustle #grind #blessed"

**Expected:** Excessive line breaks flagged; hashtag stuffing flagged.

**Pass criteria:** Both structural issues detected.

---

## SMS-Specific Tests (TC-SMS###)

### TC-SMS001: Formality Mismatch Detection

**Input:**
> "Dear John, I hope this message finds you well. I wanted to reach out regarding our upcoming meeting. Best regards, Sarah"

**Expected:** Formality mismatch patterns flagged (too formal for SMS).

**Pass criteria:** ≥3 formality patterns flagged.

### TC-SMS002: Overcommunication Detection

**Input:**
> "Just confirming we're meeting at 3. Let me know if that works. Thanks, Sarah. Looking forward to it. See you then!"

**Expected:** Overcommunication patterns flagged.

**Pass criteria:** Overcommunication detected; suggestion to consolidate.

### TC-SMS003: Appropriate Brevity Not Flagged

**Input:**
> "Running 5 min late"

**Expected:** No patterns flagged (appropriate for SMS).

**Pass criteria:** Score <10; no false positives.

---

## Teams/Slack-Specific Tests (TC-TEAMS###)

### TC-TEAMS001: Email-in-Chat Detection

**Input:**
> "Hi Sarah, hope you're doing well! I just wanted to reach out and see if you have a moment to discuss the project timeline. Please let me know when you're available. Thanks so much!"

**Expected:** Email-in-chat patterns flagged.

**Pass criteria:** ≥3 patterns flagged.

### TC-TEAMS002: Meeting Avoidance Slop

**Input:**
> "Can we hop on a quick call about this? Let's take this offline. I'll set up a meeting to discuss."

**Expected:** 3 meeting avoidance patterns flagged (for questions answerable in chat).

**Pass criteria:** All 3 patterns flagged.

### TC-TEAMS003: Passive Aggressive Detection

**Input:**
> "Per my last message... As I mentioned earlier... Just to clarify (again)..."

**Expected:** 3 passive aggressive patterns flagged.

**Pass criteria:** All 3 patterns flagged.

---

## CLAUDE.md-Specific Tests (TC-CLAUDE###)

### TC-CLAUDE001: Vague Instruction Detection

**Input:**
> "Be helpful and friendly. Provide comprehensive assistance. Strive for excellence."

**Expected:** 3 vague instruction patterns flagged.

**Pass criteria:** All 3 patterns flagged.

### TC-CLAUDE002: Meta-Commentary Detection

**Input:**
> "As an AI assistant, I am designed to help users. My purpose is to provide information."

**Expected:** Meta-commentary patterns flagged.

**Pass criteria:** ≥2 patterns flagged.

### TC-CLAUDE003: Unenforceable Rule Detection

**Input:**
> "Always be accurate. Never make mistakes. Ensure correctness at all times."

**Expected:** 3 unenforceable rule patterns flagged.

**Pass criteria:** All 3 patterns flagged.

---

## README-Specific Tests (TC-README###)

### TC-README001: Opening Slop Detection

**Input:**
> "Welcome to MyProject! This is a powerful, robust solution for all your needs."

**Expected:** Opening slop patterns flagged.

**Pass criteria:** ≥2 patterns flagged.

### TC-README002: Marketing Language Detection

**Input:**
> "Industry-leading performance. Best-in-class reliability. Enterprise-grade security. Production-ready and battle-tested."

**Expected:** 4 marketing patterns flagged.

**Pass criteria:** All 4 patterns flagged.

### TC-README003: Missing Substance Detection

**Input:**
> "## Installation
> Coming soon!
>
> ## Usage
> Check back later."

**Expected:** Missing substance patterns flagged.

**Pass criteria:** Missing substance detected.

---

## PRD-Specific Tests (TC-PRD###)

### TC-PRD001: Vague Requirements Detection

**Input:**
> "The system should be fast. Users should have a good experience. The interface should be intuitive."

**Expected:** 3 vague requirement patterns flagged.

**Pass criteria:** All 3 patterns flagged.

### TC-PRD002: Missing Acceptance Criteria Detection

**Input:**
> "Requirement: Implement user authentication."
> (No acceptance criteria provided)

**Expected:** Missing acceptance criteria flagged.

**Pass criteria:** Pattern detected; suggestion to add criteria.

### TC-PRD003: Scope Creep Signal Detection

**Input:**
> "Additionally, it would be nice if... Future consideration: we might also want to... And also, we could..."

**Expected:** 3 scope creep patterns flagged.

**Pass criteria:** All 3 patterns flagged.

---

## Design Doc-Specific Tests (TC-DESIGN###)

### TC-DESIGN001: Decision Avoidance Detection

**Input:**
> "We could use approach A or approach B. There are several options. This is left for future decision. TBD."

**Expected:** 4 decision avoidance patterns flagged.

**Pass criteria:** All 4 patterns flagged.

### TC-DESIGN002: Over-Abstraction Detection

**Input:**
> "The DataHandler will communicate with the ServiceManager which coordinates with the ProcessController."

**Expected:** Over-abstraction patterns flagged (generic component names).

**Pass criteria:** Pattern detected.

### TC-DESIGN003: Missing Context Detection

**Input:** Design doc with no "Alternatives Considered" or "Constraints" section.

**Expected:** Missing context patterns flagged.

**Pass criteria:** Both missing sections detected.

---

## Test Plan-Specific Tests (TC-TEST###)

### TC-TEST001: Vague Test Case Detection

**Input:**
> "Test Case 1: Verify the system works correctly.
> Test Case 2: Ensure performance is acceptable.
> Test Case 3: Test all edge cases."

**Expected:** 3 vague test case patterns flagged.

**Pass criteria:** All 3 patterns flagged.

### TC-TEST002: Coverage Theater Detection

**Input:**
> "We have achieved 100% code coverage. Comprehensive testing was performed."

**Expected:** Coverage theater patterns flagged.

**Pass criteria:** Both patterns flagged.

### TC-TEST003: Missing Expected Results Detection

**Input:**
> "Test: Click the button.
> Expected: Should behave properly."

**Expected:** Missing expected results pattern flagged.

**Pass criteria:** Pattern detected; suggestion to add specific expected result.

---

## CV-Specific Tests (TC-CV###)

### TC-CV001: Responsibility vs Achievement Detection

**Input:**
> "- Responsible for designing systems
> - Managed a team of 5 engineers
> - Worked on various projects
> - Participated in code reviews"

**Expected:** 4 responsibility patterns flagged.

**Pass criteria:** All 4 patterns flagged.

### TC-CV002: Buzzword Stuffing Detection

**Input:**
> "Results-driven professional. Dynamic team player. Self-starter with excellent communication skills. Detail-oriented and passionate about technology."

**Expected:** 5 buzzword patterns flagged.

**Pass criteria:** ≥4 of 5 patterns flagged.

### TC-CV003: Vague Metrics Detection

**Input:**
> "Improved performance significantly. Reduced costs substantially. Increased efficiency. Enhanced user experience."

**Expected:** 4 vague metric patterns flagged.

**Pass criteria:** All 4 patterns flagged.

---

## Cover Letter-Specific Tests (TC-COVER###)

### TC-COVER001: Generic Opening Detection

**Input:**
> "I am writing to apply for the position. I am excited about this opportunity. I believe I am the perfect candidate."

**Expected:** 3 generic opening patterns flagged.

**Pass criteria:** All 3 patterns flagged.

### TC-COVER002: CV Repetition Detection

**Input:**
> "As you can see from my resume, I have 5 years of experience. My resume shows my skills in..."

**Expected:** CV repetition patterns flagged.

**Pass criteria:** ≥2 patterns flagged.

### TC-COVER003: Empty Claims Detection

**Input:**
> "I am a hard worker. I learn quickly. I am passionate about this field."

**Expected:** 3 empty claim patterns flagged.

**Pass criteria:** All 3 patterns flagged.

### TC-COVER004: Weak Closing Detection

**Input:**
> "Thank you for your consideration. I look forward to hearing from you. Please feel free to contact me."

**Expected:** 3 weak closing patterns flagged.

**Pass criteria:** All 3 patterns flagged.

---

## Elimination Tests (TC-E###)

### TC-E001: Interactive Mode - Confirmation Prompt

**Objective:** Verify eliminator prompts before rewriting user-provided text.

**Input:**
> User: "Clean up this email: The incredibly powerful solution leverages cutting-edge technology."

**Expected behavior:**
1. Skill detects content type (Email or Document)
2. Skill detects 3+ patterns
3. Skill presents confirmation prompt with type-specific suggestions
4. Skill waits for user response

**Pass criteria:** Confirmation prompt displayed; no rewrite without approval.

### TC-E002: Interactive Mode - Batch Approval

**Input:**
> User: "Rephrase all"

**Expected behavior:** All flagged patterns rewritten using type-appropriate strategies.

**Pass criteria:** All patterns addressed; clean output returned.

### TC-E003: Interactive Mode - Selective Approval

**Input:**
> User: "Rephrase 1,3 but keep 2"

**Expected behavior:** Patterns 1 and 3 rewritten; pattern 2 preserved.

**Pass criteria:** Correct patterns rewritten; kept pattern unchanged.

### TC-E004: Automatic Mode - Email Generation

**Input:**
> User: "Write an email to the team about pushing the deadline back a week"

**Expected behavior:**
1. Skill detects content type = Email
2. Generates content without email slop
3. No "I hope this finds you well"
4. Lead with the key information (deadline change)
5. Reports summary

**Pass criteria:** Output contains no email slop; leads with the point.

### TC-E005: Automatic Mode - LinkedIn Generation

**Input:**
> User: "Write a LinkedIn post announcing our new product launch"

**Expected behavior:**
1. Skill detects content type = LinkedIn
2. Generates content without engagement bait
3. No "I'm thrilled to announce"
4. No "Agree?" at the end
5. Limited hashtags (≤3)

**Pass criteria:** Output contains no LinkedIn slop.

### TC-E006: Automatic Mode - README Generation

**Input:**
> User: "Create a README for a Python CLI tool that converts CSV to JSON"

**Expected behavior:**
1. Skill detects content type = README
2. No "Welcome to..." opening
3. Quickstart appears early
4. Installation has actual commands
5. No "coming soon" sections

**Pass criteria:** Output is actionable README with no marketing slop.

### TC-E007: Automatic Mode - Code Deactivation

**Input:**
> User: "Write a Python function to sort a list"

**Expected behavior:** Skill does not activate; code returned unchanged.

**Pass criteria:** No slop detection attempted; code output normal.

### TC-E008: Rewrite Quality - Meaning Preservation

**Input:**
> "The incredibly powerful database engine provides extremely fast query performance."

**Expected rewrite:**
> "The database engine returns query results in <10ms for typical workloads."

**Pass criteria:** Same core meaning; added specificity; no slop patterns.

---

## Type-Specific Elimination Tests (TC-E-TYPE###)

### TC-E-EMAIL: Email Rewriting

**Input:**
> "I hope this email finds you well. I wanted to follow up on our meeting. Please don't hesitate to reach out at your earliest convenience."

**Expected rewrite:**
> "Following up on our meeting: [direct request]. Let me know by Friday."

**Pass criteria:** Opening removed; closing simplified; deadline specified.

### TC-E-LINKEDIN: LinkedIn Rewriting

**Input:**
> "I'm thrilled to announce that I've just been promoted! Agree? 🚀🔥💪 #blessed #hustle #grind #success #leadership"

**Expected rewrite:**
> "Promoted to Senior Engineer at Company X. Looking forward to [specific goal]. #engineering"

**Pass criteria:** Announcement slop removed; engagement bait removed; hashtags reduced.

### TC-E-SMS: SMS Rewriting

**Input:**
> "Dear John, I hope this message finds you well. I wanted to inform you that I will be running approximately 10 minutes late. Best regards, Sarah"

**Expected rewrite:**
> "Running 10 min late"

**Pass criteria:** Formality removed; brevity achieved.

### TC-E-CV: CV Rewriting

**Input:**
> "Responsible for designing systems and managing a team. Improved performance significantly."

**Expected rewrite:**
> "Designed order processing system handling 10K orders/day. Led 5-person team to deliver on-time."

**Pass criteria:** Responsibilities → achievements; vague metrics → specific.

### TC-E-COVER: Cover Letter Rewriting

**Input:**
> "I am writing to apply for the position. I am a hard worker. Thank you for your consideration."

**Expected rewrite:**
> "[Company's recent product launch] caught my attention. At [Previous Company], I [specific achievement]. [Specific next step]."

**Pass criteria:** Generic opening → company hook; claims → examples; weak close → CTA.

---

## Integration Tests (TC-I###)

### TC-I001: Shared Dictionary - Content Type Patterns

**Objective:** Verify dictionary stores content-type-specific patterns.

**Procedure:**
1. Use eliminator to add pattern to email section: "kindly revert"
2. Analyze email containing "kindly revert" → flagged
3. Analyze README containing "kindly revert" → NOT flagged (wrong type)

**Pass criteria:** Pattern only flags in correct content type.

### TC-I002: Shared Dictionary - Content-Type Exception

**Objective:** Verify exceptions can be scoped to content type.

**Procedure:**
1. Add exception: "leverage" for PRD only
2. Analyze PRD with "leverage" → NOT flagged
3. Analyze email with "leverage" → flagged

**Pass criteria:** Exception respected only in specified content type.

### TC-I003: Metrics - Content Type Tracking

**Objective:** Verify metrics track by content type.

**Procedure:**
1. Detect 3 emails, 2 LinkedIn posts, 1 CV
2. Query metrics

**Expected:** Metrics show breakdown by content type.

**Pass criteria:** Content type counts accurate.

### TC-I004: Metrics - Type-Specific Pattern Tracking

**Objective:** Verify type-specific patterns tracked separately.

**Procedure:**
1. Detect email with email-opening-slop
2. Detect LinkedIn with engagement-bait
3. Query metrics

**Expected:** Metrics show "email-opening-slop: 1, linkedin-engagement-bait: 1"

**Pass criteria:** Type-specific categories tracked separately.

### TC-I005: Cross-Type False Positive Prevention

**Objective:** Verify type-specific patterns don't leak to other types.

**Procedure:**
1. Text contains "I hope this finds you well" (email pattern)
2. Analyze as LinkedIn post

**Expected:** Email pattern NOT flagged (wrong content type).

**Pass criteria:** No cross-type pattern leakage.

---

## Real-World Validation Protocol

### Phase 1: Detection Validation

**Procedure:**
1. User provides one document per content type (13 total)
2. Agent runs detecting-ai-slop on each
3. Agent reports slop score and all flagged patterns
4. User and agent jointly review each flag:
   - **True positive**: Correctly identified slop
   - **False positive**: Incorrectly flagged acceptable prose
   - **False negative**: Missed slop (user identifies)
5. Calculate accuracy per content type
6. Refine patterns as needed

**Deliverable:** Detection accuracy report by content type.

### Phase 2: Elimination Validation

**Procedure:**
1. Apply eliminating-ai-slop to each document
2. For each flagged pattern, user approves or rejects rewrite
3. Evaluate rewrite quality:
   - Meaning preserved?
   - Type-appropriate register?
   - Specificity increased?
4. Calculate rewrite quality per content type
5. Refine strategies as needed

**Deliverable:** Rewrite quality report by content type.

### Phase 3: Final Validation

**Procedure:**
1. Run full pipeline on fresh documents
2. Measure against success metrics
3. Document any remaining issues

**Success Criteria:**
- Content type detection ≥95% accurate
- Universal pattern detection ≥90% accurate
- Type-specific pattern detection ≥85% accurate
- False positive rate <5% (universal), <10% (type-specific)
- Meaning preservation ≥95%
- User review time <1 minute per page

---

## Execution Commands

```bash
# Install skills
./install.sh

# Load detector
node ~/.codex/superpowers-augment/superpowers-augment.js use-skill detecting-ai-slop

# Load eliminator
node ~/.codex/superpowers-augment/superpowers-augment.js use-skill eliminating-ai-slop

# Run detection with content type
"What's the slop score on this email: [paste text]"
"Score this LinkedIn post: [paste text]"
"Check this CV for AI patterns: [paste text]"

# Run elimination (interactive)
"Clean up this email: [paste text]"
"Remove the LinkedIn cringe from this: [paste text]"

# Run elimination (automatic)
"Write an email to the team about [topic]"
"Draft a LinkedIn post about [topic]"
"Create a README for [project]"
```

---

## Related Documents

- [CLAUDE.md](../CLAUDE.md) - Writing standards
- [TODO.md](../TODO.md) - Task tracking
- [Vision_PRD.md](./Vision_PRD.md) - High-level requirements
- [PRD_detecting-ai-slop.md](./PRD_detecting-ai-slop.md) - Detector requirements (FR6.1-6.11)
- [PRD_eliminating-ai-slop.md](./PRD_eliminating-ai-slop.md) - Eliminator requirements (FR4.1-4.11)
- [DESIGN.md](./DESIGN.md) - Technical design

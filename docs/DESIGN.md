# Design Document: AI Slop Detection and Elimination Skills

> **Guidelines:** See [CLAUDE.md](../CLAUDE.md) for writing standards.
> **Last Updated:** 2026-01-25
> **Status:** Revised for 13 content types
> **Author:** Matt J Bordenet

## Purpose

Technical design for two complementary skills:
- **detecting-ai-slop**: Read-only analysis producing bullshit factor scores
- **eliminating-ai-slop**: Active rewriting with interactive and automatic modes

Supports 13 content types with type-specific detection and rewriting.

See [Vision_PRD.md](./Vision_PRD.md) for high-level requirements.

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              USER WORKFLOWS                                  │
├─────────────────┬──────────────────────┬────────────────────────────────────┤
│ "Score this CV" │ "Clean up my email"  │ "Write a LinkedIn post"            │
│                 │                      │                                    │
│   ▼             │        ▼             │           ▼                        │
│ DETECTOR        │    ELIMINATOR        │      ELIMINATOR                    │
│ (read-only)     │  (interactive)       │     (automatic)                    │
└────────┬────────┴──────────┬───────────┴────────────┬───────────────────────┘
         │                   │                        │
         ▼                   ▼                        ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                       CONTENT TYPE DETECTION                                 │
│  ┌──────────────────────────────────────────────────────────────────────┐   │
│  │ Detects: Document | Email | LinkedIn | SMS | Teams | CLAUDE.md |     │   │
│  │          README | PRD | Design Doc | Test Plan | CV | Cover Letter  │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
└────────────────────────────────┬────────────────────────────────────────────┘
                                 │
                                 ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                        SHARED INFRASTRUCTURE                                 │
│  ┌────────────────────────┐  ┌──────────────────────┐                       │
│  │ Pattern Dictionary     │  │ Metrics Store        │                       │
│  │ - Universal patterns   │  │ - By content type    │                       │
│  │ - Type-specific        │  │ - By category        │                       │
│  │ (workspace root)       │  │ (workspace root)     │                       │
│  └────────────────────────┘  └──────────────────────┘                       │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Content Type Detection

### Detection Algorithm

```
1. Check explicit user declaration: "Analyze this as an email"
2. Check filename patterns: README.md, CLAUDE.md, *.test.md
3. Check content markers:
   - Email: "Subject:", signature blocks, "Dear", "Regards"
   - LinkedIn: hashtags, "I'm thrilled", engagement bait endings
   - SMS: very short (<100 words), conversational register
   - Teams/Slack: @mentions, thread references
   - CLAUDE.md: "You are", agent instruction patterns
   - README: "## Installation", "## Usage", badge patterns
   - PRD: "## Requirements", "acceptance criteria", "user stories"
   - Design Doc: "## Architecture", "## Alternatives Considered"
   - Test Plan: "## Test Cases", "Given/When/Then"
   - CV: "Experience", "Education", "Skills" sections
   - Cover Letter: "Dear Hiring Manager", application language
4. Default: Document (general prose)
```

### Content Type Table

| Content Type | Detection Triggers | Pattern Set |
|--------------|-------------------|-------------|
| Document | Default | Universal only |
| Email | "email", "Subject:", signatures | Universal + Email (FR6.1) |
| LinkedIn | "#", engagement endings, "I'm thrilled" | Universal + LinkedIn (FR6.2) |
| SMS | Length <100 words, "text message" | Universal + SMS (FR6.3) |
| Teams/Slack | "@", "Teams", "Slack", "chat" | Universal + Teams (FR6.4) |
| CLAUDE.md | Filename, "You are", instruction patterns | Universal + Agent (FR6.5) |
| README | Filename, "## Installation" | Universal + README (FR6.6) |
| PRD | "requirements", "acceptance criteria" | Universal + PRD (FR6.7) |
| Design Doc | "architecture", "alternatives considered" | Universal + Design (FR6.8) |
| Test Plan | "test cases", "Given/When/Then" | Universal + Test (FR6.9) |
| CV/Resume | "Experience", "Education", "Skills" | Universal + CV (FR6.10) |
| Cover Letter | "Dear Hiring Manager", application tone | Universal + Cover (FR6.11) |

---

## Skill 1: detecting-ai-slop

### Purpose

Analyze text and produce a bullshit factor score (0-100) with detailed breakdown, applying content-type-specific patterns.

### Invocation

```
User: "What's the bullshit factor on this CV?"
User: "Score this email draft for AI patterns"
User: "How much slop is in this README?"
User: "Check this LinkedIn post before I publish"
```

### Output Format

```
Content Type Detected: Email

Bullshit Factor: 58/100

Breakdown:
├── Lexical:      18/40  (9 patterns in 200 words)
├── Structural:   15/25  (buried lead, wall of text)
├── Semantic:     10/20  (2 hollow promises)
├── Stylometric:   5/15  (moderate sentence variance)
└── Type-Specific: 10/-- (email-specific patterns)

Universal Patterns (showing 5 of 9):
 1. Line 3: "incredibly important" [Generic booster]
 2. Line 7: "comprehensive solution" [Buzzword]
 3. Line 12: "it's worth noting" [Filler phrase]
 ...

Email-Specific Patterns (showing 5 of 6):
 1. Line 1: "I hope this email finds you well" [Opening slop]
 2. Line 5: "Per my last email" [Follow-up slop]
 3. Line 15: "Please don't hesitate to reach out" [Closing slop]
 4. Line 18: "At your earliest convenience" [Closing slop]
 5. Structural: Key request buried in paragraph 4 [Buried lead]
 ...

Stylometric Measurements:
├── Sentence length SD: 8.3 words (acceptable)
├── Type-token ratio: 0.52 (acceptable)
└── Hapax rate: 42% (acceptable)
```

### Scoring Algorithm

| Dimension | Max Points | Calculation |
|-----------|------------|-------------|
| Lexical | 40 | `min(40, universal_pattern_count * 2)` |
| Structural | 25 | `5 * structural_patterns_found` |
| Semantic | 20 | `5 * semantic_patterns_found` |
| Stylometric | 15 | `5 * stylometric_flags` |
| Type-Specific | Additive | Patterns from content type (see PRD §FR6) |

**Total:** Sum of dimensions, capped at 100.

**Type-Specific Weighting:** Content-type patterns add to the score but are reported separately for transparency.

### Detection Logic

1. **Detect content type** (algorithm above)
2. **Apply universal patterns** (100+ phrases across 5 categories)
3. **Apply type-specific patterns** (see PRD_detecting-ai-slop.md §FR6.1-6.11)
4. **Calculate stylometric metrics** (sentence variance, TTR, hapax rate)
5. **Compute composite score**
6. **Generate report**

### Pattern Categories (Universal)

| Category | Pattern Count | Examples |
|----------|---------------|----------|
| Generic Boosters | 30+ | incredibly, extremely, highly, truly |
| Buzzwords | 25+ | leverage, robust, seamless, empower |
| Filler Phrases | 25+ | it's important to note, let's dive in |
| Hedge Patterns | 15+ | of course, naturally, generally speaking |
| Sycophantic | 15+ | great question, happy to help |

### Pattern Categories (Type-Specific)

| Content Type | Categories | Pattern Count |
|--------------|------------|---------------|
| Email | Opening, Follow-up, Closing, Corporate filler | 35+ |
| LinkedIn | Announcement, Engagement bait, Humble brag, Listicle | 25+ |
| SMS | Formality mismatch, Overcommunication | 10+ |
| Teams/Slack | Email-in-chat, Meeting avoidance, Passive aggressive | 15+ |
| CLAUDE.md | Vague instructions, Meta-commentary, Unenforceable rules | 12+ |
| README | Opening slop, Marketing, Missing substance | 15+ |
| PRD | Vague requirements, Scope creep, Missing specificity | 15+ |
| Design Doc | Decision avoidance, Over-abstraction, Missing context | 15+ |
| Test Plan | Vague tests, Coverage theater, Missing traceability | 12+ |
| CV/Resume | Responsibility vs achievement, Buzzword stuffing, Vague metrics | 15+ |
| Cover Letter | Generic opening, CV repetition, Empty claims, Weak closing | 15+ |

---

## Skill 2: eliminating-ai-slop

### Purpose

Actively rewrite text to eliminate detected slop patterns, applying content-type-specific rewriting strategies.

### Mode 1: Interactive Rewriting

**Trigger:** User provides existing text with edit/review request.

```
User: "Clean up this email: [text]"
User: "Remove the LinkedIn cringe from this post: [text]"
User: "Make my cover letter less generic: [text]"
```

**Workflow:**
1. Detect content type
2. Detect patterns (universal + type-specific)
3. Present findings with content-type-aware suggestions
4. User approves/rejects
5. Apply approved rewrites using type-specific strategies

**Confirmation Prompt Format (Email Example):**
```
Content Type: Email

Found 7 slop patterns:

Universal (3):
1. "incredibly important" [Generic booster]
   → Suggest: specify what makes it important

2. "comprehensive solution" [Buzzword]
   → Suggest: describe what it actually covers

3. "it's worth noting" [Filler phrase]
   → Suggest: delete, state the point directly

Email-Specific (4):
4. "I hope this email finds you well" [Opening slop]
   → Suggest: delete, or use specific context: "Following up on Tuesday's meeting"

5. "Please don't hesitate to reach out" [Closing slop]
   → Suggest: "Let me know" or delete

6. Key request in paragraph 4 [Buried lead]
   → Suggest: move to first paragraph

7. Wall of text (no breaks in 250 words) [Structure]
   → Suggest: add paragraph breaks, use bullets for list items

Options:
- "Rephrase all" - I'll rewrite all 7
- "Keep all" - Leave text unchanged
- "List them" - I'll ask about each one
- "Rephrase 1,4,6" - Rewrite specific patterns
```

### Mode 2: Automatic Prevention

**Trigger:** User requests content generation.

```
User: "Write an email to the team about the deadline change"
User: "Draft a LinkedIn post about our product launch"
User: "Create a README for this project"
```

**Behavior:**
1. Detect requested content type from prompt
2. Generate content
3. Apply type-specific slop prevention during generation
4. Return clean output
5. Report summary

**Example Summary:**
```
[Content type: LinkedIn | Slop prevention: removed 6 patterns]
  - 2 announcement slop ("I'm thrilled to announce" → direct statement)
  - 1 engagement bait ("Agree?" → removed)
  - 2 excessive line breaks (consolidated)
  - 1 hashtag stuffing (reduced to 3 relevant hashtags)
```

### Activation Control

| Context | Content Type | Activation |
|---------|--------------|------------|
| "Write an email..." | Email | Auto-activate with email patterns |
| "Draft a LinkedIn post..." | LinkedIn | Auto-activate with LinkedIn patterns |
| "Create a README..." | README | Auto-activate with README patterns |
| "Write requirements for..." | PRD | Auto-activate with PRD patterns |
| "Help me with my resume..." | CV | Auto-activate with CV patterns |
| Code generation | None | Auto-deactivate |
| JSON, YAML, config | None | Auto-deactivate |
| "disable slop detection" | Any | Manual deactivate |

### Rewriting Strategies by Content Type

| Content Type | Key Strategy | Example Transformation |
|--------------|--------------|------------------------|
| Email | Lead with the ask | Move action request to first sentence |
| LinkedIn | Remove engagement bait | "Agree?" → (deleted) |
| SMS | Match conversational register | "Dear John" → "Hey" |
| Teams/Slack | Combine greeting + question | "Hi! Quick question..." → "@name: [question]" |
| CLAUDE.md | Make rules actionable | "Be helpful" → "Respond within 2 sentences" |
| README | Quickstart first | Move installation above features |
| PRD | Add acceptance criteria | "Fast" → "<200ms at p95" |
| Design Doc | Recommend, don't equivocate | "X or Y" → "X because [rationale]" |
| Test Plan | Add expected results | "Verify works" → "Given X, when Y, then Z" |
| CV | Achievements over duties | "Responsible for..." → "Delivered X, resulting in Y" |
| Cover Letter | Company-specific hook | "I am writing to apply..." → "[Company insight] drew me to..." |

---

## Shared Infrastructure

### Pattern Dictionary

**Location:** `{workspace_root}/.slop-dictionary.json`

**Format (updated for content types):**
```json
{
  "version": "2.0",
  "universal_patterns": [
    {
      "phrase": "incredibly",
      "category": "generic-booster",
      "count": 47,
      "added": "2026-01-24",
      "source": "built-in"
    }
  ],
  "content_type_patterns": {
    "email": [
      {
        "phrase": "I hope this email finds you well",
        "category": "opening-slop",
        "count": 12,
        "added": "2026-01-25",
        "source": "built-in"
      }
    ],
    "linkedin": [...],
    "sms": [...],
    "teams": [...],
    "claude-md": [...],
    "readme": [...],
    "prd": [...],
    "design-doc": [...],
    "test-plan": [...],
    "cv": [...],
    "cover-letter": [...]
  },
  "exceptions": [
    {
      "phrase": "leverage",
      "scope": "permanent",
      "content_type": "all",
      "added": "2026-01-25"
    },
    {
      "phrase": "I hope this finds you well",
      "scope": "permanent",
      "content_type": "email",
      "reason": "Required by company policy",
      "added": "2026-01-25"
    }
  ]
}
```

**Behavior:**
- Detector reads dictionary, does not write
- Eliminator reads and writes dictionary
- Both fall back to built-in patterns if dictionary missing
- Auto-add to .gitignore if git repo detected
- Content-type-scoped exceptions supported

### Metrics Store

**Location:** `{workspace_root}/.slop-metrics.json`

**Format (updated for content types):**
```json
{
  "version": "2.0",
  "detection": {
    "total_documents": 42,
    "by_content_type": {
      "email": 15,
      "linkedin": 8,
      "cv": 5,
      "document": 14
    },
    "total_patterns_found": 387,
    "by_category": {
      "generic-booster": 89,
      "buzzword": 67,
      "filler-phrase": 112,
      "email-opening-slop": 23,
      "linkedin-engagement-bait": 18
    },
    "average_bullshit_factor": {
      "overall": 58.3,
      "by_content_type": {
        "email": 42.1,
        "linkedin": 61.5,
        "cv": 55.8
      }
    }
  },
  "elimination": {
    "total_documents": 31,
    "by_content_type": {
      "email": 12,
      "linkedin": 7,
      "cv": 4,
      "document": 8
    },
    "patterns_fixed": 298,
    "by_content_type": {
      "email": 89,
      "linkedin": 56,
      "cv": 41
    },
    "user_kept": 23,
    "false_positives_reported": 5,
    "average_length_reduction": {
      "email": "18%",
      "linkedin": "12%",
      "sms": "35%"
    }
  }
}
```

---

## Design Decisions

### D1: Two Skills vs. One

**Decision:** Two separate skills.

**Rationale:**
- Distinct use cases (score external docs, clean my drafts, prevent during generation)
- Detector is read-only; eliminator mutates
- User can invoke just what they need
- Each skill stays focused

### D2: Content Type Detection First

**Decision:** Detect content type before pattern matching.

**Rationale:**
- Different content types have different slop patterns
- Email "slop" differs from LinkedIn "slop"
- Enables type-specific rewriting strategies
- User can override if detection is wrong

### D3: Universal + Type-Specific Patterns

**Decision:** Always apply universal patterns; add type-specific patterns based on detected type.

**Rationale:**
- Universal patterns (boosters, buzzwords) apply everywhere
- Type-specific patterns catch context-specific issues
- Layered approach maximizes detection without over-flagging

### D4: Scoring Transparency

**Decision:** Report universal and type-specific patterns separately.

**Rationale:**
- User understands what was flagged and why
- Type-specific flags may have different weight
- Enables user to calibrate per content type

### D5: Type-Specific Rewriting Strategies

**Decision:** Each content type has tailored rewriting guidance.

**Rationale:**
- "Lead with the ask" applies to email, not LinkedIn
- "Remove engagement bait" applies to LinkedIn, not email
- Context-aware rewriting produces better results

### D6: Content-Type-Scoped Exceptions

**Decision:** Exceptions can be universal or content-type-specific.

**Rationale:**
- "leverage" might be slop in general but acceptable in specific contexts
- Company policy might require certain phrases in email
- Flexibility without losing protection

---

## Implementation Notes

### Pattern Embedding

Both skills embed all patterns directly in SKILL.md:
- Universal patterns (100+)
- All 11 type-specific pattern sets (200+ additional)
- Total: 300+ patterns

**Maintenance:** When updating patterns, update both skills.

### Content Type Detection Priority

1. Explicit user declaration (highest)
2. Filename patterns
3. Content markers
4. Default: Document (lowest)

### Rewriting Safety

For content-type-specific rewrites:
- Preserve core meaning
- Apply type-appropriate register
- When uncertain, flag but don't auto-rewrite
- Track "changed my meaning" feedback per content type

---

## Related Documents

- [CLAUDE.md](../CLAUDE.md) - Writing standards
- [TODO.md](../TODO.md) - Task tracking
- [Vision_PRD.md](./Vision_PRD.md) - High-level requirements
- [PRD_detecting-ai-slop.md](./PRD_detecting-ai-slop.md) - Detector requirements (FR6.1-6.11)
- [PRD_eliminating-ai-slop.md](./PRD_eliminating-ai-slop.md) - Eliminator requirements (FR4.1-4.11)
- [TEST_PLAN.md](./TEST_PLAN.md) - Test plan

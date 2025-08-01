# PRD: eliminating-ai-slop Skill

> **Parent Document**: [Vision_PRD.md](./Vision_PRD.md)
> **Sibling Document**: [PRD_detecting-ai-slop.md](./PRD_detecting-ai-slop.md)
> **Guidelines**: [CLAUDE.md](../CLAUDE.md)

## 1. Purpose

Actively eliminate AI slop patterns through rewriting. Operates in two modes: interactive (user-provided text with confirmation prompts) and automatic (background prevention during generation).

## 2. Use Cases

| Use Case | Mode | Example | Output |
|----------|------|---------|--------|
| Clean up my draft | Interactive | "Rewrite this paragraph to remove slop" | Cleaned text with confirmation |
| Direct cleanup | Interactive | "Remove the AI patterns from this" | Cleaned text |
| Background prevention | Automatic | User requests blog post | Slop-free first draft |
| Daily workflow | Automatic | Any prose generation | Clean output by default |
| Email composition | Automatic | "Write an email to X about Y" | Direct, slop-free email |
| Email cleanup | Interactive | "Clean up this email draft" | Email with corporate filler removed |
| LinkedIn post | Automatic | "Write a LinkedIn post about X" | Post without engagement bait |
| LinkedIn cleanup | Interactive | "Make this post less cringe" | Humble brags and bait removed |
| SMS composition | Automatic | "Text my coworker about X" | Conversational, appropriately brief |
| Teams message | Automatic | "Message the team about X" | Direct, no email formality |
| CLAUDE.md | Automatic | "Write agent instructions for X" | Actionable, specific rules |
| README | Automatic | "Write a README for X" | Scannable, quickstart-first |
| PRD | Automatic | "Write requirements for X" | Measurable, prioritized |
| Design doc | Automatic | "Write a design for X" | Decision-focused, alternatives included |
| Test plan | Automatic | "Write test cases for X" | Executable, traceable |
| CV/Resume | Automatic | "Write a resume for X" | Achievement-focused, quantified |
| Cover letter | Automatic | "Write a cover letter for X" | Company-specific, demonstrates fit |

## 3. Functional Requirements

### FR1: Interactive Rewriting Mode

When user provides existing text, propose changes with confirmation.

**Trigger Conditions** (from Vision_PRD §6.1 FR10):
- User provides text with edit request: "Edit this paragraph: [text]"
- User provides text with review request: "Clean up this draft: [text]"
- User pastes text with processing instruction

**Workflow**:
1. Detect slop patterns in provided text (uses detection logic)
2. For each pattern, ask: "I found '[pattern]' ([category]). Rephrase or keep?"
3. User responds: Rephrase / Keep / Never flag
4. Batch option: "I found N patterns. Rephrase all, keep all, or list them?"

**Acceptance Criteria**:
- [ ] Distinguish between generation and processing requests
- [ ] Confirmation prompt identifies pattern and category
- [ ] User can respond individually or batch
- [ ] Temporary exceptions persist for current document
- [ ] Permanent exceptions persist to dictionary
- [ ] Safe default: flag but don't rewrite if user doesn't respond

### FR2: Automatic Prevention Mode

During prose generation, eliminate slop before returning output.

**Behavior** (from Vision_PRD §6.1 FR5):
- Analyze output during generation
- Identify slop patterns across all dimensions
- Rewrite flagged content automatically
- Return clean output to user

**Acceptance Criteria**:
- [ ] Rewrites preserve semantic meaning
- [ ] Rewrites increase specificity where hollow
- [ ] Rewrites vary structure where uniform
- [ ] User receives slop-free output without intervention
- [ ] Original pre-rewrite content available on request

### FR3: Activation Control

Automatically activate for prose, deactivate for code.

**Activation Triggers** (from Vision_PRD §6.1 FR9):
- Blog posts, wiki articles, READMEs, documentation
- Email composition or cleanup requests
- LinkedIn post composition or cleanup
- SMS/text message composition
- Teams/Slack message composition
- Any user prompt requesting prose content

**Deactivation Triggers**:
- Code blocks (Python, JavaScript, SQL, etc.)
- Configuration files (JSON, YAML, TOML)
- Shell commands, structured data

**Manual Override**:
- "Disable slop detection for this response"
- "Enable slop detection"
- "Disable [category] detection"
- "Write this formally" (disables formality-mismatch detection)

**Acceptance Criteria**:
- [ ] Auto-activate for prose contexts
- [ ] Auto-deactivate for code contexts
- [ ] Detect content type and apply appropriate pattern set
- [ ] Manual override respected
- [ ] Override resets at conversation start (unless persistence specified)

### FR4: Content-Type-Specific Rewriting

Apply different rewriting strategies based on content type.

#### FR4.1: Email Rewriting

**Rewriting Principles**:
- Lead with the ask or key information
- Remove unnecessary pleasantries
- Preserve professional tone without corporate filler
- Keep emails scannable (short paragraphs, bullet points for lists)

**Replacement Strategies**:

| Slop Pattern | Replacement Strategy |
|--------------|---------------------|
| "I hope this email finds you well" | Delete, or replace with specific context: "Following up on yesterday's meeting" |
| "Per my last email" | Reference the specific point: "Regarding the budget question" |
| "Please don't hesitate to reach out" | "Let me know" or delete entirely |
| "Just wanted to follow up" | "Following up:" + direct question |
| "At your earliest convenience" | Specific deadline: "by Friday" or "when you have 5 minutes" |
| Buried lead | Move key request to first paragraph |
| Passive voice requests | Active voice: "Could you review..." not "It would be appreciated if..." |

**Structural Rewrites**:
- Move action items to the top
- Add TL;DR for emails >200 words
- Convert long paragraphs to bullet points
- Remove redundant sign-offs

**Acceptance Criteria**:
- [ ] Detect email context from prompt or content
- [ ] Apply email-specific replacements
- [ ] Preserve original meaning and professional tone
- [ ] Result is shorter than input (when slop is removed)

#### FR4.2: LinkedIn Rewriting

**Rewriting Principles**:
- Remove engagement bait endings
- Convert humble brags to direct statements
- Reduce excessive formatting (line breaks, emojis)
- Preserve authentic voice while removing performative elements

**Replacement Strategies**:

| Slop Pattern | Replacement Strategy |
|--------------|---------------------|
| "I'm thrilled to announce" | Direct statement: "We launched X" |
| "Agree?" / "Thoughts?" | Delete, or convert to genuine question with context |
| "X lessons I learned" | Reframe as direct advice without the listicle wrapper |
| "I got rejected... here's what I learned" | Direct insight without the narrative setup |
| Excessive line breaks | Normal paragraph structure |
| Hashtag stuffing | 2-3 relevant hashtags maximum |

**Structural Rewrites**:
- Consolidate single-sentence lines into paragraphs
- Remove performative vulnerability setups
- Reduce emoji count to ≤1 per 100 words
- Convert engagement bait to genuine calls to action (or delete)

**Acceptance Criteria**:
- [ ] Detect LinkedIn context from prompt or hashtag presence
- [ ] Remove engagement bait while preserving core message
- [ ] Reduce formatting abuse
- [ ] Result reads as authentic professional communication

#### FR4.3: SMS Rewriting

**Rewriting Principles**:
- Match conversational register
- Prioritize brevity
- Remove unnecessary formality
- Get to the point immediately

**Replacement Strategies**:

| Slop Pattern | Replacement Strategy |
|--------------|---------------------|
| "Dear [Name]" | Delete or use first name only |
| "I hope this message finds you" | Delete |
| "Best regards" | Delete or use casual sign-off |
| Multi-paragraph messages | Consolidate to essential information |
| "I wanted to reach out" | Direct statement: "Hey, [request]" |

**Structural Rewrites**:
- Reduce to single paragraph when possible
- Remove sign-offs (sender is known)
- Consolidate multiple sentences into one when meaning preserved

**Acceptance Criteria**:
- [ ] Detect SMS context from prompt or message length
- [ ] Apply conversational register
- [ ] Result is ≤50 words when original intent allows
- [ ] Preserve urgency/tone markers when present

#### FR4.4: Teams/Slack Chat Rewriting

**Rewriting Principles**:
- Direct and immediate
- No email formality
- Context-appropriate terseness
- Actionable messages

**Replacement Strategies**:

| Slop Pattern | Replacement Strategy |
|--------------|---------------------|
| "Hi [Name], hope you're well. Quick question..." | "@Name: [question]" |
| "Per my last message" | Direct reference: "Re: the deadline" |
| "Can we hop on a quick call?" | Ask the question directly in chat |
| "Let's take this offline" | Continue in thread or DM |
| Long-form paragraphs | Bullet points or threaded messages |

**Structural Rewrites**:
- Combine greeting + question into single message
- Use threads for multi-part discussions
- Add context when @mentioning
- Remove unnecessary acknowledgments

**Acceptance Criteria**:
- [ ] Detect chat context from prompt or platform mention
- [ ] Apply chat-appropriate register
- [ ] Result is direct and actionable
- [ ] Preserve urgency signals and @mentions

#### FR4.5: CLAUDE.md / Agent Instruction Rewriting

**Rewriting Principles**:
- Every rule should be actionable and verifiable
- Include examples for non-obvious rules
- Remove meta-commentary about being an AI
- Make instructions specific to the use case

**Replacement Strategies**:

| Slop Pattern | Replacement Strategy |
|--------------|---------------------|
| "Be helpful and friendly" | Specific behavior: "Greet users by name when known" |
| "Ensure high-quality outputs" | Measurable: "All code must include error handling" |
| "As an AI assistant, I..." | Delete or rephrase as instruction |
| "Always be accurate" | Specific: "Verify dates against provided sources" |

**Structural Rewrites**:
- Add examples after abstract rules
- Remove redundant capability descriptions
- Consolidate overlapping instructions
- Add clear scope boundaries

**Acceptance Criteria**:
- [ ] Detect CLAUDE.md context from filename or content
- [ ] Transform vague rules into specific instructions
- [ ] Add example placeholders where missing
- [ ] Result contains no self-referential AI language

#### FR4.6: README Rewriting

**Rewriting Principles**:
- Quickstart within first 3 sections
- Show, don't tell
- Commands should be copy-pasteable
- Features need demonstrations

**Replacement Strategies**:

| Slop Pattern | Replacement Strategy |
|--------------|---------------------|
| "Welcome to [Project]!" | Direct: project name + one-line description |
| "A powerful solution for..." | Specific: "Converts X to Y in Z seconds" |
| "Production-ready" | Evidence: "Used by X teams" or remove |
| "Coming soon" | Remove or move to roadmap section |

**Structural Rewrites**:
- Move installation before features
- Add copy-paste code blocks
- Replace bullet lists with examples where possible
- Consolidate badges to essential ones

**Acceptance Criteria**:
- [ ] Detect README context from filename or prompt
- [ ] Ensure quickstart appears early
- [ ] All installation steps have executable commands
- [ ] Marketing language replaced with specifics

#### FR4.7: PRD Rewriting

**Rewriting Principles**:
- Every requirement needs acceptance criteria
- Metrics need baselines and targets
- Scope needs explicit boundaries
- Dependencies need owners

**Replacement Strategies**:

| Slop Pattern | Replacement Strategy |
|--------------|---------------------|
| "The system should be fast" | "Response time <200ms at p95" |
| "Good user experience" | Specific: "Task completion in <3 clicks" |
| "Future consideration" | Move to explicitly deferred section or delete |
| Requirements without priority | Add MoSCoW or numbered priority |

**Structural Rewrites**:
- Add acceptance criteria to all requirements
- Add baseline column to metrics tables
- Create explicit out-of-scope section
- Add owner column to dependencies

**Acceptance Criteria**:
- [ ] Detect PRD context from prompt or content patterns
- [ ] Transform vague requirements into measurable ones
- [ ] Add acceptance criteria placeholders where missing
- [ ] Ensure all metrics have baselines

#### FR4.8: Design Document Rewriting

**Rewriting Principles**:
- Decisions over descriptions
- Every option needs tradeoff analysis
- Constraints inform choices
- Failure modes are explicit

**Replacement Strategies**:

| Slop Pattern | Replacement Strategy |
|--------------|---------------------|
| "We could use X or Y" | Recommend one with rationale |
| "To be determined" | State decision deadline and owner |
| "The system will handle..." | Specify the how with diagrams |
| Generic component names | Specific: "UserAuthService" not "Handler" |

**Structural Rewrites**:
- Add "Alternatives Considered" section
- Add "Why Not" for each rejected option
- Add "Failure Modes" section
- Add scale assumptions to architecture

**Acceptance Criteria**:
- [ ] Detect design doc context from prompt or content
- [ ] Ensure all options have recommendations
- [ ] Add constraints section if missing
- [ ] Replace TBD with decision owners

#### FR4.9: Test Plan Rewriting

**Rewriting Principles**:
- Every test case has expected result
- Tests trace to requirements
- Priority reflects risk
- Environment is specified

**Replacement Strategies**:

| Slop Pattern | Replacement Strategy |
|--------------|---------------------|
| "Verify system works correctly" | Specific: "Given X, when Y, then Z" |
| "Test all edge cases" | List specific edge cases |
| "Comprehensive testing" | Specific coverage targets |
| "Should behave properly" | Expected result with values |

**Structural Rewrites**:
- Add Given/When/Then format
- Add requirement traceability column
- Add severity/priority to test cases
- Separate automated from manual tests

**Acceptance Criteria**:
- [ ] Detect test plan context from prompt or content
- [ ] Transform vague tests into specific scenarios
- [ ] Add expected results to all test cases
- [ ] Ensure requirement traceability

#### FR4.10: CV/Resume Rewriting

**Rewriting Principles**:
- Achievements over responsibilities
- Quantify all impact
- Show scope with numbers
- Skills through demonstration

**Replacement Strategies**:

| Slop Pattern | Replacement Strategy |
|--------------|---------------------|
| "Responsible for..." | "Delivered X resulting in Y" |
| "Managed a team of..." | "Led N engineers to deliver X" |
| "Improved performance" | "Reduced latency by X% (from Y to Z)" |
| "Results-driven professional" | Delete; show results instead |
| "Passionate about..." | Delete or demonstrate with projects |

**Structural Rewrites**:
- Convert responsibilities to achievements
- Add metrics to every bullet
- Replace objective with summary
- Remove "References available"

**Acceptance Criteria**:
- [ ] Detect CV context from prompt or content
- [ ] Transform responsibilities into achievements
- [ ] Add quantification prompts where missing
- [ ] Remove buzzword-heavy summaries

#### FR4.11: Cover Letter Rewriting

**Rewriting Principles**:
- Company-specific opening
- Role alignment, not CV repetition
- Demonstrate, don't claim
- Specific call to action

**Replacement Strategies**:

| Slop Pattern | Replacement Strategy |
|--------------|---------------------|
| "I am writing to apply for..." | Hook with company-specific insight |
| "I am excited to apply..." | Why this company specifically |
| "I am a hard worker" | Specific example of work ethic |
| "Thank you for your consideration" | Specific next step proposal |

**Structural Rewrites**:
- Open with company-specific hook
- Connect experience to job requirements
- Add specific examples for each claim
- End with concrete call to action

**Acceptance Criteria**:
- [ ] Detect cover letter context from prompt or content
- [ ] Ensure company-specific content present
- [ ] Transform claims into examples
- [ ] Replace generic closing with specific CTA

### FR5: Persistent Dictionary Management

Maintain and mutate the shared pattern dictionary.

**Capabilities** (from Vision_PRD §6.1 FR6):
- Add new patterns: "Add '[phrase]' to [category]"
- Add content-type-specific patterns: "Add '[phrase]' to email slop"
- Remove patterns: "Remove '[phrase]' from dictionary"
- Add exceptions: "Never flag '[phrase]'"
- Query dictionary: "Show top slop patterns"
- Query by type: "Show email slop patterns"
- Export dictionary for backup

**Storage**:
- Location: Workspace root directory
- Auto-add to .gitignore if git repository detected
- Structure: pattern text, category, content type, count, date added, source

**Acceptance Criteria**:
- [ ] Dictionary persists across sessions
- [ ] Accessible from multiple machines via workspace
- [ ] .gitignore auto-updated
- [ ] Each detection increments pattern count
- [ ] User can add/remove/query/export
- [ ] Content-type-specific patterns supported

### FR6: User Feedback Integration

Learn from user corrections.

**Missed Pattern Workflow** (from Vision_PRD §6.1 FR7):
1. User: "This phrase is slop: '[phrase]'"
2. Skill extracts phrase, adds to dictionary
3. Skill prompts for content type: "Universal, or specific to email/LinkedIn/SMS/chat?"
4. Skill confirms addition
5. Skill rescans current document
6. Pattern detected in future outputs

**False Positive Workflow**:
1. User: "Don't flag '[phrase]'"
2. Skill adds to exception list
3. User specifies scope: document-only, content-type-only, or permanent/universal

**Content-Type Feedback**:
- "That's fine for chat but not email" → Add to email patterns only
- "Too formal for text messages" → Add to SMS patterns
- "This is LinkedIn cringe" → Add to LinkedIn patterns

**Acceptance Criteria**:
- [ ] Recognize feedback patterns ("is slop", "don't flag")
- [ ] Extract exact phrase from user message
- [ ] Prompt for content type when ambiguous
- [ ] Confirm all dictionary changes
- [ ] New patterns detected in future
- [ ] Exceptions respected in future
- [ ] Content-type-scoped exceptions supported

### FR7: Metrics Tracking

Track rewriting metrics.

**Tracked Metrics** (from Vision_PRD §6.1 FR8):
- Patterns fixed (count per document, per 1000 words, by content type)
- Rewrite quality (user reports of "changed my meaning")
- Dictionary growth rate (by content type)
- User-reported misses and false positives (by content type)
- Content type distribution (emails vs LinkedIn vs SMS vs chat vs docs)
- Average length reduction by content type

**Acceptance Criteria**:
- [ ] Maintain counters per document and per content type
- [ ] Report on request: "Show slop elimination stats"
- [ ] Filter by content type: "Show email rewrite stats"
- [ ] Aggregate cumulative totals
- [ ] Metrics persist across sessions
- [ ] Exportable for analysis

### FR8: Rewriting Transparency

Report what was changed.

**Reporting Modes**:
- **Verbose** (first 30 days): Summary after every response
- **On-demand** (after trust established): Summary available on request
- **Detailed**: "Show what slop you removed" for full breakdown
- **By content type**: "Show what you changed in that email"

**Acceptance Criteria**:
- [ ] Toggle between verbose and on-demand
- [ ] Summary shows count by category and content type
- [ ] Detailed view shows before/after for each change
- [ ] Content-type-specific reporting supported

## 4. Non-Functional Requirements

| Requirement | Target |
|-------------|--------|
| Rewrite latency | <3 seconds added to response time |
| Meaning preservation | <5% of rewrites change intended meaning |
| Dictionary capacity | ≥1000 entries without performance degradation |

## 5. Out of Scope

- Bullshit factor scoring (see detecting-ai-slop)
- Read-only analysis mode (see detecting-ai-slop)

## 6. Dependencies

- Shared dictionary (workspace root)
  - Universal patterns section
  - Email patterns section
  - LinkedIn patterns section
  - SMS patterns section
  - Teams/Slack patterns section
- Shared metrics store (workspace root)
- Detection logic (embedded, same as detecting-ai-slop)
- Content type detection heuristics
- Content-type-specific replacement strategies

---

*Derived from Vision_PRD.md v2.0*
*Status: Draft*


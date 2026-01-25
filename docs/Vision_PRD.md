# AI Slop Detection Superpower Skill

## 1. Executive Summary

Claude currently generates text containing identifiable AI patterns ("slop") that require extensive manual review—consuming 10+ minutes per page of output. This PRD defines requirements for a Claude skill that implements a **Generate-Verify-Refine (GVR) loop** to automatically detect and eliminate slop patterns across lexical, structural, semantic, and stylometric dimensions. The skill will reduce review time from 10 minutes/page to <1 minute/page (90% reduction), reclaiming approximately 13.5 hours per week while producing output with zero detectable AI patterns.

## 2. Problem Statement

### 2.1 Current State

Claude's default prose generation relies on high-probability token sequences that manifest as characteristic AI patterns:

**Lexical slop**: Overused boosters ("incredibly," "leverage," "delve"), buzzwords ("synergy," "ecosystem"), filler phrases ("it's important to note"), hedge patterns ("of course," "naturally"), and sycophantic language ("great question," "happy to help")

**Structural slop**: Formulaic introductions that rephrase the question, template-driven sections (Overview → Key Points → Best Practices → Conclusion), excessive signposting ("In this section, we will..."), and uniform paragraph rhythms

**Semantic slop**: Hollow specificity (vague examples lacking who/what/when/where), symmetric coverage (artificially balanced pros/cons), and absent constraints (unrealistic claims without caveats)

**Stylometric slop**: Uniform sentence lengths (low variance), low vocabulary diversity (Type-Token Ratio), and predictable word patterns that statistical analysis can identify as machine-generated

**Current workflow**: User requests content → Claude generates output → User manually reviews for 10+ minutes per page → User identifies slop → User requests rewrites → Cycle repeats 2-3 times per document.

**Volume impact**: At 30 documents/week averaging 3 pages each, this consumes 15 hours/week (90 pages × 10 minutes = 900 minutes).

### 2.2 Impact

**Primary user**: Matt J Bordenet, working with Claude via VS Code on macOS across 3 machines.

**Affected workflows**:
- Blog post authoring and editing
- Wiki page creation and updates
- README documentation
- One-Pager and Six-Pager business documents

**Quantified pain points**:

| Pain Point | Current State | Impact |
|------------|---------------|--------|
| Manual review time | 10 minutes/page | 15 hours/week consumed |
| Iteration cycles | 2-3 rewrites/document | Degraded flow state, cognitive load |
| Pattern tracking | None (manual memory) | Inconsistent detection, repeated mistakes |
| Credibility risk | Unknown slip-through rate | Professional reputation damage if slop escapes review |

## 3. Goals and Objectives

### 3.1 Business Goals

1. **Reclaim productivity**: Reduce user review time from 10 minutes/page to <1 minute/page (90% reduction)
2. **Achieve zero-slop output**: Produce text that exhibits no detectable AI authorship patterns
3. **Build institutional memory**: Create a persistent, cross-machine-synced dictionary of anti-patterns that improves over time
4. **Enable cross-machine consistency**: Dictionary and settings accessible across all 3 machines via GitHub-based sync workflow

### 3.2 User Goals

1. **Receive clean first drafts**: Claude outputs text requiring minimal manual review
2. **Trust the process**: Confidence that slop has been automatically removed before delivery
3. **Learn from patterns**: Visibility into which slop patterns appear most frequently
4. **Contribute improvements**: Ability to flag missed patterns that the skill incorporates for future detection
5. **Maintain flow state**: Eliminate disruption from multiple rewrite cycles
6. **Iterate on detection rules**: Ability to provide feedback on detection accuracy and adjust behavior over time

### 3.3 Success Metrics

#### Primary Metrics

| Metric | Baseline | Target | Timeline | Measurement Method |
|--------|----------|--------|----------|-------------------|
| User review time | 10 minutes/page | <1 minute/page | 30 days post-launch | User-logged "Time to Publish" per document |
| Sentence length variance (σ) | ~7.5 words | >15.0 words | Immediate | Automatic calculation via Verify pass |
| Type-Token Ratio (TTR) | ~0.45 (per 100-word block) | 0.50-0.70 range | Immediate | Automatic calculation via Verify pass |
| Paragraph length variance (SD) | Unknown | >25 words | Immediate | Automatic calculation via Verify pass |
| Rewrite cycle count | 2-3 cycles/document | 0-1 cycles/document | 30 days post-launch | Conversation log audit |
| False positive rate | N/A | <5% of flagged items | 60 days post-launch | User feedback: "incorrectly flagged" / total flags |

#### Secondary Metrics

| Metric | Baseline | Target | Timeline | Measurement Method |
|--------|----------|--------|----------|-------------------|
| Dictionary growth | 0 entries | 500+ unique patterns | 90 days post-launch | Count of entries in dictionary |
| User-reported misses | N/A | <2 missed patterns/document | 60 days post-launch | User flags pattern that skill missed |
| Slop-free confidence | N/A | ≥95% of outputs confirmed clean | 90 days post-launch | Post-publication user confirmation |
| Latency overhead | 0 seconds | <3 seconds total | Immediate | Time-to-final-token measurement |
| Cross-machine sync success | N/A | 100% sync within 1 manual trigger | Immediate | Dictionary state verification across machines |

## 4. Proposed Solution

### 4.1 Architecture: The Generate-Verify-Refine (GVR) Loop

Since Claude cannot edit tokens already sent during streaming, the skill implements a **Generate-Verify-Refine** loop:

1. **Generate**: Claude produces a raw draft based on user request
2. **Verify**: The skill analyzes the draft against the slop dictionary and performs stylometric calculations
3. **Refine**: If thresholds are missed, the skill issues refinement instructions and Claude rewrites affected sections
4. **Return**: Clean output delivered to user

This loop may execute multiple passes until all thresholds are met or a maximum iteration count (3) is reached.

### 4.2 Core Functionality

**Real-time detection and elimination**: When Claude generates English prose (excluding code), the skill:
1. Analyzes output during the Verify pass
2. Identifies slop patterns across four dimensions (lexical, structural, semantic, stylometric)
3. Issues refinement commands for flagged content
4. Returns clean output after successful verification

**Continuous learning**: The skill maintains a persistent dictionary of detected patterns:
- Tracks each pattern with occurrence count, category, and timestamp
- Increments count each time a pattern is detected and fixed
- Incorporates user-reported missed patterns
- Supports user-defined exceptions (temporary and permanent)

**Cross-machine synchronization**: Dictionary accessible across all machines via GitHub-based workflow:
- Primary storage: `~/.claude/skills/slop_dictionary.json`
- Fallback: Workspace root directory
- Sync mechanism: Shell script for push/pull to private GitHub repository
- Conflict resolution: Last Write Wins (based on timestamp field)

**User feedback integration**: The skill learns from user corrections:
- User can flag missed patterns ("This is slop: [phrase]")
- User can mark false positives for exclusion
- Feedback persists across sessions with timestamp

### 4.3 User Experience

**Default operation**: User requests content as normal; GVR loop operates transparently.

**Standard workflow**:
1. User: "Write a blog post about database indexing strategies"
2. Claude + Skill: Generate draft → Verify against rules → Refine if needed → Return clean output
3. User receives: Clean first draft with no detectable AI patterns
4. User reviews in <1 minute, confirms quality, publishes

**Feedback workflow**:
1. User identifies missed slop: "This is slop: 'it's worth noting'"
2. Skill acknowledges, adds to dictionary with weight and timestamp
3. Skill rescans current document and refines if pattern found
4. Pattern detected in all future outputs

**Processing user-provided text** (distinct from generation):
When user provides existing text for editing (not requesting new generation), the skill:
1. Detects slop patterns in provided text
2. Asks user about flagged patterns before rewriting: "I found '[pattern]' ([category]). Rephrase or keep?"
3. User can approve/reject individual patterns or batch respond
4. Temporary exceptions persist for current document; permanent exceptions persist to dictionary

**Metrics visibility**: User can request metrics summary:
- "Show me slop detection stats for this document"
- Output: Pattern counts by category, stylometric measurements, dictionary size

### 4.4 Key Workflows

#### Workflow 1: Standard Content Generation (GVR Loop)
1. User requests blog post, wiki article, or documentation
2. Skill activates automatically (detects English prose generation context)
3. **Generate**: Claude produces raw draft
4. **Verify**: Skill analyzes draft against dictionary and calculates stylometric metrics
5. **Refine**: If thresholds missed, skill issues refinement commands; Claude rewrites
6. **Return**: Clean output delivered to user
7. Skill logs metrics

#### Workflow 2: User Feedback Integration
1. User identifies slop that skill missed: "This is slop: '[phrase]'"
2. Skill extracts phrase, adds to dictionary with `weight: 1.0` and `timestamp`
3. Skill immediately rescans current document
4. Skill refines if new pattern found in current output
5. Dictionary persists for future detection

#### Workflow 3: Processing User-Provided Text
1. User provides existing text: "Edit this paragraph: [text]"
2. Skill detects slop patterns in provided text
3. Skill prompts for confirmation on each pattern (or batch)
4. User approves/rejects rewrites
5. Skill processes approved changes, respects rejections

#### Workflow 4: Dictionary Synchronization
1. User completes work session on Machine A
2. User runs sync script: `slop-sync push` (uploads dictionary to GitHub)
3. User switches to Machine B
4. User runs sync script: `slop-sync pull` (downloads latest dictionary)
5. Skill operates with synchronized dictionary

#### Workflow 5: Metrics Review
1. User requests statistics: "Show slop detection metrics"
2. Skill reports current document metrics + cumulative totals
3. User reviews pattern distribution, stylometric measurements, dictionary growth

## 5. Scope

### 5.1 In Scope

**Document types**:
- Blog posts
- Wiki articles
- README files
- One-Pager documents
- Six-Pager documents
- Any English prose content (excludes code)

**Detection dimensions**:
- Lexical patterns (100+ specific phrases across 5 categories)
- Structural patterns (formulaic intros, template sections, signposting, paragraph rhythm)
- Semantic patterns (hollow specificity, symmetric coverage, absent constraints)
- Stylometric patterns (sentence length variance, paragraph length variance, TTR, hapax legomena)

**Capabilities**:
- GVR loop detection and refinement
- Persistent dictionary with frequency and timestamp tracking
- User feedback integration (add/remove patterns, exceptions)
- Metrics tracking and reporting
- Cross-machine dictionary synchronization via GitHub shell script
- Automatic `.gitignore` management to prevent accidental commits of dictionary to project repos

### 5.2 Out of Scope

**Non-English languages**: Skill operates on US English only (Phase 1)

**Code generation**: Skill does not activate for programming languages, SQL, JSON, YAML, shell scripts, or other structured code formats

**Cloud-based API sync**: No real-time cloud synchronization; sync is manual via shell script

**Batch processing**: Skill operates during active generation only, not on previously written content outside current conversation

**Machine learning inference**: Detection uses heuristic pattern matching and statistical analysis only; no ML model training or inference

**Multi-user collaboration**: Phase 1 supports single user only

### 5.3 Future Considerations

**Phase 2 possibilities** (pending Phase 1 success):
- Multi-language support
- Batch processing mode for existing document libraries
- Automated cloud sync (if manual sync proves insufficient)
- Team collaboration features (shared dictionaries)
- Advanced ML-based detection (if heuristics prove insufficient)

## 6. Requirements

### 6.1 Functional Requirements

#### FR1: Lexical Pattern Detection
**Description**: Detect slop phrases across 5 categories during the Verify pass.

**Categories**:
1. **Generic boosters**: incredibly, extremely, highly, remarkably, exceptionally, substantially, truly, really, very (when modifying already-strong adjectives), delve, tapestry, multifaceted
2. **Buzzwords**: leverage, utilize, synergy, paradigm, ecosystem, actionable, robust, scalable, holistic, streamline, empower, optimize, innovative, cutting-edge
3. **Filler phrases**: it's important to note, let's dive in, let's explore, it's worth mentioning, bear in mind, at the end of the day, in today's world, when it comes to
4. **Hedge patterns**: of course, naturally, in many ways, to some extent, generally speaking, it goes without saying, needless to say
5. **Sycophantic phrases**: great question, happy to help, I appreciate your interest, excellent point, that's a thoughtful question, I'd be glad to

**Detection rule**: Any phrase appearing ≥1 time per 300 words is flagged for replacement.

**Acceptance Criteria**:
- [ ] Skill maintains dictionary of ≥100 phrases with category tags
- [ ] Each phrase includes replacement guidance (delete, rephrase, substitute)
- [ ] Skill detects ≥90% of listed phrases in generated text
- [ ] Each detection increments dictionary count and updates timestamp
- [ ] Sycophantic phrases at response start are automatically stripped
- [ ] User can add new phrases to any category
- [ ] User can remove phrases or add to exception list

#### FR2: Structural Pattern Detection
**Description**: Identify and eliminate formulaic document structures during the Verify pass.

**Patterns**:
1. **Formulaic introductions**: Opening that restates the question → asserts topic importance → promises overview
2. **Template sections**: Rigid progression through Overview → Key Points → Best Practices → Conclusion (or similar)
3. **Excessive signposting**: "In this section, we will..." / "Now let's turn to..." / "Next, we'll examine..." / "In conclusion," / "Furthermore,"
4. **Uniform paragraph rhythm**: ≥3 consecutive paragraphs with similar word counts (within ±15%)

**Acceptance Criteria**:
- [ ] Skill detects formulaic introduction pattern
- [ ] Skill detects ≥3 different template section patterns
- [ ] Skill flags signposting phrases for removal
- [ ] Skill flags paragraph sequences with uniform rhythm
- [ ] Refinement commands specify how to vary structure
- [ ] Rewrites maintain logical flow while eliminating formulaic structure

#### FR3: Semantic Pattern Detection
**Description**: Identify hollow specificity, artificial balance, and missing constraints.

**Patterns**:
1. **Hollow specificity**: Examples lacking concrete details (no names, dates, numbers, locations, or specific outcomes)
2. **Symmetric coverage**: Artificially balanced structures (exactly N pros and N cons; perfectly mirrored sections)
3. **Absent constraints**: Absolute claims without limitations ("works perfectly," "always succeeds," "never fails")

**Acceptance Criteria**:
- [ ] Skill flags examples lacking ≥2 concrete details (who, what, when, where, how much)
- [ ] Skill detects artificially symmetric structures
- [ ] Skill identifies absolute claims and flags for realistic constraints
- [ ] Refinement commands specify what concrete details or constraints to add

#### FR4: Stylometric Pattern Detection
**Description**: Detect statistical anomalies indicating AI generation using quantitative metrics.

**Research basis**: StyloAI (Opara, 2024) and Desaire et al. (2023).

**Metrics and thresholds**:

| Metric | Formula | Flag If | Target |
|--------|---------|---------|--------|
| Sentence length variance (σ) | Standard deviation of word counts per sentence | σ < 15.0 words | σ > 15.0 words |
| Paragraph length variance (SD) | Standard deviation of word counts per paragraph | SD < 25 words | SD > 25 words |
| Type-Token Ratio (TTR) | Unique words / Total words (per 100-word window) | TTR < 0.50 or TTR > 0.70 | 0.50 ≤ TTR ≤ 0.70 |
| Hapax legomena rate | Words appearing once / Total unique words | Below user-calibrated baseline | At or above baseline |

**Acceptance Criteria**:
- [ ] Skill calculates sentence length σ for all prose blocks ≥100 words
- [ ] Skill calculates paragraph length SD per document
- [ ] Skill calculates TTR per 100-word rolling window
- [ ] Skill calculates hapax legomena rate per document
- [ ] Skill flags documents where ≥2 stylometric metrics miss thresholds
- [ ] Refinement commands instruct Claude to vary sentence/paragraph length, incorporate fragments and complex sentences
- [ ] User can adjust sensitivity (strict/moderate/loose)
- [ ] Skill logs all stylometric measurements for user review

#### FR5: Real-Time Rewriting (Refine Pass)
**Description**: Issue refinement commands to eliminate detected slop patterns.

**Acceptance Criteria**:
- [ ] Skill generates specific refinement commands (e.g., "Rewrite paragraph 2 to increase sentence variance and remove 'leverage'")
- [ ] Refinement commands preserve semantic meaning and factual accuracy
- [ ] Refinement commands address all flagged issues from Verify pass
- [ ] GVR loop iterates until all thresholds met or max iterations (3) reached
- [ ] If max iterations reached without full compliance, skill reports remaining issues to user
- [ ] Original pre-refinement content available on request for comparison

#### FR6: Persistent Dictionary
**Description**: Maintain growing dictionary of detected patterns with frequency and timestamp tracking.

**Storage hierarchy**:
1. Primary: `~/.claude/skills/slop_dictionary.json`
2. Fallback: Workspace root directory (if primary unavailable)

**Dictionary entry fields**:
- `pattern`: The slop phrase or pattern
- `category`: lexical | structural | semantic | stylometric
- `weight`: Detection priority (default 1.0, adjustable)
- `count`: Number of times detected and fixed
- `timestamp`: Last updated (ISO 8601 format)
- `source`: built-in | user-added
- `exception`: false | document | permanent

**Sync requirements**:
- Shell script `slop-sync` with commands: `push`, `pull`, `status`
- Push: Uploads dictionary to private GitHub repository
- Pull: Downloads latest dictionary, applies Last Write Wins conflict resolution
- Status: Shows sync state and any conflicts

**Acceptance Criteria**:
- [ ] Dictionary persists across Claude sessions
- [ ] Dictionary supports ≥1,000 unique entries without performance degradation
- [ ] Each detection increments count and updates timestamp
- [ ] User can query dictionary: "Show top 10 slop patterns"
- [ ] User can add patterns: "Add '[phrase]' to [category]"
- [ ] User can remove patterns: "Remove '[phrase]' from dictionary"
- [ ] User can export dictionary for backup
- [ ] Shell script successfully pushes/pulls to GitHub repository
- [ ] Conflict resolution applies Last Write Wins based on timestamp
- [ ] If dictionary file unavailable, skill falls back to built-in "Standard Slop List"

#### FR7: User Feedback Integration
**Description**: Allow user to flag missed patterns and false positives.

**Missed pattern workflow**:
1. User identifies missed slop: "This is slop: '[phrase]'"
2. Skill extracts phrase
3. Skill adds to dictionary with `weight: 1.0`, `timestamp: now`, `source: user-added`
4. Skill confirms: "Added '[phrase]' to slop dictionary. Rescanning current document..."
5. Skill rescans and refines if pattern found
6. Pattern detected in all future outputs

**False positive workflow**:
1. User identifies false positive: "Don't flag '[phrase]' as slop"
2. Skill updates dictionary entry: `exception: permanent` (or `exception: document` if user specifies)
3. Skill confirms: "Added '[phrase]' to exceptions. It won't be flagged in future."

**Acceptance Criteria**:
- [ ] Skill recognizes feedback patterns: "is slop" / "sounds AI-generated" / "typical AI phrase"
- [ ] Skill recognizes false positive patterns: "don't flag" / "keep" / "that's intentional"
- [ ] Skill extracts exact phrase from user message
- [ ] Skill confirms all dictionary changes with details
- [ ] New patterns detected in future outputs
- [ ] Exceptions respected in future outputs
- [ ] User can review exception list: "Show my exceptions"

#### FR8: Metrics Tracking
**Description**: Track and report detection and fix metrics.

**Tracked metrics**:
- Patterns detected (count per document, per 1000 words)
- Patterns fixed (count per document, per 1000 words)
- Pattern type distribution (lexical, structural, semantic, stylometric)
- GVR loop iterations per document
- Stylometric measurements (σ, SD, TTR, hapax rate)
- Dictionary size and growth rate
- User-reported misses and false positives

**Acceptance Criteria**:
- [ ] Skill maintains running counters per document
- [ ] Skill reports metrics on request: "Show slop detection stats"
- [ ] Skill reports stylometric measurements with pass/fail status
- [ ] Metrics persist across sessions
- [ ] User can export metrics for analysis

#### FR9: Automatic Activation Control
**Description**: Skill activates automatically for English prose, deactivates for code.

**Activation triggers**:
- Blog posts, wiki articles, READMEs (prose sections), documentation, business documents
- Any user prompt requesting prose content generation

**Deactivation triggers**:
- Code blocks (Python, JavaScript, SQL, etc.)
- Configuration files (JSON, YAML, TOML)
- Shell commands
- Structured data formats

**Manual override**:
- "Disable slop detection for this response"
- "Enable slop detection" (re-enable after manual disable)
- "Disable [category] detection" (e.g., "Disable structural detection for this document")

**Acceptance Criteria**:
- [ ] Skill automatically activates for prose generation contexts
- [ ] Skill automatically deactivates for code generation contexts
- [ ] User can manually override activation state
- [ ] User can disable specific detection categories
- [ ] Override state resets at start of new conversation (unless user specifies persistence)

#### FR10: Confirmation Prompts for User-Provided Text
**Description**: When user provides existing text for processing (not generation), confirm before rewriting.

**Trigger conditions**:
- User provides text with edit request: "Edit this paragraph: [text]"
- User provides text with review request: "Review this draft: [text]"
- User pastes text with processing instruction: "Clean up this content: [text]"

**Confirmation workflow**:
1. Skill detects slop patterns in user-provided text
2. Skill offers batch or individual review: "I found 5 patterns. Rephrase all, keep all, or let me list them?"
3. If individual: For each pattern, skill asks: "I found '[pattern]' ([category]). Rephrase or keep?"
4. User responds:
   - "Rephrase" / "Remove it" → Skill rewrites, logs to metrics
   - "Keep it" / "I meant that" → Skill preserves phrase, adds temporary exception
   - "Never flag [pattern]" → Skill adds permanent exception
5. Skill processes approved changes, respects rejections

**Acceptance Criteria**:
- [ ] Skill distinguishes between generation requests and processing requests
- [ ] Confirmation prompt identifies pattern and category
- [ ] User can respond to individual patterns or batch
- [ ] Temporary exceptions persist for current document only
- [ ] Permanent exceptions persist to dictionary
- [ ] If user doesn't respond, skill flags but doesn't rewrite (safe default)

#### FR11: Cross-Machine Sync Script
**Description**: Shell script for synchronizing dictionary across machines via GitHub.

**Commands**:
- `slop-sync push`: Upload local dictionary to GitHub repository
- `slop-sync pull`: Download latest dictionary from GitHub, resolve conflicts
- `slop-sync status`: Show sync state, last sync time, any pending conflicts

**Conflict resolution**: Last Write Wins based on `timestamp` field in dictionary entries.

**Acceptance Criteria**:
- [ ] Script installs to user PATH (e.g., `~/.local/bin/slop-sync`)
- [ ] Script authenticates to GitHub via existing git credentials or SSH key
- [ ] Push command commits and pushes dictionary file to configured repository
- [ ] Pull command fetches and merges dictionary, applying Last Write Wins
- [ ] Status command shows: last sync time, local changes pending, remote changes available
- [ ] Script provides clear error messages for auth failures, network issues, merge conflicts
- [ ] Script automatically adds dictionary to workspace `.gitignore` when git repo detected

### 6.2 Non-Functional Requirements

#### NFR1: Performance
**Description**: Skill must operate without significantly impacting response time.

**Requirements**:
- Verify pass completes in <800ms for documents up to 1000 words
- Total latency overhead (all GVR iterations) <3 seconds for typical document
- Dictionary lookups complete in <100ms regardless of dictionary size
- Performance does not degrade as dictionary grows to 1000+ entries

**Measurement**: User perception survey: "Responses feel noticeably delayed" reported in <10% of sessions

#### NFR2: Accuracy
**Description**: Skill must minimize false positives and false negatives.

**Requirements**:
- False positive rate: <5% of flagged items confirmed as acceptable prose by user
- False negative rate: User reports <2 missed patterns per document on average
- Rewrite quality: <5% of refinements reported as changing intended meaning
- Stylometric accuracy: ≥80% of flagged documents confirmed as "sounding AI-generated"

**Measurement**:
- User feedback tracking: "Incorrectly flagged" / total flags
- User feedback tracking: "Missed pattern" reports per document
- User feedback tracking: "Changed my meaning" reports

#### NFR3: Reliability
**Description**: Skill must operate consistently without failures.

**Requirements**:
- Skill available in ≥99% of Claude conversations where invoked
- Dictionary data preserved across sessions with zero data loss
- Graceful degradation: If dictionary file unavailable, skill operates with built-in Standard Slop List
- Sync script completes successfully in ≥95% of invocations

**Measurement**: Error logs, user reports of skill failures, dictionary integrity checks

#### NFR4: Usability
**Description**: Skill must operate with minimal user configuration.

**Requirements**:
- Works immediately upon first use with built-in patterns
- No required configuration before first use
- All commands use natural language (no special syntax required)
- Clear, concise feedback messages
- Sync script usable with single command after initial setup

**Measurement**: User can complete first successful use without reading documentation

#### NFR5: Portability
**Description**: Skill must work consistently across multiple machines.

**Requirements**:
- Dictionary stored in consistent location (`~/.claude/skills/`)
- Sync script enables dictionary synchronization via GitHub
- No machine-specific configuration required beyond initial sync setup
- Settings and exceptions portable with dictionary

**Measurement**: Dictionary state identical across all 3 machines after sync

#### NFR6: Maintainability
**Description**: Skill must support iterative improvement.

**Requirements**:
- Dictionary editable by user (add/remove patterns)
- Skill behavior adjustable via user commands (sensitivity levels)
- Dictionary exportable for backup and analysis
- Sync script updatable independent of skill

**Measurement**: User can add new pattern in <30 seconds; user can restore previous dictionary state via git history

### 6.3 Constraints

#### Technical Constraints
- **Platform**: Operates within Claude skill framework
- **Storage**: Dictionary stored at `~/.claude/skills/`; workspace fallback available
- **Sync**: Manual sync via shell script to GitHub; no real-time cloud sync
- **Processing**: GVR loop operates within Claude's generation pipeline
- **No external API dependencies**: Skill functions offline except for sync

#### Business Constraints
- **Single user**: Phase 1 supports only Matt's usage
- **Private repository**: Dictionary synced to private GitHub repo (superpowers-plus)
- **Zero budget**: No paid services or infrastructure
- **Self-maintained**: Matt is sole developer/maintainer

#### Regulatory Constraints
- **No PII in dictionary**: Patterns stored without user-identifiable context
- **Content privacy**: Generated text and dictionary remain private to user
- **No external transmission**: All data stays within Claude environment and local filesystem (except explicit GitHub sync)

## 7. Stakeholders

### 7.1 Primary User: Matt J Bordenet

**Role**: Content creator working with Claude across 3 machines via VS Code

**Impact**:
- Positive: Review time reduced from 15 hours/week to ~1.5 hours/week (90% reduction = 13.5 hours saved weekly)
- Positive: Higher quality published content with zero detectable AI patterns
- Positive: Consistent experience across all machines via GitHub sync
- Negative: Initial effort to calibrate detection sensitivity and train dictionary
- Negative: Manual sync step required when switching machines

**Needs**:
- Slop-free first drafts requiring minimal manual review
- Visibility into detection patterns and stylometric metrics
- Ability to teach skill about new slop patterns
- Confidence that skill won't introduce false positives or change meaning
- Reliable dictionary sync across machines

**Success Criteria**:
- Review time <1 minute/page for ≥90% of documents
- Zero detectable slop in ≥95% of final outputs
- <2 missed patterns/document requiring manual feedback
- <5% false positive rate
- Successful sync 100% of the time when manually triggered

### 7.2 Secondary Stakeholder: Future Users (Post Open-Source)

**Role**: Potential external users if repository is open-sourced after Phase 1 validation

**Impact**:
- Positive: Access to proven slop detection skill and curated dictionary
- Negative: May have different slop patterns or quality standards

**Needs**:
- Clear documentation
- Ability to customize for their use cases
- Contribution guidelines

**Success Criteria** (for open-source decision):
- 6 months of successful private use
- All Phase 1 success metrics sustained
- Documentation complete

### 7.3 Indirect Stakeholder: Content Readers

**Role**: Consumers of blog posts, wiki articles, and documentation

**Impact**:
- Positive: Higher quality, more credible content with authentic voice
- Negative: None (readers unaware of tooling)

**Needs**:
- Professional, credible content
- Clear explanations without buzzwords
- Authentic voice

**Success Criteria**:
- Zero reader comments questioning AI authorship

## 8. Timeline and Milestones

### Phase 1: Foundation (Weeks 1-2)
**Deliverable**: Core skill with lexical and structural detection, GVR loop

**Week 1**:
- Finalize PRD, design doc, test plan
- Implement GVR loop architecture
- Implement lexical pattern detection (100+ phrases, 5 categories)
- Implement persistent dictionary at `~/.claude/skills/`

**Week 2**:
- Implement structural pattern detection
- Implement basic metrics tracking
- Implement user feedback integration (add/remove patterns)
- Create sync shell script (`slop-sync`)
- Initial testing on 5 real documents

**Success Criteria**: Detect ≥10 lexical + structural patterns per typical AI-generated page; sync script functional

### Phase 2: Semantic and Stylometric Detection (Weeks 3-4)
**Deliverable**: Full detection coverage across all four dimensions

**Week 3**:
- Implement semantic pattern detection (hollow specificity, symmetry, absent constraints)
- Implement stylometric detection with mathematical calculations (σ, SD, TTR, hapax)
- Calibrate initial thresholds based on research

**Week 4**:
- Implement confirmation prompts for user-provided text
- Test on 15 real documents across all 3 machines
- Refine detection thresholds based on false positive/negative rates

**Success Criteria**: 
- Sentence variance σ >15.0 achieved in outputs
- TTR within 0.50-0.70 range
- False positive rate <10%

### Phase 3: Polish and Validation (Weeks 5-6)
**Deliverable**: Production-ready skill with validated metrics

**Week 5**:
- Daily use on all documents (target: 30 docs)
- Track all metrics rigorously
- Identify and fix edge cases
- Validate sync workflow across all machines

**Week 6**:
- Cross-machine validation
- User satisfaction validation
- Final refinements
- Complete technical specification appendix

**Success Criteria**: 
- User review time <1 minute/page for ≥90% of documents
- False positive rate <5%
- Sync 100% reliable

### Phase 4: Sustained Validation (Months 2-6)
**Deliverable**: Proven, battle-tested skill

**Ongoing**:
- Daily use across all document types
- Dictionary growth to 500+ patterns
- Continuous refinement based on feedback

**Success Criteria for Open-Source Consideration** (all must be met at Month 6):
- Review time <1 minute/page sustained for 30-day rolling average
- False positive rate <5% sustained
- Dictionary contains ≥500 proven patterns
- Zero critical failures in previous 30 days
- 3+ published pieces with zero detected AI patterns
- User confidence: "I haven't manually edited for slop in 2 weeks"

## 9. Risks and Mitigation

### Risk 1: False Positive Rate Exceeds 5%
**Likelihood**: Medium
**Impact**: High (skill flags acceptable prose, eroding trust)

**Mitigation**:
- Conservative initial thresholds (favor false negatives over false positives)
- User feedback mechanism to exclude incorrectly flagged patterns
- Confirmation prompts for user-provided text
- Weekly review of flagged patterns
- Adjustable sensitivity levels

**Contingency**: If false positive rate >10%, switch to highlight-only mode (flag but don't auto-refine)

### Risk 2: Stylometric Thresholds Don't Generalize
**Likelihood**: Medium
**Impact**: Medium (stylometric detection unreliable)

**Mitigation**:
- Initial thresholds based on peer-reviewed research (StyloAI, Desaire et al.)
- User calibration with human-written reference samples
- Track false positive/negative rates separately for stylometric dimension
- Adjustable sensitivity levels

**Contingency**: If stylometric accuracy <70%, disable by default; offer as opt-in "experimental" mode

### Risk 3: Dictionary Sync Fails Across Machines
**Likelihood**: Low
**Impact**: High (inconsistent experience, lost patterns)

**Mitigation**:
- Shell script with clear error messages
- Last Write Wins conflict resolution with timestamps
- Dictionary export capability for manual backup
- Git history provides rollback capability

**Contingency**: If sync unreliable, implement manual export/import as primary method

### Risk 4: Rewrites Change Intended Meaning
**Likelihood**: Medium
**Impact**: High (skill introduces errors)

**Mitigation**:
- Refinement commands preserve semantic meaning (explicit in prompt)
- Original content available on request
- User feedback tracking for "changed my meaning" reports
- Max 3 GVR iterations to prevent over-refinement

**Contingency**: If >5% of refinements change meaning, switch to suggestion mode (propose changes, user approves)

### Risk 5: Performance Degrades with Large Dictionary
**Likelihood**: Low
**Impact**: Medium (response latency increases)

**Mitigation**:
- Performance testing at 500, 1000, 2000 dictionary entries
- Frequency-based pruning: Archive entries with count <3 after 6 months
- Built-in fallback list ensures baseline functionality

**Contingency**: If latency >5 seconds, implement tiered lookup (high-frequency patterns first)

### Risk 6: GVR Loop Exceeds Max Iterations
**Likelihood**: Medium
**Impact**: Low (some slop may remain)

**Mitigation**:
- Refinement commands target specific issues (not general "make it better")
- Track which patterns persist across iterations
- Report remaining issues to user after max iterations

**Contingency**: User can manually request additional refinement pass or accept current output

## 10. Open Questions

### Q1: Rewriting Transparency ✓ RESOLVED
**Decision**: Verbose reporting initially, toggle to on-demand after trust established

**Implementation**:
- **First 30 days**: Summary after every response showing GVR loop results
- **After 30 days**: User can toggle verbose mode off; summary available on request
- **Always available**: "Show what slop you removed" for detailed breakdown including stylometric measurements

### Q2: Dictionary Scope ✓ RESOLVED
**Decision**: Single unified dictionary with category tags

**Rationale**: Domain-specific dictionaries add complexity without proportional benefit for single-user MVP. Categories provide sufficient organization.

### Q3: Sync Mechanism ✓ RESOLVED
**Decision**: Manual shell script sync to private GitHub repository

**Implementation**:
- `slop-sync push` / `pull` / `status` commands
- Last Write Wins conflict resolution based on timestamps
- Git history provides version control and rollback

### Q4: Activation Granularity ✓ RESOLVED
**Decision**: Three-level control hierarchy

1. **Binary**: Enable/disable entire skill
2. **Category**: Enable/disable specific detection dimensions
3. **Pattern**: Temporary exceptions (document-scope) and permanent exceptions (dictionary)

### Q5: Open-Source Timing ✓ RESOLVED
**Decision**: 6-month private validation, then evaluate against criteria

### Q6: Performance vs Accuracy Tradeoff ✓ RESOLVED
**Decision**: Accuracy first, optimize second

**Priority order**:
1. Maintain detection accuracy
2. Optimize for performance
3. Never sacrifice accuracy for speed

---

## 11. Implementation Hand-off Protocol

**NOTICE**: The following technical specifications are deferred to the Implementation Phase. They **MUST** be defined and added to this PRD as Appendix C before code generation begins. This section serves as a checklist for the implementation team.

### Required Technical Specifications

1. **Dictionary Schema**: Definitive JSON structure for `slop_dictionary.json` including all fields, data types, and validation rules

2. **Refinement Prompt Templates**: The specific system instructions used to drive the "Refine" pass, parameterized by detected issues

3. **Stylometric Calculation Methods**: Exact algorithms for calculating σ (sentence variance), SD (paragraph variance), TTR, and hapax legomena rate

4. **GVR Loop Control Logic**: Decision tree for when to iterate vs. when to return (thresholds, max iterations, early exit conditions)

5. **Sync Script Implementation**: Shell script source code for `slop-sync` including GitHub API integration, conflict resolution logic, and error handling

6. **Baseline Calibration Samples**: 5 samples of "Human-Authentic" text from Matt's published work to calibrate initial sensitivity thresholds

7. **Built-in Standard Slop List**: The hardcoded fallback pattern list used when dictionary is unavailable

### Process

Once these specifications are developed:
1. Add as Appendix C to this PRD
2. Review with stakeholder for approval
3. Proceed to implementation
4. Update Appendix C with any changes discovered during implementation

---

## Appendix A: Research References

### Stylometric Detection Research

1. **StyloAI** (Opara, 2024): Identified 31 stylometric features for AI text detection. Top 4 discriminating features: UniqueWordCount, StopWordCount, TTR, HapaxLegomenonRate. Achieved 81-98% accuracy on multi-domain datasets.

2. **Desaire et al.** (2023): Chemistry journal AI detection. Found standard deviation of paragraph length (threshold: 25 words) discriminates human vs AI writing with 99% accuracy when combined with 20 text features.

3. **General findings**:
   - AI text exhibits "uniform 12-18 word sentences" (low burstiness)
   - Human text mixes short punchy sentences with complex, clause-heavy structures
   - TTR varies by document length; 100-word window normalization recommended
   - Hapax legomena rate indicates vocabulary richness; AI often underperforms

### Threshold Summary

| Metric | Research Source | Threshold | Action |
|--------|-----------------|-----------|--------|
| Sentence length σ | StyloAI, industry practice | <15.0 words | Flag for refinement |
| Paragraph length SD | Desaire et al. (2023) | <25 words | Flag for refinement |
| Type-Token Ratio | StyloAI | <0.50 or >0.70 | Flag for refinement |
| Hapax legomena rate | StyloAI | Below baseline | Flag for refinement |

---

## Appendix B: Initial Lexical Pattern Dictionary

### Category 1: Generic Boosters (30+ patterns)
incredibly, extremely, highly, remarkably, exceptionally, substantially, truly, really, absolutely, completely, totally, utterly, deeply, profoundly, immensely, vastly, enormously, tremendously, significantly, particularly, especially, exceedingly, extraordinarily, intensely, overwhelmingly, delve, tapestry, multifaceted, myriad, plethora

### Category 2: Buzzwords (25+ patterns)
leverage, utilize, synergy, paradigm, ecosystem, actionable, robust, scalable, holistic, streamline, empower, optimize, innovative, cutting-edge, state-of-the-art, best-in-class, world-class, game-changing, transformative, disruptive, groundbreaking, revolutionary, next-generation, forward-thinking, thought-leader

### Category 3: Filler Phrases (25+ patterns)
it's important to note, let's dive in, let's explore, it's worth mentioning, bear in mind, at the end of the day, in today's world, when it comes to, in order to, the fact that, it should be noted, it is essential to, it is crucial to, as a matter of fact, in this day and age, at this point in time, for all intents and purposes, in the grand scheme of things, when all is said and done, by and large, first and foremost, last but not least, needless to say, it goes without saying, as we all know

### Category 4: Hedge Patterns (15+ patterns)
of course, naturally, in many ways, to some extent, generally speaking, it goes without saying, needless to say, as you might expect, as one might imagine, it could be argued, some might say, arguably, in some respects, to a certain degree, more or less

### Category 5: Sycophantic Phrases (15+ patterns)
great question, happy to help, I appreciate your interest, excellent point, that's a thoughtful question, I'd be glad to, wonderful question, fascinating topic, I'm excited to help, that's a great observation, what an interesting question, I love this question, thank you for asking, I'm delighted to assist, that's a really good point

---

## Appendix C: Technical Specifications

*[TO BE COMPLETED DURING IMPLEMENTATION PHASE]*

*See Section 11 (Implementation Hand-off Protocol) for required specifications.*

---

*This PRD was generated using the Product Requirements Assistant tool. Learn more at: https://github.com/bordenet/product-requirements-assistant*
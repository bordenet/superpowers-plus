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
- Any user prompt requesting prose content

**Deactivation Triggers**:
- Code blocks (Python, JavaScript, SQL, etc.)
- Configuration files (JSON, YAML, TOML)
- Shell commands, structured data

**Manual Override**:
- "Disable slop detection for this response"
- "Enable slop detection"
- "Disable [category] detection"

**Acceptance Criteria**:
- [ ] Auto-activate for prose contexts
- [ ] Auto-deactivate for code contexts
- [ ] Manual override respected
- [ ] Override resets at conversation start (unless persistence specified)

### FR4: Persistent Dictionary Management

Maintain and mutate the shared pattern dictionary.

**Capabilities** (from Vision_PRD §6.1 FR6):
- Add new patterns: "Add '[phrase]' to [category]"
- Remove patterns: "Remove '[phrase]' from dictionary"
- Add exceptions: "Never flag '[phrase]'"
- Query dictionary: "Show top slop patterns"
- Export dictionary for backup

**Storage**:
- Location: Workspace root directory
- Auto-add to .gitignore if git repository detected
- Structure: pattern text, category, count, date added, source

**Acceptance Criteria**:
- [ ] Dictionary persists across sessions
- [ ] Accessible from multiple machines via workspace
- [ ] .gitignore auto-updated
- [ ] Each detection increments pattern count
- [ ] User can add/remove/query/export

### FR5: User Feedback Integration

Learn from user corrections.

**Missed Pattern Workflow** (from Vision_PRD §6.1 FR7):
1. User: "This phrase is slop: '[phrase]'"
2. Skill extracts phrase, adds to dictionary
3. Skill confirms addition
4. Skill rescans current document
5. Pattern detected in future outputs

**False Positive Workflow**:
1. User: "Don't flag '[phrase]'"
2. Skill adds to exception list
3. User specifies scope: document-only or permanent

**Acceptance Criteria**:
- [ ] Recognize feedback patterns ("is slop", "don't flag")
- [ ] Extract exact phrase from user message
- [ ] Confirm all dictionary changes
- [ ] New patterns detected in future
- [ ] Exceptions respected in future

### FR6: Metrics Tracking

Track rewriting metrics.

**Tracked Metrics** (from Vision_PRD §6.1 FR8):
- Patterns fixed (count per document, per 1000 words)
- Rewrite quality (user reports of "changed my meaning")
- Dictionary growth rate
- User-reported misses and false positives

**Acceptance Criteria**:
- [ ] Maintain counters per document
- [ ] Report on request: "Show slop elimination stats"
- [ ] Aggregate cumulative totals
- [ ] Metrics persist across sessions
- [ ] Exportable for analysis

### FR7: Rewriting Transparency

Report what was changed.

**Reporting Modes**:
- **Verbose** (first 30 days): Summary after every response
- **On-demand** (after trust established): Summary available on request
- **Detailed**: "Show what slop you removed" for full breakdown

**Acceptance Criteria**:
- [ ] Toggle between verbose and on-demand
- [ ] Summary shows count by category
- [ ] Detailed view shows before/after for each change

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
- Shared metrics store (workspace root)
- Detection logic (embedded, same as detecting-ai-slop)

---

*Derived from Vision_PRD.md v2.0*
*Status: Draft*


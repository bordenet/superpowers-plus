# Composition Artifact Taxonomy

> Canonical vocabulary for `composition:` blocks in skill frontmatter.
> The auto-composition engine chains skills by matching `produces` → `consumes` artifact names.
> **All new skills MUST use artifacts from this taxonomy.** Add new entries here before inventing names.

## Artifact Categories

### Input — Raw user request or context

| Artifact | Description |
|----------|-------------|
| `challenge` | A problem or bug to investigate |
| `problem-statement` | Structured description of what's wrong |
| `goal` | Desired outcome or feature request |
| `project-brief` | High-level project scope document |
| `task-description` | Single work item description |
| `system-context` | Background knowledge about the system |
| `skill-ecosystem` | Installed skill files and metadata state |
| `branch-intent` | Intent behind a new git branch |
| `domain-context` | Subject-matter background for research |
| `skill-gap` | Identified missing capability in the skill library |
| `metric-claim` | A numeric assertion that needs verification |
| `repo-context` | Repository structure and conventions |

### Analysis — Results of investigation or analysis

| Artifact | Description |
|----------|-------------|
| `root-cause` | Identified root cause of an issue |
| `root-cause-verdict` | Adjudicated root cause with confidence |
| `risk-surface` | Identified risks and their severity |
| `impact-analysis` | Blast radius assessment of a change |
| `investigation-log` | Chronological record of investigation steps |
| `investigation-evidence` | Evidence gathered during debugging |
| `investigation-context` | Saved state for multi-session investigations |
| `investigation-handoff` | Handoff artifact for investigation continuity |
| `fresh-perspective` | Output from a think-twice fresh analysis |
| `slop-score-report` | AI writing quality score with pattern breakdown |
| `decision-matrix` | Quantified comparison of alternatives |
| `reasoning-tree` | Structured reasoning chain |
| `evidence-synthesis` | Aggregated evidence from multiple sources |

### Investigation Evidence (debug-conductor ecosystem)

| Artifact | Description |
|----------|-------------|
| `incident-packet` | Structured incident context for investigators |
| `incident-description` | Raw incident report |
| `incident-timeframe` | Time window of an incident |
| `infra-evidence` | Infrastructure investigation findings |
| `llm-evidence` | LLM/prompt behavior investigation findings |
| `experiment-evidence` | Controlled reproduction experiment results |
| `state-evidence` | Data consistency investigation findings |
| `timeline-evidence` | Timeline reconstruction findings |
| `branch-evidence-all` | All investigation branch results |
| `investigation-branches` | Active investigation branches |
| `investigation-state` | Current investigation state object |

### Design — Architecture and design outputs

| Artifact | Description |
|----------|-------------|
| `design-options` | 3+ evaluated design alternatives |
| `decision-record` | Architecture decision with rationale |
| `brainstorm-output` | Raw ideation output |
| `skill-family-design` | Design for a new skill domain |
| `innovation-proposal` | High-conviction innovation recommendation |

### Planning — Structured work plans

| Artifact | Description |
|----------|-------------|
| `phased-plan` | Multi-phase execution plan |
| `todo-items` | Discrete work items / tasks |
| `task-breakdown` | Decomposed work into subtasks |
| `fallback-plan` | Contingency plan for top risks |
| `retrospective-notes` | Lessons learned from a phase |
| `progress-report` | Status update for tracked implementation |

### Code — Source code artifacts

| Artifact | Description |
|----------|-------------|
| `code-changes` | Modified source code (diff or files) |
| `implementation` | Completed feature implementation |
| `refactored-code` | Complexity-reduced code |
| `typed-code` | TypeScript strict-mode compliant code |
| `test-suite` | Test files produced by TDD |
| `implemented-code` | Code produced by sub-agent dispatch |
| `merge-ready-branch` | Branch ready for merge after review |

### Review — Code review artifacts

| Artifact | Description |
|----------|-------------|
| `review-feedback` | Reviewer findings and recommendations |
| `review-request-file` | File-protocol review request (request.md) |
| `review-response-file` | File-protocol review response (response.md) |
| `review-report` | Structured review summary |

### Verification — Quality gate outputs

| Artifact | Description |
|----------|-------------|
| `verification-report` | Generic pass/fail verification result |
| `lint-results` | Linter output |
| `test-results` | Test runner output |
| `convention-report` | Convention compliance check result |
| `plan-validation-report` | Quality gate result for plans |
| `language-audit-report` | Professional language scan result |
| `ip-audit-report` | IP/proprietary content scan result |
| `security-report` | Security vulnerability scan result |
| `diagnostic-report` | Superpowers ecosystem health report |
| `skill-health-report` | Skill structural lint results |
| `coherence-report` | Wiki content coherence analysis |
| `markdown-structure-report` | Wiki markdown structure validation |
| `safety-verdict` | Security gate pass/fail |
| `rigor-checklist` | Engineering rigor compliance check |
| `verified-metric` | Cross-validated numeric claim |
| `validation-report` | Requirements validation output |

### Documentation — Written content

| Artifact | Description |
|----------|-------------|
| `wiki-content` | Wiki page content (input state) |
| `updated-wiki-content` | Wiki page content (output state, post-edit) |
| `wiki-plan` | Plan for wiki changes |
| `readme-draft` | README file content |
| `markdown-content` | Generic markdown text |
| `enriched-content` | Content merged with research |
| `quality-prose` | De-slopped, high-quality text |
| `sanitized-content` | Content with secrets removed |
| `verified-facts` | Fact-checked content |
| `verified-links` | Link-validated content |
| `verified-comment` | Evidence-backed issue comment |
| `created-issue` | Newly created tracking issue/ticket |
| `updated-issue` | Modified issue/ticket |
| `analysis-prompt` | Self-generated analysis prompt |
| `content-inventory` | Catalog of existing content |
| `validated-table` | Correctly formatted markdown table |
| `prose-quality-report` | Writing style assessment |

### Research — External information

| Artifact | Description |
|----------|-------------|
| `research-results` | Synthesized research findings |
| `web-findings` | Raw web search results |
| `domain-knowledge` | Extracted expert knowledge |
| `interview-artifact` | Structured interview output |

### Meta — Process and system management

| Artifact | Description |
|----------|-------------|
| `skill-updates` | Proposed skill improvements |
| `new-skill` | Newly created skill file |
| `skill-catalog` | Enumerated list of installed skills |
| `agents-config` | Generated AGENTS.md configuration |
| `updated-installation` | Freshly updated skill installation |
| `captured-loose-end` | Deferred work item detected by guardian |
| `archived-tasks` | Tasks moved to archive |
| `branch-name` | Generated branch name |
| `routed-skill-output` | Output from thinking-orchestrator dispatch |
| `upgraded-dependencies` | Dependencies with CVE fixes applied |

## Capability Categories

| Capability | Description |
|------------|-------------|
| `orchestrates-workflow` | Manages multi-step flows |
| `sequences-skills` | Chains skills in order |
| `routes-skills` | Dispatches to the correct skill |
| `analyzes-code` | Examines source code |
| `analyzes-content` | Examines written content |
| `debugs-issues` | Investigates bugs |
| `evaluates-options` | Compares alternatives |
| `generates-ideas` | Produces creative options |
| `generates-designs` | Produces design alternatives |
| `generates-docs` | Produces documentation |
| `generates-tests` | Produces test cases |
| `generates-skills` | Creates new skill files |
| `generates-prompts` | Produces analysis prompts |
| `generates-contingency` | Produces fallback plans |
| `generates-guidance` | Produces repo configuration |
| `reviews-code` | Evaluates code quality |
| `reviews-design` | Evaluates design quality |
| `verifies-output` | Confirms output correctness |
| `gates-quality` | Blocks on quality failure |
| `gates-decisions` | Blocks until quantified |
| `validates-links` | Checks URL validity |
| `validates-facts` | Checks factual accuracy |
| `validates-requirements` | Checks requirement quality |
| `validates-structure` | Checks structural correctness |
| `validates-markdown` | Checks markdown formatting |
| `validates-style` | Checks coding style |
| `validates-prose` | Checks writing quality |
| `validates-completeness` | Checks exhaustive coverage |
| `scans-language` | Scans for unprofessional language |
| `scans-ip` | Scans for proprietary IP |
| `scans-secrets` | Scans for leaked secrets |
| `scans-cves` | Scans for known vulnerabilities |
| `detects-bias` | Detects confirmation bias |
| `detects-deferral` | Detects deferred work |
| `detects-incompleteness` | Detects incomplete work |
| `detects-injection` | Detects prompt injection |
| `detects-vulnerabilities` | Detects security issues |
| `traces-consumers` | Finds all code consumers |
| `traces-data-flow` | Traces field usage across services |
| `breaks-loops` | Breaks circular reasoning |
| `fresh-analysis` | Provides zero-context analysis |
| `post-mortem-analysis` | Analyzes failures retrospectively |
| `extracts-lessons` | Derives preventive actions |
| `extracts-knowledge` | Captures domain expertise |
| `implements-feedback` | Applies reviewer suggestions |
| `dispatches-review` | Sends code for review |
| `parallel-review` | Runs multiple reviewers |
| `reduces-complexity` | Simplifies complex code |
| `refactors-code` | Restructures code |
| `enforces-conventions` | Applies naming/style rules |
| `enforces-standards` | Applies engineering standards |
| `enforces-types` | Applies TypeScript strictness |
| `enforces-tdd` | Enforces test-first workflow |
| `manages-tasks` | CRUD operations on tasks |
| `archives-tasks` | Moves tasks to history |
| `captures-todos` | Creates tasks from loose ends |
| `tracks-progress` | Maintains implementation status |
| `persists-state` | Saves state across sessions |
| `searches-web` | Queries external sources |
| `synthesizes-sources` | Combines multiple sources |
| `merges-research` | Integrates research into docs |
| `preserves-voice` | Maintains document tone |
| `creates-issues` | Creates tracking tickets |
| `edits-issues` | Modifies existing tickets |
| `validates-duplicates` | Checks for duplicate tickets |
| `validates-assertions` | Verifies comment claims |
| `verifies-issues` | Confirms issue existence |
| `verifies-contracts` | Validates API contracts |
| `verifies-facts` | Checks content accuracy |
| `verifies-repo-health` | Checks repo CI/structure |
| `cross-validates-metrics` | Double-checks numeric claims |
| `enumerates-skills` | Lists installed skills |
| `diagnoses-health` | Runs diagnostic checks |
| `validates-skills` | Validates skill structure |
| `updates-skills` | Upgrades skill installation |
| `self-improves` | Improves skills from logs |
| `pattern-extraction` | Identifies recurring patterns |
| `file-protocol-review` | Review via file I/O |
| `upgrades-packages` | Updates vulnerable deps |
| `inverts-search` | Searches for disconfirming evidence |
| `reframes-analysis` | Restructures analysis approach |
| `fixes-tests` | Resolves test failures |
| `scores-quality` | Produces numeric quality score |
| `crawls-wiki` | Traverses wiki page tree |
| `deduplicates-content` | Removes content duplication |
| `rewrites-pages` | Restructures wiki pages |
| `reviews-content` | Evaluates content quality |
| `searches-history` | Queries archived tasks |
| `structures-interviews` | Guides expert questioning |
| `designs-domains` | Plans new skill families |
| `multi-perspective-ideation` | Generates diverse ideas |
| `quantifies-tradeoffs` | Numeric option comparison |
| `blocks-destructive-ops` | Prevents harmful operations |
| `eliminates-slop` | Removes AI writing patterns |
| `analyzes-writing` | Evaluates text quality |
| `continuous-improvement` | Iterates between phases |

## Priority Scale

| Range | Tier | Description |
|-------|------|-------------|
| 1–5 | Security / Orchestration | Fire first: safety gates, workflow coordinators |
| 5–15 | Primary processing | Core analysis, debugging, planning skills |
| 15–25 | Supporting | Implementation tracking, content creation, verification |
| 25–35 | Quality gates | Review, audit, validation skills |
| 35–45 | Formatting / conventions | Style enforcement, language audit |
| 45–55 | Heavy-weight operations | Wiki refactoring, catalog generation |

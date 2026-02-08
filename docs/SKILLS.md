# Skills: Goals & Outcomes

> **CRITICAL**: These GOALS/OUTCOMES define what each skill MUST accomplish. If a skill fails to achieve its goals, it is useless and should be fixed or deprecated.

---

## detecting-ai-slop

**Goal:** Identify AI-generated content by detecting telltale patterns (boosters, hedging, clichés, uniformity) and produce an actionable slop score.

**Success Criteria:**
- [ ] Score accurately reflects AI-generation likelihood (0-100)
- [ ] Human-written text scores <30 consistently
- [ ] Obvious AI slop scores >60 consistently
- [ ] Breakdown identifies SPECIFIC patterns, not vague categories
- [ ] Stylometric metrics (sentence σ, TTR, hapax) calculated correctly

**Expected Outcomes:**
1. User pastes text → receives numeric score + pattern breakdown in <5 seconds
2. Score matches human intuition (calibrated via user samples)
3. Actionable fixes: each flagged pattern has a concrete fix suggestion
4. Content-type detection adjusts thresholds appropriately (email vs PRD)

**Failure Modes:**
- ❌ High scores on obviously human text (false positive)
- ❌ Low scores on ChatGPT-generated text (false negative)
- ❌ Vague output: "some issues detected" without specifics
- ❌ Takes >30 seconds to analyze reasonable-length text

**Invoke:** "What's the slop score on this [content type]?"

---

## eliminating-ai-slop

**Goal:** Transform AI-like text into human-quality writing by eliminating detected patterns while preserving meaning and adding specificity.

**Success Criteria:**
- [ ] GVR loop reduces slop score by ≥30 points
- [ ] Output passes stylometric thresholds (sentence σ >3, TTR >0.45)
- [ ] Meaning preserved—no information loss
- [ ] Matches target voice when calibrated
- [ ] Max 3 GVR iterations (prevents infinite loops)

**Expected Outcomes:**
1. Input text with score 70 → output text with score <40
2. User can verify before/after with side-by-side comparison
3. Transparency report explains what changed and why
4. Personal dictionary updates persist across sessions

**Failure Modes:**
- ❌ Output loses critical information
- ❌ Rewritten text sounds generic or loses voice
- ❌ Infinite GVR loops (>3 iterations)
- ❌ No improvement after rewriting

**Invoke:**
- Interactive: "Clean up this email: [text]"
- Automatic: "Write an email to the team about [topic]"
- Calibrate: "Calibrate slop detection with my writing"

---

## enforce-style-guide

**Goal:** Prevent non-compliant code from being committed by enforcing repository-specific and language-specific standards.

**Success Criteria:**
- [ ] Runs automatically before every commit
- [ ] Checks ALL mandatory requirements from style guides
- [ ] Reports violations with file:line references
- [ ] Provides fix suggestions or auto-fixes where possible
- [ ] Re-validates after fixes

**Expected Outcomes:**
1. User attempts commit → skill audits all changed files
2. Violations listed with actionable fix instructions
3. After fixes, re-audit confirms compliance
4. No non-compliant code reaches the repository

**Failure Modes:**
- ❌ Misses obvious violations (false negative)
- ❌ Flags compliant code (false positive)
- ❌ Vague error: "style violation" without location
- ❌ Skipped for some commits (inconsistent enforcement)

**Invoke:** Before ANY commit to ANY repository.

---

## golden-agents

**Goal:** Initialize or upgrade AI guidance in any repository using the golden-agents framework, with auto-detection of repo state and language.

**Success Criteria:**
- [ ] Detects git state (no repo, existing repo, existing guidance)
- [ ] Auto-detects languages and project type from files
- [ ] Presents findings for user confirmation before proceeding
- [ ] Creates all redirect files (CLAUDE.md, CODEX.md, GEMINI.md, COPILOT.md)
- [ ] Preserves project-specific content during upgrades

**Expected Outcomes:**
1. New repo → git init + generate Agents.md + redirects
2. Existing repo without guidance → generate Agents.md + redirects
3. Existing guidance with markers → safe upgrade preserving custom rules
4. Existing guidance without markers → interactive migrate/replace choice

**Failure Modes:**
- ❌ Overwrites custom project rules without backup
- ❌ Generates without confirming detected language/type
- ❌ Forgets redirect files (only creates Agents.md)
- ❌ Commits without user permission

**Invoke:** When setting up new repos, adding AI guidance, or upgrading outdated Agents.md files.

---

## incorporating-research

**Goal:** Integrate external research (Perplexity, web, ChatGPT) into existing documents by stripping citation artifacts and matching document voice.

**Success Criteria:**
- [ ] Citation artifacts (numbers, source sections) removed
- [ ] Document voice/tone preserved after integration
- [ ] Only relevant content extracted (triage works)
- [ ] User confirms scope before any edits
- [ ] No duplicate content introduced

**Expected Outcomes:**
1. User pastes Perplexity output → skill triages relevant vs noise
2. Skill proposes specific insertions with location
3. User confirms → content integrated matching existing style
4. Original document structure preserved



---

## perplexity-research

**Goal:** Automatically invoke Perplexity when the AI assistant is stuck, uncertain, or at risk of hallucinating—then evaluate if the research actually helped.

**Success Criteria:**
- [ ] Auto-triggers on 2+ failed attempts at same operation
- [ ] Auto-triggers on uncertainty/guessing
- [ ] Uses correct Perplexity tool (ask vs research vs search)
- [ ] 4-step evaluation loop: Report → Apply → Evaluate → Track
- [ ] Stats only recorded AFTER evaluating helpfulness

**Expected Outcomes:**
1. AI hits wall → Perplexity invoked automatically
2. Response summarized, then APPLIED to the problem
3. Outcome evaluated: SUCCESS (fixed it), PARTIAL (helped some), FAILURE (didn't help)
4. Stats tracked with outcome, enabling success rate analysis

**Failure Modes:**
- ❌ Perplexity called but response not applied (wasted API call)
- ❌ Stats recorded before knowing if it helped (inflated success rates)
- ❌ Over-triggers on easy problems (wastes API quota)
- ❌ Never triggers even when clearly stuck

**Invoke:** Automatic, or manual: "Use Perplexity to research X"

---

## security-upgrade

**Goal:** Systematically scan for CVEs, upgrade vulnerable dependencies, and verify fixes across all supported package managers.

**Success Criteria:**
- [ ] All package managers scanned (npm, Go, Python, Rust, Flutter)
- [ ] CVEs identified with severity and fix versions
- [ ] Upgrades applied one at a time with testing
- [ ] Breaking changes detected and addressed
- [ ] Post-upgrade verification confirms fixes

**Expected Outcomes:**
1. User invokes → full vulnerability scan across all ecosystems
2. CVEs listed with severity, affected package, fix version
3. Each upgrade tested before proceeding to next
4. Final verification shows 0 vulnerabilities (or documented exceptions)

**Failure Modes:**
- ❌ Misses vulnerabilities (incomplete scan)
- ❌ Bulk upgrades break the build
- ❌ Upgrades applied without testing
- ❌ Says "done" but vulnerabilities remain

**Invoke:** "Scan for CVEs" or "Upgrade dependencies"

---

## reviewing-ai-text *(DEPRECATED)*

**Goal:** N/A — Use `detecting-ai-slop` and `eliminating-ai-slop` instead.

This skill is deprecated. It has been superseded by the more capable slop detection and elimination skills which provide:
- Better pattern detection (300+ patterns vs original ~50)
- GVR loop for automatic rewriting
- Stylometric analysis
- Cross-machine dictionary sync
- "Add this to [file]"

---

## experimental-self-prompting ⚠️ EXPERIMENTAL

> **WARNING**: This skill is in the experimental section. See `skills/experimental/README.md` for usage guidelines.

**Goal:** Gain fresh perspective and discover hidden issues by writing comprehensive, context-free prompts before analyzing complex systems.

**Status:** Validated in 20-round experiment, but NOT production-ready.

**Location:** `skills/experimental/experimental-self-prompting/SKILL.md`

**Scientific Basis:** Validated through 20-round 2x2 factorial experiment comparing reframing × external model conditions. Condition B (Reframe-Self) won with highest VH (21) and lowest HR rate (20%).

**Known Limitations:**
- ⚠️ Only tested on 5 genesis-tools projects
- ⚠️ ~20% false positive rate (target: <15%)
- ⚠️ No automated verification pipeline
- ⚠️ DO NOT use with external models (100% HR rate)

**Graduation Criteria:**
- [ ] Tested on 10+ diverse codebases
- [ ] False positive rate consistently <15%
- [ ] Automated verification integrated
- [ ] User feedback loop established

**Invoke:** `Use the experimental-self-prompting skill to analyze [system]`

---

## think-twice

**Goal:** Break through blockers by distilling problems into comprehensive briefs and dispatching to sub-agents for fresh perspective.

**Relationship to self-prompting:** Think-twice is a *different methodology* from self-prompting. Both use sub-agents with context-free prompts, but:
- **self-prompting**: Focuses on code analysis with adversarial review prompts
- **think-twice**: Focuses on getting unstuck with consultation prompts + scoring

**Success Criteria:**
- [ ] Auto-detects stuck signals (2+ failed attempts, circular reasoning)
- [ ] Consultation prompt is fully self-contained (<2000 tokens)
- [ ] Sub-agent response scored on 4 dimensions (relevance, novelty, specificity, feasibility)
- [ ] Retry logic triggers when score <50
- [ ] User confirms recommendation resolved blocker

**Expected Outcomes:**
1. User stuck on problem → skill suggests Think Twice
2. Consultation prompt captures problem, context, what was tried, constraints
3. Sub-agent response scored and synthesized
4. Suggested next step resolves blocker in ≥60% of cases

**Failure Modes:**
- ❌ Over-triggering on easy problems (wastes resources)
- ❌ Consultation prompt too vague (unhelpful responses)
- ❌ Sub-agent response not scored (no quality signal)
- ❌ Infinite retries (max 1 retry)

**Explicit Triggers:**
- "think twice" / "get unstuck" / "I'm stuck"
- "try a different approach" / "second opinion"
- "fresh eyes" / "phone a friend"

**Invoke:** When stuck on coding/technical problems, or when user says "think twice".


# superpowers-plus

> **Guidelines:** See [CLAUDE.md](./CLAUDE.md) for writing standards.
> **Last Updated:** 2026-01-31

Personal skills extending [obra/superpowers](https://github.com/obra/superpowers) for Claude Code, Augment Code, and Codex.

## Overview

This repository contains custom AI coding assistant skills that build on the superpowers framework. These personal skills extend the core superpowers with domain-specific capabilities for AI slop detection, resume screening, and code quality enforcement.

## Installation

```bash
# Clone this repo
git clone https://github.com/bordenet/superpowers-plus.git
cd superpowers-plus

# Install obra/superpowers (if not present) and all skills
./install.sh
```

The install script:
- Clones obra/superpowers to `~/.codex/superpowers/` if not already installed
- Installs all skills from this repo to `~/.codex/skills/`
- Validates the installation

Use `./install.sh --verbose` for detailed output or `./install.sh --force` to reinstall superpowers.

## Perplexity MCP Integration

The `perplexity-research` skill enables AI assistants to automatically consult Perplexity when stuck.

### Quick Install (New Machine)

```bash
# 1. Clone this repo
git clone https://github.com/bordenet/superpowers-plus.git
cd superpowers-plus

# 2. Install base superpowers and skills
./install.sh

# 3. Configure Perplexity MCP (requires API key)
./setup/mcp-perplexity.sh

# 4. Install the perplexity-research skill
./setup/install-perplexity-skill.sh

# 5. Verify everything works
./setup/verify-perplexity-setup.sh
```

### Automatic Triggers

The skill auto-invokes when:
- **2+ failed attempts** at the same operation
- **Uncertainty/guessing** at an answer
- **Hallucination risk** (unsure about APIs/facts)
- **Outdated knowledge** (post-training topics)

### Manual Override

Say: "Use Perplexity to research X" or "Get unstuck on X"

### Stats Tracking

Stats are tracked in `~/.codex/perplexity-stats.json`:
```bash
cat ~/.codex/perplexity-stats.json | jq .
```

The skill uses a 4-step evaluation loop:
1. **Report** - Summarize Perplexity response
2. **Apply** - Actually use the information
3. **Evaluate** - Judge if it helped (SUCCESS/PARTIAL/FAILURE)
4. **Track** - Record stats only after evaluation

---

## Skills Overview

| Skill | Purpose |
|-------|---------|
| `detecting-ai-slop` | Analyze text and produce bullshit factor scores (0-100) |
| `eliminating-ai-slop` | Rewrite text to remove slop patterns |
| `enforce-style-guide` | Enforce coding standards before commits |
| `incorporating-research` | Incorporate external research into docs (strips artifacts, preserves voice) |
| `perplexity-research` | Auto-invoke Perplexity when stuck (2+ failures, uncertainty) |
| `resume-screening` | Screen Senior SDE candidates against hiring criteria |
| `phone-screen-prep` | Prepare phone screen notes with targeted questions |
| `reviewing-ai-text` | *(Deprecated)* Use detecting-ai-slop and eliminating-ai-slop instead |
| `security-upgrade` | CVE scanning and dependency upgrade workflow |

---

## Skills: Goals & Outcomes

> **CRITICAL**: These GOALS/OUTCOMES define what each skill MUST accomplish. If a skill fails to achieve its goals, it is useless and should be fixed or deprecated.

### detecting-ai-slop

**Goal:** Identify AI-generated content by detecting telltale patterns (boosters, hedging, clichés, uniformity) and produce an actionable bullshit factor score.

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

**Invoke:** "What's the bullshit factor on this [content type]?"

---

### eliminating-ai-slop

**Goal:** Transform AI-like text into human-quality writing by eliminating detected patterns while preserving meaning and adding specificity.

**Success Criteria:**
- [ ] GVR loop reduces bullshit factor by ≥30 points
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

### enforce-style-guide

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

### incorporating-research

**Goal:** Seamlessly integrate external research (Perplexity, web, ChatGPT) into existing documents while stripping artifacts and preserving document voice.

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

**Failure Modes:**
- ❌ Artifacts remain in final document (e.g., "[1]" citations)
- ❌ Integrated content clashes with document voice
- ❌ Entire paste incorporated without triage
- ❌ Edits made without user confirmation

**Invoke:**
- "Incorporate this Perplexity output into [doc]"
- "Merge this research into the doc"
- "Add this to [file]"

---

### perplexity-research

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

### resume-screening

**Goal:** Efficiently screen Senior SDE candidates against hiring criteria, flagging concerns and generating targeted phone screen questions.

**Success Criteria:**
- [ ] Work authorization checked FIRST (reject if needs sponsorship)
- [ ] 5+ years qualifying SWE experience verified
- [ ] Contractor patterns detected and flagged
- [ ] Salary alignment validated against cap
- [ ] AI slop detected in resumes/responses
- [ ] Phone screen questions target identified concerns

**Expected Outcomes:**
1. User pastes resume → HIRE/NO HIRE/PROBE decision in <30 seconds
2. Phone screen questions generated for each concern
3. Loop questions generated for deeper probing
4. AI slop flagged if detected in resume or responses

**Failure Modes:**
- ❌ Misses sponsorship requirement (wastes interview time)
- ❌ Passes unqualified candidate (< 5 years SWE)
- ❌ Rejects strong candidate on technicality (over-filtering)
- ❌ Generic questions instead of targeted probes

**Invoke:**
- "Screen at $[X]k cap" + paste resume
- "What's the bullshit factor on this resume?" (slop analysis)

---

### phone-screen-prep

**Goal:** Create phone screen notes files with targeted questions based on screening concerns, ready for the interviewer.

**Success Criteria:**
- [ ] Template copied and placeholders replaced
- [ ] Targeted questions added for each screening concern
- [ ] AI slop probing questions added when bullshit factor >50
- [ ] File named correctly (FirstName_LastName__YYYY-MM-DD.md)
- [ ] Links populated (Paylocity, GitHub, LinkedIn)

**Expected Outcomes:**
1. User requests prep → file created in correct location
2. Concerns from resume screening → targeted questions in file
3. High AI slop → explicit authenticity probing questions added
4. File ready for interviewer to use during call

**Failure Modes:**
- ❌ Wrong file location or naming
- ❌ Missing targeted questions (generic template only)
- ❌ AI slop concerns not translated to probe questions
- ❌ Links/placeholders not populated

**Invoke:** "Prep phone screen for [Name]"

---

### security-upgrade

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

### reviewing-ai-text *(DEPRECATED)*

**Goal:** N/A — Use `detecting-ai-slop` and `eliminating-ai-slop` instead.

This skill is deprecated. It has been superseded by the more capable slop detection and elimination skills which provide:
- Better pattern detection (300+ patterns vs original ~50)
- GVR loop for automatic rewriting
- Stylometric analysis
- Cross-machine dictionary sync

## Cross-Machine Sync

The `slop-sync` script synchronizes your slop dictionary across machines via GitHub:

```bash
# Initialize (first time only)
./slop-sync init

# Upload dictionary after changes
./slop-sync push

# Download latest on another machine
./slop-sync pull

# Check sync status
./slop-sync status
```

Uses Last Write Wins conflict resolution based on timestamps.

## Directory Structure

```
superpowers-plus/
├── CLAUDE.md                       # AI agent guidelines and anti-slop rules
├── TODO.md                         # Task tracking
├── README.md                       # This file
├── LICENSE
├── install.sh                      # Install superpowers and skills
├── slop-sync                       # Cross-machine dictionary sync script
├── .gitignore
├── docs/
│   ├── Vision_PRD.md               # High-level vision and requirements
│   ├── PRD_detecting-ai-slop.md    # Detector skill requirements
│   ├── PRD_eliminating-ai-slop.md  # Eliminator skill requirements
│   ├── DESIGN.md                   # Technical design
│   └── TEST_PLAN.md                # Test plan (80+ test cases)
└── skills/
    ├── detecting-ai-slop/          # Analysis and scoring (300+ patterns)
    │   └── SKILL.md
    ├── eliminating-ai-slop/        # Rewriting and prevention (GVR loop)
    │   └── SKILL.md
    ├── enforce-style-guide/
    │   └── SKILL.md
    ├── incorporating-research/     # Incorporate external research (strips artifacts)
    │   └── SKILL.md
    ├── resume-screening/           # Integrates with detecting-ai-slop
    │   ├── SKILL.md
    │   └── README.md
    ├── phone-screen-prep/          # Adds AI slop probing questions
    │   ├── SKILL.md
    │   └── README.md
    └── reviewing-ai-text/          # Deprecated
        └── SKILL.md
```

## Creating New Skills

1. Create a new directory under `skills/`
2. Add `SKILL.md` with frontmatter (name, description)
3. Run `./install.sh` to deploy
4. Test with `~/.codex/superpowers/.codex/superpowers-codex use-skill <skill-name>`

See [superpowers:writing-skills](https://github.com/obra/superpowers) for skill authoring guidelines.

## Documentation

| Document | Purpose |
|----------|---------|
| [Vision_PRD.md](./docs/Vision_PRD.md) | High-level vision and requirements |
| [PRD_detecting-ai-slop.md](./docs/PRD_detecting-ai-slop.md) | Detector requirements (13 content types) |
| [PRD_eliminating-ai-slop.md](./docs/PRD_eliminating-ai-slop.md) | Eliminator requirements (11 rewriting strategies) |
| [DESIGN.md](./docs/DESIGN.md) | Technical architecture |
| [TEST_PLAN.md](./docs/TEST_PLAN.md) | Test plan (80+ test cases) |

## Author

Matt J Bordenet (@bordenet)

# TODO - superpowers-plus

> **Last Updated:** 2026-01-24
> **Status:** Active Development - Architecture Pivot
> **Primary Focus:** Bifurcating into detecting-ai-slop + eliminating-ai-slop skills
> **Guidelines:** See [CLAUDE.md](./CLAUDE.md) for writing standards.

This document tracks all work items for the superpowers-plus repository. Update this file as tasks progress.

---

## Cross-References

| Document | Purpose | Status |
|----------|---------|--------|
| [CLAUDE.md](./CLAUDE.md) | AI agent guidelines and anti-slop rules | ✅ Complete |
| [README.md](./README.md) | Repository overview | 🔄 Needs update |
| [docs/Vision_PRD.md](./docs/Vision_PRD.md) | High-level vision and requirements | ✅ Complete |
| [docs/PRD_detecting-ai-slop.md](./docs/PRD_detecting-ai-slop.md) | Detector skill requirements | 📝 Draft |
| [docs/PRD_eliminating-ai-slop.md](./docs/PRD_eliminating-ai-slop.md) | Eliminator skill requirements | 📝 Draft |
| [docs/DESIGN.md](./docs/DESIGN.md) | Technical design | 🔄 Needs revision |
| [docs/TEST_PLAN.md](./docs/TEST_PLAN.md) | Test plan | 🔄 Needs revision |

---

## Architecture Decision (2026-01-24)

**Decision:** Bifurcate into two skills (Option A from brainstorming session)

| Skill | Purpose | Use Cases |
|-------|---------|-----------|
| `detecting-ai-slop` | Analysis, scoring, bullshit factor | External doc review (CVs), exploratory review |
| `eliminating-ai-slop` | Rewriting, prevention | Clean up drafts, background prevention |

**Rationale:**
1. User needs "bullshit factor" scoring on external documents (read-only)
2. User needs interactive rewriting for own work (with confirmation)
3. User needs background prevention during daily generation (automatic)
4. These are three distinct workflows best served by two focused skills

---

## Current Sprint: Architecture Pivot

### Phase 0: Architecture Pivot 🔄

- [x] **Brainstorm skill architecture** with superpowers:brainstorming
- [x] **Decision:** Two skills (detecting-ai-slop + eliminating-ai-slop)
- [x] **Rename PRD.md to Vision_PRD.md** (high-level vision document)
- [x] **Create PRD_detecting-ai-slop.md** (detector requirements)
- [x] **Create PRD_eliminating-ai-slop.md** (eliminator requirements)
- [x] **Update CLAUDE.md cross-references**
- [x] **Update TODO.md** (this document)
- [ ] **Review and approve Vision_PRD.md** (user approval pending)
- [ ] **Review and approve PRD_detecting-ai-slop.md** (user approval pending)
- [ ] **Review and approve PRD_eliminating-ai-slop.md** (user approval pending)

### Phase 1: Documentation Foundation ✅ (Original Work)

- [x] **Rewrite CLAUDE.md** - Add strict anti-slop writing guidelines
  - [x] Banned phrases list (production-grade, world-class, etc.)
  - [x] Cross-reference requirements for all markdown files
  - [x] Evidence-based claims mandate
  - [x] Pre-commit checklist for documentation

- [x] **Create docs/ folder structure**
  - [x] docs/PRD.md - Product Requirements Document
  - [x] docs/DESIGN.md - Technical Design Document
  - [x] docs/TEST_PLAN.md - Test Plan

### Phase 2: Skill Enhancement (Task 2 - Word Lists) ✅

- [x] **Expand lexical red flags** - Added 180+ phrases across 7 categories
  - [x] Generic boosters (20 entries: incredibly, highly, extremely, etc.)
  - [x] Vague quality words (27 entries: robust, seamless, comprehensive, etc.)
  - [x] Hype words (26 entries: game-changing, leverage, synergy, etc.)
  - [x] Glue phrases (45 entries: it's important to note, let's dive in, etc.)
  - [x] Hedge patterns (28 entries: of course, naturally, in many ways, etc.)
  - [x] Sycophantic phrases (20 entries: great question, happy to help, etc.)
  - [x] Transitional filler (29 entries: furthermore, moreover, etc.)

### Phase 3: Domain-Specific Patterns (Task 3) ✅

- [x] **Technical writing slop** - 12 patterns + 4 red flags
  - [x] API documentation patterns (passive openers, vague error handling)
  - [x] README boilerplate (capability lists, placeholder examples)
  - [x] Code comment slop (changelog filler, version vagueness)

- [x] **Marketing/business slop** - 12 patterns + 4 red flags
  - [x] Press release patterns (unsubstantiated leadership, partnership filler)
  - [x] Product description slop (transformation promises, satisfaction claims)
  - [x] Executive summary patterns (ROI promises, mission filler)

- [x] **Academic/research slop** - 12 patterns + 4 red flags
  - [x] Literature review patterns (vague attribution, gap clichés)
  - [x] Methodology boilerplate (passive voice, significance claims)

### Phase 4: Advanced Detection (Task 1) ✅

- [x] **Stylometric features** - 6 detection methods with heuristics
  - [x] Sentence length variance detection (with range calculation)
  - [x] Type-token ratio analysis (with thresholds)
  - [x] Hapax legomena frequency (40-60% target)

- [x] **Statistical signals**
  - [x] Zipf deviation detection (proper noun check)
  - [x] Entropy pattern analysis (predictability test)
  - [x] N-gram repetition check (Ctrl+F method)

### Phase 5: Testing (Task 4) ✅

- [x] **Install and test skill**
  - [x] Run ./install.sh - 4 skills installed to ~/.codex/skills/
  - [x] Verify skill loads with use-skill command - loads 597 lines
  - [x] Skill contains 230+ patterns across 7 lexical categories
  - [x] Skill contains 36 domain-specific patterns (12 per domain)
  - [x] Skill contains 6 stylometric detection methods

### Phase 6: Finalization (Original Work) ⏸️ PAUSED

- [x] Commit and push original work (commit 3bc960d)
- [ ] ~~Run pre-commit checklist~~ (paused for architecture pivot)

---

## Implementation Strategy

**Approach:** Iterative development with real-world validation

1. **Detection First** - Build and validate detecting-ai-slop before eliminating-ai-slop
2. **Real Document Testing** - Use actual wiki markdown document as validation corpus
3. **Collaborative Refinement** - User and agent jointly evaluate detection quality
4. **Sequential Skills** - Only proceed to eliminator after detector is validated

---

## Next Phases (Post PRD Approval)

### Phase 7: Design and Test Plan Revision

- [ ] **Revise DESIGN.md** for two-skill architecture
  - [ ] Detection skill architecture
  - [ ] Elimination skill architecture
  - [ ] Shared infrastructure (dictionary, metrics)
  - [ ] Data flow between skills

- [ ] **Revise TEST_PLAN.md** for two-skill architecture
  - [ ] Detection test cases (bullshit factor scoring)
  - [ ] Elimination test cases (rewriting quality)
  - [ ] Integration test cases (shared dictionary)
  - [ ] Real-world validation protocol

### Phase 8: Detector Implementation

- [ ] **Create detecting-ai-slop skill**
  - [ ] Create skills/detecting-ai-slop/SKILL.md
  - [ ] Migrate detection patterns from reviewing-ai-text
  - [ ] Implement bullshit factor scoring (0-100)
  - [ ] Implement score breakdown by dimension
  - [ ] Implement pattern location reporting

- [ ] **First Trial: Detection Validation**
  - [ ] User provides wiki markdown document
  - [ ] Run detection analysis, report all flagged patterns
  - [ ] User and agent jointly evaluate detection quality
  - [ ] Identify false positives (flagged but acceptable)
  - [ ] Identify false negatives (missed slop)
  - [ ] Refine detection algorithms based on findings
  - [ ] Iterate until detection quality is satisfactory

### Phase 9: Eliminator Implementation

- [ ] **Create eliminating-ai-slop skill**
  - [ ] Create skills/eliminating-ai-slop/SKILL.md
  - [ ] Implement interactive rewriting mode
  - [ ] Implement confirmation prompts
  - [ ] Implement automatic prevention mode
  - [ ] Implement activation control

- [ ] **Second Trial: Rewriting Validation**
  - [ ] Apply eliminator to same wiki markdown document
  - [ ] Interactively work through flagged patterns
  - [ ] User approves/rejects proposed rewrites
  - [ ] Evaluate rewrite quality (meaning preservation)
  - [ ] Refine rewriting algorithms based on findings

### Phase 10: Shared Infrastructure

- [ ] **Implement persistent dictionary**
  - [ ] Dictionary file format
  - [ ] Workspace root storage
  - [ ] .gitignore auto-update
  - [ ] Read/write operations

- [ ] **Implement metrics tracking**
  - [ ] Metrics file format
  - [ ] Detection metrics (bullshit factors, patterns)
  - [ ] Rewriting metrics (fixes, user feedback)

### Phase 11: Final Validation

- [ ] **Return to wiki markdown document**
  - [ ] Run full detection + elimination pipeline
  - [ ] Compare before/after quality
  - [ ] Measure against success metrics from PRD
  - [ ] Document lessons learned

- [ ] **Deprecate reviewing-ai-text**
  - [ ] Mark as deprecated in SKILL.md
  - [ ] Point users to new skills
  - [ ] Update install.sh

- [ ] **Cross-machine validation**
  - [ ] Test on all 3 machines
  - [ ] Verify dictionary sync
  - [ ] Verify consistent behavior

---

## Completed Tasks

### 2026-01-24

- [x] Initialize superpowers-plus repository
- [x] Copy skills from mb_scratchpad and scripts repo
- [x] Create initial README.md and CLAUDE.md
- [x] Push initial commit to origin main
- [x] Enhance reviewing-ai-text with 180+ patterns (Phase 2-4)
- [x] Commit and push enhanced skill (commit 3bc960d)
- [x] Brainstorm bifurcation with superpowers:brainstorming
- [x] Decision: Two skills (detecting-ai-slop + eliminating-ai-slop)
- [x] Create Vision_PRD.md, PRD_detecting-ai-slop.md, PRD_eliminating-ai-slop.md

---

## Backlog (Future Work)

- [ ] Add stylometric calibration with user samples
- [ ] Create CI/CD for skill validation
- [ ] Add skill versioning
- [ ] Multi-language support (Phase 2)
- [ ] Batch processing mode for document libraries

---

## Notes

### Anti-Slop Writing Rules (Preview)

These rules will be formalized in CLAUDE.md:

1. **No celebratory language** - No "excellent", "great", "amazing" about our own work
2. **No self-promotion** - No "production-grade", "world-class", "enterprise-ready"
3. **Evidence-based claims only** - Every claim needs data, citation, or specific example
4. **Cross-reference all docs** - Every markdown file links to CLAUDE.md and related docs
5. **Kill orphaned docs** - Remove or update any doc not in the cross-reference table

### Skill Testing Approach

1. **Baseline test** - Run without skill, document AI slop in output
2. **Skill test** - Run with skill, verify slop is detected
3. **Rewrite test** - Apply skill's rewrite process, verify improvement


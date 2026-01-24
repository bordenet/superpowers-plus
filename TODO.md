# TODO - superpowers-plus

> **Last Updated:** 2026-01-24
> **Status:** Active Development
> **Primary Focus:** reviewing-ai-text skill enhancement
> **Guidelines:** See [CLAUDE.md](./CLAUDE.md) for writing standards.

This document tracks all work items for the superpowers-plus repository. Update this file as tasks progress.

---

## Cross-References

| Document | Purpose | Status |
|----------|---------|--------|
| [CLAUDE.md](./CLAUDE.md) | AI agent guidelines and anti-slop rules | ✅ Complete |
| [README.md](./README.md) | Repository overview | ✅ Complete |
| [docs/PRD.md](./docs/PRD.md) | Product requirements | ✅ Complete |
| [docs/DESIGN.md](./docs/DESIGN.md) | Technical design | ✅ Complete |
| [docs/TEST_PLAN.md](./docs/TEST_PLAN.md) | Test plan | ✅ Complete |

---

## Current Sprint: reviewing-ai-text Enhancement

### Phase 1: Documentation Foundation ✅

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

### Phase 6: Finalization 🔄

- [ ] **Commit and push**
  - [x] Verify all cross-references valid (all docs link to CLAUDE.md)
  - [ ] Run pre-commit checklist
  - [ ] Push to origin main

---

## Completed Tasks

### 2026-01-24

- [x] Initialize superpowers-plus repository
- [x] Copy skills from mb_scratchpad and scripts repo
- [x] Create initial README.md
- [x] Create initial CLAUDE.md
- [x] Push initial commit to origin main

---

## Backlog (Future Work)

- [ ] Add automated slop detection script
- [ ] Create CI/CD for skill validation
- [ ] Add skill versioning
- [ ] Create skill dependency management
- [ ] Add skill testing framework

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


# TODO - superpowers-plus

> **Last Updated:** 2026-01-25
> **Status:** Enhanced with GVR loop, calibration, and slop-sync
> **Primary Focus:** Real-world validation and testing
> **Guidelines:** See [CLAUDE.md](./CLAUDE.md) for writing standards.

This document tracks all work items for the superpowers-plus repository. Update this file as tasks progress.

---

## Cross-References

| Document | Purpose | Status |
|----------|---------|--------|
| [CLAUDE.md](./CLAUDE.md) | AI agent guidelines and anti-slop rules | ✅ Complete |
| [README.md](./README.md) | Repository overview | ✅ Complete |
| [docs/Vision_PRD.md](./docs/Vision_PRD.md) | High-level vision and requirements | ✅ Complete |
| [docs/PRD_detecting-ai-slop.md](./docs/PRD_detecting-ai-slop.md) | Detector skill requirements (13 content types) | ✅ Complete |
| [docs/PRD_eliminating-ai-slop.md](./docs/PRD_eliminating-ai-slop.md) | Eliminator skill requirements (11 strategies) | ✅ Complete |
| [docs/DESIGN.md](./docs/DESIGN.md) | Technical design (13 content types) | ✅ Complete |
| [docs/TEST_PLAN.md](./docs/TEST_PLAN.md) | Test plan (80+ test cases) | ✅ Complete |

---

## Current Status

### Implemented Features

| Feature | Status | Details |
|---------|--------|---------|
| Two-skill architecture | ✅ Complete | detecting-ai-slop + eliminating-ai-slop |
| 13 content types | ✅ Complete | Document, Email, LinkedIn, SMS, Teams, CLAUDE.md, README, PRD, Design, Test Plan, CV, Cover Letter |
| 300+ detection patterns | ✅ Complete | Universal + type-specific patterns |
| 11 rewriting strategies | ✅ Complete | One per content type |
| GVR loop | ✅ Complete | Generate-Verify-Refine with max 3 iterations |
| Full dictionary schema | ✅ Complete | weight, count, timestamp, source, exception fields |
| Stylometric thresholds | ✅ Complete | Sentence σ, paragraph SD, TTR, hapax rate |
| Calibration mode | ✅ Complete | Personalized thresholds from user samples |
| slop-sync script | ✅ Complete | Cross-machine dictionary sync via GitHub |
| Metrics commands | ✅ Complete | show-slop-stats, export metrics |
| User feedback rescan | ✅ Complete | Immediate rescan after adding patterns |

| Install script | ✅ Complete | Auto-installs obra/superpowers, fault-tolerant |
| Design document | ✅ Complete | Full architecture with all enhancements |
| Test plan | ✅ Complete | 80+ test cases across all content types |

### Skills Inventory

| Skill | Status | Lines | Enhancements |
|-------|--------|-------|--------------|
| detecting-ai-slop | ✅ Enhanced | 920+ | Stylometric thresholds, calibration, metrics |
| eliminating-ai-slop | ✅ Enhanced | 690+ | GVR loop, user feedback rescan, full dictionary schema |
| enforce-style-guide | ✅ Stable | - | - |
| incorporating-research | ✅ Complete | 200+ | Triage, artifact stripping, voice preservation |
| reviewing-ai-text | ⚠️ Deprecated | - | Use detecting/eliminating instead |

---

## Next Steps

### Validation Phase

- [ ] **Real-world testing** - Test skills on actual documents across all 13 content types
- [ ] **Engineering_Culture corpus** - Already analyzed, average score 18/100 (clean)
- [ ] **Calibration testing** - Test calibration with real user samples
- [ ] **GVR loop validation** - Verify 3-iteration limit and threshold checking
- [ ] **slop-sync testing** - Test cross-machine sync workflow


### Future Enhancements

- [ ] Create CI/CD for skill validation
- [ ] Add skill versioning
- [ ] Multi-language support
- [ ] Batch processing mode for document libraries
- [ ] ML-based detection (if heuristics prove insufficient)

---

## Completed Work

### 2026-01-26

- [x] Create incorporating-research skill (200+ lines)
- [x] Test skill installation and invocation
- [x] Update TODO.md with new skill
- [x] Update README.md with new skill

### 2026-01-25 (Session 2)

- [x] Implement GVR loop (Generate-Verify-Refine, max 3 iterations)
- [x] Implement full dictionary schema (weight, count, timestamp, source, exception)
- [x] Implement stylometric thresholds (sentence σ, paragraph SD, TTR, hapax rate)
- [x] Implement calibration mode with user writing samples
- [x] Create slop-sync shell script for cross-machine dictionary sync
- [x] Implement metrics commands (show-slop-stats, export)
- [x] Implement user feedback with immediate rescan
- [x] Update detecting-ai-slop skill (610 → 920+ lines)
- [x] Update eliminating-ai-slop skill (347 → 690+ lines)
- [x] Update DESIGN.md with GVR, calibration, slop-sync
- [x] Update README.md with slop-sync
- [x] Update TODO.md with completed enhancements

### 2026-01-25 (Session 1)

- [x] Expand PRDs to 13 content types (Email, LinkedIn, SMS, Teams, CLAUDE.md, README, PRD, Design, Test Plan, CV, Cover Letter)
- [x] Update DESIGN.md for 13 content types with full architecture
- [x] Update TEST_PLAN.md with 80+ test cases across all content types
- [x] Update install.sh to auto-install obra/superpowers
- [x] Add fault tolerance and --force/--verbose flags to install.sh
- [x] Update .gitignore for MacOS files
- [x] Test install script (fresh install and update paths)
- [x] Analyze Engineering_Culture repository (19 markdown files, avg score 18/100)

### 2026-01-24

- [x] Initialize superpowers-plus repository
- [x] Copy skills from mb_scratchpad and scripts repo
- [x] Create initial README.md and CLAUDE.md
- [x] Push initial commit to origin main
- [x] Enhance reviewing-ai-text with 180+ patterns (Phase 2-4)
- [x] Brainstorm bifurcation with superpowers:brainstorming
- [x] Decision: Two skills (detecting-ai-slop + eliminating-ai-slop)
- [x] Create Vision_PRD.md, PRD_detecting-ai-slop.md, PRD_eliminating-ai-slop.md
- [x] Create detecting-ai-slop skill (610 lines)
- [x] Create eliminating-ai-slop skill (347 lines)

---

## Architecture Reference

### Two-Skill Design

| Skill | Purpose | Mode | Key Features |
|-------|---------|------|--------------|
| detecting-ai-slop | Analysis, scoring, slop score | Read-only | Stylometric thresholds, calibration, metrics |
| eliminating-ai-slop | Rewriting, prevention | Interactive + Automatic (GVR) | GVR loop, user feedback rescan, dictionary management |

### GVR Loop (Generate-Verify-Refine)

```
GENERATE → VERIFY → REFINE → RETURN (or iterate, max 3)
```

### Stylometric Thresholds

| Metric | Target |
|--------|--------|
| Sentence length σ | >15.0 words |
| Paragraph SD | >25 words |
| TTR | 0.50-0.70 |
| Hapax rate | >40% (or calibrated) |

### Content Type Support

| Category | Content Types |
|----------|---------------|
| Communication | Email, LinkedIn, SMS, Teams/Slack |
| Technical Docs | CLAUDE.md, README, PRD, Design Doc, Test Plan |
| Career Docs | CV/Resume, Cover Letter |
| General | Document (default) |

---

## Notes

### Anti-Slop Writing Rules

These rules are enforced in CLAUDE.md:

1. **No celebratory language** - No "excellent", "great", "amazing" about our own work
2. **No self-promotion** - No "production-grade", "world-class", "enterprise-ready"
3. **Evidence-based claims only** - Every claim needs data, citation, or specific example
4. **Cross-reference all docs** - Every markdown file links to CLAUDE.md and related docs

### Testing Approach

1. **Content type detection** - Verify correct type identification
2. **Pattern detection** - Verify patterns flagged correctly
3. **Cross-type isolation** - Verify type-specific patterns don't leak
4. **Rewriting quality** - Verify meaning preservation

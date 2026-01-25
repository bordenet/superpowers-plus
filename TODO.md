# TODO - superpowers-plus

> **Last Updated:** 2026-01-25
> **Status:** Active Development - 13 Content Types Implemented
> **Primary Focus:** Testing and validation across all content types
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
| Install script | ✅ Complete | Auto-installs obra/superpowers, fault-tolerant |
| Design document | ✅ Complete | Full architecture for 13 content types |
| Test plan | ✅ Complete | 80+ test cases across all content types |

### Skills Inventory

| Skill | Status | Lines |
|-------|--------|-------|
| detecting-ai-slop | ✅ Implemented | 610 |
| eliminating-ai-slop | ✅ Implemented | 347 |
| enforce-style-guide | ✅ Stable | - |
| resume-screening | ✅ Stable | 453 |
| phone-screen-prep | ✅ Stable | - |
| reviewing-ai-text | ⚠️ Deprecated | Use detecting/eliminating instead |

---

## Next Steps

### Validation Phase

- [ ] **Real-world testing** - Test skills on actual documents across all 13 content types
- [ ] **Engineering_Culture corpus** - Already analyzed, average score 18/100 (clean)
- [ ] **User feedback integration** - Collect false positives/negatives
- [ ] **Pattern refinement** - Adjust based on validation results

### Future Enhancements

- [ ] Add stylometric calibration with user samples
- [ ] Create CI/CD for skill validation
- [ ] Add skill versioning
- [ ] Multi-language support
- [ ] Batch processing mode for document libraries
- [ ] Cross-machine dictionary synchronization

---

## Completed Work

### 2026-01-25

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

| Skill | Purpose | Mode |
|-------|---------|------|
| detecting-ai-slop | Analysis, scoring, bullshit factor | Read-only |
| eliminating-ai-slop | Rewriting, prevention | Interactive + Automatic |

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

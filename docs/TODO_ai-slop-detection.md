# AI Slop Detection Skill - Future Work

> **Status:** Backlogged  
> **PRD:** [PRD_detecting-ai-slop.md](./PRD_detecting-ai-slop.md)  
> **Created:** 2026-02-08

---

## Summary

The AI Slop Detection Skill PRD is comprehensive but ambitious. This document captures the recommended phased approach for future implementation.

---

## Phase 1: MVP (Priority: High)

Core slop detection with universal document type only.

- [ ] **Slop score (0-100)** with 4-dimension breakdown:
  - Lexical: buzzwords, intensifiers, clichés
  - Structural: paragraph uniformity, list patterns
  - Stylometric: TTR, sentence variance, hapax ratio
  - Semantic: hollow claims, circular logic
- [ ] **Core 50 lexical patterns** (subset of full 150+ library)
- [ ] **Stylometric analysis engine** (TTR, sentence variance, hapax)
- [ ] **Universal document type** only (no content-specific patterns)
- [ ] **CLI output format** with score + top 3 offenders

**Success criteria:** Skill runs on any markdown file, returns score, identifies top patterns.

---

## Phase 2: Content-Specific Patterns (Priority: Medium)

Add pattern libraries for specific document types.

- [ ] **PRD patterns** (FR6.1 in PRD)
- [ ] **Technical design patterns** (FR6.2)
- [ ] **Code review patterns** (FR6.3)
- [ ] **Git commit patterns** (FR6.4)
- [ ] **Email/Slack patterns** (FR6.5)
- [ ] **Meeting notes patterns** (FR6.6)
- [ ] **Documentation patterns** (FR6.7)
- [ ] **Proposal patterns** (FR6.8)
- [ ] **Test plan patterns** (FR6.9)
- [ ] **Comparative assessment** (before/after delta scoring)

**Success criteria:** Auto-detect document type, apply relevant patterns.

---

## Phase 3: Calibration Mode (Priority: Low)

Advanced features for tuning the detector.

- [ ] **Personal calibration** - learn user's authentic voice
- [ ] **Project calibration** - learn project-specific terminology
- [ ] **False positive management** - allowlist legitimate terms
- [ ] **Threshold configuration** - adjust sensitivity

**Success criteria:** Calibration reduces false positives by 50%+.

---

## Phase 4: Integration with Eliminating-AI-Slop (Priority: Low)

Combine detection and remediation into unified workflow.

- [ ] **Detect → Remediate pipeline**
- [ ] **Pre-commit hook integration**
- [ ] **CI/CD integration patterns**

**Success criteria:** One-command slop cleanup workflow.

---

## Key Decisions Pending

| Question | Options | Notes |
|----------|---------|-------|
| Pattern library validation | Manual review vs. LLM-assisted | 150+ patterns need accuracy testing |
| Scoring calibration baseline | Genesis docs vs. external corpus | Need ground truth for tuning |
| Content type detection | Heuristic vs. LLM | Trade-off: speed vs. accuracy |

---

## Related Documents

- [PRD_detecting-ai-slop.md](./PRD_detecting-ai-slop.md) - Full requirements
- [PRD_eliminating-ai-slop.md](./PRD_eliminating-ai-slop.md) - Remediation skill
- [DESIGN.md](./DESIGN.md) - Architecture overview


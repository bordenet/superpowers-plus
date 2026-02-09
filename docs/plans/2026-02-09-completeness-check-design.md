# completeness-check Skill Design

> **Date**: 2026-02-09
> **Status**: Design Phase (Brainstorming Complete)
> **Author**: Matt Bordenet + Claude (with Perplexity review)

## Problem Statement

AI coding assistants frequently leave incomplete work when they:
- Get distracted mid-implementation
- Crash or lose context
- Context-switch away from unfinished tasks
- Exhaust their context window (~70% utilization shows degradation)

This leaves humans out of the loop on where things stood, requiring automated assistance to assess the situation.

**Origin**: Discovered while fixing 13+ broken links in genesis repo's BACKGROUND.md. The Go validator wasn't catching markdown link issues, revealing a gap in our completeness detection.

---

## Decision Log

### Decision 1: Trigger Modes
**Question**: What should be the primary trigger for this skill?
**Options**:
- A) Proactive scan only
- B) Reactive audit only
- C) Both

**Decision**: **C - Both**
**Rationale**: Different use cases require different modes. Proactive catches issues before claiming done; reactive audits accumulated debt.

### Decision 2: Detection Scope
**Question**: What categories of incomplete work should we detect?
**Options**:
- A) Just link/reference integrity
- B) Add TODO/FIXME comments
- C) Add missing test coverage
- D) Comprehensive (all of the above plus more)

**Decision**: **D - Comprehensive**
**Rationale**: Go big. Detect everything we can.

### Decision 3: Full Scope Confirmation
**Question**: Which categories should be out of scope for v1?
**Options**:
- A) All in scope
- B) Skip dead code detection
- C) Skip test coverage gaps
- D) Skip B and C

**Decision**: **A - All in scope**
**Rationale**: Ambitious v1. Use existing tools where available.

### Decision 4: Output Format
**Question**: How should findings be presented?
**Options**:
- A) Score-based (0-100)
- B) Checklist-based (pass/fail)
- C) Severity-based (Critical/Warning/Info)
- D) Hybrid (score + severity + findings)

**Decision**: **D - Hybrid**
**Rationale**: Most comprehensive. Score for quick assessment, severity for prioritization, findings for action.

### Decision 5: Detection Mechanisms
**Question**: How to handle hard-to-detect patterns (dead code, orphans)?
**Options**:
- A) Best effort with caveats
- B) Shell out to existing tools
- C) Both A and B
- D) Defer hard ones to v2

**Decision**: **C - Both**
**Rationale**: Use ESLint/Pylint/staticcheck when available, fall back to heuristics otherwise.

### Decision 6: Skill Name
**Question**: What should we call this skill?
**Options**:
- A) incomplete-work-detection
- B) repo-hygiene-audit
- C) work-in-progress-scanner
- D) completeness-check

**Decision**: **D - completeness-check**
**Rationale**: Pairs nicely with `holistic-repo-verification`. Clear and concise.

### Decision 7: Language Support
**Question**: Which languages get full static analysis?
**Options**:
- A) JavaScript/TypeScript only
- B) JS/TS + Go
- C) JS/TS + Go + Python
- D) Language-agnostic heuristics only

**Decision**: **C with fallback to D**
**Rationale**: Cover the genesis ecosystem (JS/TS, Go) plus Python (common in AI dev). Heuristics for everything else.

---

## Perplexity Review (2026-02-09)

We consulted Perplexity for a second opinion on the design. Key feedback incorporated:

### Additional Detection Categories Added
1. **Implicit Integration Contracts** - verify schema ↔ ORM, API ↔ middleware consistency
2. **Security Policy Violations** - missing rate limiting, parameterized queries
3. **Deployment Readiness** - missing config files, Dockerfiles, IaC
4. **Hallucinated Dependencies** - imports referencing non-existent packages (1 in 5 AI samples!)
5. **Context Exhaustion Patterns** - code quality degrades after ~70% context usage
6. **Happy Path Bias** - missing error handling compared to codebase norms

### Scoring Formula Revised
Original: `Critical: 10, Warning: 5, Info: 2`
Revised: `Critical: 15, Warning: 7, Info: 1` with context multipliers

### Confidence Scoring Added
- **High** (95%+): Broken refs, syntax errors, missing imports
- **Medium** (70-85%): TODOs with context, deprecated APIs
- **Low** (40-60%): Pattern matching, placeholder regex

### Integration Strategy
Don't reimplement—consume existing tools:
- ESLint/Pylint/staticcheck → normalize into categories
- Coverage.py/Istanbul → test gap detection
- Dependency graphs → orphan detection

---

## Open Questions (Revisit Later)

1. **Scoring weights**: Are 15/7/1 the right ratios? Need real-world data.
2. **Context multipliers**: How to detect "security/payment code" automatically?
3. **False positive rates**: Which heuristic checks need tuning?
4. **Performance thresholds**: What's acceptable runtime for proactive mode?

---

## Detection Categories (Final)

| Category | Severity | Confidence | Detection Method |
|----------|----------|------------|------------------|
| Broken internal links | 🔴 Critical | High | Regex + file existence |
| Retired file references | 🔴 Critical | High | Grep + file existence |
| Hallucinated dependencies | 🔴 Critical | High | Registry verification |
| Security-critical TODOs | 🔴 Critical | High | Grep + keyword filter |
| Generic TODO/FIXME | 🟡 Warning | High | Grep |
| Debug statements | 🟡 Warning | High | Grep |
| Commented-out code | 🟡 Warning | Low | Heuristic |
| Missing tests (coverage) | 🟡 Warning | High | Coverage tools |
| Missing tests (pairing) | 🟡 Warning | Medium | Heuristic |
| Placeholder content | 🟡 Warning | Low | Regex |
| Stale documentation | 🟡 Warning | Medium | Diff vs reality |
| Context exhaustion | 🟡 Warning | Medium | Positional analysis |
| Happy path bias | 🟡 Warning | Medium | Error handling density |
| Deployment gaps | 🟡 Warning | Medium | Missing config/Docker |
| Missing docstrings | 🟢 Info | Medium | AST/Regex |
| Empty directories | 🟢 Info | High | Find |
| Orphaned files | 🟢 Info | Medium | Import graph |
| Dead code | 🟢 Info | High | Linter output |

---

## Implementation Phases

### Phase 1: Fast Checks (< 1 second)
- Broken links, TODOs, debug statements, empty dirs, placeholders
- Pure grep/regex, no external tools

### Phase 2: Tool-Based Checks (1-10 seconds)
- Consume ESLint/Pylint/staticcheck output
- Type errors from TSC/mypy
- Unused imports, dead code from linters

### Phase 3: Deep Analysis (10-60 seconds, opt-in)
- Coverage analysis (run tests)
- Import graph analysis
- Orphaned file detection
- Context exhaustion patterns

---

## GitHub API Note

GitHub is experiencing availability issues (2026-02-09). Implementation will include retries with exponential backoff:

```python
wait_time = (2 ** attempt) + random.uniform(0, 1)
```

---

## Next Steps

1. [ ] Create skill file structure (`skills/completeness-check/SKILL.md`)
2. [ ] Implement Phase 1 detectors (fast checks)
3. [ ] Integrate with existing linters (Phase 2)
4. [ ] Add deep analysis (Phase 3, optional)
5. [ ] Test on genesis repo (known issues as baseline)
6. [ ] Document GitHub API retry strategy (exponential backoff)


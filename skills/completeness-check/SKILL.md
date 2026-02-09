---
name: completeness-check
description: "Detect incomplete work in repositories from AI assistant crashes, context exhaustion, or mid-implementation distractions. Use before claiming work complete or when auditing accumulated debt."
---

# completeness-check

**MANDATORY**: Use this skill before claiming work is complete on ANY repo, or when auditing accumulated incomplete work.

## The Core Principle

AI coding assistants frequently leave incomplete work when they:
- Get distracted mid-implementation
- Crash or lose context
- Context-switch away from unfinished tasks
- Exhaust their context window (~70% utilization shows degradation)

This leaves humans out of the loop. This skill helps detect and surface that incomplete work.

## When to Use This Skill

### Proactive Mode (before claiming done)
- Before committing changes
- Before creating a pull request
- Before reporting "work is complete"
- After long coding sessions

### Reactive Mode (auditing existing work)
- When taking over a project from another AI session
- When reviewing a repo that "feels incomplete"
- Periodic maintenance audits
- After discovering broken links or missing files

## Detection Categories

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
| Context exhaustion markers | 🟡 Warning | Medium | Positional analysis |
| Happy path bias | 🟡 Warning | Medium | Error handling density |
| Deployment gaps | 🟡 Warning | Medium | Missing config/Docker |
| Missing docstrings | 🟢 Info | Medium | AST/Regex |
| Empty directories | 🟢 Info | High | Find |
| Orphaned files | 🟢 Info | Medium | Import graph |
| Dead code | 🟢 Info | High | Linter output |

## CLI Usage

```bash
# Proactive mode (before claiming work complete)
completeness-check --mode proactive

# Reactive mode (auditing accumulated incomplete work)
completeness-check --mode reactive --verbose

# Target specific directory
completeness-check ./src --mode proactive

# Output formats
completeness-check --format summary    # Score + counts only
completeness-check --format detailed   # Full findings with file locations
completeness-check --format json       # Machine-readable for CI integration
```

## Scoring Formula

```
Base deductions:
  Critical (High conf):   15 points each
  Critical (Med/Low):     10 points each
  Warning (High conf):     7 points each
  Warning (Med/Low):       5 points each
  Info:                    1 point each

Score = max(0, 100 - deductions)
```

| Score | Interpretation |
|-------|----------------|
| 90-100 | ✅ Clean: minimal incomplete work detected |
| 70-89 | 🟡 Light: some loose ends, minor cleanup needed |
| 50-69 | 🟠 Moderate: noticeable gaps, review recommended |
| 30-49 | 🔴 Heavy: significant incomplete work, prioritize cleanup |
| 0-29 | ⛔ Severe: repo appears abandoned mid-implementation |

## Output Format: Summary

```
╭─────────────────────────────────────────────────────────────╮
│  COMPLETENESS CHECK                                         │
│  Repository: genesis                                        │
│  Mode: Proactive                                            │
╰─────────────────────────────────────────────────────────────╯

Completeness Score: 73/100 (Light)

Summary:
  🔴 Critical: 2
  🟡 Warning:  12
  🟢 Info:     5
```

## Implementation Phases

### Phase 1: Fast (grep-based)
- TODO/FIXME comments
- Debug statements
- Placeholder patterns
- Empty directories

### Phase 2: Tool-Based
- ESLint/staticcheck for dead code
- Coverage tools for missing tests
- Package registry for hallucinated deps

### Phase 3: Deep (expensive)
- AST parsing for orphaned code
- Semantic analysis for stale docs
- Cross-file dependency graphs

## Integration with Other Skills

- `holistic-repo-verification` - Check repo health after fixing incompleteness
- `superpowers:verification-before-completion` - Use completeness-check first
- `eliminating-ai-slop` - Clean up AI-generated patterns found

## Success Criteria

✅ All Critical issues resolved
✅ Score above 70 (or team threshold)
✅ No regressions from previous check
✅ Findings documented if deferred

---

**Remember**: AI assistants leave incomplete work more often than we realize. This skill makes that work visible.


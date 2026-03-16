# Mode 3: From Codebase Analysis

Analyze a repository to recommend skills that should exist.

---

## When to Use

- Onboarding to a new codebase
- "What skills should this repo have?"
- Skill gap analysis
- After major architectural changes

---

## Analysis Targets

### 1. Build/CI Configuration

| File/Dir | What to Look For | Potential Skill |
|----------|------------------|-----------------|
| `.github/workflows/` | Complex CI steps | CI-specific validation skill |
| `package.json` scripts | Repeated script patterns | Script-runner skill |
| `Makefile` | Multi-step targets | Build-process skill |
| `docker-compose.yml` | Service dependencies | Service-management skill |

### 2. Code Patterns

| Pattern | Signal | Potential Skill |
|---------|--------|-----------------|
| Custom linting rules | `.eslintrc` with many custom rules | Custom lint skill |
| Test patterns | Specific test utilities | Test-pattern skill |
| API conventions | Consistent endpoint structure | API-authoring skill |
| Error handling | Custom error classes | Error-handling skill |

### 3. Documentation

| File | Signal | Potential Skill |
|------|--------|-----------------|
| `CONTRIBUTING.md` | Detailed contribution rules | Contribution-gate skill |
| `docs/adr/` | ADR structure | ADR-authoring skill |
| `docs/api/` | API documentation | API-doc skill |

### 4. Commit History

```bash
# Find common commit prefixes
git log --oneline -100 | sed 's/^[a-f0-9]* //' | cut -d: -f1 | sort | uniq -c | sort -rn | head -10
```

Common patterns (e.g., `fix:`, `feat:`, `docs:`) suggest conventional-commits skill.

### 5. Pain Points

| Source | Signal | Potential Skill |
|--------|--------|-----------------|
| TODOs/FIXMEs | `grep -r "TODO\|FIXME"` | Task-triage skill |
| Long functions | Complexity metrics | Refactoring skill |
| Repeated code | Duplication detection | DRY-enforcement skill |

---

## Analysis Process

### Step 1: Inventory the Repository

```bash
# Quick structure overview
find . -type f -name "*.md" | head -20
find . -type f -name "*.sh" | head -20
ls -la .github/workflows/ 2>/dev/null
cat package.json 2>/dev/null | jq '.scripts'
```

### Step 2: Identify Workflows

Look for multi-step processes that are:
- Documented in README/CONTRIBUTING
- Encoded in CI workflows
- Mentioned in commit messages

### Step 3: Rank by Value

| Criteria | Weight |
|----------|--------|
| Frequency of workflow | High |
| Complexity of workflow | High |
| Risk of errors | High |
| Existing documentation | Medium |
| Team size benefit | Medium |

### Step 4: Propose Top 3-5

Present ranked recommendations:

```
## Skill Gap Analysis: <repo-name>

### Recommended Skills

1. **deployment-checklist** (High value)
   - Workflow: 8-step deployment process in CONTRIBUTING.md
   - Value: Prevents missed steps, reduces incidents
   
2. **api-versioning** (Medium value)
   - Pattern: v1/, v2/ prefixes in routes
   - Value: Ensures consistent versioning

3. **test-fixture-management** (Medium value)
   - Pattern: Complex fixture setup in tests
   - Value: Reduces test flakiness

Would you like me to generate any of these?
```

---

## Example Analysis

**Repository:** E-commerce API

**Findings:**

| Area | Observation | Skill Opportunity |
|------|-------------|-------------------|
| CI | 12-step deployment workflow | deployment-gate |
| Code | Custom validation decorators | validation-patterns |
| Docs | Detailed API changelog | changelog-authoring |
| Tests | Complex mocking patterns | test-mock-patterns |
| Git | Strict branch naming | branch-naming-check |

**Top Recommendation:** `deployment-gate` — The 12-step deployment process has 3 TODOs saying "don't forget this step" which signals high error risk.

---

## Output Format

For each recommended skill, provide:

1. **Name** — Suggested skill name
2. **Evidence** — What in the codebase suggests this
3. **Value** — Why this skill would help
4. **Complexity** — How hard to implement (Low/Medium/High)
5. **Priority** — Recommended priority (P1/P2/P3)

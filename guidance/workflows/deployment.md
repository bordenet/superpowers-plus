# Deployment Workflow

> **Priority**: HIGH - Applies to all projects with CI/CD  
> **Source**: strategic-proposal, architecture-decision-record, genesis Agents.md

## ⚠️ MANDATORY: CI Before Deploy

**NEVER deploy without green CI.** This is non-negotiable.

### Three-Step Process

```bash
# Step 1: Push changes to GitHub
git push origin main

# Step 2: WAIT for CI to pass
# ⚠️ DO NOT PROCEED until all checks are GREEN (not red X)

# Step 3: Deploy ONLY after CI passes
./scripts/deploy-web.sh  # or equivalent
```

## Quality Gates Checklist

Before deployment, verify:
- [ ] All tests pass locally
- [ ] Linting passes with no errors
- [ ] CI shows green checkmark
- [ ] No security vulnerabilities (npm audit, govulncheck, pip-audit)
- [ ] Coverage meets minimum threshold
- [ ] Documentation updated if APIs changed

## Non-Negotiable Quality Requirements

1. **All code must compile/build without errors**
2. **All tests must pass** - NEVER skip, disable, or bypass tests
3. **No linting errors** - Fix immediately, don't defer
4. **Commit messages must be descriptive**
5. **Changes must be properly staged** before commit

## Reference Implementations

When uncertain, check these canonical implementations:
- **PRIMARY**: `genesis-tools/architecture-decision-record/`
- **SECONDARY**: `genesis-tools/product-requirements-assistant/`

## Setup Scripts

**Rule**: ALL dependencies installed via setup scripts, NEVER manual `npm install`:
```bash
./scripts/setup.sh          # Full setup
./scripts/setup-web.sh      # Web-specific setup
```


# Genesis Tools Project Conventions

> **Priority**: HIGH - Apply to all genesis-tools projects  
> **Source**: genesis, architecture-decision-record, strategic-proposal Agents.md

## Reference Implementations

When uncertain about patterns or structure, check these canonical implementations:

| Priority | Repository | Use For |
|----------|------------|---------|
| **PRIMARY** | `genesis-tools/architecture-decision-record/` | Overall structure, scripts, workflows |
| **SECONDARY** | `genesis-tools/product-requirements-assistant/` | Alternative patterns |

**ALWAYS check reference implementations BEFORE creating new patterns.**

## Setup Scripts Requirement

**Rule**: ALL dependencies installed via setup scripts, NEVER manual commands:

```bash
# ✅ Correct
./scripts/setup.sh          # Full setup
./scripts/setup-web.sh      # Web-specific setup

# ❌ Wrong
npm install                 # Never run directly
pip install -r requirements.txt  # Use setup script
```

## Deployment Workflow

```bash
# Step 1: Push changes
git push origin main

# Step 2: WAIT for CI green checkmark
# DO NOT proceed until all checks pass

# Step 3: Deploy only after green
./scripts/deploy-web.sh
```

## Project Structure

```
project/
├── .github/
│   └── workflows/           # CI/CD configs
├── scripts/
│   ├── setup.sh            # Main setup script
│   ├── setup-web.sh        # Web dependencies
│   ├── deploy-web.sh       # Deployment
│   └── test.sh             # Test runner
├── src/                    # Source code
├── web/                    # Web interface (if applicable)
├── docs/                   # Documentation
├── Agents.md               # AI guidance
├── CLAUDE.md               # Redirect to Agents.md
└── README.md               # Project readme
```

## Documentation Hygiene

- **Automatic validation** via CI
- Update docs when APIs change
- Keep README current with setup instructions
- Cross-reference related documents


# AI Agent Guidelines - [PROJECT_NAME]

> **Last Updated**: [DATE]
> **Languages**: [javascript/python/go/shell/dart]
> **Type**: [cli-tool/web-app/mobile-app/genesis-tool]

---

## Superpowers Integration

At the START of every conversation, run:

```bash
node ~/.codex/superpowers-augment/superpowers-augment.js bootstrap
```

### Key Skills

| Skill | When to Invoke |
|-------|---------------|
| `superpowers:brainstorming` | Before creative/feature work |
| `superpowers:systematic-debugging` | Before fixing bugs |
| `superpowers:test-driven-development` | Before writing implementation |
| `superpowers:verification-before-completion` | Before claiming done |
| `superpowers:writing-plans` | Before multi-step tasks |

**The Rule**: IF A SKILL APPLIES (even 1% chance), YOU MUST INVOKE IT.

---

## Communication Standards

- **No flattery** - Skip "Great question!" or "Excellent point!"
- **No hype words** - Avoid "revolutionary", "game-changing", "cutting-edge"
- **Evidence-based** - Cite sources, provide data, or qualify as opinion
- **Direct** - State facts without embellishment

### Banned Phrases

| Category | Avoid |
|----------|-------|
| Self-Promotion | production-grade, world-class, enterprise-ready |
| Filler | incredibly, extremely, very, really, truly |
| AI Tells | leverage, utilize, facilitate, streamline, optimize |
| Sycophancy | Happy to help!, Absolutely!, I appreciate... |

---

## Quality Gates

### Before Committing

1. **Lint**: `[LINT_COMMAND]`
2. **Build**: `[BUILD_COMMAND]`
3. **Test**: `[TEST_COMMAND]`
4. **Coverage**: Minimum [XX]%

### Before Pushing

- [ ] All tests pass
- [ ] No linting errors
- [ ] No secrets in code
- [ ] Commit messages are descriptive

### Before Deploying

- [ ] CI shows green checkmark
- [ ] Security scan passed
- [ ] Documentation updated

---

## Project-Specific Rules

<!-- Add project-specific guidance below -->

---

## Quick Command Reference

```bash
# Setup
[SETUP_COMMAND]

# Development
[DEV_COMMAND]

# Test
[TEST_COMMAND]

# Lint
[LINT_COMMAND]

# Build
[BUILD_COMMAND]

# Deploy (after CI green)
[DEPLOY_COMMAND]
```


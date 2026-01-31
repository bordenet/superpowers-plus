# AI Agent Guidelines

> **Project**: [PROJECT_NAME]
> **Languages**: [javascript/python/go/shell]
> **Type**: [genesis-tools/cli-tools/web-apps]

---

## Superpowers Integration

At the START of every conversation, run:

```bash
node ~/.codex/superpowers-augment/superpowers-augment.js bootstrap
```

**The Rule**: IF A SKILL APPLIES TO YOUR TASK (even 1% chance), YOU MUST INVOKE IT.

---

## Guidance References

This project follows the consolidated guidance in `superpowers-plus/guidance/`:

### Core (Always Apply)
- `superpowers-plus/guidance/core/superpowers.md` - Skill invocation
- `superpowers-plus/guidance/core/communication.md` - Communication standards
- `superpowers-plus/guidance/core/anti-slop.md` - Writing quality

### Workflows
- `superpowers-plus/guidance/workflows/deployment.md` - CI/CD workflow
- `superpowers-plus/guidance/workflows/testing.md` - Testing standards
- `superpowers-plus/guidance/workflows/security.md` - Security practices

### Language-Specific
<!-- Uncomment the languages used in this project -->
<!-- - `superpowers-plus/guidance/languages/javascript.md` -->
<!-- - `superpowers-plus/guidance/languages/python.md` -->
<!-- - `superpowers-plus/guidance/languages/go.md` -->
<!-- - `superpowers-plus/guidance/languages/shell.md` -->

### Project Type
<!-- Uncomment if applicable -->
<!-- - `superpowers-plus/guidance/project-types/genesis-tools.md` -->
<!-- - `superpowers-plus/guidance/project-types/cli-tools.md` -->
<!-- - `superpowers-plus/guidance/project-types/web-apps.md` -->

---

## Project-Specific Rules

<!-- Add any project-specific guidance here -->

---

## Quick Reference

### Before Committing
1. Run tests: `[test command]`
2. Run linting: `[lint command]`
3. Check coverage: `[coverage command]`

### Before Pushing
- All tests pass
- CI will be green
- No secrets in code


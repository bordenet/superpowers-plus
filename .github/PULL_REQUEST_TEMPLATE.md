## Summary

<!-- Brief description of what this PR does -->

## Type of Change

- [ ] Bug fix
- [ ] New feature
- [ ] Documentation update
- [ ] Refactoring
- [ ] Other (describe):

## Quality Checklist

### Mandatory (All PRs)

> **⚠️ CI will fail if any of these are violated**

- [ ] All files end with exactly one newline
- [ ] All `.sh` files use `#!/usr/bin/env bash` shebang
- [ ] All `.sh` files pass `bash -n` syntax check
- [ ] All `.json` files are valid JSON
- [ ] Ran `./tools/harsh-review.sh` locally and it passed

### For Skill Changes

- [ ] Skill has `skill.md` or `SKILL.md` in correct location
- [ ] Skill metadata (triggers, category) is accurate
- [ ] No vendor-specific references outside `_adapters/`
- [ ] Related adapter updated if skill uses external services

### For Script Changes

- [ ] Script passes `shellcheck` (or issues are intentionally disabled)
- [ ] Script has header comment explaining purpose and usage
- [ ] Script handles errors with `set -euo pipefail`

### For Documentation Changes

- [ ] Internal links verified to exist
- [ ] External URLs verified accessible
- [ ] No broken references to files or sections

## Testing

<!-- How did you test these changes? -->

- [ ] Ran `./tools/harsh-review.sh`
- [ ] Ran `./tools/harsh-review.sh --changed-only`
- [ ] Manual verification (describe):

## Related Issues

<!-- Link any related issues -->

Closes #

---

**Reviewer Notes:**
<!-- Anything specific reviewers should look at? -->


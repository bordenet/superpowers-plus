# README Authoring — Automation & Resources

> Reference material for the `readme-authoring` skill.
> See `skill.md` for core agent guidance.

## Automation (Recommended)

Set up GitHub Actions for:

1. **Markdown lint** - markdownlint on PRs
2. **Link checker** - Detect dead links automatically
3. **Badge updates** - Auto-update coverage/version badges

Example workflow:

```yaml
# .github/workflows/docs.yml
name: Docs
on: [push, pull_request]
jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: npx markdownlint-cli2 "**/*.md"
```

---

## Resources

Based on patterns from:

- [matiassingers/awesome-readme](https://github.com/matiassingers/awesome-readme)
- [Art of README](https://github.com/hackergrrl/art-of-readme)
- [Make a README](https://www.makeareadme.com/)
- [jehna/readme-best-practices](https://github.com/jehna/readme-best-practices)
- [othneildrew/Best-README-Template](https://github.com/othneildrew/Best-README-Template)

Exemplars: Kubernetes (actionable), Google Style Guides (minimalist).

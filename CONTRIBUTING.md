# Contributing to superpowers-plus

Adding a new skill? See [docs/CONTRIBUTING.md](docs/CONTRIBUTING.md) for the full skill-authoring guide (directory layout, frontmatter template, trigger validation, CI detectors, release process). This page covers upstream sync governance and the gates that apply to every PR.

## Upstream Sync Governance

superpowers-plus folds in Jesse Vincent's [obra/superpowers](https://github.com/obra/superpowers) (MIT) directly, as described below; there is no separate intermediary fork repo in the current install or sync path.

### Pulling upstream improvements from obra/superpowers

> **v2.6.0 note:** The local obra clone tier (`~/.codex/superpowers/`) was removed in v2.6.0.
> Sync happens directly in the superpowers-plus source repo, not through an installed clone.

```bash
# In your local superpowers-plus source checkout (one-time setup)
git remote add obra https://github.com/obra/superpowers.git

# Periodic sync (review before merging)
git fetch obra
git log HEAD..obra/main --oneline   # preview changes
git merge obra/main                 # integrate
```

Review each upstream commit before merging. Changes to core skills (`brainstorming`, `systematic-debugging`, etc.) may need override updates in superpowers-plus.

---

## `using-superpowers` Change Gate

Any PR that modifies `skills/productivity/using-superpowers/skill.md` **must** include a smoke test demonstrating the 6 core trigger phrases still route correctly.

| Prompt | Expected skill trigger |
|--------|----------------------|
| "what can you do?" | `superpowers-help` |
| "update my superpowers" | `update-superpowers` |
| "let's build X" | `brainstorming` |
| "fix this bug" | `systematic-debugging` |
| "commit my changes" | `unified-commit-gate` |
| "review this code" | `code-review-battery` |

Paste the table above into a conversation and confirm each phrase triggers the correct skill before marking the PR ready.

---

## Skill Authoring Guidelines

### Frontmatter schema

```yaml
---
name: skill-name          # matches directory name
source: superpowers-plus  # always this value for skills in this repo
augment_menu: true        # include in Augment slash menu (optional)
triggers: [...]           # phrases that auto-activate the skill
anti_triggers: [...]      # phrases that must NOT activate it (optional)
description: "..."        # one-sentence description for routing
summary: "Use when: ..."  # shown in sp-help --skills
---
```

### Override declaration

If your skill overrides an upstream obra skill (matches its name and replaces it at install time), note the relationship in the skill's own description or a comment near the top of its frontmatter. A dedicated `overrides:` field does exist and is read by `tools/doctor-modules/metadata-checks.sh` and `yaml-checks.sh`, but only to suppress drift and duplicate-name warnings for multi-source overlay installs, not to document an obra-origin relationship. No skill file in this repo currently sets it. Adding one won't give you automatic obra-override drift detection; it only changes overlay-duplicate behavior in `sp-doctor`.

---

## Commit Gate

All PRs must pass the pre-push gates:

1. **Code review clearance** — run `bash tools/run-battery.sh --verdict PASS`, which writes `.code-review-cleared`
2. **IP audit** — no proprietary content in public commits (enforced by `tools/public-repo-ip-check.sh`)
3. **Shell tests** — `bats test/` must pass

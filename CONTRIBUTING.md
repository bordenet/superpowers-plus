# Contributing to superpowers-plus

## Upstream Fork Governance

superpowers-plus depends on [bordenet/superpowers](https://github.com/bordenet/superpowers), a maintained fork of Jesse Vincent's [obra/superpowers](https://github.com/obra/superpowers) (MIT). Jesse's copyright is preserved in the fork's LICENSE file.

### Pulling upstream improvements from obra/superpowers

```bash
# One-time setup
git -C ~/.codex/superpowers remote add upstream https://github.com/obra/superpowers.git

# Periodic sync (review before merging)
git -C ~/.codex/superpowers fetch upstream
git -C ~/.codex/superpowers log HEAD..upstream/main --oneline   # preview changes
git -C ~/.codex/superpowers merge upstream/main                 # integrate
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

If your skill overrides an upstream obra skill, add to frontmatter:

```yaml
overrides: upstream-skill-name
```

This documents the override relationship and helps `sp-doctor` detect drift.

---

## Commit Gate

All PRs must pass the pre-push gates:

1. **Code review clearance** — run `bash tools/code-review-battery.sh` or equivalent, which writes `.code-review-cleared`
2. **IP audit** — no CallBox-proprietary content in public commits (enforced by `tools/public-repo-ip-check.sh`)
3. **Shell tests** — `bats test/` must pass

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

Any PR that modifies `skills/engineering/using-superpowers/skill.md` **must** include a smoke test demonstrating the 6 core trigger phrases still route correctly.

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

A dedicated `overrides: source-name/skill-name` frontmatter field exists for this: `lib/install/deploy.sh` uses it to stage the named source's companion files (references, scripts) before overlaying your skill.md, and `tools/doctor-modules/metadata-checks.sh`/`yaml-checks.sh` use its presence to suppress drift and duplicate-name warnings for the intentional overlay. The `superpowers/...` source name specifically is retired as of v2.6.0 (obra/superpowers is folded in directly now; `deploy.sh` warns if it sees this form and asks you to remove it). No skill file in this repo currently sets `overrides:` for any other source, so this is documented behavior, not a proven-in-practice one.

---

## Commit Gate

All PRs must pass the pre-push gates:

1. **Code review clearance** — run `bash tools/run-battery.sh --verdict PASS`, which writes `.code-review-cleared`
2. **IP audit** — no proprietary content in public commits (enforced by `tools/public-repo-ip-check.sh`)
3. **Shell tests** — `bats test/` must pass
4. **PR content IP scan** (server-side) — the `PR Content IP Scan` CI job (`.github/workflows/pr-content-ip-scan.yml`) scans the PR's title and body text for banned terms. This exists because a squash-merge builds the final merge commit message from the PR's title/body, not from any local commit — so a banned term appearing only there would otherwise never be caught by any local hook or diff-based scan. Note: this job uses `pull_request_target`, so it only runs once its workflow file exists on the PR's base branch — it cannot check itself on the PR that first introduces it. It becomes a *required* status check only after that first landing, once GitHub has confirmed it actually reports a status on each protected branch.

Not sure which gate applies to a given file, or which review skill to dispatch? Don't work it out from memory — run `tools/review.sh route <path> [<path> ...]` (or `tools/which-gate.sh <path> [<path> ...]` for the same per-file gate/runner lookup without `review.sh`'s skill-name grouping across multiple paths). Both extract and run the actual detection logic from the gate scripts themselves, so they can't drift out of sync with hand-written prose like this list. If either errors or is unavailable, stop and report — do not fall back to this list from memory.

# Invariants — superpowers-plus

Hard rules. No exceptions without explicit human instruction.

## Source Repo

- ALL edits happen in THIS repo (the directory containing this file)
- NEVER edit installed copies: `~/.codex/superpowers-plus/`, `~/.codex/skills/`, `~/.agents/skills/`
- If unsure of source path: `git rev-parse --show-toplevel`

## Git Workflow

- NEVER commit directly to `main`, `staging`, or `dev`
- NEVER branch features from `main` or `staging` — always branch from `origin/dev`
- NEVER promote `dev → staging` without explicit user instruction
- NEVER promote `staging → main` without explicit user release instruction
- NEVER self-merge any PR — human approval required at every tier
- ALWAYS `git reset --hard origin/main` to sync local main — NEVER rebase or merge
  (squash merges change SHAs; rebase will always conflict)

## Quality Gates

- NEVER push without running `tools/run-battery.sh` first (sentinel required)
- NEVER write `.code-review-cleared` directly — only `tools/run-battery.sh` may write it
- NEVER emit "ready to push / commit / merge" without checking for required-skill triggers

## Install Artifacts

- After `sp-update` or `install.sh`, run `git restore .` in `~/.codex/superpowers-plus/`
  to clear execute-bit drift on `tools/doctor-modules/*.sh` and `tools/tests/*.sh`

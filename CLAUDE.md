# Claude Code Instructions

See **[AGENTS.md](./AGENTS.md)** for all AI guidance.

## Agent-first design principle (non-negotiable)

All infrastructure code, tooling, gates, hooks, and workflows in this
repository are designed and optimized for **AI coding agents**, not humans.
Humans interact with this repo only to approve and monitor; agents execute.

Consequences:

- **Do not add interactive prompts, manual checkpoints, or pauses for human
  confirmation** to any tool or workflow. Every step must be executable
  autonomously from start to finish.
- **Do not add human-legibility conveniences** (colorized spinners, interactive
  menus, PAGER output) that break non-interactive shells or pipe
  consumption.
- **When a tool or workflow requires a decision**, encode the decision logic
  directly in the script rather than delegating to a human prompt. If the
  decision cannot be automated, the tool should fail clearly and exit
  non-zero with a machine-readable error, not wait.
- **Quality gates exist to run autonomously.** A gate that requires human
  review before it can be checked does not belong here.
- **ship.sh is the canonical end-to-end agent workflow.** Any friction it
  exposes is a bug in the infrastructure, not a feature.

If you find yourself writing a step that says "then the human should...",
stop — that step belongs in the tool itself or the tool is incomplete.

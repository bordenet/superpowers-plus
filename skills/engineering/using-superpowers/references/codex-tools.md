# Codex Tool Mapping

Skills use Claude Code tool names. When you encounter these in a skill, use your platform equivalent:

| Skill references | Codex equivalent |
|-----------------|------------------|
| `Task` tool (dispatch subagent) | `spawn_agent` (see [Named agent dispatch](#named-agent-dispatch)) |
| Multiple `Task` calls (parallel) | Multiple `spawn_agent` calls |
| Task returns result | Arrives in your mailbox; `wait_agent` only when idle (below) |
| Resume a subagent (fix rounds) | `followup_task` (V2) |
| Task completes automatically | V2: evicted automatically. V1 only: `close_agent` |
| `TodoWrite` (task tracking) | `update_plan` |
| `Skill` tool (invoke a skill) | Skills load natively — just follow the instructions |
| `Read`, `Write`, `Edit` (files) | Use your native file tools |
| `Bash` (run commands) | Use your native shell tools |

## Subagent dispatch requires multi-agent support

Add to your Codex config (`~/.codex/config.toml`):

```toml
[features]
multi_agent = true
```

This enables the multi-agent tools. Current model presets run V2; older ones
run V1. Trust your actual tool list over this table when they disagree.

- **Spawning:** `spawn_agent {fork_turns: "none"}` gives a clean child; the
  default `"all"` copies your whole transcript into it.
- **Models:** every spawn sets `model` AND `reasoning_effort` explicitly
  (setting only `model` resets effort to that model's default), checked
  against your spawn allowlist. Machine backstop in `~/.codex/config.toml`:
  `[agents] default_subagent_model = "<mid-tier>"`,
  `default_subagent_reasoning_effort = "medium"`.
- **Fix rounds:** resume the implementer with `followup_task`; on V2 a spawned
  agent can always be messaged again, so never re-dispatch fresh for that.
- **Waiting:** `wait_agent` is an event subscription, not a poll. With local
  work left, don't wait — results arrive with your next turn. When idle, wait
  in 5-10 minute stretches (`timeout_ms` 300000-600000); after each, post one
  status line, run `list_agents`, and chase children that finished silently.
  Never stack polls shorter than five minutes.

## Named agent dispatch

Some skills name a dedicated reviewer agent (formerly `superpowers:code-reviewer`).
Codex does not have a named agent registry — `spawn_agent` creates generic agents
from built-in roles (`default`, `explorer`, `worker`).

When a skill says to dispatch a named agent type:

1. Find the agent's prompt file (e.g., `agents/code-reviewer.md` or the skill's
   local prompt template like `code-quality-reviewer-prompt.md`)
2. Read the prompt content
3. Fill any template placeholders (`{BASE_SHA}`, `{WHAT_WAS_IMPLEMENTED}`, etc.)
4. Spawn a `worker` agent with the filled content as the `message`

| Skill instruction | Codex equivalent |
|-------------------|------------------|
| A code-reviewer dispatch | `spawn_agent(agent_type="worker", message=...)` with `requesting-code-review/code-reviewer.md` content |
| `Task tool (general-purpose)` with inline prompt | `spawn_agent(message=...)` with the same prompt |

### Message framing

The `message` parameter is user-level input, not a system prompt. Structure it
for maximum instruction adherence:

```
Your task is to perform the following. Follow the instructions below exactly.

<agent-instructions>
[filled prompt content from the agent's .md file]
</agent-instructions>

Execute this now. Output ONLY the structured response following the format
specified in the instructions above.
```

- Use task-delegation framing ("Your task is...") rather than persona framing ("You are...")
- Wrap instructions in XML tags — the model treats tagged blocks as authoritative
- End with an explicit execution directive to prevent summarization of the instructions

## Environment Detection

Skills that create worktrees or finish branches should detect their
environment with read-only git commands before proceeding:

```bash
GIT_DIR=$(cd "$(git rev-parse --git-dir)" 2>/dev/null && pwd -P)
GIT_COMMON=$(cd "$(git rev-parse --git-common-dir)" 2>/dev/null && pwd -P)
BRANCH=$(git branch --show-current)
```

- `GIT_DIR != GIT_COMMON` → already in a linked worktree (skip creation)
- `BRANCH` empty → detached HEAD (cannot branch/push/PR from sandbox)

See `using-git-worktrees` Step 0 and `finishing-a-development-branch`
Step 1 for how each skill uses these signals.

## Codex App Finishing

When the sandbox blocks branch/push operations (detached HEAD in an
externally managed worktree), the agent commits all work and informs
the user to use the App's native controls:

- **"Create branch"** — names the branch, then commit/push/PR via App UI
- **"Hand off to local"** — transfers work to the user's local checkout

The agent can still run tests, stage files, and output suggested branch
names, commit messages, and PR descriptions for the user to copy.

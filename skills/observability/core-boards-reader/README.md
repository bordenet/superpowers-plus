# core-boards-reader

Read-only consumption of [Company] Core Boards (bulletin board system). Provides AI-assisted reviewing, summarizing, and searching of board discussions.

## Trigger Phrases

- "What's new on Core?" / "My action feed" / "Unread boards"
- "Catch me up" / "Summarize boards" / "Board digest"
- "Search boards for X" / "Find boards about X"
- "Read board N" / "Show me board 60565"

## Required MCP Server

`core-boards-mcp-server` — see [mcp-servers/core-boards](https://[INTERNAL-GITLAB]/mbordenet/mcp-servers/-/tree/main/core-boards)

## Environment Variables

| Variable | Required | Source |
|----------|----------|--------|
| `CORE_BOARDS_CFID` | Yes | Browser DevTools → Cookies → core.[company].com |
| `CORE_BOARDS_CFTOKEN` | Yes | Browser DevTools → Cookies → core.[company].com |

Both stored in `~/.codex/.env`. Session cookies expire after ~30 min idle.

## Companion Skills

| Skill | Purpose |
|-------|---------|
| `core-boards` | **Authoring** — generate HTML for posting to Core Boards |
| `core-boards-reader` | **Reading** — review, summarize, search (this skill) |


---
name: core-boards-reader
source: superpowers-[company]
description: "Read-only Core Boards consumption. Use when user wants to review unread boards, catch up on announcements, search board history, or summarize discussions from [Company] Core Boards."
summary: "Use when: reading Core Boards announcements. Skip when: creating posts (use core-boards)."
triggers: ["what's new on Core", "my action feed", "unread boards", "catch me up", "summarize boards", "board digest", "search boards", "core boards"]
requires_mcp: ["core-boards"]
mcp_install_hint: "$(dirname \"$SPC_SOURCE_DIR\")/mcp-servers/core-boards/install.sh"
coordination:
  group: productivity
  order: 1
  requires: []
  enables: []
  escalates_to: []
  internal: false
anti_triggers: ['post to boards', 'write a board post', 'create board post']
---

# Core Boards Reader

Read-only access to [Company] Core Boards via the `core-boards` MCP server. This skill handles reviewing, summarizing, and searching — for authoring/posting, use the `core-boards` skill instead.

## Prerequisites

- **MCP server:** `core-boards-mcp-server` must be running (provides `check_session`, `get_action_feed`, `list_boards`, `get_board`, `search_boards`, `archive_board`)
- **Env vars:** `CORE_BOARDS_CFID` and `CORE_BOARDS_CFTOKEN` in `~/.codex/.env`

## Workflows

### 1. Unread Feed — "What's new?" / "My action feed"

1. Call `check_session` — if expired, run [Auth Refresh](#auth-refresh-flow)
2. Call `get_action_feed` (optionally with `limit`)
3. Present to user:
   - "You have **N** unread bulletin boards (out of M total feed items)"
   - List boards with titles, timestamps, @-mention flags, tags
4. Ask: "Want me to summarize any of these? Say a board number or 'catch me up' for a full digest."

### 2. Catch-Me-Up Digest — "Catch me up" / "Summarize boards"

1. Call `get_action_feed` to get unread board list
2. For each board (or top 10 if many), call `get_board` with the board ID
3. For each board, produce a **2-3 sentence summary** of the discussion:
   - What the board is about (from title + first comment)
   - Key points from the thread (decisions made, questions asked, actions proposed)
   - Whether the user was @-mentioned
4. Present as a numbered digest with board titles as headers
5. Offer to drill deeper into any specific board

### 3. Search — "Search boards for X" / "Find boards about X"

1. Call `search_boards` with the user's query
   - Note: search is full-text (both post titles AND comment text via SQL LIKE)
2. Present results with titles, authors, timestamps
3. Offer: "Want to read any of these? Give me a board number or ID."
4. If user picks one, call `get_board` and present full content

### 4. Read Single Board — "Read board N" / "Show me board 60565"

1. Call `get_board` with the board ID
2. Present: title, author, full comment thread with author/date/text
3. After presenting, offer: "Want me to summarize this, or go back to your feed?"

## Auth Refresh Flow

When `check_session` returns an invalid/expired session:

```
⚠️ Your Core Boards session has expired. Let's refresh it:

1. Open https://core.[company].com/go/follow.cfm in your browser
   (should auto-login via Azure AD SSO)
2. Open DevTools (F12) → Application tab → Cookies → core.[company].com
3. Copy the values for CFID and CFTOKEN
4. Run the installer to update your cookies securely:
   source ~/.codex/.env && bash "$(dirname "$SPC_SOURCE_DIR")/mcp-servers/core-boards/install.sh"
```

⚠️ **NEVER paste cookies directly into chat** — they are session secrets. Always use the installer, which masks input and sets restrictive file permissions.

After the installer completes:
1. Retry `check_session` to confirm the new cookies work
2. Continue with the original request

## Boundaries

- **Read-only.** No writing, posting, or commenting. Use the `core-boards` authoring skill for that.
- **No follow/unfollow.** Cannot change which boards you follow.
- **No mark-as-read.** Items are marked as read only when you visit them in the browser.
- **Bulletin boards only.** Does not handle Cases, ZenDesk, Monday.com, or other Action Feed notification types.
- **Session cookies expire** after ~30 min of idle. Auth refresh is manual (browser DevTools).



## When to Use

- When user asks to check announcements, catch up on boards, or review unread items
- When searching for past discussions or decisions on Core Boards
- This is READ-ONLY — cannot author or reply to boards

## Failure Modes

| Failure | Fix |
|---------|-----|
| Session cookie expired — 401 or empty response | Re-authenticate via browser DevTools, extract fresh cookie |
| Non-board notification types returned | Filter to bulletin boards only — ignore Cases, ZenDesk, Monday.com items |
| Attempted write operation | This is READ-ONLY — redirect user to browser for authoring/replying |

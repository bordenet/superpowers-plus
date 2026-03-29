---
name: fathom-meeting-notes
source: superpowers-callbox
description: Use when retrieving meeting recordings, searching transcripts, finding action items, or referencing past discussions. Triggers on "meeting notes", "fathom", "what did we discuss", "my meeting with [name]", "call notes", "pairing session", "show today's meetings", "action items from", "meeting transcript", "who said what".
summary: "Use when: retrieving meeting recordings, searching transcripts, or finding action items."
triggers: ["meeting notes", "fathom", "what did we discuss", "my meeting with", "call notes", "pairing session", "show today meetings", "action items from", "meeting transcript"]
coordination:
  group: productivity
  order: 1
  requires: []
  enables: []
  escalates_to: []
  internal: false
anti_triggers: ['fathom API endpoint', 'fathom webhook']
---

# Fathom Meeting Notes

> **API:** `https://api.fathom.ai/external/v1/meetings`
> **Docs:** https://developers.fathom.ai/
> **Credentials:** `FATHOM_API_KEY` in `~/.codex/.env`

---

## Purpose

Retrieves meeting transcripts, summaries, and action items from Fathom AI. Use for post-meeting follow-up, extracting action items, or referencing what was discussed.

**Announce at start:** "I'm using the fathom-meeting-notes skill to retrieve your meeting data."

---

## Checklist

| Command | Action |
|---------|--------|
| "Get my meeting with [name]" | Find most recent meeting with that attendee |
| "Show today's meetings" | List all meetings recorded today |
| "Meeting notes from [date]" | List meetings from specific date |
| "What did we discuss about [topic]?" | Search transcript for topic |
| "Action items from [meeting]" | Extract action items/next steps |

---

## API Authentication

```bash
# Header format
X-Api-Key: $FATHOM_API_KEY
```

**Load from:** `source ~/.codex/.env`

---

## Core API Operations

### 1. List Recent Meetings

```bash
curl -s -H "X-Api-Key: $FATHOM_API_KEY" \
  "https://api.fathom.ai/external/v1/meetings?limit=10" | jq '.'
```

### 2. List Meetings by Date Range

```bash
# Today's meetings (UTC)
curl -s -H "X-Api-Key: $FATHOM_API_KEY" \
  "https://api.fathom.ai/external/v1/meetings?created_after=$(date -u +%Y-%m-%dT00:00:00Z)&created_before=$(date -u +%Y-%m-%dT23:59:59Z)" | jq '.'
```

### 3. Get Meeting with Full Transcript

```bash
curl -s -H "X-Api-Key: $FATHOM_API_KEY" \
  "https://api.fathom.ai/external/v1/meetings?include_transcript=true&limit=1" | jq '.'
```

### 4. Find Meeting by Title or Attendee

```bash
# Filter by title (client-side filtering after fetch)
curl -s -H "X-Api-Key: $FATHOM_API_KEY" \
  "https://api.fathom.ai/external/v1/meetings?limit=20" | \
  jq '.items[] | select(.title | test("Yousof"; "i"))'

# Filter by attendee email
curl -s -H "X-Api-Key: $FATHOM_API_KEY" \
  "https://api.fathom.ai/external/v1/meetings?limit=20" | \
  jq '.items[] | select(.calendar_invitees[].email | test("yalgburi"; "i"))'
```

### 5. Get Transcript Separately (by recording_id)

```bash
# Step 1: Get the recording_id from meeting data
curl -s -H "X-Api-Key: $FATHOM_API_KEY" \
  "https://api.fathom.ai/external/v1/meetings?limit=1" | jq '.items[0].recording_id'

# Step 2: Fetch transcript using recording_id
curl -s -H "X-Api-Key: $FATHOM_API_KEY" \
  "https://api.fathom.ai/external/v1/recordings/{RECORDING_ID}/transcript"
```

⚠️ **IMPORTANT:** Use `recording_id` (e.g., `132808290`), NOT the URL call ID (e.g., `612141967`).

**URL call ID ≠ recording_id.** The number in `https://fathom.video/calls/{CALL_ID}` is a _call ID_, not the `recording_id`. You must find the meeting via the list endpoint first, then use the `recording_id` field from the response.

These endpoints **DO NOT EXIST**:
- ❌ `/meetings/{id}` — no single-meeting lookup
- ❌ `/meetings/{id}/transcript`
- ❌ `/calls/{id}/transcript`

### 6. Find Meeting by Fathom URL

When user provides a URL like `https://fathom.video/calls/612141967`:

```bash
# Extract the call ID from the URL (612141967)
# Search through paginated results matching the URL
CALL_ID=612141967
source ~/.codex/.env

# Page 1
RESPONSE=$(curl -s -H "X-Api-Key: $FATHOM_API_KEY" \
  "https://api.fathom.ai/external/v1/meetings?limit=50")

# Check if meeting is in this page
echo "$RESPONSE" | jq --arg url "https://fathom.video/calls/$CALL_ID" \
  '.items[] | select(.url == $url) | {title, recording_id, url}'

# If not found, get cursor and paginate
CURSOR=$(echo "$RESPONSE" | jq -r '.next_cursor')
# Continue with &cursor=$CURSOR until found
```

### 7. Pagination (cursor-based)

The API uses cursor-based pagination. Meetings span multiple "sources" (host_calls, contact_calls, team_calls, etc.). A meeting where you were an invitee (not the recorder) may not appear on the first page.

```bash
# First page
RESPONSE=$(curl -s -H "X-Api-Key: $FATHOM_API_KEY" \
  "https://api.fathom.ai/external/v1/meetings?limit=50&created_after=2026-03-25T00:00:00Z")

# Get next cursor
CURSOR=$(echo "$RESPONSE" | jq -r '.next_cursor')

# Next page (if cursor is not null)
curl -s -H "X-Api-Key: $FATHOM_API_KEY" \
  "https://api.fathom.ai/external/v1/meetings?limit=50&created_after=2026-03-25T00:00:00Z&cursor=$CURSOR"
```

**Always paginate** when searching by title, URL, or attendee. Don't assume the first page has the meeting.

---

## Response Fields

| Field | Description |
|-------|-------------|
| `title` | Meeting title from calendar |
| `created_at` | When recording was processed |
| `recording_start_time` | Actual start of recording |
| `recording_end_time` | End of recording |
| `url` | Link to Fathom web player |
| `share_url` | Shareable link |
| `transcript` | Array of `{speaker, text, timestamp}` |
| `default_summary.markdown_formatted` | AI-generated summary |
| `action_items` | Extracted action items (if available) |
| `calendar_invitees` | Attendee list with emails |
| `recorded_by` | Who recorded the meeting |

---

## Workflow: Find and Summarize Meeting

1. **Find:** List recent → filter by title/attendee → identify target meeting
2. **Fetch:** Re-query with `include_transcript=true` + date filter
3. **Present:** Summary (`default_summary.markdown_formatted`), action items, key decisions, attendees, recording link (`url` or `share_url`)

---

## Common Patterns

### "What did we discuss about [topic]?"

1. Fetch meeting with transcript
2. Search transcript for keywords
3. Extract relevant segments with context
4. Summarize findings

### "Get action items from my last meeting"

1. Fetch most recent meeting
2. Check `action_items` field (may be null)
3. Parse `default_summary` for "Next Steps" section
4. Present as checklist

---

## Error Handling

| Error | Cause | Fix |
|-------|-------|-----|
| `401 Unauthorized` | Bad API key | Check `FATHOM_API_KEY` in `.env` |
| `404 Not Found` | Wrong endpoint | Use `api.fathom.ai/external/v1/` |
| Empty `items` | No meetings in range | Expand date range |
| No transcript | Recording too recent | Wait for processing (~5 min) |

---

## Rate Limits

Fathom API has rate limits. For bulk operations:
- Add `sleep 1` between requests
- Cache results locally when iterating

---

## Recording ID Verification

**Key reminder:** The URL format is `https://fathom.video/calls/{CALL_ID}` where `CALL_ID` is NOT the `recording_id`. You must look up the meeting via the list endpoint to get the actual `recording_id` for transcript fetching. Always verify via API before documenting.

---

## Privacy Notes

- Transcripts may contain sensitive information
- Do not log or store API responses permanently
- Share links only with authorized parties


## When to Use

- Fetching and synthesizing Fathom meeting transcripts
- Creating structured meeting notes with action items
- Searching past meetings for specific topics or decisions

## Failure Modes

- **Wrong API endpoint:** Using api.fathom.video instead of api.fathom.ai/external/v1/meetings
- **Missing transcript:** Forgetting include_transcript=true query parameter
- **Speaker attribution / fabricated quote:** Cross-check participant list and recording timestamps

---
name: fathom-api
source: superpowers-callbox
description: Fathom API endpoint guardrails and usage patterns for fetching meeting transcripts. Distinct from fathom-meeting-notes (which handles transcript synthesis).
summary: "Use when: making Fathom API calls. Key constraint: base URL is api.fathom.ai/external/v1."
triggers: ["fathom api", "fathom endpoint", "fathom api key", "fathom base url", "fathom curl", "api.fathom.ai", "fetch transcript"]
coordination:
  group: callbox
  order: 1
  requires: []
  enables: []
  escalates_to: []
  internal: false
anti_triggers: ['meeting notes', 'meeting transcript', 'what was discussed']
---

# Fathom API — Meeting Transcripts

When user says "fetch transcript" — the API works. Use it immediately.

**Base URL:** `https://api.fathom.ai/external/v1` (NOT `api.fathom.video`, NOT without `/external`)
**Auth:** `source ~/.codex/.env && curl -s -H "X-Api-Key: $FATHOM_API_KEY"`

**Fetch meetings:**
```bash
source ~/.codex/.env 2>/dev/null || source .env && \
curl -s -H "X-Api-Key: $FATHOM_API_KEY" \
  "https://api.fathom.ai/external/v1/meetings?include_transcript=true" | jq '.items[0]'
```

**Filters:** `include_transcript=true`, `include_summary=true`, `include_action_items=true`, `created_after=ISO_DATE`

**Response:** `{ items: [{ title, url, recording_id, created_at, transcript: [...] }], next_cursor }`

⚠️ **URL call ID ≠ recording_id.** `https://fathom.video/calls/612141967` → `612141967` is the _call ID_, not the `recording_id`. Get `recording_id` from the list response to fetch transcripts via `/recordings/{recording_id}/transcript`.

**Transcript endpoint (separate):**
```bash
curl -s -H "X-Api-Key: $FATHOM_API_KEY" \
  "https://api.fathom.ai/external/v1/recordings/{RECORDING_ID}/transcript"
```

**Pagination:** Use `next_cursor` from response. Meetings where you were an invitee (not recorder) may be on later pages.
```bash
curl -s ... "https://api.fathom.ai/external/v1/meetings?limit=50&cursor={CURSOR_VALUE}"
```

**Phone screen synthesis:** Filter by candidate name with jq `select(.title | test("NAME"; "i"))`, output to `*__SYNTHESIS.md`.

## When to Use

- When ANY Fathom API call is being made (correct endpoint, auth header, query params)
- When debugging 401/404 errors from Fathom API
- This is a guardrail — it activates to prevent wrong endpoints, NOT to drive workflow (use `fathom-meeting-notes` for workflow)

## Failure Modes

| Failure | Fix |
|---------|-----|
| 401 Unauthorized | Re-check `$FATHOM_API_KEY` in `~/.codex/.env` |
| 404 Not Found | You used the wrong endpoint. Valid: `/external/v1/meetings` (list), `/external/v1/recordings/{recording_id}/transcript` (transcript). No `/meetings/{id}` endpoint exists. |
| Empty `items` array | Widen date filter, paginate with `next_cursor`, or check Fathom UI |
| Meeting not on first page | Paginate using `cursor` param — invitee meetings appear in `contact_calls` source, often on page 2+ |
| Missing transcript | Add `include_transcript=true` query param |

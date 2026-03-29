---
name: pendo-guides
source: superpowers-[company]
description: Use when querying Pendo guides, in-app messages, tooltips, walkthroughs, or onboarding flows.
triggers: ["pendo guide", "guide completion", "active guides", "in-app message", "tooltip", "walkthrough", "onboarding flow", "guide stats"]
coordination:
  group: [company]
  order: 1
  requires: []
  enables: []
  escalates_to: []
  internal: false
anti_triggers: ['analytics', 'usage data', 'DAU', 'feature usage']
---

# Pendo Guides

> **API:** `https://app.pendo.io/api/v1`
> **Credentials:** `PENDO_API_KEY` in `~/.codex/.env`

---

## Purpose

Queries Pendo guide data: active/draft/disabled guides, completion rates, dismissal rates, and step-by-step funnel analysis.

**Announce at start:** "I'm using the pendo-guides skill to query your Pendo guide data."

---

## Checklist

| Query | Action |
|-------|--------|
| "What guides are active?" | List guides filtered by state |
| "Guide completion rate for X" | Guide stats with step funnel |
| "Show all onboarding guides" | Search guides by name |
| "Where do users drop off in guide X?" | Step-by-step funnel analysis |
| "Which guides target segment X?" | Guide segment details |

---

## API Authentication

```bash
source ~/.codex/.env
# Header: x-pendo-integration-key: $PENDO_API_KEY
```

---

## Core API Operations

### 1. List All Guides

```bash
source ~/.codex/.env
curl -s -H "x-pendo-integration-key: $PENDO_API_KEY" \
  -H "content-type: application/json" \
  "https://app.pendo.io/api/v1/guide" | \
  jq '.[] | {id, name, state, publishedAt}'
```

### 2. Filter Active Guides

```bash
source ~/.codex/.env
curl -s -H "x-pendo-integration-key: $PENDO_API_KEY" \
  -H "content-type: application/json" \
  "https://app.pendo.io/api/v1/guide" | \
  jq '[.[] | select(.state == "deployed")] | length as $count | "Active guides: \($count)", (.[] | {id, name})'
```

### 3. Guide Detail with Stats

```bash
source ~/.codex/.env
curl -s -H "x-pendo-integration-key: $PENDO_API_KEY" \
  -H "content-type: application/json" \
  "https://app.pendo.io/api/v1/guide/{guide_id}" | jq '.'
```

### 4. Search Guides by Name

```bash
source ~/.codex/.env
curl -s -H "x-pendo-integration-key: $PENDO_API_KEY" \
  -H "content-type: application/json" \
  "https://app.pendo.io/api/v1/guide" | \
  jq '.[] | select(.name | test("SEARCH_TERM"; "i")) | {id, name, state}'
```

---

## Common Patterns

### Guide Completion Analysis

```bash
source ~/.codex/.env
# Get guide with step data
curl -s -H "x-pendo-integration-key: $PENDO_API_KEY" \
  -H "content-type: application/json" \
  "https://app.pendo.io/api/v1/guide/{guide_id}" | \
  jq '{
    name: .name,
    state: .state,
    steps: [.steps[] | {id: .id, type: .type}],
    totalSteps: (.steps | length)
  }'
```

### List Guides by State

```bash
source ~/.codex/.env
# States: draft, deployed, disabled
curl -s -H "x-pendo-integration-key: $PENDO_API_KEY" \
  -H "content-type: application/json" \
  "https://app.pendo.io/api/v1/guide" | \
  jq 'group_by(.state) | .[] | {state: .[0].state, count: length, guides: [.[] | .name]}'
```

---

## Guide States

| State | Meaning |
|-------|---------|
| `draft` | Not yet published |
| `deployed` | Active and visible to users |
| `disabled` | Manually turned off |

---

## Error Handling

| Error | Cause | Fix |
|-------|-------|-----|
| `401 Unauthorized` | Bad API key | Check `PENDO_API_KEY` in `~/.codex/.env` |
| `404 Not Found` | Guide ID doesn't exist | Verify ID from list endpoint |
| Empty array | No guides configured | Check Pendo dashboard |

---

## Privacy Notes

- Guide targeting may reference user segments with PII
- Do not log segment details permanently
- Share results only with authorized parties


## When to Use

- Querying guide completion rates, active guide lists, or guide state counts
- Finding guides targeting specific user segments or page contexts
- Analyzing funnel data for onboarding flow drop-off
- Identifying in-app messages, tooltips, or walkthroughs by name/status

## Failure Modes

- **API key missing** → `401`. Verify `PENDO_API_KEY` in `~/.codex/.env`
- **Guide ID not found** → `404`. Verify ID from list endpoint before querying detail
- **Confusing with pendo-feature-tagging** → This skill is read-only for guides. Use pendo-feature-tagging to create/modify features

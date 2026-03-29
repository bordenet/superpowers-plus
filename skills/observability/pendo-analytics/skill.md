---
name: pendo-analytics
source: superpowers-callbox
description: Use when querying product analytics, feature usage, visitor counts, DAU/WAU/MAU, page views, or adoption metrics.
triggers: ["how many users", "page views", "DAU", "feature usage", "pendo analytics", "usage metrics", "adoption rate", "active users", "visitor count"]
coordination:
  group: callbox
  order: 1
  requires: []
  enables: []
  escalates_to: []
  internal: false
anti_triggers: ['create feature', 'tag feature', 'define feature']
---

# Pendo Analytics

> **API:** `https://app.pendo.io/api/v1`
> **Credentials:** `PENDO_API_KEY` in `~/.codex/.env`

---

## Purpose

Queries Pendo product analytics data: feature usage, visitor counts, page views, and adoption metrics.

**Announce at start:** "I'm using the pendo-analytics skill to query your Pendo analytics data."

---

## Checklist

| Query | Action |
|-------|--------|
| "How many users visited feature X?" | Feature usage count via aggregation |
| "What's our DAU this week?" | Daily active users aggregation |
| "Which pages are most visited?" | Page view rankings |
| "Feature adoption rate for X" | Feature usage trend over time |
| "Who's using feature X?" | Visitor details for feature |
| "Account-level usage for [account]" | Account rollup metrics |

---

## API Authentication

```bash
source ~/.codex/.env
# Header: x-pendo-integration-key: $PENDO_API_KEY
```

---

## Core API Operations

### 1. List All Features

```bash
source ~/.codex/.env
curl -s -H "x-pendo-integration-key: $PENDO_API_KEY" \
  -H "content-type: application/json" \
  "https://app.pendo.io/api/v1/feature" | jq '.[] | {id, name, appId}'
```

### 2. List All Pages

```bash
source ~/.codex/.env
curl -s -H "x-pendo-integration-key: $PENDO_API_KEY" \
  -H "content-type: application/json" \
  "https://app.pendo.io/api/v1/page" | jq '.[] | {id, name}'
```

### 3. Aggregation Query (POST)

⚠️ **Pendo uses POST for aggregation queries, not GET.**
⚠️ **Time values must be epoch milliseconds, not relative expressions like `now()-7d`.**
⚠️ **`visitors` source does NOT support `timeSeries`. Use `events` or `featureEvents` for time-series data.**

```bash
source ~/.codex/.env
# List all visitors (no time series)
curl -s -X POST \
  -H "x-pendo-integration-key: $PENDO_API_KEY" \
  -H "content-type: application/json" \
  -d '{
    "response": {"mimeType": "application/json"},
    "request": {
      "pipeline": [
        {"source": {"visitors": null}}
      ]
    }
  }' \
  "https://app.pendo.io/api/v1/aggregation" | jq '.results | length'
```

```bash
source ~/.codex/.env
# Events in last 7 days (time series with epoch ms)
SEVEN_AGO=$(( $(date +%s) * 1000 - 604800000 ))
NOW=$(( $(date +%s) * 1000 ))
curl -s -X POST \
  -H "x-pendo-integration-key: $PENDO_API_KEY" \
  -H "content-type: application/json" \
  -d "{
    \"response\": {\"mimeType\": \"application/json\"},
    \"request\": {
      \"pipeline\": [
        {\"source\": {\"events\": null, \"timeSeries\": {\"period\": \"dayRange\", \"first\": \"$SEVEN_AGO\", \"last\": \"$NOW\"}}}
      ]
    }
  }" \
  "https://app.pendo.io/api/v1/aggregation" | jq '.results | length'
```

### 4. Visitor Detail

```bash
source ~/.codex/.env
curl -s -H "x-pendo-integration-key: $PENDO_API_KEY" \
  -H "content-type: application/json" \
  "https://app.pendo.io/api/v1/visitor/{visitor_id}" | jq '.'
```

### 5. Account Detail

```bash
source ~/.codex/.env
curl -s -H "x-pendo-integration-key: $PENDO_API_KEY" \
  -H "content-type: application/json" \
  "https://app.pendo.io/api/v1/account/{account_id}" | jq '.'
```

---

## Common Patterns

### Feature Usage This Week

```bash
source ~/.codex/.env
SEVEN_AGO=$(( $(date +%s) * 1000 - 604800000 ))
NOW=$(( $(date +%s) * 1000 ))
curl -s -X POST \
  -H "x-pendo-integration-key: $PENDO_API_KEY" \
  -H "content-type: application/json" \
  -d "{
    \"response\": {\"mimeType\": \"application/json\"},
    \"request\": {
      \"pipeline\": [
        {\"source\": {\"featureEvents\": null, \"timeSeries\": {\"period\": \"dayRange\", \"first\": \"$SEVEN_AGO\", \"last\": \"$NOW\"}}},
        {\"filter\": \"featureId==FEATURE_ID_HERE\"}
      ]
    }
  }" \
  "https://app.pendo.io/api/v1/aggregation" | jq '.'
```

### Find Feature by Name

```bash
source ~/.codex/.env
curl -s -H "x-pendo-integration-key: $PENDO_API_KEY" \
  -H "content-type: application/json" \
  "https://app.pendo.io/api/v1/feature" | \
  jq '.[] | select(.name | test("SEARCH_TERM"; "i")) | {id, name}'
```

### Account-Level Usage (Last 30 Days)

```bash
source ~/.codex/.env
THIRTY_AGO=$(( $(date +%s) * 1000 - 2592000000 ))
NOW=$(( $(date +%s) * 1000 ))
curl -s -X POST \
  -H "x-pendo-integration-key: $PENDO_API_KEY" \
  -H "content-type: application/json" \
  -d "{
    \"response\": {\"mimeType\": \"application/json\"},
    \"request\": {
      \"pipeline\": [
        {\"source\": {\"events\": null, \"timeSeries\": {\"period\": \"dayRange\", \"first\": \"$THIRTY_AGO\", \"last\": \"$NOW\"}}},
        {\"filter\": \"accountId==ACCOUNT_ID_HERE\"}
      ]
    }
  }" \
  "https://app.pendo.io/api/v1/aggregation" | jq '.'
```

---

## Error Handling

| Error | Cause | Fix |
|-------|-------|-----|
| `401 Unauthorized` | Bad API key | Check `PENDO_API_KEY` in `~/.codex/.env` |
| `400 Bad Request` | Invalid aggregation pipeline | Verify JSON structure in POST body |
| `404 Not Found` | Feature/page/visitor ID doesn't exist | Verify ID from list endpoints |
| Empty response | No matching records | Expand date range or check filter |
| `429 Too Many Requests` | Rate limit exceeded | Add `sleep 1` between requests |

---

## Privacy Notes

- Visitor data may contain PII (email addresses, custom properties)
- Do not log or store API responses permanently
- Share results only with authorized parties


## When to Use

- Querying DAU/WAU/MAU, visitor counts, or active user trends
- Feature usage analysis: adoption rates, usage frequency
- Page view rankings and traffic analysis

## Failure Modes

- **Aggregation query timeout** → Date range too wide. Narrow or simplify pipeline
- **Epoch milliseconds vs relative time** → Queries use epoch ms, not `now()-7d`. Use `$(date +%s)000`
- **`visitors` source doesn't support timeSeries** → Use `events` or `featureEvents` instead

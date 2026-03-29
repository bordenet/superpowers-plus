---
name: pendo-feature-tagging
source: superpowers-callbox
description: Use when CREATING or UPDATING Pendo Feature definitions via the API, or instrumenting pendo.track() calls in code. NOT for auditing existing tag coverage (use pendo-tagging-verification).
triggers: ["create pendo feature", "add feature to pendo", "instrument in pendo", "add pendo tracking", "define pendo feature"]
coordination:
  group: callbox
  order: 1
  requires: []
  enables: ['pendo-tagging-verification']
  escalates_to: []
  internal: false
anti_triggers: ['guide completion', 'guide stats', 'analytics query']
---

# Pendo Feature Tagging

> **API:** `https://app.pendo.io/api/v1`
> **Credentials:** `PENDO_API_KEY` in `~/.codex/.env`

---

## Purpose

Creates and updates Pendo Feature definitions and verifies `pendo.track()` instrumentation in code. Use when deploying new features that need Pendo tracking.

**Announce at start:** "I'm using the pendo-feature-tagging skill to manage Pendo Feature definitions."

---

## Checklist

| Command | Action |
|---------|--------|
| "Tag this as Report Builder in Pendo" | Create Feature definition with selectors |
| "Update the Export CSV feature in Pendo" | Update existing Feature selectors |
| "Check if this code has pendo tracking" | Scan for pendo.track() calls |
| "What features are defined in Pendo?" | List all Feature definitions |

---

## Selector Generation Strategy

When creating a Feature definition, derive selectors in this priority order:

1. **`data-testid` attributes** (preferred, most stable) → `[data-testid="export-csv"]`
2. **URL path patterns** (for page-level features) → `/app/reports/*`
3. **Semantic CSS classes** (when data-testid unavailable) → `.report-builder-modal`
4. **User input fallback** — present component code and ask for guidance

---

## Safety Gates

<EXTREMELY_IMPORTANT>
1. **Duplicate check:** Always `GET /api/v1/feature` and search for similar names before creating.
2. **Confirm before write:** Show user the proposed Feature definition and get approval.
3. **Never delete without explicit approval.**
</EXTREMELY_IMPORTANT>

---

## Core API Operations

### 1. List All Features (Duplicate Check)

```bash
source ~/.codex/.env
curl -s -H "x-pendo-integration-key: $PENDO_API_KEY" \
  -H "content-type: application/json" \
  "https://app.pendo.io/api/v1/feature" | \
  jq '.[] | {id, name, appId, pageId}'
```

### 2. Search for Existing Feature by Name

```bash
source ~/.codex/.env
curl -s -H "x-pendo-integration-key: $PENDO_API_KEY" \
  -H "content-type: application/json" \
  "https://app.pendo.io/api/v1/feature" | \
  jq '.[] | select(.name | test("SEARCH_TERM"; "i")) | {id, name, pageId}'
```

### 3. Create Feature Definition

`elementPathRules` is an **array of CSS selector strings**, not objects.

```bash
source ~/.codex/.env
curl -s -X POST \
  -H "x-pendo-integration-key: $PENDO_API_KEY" \
  -H "content-type: application/json" \
  -d "{
    \"appId\": $PENDO_APP_ID,
    \"kind\": \"Feature\",
    \"name\": \"Feature Name Here\",
    \"description\": \"Optional description of the feature\",
    \"elementPathRules\": [
      \"[data-testid=\\\"feature-button\\\"]\"
    ],
    \"pageId\": \"PAGE_ID_HERE\"
  }" \
  "https://app.pendo.io/api/v1/feature" | jq '.'
```

### 4. Update Feature Definition

```bash
source ~/.codex/.env
curl -s -X PUT \
  -H "x-pendo-integration-key: $PENDO_API_KEY" \
  -H "content-type: application/json" \
  -d '{
    "name": "Updated Feature Name",
    "elementPathRules": [
      "[data-testid=\"updated-selector\"]"
    ]
  }' \
  "https://app.pendo.io/api/v1/feature/{feature_id}" | jq '.'
```

### 5. Delete Feature (Requires Approval)

```bash
source ~/.codex/.env
# ⚠️ NEVER run without explicit user approval
curl -s -X DELETE \
  -H "x-pendo-integration-key: $PENDO_API_KEY" \
  "https://app.pendo.io/api/v1/feature/{feature_id}"
```

---

## Instrumentation Verification

When checking if code has proper Pendo tracking:

### Scan for pendo.track() Calls

```bash
# Search codebase for pendo.track usage
grep -rn "pendo\.track\|pendo\.initialize\|pendo\.identify" --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" src/
```

### Expected Instrumentation Pattern

```typescript
// Track a feature event
pendo.track("Feature Name", {
  action: "clicked",
  component: "export-csv-button",
  context: "reports-page"
});
```

---

## Workflow: "Tag this as XXX in Pendo"

1. **Inspect the code** — understand the UI element (component, selectors, URL)
2. **Duplicate check** — search existing Pendo features for similar names
3. **Determine selector** — use priority order (data-testid → URL → CSS class → ask user)
4. **Find the page** — identify which Pendo Page the feature belongs to
5. **Present proposal** — show user the Feature definition before creating
6. **Create** — POST to Pendo API after user approval
7. **Verify** — confirm feature appears in Pendo feature list
8. **Check instrumentation** — scan code for pendo.track() calls, suggest additions if missing

---

## Error Handling

| Error | Cause | Fix |
|-------|-------|-----|
| `401 Unauthorized` | Bad API key | Check `PENDO_API_KEY` in `~/.codex/.env` |
| `400 Bad Request` | Invalid feature definition | Check JSON body structure |
| `409 Conflict` | Feature with same name exists | Use update instead of create |
| `404 Not Found` | Feature ID doesn't exist | Verify ID from list endpoint |


## When to Use

- Creating Pendo Feature definitions for UI elements
- Instrumenting `pendo.track()` calls in TypeScript/JavaScript
- Updating existing Feature selectors after UI changes

## Failure Modes

- **Duplicate feature name** → Feature already exists. Use update endpoint or rename
- **Missing PENDO_APP_ID** → Required for creation. Set in `~/.codex/.env`
- **Confusing with pendo-tagging-verification** → This skill creates/modifies. Use pendo-tagging-verification to audit

# Curl Fallback Patterns

Only use curl if MCP tools are unavailable or failing.

## Base URL

`https://wiki.int.[company].net/api`

## Key Endpoints

| Endpoint | Purpose | MCP Equivalent |
|----------|---------|----------------|
| `documents.info` | Fetch document content and metadata | `get_document_outline` |
| `documents.update` | Update document content | `update_document_outline` |
| `documents.create` | Create new document | `create_document_outline` |
| `documents.move` | Move document to new parent | `move_document_outline` |

## Fetch + Edit + Push Pattern

```bash
# Step 1: Fetch current state
curl -s -X POST "https://wiki.int.[company].net/api/documents.info" \
  -H "Authorization: Bearer $OUTLINE_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"id": "DOCUMENT_ID_OR_URL_SLUG"}' | jq -r '.data.text' > /tmp/wiki-current.md

# Step 2: Edit /tmp/wiki-current.md

# Step 3: Push updated content
# Build JSON payload from file directly (avoid shell command substitution which
# strips trailing newlines). jq reads the file and builds the full JSON object.
jq -Rsn --arg id "DOCUMENT_UUID" \
  '{id: $id, text: input, publish: true}' /tmp/wiki-current.md > /tmp/wiki-payload.json
curl -s -X POST "https://wiki.int.[company].net/api/documents.update" \
  -H "Authorization: Bearer $OUTLINE_API_KEY" \
  -H "Content-Type: application/json" \
  -d @/tmp/wiki-payload.json
```

## Scope Check via Curl

```bash
curl -s -X POST "https://wiki.int.[company].net/api/documents.info" \
  -H "Authorization: Bearer $OUTLINE_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"id": "TARGET_DOC_ID"}' | jq '{id: .data.id, url: .data.url, collectionId: .data.collectionId, parentDocumentId: .data.parentDocumentId}'
```

## Duplicate Check via Curl

```bash
PARENT_ID="parent-document-uuid"
TITLE="My New Page Title"

EXISTING=$(curl -s -X POST "https://wiki.int.[company].net/api/documents.list" \
  -H "Authorization: Bearer $OUTLINE_API_KEY" \
  -H "Content-Type: application/json" \
  -d "{\"parentDocumentId\": \"$PARENT_ID\"}" | jq -r ".data[] | select(.title == \"$TITLE\") | .id")

if [ -n "$EXISTING" ]; then
  echo "Page already exists: $EXISTING — use update, not create"
else
  echo "Safe to create"
fi
```

## Anchor Format

Outline uses `#h-section-name` (not `#section-name`).

```markdown
[Section Name](#h-section-name)
[↑ Back to top](#h-table-of-contents)
```

## Temp File Conventions

```
/tmp/wiki-<descriptive-name>.md
_temp_<descriptive-name>.md   # in workspace
```

Always clean up temp files after pushing.

## ❌ NEVER Use Heredocs

Heredocs (`<< EOF ... EOF`) fail silently. Use `save-file` tool instead.

